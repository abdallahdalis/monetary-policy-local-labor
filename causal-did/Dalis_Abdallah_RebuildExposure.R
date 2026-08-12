# ==============================================================================
#  Spurious Precision: Why Shift-Share Designs Overstate Monetary Policy
#                      Effects on Local Employment
#  REBUILD of the CBP county exposure measure
#  Author     : Abdallah Dalis
#  Institution: DePaul University
#
#  Built August 12, 2026, after the defect described in
#  causal-did/EXPOSURE_DEFECT_2026-08-12.md.
#
#  ------------------------------------------------------------------------------
#  THE DEFECT, in one paragraph.
#
#  01_clean_data.do (lines 206-228) cleaned the CBP NAICS field by stripping "-"
#  and "/", then took the FIRST TWO CHARACTERS and kept every row whose first two
#  characters were 23, 31, 32 or 33. CBP county files carry the whole NAICS
#  hierarchy, so "23----", "236---", "2361--" and "236115" all reduce to a
#  leading "23". `collapse (sum) emp` then added construction and manufacturing
#  employment once per hierarchy level, while the denominator used only the
#  "------" total row. The numerator is multiply-counted; the denominator is not.
#
#  `drop if exp_sens_ > 1` on line 228 is the tell. A correctly built share
#  cannot exceed one. That line silently deleted the worst-affected counties,
#  which is a non-random screen on industrial detail.
#
#  ------------------------------------------------------------------------------
#  WHAT THIS SCRIPT DOES DIFFERENTLY.
#
#  It selects SECTOR-LEVEL rows only, and it does not assume it knows how this
#  vintage of CBP encodes them. Section 1 PRINTS the code structure before any
#  filter is applied, so the hierarchy is inspected rather than guessed. Section
#  3 refuses to write output unless the rebuilt measure passes its checks.
#
#  ⚠️ DO NOT SKIP SECTION 1. The original defect came from assuming a file format
#  instead of looking at it. If the printed structure does not match what the
#  filter in section 2 expects, fix the filter, do not widen it.
#
#  Input : raw/CBP/cbp02co.txt   (Census, free download; see the memo for the URL)
#          data/cbp_exposure_2002.dta   (the DEFECTIVE file, for comparison only)
#  Output: data/cbp_exposure_2002_rebuilt.dta
#          tables/tab_exposure_rebuild_comparison.csv
#
#  The old file is NOT overwritten. Nothing downstream changes until you point it
#  at the rebuilt file deliberately.
# ==============================================================================

rm(list = ls())
suppressMessages({ library(dplyr); library(haven) })
select <- dplyr::select; filter <- dplyr::filter
if (!requireNamespace("tidyr", quietly = TRUE))
  stop("tidyr is required (pivot_wider). install.packages('tidyr')")

PROJ <- "."
TAB  <- file.path(PROJ, "tables");  dir.create(TAB, showWarnings = FALSE, recursive = TRUE)

RAW_CANDIDATES <- c("raw/CBP/cbp02co.txt", "causal-did/raw/CBP/cbp02co.txt",
                    "data/cbp02co.txt", "~/Downloads/cbp02co.txt")
RAW <- NA_character_
for (p in RAW_CANDIDATES) if (file.exists(path.expand(p))) { RAW <- path.expand(p); break }
if (is.na(RAW)) stop(
  "cbp02co.txt not found. Download and unzip:\n",
  "  https://www2.census.gov/programs-surveys/cbp/datasets/2002/cbp02co.zip\n",
  "then place cbp02co.txt in one of: ", paste(RAW_CANDIDATES, collapse = ", "))
cat(sprintf("raw CBP : %s\n", RAW))

cbp <- dplyr::as_tibble(read.csv(RAW, stringsAsFactors = FALSE))
names(cbp) <- tolower(names(cbp))
stopifnot(all(c("fipstate", "fipscty", "naics", "emp") %in% names(cbp)))

cbp <- cbp %>%
  mutate(area_fips = sprintf("%02d%03d", as.integer(fipstate), as.integer(fipscty)),
         naics_raw   = as.character(naics),
         naics_clean = gsub("[-/]", "", naics_raw),
         nlen        = nchar(naics_clean),
         emp         = as.numeric(emp))


# ==============================================================================
# === SECTION 1.0 — LOOK AT THE FILE BEFORE FILTERING IT =======================
# ==============================================================================
#  This is the section whose absence caused the defect.

cat("\n----- RAW NAICS CODE STRUCTURE -----\n")
cat(sprintf("rows: %s   counties: %d\n", format(nrow(cbp), big.mark = ","),
            n_distinct(cbp$area_fips)))

cat("\ncleaned-code LENGTH distribution (0 = the '------' total row):\n")
print(cbp %>% count(nlen) %>% arrange(nlen), n = 20)

cat("\nDISTINCT codes beginning 23 / 31 / 32 / 33, by length,\n")
cat("with total employment. If more than one length appears, the hierarchy is\n")
cat("present and a prefix match WILL double count:\n")
print(cbp %>%
        filter(grepl("^(23|31|32|33)", naics_clean)) %>%
        group_by(nlen) %>%
        summarise(distinct_codes = n_distinct(naics_clean),
                  example = paste(head(sort(unique(naics_raw)), 3), collapse = " "),
                  emp = sum(emp, na.rm = TRUE), .groups = "drop"),
      n = 20)

cat("\nSECTOR-LEVEL codes actually present (cleaned length 2, or a combined\n")
cat("manufacturing code such as '31-33'):\n")
print(cbp %>%
        filter(nlen <= 4, grepl("^(23|31|32|33)", naics_clean)) %>%
        count(naics_raw, naics_clean, nlen, wt = NULL) %>% arrange(naics_clean),
      n = 30)


# ==============================================================================
# === SECTION 2.0 — BUILD, SECTOR LEVEL ONLY ===================================
# ==============================================================================
#  Accepts either separate sector codes (23, 31, 32, 33) or a combined
#  manufacturing code (3133, from "31-33"). Anything longer is a sub-industry and
#  is EXCLUDED, because its employment is already inside its parent sector.

#  Match the RAW code, not the cleaned one. Cleaning is exactly what makes the
#  combined manufacturing code "31-33" indistinguishable from "3133//", which is
#  NAICS 3133, Textile and Fabric Finishing Mills — a 4-digit industry already
#  inside 313, already inside 31. In the 2002 vintage only "3133//" is present
#  (524 counties, 46 with nonzero employment), so a cleaned-code filter re-adds
#  those workers on top of the "31----" sector total. That is the same
#  double count this script exists to remove, one level down.
RE_CONSTR <- "^23-+$"                   # 23----
RE_MANUF  <- "^(31|32|33)-+$|^31-33$"   # 31----/32----/33----, or a true combined 31-33

is_total  <- cbp$nlen == 0
is_constr <- grepl(RE_CONSTR, cbp$naics_raw)
is_manuf  <- grepl(RE_MANUF,  cbp$naics_raw)

cat(sprintf("\nrows kept: total %d | construction %d | manufacturing %d\n",
            sum(is_total), sum(is_constr), sum(is_manuf)))
if (sum(is_constr) == 0 || sum(is_manuf) == 0)
  stop("No sector-level rows matched. Read section 1 output and fix the filter.")

agg <- bind_rows(
  cbp[is_total,  ] %>% transmute(area_fips, ind = "total",  emp),
  cbp[is_constr, ] %>% transmute(area_fips, ind = "constr", emp),
  cbp[is_manuf,  ] %>% transmute(area_fips, ind = "manuf",  emp)) %>%
  group_by(area_fips, ind) %>% summarise(emp = sum(emp, na.rm = TRUE), .groups = "drop") %>%
  tidyr::pivot_wider(names_from = ind, values_from = emp, values_fill = 0,
                     names_prefix = "emp")

# --- 2.1 DROP THE STATEWIDE RESIDUAL RECORDS. Added August 12, 2026. ----------
#  CBP writes a `SS999` record per state for establishments it cannot allocate to
#  a county. These are NOT counties. The first version of this script kept them,
#  and they did three things, all invisible:
#    (a) inflated the county count from 3,126 to 3,171, which was then propagated
#        into Methods and the plain-language summary as a count of counties;
#    (b) dragged every state mean in tab_exposure_by_state.csv down by one
#        near-zero pseudo-county — and the drag is LARGEST for states with fewest
#        counties, so the bottom of the ranking in section 5.1 is the part most
#        distorted. The District of Columbia has one real county and one 999
#        record, so its reported mean is roughly half its true value;
#    (c) contributed 45 of the 186 zero-exposure counties discussed in 5.1.
#  Their mean exposure is 0.0006, which is what a residual category looks like.
#
#  ---------------------------------------------------------------------------
#  AMENDED the same day, after the first version of this filter deleted the
#  DISTRICT OF COLUMBIA.
#
#  `999` is not universally a residual code. In the 2002 vintage the District of
#  Columbia has NO county-detail record at all: 11999 is its only area, carrying
#  418,755 employees, which is the whole District. Fifty-one states write a 999
#  record and exactly one of them -- DC -- writes nothing else. The blanket
#  `grepl("999$")` filter therefore dropped a real jurisdiction along with fifty
#  genuine residuals, and it did so silently, which is the shape of defect this
#  script exists to remove.
#
#  Note also that point (b) above was WRONG as originally written. DC's reported
#  0.0201 was not "roughly half its true value" -- it had no second record to be
#  dragged down by. 0.0201 IS its value, and it is the lowest in the country.
#
#  The fix is inspected, not assumed: the state-level check below re-derives the
#  set of states with no non-999 area and refuses to run if it is not exactly
#  {11}. DC is recoded to 11001, the FIPS that QCEW and every county shapefile
#  use for it.
#
#  CONSEQUENCE FOR THE ESTIMATION SAMPLE: DC now joins. The count is 3,127, not
#  3,126, and every regression was re-run. DC had never been in the sample in any
#  earlier version of this paper, because 11999 never matched QCEW's 11001.
#  Excluding it was an artifact, not a decision; Abdallah chose to include it on
#  August 12, 2026.
#  Which states write a 999 record and NOTHING else? Derived from the raw file,
#  not asserted. If this is ever not exactly "11", the vintage differs from the
#  one this filter was written against and the filter must be re-read.
state_only999 <- cbp %>%
  mutate(st = substr(area_fips, 1, 2), cty = substr(area_fips, 3, 5)) %>%
  group_by(st) %>%
  summarise(n_real = n_distinct(cty[cty != "999"]), .groups = "drop") %>%
  filter(n_real == 0) %>% pull(st)
cat(sprintf("\nstates whose ONLY area record is 999 : %s\n",
            paste(state_only999, collapse = ", ")))
if (!identical(sort(state_only999), "11"))
  stop("Expected exactly one state with no county-detail record (11, the ",
       "District of Columbia). Got: ", paste(state_only999, collapse = ", "),
       ". Re-read the file before filtering it.")

#  Recode DC to the FIPS the rest of the world uses for it, THEN drop residuals.
agg <- agg %>% mutate(area_fips = ifelse(area_fips == "11999", "11001", area_fips))

n_999 <- sum(grepl("999$", agg$area_fips))
cat(sprintf("statewide `SS999` residual records dropped : %d\n", n_999))
if (n_999 > 0) {
  drop999 <- agg %>% filter(grepl("999$", area_fips)) %>%
    mutate(sh = (empconstr + empmanuf) / pmax(emptotal, 1))
  cat(sprintf("  their mean share was %.4f (a residual category, not a county)\n",
              mean(drop999$sh, na.rm = TRUE)))
}
agg <- agg %>% filter(!grepl("999$", area_fips))
cat(sprintf("  District of Columbia retained as 11001    : %s\n",
            "11001" %in% agg$area_fips))
if (!"11001" %in% agg$area_fips)
  stop("The District of Columbia was lost. The recode above did not fire.")

new <- agg %>%
  filter(emptotal > 0) %>%
  mutate(exp_sens_2002 = (empconstr + empmanuf) / emptotal)

# --- 2.2 Guard: the county count must now equal the QCEW-joined count. --------
#  3,127 is not a magic number; it is 3,126 -- what the join produced while the
#  999s were still present and being discarded silently by inner_join -- plus the
#  District of Columbia, recoded above. If this stops matching, something else
#  changed and the descriptives cannot be trusted.
if (nrow(new) != 3127)
  warning(sprintf(
    "County count is %d, expected 3,127 (the QCEW-joined count). Investigate before quoting it.",
    nrow(new)))


# ==============================================================================
# === SECTION 3.0 — VERIFY, THEN AND ONLY THEN WRITE ===========================
# ==============================================================================

n_over <- sum(new$exp_sens_2002 > 1)
cat("\n----- VERIFICATION -----\n")
cat(sprintf("counties built            : %d\n", nrow(new)))
cat(sprintf("shares above 1            : %d   <- MUST be 0\n", n_over))
if (n_over > 0) {
  print(new %>% filter(exp_sens_2002 > 1) %>% arrange(desc(exp_sens_2002)) %>% head(10))
  stop("Shares still exceed 1. The numerator is still double counting. Do not write output.")
}
cat(sprintf("mean / median             : %.4f / %.4f\n",
            mean(new$exp_sens_2002), median(new$exp_sens_2002)))
cat(sprintf("p10 / p90                 : %.4f / %.4f\n",
            quantile(new$exp_sens_2002, .10), quantile(new$exp_sens_2002, .90)))
cat(sprintf("max                       : %.4f\n", max(new$exp_sens_2002)))
cat("\nSanity anchor: national construction plus manufacturing was roughly 0.19 of\n")
cat("CBP employment in 2002. A median county somewhat above that is expected; a\n")
cat("median near 0.45 is the defect.\n")

# --- Compare against the defective file, and quantify the over-count -----------
old_path <- file.path(PROJ, "data", "cbp_exposure_2002.dta")
if (file.exists(old_path)) {
  old <- read_dta(old_path) %>%
    mutate(area_fips = sprintf("%05s", as.character(area_fips)),
           old_exp = as.numeric(exp_sens_2002)) %>% select(area_fips, old_exp)
  cmp <- new %>% select(area_fips, new_exp = exp_sens_2002) %>%
    full_join(old, by = "area_fips") %>%
    mutate(factor = old_exp / new_exp)
  cat("\n----- OLD vs REBUILT -----\n")
  cat(sprintf("counties in rebuilt only  : %d   <- counties the old `drop if >1` deleted\n",
              sum(is.na(cmp$old_exp))))
  cat(sprintf("counties in old only      : %d\n", sum(is.na(cmp$new_exp))))
  cat(sprintf("median over-count factor  : %.2fx\n",
              median(cmp$factor[is.finite(cmp$factor)], na.rm = TRUE)))
  cat(sprintf("correlation old vs new    : %.3f\n",
              cor(cmp$old_exp, cmp$new_exp, use = "complete.obs")))
  cat("\nA factor well above 1 that VARIES across counties is the signature: the\n")
  cat("over-count tracks how much industry detail each county reports, so it is\n")
  cat("measurement error correlated with industrial diversity, not a rescaling.\n")
  print(summary(cmp$factor[is.finite(cmp$factor)]))
  write.csv(cmp, file.path(TAB, "tab_exposure_rebuild_comparison.csv"), row.names = FALSE)
}

write_dta(new %>% select(area_fips, exp_sens_2002),
          file.path(PROJ, "data", "cbp_exposure_2002_rebuilt.dta"))
cat("\nwrote: data/cbp_exposure_2002_rebuilt.dta\n")
cat("The defective data/cbp_exposure_2002.dta is UNCHANGED. Repoint downstream\n")
cat("scripts deliberately, one at a time, and re-run each self-check.\n")
cat("\n----- DONE -----\n")

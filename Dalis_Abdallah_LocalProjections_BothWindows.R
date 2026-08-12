# ==============================================================================
#  Spurious Precision: Why Shift-Share Designs Overstate Monetary Policy
#                      Effects on Local Employment
#  Local projections, BOTH sample windows
#  Author     : Abdallah Dalis
#  Institution: DePaul University
#
#  Built August 11, 2026.
#
#  WHY. The abstract and Methods both state that every result is reported for
#  the full window and again excluding 2009-2012. That is currently FALSE for
#  the local projections: tables/tab_signflip.csv is full-window only, and
#  Figures 5 and 6 carry the title claim on one window. This script closes that.
#
#  ⚠️⚠️  TWO THINGS TO KNOW BEFORE CHANGING ANYTHING  ⚠️⚠️
#
#  (1) WHY THE OUTCOME IS BUILT TIME-AWARE.
#
#  The original local projection in monetary_policy_labor.R builds the outcome
#  with POSITIONAL operators inside each county:
#
#        yh = 100 * (dplyr::lead(ln_emp, h) - dplyr::lag(ln_emp, 1))
#
#  On the full panel that is harmless. Dalis_Abdallah_LPReconciliation.R proved
#  it: positional and time-aware agree to machine precision there, because the
#  13 short counties are TRUNCATED, not holed. But dropping 2009-2012 creates a
#  genuine interior hole, and positional operators would then splice every
#  county's 2013q1 lag back to 2008q4. That is the seam-splicing bug from
#  PIPELINE_RECONCILIATION.md section 4d, which produces "low variance around a
#  corrupted target" and would manufacture precision in the very figure arguing
#  precision is manufactured.
#
#  So: time-aware is unnecessary for the full window and REQUIRED for the
#  excluded one. It is used for both, so the two columns are comparable.
#
#  (2) THE PANEL FILTER IS LOAD-BEARING. DO NOT CHANGE IT.
#
#  This script originally used `is.finite(ln_emp)`, matching the causal-did
#  scripts, and failed its own self-check by 0.54. The cause was NOT the lead
#  operator. It was the filter. monetary_policy_labor.R uses
#  `month3_emplvl > 0`, which drops 32 further rows out of 207,672.
#
#  ⚠️ REVISED AUGUST 12, 2026 — THE EARLIER FRAMING HERE WAS WRONG.
#
#  This note used to say those 32 rows "move the headline SE ratio range from
#  6.3-12.0 to 4.2-9.6", that "a third of the headline number rests on a filter
#  choice", and that the SENSITIVITY IS ITSELF A FINDING. That reads the two
#  filters as two defensible screens giving different answers. They are not.
#
#  `is.finite(ln_emp)` SCREENS NOTHING. In qcew_panel_all_years.dta, ln_emp is
#  coded 0 wherever month3_emplvl is 0 — log(0) became 0 upstream, not -Inf. All
#  232,008 rows pass is.finite(). It is a no-op, not an alternative.
#
#  The 32 rows are zero-employment county-quarters carrying ln_emp = 0, against
#  a median county of 8.991 and a minimum among positives of 3.219. Each sits
#  about nine log points below any real county. At h = 0 they double the outcome
#  standard deviation, 5.29 -> 10.52, and stretch its range from [-108, +181] to
#  [-821, +822].
#
#  Eleven counties, all small, and two of them are FIPS-recode pairs: Wade
#  Hampton -> Kusilvak (AK, 2015) and Shannon -> Oglala Lakota (SD, 2015). The
#  zeros cluster at rename boundaries. They are construction artifacts.
#
#  So 4.2-9.6 is NOT a robustness range. It is a contaminated estimate, and
#  reporting it as a sensitivity would overstate the paper's fragility and
#  invite a referee to ask why a broken screen was run at all. Do not report it.
#
#  What IS worth carrying: this panel codes log(0) as 0, so a screen that looks
#  equivalent silently admits 32 catastrophic-leverage rows. Methods states the
#  screen is on employment levels for that reason.
#
#  ⚠️ Also refuted August 12: these are NOT the exposure outliers at 0.9997.
#  Zero overlap with the top-15 exposure counties. Two separate open items.
#
#  Input : qcew_panel_all_years.dta, FEDFUNDS.csv, cbp_exposure_2002.dta,
#          bauer_swanson_mps.xlsx, tables/tab_signflip.csv (for the self-check)
#  Output: tables/tab_signflip_zlb-full.csv
#          tables/tab_signflip_zlb-excl.csv
#          tables/tab_signflip_window_comparison.csv
# ==============================================================================

rm(list = ls())

# ---- Packages ----------------------------------------------------------------
suppressMessages({
  library(haven)
  library(readxl)
  library(dplyr)
  library(sandwich)
})
select <- dplyr::select; filter <- dplyr::filter
lag    <- dplyr::lag;    lead   <- dplyr::lead

# ---- Paths -------------------------------------------------------------------
PROJ <- "."
TAB  <- file.path(PROJ, "tables")
dir.create(TAB, showWarnings = FALSE, recursive = TRUE)

H         <- 12
ZLB_YEARS <- 2009:2012


# ==============================================================================
# === SECTION 1.0 — BUILD THE PANEL ============================================
# ==============================================================================

DATA_CANDIDATES <- c("../Research_Monetary_Incidence/data",
                     "~/Documents/Research_Monetary_Incidence/data",
                     "causal-did/../../Research_Monetary_Incidence/data",
                     "data")
DATA <- NA_character_
for (p in DATA_CANDIDATES)
  if (file.exists(file.path(path.expand(p), "qcew_panel_all_years.dta"))) {
    DATA <- path.expand(p); break
  }
if (is.na(DATA)) stop("Panel not found. Working directory: ", getwd())
cat(sprintf("\ndata dir : %s\n", DATA))

# ⚠️ Filter and FIPS padding must match monetary_policy_labor.R exactly. See
# header note (2). `is.finite(ln_emp)` is NOT equivalent and breaks the
# self-check by 0.54.
panel <- read_dta(file.path(DATA, "qcew_panel_all_years.dta")) %>%
  mutate(area_fips = sprintf("%05s", as.character(area_fips)),
         year      = as.integer(year),
         qtr       = as.integer(qtr),
         qidx      = (year - 2002L) * 4L + qtr) %>%
  filter(year >= 2002, year <= 2019, month3_emplvl > 0) %>%
  select(area_fips, year, qtr, qidx, ln_emp)

#  Repointed August 12, 2026 to the REBUILT measure; see
#  EXPOSURE_DEFECT_2026-08-12.md and causal-did/Dalis_Abdallah_RebuildExposure.R.
#  ⚠️ The self-check against tables/tab_signflip.csv was computed on the OLD
#  measure and will now disagree by construction. That is correct behaviour, not
#  a regression: retire the old reference rather than loosen the tolerance.
EXPO_CANDIDATES <- c(file.path(DATA, "cbp_exposure_2002_rebuilt.dta"),
                     "data/cbp_exposure_2002_rebuilt.dta",
                     "../data/cbp_exposure_2002_rebuilt.dta",
                     "~/Documents/projects/monetary-policy-local-labor/data/cbp_exposure_2002_rebuilt.dta")
EXPO <- NA_character_
for (p in EXPO_CANDIDATES)
  if (file.exists(path.expand(p))) { EXPO <- path.expand(p); break }
if (is.na(EXPO)) stop(
  "Rebuilt exposure file not found. Run causal-did/Dalis_Abdallah_RebuildExposure.R ",
  "from the project root first. Looked in: ", paste(EXPO_CANDIDATES, collapse = ", "))
cat(sprintf("exposure : %s\n", EXPO))

cbp02 <- read_dta(EXPO) %>%
  mutate(area_fips = sprintf("%05s", as.character(area_fips)),
         exp_sens  = as.numeric(exp_sens_2002)) %>%
  select(area_fips, exp_sens)

ffr_q <- read.csv(file.path(DATA, "FEDFUNDS.csv"), stringsAsFactors = FALSE) %>%
  mutate(date = as.Date(observation_date),
         year = as.integer(format(date, "%Y")),
         qtr  = (as.integer(format(date, "%m")) - 1) %/% 3 + 1) %>%
  filter(year >= 2002, year <= 2019) %>%
  group_by(year, qtr) %>%
  summarise(ffr = mean(FEDFUNDS, na.rm = TRUE), .groups = "drop") %>%
  arrange(year, qtr) %>%
  mutate(dffr = c(NA, diff(ffr))) %>%
  select(year, qtr, dffr)

bs_file <- file.path(DATA, "bauer_swanson_mps.xlsx")
if (!file.exists(bs_file)) {
  bs_file <- file.path(PROJ, "data", "bauer_swanson_mps.xlsx")
}
if (!file.exists(bs_file)) {
  stop("Bauer-Swanson workbook not found. Run Dalis_Abdallah_ShockComparison_Figure.R first; it caches the download.")
}
bsq <- read_xlsx(bs_file, sheet = "Monthly (update 2023)") %>%
  transmute(year     = as.integer(Year),
            month    = as.integer(Month),
            MPS_ORTH = as.numeric(MPS_ORTH)) %>%
  mutate(qtr = (month - 1) %/% 3 + 1) %>%
  group_by(year, qtr) %>%
  summarise(MPS_ORTH = sum(MPS_ORTH, na.rm = TRUE), .groups = "drop")

P <- panel %>%
  inner_join(cbp02, by = "area_fips") %>%
  left_join(ffr_q,  by = c("year", "qtr")) %>%
  left_join(bsq,    by = c("year", "qtr")) %>%
  mutate(expz = (exp_sens - mean(exp_sens, na.rm = TRUE)) /
                 sd(exp_sens, na.rm = TRUE)) %>%
  arrange(area_fips, qidx)

cat(sprintf("counties : %d\nquarters : %d\nrows     : %s\n",
            n_distinct(P$area_fips), n_distinct(P$qidx),
            format(nrow(P), big.mark = ",")))


# ==============================================================================
# === SECTION 2.0 — TIME-AWARE OUTCOME, THEN THE PROJECTION ====================
# ==============================================================================
#  ln_emp is looked up by (county, qidx + h) and (county, qidx - 1) through an
#  explicit join. A missing quarter yields NA and the row drops. Nothing splices.

emp_lookup <- P %>% select(area_fips, qidx, ln_emp)

# Two-way within transform, matching monetary_policy_labor.R demean2().
demean2 <- function(df, v) {
  df %>%
    group_by(area_fips) %>% mutate(ci = mean(.data[[v]], na.rm = TRUE)) %>%
    group_by(qidx)      %>% mutate(ti = mean(.data[[v]], na.rm = TRUE)) %>%
    ungroup() %>%
    mutate("{v}_w" := .data[[v]] - ci - ti + mean(.data[[v]], na.rm = TRUE)) %>%
    select(-ci, -ti)
}

lp_interaction <- function(base, shockvar, exclude_zlb) {
  out <- data.frame()
  for (h in 0:H) {

    d <- base %>%
      mutate(qidx_h = qidx + h, qidx_b = qidx - 1L) %>%
      left_join(emp_lookup %>% rename(qidx_h = qidx, ln_emp_h = ln_emp),
                by = c("area_fips", "qidx_h")) %>%
      left_join(emp_lookup %>% rename(qidx_b = qidx, ln_emp_b = ln_emp),
                by = c("area_fips", "qidx_b")) %>%
      mutate(yh = 100 * (ln_emp_h - ln_emp_b),
             sx = .data[[shockvar]] * expz)

    # Restrict the ESTIMATION sample only after the outcome is built.
    if (exclude_zlb) d <- d %>% filter(!(year %in% ZLB_YEARS))

    d <- d %>% filter(is.finite(yh), is.finite(sx))
    d <- demean2(d, "yh"); d <- demean2(d, "sx")

    m <- lm(yh_w ~ sx_w - 1, data = d)
    V <- sandwich::vcovCL(m, cluster = d$qidx)   # cluster by quarter
    out <- rbind(out, data.frame(h  = h,
                                 b  = unname(coef(m)["sx_w"]),
                                 se = sqrt(V["sx_w", "sx_w"]),
                                 n  = nrow(d)))
  }
  out
}

run_window <- function(exclude_zlb, tag) {
  raw <- lp_interaction(P, "dffr",     exclude_zlb)
  sur <- lp_interaction(P, "MPS_ORTH", exclude_zlb)
  res <- merge(raw, sur, by = "h", suffixes = c("_raw", "_sur"))

  res$p_raw    <- 2 * pnorm(-abs(res$b_raw / res$se_raw))
  res$p_sur    <- 2 * pnorm(-abs(res$b_sur / res$se_sur))
  res$se_ratio <- res$se_sur / res$se_raw
  res$window   <- tag

  cat(sprintf("\n----- LOCAL PROJECTIONS: %s -----\n", tag))
  print(round(res[, c("h", "b_raw", "se_raw", "p_raw",
                      "b_sur", "se_sur", "p_sur", "se_ratio")], 4),
        row.names = FALSE)
  cat(sprintf("raw positive        : %d of %d\n", sum(res$b_raw > 0), nrow(res)))
  cat(sprintf("raw significant     : %d of %d\n", sum(res$p_raw < 0.05), nrow(res)))
  cat(sprintf("identified negative : %d of %d\n", sum(res$b_sur < 0), nrow(res)))
  cat(sprintf("identified signif.  : %d of %d\n", sum(res$p_sur < 0.05), nrow(res)))
  cat(sprintf("SE ratio range      : %.1f to %.1f\n",
              min(res$se_ratio), max(res$se_ratio)))
  res
}

full <- run_window(FALSE, "full 2002-2019")
excl <- run_window(TRUE,  "excl 2009-2012")

write.csv(full, file.path(TAB, "tab_signflip_zlb-full.csv"), row.names = FALSE)
write.csv(excl, file.path(TAB, "tab_signflip_zlb-excl.csv"), row.names = FALSE)


# ==============================================================================
# === SECTION 2.1 — SELF-CHECK AGAINST THE PUBLISHED FULL-WINDOW TABLE =========
# ==============================================================================
#  The rewrite must reproduce monetary_policy_labor.R on the full window, where
#  there is no gap and time-aware and positional builds coincide. If it does
#  not, STOP: the excluded-window numbers cannot be trusted either.

ref_path <- file.path(TAB, "tab_signflip.csv")
if (file.exists(ref_path)) {
  ref <- read.csv(ref_path)
  chk <- merge(ref, full[, c("h", "b_raw", "se_raw", "b_sur", "se_sur")],
               by = "h", suffixes = c("_ref", "_new"))
  chk$d_b_raw  <- abs(chk$b_raw_ref  - chk$b_raw_new)
  chk$d_se_raw <- abs(chk$se_raw_ref - chk$se_raw_new)
  chk$d_b_sur  <- abs(chk$b_sur_ref  - chk$b_sur_new)
  chk$d_se_sur <- abs(chk$se_sur_ref - chk$se_sur_new)
  worst <- max(chk[, c("d_b_raw", "d_se_raw", "d_b_sur", "d_se_sur")])

  cat("\n----- SELF-CHECK vs PUBLISHED tab_signflip.csv (full window) -----\n")
  cat(sprintf("largest absolute discrepancy : %.3e\n", worst))
  # ⚠️ THIS CHECK IS EXPECTED TO FAIL AT ABOUT 0.011, AND THAT IS CORRECT.
  # Resolved August 11 by Dalis_Abdallah_LPReconciliation.R. Two causes were
  # separated:
  #   0.53  the panel filter. FIXED: this script now uses month3_emplvl > 0.
  #   0.011 seam splicing in the PUBLISHED table. The filter removes 32
  #         scattered rows from counties that otherwise have all 72 quarters,
  #         creating interior holes, and the published positional lead/lag
  #         splices across them. Time-aware does not. The published numbers
  #         carry that contamination; it moves coefficients by at most 0.011
  #         and leaves the SE ratio range at 6.3 to 12.0 either way.
  # So a residual near 0.011 means this script is RIGHT and the published table
  # is very slightly contaminated. A residual near 0.5 means the filter has
  # been changed back and must be restored. Do not "fix" this by loosening the
  # threshold without knowing which of the two you are looking at.
  if (worst < 1e-6) {
    cat(" PASS, exact. Unexpected: the published table splices across 32\n")
    cat(" interior holes, so a residual near 0.011 is the correct outcome.\n")
    cat(" An exact match means the time-aware build is not being used.\n")
  } else if (worst < 0.05) {
    cat(sprintf(" PASS, expected residual (%.4f). This is the known seam\n", worst))
    cat(" contamination in the published table, not an error here. See the\n")
    cat(" note above and PIPELINE_RECONCILIATION.md.\n")
  } else {
    cat(" *** FAIL ***\n")
    cat(" The rewrite does NOT reproduce the published table. Do not use the\n")
    cat(" excluded-window numbers. Diagnose before going further.\n")
    print(round(chk[, c("h", "d_b_raw", "d_se_raw", "d_b_sur", "d_se_sur")], 8),
          row.names = FALSE)
  }
} else {
  cat("\n----- SELF-CHECK SKIPPED: tables/tab_signflip.csv not found -----\n")
}


# ==============================================================================
# === SECTION 3.0 — DOES THE TITLE CLAIM SURVIVE BOTH WINDOWS? =================
# ==============================================================================

cmp <- data.frame(
  quantity = c("raw positive", "raw significant",
               "identified negative", "identified significant",
               "SE ratio min", "SE ratio max"),
  full = c(sum(full$b_raw > 0), sum(full$p_raw < 0.05),
           sum(full$b_sur < 0), sum(full$p_sur < 0.05),
           round(min(full$se_ratio), 2), round(max(full$se_ratio), 2)),
  excl = c(sum(excl$b_raw > 0), sum(excl$p_raw < 0.05),
           sum(excl$b_sur < 0), sum(excl$p_sur < 0.05),
           round(min(excl$se_ratio), 2), round(max(excl$se_ratio), 2))
)

cat("\n----- WINDOW COMPARISON -----\n")
print(cmp, row.names = FALSE)
write.csv(cmp, file.path(TAB, "tab_signflip_window_comparison.csv"),
          row.names = FALSE)

cat("\n----- WHAT TO DO WITH THIS -----\n")
cat(" The abstract says standard errors widen 'by a factor of 6 to 12'. That\n")
cat(" range is the FULL window. If the excluded window gives a different range,\n")
cat(" the abstract must either quote both or say which window it refers to.\n")
cat(" Do not quietly keep the more impressive one.\n")
cat("\n If the identified estimates stop being uniformly negative, or the raw\n")
cat(" count of significant horizons moves, sections 5.6 and the Conclusion need\n")
cat(" rewriting, not just the abstract.\n")

cat("\n----- DONE -----\n")

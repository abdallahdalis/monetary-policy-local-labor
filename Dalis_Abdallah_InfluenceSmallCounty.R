# ==============================================================================
#  Spurious Precision: Why Shift-Share Designs Overstate Monetary Policy
#                      Effects on Local Employment
#  Influence check — does the precision gap rest on small counties?
#  Author     : Abdallah Dalis
#  Institution: DePaul University
#
#  Built August 12, 2026. Closes the influence-check item carried in
#  HANDOFF_2026-08-11_evening.md and TASKS.md.
#
#  ⚠️ WHAT THIS SCRIPT IS *NOT* CHECKING.
#
#  The item as originally written asked about 32 county-quarters dropped by the
#  panel filter, on the theory that `month3_emplvl > 0` and `is.finite(ln_emp)`
#  were two defensible screens giving a 6.3-12.0 vs 4.2-9.6 answer. That premise
#  is FALSE and was retired on August 12. `is.finite(ln_emp)` screens nothing:
#  this panel codes ln_emp as 0 wherever employment is 0, so every row passes it.
#  The 32 rows are zero-employment county-quarters sitting nine log points below
#  any real county, and 4.2-9.6 is a contaminated estimate, not a robustness
#  range. See Dalis_Abdallah_LocalProjections_BothWindows.R header note (2).
#
#  THE REAL QUESTION, which this script answers. The published screen keeps
#  counties down to roughly 25 employees. Outcome volatility falls monotonically
#  in county size (sd of the h=0 outcome is 9.05 in the smallest size decile
#  against 2.44 in the largest), so a reader is entitled to ask whether the
#  headline precision gap is produced by a minority of very small, very noisy
#  counties. This refits the local projections after dropping the smallest 1, 2
#  and 3 size deciles and reports what happens to the SE ratio.
#
#  Method mirrors Dalis_Abdallah_LocalProjections_BothWindows.R exactly: same
#  panel build, same time-aware outcome, same two-way within transform, same
#  quarter clustering. Exposure is standardized ONCE on the full joined panel
#  and then subsetted, so the regressor is on a common scale across samples.
#
#  Input : qcew_panel_all_years.dta, FEDFUNDS.csv, cbp_exposure_2002.dta,
#          bauer_swanson_mps.xlsx, tables/tab_signflip_zlb-full.csv (self-check)
#  Output: tables/tab_influence_smallcounty.csv
# ==============================================================================

rm(list = ls())

suppressMessages({
  library(haven); library(readxl); library(dplyr); library(sandwich)
})
select <- dplyr::select; filter <- dplyr::filter

PROJ <- "."
TAB  <- file.path(PROJ, "tables")
dir.create(TAB, showWarnings = FALSE, recursive = TRUE)
H <- 12

# ==============================================================================
# === SECTION 1.0 — PANEL (identical to the both-windows script) ===============
# ==============================================================================

DATA_CANDIDATES <- c("../Research_Monetary_Incidence/data",
                     "~/Documents/Research_Monetary_Incidence/data", "data")
DATA <- NA_character_
for (p in DATA_CANDIDATES)
  if (file.exists(file.path(path.expand(p), "qcew_panel_all_years.dta"))) {
    DATA <- path.expand(p); break
  }
if (is.na(DATA)) stop("Panel not found. Working directory: ", getwd())

# ⚠️ month3_emplvl is RETAINED here. The both-windows script drops it after
#    filtering; this script needs it to measure county size.
panel <- read_dta(file.path(DATA, "qcew_panel_all_years.dta")) %>%
  mutate(area_fips = sprintf("%05s", as.character(area_fips)),
         year = as.integer(year), qtr = as.integer(qtr),
         qidx = (year - 2002L) * 4L + qtr) %>%
  filter(year >= 2002, year <= 2019, month3_emplvl > 0) %>%
  select(area_fips, year, qtr, qidx, ln_emp, month3_emplvl)

#  Repointed August 12, 2026 to the REBUILT measure; see
#  EXPOSURE_DEFECT_2026-08-12.md and causal-did/Dalis_Abdallah_RebuildExposure.R.
#  NOTE the self-check reference, tables/tab_signflip_zlb-full.csv, was itself
#  regenerated on the rebuilt measure by Dalis_Abdallah_LocalProjections_BothWindows.R.
#  Both sides are therefore on the same measure and the check should PASS. If it
#  fails, the two builds have diverged — diagnose, do not loosen the tolerance.
#  The size deciles shift under the rebuild, because the joined county count went
#  from 2,889 to 3,171. Decile membership is not comparable to the earlier run.
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
         exp_sens = as.numeric(exp_sens_2002)) %>%
  select(area_fips, exp_sens)

ffr_q <- read.csv(file.path(DATA, "FEDFUNDS.csv"), stringsAsFactors = FALSE) %>%
  mutate(date = as.Date(observation_date),
         year = as.integer(format(date, "%Y")),
         qtr  = (as.integer(format(date, "%m")) - 1) %/% 3 + 1) %>%
  filter(year >= 2002, year <= 2019) %>%
  group_by(year, qtr) %>%
  summarise(ffr = mean(FEDFUNDS, na.rm = TRUE), .groups = "drop") %>%
  arrange(year, qtr) %>% mutate(dffr = c(NA, diff(ffr))) %>% select(year, qtr, dffr)

bs_file <- file.path(DATA, "bauer_swanson_mps.xlsx")
if (!file.exists(bs_file)) bs_file <- file.path(PROJ, "data", "bauer_swanson_mps.xlsx")
bsq <- read_xlsx(bs_file, sheet = "Monthly (update 2023)") %>%
  transmute(year = as.integer(Year), month = as.integer(Month),
            MPS_ORTH = as.numeric(MPS_ORTH)) %>%
  mutate(qtr = (month - 1) %/% 3 + 1) %>%
  group_by(year, qtr) %>%
  summarise(MPS_ORTH = sum(MPS_ORTH, na.rm = TRUE), .groups = "drop")

P <- panel %>%
  inner_join(cbp02, by = "area_fips") %>%
  left_join(ffr_q, by = c("year", "qtr")) %>%
  left_join(bsq,   by = c("year", "qtr")) %>%
  mutate(expz = (exp_sens - mean(exp_sens, na.rm = TRUE)) /
                 sd(exp_sens, na.rm = TRUE)) %>%
  arrange(area_fips, qidx)

# --- County size decile, on MEDIAN employment over the county's own quarters ---
size <- P %>% group_by(area_fips) %>%
  summarise(med_emp = median(month3_emplvl, na.rm = TRUE), .groups = "drop") %>%
  mutate(decile = ntile(med_emp, 10))
P <- P %>% left_join(size, by = "area_fips")

cat(sprintf("\ncounties : %d\nrows     : %s\n",
            n_distinct(P$area_fips), format(nrow(P), big.mark = ",")))
cat("\n--- county size deciles ---\n")
print(size %>% group_by(decile) %>%
        summarise(counties = n(), med_emp = median(med_emp), .groups = "drop"),
      n = 10)


# ==============================================================================
# === SECTION 2.0 — ESTIMATION (mirrors the both-windows script) ===============
# ==============================================================================

emp_lookup <- P %>% select(area_fips, qidx, ln_emp)

demean2 <- function(df, v) {
  df %>%
    group_by(area_fips) %>% mutate(ci = mean(.data[[v]], na.rm = TRUE)) %>%
    group_by(qidx)      %>% mutate(ti = mean(.data[[v]], na.rm = TRUE)) %>%
    ungroup() %>%
    mutate("{v}_w" := .data[[v]] - ci - ti + mean(.data[[v]], na.rm = TRUE)) %>%
    select(-ci, -ti)
}

lp_interaction <- function(base, shockvar) {
  out <- data.frame()
  for (h in 0:H) {
    d <- base %>%
      mutate(qidx_h = qidx + h, qidx_b = qidx - 1L) %>%
      left_join(emp_lookup %>% rename(qidx_h = qidx, ln_emp_h = ln_emp),
                by = c("area_fips", "qidx_h")) %>%
      left_join(emp_lookup %>% rename(qidx_b = qidx, ln_emp_b = ln_emp),
                by = c("area_fips", "qidx_b")) %>%
      mutate(yh = 100 * (ln_emp_h - ln_emp_b), sx = .data[[shockvar]] * expz) %>%
      filter(is.finite(yh), is.finite(sx))
    d <- demean2(d, "yh"); d <- demean2(d, "sx")
    m <- lm(yh_w ~ sx_w - 1, data = d)
    V <- sandwich::vcovCL(m, cluster = d$qidx)
    out <- rbind(out, data.frame(h = h, b = unname(coef(m)["sx_w"]),
                                 se = sqrt(V["sx_w", "sx_w"]), n = nrow(d)))
  }
  out
}

# ⚠️ The outcome is built on the FULL emp_lookup and only then subsetted, so
#    dropping small counties never creates an interior hole in a kept county.
run_sample <- function(drop_below, tag) {
  base <- P %>% filter(decile > drop_below)
  raw <- lp_interaction(base, "dffr")
  sur <- lp_interaction(base, "MPS_ORTH")
  res <- merge(raw, sur, by = "h", suffixes = c("_raw", "_sur"))
  res$se_ratio <- res$se_sur / res$se_raw
  res$p_raw    <- 2 * pnorm(-abs(res$b_raw / res$se_raw))
  res$p_sur    <- 2 * pnorm(-abs(res$b_sur / res$se_sur))
  res$sample   <- tag
  res$counties <- n_distinct(base$area_fips)
  cat(sprintf("\n%-22s counties %4d  b(h=0) %7.4f  SE ratio %.1f to %.1f  raw sig %2d/13  ident sig %2d/13\n",
              tag, res$counties[1], res$b_raw[res$h == 0],
              min(res$se_ratio), max(res$se_ratio),
              sum(res$p_raw < 0.05), sum(res$p_sur < 0.05)))
  res
}

cat("\n----- INFLUENCE CHECK: DROPPING THE SMALLEST COUNTY DECILES -----\n")
res <- rbind(run_sample(0, "full (published)"),
             run_sample(1, "drop smallest 1"),
             run_sample(2, "drop smallest 2"),
             run_sample(3, "drop smallest 3"))

write.csv(res, file.path(TAB, "tab_influence_smallcounty.csv"), row.names = FALSE)


# ==============================================================================
# === SECTION 3.0 — SELF-CHECK, AND THE VERDICT ================================
# ==============================================================================
#  The full-sample arm must reproduce the published table. If it does not, the
#  dropped-decile arms mean nothing.

ref <- read.csv(file.path(TAB, "tab_signflip_zlb-full.csv"))
f   <- res[res$sample == "full (published)", ]
chk <- merge(ref, f[, c("h", "b_raw", "se_raw", "b_sur", "se_sur")],
             by = "h", suffixes = c("_ref", "_new"))
worst <- max(abs(c(chk$b_raw_ref - chk$b_raw_new, chk$se_raw_ref - chk$se_raw_new,
                   chk$b_sur_ref - chk$b_sur_new, chk$se_sur_ref - chk$se_sur_new)))
cat(sprintf("\nSELF-CHECK vs tab_signflip_zlb-full.csv : worst absolute gap %.2e\n", worst))
if (worst > 1e-6) stop("Full-sample arm does not reproduce the published table. Stop.")
cat("SELF-CHECK OK — dropped-decile arms are trustworthy.\n")

cat("\n----- SE RATIO BY SAMPLE AND HORIZON -----\n")
wide <- reshape(res[, c("h", "sample", "se_ratio")], idvar = "h",
                timevar = "sample", direction = "wide")
print(round(wide, 2), row.names = FALSE)

cat("\n----- VERDICT -----\n")
for (s in unique(res$sample)) {
  r <- res[res$sample == s, ]
  cat(sprintf("  %-22s SE ratio %4.1f to %4.1f   b(h=0) %7.4f   identified significant %d/13\n",
              s, min(r$se_ratio), max(r$se_ratio), r$b_raw[r$h == 0],
              sum(r$p_sur < 0.05)))
}
cat("\nThe headline claim is an ORDER-OF-MAGNITUDE precision gap. It is robust if\n")
cat("the gap stays far above 1 in every arm, not if the range is numerically\n")
cat("identical. Report the widest defensible weakening, not the best number.\n")

cat("\n----- DONE -----\n")

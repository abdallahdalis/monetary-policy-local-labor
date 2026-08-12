# ==============================================================================
#  Spurious Precision — LP reconciliation diagnostic
#  Why does the time-aware rewrite disagree with tables/tab_signflip.csv?
#  Author     : Abdallah Dalis
#  Institution: DePaul University
#
#  Built August 11, 2026, after Dalis_Abdallah_LocalProjections_BothWindows.R
#  section 2.1 FAILED its self-check by up to 0.54 in absolute coefficient.
#
#  WHAT IS AT STAKE. The published full-window SE ratios run 6.3 to 12.0 and are
#  quoted in the abstract, Results section 5.6, the Conclusion, and effectively
#  the title. The time-aware rewrite gives 4.2 to 9.6. One of those is wrong.
#
#  HYPOTHESIS. The panel is unbalanced: 2,887 counties x 72 quarters = 207,864,
#  but the joined panel holds 207,672 rows, so 192 county-quarters are missing.
#  On a panel with holes, dplyr::lead() and dplyr::lag() are POSITIONAL and
#  splice across the holes. If that is the cause, the published numbers carry
#  seam contamination of the same kind PIPELINE_RECONCILIATION.md section 4d
#  documented in the DiD, arising from pre-existing gaps rather than from the
#  2009-2012 exclusion.
#
#  THIS SCRIPT DOES NOT ASSUME THAT. It runs three arms on the same data and
#  lets the match decide. Arms differ in ONE thing at a time.
#
#    A  causal-did panel build   + POSITIONAL lead/lag   (original operator)
#    B  causal-did panel build   + TIME-AWARE join       (the rewrite)
#    C  original-style panel     + POSITIONAL lead/lag   (faithful replication)
#
#  READING THE VERDICT
#    C matches published, A does not  -> the PANEL BUILD differs, not the operator
#    A matches published, B does not  -> the OPERATOR is the difference, and the
#                                        published numbers are seam-contaminated
#    nothing matches                  -> something else; do not guess, extend this
#
#  Output: tables/tab_lp_reconciliation.csv
# ==============================================================================

rm(list = ls())

suppressMessages({
  library(haven); library(dplyr); library(sandwich)
})
select <- dplyr::select; filter <- dplyr::filter
lag    <- dplyr::lag;    lead   <- dplyr::lead

PROJ <- "."; TAB <- file.path(PROJ, "tables")
H <- 12

DATA_CANDIDATES <- c("../Research_Monetary_Incidence/data",
                     "~/Documents/Research_Monetary_Incidence/data", "data")
DATA <- NA_character_
for (p in DATA_CANDIDATES)
  if (file.exists(file.path(path.expand(p), "qcew_panel_all_years.dta"))) {
    DATA <- path.expand(p); break
  }
if (is.na(DATA)) stop("Panel not found. wd: ", getwd())
cat(sprintf("\ndata dir : %s\n", DATA))

raw    <- read_dta(file.path(DATA, "qcew_panel_all_years.dta"))
cbp_r  <- read_dta(file.path(DATA, "cbp_exposure_2002.dta"))

cat("\n----- COLUMNS IN THE PANEL FILE -----\n")
print(names(raw))


# ==============================================================================
# === SECTION 1.0 — IS THE PANEL BALANCED? =====================================
# ==============================================================================

bal <- raw %>%
  mutate(area_fips = as.character(area_fips),
         year = as.integer(year), qtr = as.integer(qtr)) %>%
  filter(year >= 2002, year <= 2019)

per_county <- bal %>% count(area_fips, name = "n_q")

cat("\n----- PANEL BALANCE (2002-2019, before any join) -----\n")
cat(sprintf("counties                    : %d\n", nrow(per_county)))
cat(sprintf("quarters observed, distinct : %d\n", n_distinct(bal$year * 4 + bal$qtr)))
cat(sprintf("rows if fully balanced      : %s\n",
            format(nrow(per_county) * 72, big.mark = ",")))
cat(sprintf("rows actually present       : %s\n", format(nrow(bal), big.mark = ",")))
cat(sprintf("counties with < 72 quarters : %d\n", sum(per_county$n_q < 72)))
cat("\n distribution of quarters per county:\n")
print(table(per_county$n_q))


# ==============================================================================
# === SECTION 2.0 — SHARED INPUTS ==============================================
# ==============================================================================

ffr_q <- read.csv(file.path(DATA, "FEDFUNDS.csv"), stringsAsFactors = FALSE) %>%
  mutate(date = as.Date(observation_date),
         year = as.integer(format(date, "%Y")),
         qtr  = (as.integer(format(date, "%m")) - 1) %/% 3 + 1) %>%
  filter(year >= 2002, year <= 2019) %>%
  group_by(year, qtr) %>%
  summarise(ffr = mean(FEDFUNDS, na.rm = TRUE), .groups = "drop") %>%
  arrange(year, qtr) %>% mutate(dffr = c(NA, diff(ffr))) %>%
  select(year, qtr, dffr)

bs_file <- file.path(DATA, "bauer_swanson_mps.xlsx")
if (!file.exists(bs_file)) bs_file <- file.path(PROJ, "data", "bauer_swanson_mps.xlsx")
bsq <- readxl::read_xlsx(bs_file, sheet = "Monthly (update 2023)") %>%
  transmute(year = as.integer(Year), month = as.integer(Month),
            MPS_ORTH = as.numeric(MPS_ORTH)) %>%
  mutate(qtr = (month - 1) %/% 3 + 1) %>%
  group_by(year, qtr) %>%
  summarise(MPS_ORTH = sum(MPS_ORTH, na.rm = TRUE), .groups = "drop")

demean2 <- function(df, v) {
  df %>%
    group_by(area_fips) %>% mutate(ci = mean(.data[[v]], na.rm = TRUE)) %>%
    group_by(qidx)      %>% mutate(ti = mean(.data[[v]], na.rm = TRUE)) %>%
    ungroup() %>%
    mutate("{v}_w" := .data[[v]] - ci - ti + mean(.data[[v]], na.rm = TRUE)) %>%
    select(-ci, -ti)
}

fit_lp <- function(d) {
  d <- d %>% filter(is.finite(yh), is.finite(sx))
  d <- demean2(d, "yh"); d <- demean2(d, "sx")
  m <- lm(yh_w ~ sx_w - 1, data = d)
  V <- sandwich::vcovCL(m, cluster = d$qidx)
  c(b = unname(coef(m)["sx_w"]), se = sqrt(V["sx_w", "sx_w"]), n = nrow(d))
}


# ==============================================================================
# === SECTION 3.0 — THREE PANEL / OPERATOR ARMS ================================
# ==============================================================================

# --- Panel build 1: as used by the causal-did scripts ------------------------
panel_cd <- raw %>%
  mutate(area_fips = as.character(area_fips),
         year = as.integer(year), qtr = as.integer(qtr),
         qidx = (year - 2002L) * 4L + qtr) %>%
  filter(year >= 2002, year <= 2019, is.finite(ln_emp)) %>%
  select(area_fips, year, qtr, qidx, ln_emp)

# --- Panel build 2: as used by monetary_policy_labor.R -----------------------
#  sprintf("%05s") padding, and the month3_emplvl > 0 filter if that column
#  exists in this file.
panel_orig <- raw %>%
  mutate(area_fips = sprintf("%05s", as.character(area_fips)),
         year = as.integer(year), qtr = as.integer(qtr),
         qidx = (year - 2002L) * 4L + qtr) %>%
  filter(year >= 2002, year <= 2019)
if ("month3_emplvl" %in% names(raw)) {
  panel_orig <- panel_orig %>% filter(month3_emplvl > 0)
  cat("\n[arm C] applied month3_emplvl > 0 filter\n")
} else {
  cat("\n[arm C] month3_emplvl not in file; filter skipped\n")
}
panel_orig <- panel_orig %>% select(area_fips, year, qtr, qidx, ln_emp)

attach_shocks <- function(pn) {
  cb <- cbp_r %>%
    mutate(area_fips = sprintf("%05s", as.character(area_fips)),
           exp_sens  = as.numeric(exp_sens_2002)) %>%
    select(area_fips, exp_sens)
  pn %>%
    mutate(area_fips = sprintf("%05s", area_fips)) %>%
    inner_join(cb,    by = "area_fips") %>%
    left_join(ffr_q,  by = c("year", "qtr")) %>%
    left_join(bsq,    by = c("year", "qtr")) %>%
    mutate(expz = (exp_sens - mean(exp_sens, na.rm = TRUE)) /
                   sd(exp_sens, na.rm = TRUE)) %>%
    arrange(area_fips, qidx)
}

P_cd   <- attach_shocks(panel_cd)
P_orig <- attach_shocks(panel_orig)

cat(sprintf("\narm A/B panel rows : %s (%d counties)\n",
            format(nrow(P_cd),   big.mark = ","), n_distinct(P_cd$area_fips)))
cat(sprintf("arm C   panel rows : %s (%d counties)\n",
            format(nrow(P_orig), big.mark = ","), n_distinct(P_orig$area_fips)))

# --- Operator 1: POSITIONAL, exactly as monetary_policy_labor.R --------------
lp_positional <- function(P, shockvar) {
  out <- data.frame()
  for (h in 0:H) {
    d <- P %>% group_by(area_fips) %>%
      mutate(yh = 100 * (dplyr::lead(ln_emp, h) - dplyr::lag(ln_emp, 1)),
             sx = .data[[shockvar]] * expz) %>% ungroup()
    r <- fit_lp(d)
    out <- rbind(out, data.frame(h = h, b = r["b"], se = r["se"], n = r["n"]))
  }
  out
}

# --- Operator 2: TIME-AWARE join ---------------------------------------------
lp_timeaware <- function(P, shockvar) {
  look <- P %>% select(area_fips, qidx, ln_emp)
  out <- data.frame()
  for (h in 0:H) {
    d <- P %>%
      mutate(qidx_h = qidx + h, qidx_b = qidx - 1L) %>%
      left_join(look %>% rename(qidx_h = qidx, ln_emp_h = ln_emp),
                by = c("area_fips", "qidx_h")) %>%
      left_join(look %>% rename(qidx_b = qidx, ln_emp_b = ln_emp),
                by = c("area_fips", "qidx_b")) %>%
      mutate(yh = 100 * (ln_emp_h - ln_emp_b),
             sx = .data[[shockvar]] * expz)
    r <- fit_lp(d)
    out <- rbind(out, data.frame(h = h, b = r["b"], se = r["se"], n = r["n"]))
  }
  out
}

arm <- function(P, op, label) {
  rw <- op(P, "dffr"); sr <- op(P, "MPS_ORTH")
  data.frame(arm = label, h = rw$h,
             b_raw = rw$b, se_raw = rw$se, n_raw = rw$n,
             b_sur = sr$b, se_sur = sr$se)
}

A <- arm(P_cd,   lp_positional, "A cd-panel + positional")
B <- arm(P_cd,   lp_timeaware,  "B cd-panel + time-aware")
C <- arm(P_orig, lp_positional, "C orig-panel + positional")


# ==============================================================================
# === SECTION 4.0 — WHICH ARM MATCHES THE PUBLISHED TABLE? =====================
# ==============================================================================

ref <- read.csv(file.path(TAB, "tab_signflip.csv"))

score <- function(X) {
  m <- merge(ref, X, by = "h", suffixes = c("_ref", "_arm"))
  max(abs(c(m$b_raw_ref - m$b_raw_arm, m$se_raw_ref - m$se_raw_arm,
            m$b_sur_ref - m$b_sur_arm, m$se_sur_ref - m$se_sur_arm)))
}

verdict <- data.frame(
  arm       = c(A$arm[1], B$arm[1], C$arm[1]),
  max_abs_diff_vs_published = c(score(A), score(B), score(C))
)

cat("\n----- WHICH ARM REPRODUCES tables/tab_signflip.csv? -----\n")
print(verdict, row.names = FALSE)

cat("\n----- SE RATIO RANGE BY ARM -----\n")
for (X in list(A, B, C)) {
  r <- X$se_sur / X$se_raw
  cat(sprintf(" %-28s : %.2f to %.2f\n", X$arm[1], min(r), max(r)))
}
r_ref <- ref$se_sur / ref$se_raw
cat(sprintf(" %-28s : %.2f to %.2f\n", "published tab_signflip", min(r_ref), max(r_ref)))

write.csv(rbind(A, B, C), file.path(TAB, "tab_lp_reconciliation.csv"),
          row.names = FALSE)

cat("\n----- HOW TO READ THIS -----\n")
cat(" A matches, B does not -> the OPERATOR is the difference. The published\n")
cat("   local projections splice across gaps in an unbalanced panel, and the\n")
cat("   time-aware numbers (arm B) are the correct ones. The abstract's\n")
cat("   '6 to 12' must be replaced by arm B's range, and section 5.6, the\n")
cat("   Conclusion and the Plain-Language Summary all move with it.\n")
cat(" C matches, A does not -> the PANEL BUILD is the difference, not the\n")
cat("   operator. Diagnose the panel filter before touching any prose.\n")
cat(" nothing matches       -> extend this script. Do NOT pick the arm whose\n")
cat("   numbers are most convenient.\n")

cat("\n----- DONE -----\n")

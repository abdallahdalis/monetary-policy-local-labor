# ==============================================================================
#  Spurious Precision — randomization inference on the shift-share estimator
#  Author     : Abdallah Dalis
#  DePaul University
#
#  THE QUESTION
#    How much of this design's precision is real? Two prior scripts established
#    that (a) positional lag construction cuts clustered SEs 40 to 45 percent,
#    and (b) the serial-correlation explanation for that is REFUTED. Rather
#    than keep hunting for an analytic mechanism, this script answers the
#    question the paper actually asks, without needing one.
#
#  THE LOGIC
#    Under the null that exposure does not matter, a county's exposure share
#    could just as well have belonged to any other county. So: shuffle the
#    county-to-exposure mapping, re-estimate, and repeat. The spread of the
#    resulting placebo estimates IS the sampling distribution of the estimator
#    under the null, with no assumption about the error structure.
#
#    Compare that spread to the analytic standard error:
#      sd(null) ~= analytic SE  ->  the reported SEs are honest.
#      sd(null) >  analytic SE  ->  the reported SEs are too small, and the
#                                   ratio is exactly how much precision the
#                                   design claims but has not earned.
#
#  WHAT IS HELD FIXED
#    The national dffr series, each county's full employment path, the panel
#    structure, and the marginal distribution of exposure. Only the link
#    between a county's exposure and its own outcome is broken. Exposure is
#    permuted at the COUNTY level, one draw per county applied to all of its
#    quarters. Permuting row by row would shred the panel and manufacture a
#    null distribution that is far too tight.
#
#  RUN UNDER BOTH LAG CONSTRUCTIONS
#    This answers the pipeline question at the same time. If the positional
#    build's null distribution is no tighter than the time-aware build's, then
#    its smaller analytic SEs were never real precision to begin with.
#
#  RUNTIME
#    N_REPS fits per construction, roughly 0.3 to 1 second each. The default
#    200 is enough to read the spread; 1,000 is enough to quote a p-value.
#      N_REPS=1000 Rscript Dalis_Abdallah_RandomizationInference.R
#
#  HOW TO RUN — RSTUDIO
#    Session > Set Working Directory > To Source File Location, then Source.
# ==============================================================================

rm(list = ls())

# ---- Packages ----------------------------------------------------------------
suppressMessages({
  library(haven)
  library(dplyr)
  library(tidyr)
  library(fixest)
})
select <- dplyr::select; filter <- dplyr::filter
lag    <- dplyr::lag;    lead   <- dplyr::lead
setFixest_notes(FALSE)

N_REPS    <- as.integer(Sys.getenv("N_REPS", "200"))
SEED      <- 20260811
ZLB_YEARS <- 2009:2012

# --- EXCLUDE_ZLB switch, added August 11, 2026 -------------------------------
#  This script previously HARDCODED the 2009-2012 exclusion below, so the
#  documented command `EXCLUDE_ZLB=FALSE Rscript ...` set an environment
#  variable nothing read. It ran, printed, and wrote output that looked correct
#  while silently returning the EXCLUDED-window result. Same switch, spelling
#  and default as Dalis_Abdallah_CausalDiD_Analysis.R line 100, so the two
#  scripts now agree on what window they are estimating.
EXCLUDE_ZLB <- toupper(Sys.getenv("EXCLUDE_ZLB", "TRUE")) %in% c("TRUE", "T", "1")
CONFIG_TAG  <- ifelse(EXCLUDE_ZLB, "zlb-excl", "zlb-full")

OUT       <- "output"
dir.create(file.path(OUT, "tables"),  showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(OUT, "figures"), showWarnings = FALSE, recursive = TRUE)

set.seed(SEED)
cat(sprintf("\nreps per construction : %d\nseed : %d\n", N_REPS, SEED))


# ==============================================================================
# === SECTION 1.0 — BUILD THE PANEL BOTH WAYS ==================================
# ==============================================================================
#  Identical to Dalis_Abdallah_PrecisionMechanism.R section 1, which self-checks
#  against the analysis script. Kept in sync by hand; if the analysis script's
#  build changes, change it here too.

DATA_CANDIDATES <- c("../../../Research_Monetary_Incidence/data",
                     "../../Research_Monetary_Incidence/data",
                     "~/Documents/Research_Monetary_Incidence/data",
                     "../data", "data")
DATA <- NA_character_
for (p in DATA_CANDIDATES)
  if (file.exists(file.path(path.expand(p), "qcew_panel_all_years.dta"))) {
    DATA <- path.expand(p); break
  }
if (is.na(DATA)) stop("Panel not found. Working directory: ", getwd())

panel <- read_dta(file.path(DATA, "qcew_panel_all_years.dta")) %>%
  mutate(area_fips = as.character(area_fips),
         county_id = as.character(county_id),
         year      = as.integer(year),
         qtr       = as.integer(qtr),
         qidx      = (year - 2002L) * 4L + qtr) %>%
  select(-any_of("yq"))

ffr <- read.csv(file.path(DATA, "FEDFUNDS.csv"), stringsAsFactors = FALSE) %>%
  mutate(date = as.Date(observation_date),
         year = as.integer(format(date, "%Y")),
         qtr  = (as.integer(format(date, "%m")) - 1) %/% 3 + 1) %>%
  filter(year >= 2001, year <= 2019) %>%
  group_by(year, qtr) %>%
  summarise(fedfunds_q = mean(FEDFUNDS, na.rm = TRUE), .groups = "drop") %>%
  arrange(year, qtr) %>%
  mutate(dffr = fedfunds_q - lag(fedfunds_q, 1))
for (k in 1:4) {
  ffr[[paste0("dffr_lag",  k)]] <- lag(ffr$dffr,  k)
  ffr[[paste0("dffr_lead", k)]] <- lead(ffr$dffr, k)
}
ffr_keep <- ffr %>% filter(year >= 2002) %>%
  select(year, qtr, dffr, starts_with("dffr_lag"), starts_with("dffr_lead"))

#  Repointed August 12, 2026 to the REBUILT measure; see
#  EXPOSURE_DEFECT_2026-08-12.md and Dalis_Abdallah_RebuildExposure.R. The
#  rebuilt file lives in this project's own data/, not where DATA resolves to,
#  so it is resolved separately.
EXPO_CANDIDATES <- c(file.path(DATA, "cbp_exposure_2002_rebuilt.dta"),
                     "../data/cbp_exposure_2002_rebuilt.dta",
                     "data/cbp_exposure_2002_rebuilt.dta",
                     "~/Documents/projects/monetary-policy-local-labor/data/cbp_exposure_2002_rebuilt.dta")
EXPO <- NA_character_
for (p in EXPO_CANDIDATES)
  if (file.exists(path.expand(p))) { EXPO <- path.expand(p); break }
if (is.na(EXPO)) stop(
  "Rebuilt exposure file not found. Run Dalis_Abdallah_RebuildExposure.R from ",
  "the project root first. Looked in: ", paste(EXPO_CANDIDATES, collapse = ", "))
cat(sprintf("exposure : %s\n", EXPO))

cbp02 <- read_dta(EXPO) %>%
  mutate(area_fips = as.character(area_fips),
         exp_sens  = as.numeric(exp_sens_2002)) %>%
  select(area_fips, exp_sens)

build_base <- function(positional) {
  d <- panel %>%
    inner_join(ffr_keep, by = c("year", "qtr")) %>%
    inner_join(cbp02,    by = "area_fips") %>%
    filter(if (EXCLUDE_ZLB) !(year %in% ZLB_YEARS) else TRUE) %>%
    mutate(state = substr(area_fips, 1, 2)) %>%   # FIPS state code, for
    arrange(county_id, qidx)                      # the within-state scheme
  if (positional) {
    d <- d %>% group_by(county_id) %>%
      mutate(dffr_lag1  = lag(dffr, 1),  dffr_lag2  = lag(dffr, 2),
             dffr_lag3  = lag(dffr, 3),  dffr_lag4  = lag(dffr, 4),
             dffr_lead1 = lead(dffr, 1), dffr_lead2 = lead(dffr, 2),
             dffr_lead3 = lead(dffr, 3), dffr_lead4 = lead(dffr, 4)) %>%
      ungroup()
  }
  d
}

# Interactions are rebuilt from whatever exposure vector is supplied, so the
# same function serves the true fit and every permutation.
add_inters <- function(d, expvec) {
  d$exp_use <- expvec
  d$inter   <- d$dffr * d$exp_use
  for (k in 1:4) {
    d[[paste0("inter_lead", k)]] <- d[[paste0("dffr_lead", k)]] * d$exp_use
  }
  d
}

FML   <- ln_emp ~ inter + inter_lead1 + inter_lead2 + inter_lead3 + inter_lead4 |
  county_id + qidx
TERMS <- c("inter", paste0("inter_lead", 1:4))


# ==============================================================================
# === SECTION 2.0 — TRUE ESTIMATES AND ANALYTIC SEs ============================
# ==============================================================================

bases <- list(time = build_base(FALSE), posn = build_base(TRUE))
truth <- list()

cat("\n----- TRUE ESTIMATES -----\n")
for (nm in names(bases)) {
  d <- add_inters(bases[[nm]], bases[[nm]]$exp_sens)
  m <- feols(FML, cluster = ~county_id, data = d)
  truth[[nm]] <- data.frame(term = TERMS,
                            b  = coef(m)[TERMS],
                            se = sqrt(diag(vcov(m, vcov = ~county_id)))[TERMS],
                            row.names = NULL)
  cat(sprintf("\n%s construction:\n", nm))
  print(round(truth[[nm]][, c("b", "se")], 5))
}


# ==============================================================================
# === SECTION 3.0 — PERMUTE EXPOSURE ACROSS COUNTIES ===========================
# ==============================================================================

#  TWO SCHEMES, and the difference between them is the whole point.
#
#    "free"  — shuffle exposure across all counties. Maximally destroys
#              structure, including the GEOGRAPHIC concentration of
#              manufacturing and construction. Real shocks hit spatially
#              correlated blocks of counties; this null does not. It is
#              therefore too tight, plausibly for the same reason the
#              analytic SE is, which is why the Aug 11 free-permutation
#              result (ratio ~1) could not clear the design.
#
#    "state" — shuffle exposure only WITHIN a FIPS state. Each state keeps
#              its own exposure distribution, so the coarse geography of
#              the manufacturing belt survives the permutation. If spatial
#              correlation in exposure is what conventional SEs miss, this
#              null is WIDER than the free one, and wider than the analytic
#              SE. That is the finding that would support the paper's title.
#
#  READ THE COMPARISON, NOT EITHER NUMBER ALONE. sd(state) > sd(free) is
#  evidence that free permutation was throwing away real structure.

permute_once <- function(base, scheme) {
  key <- base %>% distinct(county_id, state, exp_sens)
  key$exp_perm <- if (scheme == "state") {
    key %>% group_by(state) %>%
      mutate(p = sample(exp_sens)) %>% ungroup() %>% pull(p)
  } else {
    sample(key$exp_sens)
  }
  ev <- key$exp_perm[match(base$county_id, key$county_id)]
  d  <- add_inters(base, ev)
  m  <- feols(FML, data = d)                        # SEs not needed here
  coef(m)[TERMS]
}

grid <- expand.grid(construction = names(bases),
                    scheme       = c("free", "state"),
                    stringsAsFactors = FALSE)

null_draws <- list()
for (g in seq_len(nrow(grid))) {
  nm  <- grid$construction[g]; sc <- grid$scheme[g]
  tag <- paste(nm, sc, sep = "_")
  cat(sprintf("\n----- PERMUTING: %s construction, %s scheme -----\n", nm, sc))
  t0  <- Sys.time()
  out <- matrix(NA_real_, nrow = N_REPS, ncol = length(TERMS),
                dimnames = list(NULL, TERMS))
  for (r in seq_len(N_REPS)) {
    out[r, ] <- tryCatch(permute_once(bases[[nm]], sc),
                         error = function(e) rep(NA_real_, length(TERMS)))
    if (r %% 50 == 0) cat(sprintf("  %d/%d\n", r, N_REPS))
  }
  null_draws[[tag]] <- out
  cat(sprintf("  done in %.1f min | failed reps: %d\n",
              as.numeric(difftime(Sys.time(), t0, units = "mins")),
              sum(is.na(out[, 1]))))
}


# ==============================================================================
# === SECTION 4.0 — THE VERDICT ================================================
# ==============================================================================
#  sd(null) is the honest standard error. The ratio to the analytic SE is how
#  much precision the design claims but has not earned.

res <- bind_rows(lapply(seq_len(nrow(grid)), function(g) {
  nm <- grid$construction[g]; sc <- grid$scheme[g]
  nd <- null_draws[[paste(nm, sc, sep = "_")]]
  tr <- truth[[nm]]
  data.frame(
    construction = nm,
    scheme       = sc,
    term         = TERMS,
    b_true       = round(tr$b, 5),
    se_analytic  = round(tr$se, 5),
    sd_null      = round(apply(nd, 2, sd, na.rm = TRUE), 5),
    ratio        = round(apply(nd, 2, sd, na.rm = TRUE) / tr$se, 2),
    p_ri         = round(sapply(seq_along(TERMS), function(j)
      mean(abs(nd[, j]) >= abs(tr$b[j]), na.rm = TRUE)), 4),
    #  Added August 12, 2026. A permutation p-value cannot be read without
    #  knowing how many draws produced it: at 200 draws p is quantised to 0.005
    #  and carries a Monte Carlo standard error of about 0.015 near 0.05, which
    #  is wider than the gap between the leads this paper counts and the ones it
    #  does not. The file used to omit the one number that makes its own p
    #  column interpretable. It no longer does.
    n_reps       = N_REPS,
    mcse_p       = round(sqrt(sapply(seq_along(TERMS), function(j)
      mean(abs(nd[, j]) >= abs(tr$b[j]), na.rm = TRUE)) *
      (1 - sapply(seq_along(TERMS), function(j)
        mean(abs(nd[, j]) >= abs(tr$b[j]), na.rm = TRUE))) / N_REPS), 4),
    row.names = NULL)
}))

cat("\n\n----- RANDOMIZATION INFERENCE -----\n")
print(res)
write.csv(res, file.path(OUT, "tables",
                         sprintf("randomization_inference_%s.csv", CONFIG_TAG)),
          row.names = FALSE)

cat("\n",
    "ratio  = sd(null) / analytic SE.\n",
    "  ~1     analytic SEs are honest UNDER THAT SCHEME'S null.\n",
    "  >1     analytic SEs are too small by that factor.\n",
    "p_ri   = share of permutations with |b| at least the true |b|.\n",
    "n_reps = permutations drawn. mcse_p = Monte Carlo standard error of p_ri.\n",
    "         A lead is counted as rejecting only if p_ri < 0.05. Where\n",
    "         p_ri +/- 2*mcse_p straddles 0.05, THE COUNT IS NOT SETTLED and\n",
    "         N_REPS must be raised before the count is quoted.\n")

#  Say so out loud rather than leaving it to whoever reads the csv.
straddle <- res[abs(res$p_ri - 0.05) < 2 * res$mcse_p, ]
if (nrow(straddle) > 0) {
  cat("\n⚠️ TERMS WHOSE REJECT/NOT-REJECT VERDICT IS INSIDE MONTE CARLO NOISE\n")
  cat("   at N_REPS =", N_REPS, ". Raise N_REPS before quoting a count.\n")
  print(straddle[, c("construction", "scheme", "term", "p_ri", "mcse_p")],
        row.names = FALSE)
} else {
  cat(sprintf("\nNo term's verdict sits inside Monte Carlo noise at N_REPS = %d.\n",
              N_REPS))
}

# --- THE DECISIVE COMPARISON -------------------------------------------------
#  Canonical construction only. Does preserving state geography widen the null?

cat("\n\n----- FREE vs WITHIN-STATE PERMUTATION (time-aware) -----\n")
key <- res %>%
  filter(construction == "time") %>%
  select(term, scheme, se_analytic, sd_null, p_ri) %>%
  tidyr::pivot_wider(names_from = scheme,
                     values_from = c(sd_null, p_ri)) %>%
  mutate(widening = round(sd_null_state / sd_null_free, 2),
         ratio_state_vs_analytic = round(sd_null_state / se_analytic, 2))
print(as.data.frame(key))

cat("\n",
    "widening = sd(state null) / sd(free null).\n",
    "  >1 means free permutation was destroying real spatial structure and\n",
    "     understating the null. The larger it is, the more the geographic\n",
    "     concentration of exposure matters for inference.\n",
    "ratio_state_vs_analytic = sd(state null) / analytic SE.\n",
    "  >1 says the reported standard errors understate the true sampling\n",
    "     variation once the geography of exposure is respected.\n",
    "  ~1 or <1 says this design survives the test.\n",
    "\n",
    "*** READ THIS BEFORE ACTING ON THE NUMBERS ABOVE (added Aug 11, 2026) ***\n",
    "  This guidance previously read '>1 IS THE RESULT THAT SUPPORTS THE\n",
    "  PAPER'S TITLE' and '~1 means the title should change.' BOTH WERE\n",
    "  WRONG and are retracted. This script tests the shift-share DiD.\n",
    "  The title's spurious-precision claim does NOT live here. It rests on\n",
    "  the LOCAL PROJECTIONS in ../monetary_policy_labor.R, where identified\n",
    "  Bauer-Swanson SEs run 6 to 12 times wider than raw dFFR SEs\n",
    "  (../tables/tab_signflip.csv). Nothing this script prints can support\n",
    "  or refute the title. See PIPELINE_RECONCILIATION.md sections 4g, 4h.\n",
    "\n",
    "  What this script DOES establish: the pre-trends failure, which is\n",
    "  robust, and the fact that the DiD's own SEs are not pathological.\n",
    "  Also: do NOT quote the within-state p-values as stronger evidence.\n",
    "  The within-state null narrows mechanically, so they are\n",
    "  anti-conservative. See section 4f.\n")


# ==============================================================================
# === SECTION 5.0 — FIGURE =====================================================
# ==============================================================================

#  Canonical construction only. Free and within-state nulls overlaid, so the
#  widening (or its absence) is visible rather than inferred from a table.

png(file.path(OUT, "figures",
              sprintf("fig_randomization_inference_%s.png", CONFIG_TAG)),
    width = 2100, height = 1050, res = 150)
op <- par(mfrow = c(1, 3), mar = c(4, 4, 3, 1))
for (tm in c("inter", "inter_lead3", "inter_lead4")) {
  xf <- null_draws[["time_free"]][,  tm]
  xs <- null_draws[["time_state"]][, tm]
  tb <- truth[["time"]]$b[truth[["time"]]$term == tm]
  rng <- range(c(xf, xs, tb), na.rm = TRUE)
  hf <- hist(xf, breaks = 30, plot = FALSE)
  hs <- hist(xs, breaks = 30, plot = FALSE)
  plot(hf, col = adjustcolor("steelblue", 0.45), border = "white",
       xlim = rng, ylim = c(0, max(hf$counts, hs$counts)),
       main = sprintf("time-aware — %s", tm),
       xlab = "placebo estimate")
  plot(hs, col = adjustcolor("darkorange3", 0.45), border = "white", add = TRUE)
  abline(v = tb, col = "firebrick", lwd = 2)
  abline(v = 0,  lty = 2, col = "grey40")
  legend("topright", bty = "n", cex = 0.8,
         fill = c(adjustcolor("steelblue", 0.45),
                  adjustcolor("darkorange3", 0.45), NA),
         border = c("white", "white", NA), lty = c(NA, NA, 1),
         col = c(NA, NA, "firebrick"), lwd = c(NA, NA, 2),
         legend = c("free permutation", "within-state", "actual estimate"))
}
par(op)
invisible(dev.off())

cat(sprintf("\nwindow : %s\n", ifelse(EXCLUDE_ZLB, "excl 2009-2012", "full 2002-2019")))
cat(sprintf("wrote: %s/tables/randomization_inference_%s.csv\n", OUT, CONFIG_TAG))
cat(sprintf("wrote: %s/figures/fig_randomization_inference_%s.png\n", OUT, CONFIG_TAG))
cat("\n----- DONE -----\n")

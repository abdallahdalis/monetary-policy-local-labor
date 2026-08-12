# ==============================================================================
#  Spurious Precision — WHY do positional lags shrink the standard errors?
#  Author     : Abdallah Dalis
#  DePaul University
#
#  THE QUESTION
#    Dalis_Abdallah_PipelineDiagnostic.R established that switching from
#    time-aware to positional lag construction cuts clustered standard errors
#    by 40 to 45 percent while barely moving the point estimates, turning
#    inter_lead3 from p = 0.21 into p = 0.0002. That is the paper's thesis
#    demonstrated in its own code. It is not publishable until the mechanism
#    is understood.
#
#  THE HYPOTHESIS
#    Cluster-robust SEs exceed iid SEs by a factor that grows with the within
#    cluster serial correlation of x_it * e_it. In this panel dffr is highly
#    serially correlated, so clustering by county inflates SEs substantially.
#    Positional construction splices lags across the 2009-2012 hole, which
#    scrambles the time alignment of the regressor and DESTROYS that serial
#    correlation. The cluster adjustment then has little left to correct, and
#    SEs fall toward iid size -- which is exactly the precision the design has
#    not earned.
#
#  THE TEST
#    If the hypothesis holds, the ratio SE_cluster / SE_iid should be large
#    under time-aware construction and much smaller under positional. The
#    point estimates should be similar either way. Three direct checks follow.
#
#  SELF-CHECK
#    Section 1 prints the placebo coefficients next to the values already on
#    record from the four-config diagnostic. If they do not match, the panel
#    build below has drifted from Dalis_Abdallah_CausalDiD_Analysis.R and
#    nothing downstream should be trusted. Stop and reconcile first.
#
#  HOW TO RUN — RSTUDIO
#    Session > Set Working Directory > To Source File Location, then Source.
#  HOW TO RUN — TERMINAL
#    Rscript Dalis_Abdallah_PrecisionMechanism.R
# ==============================================================================

rm(list = ls())

# ---- Packages ----------------------------------------------------------------
suppressMessages({
  library(haven)
  library(dplyr)
  library(fixest)
})
select <- dplyr::select; filter <- dplyr::filter
lag    <- dplyr::lag;    lead   <- dplyr::lead
setFixest_notes(FALSE)

ZLB_YEARS <- 2009:2012


# ==============================================================================
# === SECTION 0.0 — LOCATE DATA ================================================
# ==============================================================================

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
cat(sprintf("data folder: %s\n", DATA))


# ==============================================================================
# === SECTION 1.0 — BUILD THE PANEL BOTH WAYS ==================================
# ==============================================================================
#  Mirrors Dalis_Abdallah_CausalDiD_Analysis.R sections 1.1 to 1.6. The only
#  thing that varies is how leads and lags are constructed.

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

cbp02 <- read_dta(file.path(DATA, "cbp_exposure_2002.dta")) %>%
  mutate(area_fips = as.character(area_fips),
         exp_sens  = as.numeric(exp_sens_2002)) %>%
  select(area_fips, exp_sens)

build <- function(positional) {
  d <- panel %>%
    inner_join(ffr_keep, by = c("year", "qtr")) %>%
    inner_join(cbp02,    by = "area_fips") %>%
    filter(!(year %in% ZLB_YEARS)) %>%
    arrange(county_id, qidx)

  if (positional) {                       # Stata: dffr[_n-k] AFTER the filter
    d <- d %>% group_by(county_id) %>%
      mutate(dffr_lag1  = lag(dffr, 1),  dffr_lag2  = lag(dffr, 2),
             dffr_lag3  = lag(dffr, 3),  dffr_lag4  = lag(dffr, 4),
             dffr_lead1 = lead(dffr, 1), dffr_lead2 = lead(dffr, 2),
             dffr_lead3 = lead(dffr, 3), dffr_lead4 = lead(dffr, 4)) %>%
      ungroup()
  }

  d <- d %>% mutate(inter = dffr * exp_sens)
  for (k in 1:4) {
    d[[paste0("inter_lag",  k)]] <- d[[paste0("dffr_lag",  k)]] * d$exp_sens
    d[[paste0("inter_lead", k)]] <- d[[paste0("dffr_lead", k)]] * d$exp_sens
  }
  d
}

df_time <- build(positional = FALSE)
df_posn <- build(positional = TRUE)

fml <- ln_emp ~ inter + inter_lead1 + inter_lead2 + inter_lead3 + inter_lead4 |
  county_id + qidx

m_time <- feols(fml, cluster = ~county_id, data = df_time)
m_posn <- feols(fml, cluster = ~county_id, data = df_posn)

cat("\n----- SELF-CHECK vs FOUR-CONFIG DIAGNOSTIC -----\n")
chk <- data.frame(
  term       = c("inter", paste0("inter_lead", 1:4)),
  this_time  = round(coef(m_time)[c("inter", paste0("inter_lead", 1:4))], 5),
  onrecord   = c(0.02219, 0.00948, 0.01043, -0.00350, -0.01771),
  this_posn  = round(coef(m_posn)[c("inter", paste0("inter_lead", 1:4))], 5),
  onrecord_p = c(0.02364, 0.01298, 0.00982, -0.00660, -0.01498),
  row.names  = NULL)
print(chk)
if (max(abs(chk$this_time - chk$onrecord)) > 5e-4)
  warning("SELF-CHECK FAILED: this build does not match the analysis script. ",
          "Reconcile before trusting anything below.")


# ==============================================================================
# === SECTION 2.0 — TEST 1: DOES CLUSTERING STOP BITING? =======================
# ==============================================================================
#  The core test. SE_cluster / SE_iid measures how much the county clustering
#  inflates the standard error. If positional construction destroys within
#  county serial correlation, this ratio collapses.

se_of <- function(m, vc) sqrt(diag(vcov(m, vcov = vc)))

terms <- c("inter", paste0("inter_lead", 1:4))
tab <- data.frame(term = terms)
for (nm in c("time", "posn")) {
  m <- if (nm == "time") m_time else m_posn
  tab[[paste0(nm, "_iid")]]   <- round(se_of(m, "iid")[terms],        5)
  tab[[paste0(nm, "_clus")]]  <- round(se_of(m, ~county_id)[terms],   5)
  tab[[paste0(nm, "_ratio")]] <- round(tab[[paste0(nm, "_clus")]] /
                                         tab[[paste0(nm, "_iid")]],   2)
}

cat("\n\n----- TEST 1: CLUSTER INFLATION FACTOR -----\n")
print(tab[, c("term", "time_iid", "time_clus", "time_ratio",
              "posn_iid", "posn_clus", "posn_ratio")])
cat(sprintf("\nmean inflation, time-aware : %.2fx\n", mean(tab$time_ratio)))
cat(sprintf("mean inflation, positional : %.2fx\n", mean(tab$posn_ratio)))
cat("\nHYPOTHESIS CONFIRMED IF the positional ratio is much closer to 1.\n",
    "That would mean the clustered SE has stopped correcting for anything,\n",
    "because the serial correlation it exists to handle has been scrambled.\n")


# ==============================================================================
# === SECTION 3.0 — TEST 2: IS THE REGRESSOR STILL SERIALLY CORRELATED? ========
# ==============================================================================
#  Direct evidence for the same claim, measured on the regressor itself rather
#  than inferred from the variance estimator.

ac1 <- function(d, v) {
  d %>% arrange(county_id, qidx) %>% group_by(county_id) %>%
    summarise(r = suppressWarnings(cor(.data[[v]], lag(.data[[v]], 1),
                                       use = "complete.obs")),
              .groups = "drop") %>%
    summarise(mean_ac1 = mean(r, na.rm = TRUE)) %>% pull(mean_ac1)
}

cat("\n\n----- TEST 2: WITHIN-COUNTY FIRST-ORDER AUTOCORRELATION -----\n")
ac_tab <- data.frame(
  variable   = c("dffr", "inter", "inter_lead3"),
  time_aware = sapply(c("dffr", "inter", "inter_lead3"), function(v) round(ac1(df_time, v), 4)),
  positional = sapply(c("dffr", "inter", "inter_lead3"), function(v) round(ac1(df_posn, v), 4)),
  row.names  = NULL)
print(ac_tab)
cat("\nA large drop from time-aware to positional is the mechanism, seen directly.\n")


# ==============================================================================
# === SECTION 4.0 — TEST 3: RULE OUT THE BORING EXPLANATIONS ===================
# ==============================================================================
#  Before claiming a mechanism, confirm the SE change is not simply more
#  observations or more regressor variance.

cat("\n\n----- TEST 3: SAMPLE SIZE AND REGRESSOR SPREAD -----\n")
cat(sprintf("N used, time-aware  : %s\n", format(nobs(m_time), big.mark = ",")))
cat(sprintf("N used, positional  : %s\n", format(nobs(m_posn), big.mark = ",")))
cat(sprintf("sd(inter_lead3) time: %.6f\n", sd(df_time$inter_lead3, na.rm = TRUE)))
cat(sprintf("sd(inter_lead3) posn: %.6f\n", sd(df_posn$inter_lead3, na.rm = TRUE)))
cat("\nIf N and sd are close, neither explains a 40 pct SE cut, and the\n",
    "serial-correlation story in Tests 1 and 2 is what is left.\n")

cat("\n----- DONE -----\n")

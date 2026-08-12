# ==============================================================================
#  Spurious Precision — Shift-Share DiD, county employment and monetary policy
#  R port of causal-did/02_analysis.do  (Stata license lapsed, August 2026)
#  Author     : Abdallah Dalis
#  Institution: DePaul University
#
#  WHAT THIS REPLACES
#    01_clean_data.do  — NOT ported. Its output (the cleaned QCEW panel and the
#                        CBP 2002 exposure file) already exists on disk. This
#                        script rebuilds only the merge and the estimation.
#    02_analysis.do    — ported in full except Spec 3, see KNOWN GAPS.
#
#  STATA -> R MAPPING
#    reghdfe y x, absorb(a b) cluster(c)   ->  feols(y ~ x | a + b, cluster = ~c)
#    esttab ... using file.tex             ->  etable(..., file = ...)
#    xtset / by county: gen lag            ->  see LEADS AND LAGS note below
#
#  KNOWN GAPS (read before trusting any output)
#    1. Spec 3, the alternative-base-year robustness table, CANNOT be
#       reproduced. It needs cbp_exposure_2003/2013/2014, which are not on
#       disk — only cbp_exposure_2002.dta survives. Rebuilding them requires
#       the raw Census CBP county files (cbp03co / cbp13co / cbp14co).
#       Spec 3 is skipped, not silently approximated.
#    2. The `dffr` main effect is collinear with quarter fixed effects (it
#       varies only over time). reghdfe absorbed it; fixest drops it. Only the
#       interaction is identified. This is correct, not a bug.
#
#  LEADS AND LAGS — a deliberate departure from the Stata original
#    02_analysis.do built leads/lags positionally, `by county_id: gen
#    dffr_lag1 = dffr[_n-1]`. The panel is not fully balanced (232,008 rows
#    against 3,228 x 72 = 232,416, so ~408 county-quarters are missing), which
#    means positional lags silently cross gaps for affected counties.
#    This script instead builds leads and lags on the 72-row quarterly FFR
#    series and merges them on. That is time-aware and unambiguously correct.
#    Expect trivial differences from the Stata output for the handful of
#    counties with gaps. If exact Stata replication is ever needed, set
#    POSITIONAL_LAGS <- TRUE below.
# ==============================================================================

rm(list = ls())

# ---- Packages ----------------------------------------------------------------
# install.packages(c("haven","dplyr","tidyr","fixest"))
suppressMessages({
  library(haven)     # read_dta
  library(dplyr)
  library(tidyr)
  library(fixest)    # feols — the reghdfe equivalent
})

select <- dplyr::select; filter <- dplyr::filter
lag    <- dplyr::lag;    lead   <- dplyr::lead

setFixest_notes(FALSE)


# ==============================================================================
# === SECTION 0.0 — PARAMETERS =================================================
# ==============================================================================

# --- 0.1 Paths. Data lives in the Research_Monetary_Incidence project, which
#         sits beside `projects/`, not inside it. Resolved by search rather
#         than hardcoded so this runs from the repo root or from causal-did/.
DATA_CANDIDATES <- c(
  "../../../Research_Monetary_Incidence/data",          # from causal-did/
  "../../Research_Monetary_Incidence/data",             # from repo root
  "~/Documents/Research_Monetary_Incidence/data",       # absolute fallback
  "../data", "data"                                     # local copy, if made
)
DATA <- NA_character_
for (p in DATA_CANDIDATES) {
  if (file.exists(file.path(path.expand(p), "qcew_panel_all_years.dta"))) {
    DATA <- path.expand(p); break
  }
}
if (is.na(DATA)) {
  stop(paste0("Could not locate qcew_panel_all_years.dta.\n",
              "Working directory: ", getwd(), "\nTried:\n  ",
              paste(DATA_CANDIDATES, collapse = "\n  "),
              "\nSet DATA manually to the folder holding the .dta file."))
}
OUT  <- "output"
dir.create(file.path(OUT, "tables"),  showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(OUT, "figures"), showWarnings = FALSE, recursive = TRUE)

# --- 0.2 SAMPLE WINDOW -------------------------------------------------------
#  The single most consequential parameter in this script, and the reason it is
#  at the top rather than buried in a filter call.
#
#  01_clean_data.do line 160 excluded 2009-2012 ("financial crisis").
#  monetary_policy_labor.R line 76 did NOT — the local projections behind
#  Figures 4 and 5 use the full 2002-2019 panel.
#
#  Those two halves of the paper are therefore estimated on samples differing
#  by 51,568 county-quarters, 22 percent of the data. That must be reconciled
#  before the revision ships. Set this deliberately and state the choice in
#  Methods.
#  Override from the shell without editing this file:
#      EXCLUDE_ZLB=FALSE Rscript Dalis_Abdallah_CausalDiD_Analysis.R
EXCLUDE_ZLB    <- toupper(Sys.getenv("EXCLUDE_ZLB", "TRUE")) %in% c("TRUE", "T", "1")
ZLB_YEARS      <- 2009:2012     # FALSE = full window (LP / figure sample)

# --- 0.3 LAG CONSTRUCTION ----------------------------------------------------
#  TRUE reproduces the Stata construction, seam bug included. Note the order of
#  operations below: the ZLB filter is applied BEFORE positional lags are built,
#  exactly as in the Stata pipeline (01_clean_data.do dropped 2009-2012, then
#  02_analysis.do ran `by county_id: gen dffr_lag1 = dffr[_n-1]`). With both
#  flags TRUE, every county's 2013q1 row therefore takes its lag-1 from 2008q4.
#  Suspected source of the Stata / R divergence in the event-study post-period.
#      POSITIONAL_LAGS=TRUE Rscript Dalis_Abdallah_CausalDiD_Analysis.R
POSITIONAL_LAGS <- toupper(Sys.getenv("POSITIONAL_LAGS", "FALSE")) %in% c("TRUE", "T", "1")

CONFIG_TAG      <- sprintf("zlb-%s_pos-%s",
                           ifelse(EXCLUDE_ZLB,    "excl", "full"),
                           ifelse(POSITIONAL_LAGS, "on",   "off"))

cat("\n----- CONFIGURATION -----\n")
cat(sprintf("data folder       : %s\n", DATA))
cat(sprintf("exclude 2009-2012 : %s\n", EXCLUDE_ZLB))
cat(sprintf("lag construction  : %s\n",
            ifelse(POSITIONAL_LAGS, "positional (Stata-faithful)", "time-aware (default)")))


# ==============================================================================
# === SECTION 1.0 — BUILD THE ANALYSIS PANEL ===================================
# ==============================================================================

# --- 1.1 QCEW county panel (output of 01_clean_data.do, Parts 1-2) -----------
#  NOTE. The original port joined on `yq` and silently produced zero rows.
#  Stata %tq quarterly dates come back from haven as a NUMERIC (quarters since
#  1960q1), not a Date; as.Date() on that reinterprets it as days since 1970,
#  so 2002q1 became a date in the 1970s and matched nothing. All joins below
#  therefore key on `year` and `qtr`, which are plain integers and cannot be
#  misread. `qidx` is a derived integer quarter index used as the time FE.
panel <- read_dta(file.path(DATA, "qcew_panel_all_years.dta")) %>%
  mutate(area_fips = as.character(area_fips),
         county_id = as.character(county_id),
         year      = as.integer(year),
         qtr       = as.integer(qtr),
         qidx      = (year - 2002L) * 4L + qtr) %>%
  select(-any_of("yq"))

cat("\n----- QCEW PANEL -----\n")
cat(sprintf("rows %s | counties %s | %s to %s\n",
            format(nrow(panel), big.mark = ","),
            format(n_distinct(panel$area_fips), big.mark = ","),
            min(panel$year), max(panel$year)))

# --- 1.2 Federal funds rate, monthly -> quarterly mean -> first difference ---
ffr <- read.csv(file.path(DATA, "FEDFUNDS.csv"), stringsAsFactors = FALSE) %>%
  mutate(date  = as.Date(observation_date),
         year  = as.integer(format(date, "%Y")),
         qtr   = (as.integer(format(date, "%m")) - 1) %/% 3 + 1) %>%
  filter(year >= 2001, year <= 2019) %>%              # 2001 kept for the lag
  group_by(year, qtr) %>%
  summarise(fedfunds_q = mean(FEDFUNDS, na.rm = TRUE), .groups = "drop") %>%
  arrange(year, qtr) %>%
  mutate(dffr = fedfunds_q - lag(fedfunds_q, 1))

# --- 1.3 Leads and lags of dffr, built on the time series (see header) -------
if (!POSITIONAL_LAGS) {
  for (k in 1:4) {
    ffr[[paste0("dffr_lag",  k)]] <- lag(ffr$dffr,  k)
    ffr[[paste0("dffr_lead", k)]] <- lead(ffr$dffr, k)
  }
}

ffr_keep <- ffr %>%
  filter(year >= 2002) %>%
  select(year, qtr, dffr, starts_with("dffr_lag"), starts_with("dffr_lead"))

cat("\n----- FFR QUARTERLY -----\n")
cat(sprintf("quarters %d | dffr mean %.4f sd %.4f min %.3f max %.3f\n",
            nrow(ffr_keep), mean(ffr_keep$dffr, na.rm = TRUE),
            sd(ffr_keep$dffr, na.rm = TRUE),
            min(ffr_keep$dffr, na.rm = TRUE), max(ffr_keep$dffr, na.rm = TRUE)))

# --- 1.4 CBP 2002 exposure — MAIN, fully predetermined -----------------------
cbp02 <- read_dta(file.path(DATA, "cbp_exposure_2002.dta")) %>%
  mutate(area_fips = as.character(area_fips),
         exp_sens  = as.numeric(exp_sens_2002)) %>%
  select(area_fips, exp_sens)

cat("\n----- CBP 2002 EXPOSURE -----\n")
cat(sprintf("counties %s | mean %.4f sd %.4f min %.4f max %.4f\n",
            format(nrow(cbp02), big.mark = ","),
            mean(cbp02$exp_sens), sd(cbp02$exp_sens),
            min(cbp02$exp_sens), max(cbp02$exp_sens)))

# --- 1.5 Merge, apply sample window, construct interactions ------------------
#  Row counts are reported after EACH join. The first version of this script
#  reported only the final count, which is why a failed join looked like an
#  empty dataset with no indication of where it broke.
df <- panel %>% inner_join(ffr_keep, by = c("year", "qtr"))
cat(sprintf("\nafter FFR join      : %s rows\n", format(nrow(df), big.mark = ",")))
if (nrow(df) == 0) stop("FFR join produced zero rows — check year/qtr keys.")

df <- df %>% inner_join(cbp02, by = "area_fips")   # drops counties absent from CBP 2002
cat(sprintf("after exposure join : %s rows | %s counties\n",
            format(nrow(df), big.mark = ","),
            format(n_distinct(df$area_fips), big.mark = ",")))
if (nrow(df) == 0) stop("Exposure join produced zero rows — check area_fips keys.")

n_premerge <- nrow(df)
if (EXCLUDE_ZLB) df <- df %>% filter(!(year %in% ZLB_YEARS))

df <- df %>%
  arrange(county_id, qidx) %>%
  group_by(county_id) %>%
  mutate(d_ln_emp = ln_emp - lag(ln_emp, 1)) %>%
  ungroup() %>%
  mutate(inter = dffr * exp_sens)

if (POSITIONAL_LAGS) {
  df <- df %>% arrange(county_id, qidx) %>% group_by(county_id) %>%
    mutate(across(all_of("dffr"),
                  list(lag1 = ~lag(.x,1), lag2 = ~lag(.x,2),
                       lag3 = ~lag(.x,3), lag4 = ~lag(.x,4),
                       lead1 = ~lead(.x,1), lead2 = ~lead(.x,2),
                       lead3 = ~lead(.x,3), lead4 = ~lead(.x,4)),
                  .names = "dffr_{.fn}")) %>% ungroup()
}

for (k in 1:4) {
  df[[paste0("inter_lag",  k)]] <- df[[paste0("dffr_lag",  k)]] * df$exp_sens
  df[[paste0("inter_lead", k)]] <- df[[paste0("dffr_lead", k)]] * df$exp_sens
}

# --- 1.6 High/low exposure split for the event study -------------------------
med_exp <- median(cbp02$exp_sens, na.rm = TRUE)
df <- df %>% mutate(hi_exposure = as.integer(exp_sens > med_exp),
                    hi_inter    = dffr * hi_exposure)
for (k in 1:4) {
  df[[paste0("hi_lag",  k)]] <- df[[paste0("dffr_lag",  k)]] * df$hi_exposure
  df[[paste0("hi_lead", k)]] <- df[[paste0("dffr_lead", k)]] * df$hi_exposure
}

cat("\n----- ANALYSIS PANEL -----\n")
cat(sprintf("rows before window filter : %s\n", format(n_premerge, big.mark = ",")))
cat(sprintf("rows after  window filter : %s\n", format(nrow(df),   big.mark = ",")))
cat(sprintf("counties                  : %s\n", format(n_distinct(df$county_id), big.mark = ",")))
cat(sprintf("quarters                  : %d\n", n_distinct(df$qidx)))
cat(sprintf("median exposure (split)   : %.4f\n", med_exp))
cat("\nsummary of estimation variables:\n")
print(summary(df[, c("ln_emp", "d_ln_emp", "dffr", "exp_sens", "inter")]))


# ==============================================================================
# === SECTION 2.0 — SPECIFICATIONS =============================================
# ==============================================================================
#  All specs: county and quarter fixed effects, SE clustered by county.
#  `dffr` is omitted throughout — collinear with quarter FE, as in reghdfe.
# ==============================================================================

# --- 2.1 SPEC 1 — main shift-share DiD, contemporaneous ----------------------
main_spec <- feols(ln_emp ~ inter | county_id + qidx, cluster = ~county_id, data = df)

# --- 2.2 SPEC 2 — distributed lag, 4 quarters --------------------------------
dist_lag <- feols(ln_emp ~ inter + inter_lag1 + inter_lag2 + inter_lag3 + inter_lag4 |
                    county_id + qidx, cluster = ~county_id, data = df)

# --- 2.3 SPEC 3 — SKIPPED. See KNOWN GAPS in the header. ---------------------
cat("\n[SKIPPED] Spec 3 (alternative CBP base years): cbp_exposure_2003/2013/2014\n")
cat("          are not on disk. Table 3 cannot be regenerated. Rebuild from raw\n")
cat("          Census CBP county files if this robustness check is needed.\n")

# --- 2.4 SPEC 4 — employment growth as outcome -------------------------------
rob_growth <- feols(d_ln_emp ~ inter | county_id + qidx, cluster = ~county_id, data = df)

# --- 2.5 SPEC 5 — pre-trends / placebo, leads of dFFR ------------------------
placebo <- feols(ln_emp ~ inter + inter_lead1 + inter_lead2 + inter_lead3 + inter_lead4 |
                   county_id + qidx, cluster = ~county_id, data = df)

# --- 2.6 Event study — high vs low exposure, lead -1 omitted as reference ----
event_study <- feols(ln_emp ~ hi_lead4 + hi_lead3 + hi_lead2 +
                       hi_inter + hi_lag1 + hi_lag2 + hi_lag3 + hi_lag4 |
                       county_id + qidx, cluster = ~county_id, data = df)


# ==============================================================================
# === SECTION 3.0 — CUMULATIVE EFFECT ==========================================
# ==============================================================================

cum_terms <- c("inter", "inter_lag1", "inter_lag2", "inter_lag3", "inter_lag4")
cum_b     <- sum(coef(dist_lag)[cum_terms])
V         <- vcov(dist_lag)[cum_terms, cum_terms]
cum_se    <- sqrt(sum(V))

cat("\n----- CUMULATIVE FOUR-QUARTER EFFECT -----\n")
cat(sprintf("estimate %.4f | se %.4f | t %.2f | p %.4f\n",
            cum_b, cum_se, cum_b / cum_se, 2 * pnorm(-abs(cum_b / cum_se))))


# ==============================================================================
# === SECTION 4.0 — PRE-TRENDS VERDICT, COMPUTED NOT ASSERTED ==================
# ==============================================================================
#  The Stata original hard-coded "Lead 1 significant" and "leads 2-4 close to
#  zero," neither of which matched the estimates. This block derives the
#  verdict from the coefficients so the note cannot drift again.
# ==============================================================================

lead_tab <- data.frame(
  term = paste0("inter_lead", 1:4),
  b    = sapply(paste0("inter_lead", 1:4), function(v) coef(placebo)[[v]]),
  se   = sapply(paste0("inter_lead", 1:4), function(v) se(placebo)[[v]])
)
lead_tab$p   <- 2 * pnorm(-abs(lead_tab$b / lead_tab$se))
lead_tab$sig <- lead_tab$p < 0.05

cat("\n----- PRE-TRENDS (Table 4) -----\n")
print(round(lead_tab[, c("b", "se", "p")], 4))

sig_leads <- which(lead_tab$sig)
if (length(sig_leads) > 0) {
  cat(sprintf("VERDICT: parallel-trends test FAILS. Significant leads: %s.\n",
              paste(sig_leads, collapse = ", ")))
  if (length(unique(sign(lead_tab$b[sig_leads]))) > 1)
    cat("         Significant leads carry OPPOSITE signs — an oscillation, not anticipation.\n")
  cat("         This rules out a causal reading of the contemporaneous estimate.\n")
} else {
  cat("VERDICT: no individually significant leads.\n")
}

post <- c("hi_inter", paste0("hi_lag", 1:4))
pb   <- sapply(post, function(v) coef(event_study)[[v]])
cat("\n----- EVENT STUDY POST-PERIOD -----\n")
cat(sprintf("coefficients: %s\n", paste(sprintf("%+.4f", pb), collapse = ", ")))
cat(sprintf("sign changes: %d of %d steps%s\n",
            sum(diff(sign(pb)) != 0), length(pb) - 1,
            ifelse(sum(diff(sign(pb)) != 0) >= 3,
                   " — alternating, not a dynamic response.", "")))


# ==============================================================================
# === SECTION 5.0 — EXPORT TABLES ==============================================
# ==============================================================================

sample_tag <- ifelse(EXCLUDE_ZLB, "excl 2009-2012", "full 2002-2019")

note4 <- sprintf(paste0("SE clustered by county. Sample: %s. ",
                        "Leads significant at 5 pct: %s. Parallel-trends test %s."),
                 sample_tag,
                 ifelse(length(sig_leads) == 0, "none", paste(sig_leads, collapse = ", ")),
                 ifelse(length(sig_leads) > 0, "FAILS", "passes"))

etable(main_spec, dist_lag, rob_growth,
       file = file.path(OUT, "tables", "table2_main_R.tex"), replace = TRUE,
       title = paste0("Effect of Monetary Policy on County Employment (", sample_tag, ")"),
       notes = paste0("SE clustered by county. Exposure = CBP 2002 constr+manuf share. Sample: ",
                      sample_tag, "."))

etable(placebo,
       file = file.path(OUT, "tables", "table4_placebo_R.tex"), replace = TRUE,
       title = "Pre-Trends / Placebo Test", notes = note4)

etable(event_study,
       file = file.path(OUT, "tables", "table5_event_study_R.tex"), replace = TRUE,
       title = "Event Study Coefficients — High vs Low Exposure",
       notes = paste0("SE clustered by county. High = above-median constr+manuf share. ",
                      "Reference period t-1 omitted. Sample: ", sample_tag, "."))

tidy_out <- bind_rows(lapply(
  list(main_spec = main_spec, dist_lag = dist_lag, rob_growth = rob_growth,
       placebo = placebo, event_study = event_study),
  function(m) data.frame(term = names(coef(m)), b = coef(m), se = se(m),
                         p = pvalue(m), row.names = NULL)),
  .id = "spec")
tidy_out$sample <- sample_tag
write.csv(tidy_out, file.path(OUT, "tables", "all_coefficients_R.csv"), row.names = FALSE)

# Config-tagged copy so repeated runs under different flags do not overwrite
# each other. Consumed by Dalis_Abdallah_PipelineDiagnostic.R.
write.csv(tidy_out,
          file.path(OUT, "tables", sprintf("all_coefficients_R_%s.csv", CONFIG_TAG)),
          row.names = FALSE)

cat("\n----- CONSOLE SUMMARY -----\n")
etable(main_spec, dist_lag, rob_growth, placebo, event_study)

cat(sprintf("\nwrote: %s/tables/{table2_main_R,table4_placebo_R,table5_event_study_R}.tex\n", OUT))
cat(sprintf("wrote: %s/tables/all_coefficients_R.csv\n", OUT))
cat("\n----- DONE -----\n")

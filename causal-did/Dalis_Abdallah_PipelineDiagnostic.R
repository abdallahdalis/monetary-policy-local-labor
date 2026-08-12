# ==============================================================================
#  Spurious Precision — Stata / R pipeline reconciliation
#  Diagnostic: why does the event-study post-period differ across pipelines?
#  Author     : Abdallah Dalis
#  DePaul University
#
#  THE QUESTION
#    02_analysis.do reports a post-period of  +0.0194, -0.0079, +0.0128,
#    -0.0072, +0.0013  (signs alternate, five reversals).
#    Dalis_Abdallah_CausalDiD_Analysis.R reports +0.0034, +0.0005, +0.0021,
#    +0.0009, +0.0095  (all positive, zero reversals), and roughly five times
#    smaller. The pre-trends failure is robust across both. The post-period
#    shape is not. This script finds out why before either version is claimed.
#
#  THE HYPOTHESIS, IN RANK ORDER
#    H1  SEAM SPLICING. Stata dropped 2009-2012 in 01_clean_data.do, THEN built
#        lags positionally (`by county_id: gen dffr_lag1 = dffr[_n-1]`). For
#        every county the 2013q1 row therefore takes its lag-1 from 2008q4, a
#        17-quarter jump. Four leads and four lags means eight contaminated
#        quarters per county at the seam, across all ~3,228 counties, sitting
#        exactly where |dffr| is largest. This would manufacture an alternating
#        pattern out of nothing, which is on the nose for a paper called
#        Spurious Precision.
#    H2  MEDIAN SPLIT. Stata: `sum exp_sens, detail` then `>= r(p50)` — median
#        over county-QUARTER rows, inclusive. R: `median(cbp02$exp_sens)` then
#        `>` — median over unique COUNTIES, strict. Different population and
#        different inequality, so counties can land on opposite sides.
#    H3  WINDOW MISMATCH. The .do figure notes say the exclusion is
#        2008q4-2013q1 (18 quarters). Both scripts actually drop calendar
#        2009-2012 (16 quarters). If the .dta was built on the wider window,
#        the samples differ by two crisis quarters.
#
#  HOW TO RUN — RSTUDIO
#    1. Open this file in RStudio.
#    2. Session > Set Working Directory > To Source File Location.
#    3. Click Source (or Cmd+Shift+S). Do NOT use Run, which sends line by
#       line and will trip over the multi-line blocks.
#    Note: line 1 is `rm(list = ls())`, so an unsaved global environment gets
#    cleared. Save anything you care about first.
#
#  HOW TO RUN — TERMINAL
#    cd .../projects/monetary-policy-local-labor/causal-did
#    Rscript Dalis_Abdallah_PipelineDiagnostic.R
#
#  Runs the analysis script four times (about 4x its normal runtime), then
#  reports. Nothing here overwrites a paper table.
# ==============================================================================

rm(list = ls())

# ---- Packages ----------------------------------------------------------------
suppressMessages({
  library(haven)
  library(dplyr)
  library(tidyr)
})

ANALYSIS <- "Dalis_Abdallah_CausalDiD_Analysis.R"
OUT      <- "output"
TABLES   <- file.path(OUT, "tables")

if (!file.exists(ANALYSIS))
  stop("Working directory is ", getwd(), ", which does not contain ", ANALYSIS,
       ".\nIn RStudio: Session > Set Working Directory > To Source File Location.")

# Resolve Rscript from the running R installation rather than trusting PATH.
# RStudio launched from Finder on macOS often carries a trimmed PATH, so a bare
# "Rscript" can fail there while working fine in a terminal.
RSCRIPT <- file.path(R.home("bin"), "Rscript")
if (!file.exists(RSCRIPT)) RSCRIPT <- "Rscript"
cat(sprintf("using Rscript: %s\n", RSCRIPT))


# ==============================================================================
# === SECTION 1.0 — RUN THE FOUR CONFIGURATIONS ================================
# ==============================================================================
#  R default is (excl, off). Stata is (excl, on). If H1 is right, (excl, on)
#  reproduces the alternating signs and (excl, off) does not.

configs <- data.frame(
  zlb = c("TRUE", "TRUE",  "FALSE", "FALSE"),
  pos = c("FALSE", "TRUE", "FALSE", "TRUE"),
  stringsAsFactors = FALSE
)
configs$tag <- sprintf("zlb-%s_pos-%s",
                       ifelse(configs$zlb == "TRUE", "excl", "full"),
                       ifelse(configs$pos == "TRUE", "on",   "off"))
configs$label <- c("R default (time-aware, excl 2009-2012)",
                   "STATA-FAITHFUL (positional, excl 2009-2012)",
                   "time-aware, full window",
                   "positional, full window")

cat("\n----- RUNNING FOUR CONFIGURATIONS -----\n")
for (i in seq_len(nrow(configs))) {
  cat(sprintf("\n[%d/%d] %s\n", i, nrow(configs), configs$label[i]))
  log_file <- file.path(TABLES, sprintf("run_%s.log", configs$tag[i]))
  status <- tryCatch(
    system2(RSCRIPT, args = ANALYSIS,
            env = c(sprintf("EXCLUDE_ZLB=%s",     configs$zlb[i]),
                    sprintf("POSITIONAL_LAGS=%s", configs$pos[i])),
            stdout = log_file, stderr = log_file),
    error = function(e) { cat("  FAILED: ", conditionMessage(e), "\n"); 1L }
  )
  cat(sprintf("  exit %s | log: %s\n", status, log_file))
}


# ==============================================================================
# === SECTION 2.0 — EVENT-STUDY POST-PERIOD, SIDE BY SIDE ======================
# ==============================================================================
#  The post-period terms, in event time. hi_inter is t=0.

post_terms <- c("hi_inter", "hi_lag1", "hi_lag2", "hi_lag3", "hi_lag4")
lead_terms <- c("inter_lead1", "inter_lead2", "inter_lead3", "inter_lead4")

read_tagged <- function(tag) {
  f <- file.path(TABLES, sprintf("all_coefficients_R_%s.csv", tag))
  if (!file.exists(f)) { warning("missing: ", f); return(NULL) }
  read.csv(f, stringsAsFactors = FALSE)
}

collect <- function(spec_name, terms, label) {
  rows <- lapply(seq_len(nrow(configs)), function(i) {
    d <- read_tagged(configs$tag[i])
    if (is.null(d)) return(NULL)
    d <- d[d$spec == spec_name & d$term %in% terms, c("term", "b", "se", "p")]
    if (!nrow(d)) return(NULL)
    d$config <- configs$label[i]
    d
  })
  rows <- bind_rows(rows)
  if (!nrow(rows)) { cat("\n(no rows for ", label, ")\n"); return(invisible(NULL)) }
  rows$term <- factor(rows$term, levels = terms)

  cat(sprintf("\n\n----- %s: COEFFICIENTS -----\n", label))
  print(rows %>%
          mutate(b = round(b, 4)) %>%
          select(config, term, b) %>%
          pivot_wider(names_from = term, values_from = b),
        width = 200)

  cat(sprintf("\n----- %s: SIGN REVERSALS -----\n", label))
  flips <- rows %>%
    arrange(config, term) %>%
    group_by(config) %>%
    summarise(n_negative = sum(b < 0),
              n_sign_changes = sum(diff(sign(b)) != 0),
              max_abs_b = round(max(abs(b)), 4), .groups = "drop")
  print(as.data.frame(flips))
  invisible(rows)
}

collect("event_study", post_terms, "EVENT STUDY POST-PERIOD")
collect("placebo",     lead_terms, "PLACEBO LEADS (pre-trends)")

cat("\n",
    "READ THIS AS: if 'positional, excl 2009-2012' shows sign changes and\n",
    "'time-aware, excl 2009-2012' does not, H1 is confirmed and the Stata\n",
    "alternating post-period is a lag-splicing artifact, not a finding.\n")


# ==============================================================================
# === SECTION 3.0 — H1 DIRECT: HOW MANY OBSERVATIONS CROSS THE SEAM? ===========
# ==============================================================================
#  Counted on the panel itself, independent of any regression.

DATA_CANDIDATES <- c("../../../Research_Monetary_Incidence/data",
                     "../../Research_Monetary_Incidence/data",
                     "~/Documents/Research_Monetary_Incidence/data",
                     "../data", "data")
DATA <- NA_character_
for (p in DATA_CANDIDATES)
  if (file.exists(file.path(path.expand(p), "qcew_panel_all_years.dta"))) {
    DATA <- path.expand(p); break
  }

if (is.na(DATA)) {
  cat("\n(Section 3 skipped: panel not found.)\n")
} else {
  panel <- read_dta(file.path(DATA, "qcew_panel_all_years.dta")) %>%
    mutate(year = as.integer(year), qtr = as.integer(qtr),
           county_id = as.character(county_id),
           qidx = (year - 2002L) * 4L + qtr) %>%
    filter(year >= 2002, year <= 2019)

  kept <- panel %>% filter(!(year %in% 2009:2012)) %>% arrange(county_id, qidx)

  # Under positional construction, an observation is contaminated when the row
  # k positions away in the county block is not k quarters away in real time.
  contaminated <- kept %>%
    group_by(county_id) %>%
    summarise(bad = sum(sapply(1:4, function(k) {
      d <- qidx - dplyr::lag(qidx, k)
      sum(!is.na(d) & d != k)
    })) + sum(sapply(1:4, function(k) {
      d <- dplyr::lead(qidx, k) - qidx
      sum(!is.na(d) & d != k)
    })), .groups = "drop")

  n_rows      <- nrow(kept)
  n_bad       <- sum(contaminated$bad)
  n_counties  <- sum(contaminated$bad > 0)

  cat("\n\n----- H1: SEAM CONTAMINATION UNDER POSITIONAL LAGS -----\n")
  cat(sprintf("rows in the 2009-2012-excluded panel : %s\n", format(n_rows, big.mark = ",")))
  cat(sprintf("lead/lag cells spanning a time gap   : %s\n", format(n_bad, big.mark = ",")))
  cat(sprintf("counties affected                    : %s of %s\n",
              format(n_counties, big.mark = ","),
              format(n_distinct(kept$county_id), big.mark = ",")))
  cat(sprintf("share of all lead/lag cells          : %.1f pct\n",
              100 * n_bad / (8 * n_rows)))
  cat("\nIf 'counties affected' is essentially every county, the Stata leads and\n",
      "lags are not approximately right with a few exceptions. They are wrong\n",
      "at the crisis boundary for the whole panel.\n")

  # ============================================================================
  # === SECTION 4.0 — H2: DOES THE MEDIAN DEFINITION MOVE COUNTIES? ===========
  # ============================================================================
  cbp_f <- file.path(DATA, "cbp_exposure_2002.dta")
  if (file.exists(cbp_f)) {
    cbp02 <- read_dta(cbp_f) %>%
      mutate(area_fips = as.character(area_fips),
             exp_sens  = as.numeric(exp_sens_2002)) %>%
      select(area_fips, exp_sens)

    merged <- kept %>%
      mutate(area_fips = as.character(area_fips)) %>%
      inner_join(cbp02, by = "area_fips")

    med_county <- median(cbp02$exp_sens,  na.rm = TRUE)   # R:     unique counties
    med_rows   <- median(merged$exp_sens, na.rm = TRUE)   # Stata: county-quarters

    cty <- merged %>%
      distinct(area_fips, exp_sens) %>%
      mutate(hi_R     = as.integer(exp_sens >  med_county),
             hi_stata = as.integer(exp_sens >= med_rows))

    cat("\n\n----- H2: MEDIAN SPLIT DEFINITION -----\n")
    cat(sprintf("median over unique counties (R)      : %.6f\n", med_county))
    cat(sprintf("median over county-quarters (Stata)  : %.6f\n", med_rows))
    cat(sprintf("counties assigned differently        : %s of %s (%.2f pct)\n",
                format(sum(cty$hi_R != cty$hi_stata), big.mark = ","),
                format(nrow(cty), big.mark = ","),
                100 * mean(cty$hi_R != cty$hi_stata)))
    cat("\nA small number here means H2 is a rounding issue, not the story.\n",
        "A large number means the two pipelines are comparing different groups.\n")
  } else {
    cat("\n(Section 4 skipped: cbp_exposure_2002.dta not found.)\n")
  }
}

cat("\n----- DONE -----\n")

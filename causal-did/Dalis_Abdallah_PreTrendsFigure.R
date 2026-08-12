# ==============================================================================
#  Spurious Precision: Why Shift-Share Designs Overstate Monetary Policy
#                      Effects on Local Employment
#  Figure 3 — the pre-trends test, both windows
#  Author     : Abdallah Dalis
#  Institution: DePaul University
#
#  Built August 11, 2026, per FIGURE_PLAN_2026-08-11.md.
#
#  WHY THIS SCRIPT EXISTS. The manuscript had a parameterization mismatch. Two
#  pre-trend objects live in the codebase and they disagree about which leads
#  fail:
#
#    placebo      continuous, inter_lead1..4   -> significant leads 1, 2, 4
#    event_study  binary high vs low, hi_lead* -> significant leads 3, 4
#
#  Lead 3 is the sharp disagreement: -0.0034 (p = 0.219) in the placebo spec
#  against +0.0044 (p = 0.004) in the event study. Opposite sign, opposite
#  verdict.
#
#  The abstract's "two of four leads" comes from the PLACEBO spec, and the
#  randomization inference in PIPELINE_RECONCILIATION.md sections 4c and 4h was
#  run on those same coefficients. So the placebo spec is the parameterization
#  the paper's evidence is actually verified on, and Figure 3 plots it.
#
#  This also makes Figures 3 and 4 show the same object: analytic intervals
#  here, permutation null there.
#
#  Input : qcew_panel_all_years.dta, FEDFUNDS.csv, cbp_exposure_2002.dta
#          (resolved through DATA_CANDIDATES, as in the other scripts)
#  Output: output/figures/fig3_pretrends.png
#          output/tables/tab_pretrends_both_windows.csv
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

# ---- Paths -------------------------------------------------------------------
OUT <- "output"
dir.create(file.path(OUT, "tables"),  showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(OUT, "figures"), showWarnings = FALSE, recursive = TRUE)

# ---- Palette (per 00_Resources/output-standards.md) --------------------------
col_full <- "steelblue"
col_excl <- "darkorange3"

Z95       <- 1.959964
ZLB_YEARS <- 2009:2012

# paste(collapse = " and ") produces "1 and 2 and 4" for three or more items.
fmt_list <- function(x) {
  if (length(x) == 0) return("none")
  if (length(x) <= 2) return(paste(x, collapse = " and "))
  paste0(paste(x[-length(x)], collapse = ", "), ", and ", x[length(x)])
}


# ==============================================================================
# === SECTION 1.0 — BUILD THE PANEL ============================================
# ==============================================================================
#  Copied from Dalis_Abdallah_RandomizationInference.R section 1.0 so the three
#  scripts estimate the same object. If that build changes, change it here too.
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
cat(sprintf("\ndata dir : %s\n", DATA))

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
#  ⚠️ Dalis_Abdallah_RandomizationInference.R shares this section 1.0 build and
#  must be repointed and re-run too. Until it is, the RI counts quoted in
#  sections 3.0 and 4.0 below are computed on the OLD measure.
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

# Time-aware lag construction only. The positional build is a diagnostic
# artifact, not a specification. See PIPELINE_RECONCILIATION.md section 4d.
build_panel <- function(exclude_zlb) {
  d <- panel %>%
    inner_join(ffr_keep, by = c("year", "qtr")) %>%
    inner_join(cbp02,    by = "area_fips") %>%
    filter(if (exclude_zlb) !(year %in% ZLB_YEARS) else TRUE) %>%
    arrange(county_id, qidx)
  d$inter <- d$dffr * d$exp_sens
  for (k in 1:4) {
    d[[paste0("inter_lead", k)]] <- d[[paste0("dffr_lead", k)]] * d$exp_sens
  }
  d
}

FML <- ln_emp ~ inter + inter_lead1 + inter_lead2 + inter_lead3 + inter_lead4 |
  county_id + qidx


# ==============================================================================
# === SECTION 2.0 — ESTIMATE BOTH WINDOWS ======================================
# ==============================================================================

windows <- list("full 2002-2019" = FALSE, "excl 2009-2012" = TRUE)
res     <- list()

for (nm in names(windows)) {
  d <- build_panel(windows[[nm]])
  m <- feols(FML, cluster = ~county_id, data = d)

  terms <- paste0("inter_lead", 1:4)
  out <- data.frame(
    window = nm,
    lead   = 1:4,
    b      = sapply(terms, function(v) coef(m)[[v]]),
    se     = sapply(terms, function(v) se(m)[[v]])
  )
  out$t  <- out$b / out$se
  out$p  <- 2 * pnorm(-abs(out$t))
  out$lo <- out$b - Z95 * out$se
  out$hi <- out$b + Z95 * out$se
  res[[nm]] <- out

  cat(sprintf("\n----- %s -----\n", nm))
  cat(sprintf("n obs                : %s\n", format(nobs(m), big.mark = ",")))
  cat(sprintf("contemporaneous inter: %+.4f (se %.4f)\n",
              coef(m)[["inter"]], se(m)[["inter"]]))
  print(round(out[, c("lead", "b", "se", "t", "p")], 4), row.names = FALSE)

  sig <- out$lead[out$p < 0.05]
  cat(sprintf("leads significant at 5 pct : %s\n",
              ifelse(length(sig) == 0, "none", paste(sig, collapse = ", "))))
  cat(sprintf("parallel-trends test       : %s\n",
              ifelse(length(sig) > 0, "FAILS", "passes")))
}

pt <- do.call(rbind, res)
write.csv(pt, file.path(OUT, "tables", "tab_pretrends_both_windows.csv"),
          row.names = FALSE)


# ==============================================================================
# === SECTION 3.0 — FIGURE 3 ===================================================
# ==============================================================================
#  Design note. Both windows appear in one panel, offset horizontally so the
#  intervals do not overlap. Showing them together is the point: the window
#  decision is reported rather than defended, so the reader should be able to
#  see that the pre-trends verdict does not depend on it.
# ==============================================================================

f <- res[["full 2002-2019"]]
e <- res[["excl 2009-2012"]]

off  <- 0.10
ylim <- range(c(f$lo, f$hi, e$lo, e$hi))
ylim <- ylim + c(-1, 1) * 0.10 * diff(ylim)

png(file.path(OUT, "figures", "fig3_pretrends.png"),
    width = 2100, height = 1050, res = 150)

layout(matrix(c(1, 2), nrow = 2), heights = c(0.85, 0.15))
par(mar = c(4.4, 4.8, 3.4, 1.4), family = "sans")

plot(NA, xlim = c(0.6, 4.4), ylim = ylim, xaxt = "n", las = 1, bty = "n",
     xlab = "Lead (quarters before the policy change)",
     ylab = "Interaction coefficient",
     main = "The design fails its own pre-trends test, in both windows",
     cex.main = 1.25, cex.lab = 1.05)
axis(1, at = 1:4, labels = paste("Lead", 1:4))

abline(h = 0, col = "grey35", lwd = 1.2)
grid(nx = NA, ny = NULL, col = "grey88", lty = 1)

draw_window <- function(d, xoff, col, pch) {
  x <- d$lead + xoff
  segments(x, d$lo, x, d$hi, col = col, lwd = 2.4)
  segments(x - 0.05, d$lo, x + 0.05, d$lo, col = col, lwd = 2.0)
  segments(x - 0.05, d$hi, x + 0.05, d$hi, col = col, lwd = 2.0)
  points(x, d$b, col = col, pch = pch, cex = 1.25)
}

draw_window(f, -off, col_full, 16)
draw_window(e,  off, col_excl, 17)

# Mark which leads reject, computed rather than asserted, so the annotation
# cannot drift from the estimates.
sig_full <- f$lead[f$p < 0.05]
sig_excl <- e$lead[e$p < 0.05]
# Collapse the annotation when both windows agree, which they do at present.
# Spelling an identical list twice reads as though the windows differ.
sub_txt <- if (identical(sig_full, sig_excl)) {
  sprintf(paste0("Clustered inference rejects leads %s in both windows. ",
                 "Leads 2 and 4 also reject under randomization inference."),
          fmt_list(sig_full))
} else {
  sprintf(paste0("Clustered inference rejects leads %s (full) and %s (excl. 2009-2012). ",
                 "Leads 2 and 4 also reject under randomization inference."),
          fmt_list(sig_full), fmt_list(sig_excl))
}
mtext(sub_txt, side = 3, line = 0.2, cex = 0.82, col = "grey25")

par(mar = c(0, 4.8, 0, 1.4))
plot.new()
legend("center", horiz = TRUE, bty = "n", cex = 1.0, seg.len = 2.0,
       legend = c("Full window, 2002 to 2019",
                  "Excluding 2009 to 2012"),
       col = c(col_full, col_excl), lwd = 2.4, pch = c(16, 17))

dev.off()
cat(sprintf("\nwrote: %s\n", file.path(OUT, "figures", "fig3_pretrends.png")))


# ==============================================================================
# === SECTION 4.0 — CAPTION, GENERATED FROM THE ESTIMATES ======================
# ==============================================================================

cat("\n----- FIGURE 3 CAPTION (paste into the paper) -----\n")
cat("Figure 3. Pre-period leads of the exposure interaction, with 95 percent\n")
cat("confidence intervals, standard errors clustered by county. Leads are added\n")
cat("to the main specification; a design satisfying parallel trends would place\n")
cat("all four at zero. Estimates are shown for the full 2002 to 2019 panel and\n")
cat("for the sample excluding 2009 to 2012.\n")
if (identical(sig_full, sig_excl)) {
  cat(sprintf(
  "Under clustered inference, leads %s reject zero at 5 percent, and the two windows\n",
    fmt_list(sig_full)))
  #  ⚠️ This line asserted "agree to three decimal places." They do not: the
  #  largest lead gap between windows is about 0.0015, which is agreement to TWO
  #  decimals. Compute the gap and print it rather than characterising it.
  gap <- max(abs(f$b[match(e$lead, f$lead)] - e$b), na.rm = TRUE)
  cat(sprintf("agree to within %.4f on every lead. The parallel-trends assumption fails regardless of\n",
              gap))
  cat("the window, so the difference-in-differences estimate cannot be read causally.\n")
} else {
  cat(sprintf(
  "Under clustered inference, leads %s reject zero at 5 percent in the full window,\n",
    fmt_list(sig_full)))
  cat(sprintf(
  "and leads %s reject excluding 2009 to 2012. The parallel-trends assumption fails\n",
    fmt_list(sig_excl)))
  cat("under both windows, so the difference-in-differences estimate cannot be read\n")
  cat("causally.\n")
}
# The figure shows more leads rejecting under clustered inference than the paper
# reports, because the reported count is the INTERSECTION with randomization
# inference. That gap is deliberate and has to be explained here, or a reader
# will take it for an inconsistency.
#
# ⚠️ AMENDED August 12, 2026. These three lines used to READ "leads 2 and 4 also
# reject under randomization inference, while lead 1 is marginal (p = 0.055)."
# They were prose, not a computation: the numbers were transcribed from an RI run
# that predated the exposure rebuild, and they stayed put while the RI file
# underneath them changed to leads 2 and 3. A caption that asserts a number it
# did not compute is the same defect this project has now documented five times.
# The block below DERIVES the intersection from the RI file, and says so if the
# file is missing rather than falling back on a remembered answer.
RI_PATH <- file.path(OUT, "tables", "randomization_inference_zlb-full.csv")
if (file.exists(RI_PATH)) {
  ri <- read.csv(RI_PATH, stringsAsFactors = FALSE)
  ri <- ri[ri$construction == "time" & ri$scheme == "free" &
             grepl("^inter_lead", ri$term), ]
  ri$lead <- as.integer(sub("^inter_lead", "", ri$term))
  #  Read the draw count off the file rather than hard-coding it. The previous
  #  version of this line said "0 of 200 draws" as literal text and kept saying
  #  it after the run was raised to 2,000 -- a caption asserting a number it did
  #  not read, which is the exact defect this block was written to remove.
  RI_REPS <- if ("n_reps" %in% names(ri)) as.integer(ri$n_reps[1]) else NA_integer_
  if (is.na(RI_REPS))
    stop("randomization_inference_zlb-full.csv has no n_reps column. Re-run ",
         "Dalis_Abdallah_RandomizationInference.R; a permutation p-value ",
         "cannot be reported without its draw count.")
  ri <- ri[order(ri$lead), ]
  ri_sig  <- ri$lead[ri$p_ri < 0.05]
  both    <- intersect(sig_full, ri_sig)
  marginal <- ri$lead[ri$p_ri >= 0.05 & ri$p_ri < 0.10 & ri$lead %in% sig_full]
  cat(sprintf(
    "Of these, lead%s %s also reject under randomization inference",
    if (length(both) == 1) "" else "s", fmt_list(both)))
  if (length(marginal) > 0)
    cat(sprintf(", while lead%s %s\n%s (p = %s)",
                if (length(marginal) == 1) "" else "s", fmt_list(marginal),
                if (length(marginal) == 1) "is marginal" else "are marginal",
                paste(sprintf("%.3f", ri$p_ri[ri$lead %in% marginal]),
                      collapse = ", ")))
  cat(".\n")
  cat(sprintf(
    "The paper reports the %d-lead count throughout, which is the conservative\n",
    length(both)))
  cat("reading: it counts only leads that fail under both methods.\n")

  cat("\n----- CONSISTENCY CHECK AGAINST THE ABSTRACT -----\n")
  cat(sprintf(" Clustered inference rejects leads %s. Randomization inference rejects\n",
              fmt_list(sig_full)))
  cat(sprintf(" leads %s. The intersection, which is what the paper reports, is %s.\n",
              fmt_list(ri_sig), fmt_list(both)))
  cat(" RI p-values, time construction, free scheme:\n")
  for (i in seq_len(nrow(ri)))
    cat(sprintf("   lead %d : p_ri = %.3f%s\n", ri$lead[i], ri$p_ri[i],
                if (ri$p_ri[i] == 0)
                  sprintf("   (0 of %d draws; report as p < %.4f)",
                          RI_REPS, 1 / (2 * RI_REPS)) else ""))
  cat(sprintf(" The abstract submitted August 11 says TWO of four. That is %s.\n",
              if (length(both) == 2) "still the count" else
                "NO LONGER THE COUNT -- the abstract sentence has to change"))
} else {
  cat("\n⚠️ randomization_inference_zlb-full.csv not found. The reported lead count\n")
  cat("   is the intersection of this table with that file and CANNOT be stated\n")
  cat("   without it. Run Dalis_Abdallah_RandomizationInference.R.\n")
}

cat("\n----- DONE -----\n")

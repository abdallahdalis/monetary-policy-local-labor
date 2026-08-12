# ==============================================================================
#  Spurious Precision: Why Shift-Share Designs Overstate Monetary Policy
#                      Effects on Local Employment
#  Figures 4 and 5 on disk = manuscript Figures 5 and 6. Raw vs identified local
#  projections (with bands), and the standard-error paths behind them.
#  Author     : Abdallah Dalis
#  Institution: DePaul University
#
#  Rebuilds the headline figure for SSRN 7000419 (revision, August 2026).
#  The superseded figure plotted point estimates only. Point estimates alone
#  assert a sign reversal the data does not support: the two estimators are
#  not statistically distinguishable at any horizon. The bands ARE the finding.
#
#  ⚠️ FILE NAMES DO NOT MATCH MANUSCRIPT NUMBERS. Mapping, per
#  FIGURE_PLAN_2026-08-11.md:
#      fig4_raw_vs_identified.png  ->  manuscript Figure 5
#      fig5_precision_collapse.png ->  manuscript Figure 6
#  Check this before writing any float block.
#
#  Input : tables/tab_signflip_zlb-full.csv   (headline window)
#          tables/tab_signflip_zlb-excl.csv   (2009-2012 excluded)
#  ⚠️ tables/tab_signflip.csv is SUPERSEDED — single window, carries a small
#     seam contamination. This script no longer reads it. Do not restore it.
#
#  Output: figures/fig4_raw_vs_identified.png   full window only, with bands
#          figures/fig5_precision_collapse.png  BOTH windows, standard errors
#          tables/tab_signflip_diagnostics.csv  both windows, stacked
#
#  Why the two figures treat the window differently. Figure 5 plots confidence
#  bands; four overlapping bands in one frame is unreadable, so it stays on the
#  headline window. Figure 6 plots standard-error paths and has no bands, so
#  four lines cost nothing, and it is where the excluded window is reported.
#
#  ⚠️ The two windows do NOT sit on top of each other, and an earlier draft of
#  this header wrongly said they did. The raw paths are coincident, but the
#  identified path runs 13 to 19 percent higher in the excluded window. Section
#  2.1 prices that against the loss of 16 quarterly clusters and finds it is
#  the cluster count, not the shock measure. Do not describe the two windows as
#  overlapping, and do not read the gap as a substantive finding.
# ==============================================================================

rm(list = ls())

# ---- Packages ----------------------------------------------------------------
# Base R only. No dependencies beyond stats/grDevices/graphics.

# ---- Paths -------------------------------------------------------------------
PROJ    <- "."
IN_FULL <- file.path(PROJ, "tables", "tab_signflip_zlb-full.csv")
IN_EXCL <- file.path(PROJ, "tables", "tab_signflip_zlb-excl.csv")
FIG     <- file.path(PROJ, "figures")
TAB    <- file.path(PROJ, "tables")
dir.create(FIG, showWarnings = FALSE, recursive = TRUE)
dir.create(TAB, showWarnings = FALSE, recursive = TRUE)

# ---- Palette (per 00_Resources/output-standards.md) ---------------------------
col_raw  <- "steelblue"
col_sur  <- "firebrick"
band_raw <- adjustcolor(col_raw, alpha.f = 0.22)
band_sur <- adjustcolor(col_sur, alpha.f = 0.18)

Z95 <- 1.959964


# ==============================================================================
# === SECTION 1.0 — LOAD BOTH WINDOWS, AND VERIFY THEM =========================
# ==============================================================================
#  `lp` is the FULL window and carries the headline figures. `lp_x` is the
#  excluded window and appears only in Figure 6.
#
#  SELF-CHECK, and it is not decorative. Each input file ships its own p_raw,
#  p_sur and se_ratio columns. Those are recomputed here from b and se, and the
#  script STOPS if they disagree. The standing lesson in this project is that a
#  rewrite is not trusted until it reproduces the table it replaces.
# ==============================================================================

load_lp <- function(path, label) {
  d <- read.csv(path, stringsAsFactors = FALSE)
  d <- d[order(d$h), ]

  # --- 1.1 Confidence bands ---
  d$lo_raw <- d$b_raw - Z95 * d$se_raw
  d$hi_raw <- d$b_raw + Z95 * d$se_raw
  d$lo_sur <- d$b_sur - Z95 * d$se_sur
  d$hi_sur <- d$b_sur + Z95 * d$se_sur

  # --- 1.2 Recompute what the file already claims ---
  p_raw_chk    <- 2 * pnorm(-abs(d$b_raw / d$se_raw))
  p_sur_chk    <- 2 * pnorm(-abs(d$b_sur / d$se_sur))
  se_ratio_chk <- d$se_sur / d$se_raw

  gaps <- c(p_raw    = max(abs(p_raw_chk    - d$p_raw)),
            p_sur    = max(abs(p_sur_chk    - d$p_sur)),
            se_ratio = max(abs(se_ratio_chk - d$se_ratio)))

  if (any(gaps > 1e-8)) {
    stop(sprintf("SELFCHECK FAILED for %s (%s): %s",
                 label, basename(path),
                 paste(sprintf("%s=%.3e", names(gaps), gaps), collapse = ", ")))
  }
  cat(sprintf("selfcheck OK   %-16s  max gap %.2e   %s\n",
              label, max(gaps), basename(path)))

  # --- 1.3 Difference test.
  #     Treats the two estimates as independent, which overstates the evidence
  #     for a difference because they share a sample. Read as an upper bound.
  d$se_diff <- sqrt(d$se_raw^2 + d$se_sur^2)
  d$p_diff  <- 2 * pnorm(-abs((d$b_raw - d$b_sur) / d$se_diff))

  d$label <- label
  d
}

cat("\n----- INPUT -----\n")
cat("outcome     : 100 x log employment change, cumulative to horizon h\n")
cat("clustering  : by quarter (vcovCL, see monetary_policy_labor.R)\n")
lp   <- load_lp(IN_FULL, "full 2002-2019")
lp_x <- load_lp(IN_EXCL, "excl 2009-2012")

stopifnot(identical(lp$h, lp_x$h))


# ==============================================================================
# === SECTION 2.0 — DIAGNOSTICS, BOTH WINDOWS ==================================
# ==============================================================================

summarise_lp <- function(d) list(
  n_h       = nrow(d),
  raw_pos   = sum(d$b_raw > 0),
  raw_sig   = sum(d$p_raw < 0.05),
  sur_neg   = sum(d$b_sur < 0),
  sur_sig   = sum(d$p_sur < 0.05),
  ratio_min = min(d$se_ratio),
  ratio_max = max(d$se_ratio),
  dif_sig   = sum(d$p_diff < 0.05),
  p_dif_min = min(d$p_diff),
  h_closest = d$h[which.min(d$p_diff)]
)

S  <- summarise_lp(lp)
Sx <- summarise_lp(lp_x)

# --- 2.1 How far apart are the two windows, and is the gap interesting? -------
#  The excluded window's identified standard errors sit visibly above the full
#  window's. Before reading anything into that, price the mundane explanation:
#  the local projections cluster by QUARTER, and excluding 2009-2012 removes 16
#  of 71 quarterly clusters. Under a balanced panel that alone widens standard
#  errors by sqrt(71/55) - 1, about 14 percent.
#
#  Quarter counts are stated in FIGURE_PLAN_2026-08-11.md (71 full, 55 excluded)
#  and are CROSS-CHECKED here against the observation counts in the input files,
#  which is the only quarter information those files carry.
N_Q_FULL <- 71
N_Q_EXCL <- 55

q_ratio <- sqrt(N_Q_FULL / N_Q_EXCL)
n_ratio <- sqrt(lp$n_raw[lp$h == 0] / lp_x$n_raw[lp_x$h == 0])
if (abs(q_ratio - n_ratio) > 0.01) {
  stop(sprintf(
    "Quarter counts (%d/%d -> %.4f) disagree with observation counts (%.4f). Fix before citing.",
    N_Q_FULL, N_Q_EXCL, q_ratio, n_ratio))
}
cat(sprintf("selfcheck OK   quarter counts    %d vs %d, sqrt-ratio %.4f matches obs %.4f\n",
            N_Q_FULL, N_Q_EXCL, q_ratio, n_ratio))

gap_sur     <- 100 * (lp_x$se_sur / lp$se_sur - 1)   # percent, by horizon
gap_raw_abs <- max(abs(lp_x$se_raw - lp$se_raw))

cat("\n----- HEADLINE DIAGNOSTICS -----\n")
cat(sprintf("%-30s %14s %14s\n", "", "full 2002-2019", "excl 2009-2012"))
cat(sprintf("%-30s %14d %14d\n", "horizons",             S$n_h,      Sx$n_h))
cat(sprintf("%-30s %14d %14d\n", "raw positive",         S$raw_pos,  Sx$raw_pos))
cat(sprintf("%-30s %14d %14d\n", "raw significant",      S$raw_sig,  Sx$raw_sig))
cat(sprintf("%-30s %14d %14d\n", "identified negative",  S$sur_neg,  Sx$sur_neg))
cat(sprintf("%-30s %14d %14d\n", "identified significant", S$sur_sig, Sx$sur_sig))
cat(sprintf("%-30s %14.2f %14.2f\n", "SE ratio min",     S$ratio_min, Sx$ratio_min))
cat(sprintf("%-30s %14.2f %14.2f\n", "SE ratio max",     S$ratio_max, Sx$ratio_max))
cat(sprintf("%-30s %14.4f %14.4f\n", "smallest p(diff)", S$p_dif_min, Sx$p_dif_min))

cat("\n----- HOW FAR APART ARE THE TWO WINDOWS -----\n")
cat(sprintf("raw SE paths, largest absolute difference : %.4f  (visually coincident)\n",
            gap_raw_abs))
cat(sprintf("identified SE, excl vs full, h >= 1       : %+.1f%% to %+.1f%%\n",
            min(gap_sur[-1]), max(gap_sur[-1])))
cat(sprintf("expected from %d vs %d quarterly clusters  : %+.1f%%\n",
            N_Q_EXCL, N_Q_FULL, 100 * (q_ratio - 1)))
cat("=> the window gap is a cluster-count effect. Do not read it as evidence\n")
cat("   about the shock measure, and do not tie it to the Figure 2 argument.\n")

# ⚠️ The excluded window is NOT negative at all 13 horizons: h=0 is +0.002
#    (se 0.493). Any text saying "every horizon turns negative" is a FULL-window
#    claim only. This guard exists so the difference is impossible to forget.
if (Sx$sur_neg != Sx$n_h) {
  h0 <- lp_x[which(lp_x$b_sur > 0), c("h", "b_sur", "se_sur")]
  cat("\n⚠️  EXCLUDED WINDOW: identified estimate is positive at ",
      nrow(h0), " horizon(s).\n", sep = "")
  print(round(h0, 4), row.names = FALSE)
  cat("    Not a sign reversal — indistinguishable from zero. Do not write\n")
  cat("    \"negative at every horizon\" without the full-window qualifier.\n")
}

cat("\n----- BY HORIZON, FULL WINDOW -----\n")
print(round(lp[, c("h", "b_raw", "se_raw", "p_raw",
                   "b_sur", "se_sur", "p_sur", "se_ratio", "p_diff")], 4),
      row.names = FALSE)

cat("\n----- BY HORIZON, EXCLUDED WINDOW -----\n")
print(round(lp_x[, c("h", "b_raw", "se_raw", "p_raw",
                     "b_sur", "se_sur", "p_sur", "se_ratio", "p_diff")], 4),
      row.names = FALSE)

keep <- c("label", "h", "b_raw", "se_raw", "p_raw", "b_sur", "se_sur", "p_sur",
          "se_ratio", "se_diff", "p_diff", "lo_raw", "hi_raw", "lo_sur", "hi_sur")
write.csv(rbind(lp[, keep], lp_x[, keep]),
          file.path(TAB, "tab_signflip_diagnostics.csv"), row.names = FALSE)


# ==============================================================================
# === SECTION 3.0 — FIGURE 4 (= MANUSCRIPT FIG 5): RAW VS IDENTIFIED ===========
# ==============================================================================
#  FULL WINDOW ONLY, deliberately. Four confidence bands in one frame is
#  unreadable; the excluded window is carried by Figure 6 instead.
#
#  Design note. The y-axis spans the identified band in full and is NOT
#  truncated. The identified interval swallowing zero at every horizon is the
#  result. Cropping it to make the series legible would reintroduce exactly the
#  false confidence this paper is about.
# ==============================================================================

ylim4 <- range(c(lp$lo_raw, lp$hi_raw, lp$lo_sur, lp$hi_sur))
ylim4 <- ylim4 + c(-1, 1) * 0.04 * diff(ylim4)

png(file.path(FIG, "fig4_raw_vs_identified.png"),
    width = 2100, height = 1500, res = 150)

layout(matrix(c(1, 2), nrow = 2), heights = c(0.86, 0.14))
par(mar = c(4.2, 4.6, 3.2, 1.4), family = "sans")

plot(NA, xlim = range(lp$h), ylim = ylim4,
     xlab = "Horizon (quarters after the shock)",
     ylab = "Interaction coefficient (percent)",
     main = "Same design, same data: precision collapses once the cycle is removed",
     cex.main = 1.25, cex.lab = 1.05, las = 1, bty = "n")

# --- 3.1 Bands first, so point estimates draw on top ---
polygon(c(lp$h, rev(lp$h)), c(lp$lo_sur, rev(lp$hi_sur)),
        col = band_sur, border = NA)
polygon(c(lp$h, rev(lp$h)), c(lp$lo_raw, rev(lp$hi_raw)),
        col = band_raw, border = NA)

abline(h = 0, col = "grey35", lwd = 1.1)
grid(nx = NA, ny = NULL, col = "grey88", lty = 1)

# --- 3.2 Point estimates ---
lines(lp$h, lp$b_raw, col = col_raw, lwd = 2.6, type = "b", pch = 16, cex = 0.85)
lines(lp$h, lp$b_sur, col = col_sur, lwd = 2.6, type = "b", pch = 17, cex = 0.85)

# --- 3.3 The one annotation that carries the argument ---
mtext(sprintf(
  "Full window, 2002-2019. Identified standard errors run %.1f to %.1f times wider. No horizon rejects zero.",
  S$ratio_min, S$ratio_max),
  side = 3, line = 0.15, cex = 0.92, col = "grey25")

# --- 3.4 Legend strip beneath the plot ---
par(mar = c(0, 4.6, 0, 1.4))
plot.new()
legend("center", horiz = TRUE, bty = "n", cex = 1.02, seg.len = 2.2,
       legend = c("Raw rate change x exposure (endogenous)",
                  "Identified surprise x exposure (Bauer-Swanson)"),
       col    = c(col_raw, col_sur),
       lwd    = 2.6, pch = c(16, 17))

dev.off()
cat(sprintf("\nwrote: %s\n", file.path(FIG, "fig4_raw_vs_identified.png")))


# ==============================================================================
# === SECTION 4.0 — FIGURE 5 (= MANUSCRIPT FIG 6): THE PRECISION COLLAPSE ======
# ==============================================================================
#  Figure 5 shows the collapse; Figure 6 measures it. Standard errors by
#  horizon on a common axis.
#
#  BOTH WINDOWS, and this is the change of August 12. Encoding: colour is the
#  estimator, line type is the sample window. There are no confidence bands
#  here, only four lines, so the frame stays readable. Results section 5.6 and
#  the Conclusion both state excluded-window numbers; before this, nothing in
#  the figure set supported them.
#
#  What the reader should take from the four lines: the raw and identified paths
#  are an order of magnitude apart in BOTH windows. The full-vs-excluded gap
#  within each estimator is second-order and is explained by cluster count in
#  section 2.1.
# ==============================================================================

png(file.path(FIG, "fig5_precision_collapse.png"),
    width = 2100, height = 1200, res = 150)

layout(matrix(c(1, 2), nrow = 2), heights = c(0.80, 0.20))
par(mar = c(4.2, 4.6, 3.4, 1.4), family = "sans")

ylim5 <- c(0, max(c(lp$se_sur, lp_x$se_sur)) * 1.18)

plot(NA, xlim = range(lp$h), ylim = ylim5,
     xlab = "Horizon (quarters after the shock)",
     ylab = "Standard error",
     main = "Precision is borrowed from the business cycle, not earned from policy",
     cex.main = 1.25, cex.lab = 1.05, las = 1, bty = "n")

grid(nx = NA, ny = NULL, col = "grey88", lty = 1)

# --- 4.1 Excluded window first, dashed and open symbols, so the headline
#         window draws on top of it ---
lines(lp_x$h, lp_x$se_raw, col = col_raw, lwd = 2.0, lty = 2,
      type = "b", pch = 1, cex = 0.78)
lines(lp_x$h, lp_x$se_sur, col = col_sur, lwd = 2.0, lty = 2,
      type = "b", pch = 2, cex = 0.78)

# --- 4.2 Full window, solid and filled ---
lines(lp$h, lp$se_raw, col = col_raw, lwd = 2.6, type = "b", pch = 16, cex = 0.85)
lines(lp$h, lp$se_sur, col = col_sur, lwd = 2.6, type = "b", pch = 17, cex = 0.85)

# --- 4.3 Ratio labels, FULL WINDOW ONLY. Labelling both sets doubles the ink
#         for no added claim; the excluded range is stated in the subtitle.
#  ⚠️ pos = 1 (BELOW the point), not 3. Above the solid identified path is where
#     the dashed excluded path runs, and at h = 1 to 3 the labels collided with
#     its markers. Below is empty space all the way down to the raw paths.
text(lp$h, lp$se_sur, labels = sprintf("%.0fx", lp$se_ratio),
     pos = 1, cex = 0.72, col = "grey30", offset = 0.5)

mtext(sprintf(
  "Identified standard errors run %.1f to %.1f times wider in the full window, and %.1f to %.1f excluding 2009-2012.",
  S$ratio_min, S$ratio_max, Sx$ratio_min, Sx$ratio_max),
  side = 3, line = 0.15, cex = 0.90, col = "grey25")

par(mar = c(0, 4.6, 0, 1.4))
plot.new()
legend("center", ncol = 2, bty = "n", cex = 0.98, seg.len = 2.6,
       legend = c("Raw rate change, full 2002-2019",
                  "Raw rate change, excl 2009-2012",
                  "Identified surprise, full 2002-2019",
                  "Identified surprise, excl 2009-2012"),
       col = c(col_raw, col_raw, col_sur, col_sur),
       lty = c(1, 2, 1, 2),
       pch = c(16, 1, 17, 2),
       lwd = c(2.6, 2.0, 2.6, 2.0))

dev.off()
cat(sprintf("wrote: %s\n", file.path(FIG, "fig5_precision_collapse.png")))


# ==============================================================================
# === SECTION 5.0 — CAPTION TEXT, GENERATED FROM THE ESTIMATES =================
# ==============================================================================
#  Printed rather than hard-coded so the caption cannot drift from the numbers.
# ==============================================================================

# --- 5.1 Guard: the caption asserts "all N horizons". Verify, do not assume. ---
stopifnot(S$raw_pos == S$n_h, S$sur_neg == S$n_h, S$sur_sig == 0, S$dif_sig == 0)

cat("\n----- MANUSCRIPT FIGURE 5 CAPTION  (file fig4_raw_vs_identified.png) -----\n")
cat(sprintf(
"Figure 5. Local projection estimates of the exposure interaction, horizons %d to %d,\n",
  min(lp$h), max(lp$h)))
cat(     "full sample 2002-2019. Shaded regions are 95 percent confidence intervals,\n")
cat(     "standard errors clustered by quarter. The raw estimator uses the realized\n")
cat(     "quarterly change in the federal funds rate; the identified estimator substitutes\n")
cat(     "Bauer-Swanson high-frequency surprises, holding the design fixed. Raw estimates\n")
cat(sprintf(
"are positive at all %d horizons and significant at %d. Identified estimates are\n",
  S$raw_pos, S$raw_sig))
cat(sprintf(
"negative at all %d and significant at none, with standard errors %.1f to %.1f times\n",
  S$sur_neg, S$ratio_min, S$ratio_max))
cat(sprintf(
"wider. The two estimators are not statistically distinguishable at any horizon\n"))
cat(sprintf(
"(smallest p = %.3f, at h = %d), so the figure does not establish a change in sign.\n",
  S$p_dif_min, S$h_closest))
cat(     "It establishes a collapse in precision.\n")

cat("\n----- MANUSCRIPT FIGURE 6 CAPTION  (file fig5_precision_collapse.png) -----\n")
cat(sprintf(
"Figure 6. Standard errors of the local projection estimates by horizon, both sample\n"))
cat(     "windows. Colour distinguishes the shock measure; line type distinguishes the\n")
cat(sprintf(
"window. Identified standard errors run %.1f to %.1f times wider than raw ones over\n",
  S$ratio_min, S$ratio_max))
# ⚠️ "below", not "above". The labels moved in section 4.3 to clear the dashed
#    excluded path, and this sentence has to move with them.
cat(sprintf(
"2002-2019, and %.1f to %.1f times wider excluding 2009-2012. Labels below the\n",
  Sx$ratio_min, Sx$ratio_max))
cat(     "identified path give the ratio at each horizon for the full window. The gap holds\n")
cat(sprintf(
"at every horizon in both windows. The two raw paths are nearly coincident (largest\n"))
cat(sprintf(
"difference %.3f). The identified path is %.0f to %.0f percent higher in the excluded\n",
  gap_raw_abs, min(gap_sur[-1]), max(gap_sur[-1])))
cat(sprintf(
"window from h = 1 onward, which is close to the %.0f percent expected from estimating\n",
  100 * (sqrt(N_Q_FULL / N_Q_EXCL) - 1)))
cat(sprintf(
"on %d quarterly clusters rather than %d. Point estimates are in Figure 5; raw\n",
  N_Q_EXCL, N_Q_FULL))
cat(sprintf(
"estimates are significant at %d of %d horizons in both windows and identified\n",
  S$raw_sig, S$n_h))
cat(     "estimates at none.\n")

# --- 5.2 The one asymmetry between windows, printed so it cannot be forgotten ---
if (Sx$sur_neg != Sx$n_h) {
  cat(sprintf(
"\n⚠️  CAVEAT FOR ANY TEXT ABOUT THE EXCLUDED WINDOW: identified estimates are\n"))
  cat(sprintf(
"    negative at %d of %d horizons there, not all %d. Qualify accordingly.\n",
    Sx$sur_neg, Sx$n_h, Sx$n_h))
}

cat("\n----- DONE -----\n")

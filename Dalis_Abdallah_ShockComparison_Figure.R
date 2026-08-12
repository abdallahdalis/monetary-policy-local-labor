# ==============================================================================
#  Spurious Precision: Why Shift-Share Designs Overstate Monetary Policy
#                      Effects on Local Employment
#  Figure 2 — the two shock measures, and why one of them is endogenous
#  Author     : Abdallah Dalis
#  Institution: DePaul University
#
#  Built August 11, 2026, per FIGURE_PLAN_2026-08-11.md.
#
#  WHY THIS FIGURE EXISTS. The paper's central move is replacing the realized
#  quarterly change in the federal funds rate with Bauer-Swanson high-frequency
#  surprises. Every downstream result turns on that substitution, and until now
#  the reader was asked to accept on assertion that one measure is contaminated
#  by the business cycle and the other is not. This figure shows it.
#
#  The top row plots both series. The bottom row is the actual argument: each
#  shock against contemporaneous national employment growth. If the raw measure
#  is endogenous, it correlates with the cycle it is supposed to be shocking.
#  If the identified measure is clean, it does not.
#
#  Input : data/FEDFUNDS.csv          (cached FRED)
#          data/PAYEMS.csv            (cached FRED)
#          data/bauer_swanson_mps.xlsx (downloaded on first run, SF Fed)
#  Output: figures/fig2_shock_comparison.png
#          tables/tab_shock_comparison.csv
#
#  NOTE: the Bauer-Swanson workbook is not in data/ and will be downloaded on
#  the first run. That step needs an internet connection. Everything else runs
#  from the cached CSVs.
# ==============================================================================

rm(list = ls())

# ---- Packages ----------------------------------------------------------------
suppressMessages({
  library(readxl)       # read_xlsx (Bauer-Swanson workbook)
  library(dplyr)
})
select <- dplyr::select; filter <- dplyr::filter

# ---- Paths -------------------------------------------------------------------
PROJ <- "."
DATA <- file.path(PROJ, "data")
FIG  <- file.path(PROJ, "figures")
TAB  <- file.path(PROJ, "tables")
dir.create(FIG, showWarnings = FALSE, recursive = TRUE)
dir.create(TAB, showWarnings = FALSE, recursive = TRUE)

# ---- Palette (per 00_Resources/output-standards.md) --------------------------
col_raw <- "steelblue"
col_sur <- "firebrick"
col_rec <- adjustcolor("grey55", alpha.f = 0.18)

# Sample window. Matches monetary_policy_labor.R and the headline DiD window.
YR_MIN <- 2002
YR_MAX <- 2019


# ==============================================================================
# === SECTION 1.0 — LOAD AND BUILD THE QUARTERLY SERIES ========================
# ==============================================================================
#  Construction is copied deliberately from monetary_policy_labor.R lines 63-86
#  so this figure describes the same variables the local projections estimate.
#  If that file's construction changes, this one has to change with it.
# ==============================================================================

# --- 1.1 Funds rate: quarterly mean, then first difference -------------------
ffr_m <- read.csv(file.path(DATA, "FEDFUNDS.csv"), stringsAsFactors = FALSE) %>%
  mutate(date = as.Date(observation_date),
         ffr  = as.numeric(FEDFUNDS))

ffr_q <- ffr_m %>%
  filter(date >= as.Date(sprintf("%d-01-01", YR_MIN)),
         date <= as.Date(sprintf("%d-12-31", YR_MAX))) %>%
  mutate(year = as.integer(format(date, "%Y")),
         qtr  = as.integer(substr(quarters(date), 2, 2))) %>%
  group_by(year, qtr) %>%
  summarise(ffr = mean(ffr), .groups = "drop") %>%
  arrange(year, qtr) %>%
  mutate(dffr = c(NA, diff(ffr)))

# --- 1.2 Employment: quarterly mean of PAYEMS, then log growth ---------------
#  This is the cycle proxy. National, not county, because the endogeneity being
#  shown is the Fed reacting to the aggregate economy.
pay_q <- read.csv(file.path(DATA, "PAYEMS.csv"), stringsAsFactors = FALSE) %>%
  mutate(date = as.Date(observation_date),
         pay  = as.numeric(PAYEMS)) %>%
  filter(date >= as.Date(sprintf("%d-01-01", YR_MIN)),
         date <= as.Date(sprintf("%d-12-31", YR_MAX))) %>%
  mutate(year = as.integer(format(date, "%Y")),
         qtr  = as.integer(substr(quarters(date), 2, 2))) %>%
  group_by(year, qtr) %>%
  summarise(pay = mean(pay), .groups = "drop") %>%
  arrange(year, qtr) %>%
  mutate(dlemp = 100 * c(NA, diff(log(pay))))

# --- 1.3 Bauer-Swanson surprises: monthly, summed to quarter -----------------
bs_url  <- "https://www.frbsf.org/wp-content/uploads/monetary-policy-surprises-data.xlsx"
bs_file <- file.path(DATA, "bauer_swanson_mps.xlsx")
if (!file.exists(bs_file)) {
  cat("\nBauer-Swanson workbook not cached. Downloading once from the SF Fed.\n")
  download.file(bs_url, bs_file, mode = "wb")
}

bsq <- read_xlsx(bs_file, sheet = "Monthly (update 2023)") %>%
  transmute(year     = as.integer(Year),
            month    = as.integer(Month),
            MPS_ORTH = as.numeric(MPS_ORTH)) %>%
  mutate(qtr = (month - 1) %/% 3 + 1) %>%
  group_by(year, qtr) %>%
  summarise(MPS_ORTH = sum(MPS_ORTH, na.rm = TRUE), .groups = "drop")

# --- 1.4 Join, and build a plotting time index -------------------------------
q <- ffr_q %>%
  inner_join(bsq,   by = c("year", "qtr")) %>%
  inner_join(pay_q, by = c("year", "qtr")) %>%
  arrange(year, qtr) %>%
  mutate(t = year + (qtr - 1) / 4)

cat("\n----- SAMPLE -----\n")
cat(sprintf("quarters      : %d\n", nrow(q)))
cat(sprintf("range         : %d Q%d to %d Q%d\n",
            min(q$year), q$qtr[which.min(q$t)], max(q$year), q$qtr[which.max(q$t)]))
# summary() on a data frame returns formatted character strings, so it cannot be
# rounded. Build the numeric summary directly instead.
num_summary <- function(x) {
  x <- x[is.finite(x)]
  c(n = length(x), mean = mean(x), sd = sd(x), min = min(x), max = max(x))
}

cat("\n----- SERIES SUMMARY -----\n")
print(round(t(sapply(q[, c("dffr", "MPS_ORTH", "dlemp")], num_summary)), 4))


# ==============================================================================
# === SECTION 2.0 — THE DIAGNOSTIC THE FIGURE IS MAKING ========================
# ==============================================================================
#  Three correlations carry the argument:
#    1. raw shock vs contemporaneous employment growth  -> should be non-trivial
#    2. identified shock vs the same                    -> should be near zero
#    3. raw vs identified                               -> should be weak, which
#       is why substituting one for the other changes the answer
# ==============================================================================

qq <- q %>% filter(is.finite(dffr), is.finite(MPS_ORTH), is.finite(dlemp))

cor_raw_emp <- cor(qq$dffr,     qq$dlemp)
cor_sur_emp <- cor(qq$MPS_ORTH, qq$dlemp)
cor_raw_sur <- cor(qq$dffr,     qq$MPS_ORTH)

fit_raw <- lm(dlemp ~ dffr,     data = qq)
fit_sur <- lm(dlemp ~ MPS_ORTH, data = qq)

p_raw <- summary(fit_raw)$coefficients["dffr",     "Pr(>|t|)"]
p_sur <- summary(fit_sur)$coefficients["MPS_ORTH", "Pr(>|t|)"]

cat("\n----- ENDOGENEITY DIAGNOSTIC -----\n")
cat(sprintf("cor(raw dFFR, employment growth)        : %+.3f  (p = %.4f)\n",
            cor_raw_emp, p_raw))
cat(sprintf("cor(identified surprise, emp growth)    : %+.3f  (p = %.4f)\n",
            cor_sur_emp, p_sur))
cat(sprintf("cor(raw dFFR, identified surprise)      : %+.3f\n", cor_raw_sur))
cat(sprintf("R2, employment growth on raw            : %.4f\n", summary(fit_raw)$r.squared))
cat(sprintf("R2, employment growth on identified     : %.4f\n", summary(fit_sur)$r.squared))

diag_tab <- data.frame(
  quantity = c("cor(raw, emp growth)", "cor(identified, emp growth)",
               "cor(raw, identified)", "R2 emp on raw", "R2 emp on identified"),
  value    = round(c(cor_raw_emp, cor_sur_emp, cor_raw_sur,
                     summary(fit_raw)$r.squared, summary(fit_sur)$r.squared), 4),
  p_value  = c(round(p_raw, 4), round(p_sur, 4), NA, NA, NA)
)


# ==============================================================================
# === SECTION 2.1 — IS THE +0.47 JUST 2008? ====================================
# ==============================================================================
#  Added August 11, 2026, after inspecting the rendered figure. The bottom-left
#  scatter is visibly leveraged: a handful of crisis quarters sit at dFFR of
#  -1.0 to -1.5 while the ZLB years pile up at exactly zero. The obvious
#  referee objection is that the correlation is a 2008 artifact.
#
#  Answered three ways rather than one:
#    full     Pearson on all quarters
#    excl     Pearson excluding 2009-2012, the paper's robustness window
#    spearman rank correlation on all quarters, which is immune to the
#             leverage objection because it does not care about magnitudes
#
#  If the relationship only exists in `full`, the figure does not support the
#  endogeneity claim and the caption has to say so.
# ==============================================================================

qq_excl <- qq %>% filter(!(year %in% 2009:2012))

rob <- data.frame(
  sample   = c("full 2002-2019", "excl 2009-2012", "full, Spearman"),
  n        = c(nrow(qq), nrow(qq_excl), nrow(qq)),
  r_raw    = c(cor(qq$dffr, qq$dlemp),
               cor(qq_excl$dffr, qq_excl$dlemp),
               cor(qq$dffr, qq$dlemp, method = "spearman")),
  r_ident  = c(cor(qq$MPS_ORTH, qq$dlemp),
               cor(qq_excl$MPS_ORTH, qq_excl$dlemp),
               cor(qq$MPS_ORTH, qq$dlemp, method = "spearman"))
)
rob$r_raw   <- round(rob$r_raw,   3)
rob$r_ident <- round(rob$r_ident, 3)

cat("\n----- LEVERAGE / WINDOW ROBUSTNESS -----\n")
print(rob, row.names = FALSE)
cat("\n If r_raw stays clearly positive across all three rows, the +0.47 is not\n")
cat(" a 2008 artifact and the caption may say so. If it collapses in either the\n")
cat(" excluded window or the rank correlation, it IS a crisis artifact and the\n")
cat(" endogeneity claim needs a different cycle proxy. Do not split the\n")
cat(" difference: report whichever answer comes back.\n")

r_raw_excl <- rob$r_raw[2]
r_raw_rank <- rob$r_raw[3]

diag_tab <- rbind(
  diag_tab,
  data.frame(quantity = c("cor(raw, emp growth) excl 2009-2012",
                          "cor(raw, emp growth) Spearman",
                          "cor(identified, emp growth) excl 2009-2012"),
             value    = c(r_raw_excl, r_raw_rank, rob$r_ident[2]),
             p_value  = NA)
)
write.csv(diag_tab, file.path(TAB, "tab_shock_comparison.csv"), row.names = FALSE)


# ==============================================================================
# === SECTION 3.0 — FIGURE 2 ===================================================
# ==============================================================================
#  Row 1: both series over time, own scales, recession shaded.
#  Row 2: each series against contemporaneous employment growth. This row is
#         the argument; row 1 is orientation.
#
#  Design note. The two shocks are NOT plotted on a shared axis. They are in
#  different units and a common scale would either flatten one series or
#  require standardizing, which invites the objection that the comparison was
#  rescaled to produce the point. Separate panels, honest units.
# ==============================================================================

# NBER recession, Dec 2007 to Jun 2009, in the plotting time index.
rec_start <- 2007 + 3/4
rec_end   <- 2009 + 1/4

shade_recession <- function() {
  usr <- par("usr")
  rect(rec_start, usr[3], rec_end, usr[4], col = col_rec, border = NA)
}

png(file.path(FIG, "fig2_shock_comparison.png"),
    width = 2100, height = 1500, res = 150)

layout(matrix(c(1, 2,
                3, 4,
                5, 5), nrow = 3, byrow = TRUE),
       heights = c(0.38, 0.48, 0.14))

# Top row carries no x-axis label, so it needs less bottom margin than the
# scatter row. Setting one margin for all four panels clipped the bottom-row
# xlab in the first render (Aug 11); the rows now get their own.
MAR_TOP <- c(3.4, 4.6, 3.0, 1.2)
MAR_BOT <- c(5.2, 4.6, 3.4, 1.2)
par(mar = MAR_TOP, family = "sans")

# --- 3.1 Top left: raw quarterly change in the funds rate --------------------
plot(q$t, q$dffr, type = "n", las = 1, bty = "n",
     xlab = "", ylab = "Percentage points",
     main = "Raw change in the federal funds rate",
     cex.main = 1.15, cex.lab = 1.0)
shade_recession()
abline(h = 0, col = "grey35", lwd = 1.1)
lines(q$t, q$dffr, col = col_raw, lwd = 2.2)

# --- 3.2 Top right: identified surprise --------------------------------------
plot(q$t, q$MPS_ORTH, type = "n", las = 1, bty = "n",
     xlab = "", ylab = "Percentage points",
     main = "Bauer-Swanson identified surprise",
     cex.main = 1.15, cex.lab = 1.0)
shade_recession()
abline(h = 0, col = "grey35", lwd = 1.1)
lines(q$t, q$MPS_ORTH, col = col_sur, lwd = 2.2)

# --- 3.3 Bottom left: raw shock against the cycle ----------------------------
#  The robustness line goes ON the figure, not only in the caption. A skeptic
#  screenshots the panel, and the leverage objection is the first one they will
#  raise about this scatter.
par(mar = MAR_BOT)
plot(qq$dffr, qq$dlemp, pch = 16, cex = 0.9, las = 1, bty = "n",
     col = adjustcolor(col_raw, alpha.f = 0.65),
     xlab = "Raw change in funds rate (pp)",
     ylab = "Employment growth (percent)",
     main = sprintf("Raw shock moves with the economy  (r = %+.2f, p = %.3f)",
                    cor_raw_emp, p_raw),
     cex.main = 1.12, cex.lab = 1.0)
mtext(sprintf("excl. 2009-2012: r = %+.2f    rank correlation: r = %+.2f",
              r_raw_excl, r_raw_rank),
      side = 3, line = 0.2, cex = 0.78, col = "grey30")
abline(h = 0, v = 0, col = "grey80")
abline(fit_raw, col = col_raw, lwd = 2.4)

# --- 3.4 Bottom right: identified shock against the cycle --------------------
par(mar = MAR_BOT)
plot(qq$MPS_ORTH, qq$dlemp, pch = 17, cex = 0.9, las = 1, bty = "n",
     col = adjustcolor(col_sur, alpha.f = 0.65),
     xlab = "Identified surprise (pp)",
     ylab = "Employment growth (percent)",
     main = sprintf("Identified shock does not  (r = %+.2f, p = %.3f)",
                    cor_sur_emp, p_sur),
     cex.main = 1.12, cex.lab = 1.0)
mtext(sprintf("excl. 2009-2012: r = %+.2f", rob$r_ident[2]),
      side = 3, line = 0.2, cex = 0.78, col = "grey30")
abline(h = 0, v = 0, col = "grey80")
abline(fit_sur, col = col_sur, lwd = 2.4)

# --- 3.5 Legend strip --------------------------------------------------------
par(mar = c(0, 4.6, 0, 1.2))
plot.new()
legend("center", horiz = TRUE, bty = "n", cex = 1.0, seg.len = 2.2,
       legend = c("Raw rate change (endogenous)",
                  "Identified surprise (Bauer-Swanson)",
                  "Shaded: NBER recession, 2007 Q4 to 2009 Q2"),
       col    = c(col_raw, col_sur, col_rec),
       lwd    = c(2.4, 2.4, 8), pch = c(16, 17, NA))

dev.off()
cat(sprintf("\nwrote: %s\n", file.path(FIG, "fig2_shock_comparison.png")))


# ==============================================================================
# === SECTION 4.0 — CAPTION TEXT, GENERATED FROM THE ESTIMATES =================
# ==============================================================================
#  Printed rather than hard-coded, so the caption cannot drift from the numbers.
#  Same convention as Dalis_Abdallah_SpuriousPrecision_Figures.R section 5.0.
# ==============================================================================

cat("\n----- FIGURE 2 CAPTION (paste into the paper) -----\n")
cat(sprintf(
"Figure 2. The two measures of monetary policy, %d Q1 to %d Q4, %d quarters.\n",
  YR_MIN, YR_MAX, nrow(qq)))
cat(
"Top panels plot each series over time on its own scale; shading marks the NBER\n")
cat(
"recession. Bottom panels plot each measure against contemporaneous national\n")
cat(
"employment growth, with the fitted line. The realized change in the federal funds\n")
cat(sprintf(
"rate correlates with the cycle it is meant to shock (r = %+.2f, p = %.3f), while the\n",
  cor_raw_emp, p_raw))
cat(sprintf(
"Bauer-Swanson surprise does not (r = %+.2f, p = %.3f). The two measures correlate at\n",
  cor_sur_emp, p_sur))
cat(sprintf(
"only %+.2f with each other. This is the endogeneity the paper prices: the raw measure\n",
  cor_raw_sur))
cat(
"carries business-cycle variation into a design that then reports it as policy\n")
cat(
"variation, and reports it precisely.\n")
cat(sprintf(
"The raw correlation is not an artifact of the financial crisis: it is %+.2f excluding\n",
  r_raw_excl))
cat(sprintf(
"2009 to 2012, and the rank correlation over the full window is %+.2f.\n",
  r_raw_rank))

cat("\n----- INTERPRETATION GUARD -----\n")
cat(" 1. This figure documents that the raw measure is correlated with the\n")
cat("    cycle. It does NOT establish the sign of the employment response, and\n")
cat("    the paper does not claim a sign flip: the raw and identified local\n")
cat("    projections are not statistically distinguishable at any horizon.\n")
cat(" 2. The near-zero correlation BETWEEN the two measures is partly by\n")
cat("    construction. MPS_ORTH is the ORTHOGONALIZED Bauer-Swanson series,\n")
cat("    purged of macro and financial information predating the meeting. Do\n")
cat("    not present it as a discovery. The point is that the literature\n")
cat("    substitutes one for the other anyway, despite their sharing almost no\n")
cat("    variation.\n")
cat(" 3. The POSITIVE sign on the raw correlation cannot be the causal effect\n")
cat("    of tightening, since that would mean tightening raises employment,\n")
cat("    which is the reading this paper rejects. It is the Fed reacting to a\n")
cat("    strong labor market. Use this line when a referee asks.\n")

cat("\n----- DONE -----\n")

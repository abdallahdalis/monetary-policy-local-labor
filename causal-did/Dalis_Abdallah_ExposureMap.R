# ==============================================================================
#  Spurious Precision: Why Shift-Share Designs Overstate Monetary Policy
#                      Effects on Local Employment
#  Figure 1 — county exposure map, 2002
#  Author     : Abdallah Dalis
#  Institution: DePaul University
#
#  Written August 12, 2026.
#
#  ------------------------------------------------------------------------------
#  WHY THIS SCRIPT EXISTS AT ALL.
#
#  `causal-did/output/figures/exposure_map_2002.pdf` has been the paper's Figure 1
#  since commit 85558e0, and NOTHING IN THE REPOSITORY PRODUCES IT. A search for
#  every plausible mapping call — exposure_map, choropleth, usmap, geom_sf, maps::
#  — returns no hits in any .R or .do file. The figure is an orphan artifact.
#
#  That is a worse problem than the figure being stale. A paper arguing that
#  applied work should show its diagnostics cannot carry a headline figure that
#  cannot be regenerated. The orphan is ALSO on the defective exposure measure,
#  so it is wrong as well as unreproducible, but the reproducibility hole is the
#  part that would still be there after a correction.
#
#  This script replaces it. It writes to a NEW filename so the orphan stays on
#  disk as provenance until Abdallah decides to retire it.
#
#  ⚠️ I could not execute this. There is no R in the environment it was drafted
#  in. Treat the first run as a test: the verification block in section 3 is
#  written to catch a silent failure, particularly counties dropped by a FIPS
#  join mismatch, which is the usual way a county choropleth goes quietly wrong.
#
#  Input : data/cbp_exposure_2002_rebuilt.dta
#  Output: causal-did/output/figures/exposure_map_2002_rebuilt.pdf
#          causal-did/output/tables/tab_exposure_map_check.csv
#  Run from the PROJECT ROOT.
# ==============================================================================

rm(list = ls())
suppressMessages({ library(dplyr); library(haven) })

for (p in c("usmap", "ggplot2")) if (!requireNamespace(p, quietly = TRUE))
  stop(sprintf("Package '%s' is required. install.packages('%s')", p, p))
suppressMessages({ library(usmap); library(ggplot2) })

PROJ <- "."
FIG  <- file.path(PROJ, "causal-did", "output", "figures")
TAB  <- file.path(PROJ, "causal-did", "output", "tables")
dir.create(FIG, showWarnings = FALSE, recursive = TRUE)

EXPO <- file.path(PROJ, "data", "cbp_exposure_2002_rebuilt.dta")
if (!file.exists(EXPO)) stop(
  "Rebuilt exposure not found at ", EXPO,
  ". Run causal-did/Dalis_Abdallah_RebuildExposure.R from the project root first.")

exp02 <- read_dta(EXPO) %>%
  transmute(fips = sprintf("%05s", as.character(area_fips)),
            exposure = as.numeric(exp_sens_2002))

cat(sprintf("\nexposure file : %s\ncounties      : %d\n", EXPO, nrow(exp02)))


# ==============================================================================
# === SECTION 1.0 — JOIN AGAINST THE MAP, AND COUNT WHAT FALLS OUT =============
# ==============================================================================
#  The failure mode of a county choropleth is a silent FIPS mismatch: the plot
#  renders, looks fine, and quietly omits several hundred counties. Count first.

#  ⚠️ GEOGRAPHY VINTAGE, and this is the real bug behind the Connecticut gap.
#
#  usmap 1.0.0 ships 2022 boundaries. Connecticut abolished its eight counties
#  for statistical purposes in 2022 and the package carries the nine planning
#  regions (09110-09190) instead, so every legacy CT FIPS (09001-09015) in a 2002
#  file fails to match and Connecticut renders as blank "no data". The pre-2015
#  Alaska census areas (02201-02280) fail for the same reason.
#
#  Connecticut is where it is VISIBLE, but the defect is general: this is 2002
#  data drawn on 2022 boundaries. The fix is to match the geography to the data
#  vintage, not to patch Connecticut.
#
#  ⚠️ CORRECTED August 12, 2026. This note first said to downgrade `usmap` to
#  0.6.1. That does NOT work: the boundaries do not live in usmap, they live in
#  the `usmapdata` companion package, and usmap 0.6.1 against usmapdata 1.1.0
#  still returns the nine planning regions. Pin the DATA package:
#
#      remotes::install_version("usmapdata", version = "0.2.0")
#
#  Verified pin: usmap 0.6.1 + usmapdata 0.2.0 -> 8 legacy CT counties present,
#  unmatched falls from 60 to 7. The residual 7 are genuine post-2002 FIPS
#  changes and are expected: five Alaska census areas (02201/02232/02261/02270/
#  02280), Shannon County SD -> Oglala Lakota (46113), and Bedford City VA
#  (51515), which merged into Bedford County in 2013.
#
#  The 95 percent match gate did not catch this — 3,111 of 3,171 is 98.1 percent,
#  and an entire state can go missing inside a 1.9 percent shortfall. The gate
#  below is therefore now per-STATE as well as overall.
county_geo <- usmap::us_map(regions = "counties")
geo_fips   <- unique(county_geo$fips)

# --- Per-state coverage. A whole state at zero coverage is invisible in an
#     aggregate match rate and is exactly what happened to Connecticut.
cover <- exp02 %>%
  mutate(st = substr(fips, 1, 2), ok = fips %in% geo_fips) %>%
  group_by(st) %>%
  summarise(n = n(), matched = sum(ok), rate = mean(ok), .groups = "drop") %>%
  arrange(rate)
cat("\n--- per-state map coverage, worst five ---\n"); print(head(cover, 5), n = 5)
if (any(cover$rate < 0.5))
  stop("At least one state matched under half its counties. The map geography ",
       "does not match the data vintage. See the note above; do not plot this.")

matched   <- intersect(exp02$fips, geo_fips)
unmatched <- setdiff(exp02$fips, geo_fips)   # in our data, not on the map
missing   <- setdiff(geo_fips, exp02$fips)   # on the map, no exposure value

cat(sprintf("map polygons  : %d\nmatched       : %d\nunmatched     : %d\nno data       : %d\n",
            length(geo_fips), length(matched), length(unmatched), length(missing)))

if (length(unmatched) > 0) {
  cat("\n⚠️ counties in the exposure file that the map does not recognise:\n")
  print(head(sort(unmatched), 25))
  cat("   Usually 02xxx/46xxx FIPS recodes or territories. Confirm they are\n")
  cat("   genuinely absent from the map rather than a zero-padding failure.\n")
}

write.csv(data.frame(
  quantity = c("exposure counties", "map polygons", "matched", "unmatched", "no data"),
  value    = c(nrow(exp02), length(geo_fips), length(matched),
               length(unmatched), length(missing))),
  file.path(TAB, "tab_exposure_map_check.csv"), row.names = FALSE)

if (length(matched) < 0.95 * nrow(exp02))
  stop("Fewer than 95 percent of counties matched the map. Fix the join before plotting.")


# ==============================================================================
# === SECTION 2.0 — THE MAP ====================================================
# ==============================================================================
#  Per 00_Resources/output-standards.md: ink-light, one muted accent, bottom line
#  readable fast. A sequential single-hue ramp, because exposure is a share with
#  a meaningful zero and no natural midpoint. No diverging palette: it would
#  invent a reference point the measure does not have.

brks <- c(0, 0.10, 0.20, 0.30, 0.40, 0.80)
exp02 <- exp02 %>%
  mutate(band = cut(exposure, breaks = brks, include.lowest = TRUE,
                    labels = c("under 0.10", "0.10 to 0.20", "0.20 to 0.30",
                               "0.30 to 0.40", "over 0.40")))

p <- plot_usmap(data = exp02, values = "band", regions = "counties",
                color = NA, linewidth = 0) +
  scale_fill_manual(
    values = c("under 0.10"    = "#F2EFEA",
               "0.10 to 0.20"  = "#D9C6C2",
               "0.20 to 0.30"  = "#C09B96",
               "0.30 to 0.40"  = "#A5665F",
               "over 0.40"     = "#8A1C1C"),
    na.value = "grey92", name = NULL, drop = FALSE) +
  labs(
    title = "Exposure is regional, not idiosyncratic",
    subtitle = sprintf(
      "Share of county employment in construction and manufacturing, 2002. %d counties. Median %.3f, tenth to ninetieth percentile %.3f to %.3f.",
      nrow(exp02), median(exp02$exposure),
      quantile(exp02$exposure, .10), quantile(exp02$exposure, .90))) +
  theme(legend.position = "bottom",
        plot.title    = element_text(face = "bold", size = 13),
        plot.subtitle = element_text(size = 9, colour = "grey30"))

#  Device note, August 12, 2026. This previously specified device = cairo_pdf.
#  On a machine without XQuartz, cairo_pdf fails to load libXrender and R raises
#  a WARNING rather than an error, so ggsave wrote nothing while the script
#  happily printed "wrote:". Use the base pdf() device, which has no cairo
#  dependency, and assert the file exists rather than trusting the call.
MAP_PDF <- file.path(FIG, "exposure_map_2002_rebuilt.pdf")
if (file.exists(MAP_PDF)) file.remove(MAP_PDF)
ggsave(MAP_PDF, p, width = 10, height = 6.6)

if (!file.exists(MAP_PDF) || file.size(MAP_PDF) < 10000)
  stop("ggsave did not produce a usable PDF at ", MAP_PDF,
       ". Check the graphics device; a cairo failure is only a warning.")
cat(sprintf("\nwrote: %s (%.0f KB)\n", MAP_PDF, file.size(MAP_PDF) / 1024))


# ==============================================================================
# === SECTION 3.0 — VERIFY THE MAP AGAINST THE STATE TABLE =====================
# ==============================================================================
#  Section 5.1 of the paper names the highest and lowest states. Those come from
#  tab_exposure_by_state.csv. If the map is built from the same file they must
#  agree, and if they do not, ONE OF THE TWO IS WRONG. This is the check that
#  would have caught the New England error on August 11.

st <- exp02 %>%
  mutate(state_fips = as.integer(substr(fips, 1, 2))) %>%
  group_by(state_fips) %>%
  summarise(mean_exp = mean(exposure, na.rm = TRUE), .groups = "drop") %>%
  arrange(desc(mean_exp))

cat("\n----- TOP 10 STATES AS PLOTTED -----\n"); print(head(st, 10), n = 10)
cat("\n----- BOTTOM 10 -----\n");                print(tail(st, 10), n = 10)

ref_path <- file.path(TAB, "tab_exposure_by_state.csv")
if (file.exists(ref_path)) {
  ref <- read.csv(ref_path)
  chk <- merge(st, ref[, c("state_fips", "mean_exp")], by = "state_fips",
               suffixes = c("_map", "_ref"))
  worst <- max(abs(chk$mean_exp_map - chk$mean_exp_ref))
  cat(sprintf("\nSELF-CHECK vs tab_exposure_by_state.csv : worst gap %.2e\n", worst))
  if (worst > 1e-6)
    stop("The map and the state table disagree. Section 5.1 is written from the ",
         "table; resolve before trusting either.")
  cat("SELF-CHECK OK — the map and section 5.1 are the same measure.\n")
} else {
  cat("\n⚠️ tab_exposure_by_state.csv absent; run Dalis_Abdallah_ExposureDescriptives.R.\n")
}

cat("\n----- DONE -----\n")
cat("The orphan causal-did/output/figures/exposure_map_2002.pdf is UNTOUCHED.\n")
cat("Retire it deliberately once this output is checked.\n")

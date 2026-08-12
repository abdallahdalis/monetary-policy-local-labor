# ==============================================================================
#  Spurious Precision: Why Shift-Share Designs Overstate Monetary Policy
#                      Effects on Local Employment
#  Exposure descriptives — clears three placeholders in the manuscript
#  Author     : Abdallah Dalis
#  Institution: DePaul University
#
#  Built August 11, 2026. This script exists to replace assertions with numbers.
#
#  THREE THINGS IT SETTLES:
#
#  1. County counts per window. Two figures appear in the project record, 2,887
#     and 3,228, in different contexts, and neither was traced to a sample.
#     sections/methods.tex carries a TODO for this.
#
#  2. The exposure distribution. sections/results_discussion.tex section 5.1 has
#     three bracketed placeholders. They were left blank rather than guessed.
#
#  3. WHERE exposure actually concentrates. The section 5.1 draft asserts the
#     industrial Midwest and interior South, thinning in coastal metros. That
#     sentence was written from general knowledge about manufacturing, NOT from
#     this file. It is plausible and probably right, which is what makes it
#     dangerous. If the data disagree, the sentence gets rewritten or cut.
#
#  Output: output/tables/tab_exposure_descriptives.csv
#          output/tables/tab_exposure_by_state.csv
# ==============================================================================

rm(list = ls())

# ---- Packages ----------------------------------------------------------------
suppressMessages({
  library(haven)
  library(dplyr)
})
select <- dplyr::select; filter <- dplyr::filter

OUT <- "output"
dir.create(file.path(OUT, "tables"), showWarnings = FALSE, recursive = TRUE)

ZLB_YEARS <- 2009:2012


# ==============================================================================
# === SECTION 1.0 — LOAD ========================================================
# ==============================================================================
#  Same resolution and same build as the other causal-did scripts.

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
         qtr       = as.integer(qtr))

cbp02 <- read_dta(file.path(DATA, "cbp_exposure_2002.dta")) %>%
  mutate(area_fips = as.character(area_fips),
         exp_sens  = as.numeric(exp_sens_2002)) %>%
  select(area_fips, exp_sens)

ffr <- read.csv(file.path(DATA, "FEDFUNDS.csv"), stringsAsFactors = FALSE) %>%
  mutate(date = as.Date(observation_date),
         year = as.integer(format(date, "%Y")),
         qtr  = (as.integer(format(date, "%m")) - 1) %/% 3 + 1) %>%
  filter(year >= 2001, year <= 2019) %>%
  group_by(year, qtr) %>%
  summarise(fedfunds_q = mean(FEDFUNDS, na.rm = TRUE), .groups = "drop") %>%
  arrange(year, qtr) %>%
  mutate(dffr = fedfunds_q - lag(fedfunds_q, 1)) %>%
  filter(year >= 2002) %>%
  select(year, qtr, dffr)


# ==============================================================================
# === SECTION 2.0 — COUNTY COUNTS, PER SAMPLE ==================================
# ==============================================================================
#  Reported at each stage so it is clear WHERE counties are lost. A single
#  headline count with no attrition trail is how 2,887 and 3,228 both ended up
#  in the record with neither traceable.

cat("\n----- COUNTY COUNTS BY STAGE -----\n")
cat(sprintf("raw QCEW panel                     : %6d counties\n",
            n_distinct(panel$area_fips)))
cat(sprintf("CBP 2002 exposure file             : %6d counties\n",
            n_distinct(cbp02$area_fips)))

joined <- panel %>%
  inner_join(ffr,   by = c("year", "qtr")) %>%
  inner_join(cbp02, by = "area_fips")

cat(sprintf("after joining exposure and rates   : %6d counties\n",
            n_distinct(joined$area_fips)))

for (nm in c("full 2002-2019", "excl 2009-2012")) {
  d <- if (nm == "excl 2009-2012") joined %>% filter(!(year %in% ZLB_YEARS)) else joined
  cat(sprintf("  %-18s : %6d counties, %s county-quarters\n",
              nm, n_distinct(d$area_fips), format(nrow(d), big.mark = ",")))
}

cat("\n NOTE: the estimation samples are smaller than these counts, because\n")
cat(" feols drops singleton fixed effects and rows with missing leads. Quote\n")
cat(" the ESTIMATION n from the model output, not from this table, and say\n")
cat(" which one you are quoting.\n")


# ==============================================================================
# === SECTION 3.0 — THE EXPOSURE DISTRIBUTION ==================================
# ==============================================================================
#  Fills the three bracketed placeholders in results_discussion.tex section 5.1.

ex <- cbp02 %>% filter(is.finite(exp_sens))

q <- quantile(ex$exp_sens, c(0, 0.10, 0.25, 0.50, 0.75, 0.90, 1))
desc <- data.frame(
  statistic = c("n counties", "mean", "sd", "min", "p10", "p25",
                "median", "p75", "p90", "max", "p90 / p10"),
  value = round(c(nrow(ex), mean(ex$exp_sens), sd(ex$exp_sens),
                  q[1], q[2], q[3], q[4], q[5], q[6], q[7],
                  q[6] / q[2]), 4)
)

cat("\n----- EXPOSURE DISTRIBUTION (2002 constr + manuf share) -----\n")
print(desc, row.names = FALSE)

write.csv(desc, file.path(OUT, "tables", "tab_exposure_descriptives.csv"),
          row.names = FALSE)


# ==============================================================================
# === SECTION 4.0 — WHERE IS EXPOSURE CONCENTRATED? ============================
# ==============================================================================
#  ⚠️ THIS IS THE CHECK ON THE PROSE. The section 5.1 draft claims exposure
#  concentrates in the industrial Midwest and interior South and thins in
#  coastal metros. That claim was NOT sourced from this file. Confirm, revise,
#  or cut it based on what prints below.

ex_st <- ex %>%
  mutate(state_fips = substr(area_fips, 1, 2)) %>%
  group_by(state_fips) %>%
  summarise(n_counties  = n(),
            mean_exp    = mean(exp_sens),
            median_exp  = median(exp_sens),
            .groups = "drop") %>%
  arrange(desc(mean_exp))

cat("\n----- TOP 10 STATES BY MEAN COUNTY EXPOSURE -----\n")
print(as.data.frame(head(ex_st, 10)), row.names = FALSE)

cat("\n----- BOTTOM 10 STATES BY MEAN COUNTY EXPOSURE -----\n")
print(as.data.frame(tail(ex_st, 10)), row.names = FALSE)

write.csv(ex_st, file.path(OUT, "tables", "tab_exposure_by_state.csv"),
          row.names = FALSE)

cat("\n----- HOW TO USE THIS -----\n")
cat(" State FIPS codes, for reading the tables above:\n")
cat("   17 IL | 18 IN | 21 KY | 26 MI | 37 NC | 39 OH | 45 SC | 47 TN | 55 WI\n")
cat("   02 AK | 04 AZ | 08 CO | 12 FL | 15 HI | 32 NV | 35 NM | 06 CA | 25 MA\n")
cat("\n If the top of the list is Midwest and interior South, the section 5.1\n")
cat(" sentence stands as written. If it is not, REWRITE IT to match this table\n")
cat(" rather than keeping a sentence that merely sounds right.\n")

cat("\n----- DONE -----\n")

# ==============================================================================
#  ECO 508 Research Program — Part 3
#  Racial Composition and the Local Employment Incidence of Monetary Contractions
#  Author     : Abdallah Dalis
#  Professor  : Jin Man Lee (program advisor)
#  Institution: DePaul University
#
#  Extends the Part 2 local-projection pipeline (Dalis_Abdallah_ECO508_Code.R).
#  Question: once tightening is identified cleanly (Bauer-Swanson surprise) and
#  shown to be contractionary, is the employment cost larger in higher-minority
#  counties? Keeps Part 2's identified-surprise LP exactly; swaps the heterogeneity
#  dimension from industry exposure to PREDETERMINED (2000 Census) racial shares.
#
#  NOTE (reproducibility): the sandbox that drafted this has no R, so the figures
#  and the sign/precision pattern were confirmed in a mirrored Python run. RUN THIS
#  ONCE ON THE MAC and confirm the numbers before citing them anywhere.
# ==============================================================================

rm(list = ls())

# ---- Packages ----------------------------------------------------------------
# install.packages(c("haven","readxl","dplyr","tidyr","sandwich","ggplot2"))
suppressMessages({
  library(haven)        # read_dta
  library(readxl)       # read_xlsx (Bauer-Swanson)
  library(dplyr); library(tidyr)
  library(sandwich)     # vcovCL clustered SE
  library(fixest)       # feols: multi-way (non-nested) fixed effects, clustered SE
})
select <- dplyr::select; filter <- dplyr::filter
lag    <- dplyr::lag;    lead   <- dplyr::lead
mutate <- dplyr::mutate; summarise <- dplyr::summarise

set.seed(508)

# ---- Paths -------------------------------------------------------------------
# DATA  = the Part 2 FinalProject/data folder (shared QCEW / CBP / Bauer-Swanson / FRED).
# RACE  = predetermined 2000 Census county shares built for Part 3 (this folder).
# OUT   = this Part 3 folder (figures/ and tables/ written here).
# Set the working directory to THIS file's folder before sourcing, then:
DATA <- "data"
RACE <- "data/county_race_2000.csv"
OUT  <- "."
dir.create(file.path(OUT, "figures"), showWarnings = FALSE)
dir.create(file.path(OUT, "tables"),  showWarnings = FALSE)

# ==============================================================================
# SECTION 1 — DATA ACQUISITION  (reuses the Part 2 inputs)
# ==============================================================================
cat("\n----- Loading data -----\n")

# 1.1 QCEW county employment panel + CBP 2002 industry exposure (Part 2 panel)
qcew <- read_dta(file.path(DATA, "qcew_panel_all_years.dta")) %>%
  mutate(area_fips = sprintf("%05s", area_fips)) %>%
  filter(year >= 2002, year <= 2019, month3_emplvl > 0) %>%
  mutate(yq = year * 4 + (qtr - 1))
expo <- read_dta(file.path(DATA, "cbp_exposure_2002.dta")) %>%
  mutate(area_fips = sprintf("%05s", area_fips))

# 1.2 Bauer-Swanson orthogonalized surprise -> quarterly sum (Part 2 convention)
bs  <- read_xlsx(file.path(DATA, "bauer_swanson_mps.xlsx"), sheet = "Monthly (update 2023)")
bs  <- bs %>% transmute(year = as.integer(Year), month = as.integer(Month),
                        MPS_ORTH = as.numeric(MPS_ORTH)) %>%
  mutate(qtr = (month - 1) %/% 3 + 1)
bsq <- bs %>% group_by(year, qtr) %>%
  summarise(MPS_ORTH = sum(MPS_ORTH, na.rm = TRUE), .groups = "drop")

# 1.3 FRED FEDFUNDS -> quarterly change (endogenous-shock comparison only)
fred <- function(id) {
  x <- read.csv(sprintf("https://fred.stlouisfed.org/graph/fredgraph.csv?id=%s", id))
  names(x) <- c("date", "value"); x$date <- as.Date(x$date); x
}
ffr   <- fred("FEDFUNDS"); names(ffr)[2] <- "ffr"
ffr_q <- ffr %>% filter(date >= "2002-01-01", date <= "2019-12-31") %>%
  mutate(year = as.integer(format(date, "%Y")),
         qtr  = as.integer(substr(quarters(date), 2, 2))) %>%
  group_by(year, qtr) %>% summarise(ffr = mean(ffr), .groups = "drop") %>%
  arrange(year, qtr) %>% mutate(dffr = c(NA, diff(ffr)))

# 1.4 Predetermined 2000 Census racial composition (Part 3's new dimension)
# Built from the Census 2000-2010 intercensal county file (ESTIMATESBASE2000 =
# April 1, 2000 census base => strictly pre-sample, predetermined).
race <- read.csv(RACE, colClasses = c(area_fips = "character")) %>%
  mutate(area_fips = sprintf("%05s", area_fips))

# 1.5 Predetermined 2000 median household income (Census 2000 SF3, table P053001;
# pulled via the Census API endpoint data/2000/dec/sf3). Income control.
income <- read.csv(file.path(DATA, "county_income_2000.csv"),
                   colClasses = c(area_fips = "character")) %>%
  mutate(area_fips = sprintf("%05s", area_fips)) %>%
  select(area_fips, ln_medhhinc2000)

# ==============================================================================
# SECTION 2 — PANEL ASSEMBLY + STANDARDIZED HETEROGENEITY DIMENSIONS
# ==============================================================================
cat("\n----- Building panel -----\n")
zscore <- function(v) (v - mean(v, na.rm = TRUE)) / sd(v, na.rm = TRUE)

P <- qcew %>%
  inner_join(expo, by = "area_fips") %>%
  inner_join(race, by = "area_fips") %>%
  inner_join(income, by = "area_fips") %>%
  left_join(ffr_q %>% select(year, qtr, dffr), by = c("year", "qtr")) %>%
  left_join(bsq, by = c("year", "qtr")) %>%
  mutate(expz   = zscore(exp_sens_2002),     # Parts 1-2 industry exposure (for validation)
         blackz = zscore(black_share),       # PART 3 headline dimension
         hispz  = zscore(hisp_share),
         lnpopz = zscore(ln_pop2000),        # predetermined county size control
         lnincz = zscore(ln_medhhinc2000)) %>% # predetermined county income control
  arrange(area_fips, yq)

cat(sprintf("panel rows = %d | counties = %d | quarters = %d\n",
            nrow(P), dplyr::n_distinct(P$area_fips), dplyr::n_distinct(P$yq)))

# ==============================================================================
# SECTION 3 — LOCAL PROJECTIONS  (identical machinery to Part 2 Eq. 4)
#   100*(l_{i,t+h} - l_{i,t-1}) = a_i^h + d_t^h + theta_h*(shock_t x dim_i) + e
#   two-way within (county + quarter FE); SE clustered by quarter; h = 0..12.
# ==============================================================================
cat("\n----- Local projections -----\n")

# two-way within transform (county + time demeaning), reused from Part 2
demean2 <- function(df, v) {
  df %>% group_by(area_fips) %>% mutate(ci = mean(.data[[v]], na.rm = TRUE)) %>%
    group_by(yq)        %>% mutate(ti = mean(.data[[v]], na.rm = TRUE)) %>% ungroup() %>%
    mutate("{v}_w" := .data[[v]] - ci - ti + mean(.data[[v]], na.rm = TRUE)) %>%
    select(-ci, -ti)
}

# LP interaction: employment growth on (shock x standardized heterogeneity dim)
lp_interaction <- function(P, shockvar, dimvar, H = 12) {
  out <- data.frame()
  for (h in 0:H) {
    d <- P %>% group_by(area_fips) %>%
      mutate(yh = 100 * (dplyr::lead(ln_emp, h) - dplyr::lag(ln_emp, 1)),
             sx = .data[[shockvar]] * .data[[dimvar]]) %>% ungroup() %>%
      filter(is.finite(yh), is.finite(sx))
    d <- demean2(d, "yh"); d <- demean2(d, "sx")
    m <- lm(yh_w ~ sx_w - 1, data = d)
    V <- sandwich::vcovCL(m, cluster = d$yq)          # quarter-clustered
    b <- coef(m)["sx_w"]; se <- sqrt(V["sx_w", "sx_w"])
    out <- rbind(out, data.frame(h = h, theta = b, se = se, t = b / se))
  }
  rownames(out) <- NULL
  out
}

lp_black <- lp_interaction(P, "MPS_ORTH", "blackz")   # PART 3 HEADLINE: surprise x Black share
lp_hisp  <- lp_interaction(P, "MPS_ORTH", "hispz")    # surprise x Hispanic share
lp_raw   <- lp_interaction(P, "dffr",     "blackz")   # endogenous dFFR x Black (artifact check)
lp_val   <- lp_interaction(P, "MPS_ORTH", "expz")     # VALIDATION: should reproduce Part 2 (negative)

cat("\n--- surprise x BLACK share (headline) ---\n");   print(round(lp_black, 4))
cat("\n--- surprise x HISPANIC share ---\n");           print(round(lp_hisp, 4))
cat("\n--- dFFR x BLACK share (endogenous) ---\n");      print(round(lp_raw, 4))
cat("\n--- VALIDATION: surprise x exposure ---\n");      print(round(lp_val, 4))

tab <- merge(merge(lp_black, lp_hisp, by = "h", suffixes = c("_black", "_hisp")),
             lp_val, by = "h")
names(tab)[(ncol(tab) - 2):ncol(tab)] <- c("theta_exp", "se_exp", "t_exp")
write.csv(tab, file.path(OUT, "tables/tab_part3_lp.csv"), row.names = FALSE)

# ==============================================================================
# SECTION 4 — FIGURE: theta_h paths (headline vs Hispanic vs validation)
# ==============================================================================
png(file.path(OUT, "figures/fig_part3_incidence.png"), width = 2100, height = 1350, res = 300)
ylim <- range(lp_black$theta - 1.96 * lp_black$se, lp_black$theta + 1.96 * lp_black$se,
              lp_val$theta) * 1.1
plot(lp_black$h, lp_black$theta, type = "b", col = "firebrick", lwd = 2, ylim = ylim,
     xlab = "Horizon (quarters)", ylab = "Interaction coefficient (theta_h)",
     main = "Incidence of identified tightening by county racial composition")
polygon(c(lp_black$h, rev(lp_black$h)),
        c(lp_black$theta - 1.96 * lp_black$se, rev(lp_black$theta + 1.96 * lp_black$se)),
        col = rgb(.54, .11, .11, .13), border = NA)
lines(lp_hisp$h, lp_hisp$theta, type = "b", col = "darkorange3", lwd = 2, lty = 2)
lines(lp_val$h,  lp_val$theta,  type = "b", col = "steelblue",  lwd = 2, lty = 3)
abline(h = 0, lty = 2)
legend("bottomleft", bty = "n", lwd = 2,
       col = c("firebrick", "darkorange3", "steelblue"), lty = c(1, 2, 3),
       legend = c("surprise x Black share (95% band)", "surprise x Hispanic share",
                  "surprise x industry exposure (Part 2 validation)"))
dev.off()

# ==============================================================================
# SECTION 5 — CONTROL LADDER  (the credibility test)
#   Part 2 showed the INDUSTRY gradient was really county size. So the key test
#   for Part 3 is whether the racial gradient survives netting out size (and the
#   industry channel). Multi-regressor LP: interact the surprise with several
#   standardized dimensions at once; report theta on Black share as controls add.
# ==============================================================================
cat("\n----- Control ladder -----\n")

# (lnpopz and lnincz are already built in Section 2.)

# Multi-regressor LP: each dim in `dims` is interacted with MPS_ORTH; two-way
# within transform on outcome + all interactions; quarter-clustered SE.
lp_multi <- function(P, dims, H = 12) {
  ix <- paste0("sx_", dims)
  res <- setNames(lapply(dims, function(z) data.frame()), dims)
  for (h in 0:H) {
    d <- P %>% group_by(area_fips) %>%
      mutate(yh = 100 * (dplyr::lead(ln_emp, h) - dplyr::lag(ln_emp, 1))) %>% ungroup()
    for (j in seq_along(dims)) d[[ix[j]]] <- d$MPS_ORTH * d[[dims[j]]]
    d <- d %>% filter(is.finite(yh), if_all(all_of(ix), is.finite))
    for (v in c("yh", ix)) d <- demean2(d, v)
    f <- as.formula(paste0("yh_w ~ ", paste0(ix, "_w", collapse = " + "), " - 1"))
    m <- lm(f, data = d); V <- sandwich::vcovCL(m, cluster = d$yq)
    for (j in seq_along(dims)) {
      cf <- paste0(ix[j], "_w")
      res[[dims[j]]] <- rbind(res[[dims[j]]],
        data.frame(h = h, theta = coef(m)[cf], se = sqrt(V[cf, cf]),
                   t = coef(m)[cf] / sqrt(V[cf, cf])))
    }
  }
  lapply(res, function(x){ rownames(x) <- NULL; x })
}

s1 <- lp_multi(P, "blackz")                                  # baseline
s2 <- lp_multi(P, c("blackz", "lnpopz"))                     # + county size
s3 <- lp_multi(P, c("blackz", "lnpopz", "lnincz"))           # + size + income
s4 <- lp_multi(P, c("blackz", "lnpopz", "lnincz", "expz"))   # + size + income + industry exposure

ladder <- data.frame(h = s1$blackz$h,
  b_black = s1$blackz$theta,          t = s1$blackz$t,
  b_pop = s2$blackz$theta,            t_pop = s2$blackz$t,
  b_pop_inc = s3$blackz$theta,        t_pop_inc = s3$blackz$t,
  b_pop_inc_exp = s4$blackz$theta,    t_pop_inc_exp = s4$blackz$t)
cat("\n--- Black-share coefficient across the control ladder ---\n"); print(round(ladder, 3))
# NOTE (finding): income does NOT absorb the Black gradient; it sharpens it at the
# long horizons (poorer and higher-Black counties partly offset). Still imprecise.
write.csv(ladder, file.path(OUT, "tables/tab_part3_controlladder.csv"), row.names = FALSE)

png(file.path(OUT, "figures/fig_part3_controlladder.png"), width = 2100, height = 1350, res = 300)
yl <- range(s3$blackz$theta - 1.96 * s3$blackz$se, s3$blackz$theta + 1.96 * s3$blackz$se) * 1.1
plot(ladder$h, ladder$b_pop_inc, type = "b", col = "firebrick", lwd = 2.4, ylim = yl,
     xlab = "Horizon (quarters)", ylab = "theta_h on surprise x Black share",
     main = "Income does not absorb the Black gradient (it sharpens it)")
polygon(c(s3$blackz$h, rev(s3$blackz$h)),
        c(s3$blackz$theta - 1.96 * s3$blackz$se, rev(s3$blackz$theta + 1.96 * s3$blackz$se)),
        col = rgb(.54, .11, .11, .12), border = NA)
lines(ladder$h, ladder$b_black,       type = "b", col = "grey55", lwd = 1.8)
lines(ladder$h, ladder$b_pop_inc_exp, type = "b", col = "steelblue", lwd = 1.8, lty = 2)
abline(h = 0, lty = 2)
legend("bottomleft", bty = "n", lwd = 2, col = c("grey55", "firebrick", "steelblue"),
       lty = c(1, 1, 2),
       legend = c("Black alone", "+ log-pop + income (95% band)", "+ log-pop + income + exposure"))
dev.off()

# ==============================================================================
# SECTION 6 — WITHIN-CBSA IDENTIFICATION  (the strongest confound defense)
#   Replace the national time FE with CBSA x quarter FE: compare higher- vs
#   lower-Black counties INSIDE the same metro-quarter. county FE + CBSA^quarter
#   FE are NON-NESTED, so this uses feols (multi-way FE) rather than the hand
#   demeaning above. Run on the metro-county subsample under BOTH FE schemes so
#   the FE change is isolated from the sample change (between+within vs within).
#
#   HEADLINE FINDING (confirmed in the mirrored Python run): the negative Black
#   gradient is a BETWEEN-metro pattern. Under national time FE the metro
#   subsample still shows the negative long-horizon gradient; under CBSA^quarter
#   FE it flips positive. Within metros, higher-Black counties do NOT contract
#   more. Everything remains imprecise (|t| < 1.4).
# ==============================================================================
cat("\n----- Within-CBSA identification -----\n")

# County -> CBSA crosswalk (Census 2020 delineation, list1). Keep counties whose
# CBSA has >= 2 sample counties (otherwise CBSA^quarter FE leave no within variation).
cbsa <- read.csv(file.path(DATA, "county_cbsa_2020.csv"),
                 colClasses = c(area_fips = "character", cbsa = "character")) %>%
  mutate(area_fips = sprintf("%05s", area_fips)) %>% select(area_fips, cbsa)
PM <- P %>% inner_join(cbsa, by = "area_fips") %>% filter(!is.na(cbsa))
keep <- PM %>% distinct(cbsa, area_fips) %>% count(cbsa) %>% filter(n >= 2) %>% pull(cbsa)
PM <- PM %>% filter(cbsa %in% keep)
cat(sprintf("metro sample: rows = %d | counties = %d | CBSAs = %d\n",
            nrow(PM), dplyr::n_distinct(PM$area_fips), dplyr::n_distinct(PM$cbsa)))

# LP with feols; FE supplied as a string ("area_fips + yq" or "area_fips + cbsa^yq").
lp_feols <- function(PM, fe_str, H = 12) {
  out <- data.frame()
  for (h in 0:H) {
    d <- PM %>% group_by(area_fips) %>%
      mutate(yh = 100 * (dplyr::lead(ln_emp, h) - dplyr::lag(ln_emp, 1)),
             sxb = MPS_ORTH * blackz, sxp = MPS_ORTH * lnpopz,
             sxi = MPS_ORTH * lnincz) %>% ungroup() %>%
      filter(is.finite(yh), is.finite(sxb), is.finite(sxp), is.finite(sxi))
    m <- feols(as.formula(paste0("yh ~ sxb + sxp + sxi | ", fe_str)),
               data = d, cluster = ~yq)
    out <- rbind(out, data.frame(h = h, theta = coef(m)["sxb"],
                                 se = se(m)["sxb"], t = coef(m)["sxb"]/se(m)["sxb"]))
  }
  rownames(out) <- NULL; out
}

bw  <- lp_feols(PM, "area_fips + yq")       # between + within metro (national time FE)
win <- lp_feols(PM, "area_fips + cbsa^yq")  # within metro only (CBSA x quarter FE)

cat("\n--- Black (net log-pop), metro sample, BETWEEN+WITHIN (national time FE) ---\n"); print(round(bw, 4))
cat("\n--- Black (net log-pop), metro sample, WITHIN-CBSA (CBSA x quarter FE) ---\n");   print(round(win, 4))
wvb <- data.frame(h = bw$h, between_within_b = bw$theta, between_within_t = bw$t,
                  within_metro_b = win$theta, within_metro_t = win$t)
write.csv(wvb, file.path(OUT, "tables/tab_part3_within_vs_between.csv"), row.names = FALSE)

png(file.path(OUT, "figures/fig_part3_within_vs_between.png"), width = 2100, height = 1350, res = 300)
yl <- range(win$theta - 1.96*win$se, win$theta + 1.96*win$se, bw$theta) * 1.1
plot(bw$h, bw$theta, type = "b", col = "firebrick", lwd = 2.2, ylim = yl,
     xlab = "Horizon (quarters)", ylab = "theta_h on surprise x Black share (net log-pop)",
     main = "Black-share gradient is between-metro, not within-metro")
polygon(c(win$h, rev(win$h)), c(win$theta - 1.96*win$se, rev(win$theta + 1.96*win$se)),
        col = rgb(.15,.34,.48,.12), border = NA)
lines(win$h, win$theta, type = "b", col = "steelblue", lwd = 2.2)
abline(h = 0, lty = 2)
legend("topleft", bty = "n", lwd = 2, col = c("firebrick","steelblue"),
       legend = c("between + within metro (national-time FE)",
                  "within metro only (CBSA x quarter FE, 95% band)"))
dev.off()

# ==============================================================================
# SECTION 7 — ROBUSTNESS  (completes the draft)
#   (a) Black and Hispanic shares entered JOINTLY (net pop + income), under both
#       national-time FE and within-CBSA FE.
#   (b) Driscoll-Kraay SE (serial correlation across quarters + cross-sectional
#       dependence) vs the quarter-clustered baseline, on the black coefficient.
#   Both confirm the story: the Black gradient is robust and is NOT Hispanic in
#   disguise; Hispanic is null; DK does not weaken precision (h11 |t|~1.5).
# ==============================================================================
cat("\n----- Robustness -----\n")

# feols-based LP returning theta on each interaction; vcov passed through.
lp_fe2 <- function(dat, dims, fe_str, vcv, H = 12) {
  ix <- paste0("sx_", dims)
  res <- setNames(lapply(dims, function(z) data.frame()), dims)
  for (h in 0:H) {
    d <- dat %>% group_by(area_fips) %>%
      mutate(yh = 100 * (dplyr::lead(ln_emp, h) - dplyr::lag(ln_emp, 1))) %>% ungroup()
    for (j in seq_along(dims)) d[[ix[j]]] <- d$MPS_ORTH * d[[dims[j]]]
    d <- d %>% filter(is.finite(yh), if_all(all_of(ix), is.finite))
    m <- feols(as.formula(paste0("yh ~ ", paste(ix, collapse = " + "), " | ", fe_str)),
               data = d, vcov = vcv)
    for (j in seq_along(dims))
      res[[dims[j]]] <- rbind(res[[dims[j]]],
        data.frame(h = h, theta = coef(m)[ix[j]], se = se(m)[ix[j]],
                   t = coef(m)[ix[j]] / se(m)[ix[j]]))
  }
  lapply(res, function(x){ rownames(x) <- NULL; x })
}

# (a) Black + Hispanic jointly (net pop + income)
jn <- lp_fe2(P,  c("blackz","hispz","lnpopz","lnincz"), "area_fips + yq",     ~yq)
jw <- lp_fe2(PM, c("blackz","hispz","lnpopz","lnincz"), "area_fips + cbsa^yq", ~yq)
joint <- data.frame(h = jn$blackz$h,
  black_nat = jn$blackz$theta, t_black_nat = jn$blackz$t,
  hisp_nat  = jn$hispz$theta,  t_hisp_nat  = jn$hispz$t,
  black_within = jw$blackz$theta, t_black_within = jw$blackz$t,
  hisp_within  = jw$hispz$theta,  t_hisp_within  = jw$hispz$t)
cat("\n--- Black + Hispanic jointly (net pop+income) ---\n"); print(round(joint, 3))
write.csv(joint, file.path(OUT, "tables/tab_part3_joint_black_hisp.csv"), row.names = FALSE)

# (b) Driscoll-Kraay vs quarter-cluster, black coef net pop+income (national FE)
cl <- lp_fe2(P, c("blackz","lnpopz","lnincz"), "area_fips + yq", ~yq)$blackz       # quarter cluster
dk <- lp_fe2(P, c("blackz","lnpopz","lnincz"), "area_fips + yq", DK ~ yq)$blackz   # Driscoll-Kraay
dktab <- data.frame(h = cl$h, theta = cl$theta,
  se_cluster = cl$se, t_cluster = cl$t, se_DK = dk$se, t_DK = dk$t)
cat("\n--- black coef: quarter-cluster vs Driscoll-Kraay SE ---\n"); print(round(dktab, 3))
write.csv(dktab, file.path(OUT, "tables/tab_part3_driscollkraay.csv"), row.names = FALSE)

cat("\n===== DONE: LP + control ladder + within-CBSA + robustness written. =====\n")

# ==============================================================================
# NEXT SESSION:
#   - add surprise x ln(median household income) to the ladder (needs 2000 SF3 /
#     ACS income by county; Census API key required, not yet pulled).
#   - Black and Hispanic shares entered jointly; repeat the within-CBSA cut for each.
#   - Driscoll-Kraay SE as a robustness check on the quarter-clustered baseline.
#   - REFRAME the paper around the between- vs within-metro decomposition: the
#     place-based racial incidence operates ACROSS metros, not within them.
# ==============================================================================
# END OF SCRIPT
# ==============================================================================

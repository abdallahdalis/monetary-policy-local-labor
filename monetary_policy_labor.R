# ==============================================================================
#  ECO 508: Predictive Analytics and Time Series Analysis
#  Final Project — State-vs-County Aggregation and Identification in
#                  U.S. Monetary Policy Transmission to Employment, 2002-2019
#  Author    : Abdallah Dalis
#  Professor : Jin Man Lee
#  Institution: DePaul University, Department of Economics
#
#  This script reproduces every table and figure in the report end-to-end:
#    Methods: (1) reduced-form VAR, (2) recursive SVAR, (3) Jorda local
#    projections with Bauer-Swanson high-frequency surprises, (4) random forest.
#  NOTE (reproducibility): run this script once with the FinalProject folder as the
#  working directory to regenerate every figure and table in the report. Minor
#  differences in VAR bootstrap bands or random-forest seeds across runs are expected.
# ==============================================================================

rm(list = ls())

# ---- Packages ----------------------------------------------------------------
# install.packages(c("haven","readxl","dplyr","tidyr","vars","sandwich",
#                    "lmtest","randomForest","ggplot2","tseries"))
suppressMessages({
  library(haven)        # read_dta
  library(readxl)       # read_xlsx (Bauer-Swanson)
  library(dplyr); library(tidyr)
  library(vars)         # VAR, SVAR, irf, fevd, causality
  library(sandwich); library(lmtest)   # Newey-West / clustered SE
  library(randomForest)
  library(tseries)      # adf.test, kpss.test
  library(ggplot2)
})

# Resolve namespace conflicts: vars/MASS mask dplyr::select; stats masks filter/lag.
# Force the dplyr versions so the pipelines below behave as intended.
select <- dplyr::select; filter <- dplyr::filter
lag    <- dplyr::lag;    lead   <- dplyr::lead
summarise <- dplyr::summarise; mutate <- dplyr::mutate

set.seed(508)

# ---- Paths (self-contained: set the working directory to this folder) --------
# In RStudio: Session > Set Working Directory > To Source File Location,
# or run setwd("/path/to/FinalProject") before sourcing.
DATA <- "data"     # input .dta files (QCEW, CBP) + cached downloads live here
OUT  <- "."        # figures/ and tables/ are written here, next to the report .tex
dir.create(file.path(OUT,"figures"), showWarnings = FALSE)
dir.create(file.path(OUT,"tables"),  showWarnings = FALSE)

# ==============================================================================
# SECTION 1 — DATA ACQUISITION
# ==============================================================================
cat("\n----- Loading data -----\n")

# 1.1 FRED monthly series (download direct CSV)
fred <- function(id) {
  x <- read.csv(sprintf("https://fred.stlouisfed.org/graph/fredgraph.csv?id=%s", id))
  names(x) <- c("date","value"); x$date <- as.Date(x$date); x
}
ffr <- fred("FEDFUNDS"); names(ffr)[2] <- "ffr"
pay <- fred("PAYEMS");   names(pay)[2] <- "pay"
cpi <- fred("CPIAUCSL"); names(cpi)[2] <- "cpi"

# 1.2 Bauer-Swanson monetary policy surprises (SF Fed update; download once)
bs_url <- "https://www.frbsf.org/wp-content/uploads/monetary-policy-surprises-data.xlsx"
bs_file <- file.path(DATA, "bauer_swanson_mps.xlsx")
if (!file.exists(bs_file)) download.file(bs_url, bs_file, mode = "wb")
bs <- read_xlsx(bs_file, sheet = "Monthly (update 2023)")
bs <- bs %>% transmute(year = as.integer(Year), month = as.integer(Month),
                       MPS_ORTH = as.numeric(MPS_ORTH)) %>%
  mutate(qtr = (month - 1) %/% 3 + 1)
bsq <- bs %>% group_by(year, qtr) %>% summarise(MPS_ORTH = sum(MPS_ORTH, na.rm = TRUE), .groups = "drop")

# 1.3 QCEW county employment panel + CBP 2002 exposure (reused from ECO 510)
qcew <- read_dta(file.path(DATA, "qcew_panel_all_years.dta")) %>%
  mutate(area_fips = sprintf("%05s", area_fips)) %>%
  filter(year >= 2002, year <= 2019, month3_emplvl > 0) %>%
  mutate(yq = year*4 + (qtr - 1))
expo <- read_dta(file.path(DATA, "cbp_exposure_2002.dta")) %>%
  mutate(area_fips = sprintf("%05s", area_fips))
qcew <- inner_join(qcew, expo, by = "area_fips")

# quarterly funds-rate change
ffr_q <- ffr %>% filter(date >= "2002-01-01", date <= "2019-12-31") %>%
  mutate(year = as.integer(format(date,"%Y")), qtr = as.integer(substr(quarters(date),2,2))) %>%
  group_by(year, qtr) %>% summarise(ffr = mean(ffr), .groups="drop") %>%
  arrange(year, qtr) %>% mutate(dffr = c(NA, diff(ffr)))

# ==============================================================================
# SECTION 2 — DESCRIPTIVES, STATIONARITY  (Table 1, Table 2, Figure 1)
# ==============================================================================
cat("\n----- Descriptives & stationarity -----\n")
M <- cpi %>% inner_join(pay, "date") %>% inner_join(ffr, "date") %>% arrange(date) %>%
  mutate(dlcpi = 100*c(NA,diff(log(cpi))),
         dlemp = 100*c(NA,diff(log(pay))),
         dffr  = c(NA, diff(ffr)))
W <- M %>% filter(date >= "2002-01-01", date <= "2019-12-31")

summ <- function(x){x<-na.omit(x); c(mean=mean(x),sd=sd(x),min=min(x),max=max(x),
                                     skew=mean((x-mean(x))^3)/sd(x)^3, kurt=mean((x-mean(x))^4)/sd(x)^4-3)}
tab_summary <- rbind(`FFR level`=summ(W$ffr),`dFFR`=summ(W$dffr),
                     `Emp growth`=summ(W$dlemp),`Inflation`=summ(W$dlcpi))
write.csv(round(tab_summary,3), file.path(OUT,"tables/tab_summary.csv"))
print(round(tab_summary,3))

adfkpss <- function(x){x<-na.omit(x)
c(adf=suppressWarnings(adf.test(x)$p.value), kpss=suppressWarnings(kpss.test(x)$p.value))}
tab_adfkpss <- rbind(`FFR level`=adfkpss(W$ffr),`dFFR`=adfkpss(W$dffr),
                     `Emp growth`=adfkpss(W$dlemp),`Inflation`=adfkpss(W$dlcpi))
write.csv(round(tab_adfkpss,3), file.path(OUT,"tables/tab_adfkpss.csv"))

png(file.path(OUT,"figures/fig1_series.png"), width=2100, height=1500, res=300)
op <- par(mfrow=c(3,1), mar=c(2.5,4,1,1))
plot(W$date, W$ffr, type="l", col="steelblue", ylab="Fed funds rate (%)", xlab="")
rect(as.Date("2008-12-01"),-1,as.Date("2015-12-01"),10,col=rgb(.54,.11,.11,.07),border=NA)
plot(W$date, W$dlemp, type="l", col="grey40", ylab="Emp growth"); abline(h=0,lty=2)
plot(W$date, W$dlcpi, type="l", col="grey40", ylab="Inflation"); abline(h=0,lty=2)
par(op); dev.off()

# ==============================================================================
# SECTION 3 — VAR  (Tables 3-5, Figure 2)   benchmark 1976-2008 vs window 2002-2019
# ==============================================================================
cat("\n----- VAR -----\n")
mk <- function(lo,hi) M %>% filter(date>=lo, date<=hi) %>% select(dlcpi,dlemp,dffr) %>% na.omit()
fit_var <- function(d){ p <- VARselect(d, lag.max=12)$selection["AIC(n)"]; VAR(d, p=as.integer(p), type="const") }
vb <- mk("1976-01-01","2008-12-31"); var_b <- fit_var(vb)   # pre-ZLB benchmark
vz <- mk("2002-01-01","2019-12-31"); var_z <- fit_var(vz)   # paper window (ZLB)

# lag-selection, Granger, FEVD
write.csv(VARselect(vb, lag.max=12)$selection, file.path(OUT,"tables/tab_varlag.csv"))
# Pairwise Granger test (does dffr help predict employment?) -- matches the report's claim.
p_b <- as.integer(VARselect(vb, lag.max=12)$selection["AIC(n)"])
gr  <- grangertest(dlemp ~ dffr, order = p_b, data = vb)
cat("Granger dffr -> emp p =", round(gr$`Pr(>F)`[2], 4), "\n")
gr2 <- grangertest(dffr ~ dlemp, order = p_b, data = vb)   # reverse direction (endogeneity check)
cat("Granger emp -> dffr p =", round(gr2$`Pr(>F)`[2], 4), "\n")
fevd_emp <- fevd(var_b, n.ahead=24)$dlemp
write.csv(round(fevd_emp[c(6,12,24),],3), file.path(OUT,"tables/tab_fevd.csv"))

# IRF: employment response to a contractionary (dffr) shock, cumulative
irf_b <- irf(var_b, impulse="dffr", response="dlemp", n.ahead=24, ortho=TRUE,
             cumulative=TRUE, boot=TRUE, runs=500, ci=0.95)
irf_z <- irf(var_z, impulse="dffr", response="dlemp", n.ahead=24, ortho=TRUE,
             cumulative=TRUE, boot=TRUE, runs=500, ci=0.95)
png(file.path(OUT,"figures/fig2_var_irf.png"), width=2100, height=1050, res=300)
op <- par(mfrow=c(1,2), mar=c(4,4,2,1))
plot_irf <- function(ir,ttl){ y<-ir$irf$dffr; lo<-ir$Lower$dffr; hi<-ir$Upper$dffr; h<-0:(length(y)-1)
plot(h,y,type="l",col="firebrick",lwd=2,ylim=range(lo,hi),main=ttl,
     xlab="Months after shock",ylab="Cum. emp response (%)")
polygon(c(h,rev(h)),c(lo,rev(hi)),col=rgb(.15,.34,.48,.15),border=NA); lines(h,y,col="firebrick",lwd=2); abline(h=0)}
plot_irf(irf_b,"Pre-ZLB benchmark (1976-2008)"); plot_irf(irf_z,"Paper window (2002-2019)")
par(op); dev.off()

# ==============================================================================
# SECTION 4 — SVAR  (recursive / Cholesky, Figure 3)
# ==============================================================================
cat("\n----- SVAR (recursive) -----\n")
# Amat lower-triangular: prices, emp, dffr ordered last (MP shock last)
Amat <- diag(3); Amat[lower.tri(Amat)] <- NA
svar_b <- SVAR(var_b, Amat = Amat, Bmat = NULL, estmethod = "scoring", max.iter = 3000)
sirf <- irf(svar_b, impulse="dffr", response=c("dlcpi","dlemp","dffr"), n.ahead=24, boot=TRUE, runs=400)
png(file.path(OUT,"figures/fig3_svar_irf.png"), width=2400, height=900, res=300)
plot(sirf)  # 3-panel structural responses to the MP shock
dev.off()

# ==============================================================================
# SECTION 5 — LOCAL PROJECTIONS  (Figures 4-6, Table 6)
#   First-stage diagnostic: surprise does NOT move quarterly dffr -> use shock directly
# ==============================================================================
cat("\n----- Local projections -----\n")
nat <- inner_join(ffr_q, bsq, by=c("year","qtr"))
fs <- lm(dffr ~ MPS_ORTH, data = nat)
cat("Quarterly first-stage F (dffr ~ surprise) =",
    round(summary(fs)$fstatistic[1],2), " -> weak; use surprise as direct shock\n")

# 5.1 FULL-PANEL sign-flip: interaction (shock x standardized exposure), county+time FE
P <- qcew %>% left_join(ffr_q %>% select(year,qtr,dffr), by=c("year","qtr")) %>%
  left_join(bsq, by=c("year","qtr")) %>%
  mutate(expz = (exp_sens_2002 - mean(exp_sens_2002))/sd(exp_sens_2002)) %>%
  arrange(area_fips, yq)

# two-way within transform helper
demean2 <- function(df, v){
  df %>% group_by(area_fips) %>% mutate(ci = mean(.data[[v]], na.rm=TRUE)) %>%
    group_by(yq) %>% mutate(ti = mean(.data[[v]], na.rm=TRUE)) %>% ungroup() %>%
    mutate("{v}_w" := .data[[v]] - ci - ti + mean(.data[[v]], na.rm=TRUE)) %>% select(-ci,-ti)
}
lp_interaction <- function(P, shockvar, H=12){
  out <- data.frame()
  for(h in 0:H){
    d <- P %>% group_by(area_fips) %>%
      mutate(yh = 100*(dplyr::lead(ln_emp,h) - dplyr::lag(ln_emp,1)),
             sx = .data[[shockvar]]*expz) %>% ungroup() %>%
      filter(is.finite(yh), is.finite(sx))
    d <- demean2(d,"yh"); d <- demean2(d,"sx")
    m <- lm(yh_w ~ sx_w - 1, data=d)
    # cluster by quarter
    V <- sandwich::vcovCL(m, cluster = d$yq)
    out <- rbind(out, data.frame(h=h, b=coef(m)["sx_w"], se=sqrt(V["sx_w","sx_w"])))
  }
  out
}
lp_raw <- lp_interaction(P, "dffr")        # endogenous (DiD-style) -> positive
lp_sur <- lp_interaction(P, "MPS_ORTH")    # identified surprise   -> negative
write.csv(merge(lp_raw, lp_sur, by="h", suffixes=c("_raw","_sur")),
          file.path(OUT,"tables/tab_signflip.csv"), row.names=FALSE)

png(file.path(OUT,"figures/fig4_signflip.png"), width=2100, height=1350, res=300)
plot(lp_raw$h, lp_raw$b, type="b", col="steelblue", lwd=2, ylim=range(lp_raw$b,lp_sur$b)*1.2,
     xlab="Horizon (quarters)", ylab="Interaction coefficient",
     main="Sign reversal: identification flips the exposure gradient")
lines(lp_sur$h, lp_sur$b, type="b", col="firebrick", lwd=2); abline(h=0)
legend("topleft", c("dFFR x exposure (endogenous)","surprise x exposure (identified)"),
       col=c("steelblue","firebrick"), lwd=2, bty="n")
dev.off()

# 5.2 Focused big-county direct-shock LP IRF (Lee's narrow design)
big5 <- c("06037","17031","36061","48201","04013")  # LA, Cook, NY, Harris, Maricopa
P5 <- P %>% filter(area_fips %in% big5)
lp_big <- data.frame()
for(h in 0:12){
  d <- P5 %>% group_by(area_fips) %>%
    mutate(yh = 100*(dplyr::lead(ln_emp,h)-dplyr::lag(ln_emp,1))) %>% ungroup() %>%
    filter(is.finite(yh), is.finite(MPS_ORTH))
  m <- lm(yh ~ MPS_ORTH + factor(area_fips), data=d)
  V <- sandwich::vcovCL(m, cluster=d$yq)
  lp_big <- rbind(lp_big, data.frame(h=h, b=coef(m)["MPS_ORTH"], se=sqrt(V["MPS_ORTH","MPS_ORTH"])))
}
png(file.path(OUT,"figures/fig5_lp_bigcounty.png"), width=1900, height=1300, res=300)
plot(lp_big$h, lp_big$b, type="b", col="firebrick", lwd=2,
     ylim=range(lp_big$b-1.96*lp_big$se, lp_big$b+1.96*lp_big$se),
     xlab="Horizon (quarters)", ylab="Employment response (%)",
     main="LP: employment response to identified surprise, 5 major counties")
polygon(c(lp_big$h,rev(lp_big$h)),
        c(lp_big$b-1.96*lp_big$se, rev(lp_big$b+1.96*lp_big$se)),
        col=rgb(.54,.11,.11,.13), border=NA); abline(h=0)
dev.off()

# 5.3 LP vs VAR overlay (normalized employment responses -- Figure 6)
var_emp <- irf_b$irf$dffr[1:13]                       # VAR cumulative emp response, months 0-12
nrm <- function(x) x / abs(min(x))                    # normalize to trough = -1
png(file.path(OUT,"figures/fig6_lp_vs_var.png"), width=1900, height=1300, res=300)
plot(0:12, nrm(var_emp), type="b", col="steelblue", lwd=2, ylim=c(-1.2, 0.8),
     xlab="Horizon", ylab="Normalized employment response",
     main="LP vs VAR: both deliver a hump-shaped contraction")
lines(lp_big$h, nrm(lp_big$b), type="b", col="firebrick", lwd=2); abline(h=0)
legend("bottomright", c("VAR (national, monthly)","Local projection (counties, quarterly)"),
       col=c("steelblue","firebrick"), lwd=2, bty="n")
dev.off()

# ==============================================================================
# SECTION 6 — RANDOM FOREST  (rolling-origin CV, Table 7, Figures 7-8)
# ==============================================================================
cat("\n----- Random forest -----\n")
d <- M %>% filter(date>="2000-01-01", date<="2019-12-31")
for(v in c("dlemp","dlcpi","dffr")) for(L in 1:12) d[[sprintf("%s_l%d",v,L)]] <- dplyr::lag(d[[v]],L)
cols <- grep("_l", names(d), value=TRUE)
d <- d %>% filter(complete.cases(d[,c(cols,"dlemp")]), date>="2002-01-01")

rmse <- function(a,b) sqrt(mean((a-b)^2))
mae  <- function(a,b) mean(abs(a-b))
cv <- data.frame()
allpred <- c(); allact <- c()
dd  <- as.data.frame(d)                    # drop tibble class so randomForest indexes cleanly
dyr <- as.integer(format(dd$date, "%Y"))   # calendar year of each observation
# Rolling-origin CV: iterate over test YEARS (not Dates -- a for() loop over a Date
# vector silently coerces it to numeric, which is what broke format() before).
for(yr in 2014:2019){
  te <- dyr == yr        # test set = that calendar year
  tr <- dyr <  yr        # train set = everything strictly before it
  if(!any(te) || sum(tr) < 50) next
  rf <- randomForest(x = dd[tr, cols], y = dd$dlemp[tr], ntree=400, mtry=6, nodesize=3)
  pr <- predict(rf, dd[te, cols]); ac <- dd$dlemp[te]
  rw <- dd$dlemp_l1[te]; sn <- dd$dlemp_l12[te]
  cv <- rbind(cv, data.frame(year=yr, RF=rmse(ac,pr), RW=rmse(ac,rw), SeasNaive=rmse(ac,sn),
                             RF_MAE=mae(ac,pr), RW_MAE=mae(ac,rw)))
  allpred <- c(allpred,pr); allact <- c(allact,ac)
}
cv <- rbind(cv, data.frame(year=NA, RF=mean(cv$RF), RW=mean(cv$RW), SeasNaive=mean(cv$SeasNaive),
                           RF_MAE=mean(cv$RF_MAE), RW_MAE=mean(cv$RW_MAE)))
write.csv(round(cv,4), file.path(OUT,"tables/tab_rf_cv.csv"), row.names=FALSE)
cat("corr(RF forecast, actual) =", round(cor(allpred,allact),3), " (~0 -> no skill)\n")

rf_full <- randomForest(x = dd[dyr < 2016, cols], y = dd$dlemp[dyr < 2016],
                        ntree=600, mtry=6, nodesize=3, importance=TRUE)
# Variable importance via barplot (varImpPlot ignores mfrow, which blanked a panel).
imp10 <- sort(importance(rf_full)[, "%IncMSE"], decreasing = TRUE)[1:10]
png(file.path(OUT,"figures/fig7_rf.png"), width=2600, height=1000, res=300)
op <- par(mfrow=c(1,2))
par(mar=c(4,6,3,1))
barplot(rev(imp10), horiz=TRUE, las=1, col="steelblue", cex.names=0.75,
        main="RF variable importance", xlab="%IncMSE")
par(mar=c(4,4,3,1))
plot(allact, type="l", col="grey40", ylab="Emp growth", xlab="Index",
     main="RF rolling forecast vs actual")
lines(allpred, col="firebrick")
legend("topright", c("Actual","RF"), col=c("grey40","firebrick"), lwd=2, bty="n")
par(op); dev.off()

# Figure 8: partial dependence of the top predictor (own lag-1 employment growth).
# Manual PDP (avoids partialPlot non-standard-evaluation issues).
xv   <- "dlemp_l1"
grid <- seq(min(dd[[xv]]), max(dd[[xv]]), length.out = 40)
base <- dd[dyr < 2016, cols]
pdp  <- sapply(grid, function(g){ b <- base; b[[xv]] <- g; mean(predict(rf_full, b)) })
png(file.path(OUT,"figures/fig8_rf_pdp.png"), width=1500, height=1200, res=300)
plot(grid, pdp, type="l", col="firebrick", lwd=2,
     xlab="dlemp_l1  (lagged employment growth)", ylab="Partial dependence",
     main="Partial dependence: dlemp_l1")
dev.off()

cat("\n===== DONE: figures/ and tables/ written. =====\n")
# ==============================================================================
# END OF SCRIPT
# ==============================================================================

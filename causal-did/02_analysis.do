/*==============================================================================
  02_analysis.do
  Monetary Policy & Local Labor Markets
  Author : Abdallah Dalis | ECO 510

  PURPOSE:
    All analysis — figures, regressions, and tables — for the final paper.
    Merges and supersedes analysis.do and analysis_v2.do.

  ESTIMATING EQUATION (main spec):
    ln(emp_it) = β1·ΔFFRt + β3·(ΔFFRt × exp_sens_i) + αi + γt + ε_it

    where:
      ln(emp_it)    = log county employment, county i quarter t
      ΔFFRt         = quarterly change in federal funds rate (absorbed by γt)
      exp_sens_i    = CBP 2002 construction+manufacturing share (predetermined)
      αi            = county fixed effects
      γt            = quarter fixed effects
      SE clustered by county

  SPECIFICATIONS:
    1. Main shift-share DiD (contemporaneous interaction)
    2. Distributed lag (4 lags) — headline result
    3. Robustness: CBP 2003 base year
    4. Robustness: CBP 2013 base year
    5. Robustness: Employment growth rate outcome
    6. Pre-trends / placebo test (leads of ΔFFRt)

  FIGURES:
    A. Parallel trends (high vs low exposure over time)
    B. Quarterly sensitivity (all 4 quartiles over time)
    C. Event study (high vs low, leads and lags)

  Requires: output/data/analysis_panel.dta  (produced by 01_clean_data.do)
  Outputs:  output/tables/  output/figures/  output/logs/
==============================================================================*/

cd "/Users/abdallahdalis/Documents/School/Classes/ECO_510_Causal_Inference/Final Project"

cap log close
log using "output/logs/02_analysis.log", replace text

cap mkdir "output/tables"
cap mkdir "output/figures"

* Install required packages if not present
cap which reghdfe
if _rc ssc install reghdfe, replace

cap which coefplot
if _rc ssc install coefplot, replace

cap which esttab
if _rc ssc install estout, replace


/*------------------------------------------------------------------------------
  LOAD DATA
  Keep only core variables to avoid conflicts from any previous runs
------------------------------------------------------------------------------*/

use "output/data/analysis_panel.dta", clear

keep area_fips county_id area_title year qtr yq ///
     month3_emplvl avg_wkly_wage total_qtrly_wages ///
     ln_emp fedfunds_q dffr ///
     exp_sens exp_sens_2002 exp_sens_2003 exp_sens_2013 exp_sens_2014

xtset county_id yq
sort county_id yq


/*------------------------------------------------------------------------------
  GENERATE VARIABLES
------------------------------------------------------------------------------*/

* --- Lags and leads of ΔFFRt (for distributed lag and placebo specs) ---
forval k = 1/4 {
    by county_id: gen dffr_lag`k'  = dffr[_n-`k']
    by county_id: gen dffr_lead`k' = dffr[_n+`k']
}

* --- Interaction terms: ΔFFRt × exposure (main and robustness) ---
gen inter      = dffr * exp_sens        // main spec (CBP 2002)
gen inter_2003 = dffr * exp_sens_2003   // robustness: CBP 2003
gen inter_2013 = dffr * exp_sens_2013   // robustness: CBP 2013
gen inter_2014 = dffr * exp_sens_2014   // robustness: CBP 2014

* --- Lagged and lead interactions (using main exp_sens) ---
forval k = 1/4 {
    by county_id: gen inter_lag`k'  = dffr_lag`k'  * exp_sens
    by county_id: gen inter_lead`k' = dffr_lead`k' * exp_sens
}

* --- Employment growth rate (robustness: alternative outcome) ---
by county_id (yq): gen d_ln_emp = ln_emp - ln_emp[_n-1]

* --- Discrete exposure bins (for figures and event study) ---

* Quartile groups (1=lowest, 4=highest)
xtile exp_quartile = exp_sens, nq(4)
label define exp_qlbl 1 "Q1 (Lowest)" 2 "Q2" 3 "Q3" 4 "Q4 (Highest)"
label values exp_quartile exp_qlbl

* High vs low exposure (above/below median) — for parallel trends and event study
sum exp_sens, detail
gen hi_exposure = (exp_sens >= r(p50))
label define hilbl 0 "Low Exposure (Below Median)" 1 "High Exposure (Above Median)"
label values hi_exposure hilbl

* Interactions with hi_exposure binary (for event study plot)
forval k = 1/4 {
    gen hi_lag`k'  = dffr_lag`k'  * hi_exposure
    gen hi_lead`k' = dffr_lead`k' * hi_exposure
}
gen hi_inter = dffr * hi_exposure

label var inter      "ΔFFRt × Exposure (CBP 2002)"
label var d_ln_emp   "Quarter-on-quarter log employment change"
label var hi_exposure "Above-median exposure county (=1)"


/*------------------------------------------------------------------------------
  FIGURE A: PARALLEL TRENDS — log employment by high/low exposure over time
  Primary visual evidence for the parallel trends assumption.
  Lines should track closely together throughout the pre-period.
------------------------------------------------------------------------------*/

preserve
    collapse (mean) ln_emp, by(yq hi_exposure)
    format yq %tq

    * Deviation from base period (2002q1) — all series start at zero
    sort hi_exposure yq
    by hi_exposure: gen base = ln_emp[1]
    gen dev_ln_emp = ln_emp - base

    twoway ///
        (line dev_ln_emp yq if hi_exposure==0, ///
            lcolor(navy) lwidth(medium) lpattern(solid)) ///
        (line dev_ln_emp yq if hi_exposure==1, ///
            lcolor(cranberry) lwidth(medium) lpattern(dash)), ///
        yline(0, lcolor(gray) lpattern(dot)) ///
        xlabel(, angle(45) labsize(small)) ///
        ylabel(, labsize(small)) ///
        xline(168, lcolor(gray) lpattern(dash) lwidth(thin)) ///
        xline(195 212, lcolor(gs10) lpattern(shortdash) lwidth(medium)) ///
        xline(177 186 190 223 235 236 239, ///
            lcolor(gs12) lpattern(shortdash) lwidth(thin)) ///
        text(-0.045 203 "GFC Gap" "(2009-2012)" "FFR = 0", ///
            size(vsmall) color(gs8) justification(center)) ///
        legend(order(1 "Low Exposure (Below Median)" 2 "High Exposure (Above Median)") ///
               position(6) rows(1) size(small)) ///
        title("Parallel Trends — Deviation from Base Period", size(medium)) ///
        subtitle("2002q1–2019q4 | Normalized to zero at 2002q1", size(small)) ///
        xtitle("Quarter") ytitle("Deviation from 2002q1 Mean Log Employment") ///
        note("Darker dashed lines mark GFC exclusion window (2008q4-2013q1)." ///
             "Light dashed lines mark active FFR change periods used for identification.", ///
             size(vsmall)) ///
        graphregion(color(white)) bgcolor(white)

    graph export "output/figures/parallel_trends.png", replace width(1600)
    di "Figure A saved: parallel_trends.png"
restore


/*------------------------------------------------------------------------------
  FIGURE B: QUARTERLY SENSITIVITY — log employment by exposure quartile
  Shows all four exposure groups tracking together each quarter.
  Strengthens parallel trends evidence beyond the binary high/low split.
------------------------------------------------------------------------------*/

preserve
    collapse (mean) ln_emp, by(yq exp_quartile)
    format yq %tq

    * Deviation from base period (2002q1) — all series start at zero
    sort exp_quartile yq
    by exp_quartile: gen base = ln_emp[1]
    gen dev_ln_emp = ln_emp - base

    twoway ///
        (line dev_ln_emp yq if exp_quartile==1, lcolor(navy)     lwidth(medium)) ///
        (line dev_ln_emp yq if exp_quartile==2, lcolor(teal)     lwidth(medium)) ///
        (line dev_ln_emp yq if exp_quartile==3, lcolor(orange)   lwidth(medium)) ///
        (line dev_ln_emp yq if exp_quartile==4, lcolor(cranberry) lwidth(medium)), ///
        yline(0, lcolor(gray) lpattern(dot)) ///
        xlabel(, angle(45) labsize(small)) ///
        ylabel(, labsize(small)) ///
        xline(168, lcolor(gray) lpattern(dash) lwidth(thin)) ///
        xline(195 212, lcolor(gs10) lpattern(shortdash) lwidth(medium)) ///
        xline(177 186 190 223 235 236 239, ///
            lcolor(gs12) lpattern(shortdash) lwidth(thin)) ///
        text(-0.045 203 "GFC Gap" "(2009-2012)" "FFR = 0", ///
            size(vsmall) color(gs8) justification(center)) ///
        legend(order(1 "Q1: Lowest Exposure" 2 "Q2" 3 "Q3" 4 "Q4: Highest Exposure") ///
               position(6) rows(2) size(small)) ///
        title("Quarterly Sensitivity — Deviation from Base Period", size(medium)) ///
        subtitle("2002q1–2019q4 | Normalized to zero at 2002q1", size(small)) ///
        xtitle("Quarter") ytitle("Deviation from 2002q1 Mean Log Employment") ///
        note("Darker dashed lines mark GFC exclusion window (2008q4-2013q1)." ///
             "Light dashed lines mark active FFR change periods used for identification.", ///
             size(vsmall)) ///
        graphregion(color(white)) bgcolor(white)

    graph export "output/figures/quarterly_sensitivity.png", replace width(1600)
    di "Figure B saved: quarterly_sensitivity.png"
restore


/*------------------------------------------------------------------------------
  FIGURE C: EVENT STUDY — high vs low exposure counties, leads and lags
  Tests pre-trends formally: lead coefficients should be ≈ 0.
  Post-period pattern should be consistent with the distributed lag result.
  Lead -1 omitted as reference period (normalized to zero).
  Pre-period coefficients ≈ 0 supports parallel trends; post-period
  pattern should be consistent with the distributed lag result.
------------------------------------------------------------------------------*/

di ""
di "====== EVENT STUDY: HIGH vs LOW EXPOSURE ======"

* Lead -1 (hi_lead1) OMITTED as reference category — normalized to zero
reghdfe ln_emp ///
    hi_lead4 hi_lead3 hi_lead2 ///
    hi_inter ///
    hi_lag1 hi_lag2 hi_lag3 hi_lag4 ///
    , absorb(county_id yq) cluster(county_id)

estimates store event_study
estadd local county_fe "Yes"
estadd local quarter_fe "Yes"

* --- Manual event study plot for clean x-axis with -1 at zero ---
* Build coefficient matrix: 9 periods (−4 to +4), reference at −1
preserve
    clear
    set obs 9

    gen period = _n - 5                  // -4, -3, -2, -1, 0, 1, 2, 3, 4
    gen coef   = 0
    gen ci_lo  = 0
    gen ci_hi  = 0

    * Fill from stored estimates (period -1 stays at zero = reference)
    estimates restore event_study

    local vars "hi_lead4 hi_lead3 hi_lead2"
    local row = 1
    foreach v of local vars {
        replace coef  = _b[`v']                       in `row'
        replace ci_lo = _b[`v'] - 1.96 * _se[`v']     in `row'
        replace ci_hi = _b[`v'] + 1.96 * _se[`v']     in `row'
        local ++row
    }
    * Row 4 = period -1 (reference) — already zero, no CI

    local row = 5
    local vars2 "hi_inter hi_lag1 hi_lag2 hi_lag3 hi_lag4"
    foreach v of local vars2 {
        replace coef  = _b[`v']                       in `row'
        replace ci_lo = _b[`v'] - 1.96 * _se[`v']     in `row'
        replace ci_hi = _b[`v'] + 1.96 * _se[`v']     in `row'
        local ++row
    }

    * Reference period: no CI bars (set bounds = point = 0)
    gen is_ref = (period == -1)

    twoway ///
        (rcap ci_lo ci_hi period if !is_ref, lcolor(navy) lwidth(medium)) ///
        (scatter coef period if !is_ref, mcolor(navy) msymbol(circle) msize(medlarge)) ///
        (scatter coef period if  is_ref, mcolor(cranberry) msymbol(diamond) msize(large)), ///
        yline(0, lcolor(black) lwidth(thin)) ///
        xline(-0.5, lcolor(gray) lpattern(dash) lwidth(thin)) ///
        xlabel(-4(1)4, labsize(small)) ///
        ylabel(, labsize(small) format(%9.3f)) ///
        legend(order(2 "Estimated Coefficient" 3 "Reference Period (t−1)") ///
               position(6) rows(1) size(small)) ///
        title("Event Study: High vs Low Exposure Counties", size(medium)) ///
        subtitle("Coefficient on ΔFFRt × High Exposure | County & Quarter FE", size(small)) ///
        xtitle("Quarters Relative to FFR Change") ///
        ytitle("Differential Employment Effect") ///
        graphregion(color(white)) bgcolor(white) ///
        note("High = above-median construction+manufacturing share" ///
             "95% CIs shown | SE clustered by county | Reference: t−1 = 0")

    graph export "output/figures/event_study.png", replace width(1600)
    di "Figure C saved: event_study.png"
restore


/*------------------------------------------------------------------------------
  SPEC 1: MAIN SHIFT-SHARE DiD (contemporaneous)
  Estimates the immediate effect of ΔFFRt on employment for high-exposure
  counties relative to low-exposure counties, conditional on county and
  quarter fixed effects.
  Note: ΔFFRt alone is omitted (collinear with quarter FE) — expected.
------------------------------------------------------------------------------*/

di ""
di "====== SPEC 1: MAIN REGRESSION ======"

reghdfe ln_emp dffr inter, ///
    absorb(county_id yq) cluster(county_id)

estimates store main_spec
estadd local county_fe "Yes"
estadd local quarter_fe "Yes"

di "Main interaction (ΔFFRt × Exposure): " _b[inter] " (se=" _se[inter] ")"


/*------------------------------------------------------------------------------
  SPEC 2: DISTRIBUTED LAG (4 quarters)
  Allows employment to respond gradually to monetary policy shocks.
  This is the headline specification — monetary policy transmits with delay.
  Cumulative effect (lincom) is the primary reported estimate.
------------------------------------------------------------------------------*/

di ""
di "====== SPEC 2: DISTRIBUTED LAG (4 LAGS) ======"

reghdfe ln_emp dffr inter inter_lag1 inter_lag2 inter_lag3 inter_lag4, ///
    absorb(county_id yq) cluster(county_id)

estimates store dist_lag
estadd local county_fe "Yes"
estadd local quarter_fe "Yes"

* Cumulative effect: sum of all 5 interaction terms (t through t-4)
lincom inter + inter_lag1 + inter_lag2 + inter_lag3 + inter_lag4
di "Cumulative effect (4-quarter window): " r(estimate)


/*------------------------------------------------------------------------------
  SPEC 3: ROBUSTNESS — Alternative CBP base years
  Tests whether the main result is sensitive to the choice of base year
  used to construct the exposure variable.
------------------------------------------------------------------------------*/

di ""
di "====== SPEC 3a: ROBUSTNESS — CBP 2003 BASE YEAR ======"

reghdfe ln_emp dffr inter_2003, ///
    absorb(county_id yq) cluster(county_id)

estimates store rob_cbp2003
estadd local county_fe "Yes"
estadd local quarter_fe "Yes"

di ""
di "====== SPEC 3b: ROBUSTNESS — CBP 2013 BASE YEAR ======"

reghdfe ln_emp dffr inter_2013, ///
    absorb(county_id yq) cluster(county_id)

estimates store rob_cbp2013
estadd local county_fe "Yes"
estadd local quarter_fe "Yes"

di ""
di "====== SPEC 3c: ROBUSTNESS — CBP 2014 BASE YEAR ======"

reghdfe ln_emp dffr inter_2014, ///
    absorb(county_id yq) cluster(county_id)

estimates store rob_cbp2014
estadd local county_fe "Yes"
estadd local quarter_fe "Yes"


/*------------------------------------------------------------------------------
  SPEC 4: ROBUSTNESS — Employment growth rate as outcome
  Replaces log employment level with quarter-on-quarter log change.
  Tests whether the main result is driven by the level functional form.
------------------------------------------------------------------------------*/

di ""
di "====== SPEC 4: ROBUSTNESS — EMPLOYMENT GROWTH OUTCOME ======"

reghdfe d_ln_emp dffr inter, ///
    absorb(county_id yq) cluster(county_id)

estimates store rob_growth
estadd local county_fe "Yes"
estadd local quarter_fe "Yes"


/*------------------------------------------------------------------------------
  SPEC 5: PRE-TRENDS / PLACEBO TEST — leads of ΔFFRt
  Replaces lags with leads. Under parallel trends, high-exposure counties
  should not anticipate future FFR changes — coefficients should be ≈ 0.
  Lead 1 is significant (discussed as limitation: Fed reacts to employment).
  Leads 2-4 are close to zero, providing partial support for identification.
------------------------------------------------------------------------------*/

di ""
di "====== SPEC 5: PLACEBO — LEADS OF ΔFFRt ======"

reghdfe ln_emp dffr inter inter_lead1 inter_lead2 inter_lead3 inter_lead4, ///
    absorb(county_id yq) cluster(county_id)

estimates store placebo
estadd local county_fe "Yes"
estadd local quarter_fe "Yes"

di ""
di "Lead coefficients (close to zero supports parallel trends):"
di "  Lead 1: " _b[inter_lead1] " (se=" _se[inter_lead1] ")"
di "  Lead 2: " _b[inter_lead2] " (se=" _se[inter_lead2] ")"
di "  Lead 3: " _b[inter_lead3] " (se=" _se[inter_lead3] ")"
di "  Lead 4: " _b[inter_lead4] " (se=" _se[inter_lead4] ")"


/*------------------------------------------------------------------------------
  OUTPUT TABLES
  All variable labels are human-readable (no coded names like 'inter').
  ΔFFRt alone excluded from tables (omitted by Stata — absorbed by quarter FE).
  Each table output in both CSV (for editing) and LaTeX (for presentation).
------------------------------------------------------------------------------*/

* --- Add mean of dependent variable to all stored estimates ---
sum ln_emp
local mean_ln_emp : di %9.3f r(mean)

foreach est in main_spec dist_lag rob_cbp2003 rob_cbp2013 rob_cbp2014 rob_growth placebo event_study {
    estimates restore `est'
    estadd local mean_depvar "`mean_ln_emp'"
}

* --- Store cumulative effect for distributed lag ---
estimates restore dist_lag
lincom inter + inter_lag1 + inter_lag2 + inter_lag3 + inter_lag4
local cum_eff : di %9.3f r(estimate)
local cum_se  : di %9.3f r(se)
estadd local cum_effect "`cum_eff'"
estadd local cum_se     "(`cum_se')"

* --- Table 2: Main results ---
esttab main_spec dist_lag ///
    using "output/tables/table2_main.tex", ///
    replace booktabs ///
    keep(inter inter_lag1 inter_lag2 inter_lag3 inter_lag4) ///
    coeflabels(inter      "$\Delta FFR_t \times \text{Exposure}$" ///
               inter_lag1 "$\Delta FFR_{t-1} \times \text{Exposure}$" ///
               inter_lag2 "$\Delta FFR_{t-2} \times \text{Exposure}$" ///
               inter_lag3 "$\Delta FFR_{t-3} \times \text{Exposure}$" ///
               inter_lag4 "$\Delta FFR_{t-4} \times \text{Exposure}$") ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    scalars("cum_effect Cumulative Effect" "cum_se  " ///
            "mean_depvar Mean Dep. Var." ///
            "county_fe County FE" "quarter_fe Quarter FE" ///
            "N Observations" "r2 R-squared") ///
    title("Effect of Monetary Policy on County Employment") ///
    mtitles("Contemporaneous" "Distributed Lag") ///
    addnotes("Standard errors clustered by county in parentheses." ///
             "Exposure = CBP 2002 construction + manufacturing employment share." ///
             "Cumulative effect = sum of contemporaneous and four lagged interactions.")

esttab main_spec dist_lag ///
    using "output/tables/table2_main.csv", ///
    replace csv ///
    keep(inter inter_lag1 inter_lag2 inter_lag3 inter_lag4) ///
    coeflabels(inter      "ΔFFRt × Exposure" ///
               inter_lag1 "ΔFFRt × Exposure (lag 1)" ///
               inter_lag2 "ΔFFRt × Exposure (lag 2)" ///
               inter_lag3 "ΔFFRt × Exposure (lag 3)" ///
               inter_lag4 "ΔFFRt × Exposure (lag 4)") ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    scalars("cum_effect Cumulative Effect" "cum_se  " ///
            "mean_depvar Mean Dep. Var." ///
            "county_fe County FE" "quarter_fe Quarter FE" ///
            "N Observations" "r2 R-squared") ///
    title("Table 2: Effect of Monetary Policy on County Employment") ///
    mtitles("Contemporaneous" "Distributed Lag") ///
    addnotes("SE clustered by county. Exposure = CBP 2002 constr+manuf share." ///
             "Cumulative effect = sum of contemporaneous and four lagged interactions.")

* --- Table 3: Robustness checks ---
esttab main_spec rob_cbp2003 rob_cbp2013 rob_cbp2014 rob_growth ///
    using "output/tables/table3_robustness.tex", ///
    replace booktabs ///
    keep(inter inter_2003 inter_2013 inter_2014) ///
    coeflabels(inter      "$\Delta FFR_t \times \text{Exposure (CBP 2002)}$" ///
               inter_2003 "$\Delta FFR_t \times \text{Exposure (CBP 2003)}$" ///
               inter_2013 "$\Delta FFR_t \times \text{Exposure (CBP 2013)}$" ///
               inter_2014 "$\Delta FFR_t \times \text{Exposure (CBP 2014)}$") ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    scalars("mean_depvar Mean Dep. Var." ///
            "county_fe County FE" "quarter_fe Quarter FE" ///
            "N Observations" "r2 R-squared") ///
    title("Robustness Checks --- Alternative Base Years and Outcome") ///
    mtitles("Main" "CBP 2003" "CBP 2013" "CBP 2014" "Growth Rate") ///
    addnotes("Standard errors clustered by county in parentheses." ///
             "Column 5 outcome = quarter-on-quarter log employment change.")

esttab main_spec rob_cbp2003 rob_cbp2013 rob_cbp2014 rob_growth ///
    using "output/tables/table3_robustness.csv", ///
    replace csv ///
    keep(inter inter_2003 inter_2013 inter_2014) ///
    coeflabels(inter      "ΔFFRt × Exposure (CBP 2002, main)" ///
               inter_2003 "ΔFFRt × Exposure (CBP 2003)" ///
               inter_2013 "ΔFFRt × Exposure (CBP 2013)" ///
               inter_2014 "ΔFFRt × Exposure (CBP 2014)") ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    scalars("mean_depvar Mean Dep. Var." ///
            "county_fe County FE" "quarter_fe Quarter FE" ///
            "N Observations" "r2 R-squared") ///
    title("Table 3: Robustness Checks — Alternative Base Years and Outcome") ///
    mtitles("Main" "CBP 2003" "CBP 2013" "CBP 2014" "Growth Rate") ///
    addnotes("SE clustered by county. Col 5 outcome = quarter-on-quarter log emp change.")

* --- Table 4: Pre-trends / placebo ---
esttab placebo ///
    using "output/tables/table4_placebo.tex", ///
    replace booktabs ///
    keep(inter inter_lead1 inter_lead2 inter_lead3 inter_lead4) ///
    coeflabels(inter       "$\Delta FFR_t \times \text{Exposure}$" ///
               inter_lead1 "$\Delta FFR_{t+1} \times \text{Exposure}$" ///
               inter_lead2 "$\Delta FFR_{t+2} \times \text{Exposure}$" ///
               inter_lead3 "$\Delta FFR_{t+3} \times \text{Exposure}$" ///
               inter_lead4 "$\Delta FFR_{t+4} \times \text{Exposure}$") ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    scalars("mean_depvar Mean Dep. Var." ///
            "county_fe County FE" "quarter_fe Quarter FE" ///
            "N Observations" "r2 R-squared") ///
    title("Pre-Trends / Placebo Test") ///
    mtitles("Leads Specification") ///
    addnotes("Standard errors clustered by county in parentheses." ///
             "Lead 1 significant --- consistent with Fed responding to employment conditions.")

esttab placebo ///
    using "output/tables/table4_placebo.csv", ///
    replace csv ///
    keep(inter inter_lead1 inter_lead2 inter_lead3 inter_lead4) ///
    coeflabels(inter       "ΔFFRt × Exposure (t)" ///
               inter_lead1 "ΔFFRt × Exposure (lead 1)" ///
               inter_lead2 "ΔFFRt × Exposure (lead 2)" ///
               inter_lead3 "ΔFFRt × Exposure (lead 3)" ///
               inter_lead4 "ΔFFRt × Exposure (lead 4)") ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    scalars("mean_depvar Mean Dep. Var." ///
            "county_fe County FE" "quarter_fe Quarter FE" ///
            "N Observations" "r2 R-squared") ///
    title("Table 4: Pre-Trends / Placebo Test") ///
    mtitles("Leads Specification") ///
    addnotes("SE clustered by county. Lead 1 significant — Fed reacts to employment (see text).")

* --- Table 5: Event study coefficients ---
esttab event_study ///
    using "output/tables/table5_event_study.tex", ///
    replace booktabs ///
    keep(hi_lead4 hi_lead3 hi_lead2 hi_inter hi_lag1 hi_lag2 hi_lag3 hi_lag4) ///
    order(hi_lead4 hi_lead3 hi_lead2 hi_inter hi_lag1 hi_lag2 hi_lag3 hi_lag4) ///
    coeflabels(hi_lead4 "$\Delta FFR_{t+4} \times \text{High}$" ///
               hi_lead3 "$\Delta FFR_{t+3} \times \text{High}$" ///
               hi_lead2 "$\Delta FFR_{t+2} \times \text{High}$" ///
               hi_inter "$\Delta FFR_t \times \text{High}$" ///
               hi_lag1  "$\Delta FFR_{t-1} \times \text{High}$" ///
               hi_lag2  "$\Delta FFR_{t-2} \times \text{High}$" ///
               hi_lag3  "$\Delta FFR_{t-3} \times \text{High}$" ///
               hi_lag4  "$\Delta FFR_{t-4} \times \text{High}$") ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    scalars("mean_depvar Mean Dep. Var." ///
            "county_fe County FE" "quarter_fe Quarter FE" ///
            "N Observations" "r2 R-squared") ///
    title("Event Study Coefficients --- High vs Low Exposure") ///
    mtitles("ln(Employment)") ///
    addnotes("Standard errors clustered by county in parentheses." ///
             "High = above-median construction + manufacturing share." ///
             "Reference period: t$-$1 (omitted, normalized to zero).")

esttab event_study ///
    using "output/tables/table5_event_study.csv", ///
    replace csv ///
    keep(hi_lead4 hi_lead3 hi_lead2 hi_inter hi_lag1 hi_lag2 hi_lag3 hi_lag4) ///
    order(hi_lead4 hi_lead3 hi_lead2 hi_inter hi_lag1 hi_lag2 hi_lag3 hi_lag4) ///
    coeflabels(hi_lead4 "ΔFFRt+4 × High" ///
               hi_lead3 "ΔFFRt+3 × High" ///
               hi_lead2 "ΔFFRt+2 × High" ///
               hi_inter "ΔFFRt × High" ///
               hi_lag1  "ΔFFRt-1 × High" ///
               hi_lag2  "ΔFFRt-2 × High" ///
               hi_lag3  "ΔFFRt-3 × High" ///
               hi_lag4  "ΔFFRt-4 × High") ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    scalars("mean_depvar Mean Dep. Var." ///
            "county_fe County FE" "quarter_fe Quarter FE" ///
            "N Observations" "r2 R-squared") ///
    title("Table 5: Event Study Coefficients — High vs Low Exposure") ///
    mtitles("ln(Employment)") ///
    addnotes("SE clustered by county. High = above-median constr+manuf share." ///
             "Reference period: t−1 (omitted, normalized to zero).")

di ""
di "All tables saved to output/tables/"
di "All figures saved to output/figures/"
di "02_analysis.do complete."
log close

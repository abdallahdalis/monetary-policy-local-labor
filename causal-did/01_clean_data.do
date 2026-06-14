/*==============================================================================
  01_clean_data.do
  Monetary Policy & Local Labor Markets
  Author : Abdallah Dalis | ECO 510

  PURPOSE:
    Builds the analysis panel from raw QCEW, FRED, and CBP data.
    Outputs a single clean dataset: output/data/analysis_panel.dta

  IDENTIFICATION CHOICE:
    Main exposure = CBP 2002 (fully predetermined — measured before the
    analysis window begins, eliminating reverse causality concerns in the
    exposure measure itself). CBP 2003, 2013, 2014 retained as robustness.

  SAMPLE:
    County-quarter panel, 2002q1-2008q4 and 2013q1-2019q4.
    2009-2012 excluded from main sample (financial crisis); available as
    a robustness extension if those QCEW files are downloaded.

  EXPECTED RAW DATA STRUCTURE:
    raw/
      QCEW/
        2002.q1-q4.singlefile.csv
        ...  (one file per year: 2002-2008, 2013-2019)
      CBP/
        cbp02co.txt  cbp03co.txt  cbp13co.txt  cbp14co.txt
      FRED/
        FEDFUNDS.csv

  OUTPUTS:
    output/data/analysis_panel.dta   (FINAL — input to 02_analysis.do)
==============================================================================*/

cd "/Users/abdallahdalis/Documents/School/Classes/ECO_510_Causal_Inference/Final Project"

cap log close
log using "output/logs/01_clean_data.log", replace text

cap mkdir "output"
cap mkdir "output/data"
cap mkdir "output/logs"


/*------------------------------------------------------------------------------
  PART 1: QCEW — Build county-quarter employment panel
  Source: BLS Quarterly Census of Employment and Wages
  Level:  County-level total employment (agglvl_code=70, industry_code=10)
  Note:   area_fips encoded to county_id AFTER appending all years to ensure
          consistent integer IDs across the full panel
------------------------------------------------------------------------------*/

cap program drop clean_qcew
program define clean_qcew

    * Remove state-level aggregates and unknown-county rows
    * area_fips is string in singlefile format
    cap confirm string variable area_fips
    if _rc {
        tostring area_fips, gen(area_fips_str) format(%05.0f)
        drop area_fips
        rename area_fips_str area_fips
    }
    drop if substr(area_fips,3,3)=="000" | substr(area_fips,3,3)=="999"

    * Keep county total-employment rows only
    * Handle both numeric and string industry_code (singlefile stores as string)
    cap confirm string variable industry_code
    if _rc==0 {
        keep if industry_code=="10"
        destring agglvl_code, replace force
        destring own_code, replace force
        destring size_code, replace force
    }
    else {
        keep if industry_code==10
    }
    keep if agglvl_code==70

    * Drop subcategory rows if ownership/size breakdown present
    cap confirm variable own_code
    if _rc==0 keep if own_code==0

    cap confirm variable size_code
    if _rc==0 keep if size_code==0

    * Quarterly time variable
    * Destring year/qtr if needed (singlefile may import as string)
    cap confirm string variable year
    if _rc==0 destring year, replace force
    cap confirm string variable qtr
    if _rc==0 destring qtr, replace force

    gen yq = yq(year, qtr)
    format yq %tq

    * Destring employment/wage vars if needed
    foreach v in month3_emplvl avg_wkly_wage total_qtrly_wages {
        cap confirm string variable `v'
        if _rc==0 destring `v', replace force
    }

    * area_title not present in singlefile format — skip if missing
    cap confirm variable area_title
    if _rc {
        gen area_title = ""
    }

    keep area_fips area_title year qtr yq month3_emplvl avg_wkly_wage total_qtrly_wages

end

tempfile master
clear
save `master', emptyok replace

foreach y in 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 {
    di "=== LOADING YEAR `y' ==="
    import delimited ///
        "raw/QCEW/`y'.q1-q4.singlefile.csv", ///
        clear
    clean_qcew
    append using `master'
    save `master', replace
}

use `master', clear

* Encode FIPS after appending so county_id is consistent across all years
encode area_fips, gen(county_id)

di "Total QCEW obs: " _N
duplicates report area_fips yq

* Log employment (ln(emp+1) to handle any zero-employment counties)
gen ln_emp = ln(month3_emplvl + 1)
label var ln_emp "Log total employment (month 3 of quarter)"

save "output/data/qcew_panel_all_years.dta", replace


/*------------------------------------------------------------------------------
  PART 2: FRED — Quarterly FFR and first difference (ΔFFRt)
  Source: FRED FEDFUNDS series (monthly), columns: observation_date, fedfunds
  Method: Average monthly values within each quarter, then first-difference
------------------------------------------------------------------------------*/

import delimited "raw/FRED/FEDFUNDS.csv", clear varnames(1)
rename *, lower

* Parse YYYY-MM-DD
rename observation_date date
gen year  = real(substr(date,1,4))
gen month = real(substr(date,6,2))
gen qtr   = ceil(month/3)

* Quarterly average
collapse (mean) fedfunds_q=fedfunds, by(year qtr)

* Keep analysis years only
keep if (year>=2002 & year<=2008) | (year>=2013 & year<=2019)

sort year qtr
gen yq = yq(year, qtr)
format yq %tq

tsset yq
gen dffr = D.fedfunds_q

label var fedfunds_q "Federal funds rate (quarterly avg, %)"
label var dffr       "Quarterly change in FFR (pp)"

save "output/data/fedfunds_q.dta", replace
di "FFR quarters saved: " _N


/*------------------------------------------------------------------------------
  PART 3: CBP — County industry exposure measure
  Source: Census County Business Patterns
  Definition: (construction + manufacturing employment) / total employment
  NAICS: construction = 23; manufacturing = 31, 32, 33

  BASE YEAR CHOICE:
    exp_sens_2002 = MAIN specification.
      Fully predetermined: measured before the 2002q1 start of the sample,
      so it cannot be affected by any FFR change or employment outcome in
      the analysis window. Standard approach in the Bartik/shift-share
      literature (cf. Autor, Dorn & Hanson 2013).

    exp_sens_2003/2013/2014 = robustness alternatives only.
------------------------------------------------------------------------------*/

cap program drop build_cbp_exposure
program define build_cbp_exposure
    args sfx yr

    di "=== BUILDING CBP EXPOSURE: `yr' ==="
    import delimited "raw/CBP/cbp`sfx'co.txt", clear

    * Construct 5-digit county FIPS
    tostring fipstate, gen(st)  format(%02.0f)
    tostring fipscty,  gen(cty) format(%03.0f)
    gen area_fips = st + cty
    drop st cty

    * Clean NAICS codes (remove range separators)
    gen naics_clean = subinstr(naics, "-", "", .)
    replace naics_clean = subinstr(naics_clean, "/", "", .)
    gen naics2   = substr(naics_clean, 1, 2)
    gen is_total = (naics_clean == "")

    * Retain total, construction (23), and manufacturing (31/32/33) rows
    keep if is_total | naics2=="23" | inlist(naics2,"31","32","33")

    gen ind = ""
    replace ind = "total"  if is_total
    replace ind = "constr" if naics2=="23"
    replace ind = "manuf"  if inlist(naics2,"31","32","33")

    * Sum sub-industries and reshape to wide (one row per county)
    collapse (sum) emp, by(area_fips ind)
    reshape wide emp, i(area_fips) j(ind) string

    drop if missing(emptotal) | emptotal<=0

    gen exp_sens_`yr' = (empconstr + empmanuf) / emptotal

    * Remove implausible shares
    drop if exp_sens_`yr' > 1

    keep area_fips exp_sens_`yr'
    save "output/data/cbp_exposure_`yr'.dta", replace

    summ exp_sens_`yr'
end

build_cbp_exposure 02 2002
build_cbp_exposure 03 2003
build_cbp_exposure 13 2013
build_cbp_exposure 14 2014


/*------------------------------------------------------------------------------
  PART 4: Merge into analysis panel
------------------------------------------------------------------------------*/

use "output/data/qcew_panel_all_years.dta", clear

* Time-series merge: every county gets the same FFR each quarter
merge m:1 yq using "output/data/fedfunds_q.dta", nogen
di "After FFR merge: " _N

* Cross-sectional merge: each county gets its exposure share
foreach yr in 2002 2003 2013 2014 {
    merge m:1 area_fips using "output/data/cbp_exposure_`yr'.dta", keep(1 3) nogen
}

* --- Define main and robustness exposure variables ---

* MAIN: CBP 2002 — fully predetermined for entire analysis window
gen exp_sens = exp_sens_2002
label var exp_sens      "Main exposure: CBP 2002 constr+manuf share (predetermined)"
label var exp_sens_2002 "Robustness: CBP 2002 base year"
label var exp_sens_2003 "Robustness: CBP 2003 base year"
label var exp_sens_2013 "Robustness: CBP 2013 base year"
label var exp_sens_2014 "Robustness: CBP 2014 base year"

* Drop ~846 counties missing from CBP 2002
* (these counties would need to be systematically different in their
*  industry-employment response to monetary policy to bias results)
drop if missing(exp_sens)
di "After dropping counties missing CBP 2002 exposure: " _N


/*------------------------------------------------------------------------------
  PART 5: Final checks and save
------------------------------------------------------------------------------*/

xtset county_id yq

di ""
di "=== SUMMARY STATISTICS ==="
tabstat ln_emp dffr exp_sens, stat(mean sd min max n) col(stat)
di "Total obs: " _N

sort county_id yq
save "output/data/analysis_panel.dta", replace

di ""
di "01_clean_data.do complete."
di "Final dataset: output/data/analysis_panel.dta"
log close

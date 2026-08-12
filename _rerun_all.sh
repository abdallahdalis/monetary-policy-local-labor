#!/bin/bash
# Full re-run after the DC recode (11999 -> 11001), August 12 2026.
export PATH=/usr/local/bin:/opt/homebrew/bin:$PATH
ROOT=~/Documents/projects/monetary-policy-local-labor
L=/tmp/rerun
mkdir -p $L
set -x

cd $ROOT/causal-did || exit 1
Rscript --vanilla Dalis_Abdallah_ExposureDescriptives.R                       > $L/01_descriptives.log 2>&1
EXCLUDE_ZLB=FALSE POSITIONAL_LAGS=FALSE Rscript --vanilla Dalis_Abdallah_CausalDiD_Analysis.R > $L/02_did_full_posoff.log 2>&1
EXCLUDE_ZLB=TRUE  POSITIONAL_LAGS=FALSE Rscript --vanilla Dalis_Abdallah_CausalDiD_Analysis.R > $L/03_did_excl_posoff.log 2>&1
EXCLUDE_ZLB=FALSE POSITIONAL_LAGS=TRUE  Rscript --vanilla Dalis_Abdallah_CausalDiD_Analysis.R > $L/04_did_full_poson.log  2>&1
EXCLUDE_ZLB=TRUE  POSITIONAL_LAGS=TRUE  Rscript --vanilla Dalis_Abdallah_CausalDiD_Analysis.R > $L/05_did_excl_poson.log  2>&1
Rscript --vanilla Dalis_Abdallah_PreTrendsFigure.R                            > $L/06_pretrends.log 2>&1
EXCLUDE_ZLB=FALSE Rscript --vanilla Dalis_Abdallah_RandomizationInference.R    > $L/07_ri_full.log 2>&1
EXCLUDE_ZLB=TRUE  Rscript --vanilla Dalis_Abdallah_RandomizationInference.R    > $L/08_ri_excl.log 2>&1

cd $ROOT || exit 1
Rscript --vanilla Dalis_Abdallah_LocalProjections_BothWindows.R               > $L/09_lp.log 2>&1
Rscript --vanilla Dalis_Abdallah_InfluenceSmallCounty.R                       > $L/10_influence.log 2>&1
Rscript --vanilla monetary_policy_labor.R                                     > $L/11_mpl.log 2>&1
Rscript --vanilla Dalis_Abdallah_SpuriousPrecision_Figures.R                  > $L/12_spurious.log 2>&1
Rscript --vanilla causal-did/Dalis_Abdallah_ExposureMap.R                     > $L/13_map.log 2>&1
echo ALL_DONE > $L/STATUS

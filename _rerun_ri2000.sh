#!/bin/bash
# Raise the permutation count so the pre-trends lead count stops resting on
# Monte Carlo noise. At 200 draws the MCSE of p near 0.05 is ~0.015, wider than
# the gap between the leads counted and the leads not counted.
export PATH=/usr/local/bin:/opt/homebrew/bin:$PATH
cd ~/Documents/projects/monetary-policy-local-labor/causal-did || exit 1
L=/tmp/rerun
N_REPS=2000 EXCLUDE_ZLB=FALSE Rscript --vanilla Dalis_Abdallah_RandomizationInference.R > $L/20_ri2000_full.log 2>&1
N_REPS=2000 EXCLUDE_ZLB=TRUE  Rscript --vanilla Dalis_Abdallah_RandomizationInference.R > $L/21_ri2000_excl.log 2>&1
Rscript --vanilla Dalis_Abdallah_PreTrendsFigure.R > $L/22_pretrends2.log 2>&1
echo DONE > $L/RI2_STATUS

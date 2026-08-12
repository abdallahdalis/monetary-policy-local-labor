# Revision Memo: Rate Sensitivity and Employment

**Date:** August 7, 2026
**Author:** Abdallah Dalis
**Purpose:** This memo restructures SSRN working paper 7000419 so the sign-flip diagnostic becomes the contribution. Target is the TEC2026 Job Market Poster Session deadline of August 26.

---

## 1. The problem in one paragraph

The posted paper reports a positive employment response to monetary tightening in rate-sensitive counties. Your own R script labels that estimator endogenous. `monetary_policy_labor.R` line 212 names the two series "dFFR x exposure (endogenous)" and "surprise x exposure (identified)." Line 203 carries the comment `# identified surprise -> negative`. The file `tables/tab_signflip.csv` confirms it. Raw estimates run positive at all thirteen horizons and significant at eleven of them (h=11 is p=0.066, h=12 is p=0.205). Identified estimates run negative at all thirteen and reach significance at none. *Corrected August 7 — this paragraph previously said "significant across all thirteen," which contradicts section 3.*

The result you published is the one your project already diagnosed as biased. The fix is to publish the diagnosis instead.

**Revised August 7 after running the difference test.** The two estimators are not statistically distinguishable at any horizon. The closest is h=2 at p=0.056. So the paper cannot claim the sign flips. What it can claim is stronger and more honest. Identified standard errors run 6 to 12 times wider than naive ones (6.30 at h=0, 11.97 at h=3). The naive design's precision is borrowed from the business cycle. See section 8.

---

## 2. Proposed new title

**Spurious Precision: Why Shift-Share Designs Overstate Monetary Policy Effects on Local Employment**

This moves the contribution into the title. SSRN lets you upload a revised version under the same abstract ID, so citations and the DOI survive.

---

## 3. Revised abstract (212 words, under the TEC 250-word cap)

> Applied work often measures monetary policy with observed changes in the federal funds rate. That measure is endogenous. The Fed tightens when the economy runs hot, and rate-exposed sectors are the most cyclical. This paper prices the resulting bias in a local labor market design.
>
> I use QCEW county employment from 2002 to 2019 in a shift-share difference-in-differences framework. Exposure is the predetermined 2002 county employment share in construction and manufacturing. County and quarter fixed effects absorb level differences and common national shocks.
>
> The naive estimator looks strong and points the wrong way. The contemporaneous interaction is 0.020 (p<0.01). Local projections on the rate change are significant at 11 of 13 horizons. Read directly, tightening raises employment where theory says it should fall.
>
> Bauer-Swanson high-frequency surprises change the picture. Point estimates turn negative at all 13 horizons. Standard errors rise by a factor of 6 to 12. No horizon rejects zero.
>
> The two estimators are not statistically distinguishable. That is the result. The naive design borrows its precision from business-cycle variation, not policy variation. Its tight confidence intervals are an artifact. County-quarter panels lack the power to identify monetary transmission once the cycle is removed.
>
> Researchers should report both estimators. The collapse in precision, not the change in sign, is the diagnostic.

---

## 4. Plain-Language Summary box

> **Plain-Language Summary**
>
> **What was asked.** When the Federal Reserve raises interest rates, do jobs disappear faster in places that build houses and make things?
>
> **What was found.** The obvious way to run this test gives a confident, backwards answer. It says rate hikes add jobs in those places. The reason is timing. The Fed raises rates because the economy is already booming, and those sectors boom hardest. A method that isolates only the surprise part of Fed decisions points the expected direction instead. It also carries error bars six to twelve times wider.
>
> **What it means.** The confident answer was never really confident. Its precision came from the boom the Fed was reacting to, not from the rate change. Strip that out and county data by quarter is too thin to answer the question.
>
> **The honest limitation.** The two methods cannot be told apart statistically. This paper shows that a common shortcut manufactures false confidence. It does not deliver the right number, and it argues this data cannot.

---

## 5. Restructured outline

Following the wine-glass structure. Sections written in the order listed in `00_Resources/research-paper-writing-process.md`, results first.

### Figures, in story order

| # | Figure | One-sentence takeaway |
| --- | --- | --- |
| 1 | Exposure map, CBP 2002 shares | Rate-sensitive employment concentrates in the industrial Midwest and the Southeast. |
| 2 | Parallel trends, high vs low exposure | Levels track closely, which is why the design looks credible at first glance. |
| 3 | Event study, leads and lags | Lead +4 is significant and the post-period alternates sign, so the design fails its own test. |
| 4 | **Raw vs identified, horizons 0 to 12, with confidence bands** | **The headline. Same data, opposite signs, and error bands 6 to 12 times wider.** |
| 5 | Standard errors by horizon, both estimators | Precision collapses once the cycle is removed, which is the whole argument. |

Figure 4 is the paper, and it must show the bands. A version plotting point estimates alone would make a claim the data does not support. The bands are the finding.

### Section plan

**Results and Discussion** (write first, figure by figure)

1. The naive estimate and why it looks convincing. Report 0.020 (p<0.01). Note that it survives four alternative base years.
2. Why base-year robustness proves little. Industrial composition persists, so 2002, 2003, 2013, and 2014 shares are near-collinear. A test that does not vary the load-bearing assumption is not a test.
3. Pre-trends fail. Report leads 3 and 4 from Table 4. Report lead +4 from the event study. State plainly that this rules out the causal reading.
4. The comparison. Present Figure 4. Raw significant at 11 of 13 horizons, identified at 0 of 13, negative at all 13. State in the same breath that the difference is not significant at any horizon.
5. Precision, not sign, is the finding. Identified standard errors run 6 to 12 times wider (min 6.30 at h=0, max 11.97 at h=3). The naive estimator's tight bands come from cycle variation the design never removed.
6. Why the surprise is used directly. Bauer-Swanson surprises do not move quarterly rate changes, so the first stage is weak. The surprise is the shock, not an instrument. Frame this as design, not fallback.

**Methodology**

Data, sample window, the **2009q1 to 2012q4** exclusion and its justification, exposure construction, the estimating equation, both shock measures, clustering, software.

*Corrected August 7.* The window was previously written here as "2008q4 to 2013q1." That is wrong at both endpoints — `01_clean_data.do` line 160 keeps `year<=2008 | year>=2013`, so 2008q4 and 2013q1 are both in the sample. Excluded is 2009q1–2012q4.

Add a short subsection on shift-share identification. Cite Goldsmith-Pinkham, Sorkin and Swift (2020) on share-based identification, and Borusyak, Hull and Jaravel (2022) on shock-based identification. Report Rotemberg weights if time allows. If not, name it as the next step.

**Introduction**

Territory: monetary transmission is heterogeneous across places. Niche: county-level work often uses the observed rate because shocks are hard to get at that frequency. Occupy: this paper prices that shortcut.

**Conclusion**

Take-home, the diagnostic as a portable tool, limitations, and the next step of raising power through annual aggregation or a longer window.

---

## 5b. 🔴 BLOCKING — the tables and the headline figure use different samples

**Found August 7. This outranks everything else in the revision.**

The Stata DiD tables exclude 2009q1–2012q4 (`01_clean_data.do` line 160: `keep if year<=2008 | year>=2013`). The R local projections behind Figures 4 and 5 do not (`monetary_policy_labor.R` line 76: `filter(year >= 2002, year <= 2019)`). The two halves of the paper are estimated on samples that differ by 51,568 county-quarters, 22 percent of the panel, and no text in the paper reconciles them.

Figure 4 is the headline. A reader who compares its sample to Table 2's finds the discrepancy immediately, and the paper's entire subject is researchers being insufficiently careful about what drives their estimates. Shipping this unreconciled would hand a skeptic the paper's own thesis to use against it.

**Three ways to resolve, in order of preference.**

1. **Re-estimate the local projections on the table sample (excluding 2009–2012).** Makes the paper internally consistent on the more defensible window. Requires the port described below. This is the recommended path.
2. **Re-estimate the tables on the full window.** Cheaper in principle but wrong in substance — it puts four years of near-zero rate variation back into the design, which is the mechanism the paper indicts.
3. **Report both, and make the comparison a result.** Most work, potentially the strongest paper: the gap between the two windows is a direct measurement of how much precision the ZLB period manufactures. Only if time allows before Aug 26.

**Until this is resolved, treat Figures 4 and 5 as provisional.** The shape of the argument will survive — identified standard errors are 6 to 12 times wider, and that is not a sample-window artifact — but the specific coefficients and band widths will move.

### RESOLVED August 7 — run it both ways, and the ZLB window is a result

`Dalis_Abdallah_CausalDiD_Analysis.R` run with `EXCLUDE_ZLB=TRUE` and `FALSE`. Adding the zero-lower-bound window barely moves the point estimates and sharply tightens the standard errors. That is the spurious-precision mechanism, reproduced on this paper's own data.

| Quantity | Excl. 2009–2012 (N=161,528) | Full window (N=207,672) | Change in SE |
| --- | --- | --- | --- |
| Contemporaneous `inter` | 0.0210 (0.0043) | 0.0223 (0.0043) | none |
| **Cumulative 4-quarter** | **0.0510 (0.0112)** | **0.0581 (0.0072)** | **−36%** |
| Lag 2 | 0.0034 (0.0057), ns | 0.0106 (0.0040), p<0.01 | −30% |
| Lag 3 | 0.0161 (0.0058), p<0.05 | 0.0161 (0.0040), p<0.01 | −31% |
| Lag 4 | 0.0199 (0.0131), ns | 0.0290 (0.0067), p<0.01 | **−49%** |
| Distributed lags significant | **2 of 4** | **4 of 4** | — |

The lag-3 point estimate is *identical* to four decimals across the two samples while its standard error falls by a third. Adding four years in which the funds rate barely moved cannot have added information about how employment responds to the funds rate. It added observations, and the standard error formula rewarded that.

**Decision: excl. 2009–2012 is the reported specification; the full window becomes a demonstration table.** This is a stronger version of the paper than the one planned this morning — the diagnostic no longer rests only on the raw-vs-identified comparison, it is shown twice by two independent routes.

**Consequence for the figures.** `tab_signflip.csv` was produced on the full window. Figures 4 and 5 must be rebuilt on the excl-2009–2012 sample to match the tables, which means re-running the local projections in `monetary_policy_labor.R` with the same exclusion.

---

## 6. Fixes required regardless of framing

Three items in the current output are wrong or misleading. Fix them even if you keep the old structure.

1. **The posted SSRN abstract has three problems, not one.** Verified against the live page August 7. Ranked by damage:

   a. **It states the result as a causal finding.** *"I find that counties with greater concentrations of rate-sensitive industries experience systematically higher employment growth during monetary policy tightening."* No identification caveat. This is the worst sentence on the page, and the pre-trends failure (leads 3 and 4 significant, opposite signs) rules it out.

   b. **It claims robustness from a test that is not one.** *"Results are robust across alternative base-year exposure measures."* Per section 5.2, 2002/2003/2013/2014 shares are near-collinear, so this never varies the load-bearing assumption.

   c. **It splices two regressions.** *"The contemporaneous interaction coefficient is 0.020 (p < 0.01), with the dominant effect materializing at a nine-month lag (β = 0.025, p < 0.01) and a cumulative four-quarter effect of 0.042 (p < 0.01)."* Chained with "with" and "and," this reads as one specification. The 0.020 is Table 2 column 1 (contemporaneous-only). The 0.025 and 0.042 are column 2 (distributed lag), where the contemporaneous term is −0.0054 and insignificant.

   d. **The identified-surprise result is absent entirely.** A reader cannot tell the design fails its own test.

   The revised abstract in section 3 fixes all four. Body text in `mennis-submission/RateSensitivity_Employment_Mennis_anon.md` line 73 already labels both models correctly — the splice is an abstract-only problem. Line 21 of that same file does splice (0.020 with the 0.042 cumulative) and needs the same fix.

2. ~~**The Table 4 note misstates the result.** It reads "Lead 1 significant." Lead 1 is 0.0132 with a standard error of 0.0108, which is not significant. Leads 3 and 4 are significant, at 0.0153 and −0.0257. Correct the note in `02_analysis.do`.~~
   ⚠️ **SUPERSEDED August 11, 2026.** The instruction above is itself wrong and must not be followed. The numbers it prescribes (0.0153, −0.0257) are Stata output that the R pipeline does not reproduce: lead 3 is **−0.0035, p = 0.21**, not significant and the opposite sign. The significant leads are **1, 2 and 4**. The note has been **retired rather than corrected**, and `table4_placebo_R` now computes significance instead of asserting it. Writing a third hand-authored version of this note is the failure mode. See `causal-did/PIPELINE_RECONCILIATION.md`.

3. **The event study needs an honest caption.** Post-period coefficients run +0.0194, −0.0079, +0.0128, −0.0072, +0.0013. Alternating signs are not a dynamic response. Say what the pattern is rather than letting a reader assume it supports the lag story.

---

## 7. Sequence to August 26

| By | Task |
| --- | --- |
| Aug 10 | Fix the three errors in section 6. Rerun `02_analysis.do`. |
| Aug 13 | Rebuild Figure 4 at publication quality. It is the paper. |
| Aug 17 | Draft Results and Discussion, figure by figure. |
| Aug 20 | Methods, then Introduction, then Conclusion. |
| Aug 23 | Abstract, Plain-Language Summary box, reference check. |
| Aug 24 | Set aside 45 minutes, read aloud, edit. |
| Aug 25 | Upload revised version to SSRN. |
| Aug 26 | Submit TEC2026 application with the new abstract and the SSRN link. |

---

## 8. Skeptic response plan

Built on three rules from the NABE Writing Skills workbook, July 29, 2026.

> **"Boss and their boss ⇒ skeptic."** The poster gets photographed and forwarded to someone tougher than whoever you spoke with. Write for the second reader.
>
> **"Where's your backup?"** answered **"in the next paragraph, not longer than 3 sentences."** Every concession sits next to its claim, never in a limitations block at the end.
>
> **"20 seconds."** If a reader stops after the headline and one sentence, the poster still worked.

A skeptic's power comes from being first to name the weakness. Name it first and it converts to credibility.

### The five attacks, ranked by damage

| # | Attack | Honest status | Where the answer goes |
| --- | --- | --- | --- |
| 1 | "Prove the two estimators differ." | **You lose this one.** Not significant at any horizon, closest h=2 at p=0.056. | Concede in the sentence after the comparison. Then pivot: the precision collapse is the claim, and it does not need this test. |
| 2 | "The 2009q1–2012q4 window is a researcher degree of freedom." | **Winnable on design grounds only. Justify from the ZLB, and disclose the sample mismatch below.** The reason recorded at the time was "financial crisis" (`01_clean_data.do` line 17), not ZLB — say both, and do not present ZLB as though it were the original wording. Supporting evidence that ZLB reasoning predates the results: `monetary_policy_labor.R` lines 125–126 (June 4) already split a "pre-ZLB benchmark (1976-2008)" from the "paper window (2002-2019, ZLB)." | Methods, first paragraph of the sample subsection. |

> ⚠️ **Retracted claim, August 7.** An earlier version of this row asserted that the 2009–2012 county files "were never acquired," citing `01_clean_data.do` line 24, and called this a physical constraint proving the exclusion could not have been results-driven. **That is false.** `Research_Monetary_Incidence/data/qcew_panel_all_years.dta` contains all 18 years — 51,568 rows for 2009–2012 across 3,223 counties, 22 percent of the panel. Line 24 is a comment describing the Stata pipeline's expected raw inputs, not a fact about what data exists. Do not use the "never acquired" argument anywhere. It is wrong and it is checkable in thirty seconds by anyone who opens the repo.
| 3 | "Weak first stage, then you used the surprise anyway." | **Winnable.** Bauer-Swanson surprises are the shock, not an instrument. Standard practice. | Methods, stated up front as a choice. Do not let it read as a fallback. |
| 4 | "Shift-share exogeneity runs through the shares." | **Partially.** Cite Goldsmith-Pinkham, Sorkin and Swift (2020) and Borusyak, Hull and Jaravel (2022). Rotemberg weights if time allows. | Methods subsection, and name it as the next step if the weights are not computed. |
| 5 | "Levels outcome, differenced regressor." | **Winnable.** The growth-rate specification already exists. | One sentence in Methods, one line in the robustness table. |

### The one line that does the most work

Place this directly under Figure 4, inside a box, surrounded by white space:

> The two estimators are not statistically distinguishable at any horizon. That is the point. A design whose precision survives only when the business cycle is left in was never identifying policy.

### Poster headline

Not "tightening raises employment." Closer to:

> **Precise and wrong, or honest and underpowered.**

The five-minute Lightning Talk is that line, Figure 4, and the boxed sentence above. Everything else answers questions.

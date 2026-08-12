# Pipeline Reconciliation — Stata vs R

*Abdallah Dalis · August 11, 2026 · `causal-did/`*

**Purpose.** This memo records why the Stata and R pipelines disagreed on the event-study post-period, what the four-configuration diagnostic settled, and which claims are now safe to publish. It exists so the Table 4 note is never rewritten a third time from a source that cannot be run.

---

## Plain-Language Summary

**What was asked.** Two versions of the same regression, one in Stata and one in R, gave different answers about how county employment responds after a monetary policy shock. Before publishing either, we needed to know which was right and why.

**What was found.** Neither. The Stata numbers cannot be reproduced by any configuration of the R code, so they are lost. The R numbers are reproducible but the post-period pattern is unstable across defensible choices, so it should not be described at all. One finding did survive, and it is the more useful one: a routine data-handling choice about how lagged variables are built cuts standard errors by 40 to 45 percent without meaningfully moving the estimates, which turns a clearly null result into one significant at 1 percent.

**What it means.** The paper argues that shift-share designs overstate precision. Here is that overstatement produced inside our own pipeline, by a choice that no published table would ever show.

**The honest limitation.** We can demonstrate that the standard errors shrink. We cannot yet explain the mechanism. Until that is understood, this is an observation, not a result.

---

## 1. The disagreement

| | t | t+1 | t+2 | t+3 | t+4 |
|---|---|---|---|---|---|
| Stata (`02_analysis.do`) | +0.0194 | −0.0079 | +0.0128 | −0.0072 | +0.0013 |
| R (time-aware, default) | +0.0034 | +0.0005 | +0.0021 | +0.0009 | +0.0095 |

Four sign changes against zero, and magnitudes differing by roughly a factor of five.

## 2. Hypotheses tested

Four configurations, crossing sample window (exclude 2009–2012 vs full) with lag construction (time-aware vs positional). Run via `Dalis_Abdallah_PipelineDiagnostic.R`.

**H1 — seam splicing. Mechanism confirmed, effect misdiagnosed.** Stata dropped 2009–2012 and *then* built lags positionally, so every county's 2013q1 row drew its lag-1 from 2008q4. The diagnostic confirms this hits **3,223 of 3,228 counties** and contaminates **64,460 lead/lag cells**, 4.5 percent of the total, concentrated where |ΔFFR| is largest. But it does **not** reproduce the Stata sawtooth: the Stata-faithful config returns −0.0017, −0.0010, +0.0080, +0.0100, +0.0071, one sign change, not four. The prediction that this would explain the alternating pattern was wrong.

**H2 — median split definition. Rejected.** Stata took the median over county-quarter rows with `>=`; R takes it over unique counties with `>`. The medians differ at the fourth decimal (0.456657 vs 0.455516) and reassign **one county out of 2,887**. Not the story.

**H3 — window mismatch. Untested, still open.** The `.do` figure notes say the exclusion window is 2008q4–2013q1 (18 quarters); both scripts actually drop calendar 2009–2012 (16 quarters). If `analysis_panel.dta` was built on the wider window, the samples differ by two crisis quarters. Worth ten minutes if the Stata numbers ever need to be recovered.

## 3. What survives

**Robust — the parallel-trends test fails.** In all four configurations. Lead 4 is negative and significant everywhere (−0.0150 to −0.0181). This is the paper's defensible core and it is not in doubt.

**Not robust — the event-study post-period shape.** `hi_inter` ranges from +0.0034 to −0.0041 across configurations, with significance flipping. **No characterization of the post-period is safe.** Do not call it dynamic, oscillating, or flat. Report the coefficients and say the shape is not identified.

**Orphaned — the Stata post-period.** Unreproducible by any config. Treat those five numbers as lost, not as evidence.

**Retired — the Table 4 note, both versions.** The original said "Lead 1 significant," which was false. The August 7 correction said "Leads 3 and 4 are significant (0.0153 and −0.0257)," which is also false under the time-aware pipeline: lead 3 is **−0.0035, p = 0.21**, not significant and the opposite sign. The significant leads are **1, 2 and 4**. The note is now retired rather than corrected, and `table4_placebo_R` computes the verdict instead of asserting it.

## 4. The new result: manufactured precision

Same data, same specification. Only the lag construction changes.

| term | b (time-aware) | b (positional) | SE (time-aware) | SE (positional) | p |
|---|---|---|---|---|---|
| `inter_lead1` | +0.0095 | +0.0130 | 0.00433 | 0.00248 | 0.029 → 0.0000 |
| `inter_lead2` | +0.0104 | +0.0098 | 0.00461 | 0.00283 | 0.024 → 0.0005 |
| `inter_lead3` | −0.0035 | −0.0066 | 0.00278 | 0.00180 | **0.208 → 0.0002** |
| `hi_lead2` | +0.0061 | +0.0062 | 0.00327 | 0.00134 | 0.064 → 0.0000 |

Standard errors fall 40 to 45 percent across the board. Point estimates barely move. A result with p = 0.21 becomes one with p = 0.0002.

This is the paper's thesis, self-demonstrated. *Spurious Precision* argues that shift-share designs borrow precision they have not earned. Here that happens inside our own code, through a choice invisible in any published table.

**Before this is claimed, the mechanism must be understood.** Splicing across the gap plausibly injects repeated or mechanically correlated values into the lag variables, understating genuine sampling variation. That is a hypothesis, not a finding. Publishing a precision result we cannot explain would repeat the error this memo exists to close.

### 4a. Mechanism test — hypothesis REFUTED (August 11)

`Dalis_Abdallah_PrecisionMechanism.R`. The hypothesis was that positional splicing destroys the within-county serial correlation that cluster-robust standard errors exist to correct, so the cluster adjustment stops biting. **Wrong on both halves.**

| test | prediction | result |
|---|---|---|
| SE_cluster / SE_iid, time-aware | well above 1 | **0.81** |
| SE_cluster / SE_iid, positional | near 1 | **0.72**, further from 1, not closer |
| within-county AC(1) of `inter_lead3` | large drop | 0.668 → 0.623, negligible |
| within-county AC(1) of `dffr`, `inter` | drop | **0.6134 under both**, identical |

Serial correlation is intact. The cluster adjustment does not stop biting. The mechanism is not what was proposed.

The boring explanations are also out: N is 150,004 vs 149,980 (24 observations apart) and sd(`inter_lead3`) is 0.2064 vs 0.2052. Neither moves an SE by 40 percent.

**Also note: the iid SEs fall too**, from ~0.0055 to ~0.0047, about 14 percent. So the shrinkage is not purely a clustering phenomenon. Roughly a third of the effect survives with no clustering at all.

### 4b. The anomaly this surfaced, which matters more

**Clustering by county makes the standard errors SMALLER than iid, in the published specification.** Mean ratio 0.81 time-aware, and below 1 for four of five terms (lead 4 is the exception at 1.26). That is backwards from what a county panel with a serially correlated regressor should produce, and it is true of the **canonical R specification**, not only the buggy Stata one.

This is worth more than the pipeline question. If county clustering is shrinking rather than inflating the standard errors, the paper's headline precision may be overstated for a reason that has nothing to do with the Stata bug — which is, verbatim, the paper's thesis, sitting in its primary specification.

**Working explanation, unverified:** the identifying variation is a single national time series (`dffr`) interacted with a county-constant exposure share. Counties with similar exposure therefore receive near-identical shocks, and that correlation runs *across* counties, not within them. Clustering by county cannot see it. This is the standard shift-share inference problem, and if it holds, county-clustered SEs are the wrong estimator for this design regardless of how the lags are built.

**Next step: exposure-robust inference, not more mechanism-chasing.** Recall Adão, Kolesár and Morales (QJE 2019), "Shift-Share Designs: Theory and Inference," on conventional standard errors being severely understated in exactly this setting — verify the reference before citing. Pair it with randomization inference (permute `exp_sens` across counties, rebuild the null distribution) for an assumption-free read on how much of the precision is real. That answers the paper's question directly, without needing to derive the analytic mechanism of a bug in a pipeline that can no longer be run.

### 4c. Randomization inference — the title's claim is NOT supported (August 11)

`Dalis_Abdallah_RandomizationInference.R`, 200 county-level permutations of `exp_sens` per construction, seed 20260811. `ratio` = sd(null) / analytic SE; above 1 means the analytic SE understates.

| term | ratio, time-aware | p analytic | p randomization |
|---|---|---|---|
| `inter` | 1.08 | 0.0000 | 0.000 |
| `inter_lead1` | 1.17 | 0.029 | **0.055** |
| `inter_lead2` | 0.98 | 0.024 | 0.015 |
| `inter_lead3` | 1.04 | 0.208 | 0.240 |
| `inter_lead4` | 0.72 | 0.005 | 0.000 |

**In the canonical specification, the county-clustered analytic standard errors are approximately honest.** Ratios sit at 1.08, 1.17, 0.98, 1.04, 0.72. There is no 40 percent understatement to report. The exposure-correlation explanation floated in 4b is **not supported by this test**, and the analytic and randomization p-values agree closely throughout.

**⚠️ But this test cannot detect the problem it was aimed at.** Free permutation of exposure across counties **destroys the spatial clustering of exposure**. Real manufacturing and construction shares are geographically concentrated, so real shocks hit spatially correlated blocks of counties; permuted exposure scatters them at random. The permutation null is therefore built on a world with less correlated treatment than the real one, and is likely too tight for the same reason the analytic SE may be. **A ratio near 1 here is not a clean bill of health — it may be two tight numbers agreeing with each other.** The Adão–Kolesár–Morales concern remains open and untested.

### 4d. The pipeline question, closed — but not as predicted

The prediction was that the positional build's null spread would match the time-aware one, showing its tighter analytic SEs were fake. It does not:

| term | sd(null) time-aware | sd(null) positional |
|---|---|---|
| `inter` | 0.00383 | 0.00282 |
| `inter_lead1` | 0.00506 | 0.00188 |
| `inter_lead3` | 0.00290 | 0.00165 |

The positional estimator genuinely has a tighter sampling distribution, and its analytic SEs match its own null (ratios 0.76 to 0.94). **So the positional build is not statistically overconfident. It is precisely estimating the wrong quantity.** Splicing lags across the 2009–2012 hole produces a regressor that is partly deterministic artifact, less correlated with county idiosyncratic shocks, and therefore lower-variance. Low variance around a corrupted target is a bias problem, not a variance problem, and no amount of inference will surface it. **Only cross-pipeline comparison catches this. Randomization inference inside the buggy pipeline endorses the bug:** `inter_lead3` gets p = 0.000 there against p = 0.240 in the canonical build.

### 4e. Where this leaves the paper — read before writing the abstract

Three separate tests have now failed to demonstrate spurious precision in the canonical specification: the mechanism test (4a), the cluster-inflation comparison (4b), and randomization inference (4c). **The title claim is currently unsupported by this paper's own evidence.**

What *is* robust, across every configuration and both inference methods:

> The parallel-trends assumption fails. Leads 2 and 4 are significant under both analytic and randomization inference, lead 1 is marginal (p = 0.055), and the failure holds in all four pipeline configurations. The shift-share DiD estimate therefore cannot be read causally.

That is a real, defensible, publishable contribution. It is not the same paper as *Spurious Precision*.

**Two honest routes before Aug 26.** Either run the test that could actually support the title — AKM exposure-robust standard errors, or a spatially constrained permutation (shuffle exposure within state or within CBSA) that preserves the geographic correlation free permutation destroys — or retitle around the pre-trends failure, which is already earned. Choosing the first and finding nothing still leaves the second available. Choosing neither and shipping the current title would be the exact error this memo exists to prevent.

### 4f. Within-state permutation — fourth failure, and the test was mis-specified (August 11)

Run under a pre-commitment: if the within-state null did not widen, the title changes and no fifth test gets run.

| term | sd(null) free | sd(null) within-state | widening | sd(state) / analytic SE |
|---|---|---|---|---|
| `inter` | 0.00383 | 0.00283 | **0.74** | 0.79 |
| `inter_lead1` | 0.00506 | 0.00337 | **0.67** | 0.78 |
| `inter_lead2` | 0.00450 | 0.00361 | **0.80** | 0.78 |
| `inter_lead3` | 0.00290 | 0.00212 | **0.73** | 0.76 |
| `inter_lead4` | 0.00449 | 0.00372 | **0.83** | 0.59 |

The null did not widen. It **narrowed**, by 17 to 33 percent, and every within-state null sits *below* the analytic SE. Read literally, the county-clustered analytic standard errors are **conservative**, not anti-conservative.

**The test was the wrong instrument, and the error was mine.** Restricting the shuffle to within-state means exposure can only move to a county with *similar* exposure, because industrial structure is regionally correlated. That is a **less aggressive** randomization, so the placebo estimates move less and the null narrows mechanically. It does not simulate correlated shocks across similarly exposed counties, which is what the Adão–Kolesár–Morales concern is about. AKM is about the variance contributed by a small number of common sectoral shocks; the right instrument is their variance estimator, or permutation of the **sectoral shocks**, not of the county exposures.

⚠️ **Do not read the within-state p-values as stronger evidence.** `inter_lead3` moves from p = 0.240 (free) to p = 0.100 (within-state), and `inter_lead2` from 0.015 to 0.000. Those are smaller only because the null is mechanically tighter. They are anti-conservative and should not be quoted.

**Formally, the AKM question remains untested.** Practically, it is now four tests in the same direction, and the pre-commitment binds. Continuing would be motivated search against a deadline, which is a worse failure than a narrower title.

### 4g. ⚠️ RETRACTED WITHIN THE HOUR — I TESTED THE WRONG HALF OF THE PAPER

**Everything in 4g below is wrong and the title does not change.** The error, stated plainly: sections 4a through 4f test the **shift-share difference-in-differences** in `causal-did/`. The paper's spurious-precision claim was never about that. It rests on the **local projections** in `monetary_policy_labor.R`, which compare raw federal funds rate changes against Bauer–Swanson high-frequency identified surprises. Different estimator, different file, different evidence. I never opened it, and then recommended retitling on the strength of four tests that could not have spoken to the claim.

The LP evidence, from `tables/tab_signflip.csv`, is intact:

| horizon | raw b (se) | identified b (se) | SE ratio |
|---|---|---|---|
| 0 | 0.198 (0.077) | −0.388 (0.497) | **6.5×** |
| 3 | 0.888 (0.131) | −1.281 (1.566) | **12.0×** |
| 6 | 1.252 (0.257) | −1.916 (2.630) | **10.2×** |
| 12 | 0.657 (0.518) | −2.417 (3.264) | **6.3×** |

Raw is significant at 11 of 13 horizons and positive at all 13. Identified is significant at 0 of 13 and negative at all 13. **Identified standard errors run 6.3 to 12.0 times wider.** That is the spurious precision, it is real, and the title is earned.

**What 4a–4f actually established** is narrower and still worth having: the DiD half of the paper does *not* exhibit a standard-error pathology. Its SEs survive four checks and look conservative by the last one. So the two halves fail for **different reasons** — the LP half shows precision borrowed from the business cycle, the DiD half shows a parallel-trends violation. That is two independent diagnostics, which is the structure the revision memo already anticipated at line 133. It strengthens the paper rather than weakening it.

**The methodological lesson, which is the same one this memo keeps recording:** I anchored on the first artifact I opened, spent four tests inside it, and never checked whether it was the artifact the claim came from. Verify which file a claim lives in before testing it.

### 4h. Full-window randomization inference — the pre-trends claim is verified (August 11, later)

Run after the window decision, to make the abstract's "under both clustered and randomization inference" sentence cover the headline window rather than only the excluded one.

**First, a bug that would have faked the verification.** `Dalis_Abdallah_RandomizationInference.R` never read `EXCLUDE_ZLB`. The exclusion was hardcoded, so the documented command `EXCLUDE_ZLB=FALSE Rscript ...` set an environment variable nothing consumed. It would have run cleanly, printed a full table, and returned the **excluded**-window result under a full-window label. Patched: the switch now matches `Dalis_Abdallah_CausalDiD_Analysis.R` line 100, outputs are tagged `zlb-full` / `zlb-excl`, and the console prints the window it ran. Verified output line: `window : full 2002-2019`.

**Result, time-aware construction, free permutation, full 2002–2019:**

| term | b | analytic SE | t | sd(null) | ratio | p_ri |
|---|---|---|---|---|---|---|
| `inter` | 0.02401 | 0.00367 | 6.54 | 0.00392 | 1.07 | 0.000 |
| `inter_lead1` | 0.00961 | 0.00435 | 2.21 | 0.00509 | 1.17 | 0.055 |
| `inter_lead2` | 0.01113 | 0.00456 | 2.44 | 0.00445 | 0.98 | **0.010** |
| `inter_lead3` | −0.00336 | 0.00274 | −1.23 | 0.00285 | 1.04 | 0.260 |
| `inter_lead4` | −0.01806 | 0.00626 | −2.89 | 0.00450 | 0.72 | **0.000** |

**The abstract sentence is verified.** Leads 2 and 4 clear 5 percent under both clustered and randomization inference in the headline window. "Two of four" stays the correct conservative count: analytically leads 1, 2 and 4 are significant, but lead 1 is p_ri = 0.055 and fails the "both methods" bar.

**The window does not matter here.** Free-permutation ratios are 1.07, 1.17, 0.98, 1.04, 0.72 full window against 1.08, 1.17, 0.98, 1.04, 0.72 excluded. The §4f within-state pattern also reproduces: ratios 0.79, 0.78, 0.78, 0.76, 0.59, all below 1, null narrowing rather than widening. Fifth run, same direction, no new information.

**Note on `inter` = 0.02401.** This is the `placebo` spec, which includes the four leads. It is **not** the headline coefficient. The headline is `main_spec`, 0.0223 full window. See `ABSTRACT_2026-08-11.md` §"What changed," item 1.

**⚠️ Trap removed from the script.** Its console guidance read *">1 IS THE RESULT THAT SUPPORTS THE PAPER'S TITLE"* and *"~1 means the title should change."* Both were written before the §4g retraction and both are wrong: this script tests the DiD, and the title rests on the local projections. Read literally against these ratios it would have prompted a sixth retitle. The `cat` block now carries the retraction inline.

---

### 4g (RETRACTED). Decision — the title changes

Four tests have failed to find spurious precision in the canonical specification: the mechanism test (4a), the cluster-inflation comparison (4b), free-permutation randomization inference (4c), and the within-state permutation (4f). The design's reported standard errors survive every check available in the time remaining, and by the last one they look conservative.

**The paper's earned claim, and the whole of it:**

> County employment responds to monetary policy shocks in proportion to construction and manufacturing exposure, with a contemporaneous elasticity of 0.022. **But the parallel-trends assumption fails.** Leads 2 and 4 are significant under both analytic and randomization inference, lead 1 is marginal (p = 0.055), and the failure is robust across all four pipeline configurations and both permutation schemes. The shift-share difference-in-differences estimate cannot be read causally.

Nothing above depends on a Stata output that no longer runs, on a mechanism that was never identified, or on a precision claim the data declined to support four times.

**Retitle around the pre-trends failure.** Candidate direction, not final: the paper is about a shift-share design that produces a clean, precisely estimated, and *uninterpretable* coefficient — and about how the pre-trends test is the thing that catches it. That is a real methodological contribution, it is fully supported, and it is the paper that actually exists on disk.

## 5. File status

| File | Status |
|---|---|
| `Dalis_Abdallah_CausalDiD_Analysis.R` | **Canonical.** Table 4 note computed, not asserted. |
| `Dalis_Abdallah_PipelineDiagnostic.R` | Four-config comparison. Rerun after any spec change. |
| `output/tables/table4_placebo_R.*` | **Canonical Table 4.** |
| `output/tables/table5_event_study_R.*` | **Canonical Table 5.** Post-period shape not to be described. |
| `output/tables/table4_placebo.*` | Superseded, marked in place. Do not cite. |
| `output/tables/table5_event_study.*` | Superseded, marked in place. Do not cite. |
| `02_analysis.do` | Provenance only. Cannot be run. |

The four superseded artifacts are marked but **not deleted or moved**, pending Abdallah's call. Deleting them removes the provenance trail; keeping them risks a stale `\input`. Recommendation: move all four to `output/tables/superseded_stata/` rather than delete.

## 6. Open items

1. Decide the fate of the four superseded artifacts (move recommended).
2. Explain the standard-error shrinkage before claiming it.
3. Test H3, the 16- vs 18-quarter exclusion window, if the Stata numbers matter.
4. Settle whether the GFC exclusion was chosen on zero-lower-bound grounds or after seeing results. Only Abdallah knows, and a referee will ask.

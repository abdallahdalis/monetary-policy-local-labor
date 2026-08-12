# Figure Plan — *Spurious Precision* merged manuscript

*Abdallah Dalis · August 11, 2026 · steps 2 and 3 of `00_Resources/research-paper-writing-process.md`*

**Purpose.** Decide which figures carry the merged paper before any prose is written. The process rule is that no section gets written whose content is not yet supported by a figure, table, or estimated result, so this file is the gate.

**Context.** The merged paper draws on two existing manuscripts: the SSRN posting (`mennis-submission/`, shift-share DiD) and the ECO 508 course paper (`report.tex`, VAR, SVAR, local projections, random forest). Thirteen figures exist across both. Six survive.

---

## The paper's argument, in one line

A shift-share design returns a tight, wrong-signed employment effect. Two independent diagnostics reject reading it causally: the design fails its own pre-trends test, and replacing the endogenous rate change with identified surprises collapses precision by a factor of 6 to 12.

Every figure below earns its place against that sentence. Anything arguing about the **sign** rather than the **precision** is cut, for the reason given in the next section.

---

## The cut that matters: VAR, SVAR, and the LP-versus-VAR overlay

**Cut `fig2_var_irf`, `fig3_svar_irf`, and `fig6_lp_vs_var`.**

These figures exist to establish that theory and conventional time-series evidence say employment should *fall*. That was the right spine for the ECO 508 paper, which asked whether the positive sign came from aggregation or identification.

It is the wrong spine here. The abstract concedes, early and deliberately, that the raw and identified estimators are **not statistically distinguishable at any horizon** (smallest p = 0.056). The paper's claim is the collapse in precision, not the change in sign. Importing a VAR to argue the correct sign reintroduces exactly the argument the paper declines to make, and it invites the first referee question you do not want: *if the sign evidence is this strong, why is it not your headline?*

A citation to Carlino and DeFina (1998) does the same work in one sentence, with no figure and no exposure.

**Also cut `fig7_rf` and `fig8_rf_pdp`.** Random forest predictability is a different question. The finding there (lower RMSE, zero correlation with realized growth) is real and worth keeping in the ECO 508 paper, but it has no bearing on whether a shift-share design overstates precision.

**Retire `fig4_signflip`.** Superseded by `fig4_raw_vs_identified`, which adds the confidence bands. The bands are the finding; the point-estimate version asserts a sign reversal the data does not support. Do not cite the old file.

---

## The six figures

Ordered context → key pattern → implication, per step 3.

| # | Figure | Source | Question it answers | Status |
|---|---|---|---|---|
| 1 | County exposure map, 2002 | `causal-did/output/figures/exposure_map_2002.pdf` | Where does the cross-sectional variation come from? | **Exists** |
| 2 | The two shock measures, 2002–2019 | `figures/fig2_shock_comparison.png` | What does "removing the cycle" actually remove? | **BUILT Aug 11** |
| 3 | Pre-period leads, both windows | `causal-did/output/figures/fig3_pretrends.png` | Does the design pass its own pre-trends test? | **BUILT Aug 11**, replaces the event study |
| 4 | Randomization-inference null distributions | `causal-did/output/figures/fig_randomization_inference_zlb-full.png` | Does the pre-trends failure survive assumption-free inference? | **Exists** (regenerated Aug 11, full window) |
| 5 | Raw vs identified local projections, with bands | `figures/fig4_raw_vs_identified.png` | What happens when the endogenous shock is replaced? | **Exists** |
| 6 | Precision collapse, standard errors by horizon | `figures/fig5_precision_collapse.png` | How large is the overstatement? | **Exists** |

Figures 1 and 2 set the stage. Figures 3 and 4 are diagnostic one. Figures 5 and 6 are diagnostic two. The two diagnostics are independent and fail for different reasons, which is the structure of the paper.

### Figure 2 is the gap, and it is the important one

The paper's central move is substituting Bauer-Swanson high-frequency surprises for the realized quarterly change in the federal funds rate. **There is currently no figure showing those two series together.** A reader is asked to accept that one is contaminated by the business cycle and the other is not, on assertion.

Plot both over 2002–2019 on a common axis, with recession shading. The visual point is that the raw series tracks the cycle and the identified series looks close to noise. That is the entire mechanism of the paper in one panel, and it belongs before the results rather than after.

Data are already joined in `monetary_policy_labor.R` at the `nat <- inner_join(ffr_q, bsq, ...)` step. This is a short script, not new analysis.

#### Built August 11. Script: `Dalis_Abdallah_ShockComparison_Figure.R`

Four panels. Top row plots each series on its own scale with the NBER recession shaded. Bottom row is the argument: each shock against contemporaneous national employment growth, 71 quarters.

| | vs employment growth | R² |
|---|---|---|
| Raw ΔFFR | **+0.470** (p < 0.0001) | 0.220 |
| Identified surprise | −0.119 (p = 0.321) | 0.014 |

`cor(raw, identified) = −0.010`. The two measures the literature treats as substitutes share essentially no variation, and only one of them tracks the cycle.

**The leverage objection was tested and it reversed.** The bottom-left scatter is visibly leveraged by crisis quarters, so a referee will say the correlation is a 2008 artifact. It is not:

| sample | n | r(raw, emp) | r(identified, emp) |
|---|---|---|---|
| full 2002–2019 | 71 | +0.470 | −0.119 |
| excl 2009–2012 | 55 | **+0.662** | −0.077 |
| full, Spearman | 71 | **+0.502** | −0.048 |

Dropping the crisis window makes the endogeneity **stronger**, and the rank correlation rules out a magnitude artifact. Both robustness figures print on the panels themselves, not only in the caption.

**Why, and it belongs in the Discussion.** At the zero lower bound the funds rate was pinned while employment moved a great deal. Those quarters pair near-zero ΔFFR with large employment swings, which drags the correlation toward zero. They are periods when the Fed *could not* react, so they attenuate the measured reaction function. **The consequence: the full-window headline is the conservative choice.** The endogeneity being priced is larger in the robustness window than in the headline one. Say so, and it preempts the referee who assumes the window was chosen to flatter the result.

**Three constraints on how this figure gets written up**, printed by the script as an interpretation guard:

1. It documents correlation with the cycle. It does **not** establish the sign of the employment response, and the paper does not claim a sign flip.
2. The near-zero correlation between the two measures is **partly by construction**, since `MPS_ORTH` is the orthogonalized series. Do not present −0.010 as a discovery. The point is that the literature substitutes one for the other regardless.
3. The positive sign on the raw correlation cannot be the causal effect of tightening, because that would mean tightening raises employment, which is the reading this paper rejects. It is the Fed reacting to a strong labor market. This is the answer when a referee asks.

### Figure 3: parameterization settled August 11, and it was not cosmetic

Two pre-trend objects live in the codebase and they **disagree about which leads fail**:

| spec | parameterization | significant leads, full window |
|---|---|---|
| `placebo` | continuous, `inter_lead1..4` | **1, 2, 4** |
| `event_study` | binary high vs low, `hi_lead1..4` | **3, 4** (lead 2 marginal, p = 0.068) |

Lead 3 is the sharp disagreement: −0.0034 (p = 0.219) against +0.0044 (p = 0.004). Opposite sign, opposite verdict.

**Decision: the paper uses the `placebo` spec.** The abstract's count and the randomization inference in `PIPELINE_RECONCILIATION.md` §4c and §4h were both computed on those coefficients, so it is the parameterization the evidence is actually verified on. Switching the text to the event study would mean re-running randomization inference on `hi_lead*` and rewriting the abstract. Switching the figure was one script.

A second benefit: Figures 3 and 4 now show the **same object**. Figure 3 gives the analytic intervals, Figure 4 gives the same coefficients under permutation. That is better exposition than two figures of two different things.

The event-study parameterization is **out** of the pre-trends claim. Do not mix them.

#### Built August 11. Script: `causal-did/Dalis_Abdallah_PreTrendsFigure.R`

Both windows in one panel, offset so intervals do not overlap. Showing them together is the point: the window is reported rather than defended, so the reader should see that the verdict does not turn on it.

| lead | full 2002–2019 (n = 196,148) | excl 2009–2012 (n = 150,004) |
|---|---|---|
| 1 | +0.0096 (p = 0.027) | +0.0095 (p = 0.029) |
| 2 | +0.0111 (p = 0.015) | +0.0104 (p = 0.024) |
| 3 | −0.0034 (p = 0.219) | −0.0035 (p = 0.208) |
| 4 | −0.0181 (p = 0.004) | −0.0177 (p = 0.005) |

Identical verdict, agreeing to three decimal places. Parallel trends fails in both.

**Three leads reject, but the paper reports "two of four."** That gap is deliberate: only leads 2 and 4 also reject under randomization inference, and lead 1 is marginal at p = 0.055. Counting the intersection rather than the union is the conservative reading. **A reader comparing the figure to the abstract will otherwise see a contradiction**, so the reconciliation now appears in the figure subtitle, the generated caption, and §5.4 of the draft. The three move together or not at all.

The significance annotation is computed from the estimates at run time, never typed. The Table 4 note in this project has been wrong twice and retired once; no hand-written significance claim should survive in this codebase.

### A constraint that applies to Figure 3 as well as the event study

**Do not describe the post-period shape in the caption or the text.** `PIPELINE_RECONCILIATION.md` section 3 records that `hi_inter` ranges from +0.0034 to −0.0041 across defensible configurations with significance flipping. Report the coefficients and state that the post-period shape is not identified. Do not call it dynamic, oscillating, or flat.

**Extend the same discipline to the pre-period shape.** Leads 1 and 2 are positive, lead 4 is negative, lead 3 is null. That is not monotone, and it invites a story. Do not tell one. The claim the paper needs is that the leads are **not zero**, and only that claim is robust. The pre-period leads happen to be stable across windows, which makes the temptation to characterize them stronger than it was for the post-period, not weaker.

---

## Undecided, parked deliberately

**`fig5_lp_bigcounty`.** Local projections on large counties, regressing employment growth on `MPS_ORTH` alone with county fixed effects. Note that this is a **level** local projection, not the exposure interaction, so it is a different object from Figures 5 and 6 and cannot sit beside them without explanation. Candidate for an appendix robustness note; more likely a cut. Decide when the Results section reaches it, not before.

**`fig1_series`** (FFR level, dFFR, employment growth, inflation, with ADF and KPSS). Genuinely useful as a data figure, but it may be redundant once Figure 2 exists. Build Figure 2 first, then look at both together and decide.

---

## Standing constraints on every figure

- PNG at 150 dpi, 2100×1500 or 2100×1050, `layout()` for legend strips beneath the plot, palette steelblue / firebrick / darkgreen / darkorange3. Per `00_Resources/output-standards.md`.
- Captions generated from the estimates rather than hard-coded, following the pattern already in `Dalis_Abdallah_SpuriousPrecision_Figures.R` section 5.0. A hard-coded caption drifts; a printed one cannot.
- Bottom line readable in about 10 seconds. Relaxed standard applies here (econometric figures), but the takeaway must still be findable fast.
- Manuscript is LaTeX compiled to PDF, and it gets a **Plain-Language Summary box** in the Dalis style. Not optional.

---

## Open item found while writing this

`TASKS.md` carries an unticked item, "Rebuild Figure 4 with confidence bands." **This is already done.** `Dalis_Abdallah_SpuriousPrecision_Figures.R` was written August 7 and produced `fig4_raw_vs_identified.png` and `fig5_precision_collapse.png` the same day. The task line predates the work and was never closed.

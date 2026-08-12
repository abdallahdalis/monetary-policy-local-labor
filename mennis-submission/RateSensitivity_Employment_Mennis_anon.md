# Rate Sensitivity and Employment: A Shift-Share Difference-in-Differences Analysis of Federal Funds Rate Changes on County-Level Employment

*Running head: Rate Sensitivity and Employment*

**Keywords:** monetary policy transmission; shift-share difference-in-differences; regional labor markets; high-frequency identification; federal funds rate

---

## Abstract

A county-level shift-share difference-in-differences design interacting predetermined 2002 construction-and-manufacturing exposure with the realized change in the federal funds rate yields a robust positive employment response to tightening—rate-sensitive counties appear to gain jobs when the Fed raises rates. This paper asks whether that sign is real or an identification artifact. Holding the design fixed and replacing the endogenous rate change with an identified high-frequency monetary surprise flips the exposure interaction negative at every horizon, matching theory and national vector-autoregression evidence. The positive sign reflects policy-rate endogeneity, not regional structure—a caution for practitioners building regional rate-exposure measures.

---

## 1. Introduction

Analysts who advise businesses on where to expand, whom to lend to, and how to staff increasingly want a regional answer to a national question: when the Federal Reserve moves interest rates, which local economies feel it most? A natural and widely used way to build such a regional rate-exposure measure is to interact a locality's industry mix—how concentrated it is in credit-sensitive sectors like construction and manufacturing—with the change in the policy rate. This paper shows that the most natural version of that calculation returns the wrong sign, why it does, and how to fix it cheaply. That matters for application: a regional risk indicator that tells a lender or a site-selection team that rate-sensitive markets *benefit* from tightening would steer capital and hiring in precisely the wrong direction. The "so what" here is concrete—the design choice between the realized policy rate and an identified policy surprise changes the sign of the answer a practitioner gets.

The substantive question has a long pedigree. A tradition in regional macroeconomics holds that contractionary monetary policy reduces employment, and that interest-sensitive local economies—those concentrated in construction and durable-goods manufacturing—contract *more* [Carlino and DeFina 1998]. Counties differ sharply in industrial composition, and industries differ in their sensitivity to credit conditions, so the geographic footprint of a rate change should be uneven and, in principle, predictable from local industry shares.

A shift-share difference-in-differences (DiD) design built to test this prediction reverses it. Interacting the quarterly change in the federal funds rate with predetermined 2002 construction-and-manufacturing exposure across roughly 2,900 U.S. counties yields a positive, statistically significant interaction (contemporaneous coefficient 0.020, cumulative four-quarter effect 0.042, both significant at the 1 percent level). Read literally, high-exposure counties *gain* employment when the Fed tightens—at odds with both theory and the conventional vector-autoregression (VAR) evidence.

This paper asks a precise question: **is the positive sign an artifact of spatial aggregation, or of identification?** The two explanations carry very different lessons. If aggregation drives it, the county design is capturing something real that coarser geographies miss, and the positive sign is a finding. If identification drives it, the problem is that the realized funds-rate change is endogenous—it rises precisely when the economy, and interest-sensitive sectors with it, is booming—so the "effect" is reverse causation, and replacing the endogenous rate with an exogenous policy *surprise* should restore the contractionary sign.

The contribution is to confront the two explanations within a single, internally consistent design. I hold the shift-share structure fixed and vary only the source of policy variation, benchmarking against national VAR and structural-VAR systems. Three results follow. First, the realized-rate DiD puzzle is robust: it survives alternative base years, an alternative outcome, and placebo tests, so it is not a fragile specification choice—which is exactly what makes the next step decisive. Second, and centrally, when the endogenous rate change is replaced with an identified Bauer-Swanson high-frequency surprise, the exposure interaction flips sign from significantly positive to negative at every horizon, though the surprise-based estimates are imprecise. Third, national VARs reproduce the textbook negative employment response on a clean pre-2008 sample but invert over 2002-2019, because the zero-lower-bound (ZLB) episode strips the funds rate of policy content—an independent demonstration of the same endogeneity mechanism. The evidence points to identification, not aggregation. The positive sign is an endogeneity artifact; the underlying effect is contractionary.

The remainder of the paper reviews the relevant literature (Section 2), describes the data (Section 3) and the empirical strategy (Section 4), presents results (Section 5), draws out the implications for applied practice (Section 6), and concludes (Section 7).

## 2. Background and Related Work

*The regional transmission benchmark.* The empirical benchmark is Carlino and DeFina [1998], who ask whether U.S. regions respond differently to a common monetary shock and whether structural features explain the heterogeneity. Estimating a structural VAR across BEA regions, they find that durable-manufacturing-heavy regions contract more sharply than the national average, with the gaps lining up with industry mix and small-firm shares. Theirs is the canonical statement of the prediction the realized-rate DiD violates: greater interest-sensitivity should mean a *larger* contraction, not an employment gain. Romer and Romer [2004], using narrative identification, likewise find that contractionary shocks reduce industrial production and employment. These studies establish that transmission to labor markets exists; they say less about its geographic distribution.

*Shift-share identification.* The design here is a shift-share (Bartik) object, interacting national policy variation with predetermined local industry shares [Bartik 1991]. Goldsmith-Pinkham, Sorkin, and Swift [2020] show that such a design is numerically equivalent to using the predetermined shares as instruments, so identification rests on the exogeneity of the shares and is driven largely by the cross-section. Borusyak, Hull, and Jaravel [2022] develop the complementary view in which identification can rest on the shocks, valid under many quasi-randomly assigned shifts provided no small set dominates. Both warnings bite here: with few and endogenous monetary "shifts," and exposure shares plausibly correlated with county trajectories, a shift-share design is exactly the configuration in which an endogenous policy rate can flip a coefficient's sign.

*High-frequency identification.* The corrective shock comes from the high-frequency identification literature. Gürkaynak, Sack, and Swanson [2005] show that narrow-window changes in money-market futures around FOMC announcements isolate the component of policy that markets did not expect. Nakamura and Steinsson [2018] use such surprises to measure monetary non-neutrality and document a "Fed information effect," whereby announcements also reveal the central bank's private read on the economy—the leading alternative explanation for perverse-signed responses, which I carry into the limitations. Bauer and Swanson [2023] show that raw surprises are partly forecastable from pre-announcement conditions and recommend orthogonalizing them; I adopt their cleaned series.

*Estimation.* National benchmarks follow the recursive structural-VAR template of Christiano, Eichenbaum, and Evans [1999]. The cross-sectional responses use the local projections of Jordà [2005], which Plagborg-Møller and Wolf [2021] prove estimate the same population impulse responses as VARs, so any divergence reflects shock measurement rather than the estimator [Coibion 2012]. Where an identified surprise is available, Gertler and Karadi [2015] and Stock and Watson [2018] formalize its use as an external instrument; I show below that the external-instrument route is infeasible at quarterly frequency and the surprise must enter directly as the shock.

## 3. Data

*County employment.* County-quarter employment is total private employment from the Quarterly Census of Employment and Wages (QCEW), published by the Bureau of Labor Statistics, with near-universal employer coverage through mandatory unemployment-insurance reporting. The panel spans 2002Q1 through 2019Q4 for 2,887 counties. The 2008Q4-2013Q1 zero-rate window is excluded because the funds rate carries no policy variation there (discussed in Section 5), leaving 155,757 county-quarter observations. The outcome is the natural log of county employment.

*Exposure.* The exposure measure is each county's 2002 share of employment in construction (NAICS 23) and manufacturing (NAICS 31-33), from the Census Bureau's County Business Patterns (CBP). Because it is fixed at 2002—before the sample begins—it is predetermined with respect to all subsequent rate decisions and employment outcomes. Roughly 846 counties appear in the QCEW but not the 2002 CBP and are dropped; they are geographically dispersed with no distinctive industrial profile, so for their omission to bias results they would need to differ in both industry composition and rate response simultaneously.

*Policy variation.* Two measures of policy variation are used. The first is the quarterly change in the effective federal funds rate from FRED (series FEDFUNDS), the endogenous measure that drives the puzzle. The second is the Bauer and Swanson [2023] orthogonalized high-frequency surprise (monthly, summed to quarters), the identified measure used to resolve it. National monthly series for the VAR benchmarks—the funds rate, total nonfarm payrolls (PAYEMS), and the CPI (CPIAUCSL)—are also from FRED; employment and prices enter as 100 × Δlog.

⟨⟨Table 1 here⟩⟩

Summary statistics for the national monthly series appear in Table 1. The funds-rate change is sharply non-normal (excess kurtosis 15.9): it sits near zero throughout the ZLB and moves only in discrete tightening and easing episodes. This near-degeneracy of the realized rate over the sample is the seed of both the DiD puzzle and the VAR inversion documented below.

⟨⟨Figure 1 here⟩⟩

Figure 1 maps the 2002 exposure measure, showing the predetermined geographic variation—concentrated in the industrial Midwest and parts of the South—that the design exploits.

## 4. Empirical Strategy

*The shift-share DiD.* The main specification regresses log county employment on the interaction of the quarterly funds-rate change with predetermined exposure:

ln(Emp_ct) = β₁ ΔFFR_t + β₂ Exposure_c + β₃ (ΔFFR_t × Exposure_c) + γ_c + δ_t + ε_ct,

where γ_c are county fixed effects absorbing all time-invariant county characteristics, and δ_t are quarter fixed effects absorbing every aggregate shock common to all counties in a quarter—including the level and change of the funds rate itself, which is collinear with the quarter effects. The coefficient β₃ is therefore identified purely from cross-sectional heterogeneity in employment responses across counties with different industry mixes, not from aggregate time-series variation in rates. Standard errors are clustered by county. A distributed-lag version adds four quarterly lags of the interaction; an event-study version replaces continuous exposure with an above-median indicator interacted with leads and lags of the rate change.

*The identification test.* The design's Achilles heel is that the funds-rate change is endogenous to the cycle. The quarter fixed effects absorb its aggregate level, but the *interaction* with exposure can still inherit endogeneity if the Fed reacts to conditions in rate-sensitive sectors—generating a mechanical correlation between rate changes and current employment in high-exposure counties. To test this directly, I hold the shift-share structure fixed and swap the source of policy variation. Using the local-projection form of Jordà [2005], I estimate the exposure interaction at each horizon h,

100 (ℓ_{c,t+h} − ℓ_{c,t−1}) = α_c^h + δ_t^h + θ_h (shock_t × exposure_c) + ε_{c,t+h},

twice: once with shock_t = ΔFFR_t, the endogenous rate change that produces the puzzle, and once with shock_t = s_t, the identified Bauer-Swanson surprise. County and time fixed effects absorb the level of the shock and of exposure, so θ_h is identified from the differential response by exposure; standard errors are clustered by quarter, since the identifying variation lives in the 72 quarterly shocks. I use the surprise directly as the shock rather than as an instrument for ΔFFR_t because the quarterly first stage is empty: regressing ΔFFR_t on the orthogonalized surprise yields an F-statistic near zero. Because the orthogonalized surprise does not move the realized quarterly rate, the external-instrument approach of Gertler and Karadi [2015] and Stock and Watson [2018] is infeasible, and entering the surprise directly is the standard fallback [Coibion 2012].

*National benchmark.* To corroborate the mechanism independently of the cross-section, I estimate a reduced-form VAR in inflation, employment growth, and the funds-rate change, with lag length chosen by standard criteria, and a recursively identified structural VAR in the manner of Christiano, Eichenbaum, and Evans [1999], with the funds rate ordered last. Each is estimated on a clean pre-ZLB benchmark (1976-2008) and re-estimated on 2002-2019 to isolate the effect of the zero lower bound.

## 5. Results

*The puzzle.* Table 2 reports the main DiD. The contemporaneous interaction is 0.020 (s.e. 0.004, p < 0.01): a one-percentage-point rise in the funds rate is associated with roughly 2 percent higher employment in a fully construction-and-manufacturing county relative to one with none. In the distributed-lag specification, the contemporaneous term is near zero and the effect builds, peaking at the third lag—about nine months out—at 0.025 (p < 0.01); the cumulative four-quarter effect is 0.042 (s.e. 0.011, p < 0.01). The lag pattern is economically sensible if read at face value: construction and manufacturing projects involve planning and contracting delays. The sign, however, is backwards.

⟨⟨Table 2 here⟩⟩

*The puzzle is robust—which is the point.* A natural first reaction is that the positive sign is a specification fluke. It is not. Table 3 re-estimates the main interaction with exposure measured from the 2003, 2013, and 2014 CBP, and with quarterly employment growth as the outcome. The interaction is positive and significant at the 1 percent level in every case, clustering tightly between 0.019 and 0.023 across base years spanning twelve calendar years. The robustness matters not because it validates the finding but because it rules out the easy explanations: the puzzle is a stable property of the realized-rate design, so resolving it requires changing the *identification*, not the specification.

⟨⟨Table 3 here⟩⟩

*Early warning: the Fed reacts to these sectors.* Table 4 reports a placebo/leads specification, interacting exposure with *future* rate changes. Anticipation cannot plausibly explain a relationship between current employment and rate changes three to four quarters ahead, which firms cannot observe. Yet the third and fourth leads are statistically significant and alternate in sign. The natural reading is reverse causality at the aggregate level: the Federal Reserve responds to labor-market conditions in construction and manufacturing, generating a mechanical correlation between future rate changes and current high-exposure employment. The event study tells the same story—a significant contemporaneous effect alongside significant pre-period coefficients with no clean pre-trend. These are the fingerprints of endogeneity, and they motivate the identification test.

⟨⟨Table 4 here⟩⟩

⟨⟨Figure 2 here⟩⟩

*Aggregation or identification? The national VAR.* Figure 2 isolates the mechanism away from the cross-section. On the clean 1976-2008 benchmark, the reduced-form and structural VARs deliver the textbook result: a contractionary shock produces a hump-shaped employment decline, troughing near −0.38 percent (structural trough near −0.20 percent). Re-estimating the identical specification on 2002-2019 *inverts* the response to strongly positive (about +2.45 percent at a one-year horizon, i.e., 12 months in the monthly VAR). The reason is the zero lower bound: with the funds rate pinned near zero from late 2008 through 2015, its change carries almost no policy content, and the VAR recovers reverse causation—rates rise as employment recovers. The same endogeneity that contaminates the realized-rate DiD interaction contaminates the realized-rate VAR. This is an aggregation-free demonstration of an identification problem.

*The sign reversal.* Table 5 and Figure 3 are the paper's central result. Using the endogenous funds-rate change in the shift-share interaction reproduces the puzzle: the exposure interaction is positive and strongly significant at every horizon, rising from +0.20 (p < 0.05) at impact to +1.25 (p < 0.01) by six quarters. Replacing it with the identified Bauer-Swanson surprise—changing nothing else—flips the coefficient negative at every horizon, from −0.39 to −2.01, deepening with the horizon and matching the contractionary prediction of theory and the national VAR. The surprise-based estimates are not individually significant (|t| ≤ 1.2), reflecting the limited variation in 72 quarterly shocks; the result is the *contrast*. A precisely estimated positive coefficient under the endogenous rate, and a uniformly negative coefficient under the identified shock, is what an endogeneity artifact looks like.

⟨⟨Table 5 here⟩⟩

⟨⟨Figure 3 here⟩⟩

*A caution on the cross-section.* The exposure gradient is not robust to county size. Among the twenty largest counties split by exposure—so size is roughly held fixed—high- and low-exposure metros contract *similarly* after an identified shock (difference |t| < 1.3 at all horizons). Extreme-exposure counties tend to be small, specialized places, so a naive high-versus-low split confounds exposure with size and diversification. The honest reading reinforces the thesis: identification, not a clean cross-sectional exposure channel, drives the sign. Clean shocks lower employment broadly; the DiD's positive interaction was an endogeneity artifact.

## 6. Implications for Applied Practice

The practical lesson is specific and actionable. Practitioners—regional economists, commercial and bank credit analysts, real-estate and construction strategists, site-selection teams—routinely gauge local exposure to monetary policy by interacting local industry mix with movements in the policy rate. This paper shows that the most natural implementation, using the realized change in the funds rate, returns the wrong sign in a precisely estimated and robust way. A regional risk model built that way would report that construction- and manufacturing-heavy markets *gain* employment when the Fed tightens, understating downside risk in exactly the markets most exposed to it.

The fix is cheap. Orthogonalized high-frequency monetary surprises are now publicly maintained and updated [Bauer and Swanson 2023]; substituting them for the realized rate, inside the same exposure design, recovers the theory-consistent contractionary sign. The broader caution generalizes beyond this application: any indicator that interacts a cross-sectional exposure with the realized policy rate is most vulnerable precisely when the policy rate is most endogenous—during the cyclical turns and at the effective lower bound, when practitioners most need it to be right. Whenever the realized rate and an identified surprise are both available, the surprise is the safer input for a regional exposure measure.

## 7. Conclusion

This paper adjudicated between two explanations for a counterintuitive positive employment response to monetary tightening in a county shift-share design. The evidence points to identification, not aggregation. The realized-rate DiD puzzle is robust to base year, outcome, and specification, so it is not a fragile artifact of modeling choices. National VARs reproduce the textbook contractionary response on a clean pre-2008 sample and invert over 2002-2019 only because the zero lower bound strips the funds rate of policy content. Most directly, holding the shift-share design fixed and replacing the endogenous funds-rate change with an identified high-frequency surprise flips the exposure interaction from significantly positive to negative at every horizon. The most plausible reading is that the positive sign is an endogeneity artifact and the underlying effect is contractionary.

These conclusions come with real limits. The surprise-based estimates are imprecise: seventy-two quarters of monetary surprises provide limited identifying variation, so the negative interaction is directional rather than statistically significant, and an instrumental-variables projection is infeasible because the orthogonalized surprise does not move the realized quarterly rate. The cross-sectional exposure gradient is confounded with county size and does not survive once size is held fixed. A deeper alternative I cannot fully rule out is the central-bank information effect [Nakamura and Steinsson 2018; Jarociński and Karadi 2020]: if surprises blend pure policy and information shocks, part of the interaction may reflect news about the economy rather than endogeneity, and decomposing the two is the priority extension. Other natural steps include a Wu-Xia shadow rate [Wu and Xia 2016] to recover policy content through the zero lower bound, a longer surprise sample, and Driscoll-Kraay or wild-cluster inference to sharpen the panel projection. The methodological message survives these caveats: shift-share designs built on the realized policy rate can mislead precisely where the policy rate is most endogenous, and an identified shock is the remedy.

## References

Bartik, Timothy J. 1991. *Who Benefits from State and Local Economic Development Policies?* Kalamazoo, MI: W.E. Upjohn Institute for Employment Research.

Bauer, Michael D., and Eric T. Swanson. 2023. "A Reassessment of Monetary Policy Surprises and High-Frequency Identification." *NBER Macroeconomics Annual* 37: 87-155.

Borusyak, Kirill, Peter Hull, and Xavier Jaravel. 2022. "Quasi-Experimental Shift-Share Research Designs." *Review of Economic Studies* 89(1): 181-213.

Carlino, Gerald, and Robert DeFina. 1998. "The Differential Regional Effects of Monetary Policy." *Review of Economics and Statistics* 80(4): 572-587.

Christiano, Lawrence J., Martin Eichenbaum, and Charles L. Evans. 1999. "Monetary Policy Shocks: What Have We Learned and to What End?" In *Handbook of Macroeconomics*, vol. 1A, edited by John B. Taylor and Michael Woodford, 65-148. Amsterdam: Elsevier.

Coibion, Olivier. 2012. "Are the Effects of Monetary Policy Shocks Big or Small?" *American Economic Journal: Macroeconomics* 4(2): 1-32.

Gertler, Mark, and Peter Karadi. 2015. "Monetary Policy Surprises, Credit Costs, and Economic Activity." *American Economic Journal: Macroeconomics* 7(1): 44-76.

Goldsmith-Pinkham, Paul, Isaac Sorkin, and Henry Swift. 2020. "Bartik Instruments: What, When, Why, and How." *American Economic Review* 110(8): 2586-2624.

Gürkaynak, Refet S., Brian Sack, and Eric T. Swanson. 2005. "Do Actions Speak Louder Than Words? The Response of Asset Prices to Monetary Policy Actions and Statements." *International Journal of Central Banking* 1(1): 55-93.

Jarociński, Marek, and Peter Karadi. 2020. "Deconstructing Monetary Policy Surprises: The Role of Information Shocks." *American Economic Journal: Macroeconomics* 12(2): 1-43.

Jordà, Òscar. 2005. "Estimation and Inference of Impulse Responses by Local Projections." *American Economic Review* 95(1): 161-182.

Nakamura, Emi, and Jón Steinsson. 2018. "High-Frequency Identification of Monetary Non-Neutrality: The Information Effect." *Quarterly Journal of Economics* 133(3): 1283-1330.

Plagborg-Møller, Mikkel, and Christian K. Wolf. 2021. "Local Projections and VARs Estimate the Same Impulse Responses." *Econometrica* 89(2): 955-980.

Romer, Christina D., and David H. Romer. 2004. "A New Measure of Monetary Shocks: Derivation and Implications." *American Economic Review* 94(4): 1055-1084.

Stock, James H., and Mark W. Watson. 2018. "Identification and Estimation of Dynamic Causal Effects in Macroeconomics Using External Instruments." *The Economic Journal* 128(610): 917-948.

Wu, Jing Cynthia, and Fan Dora Xia. 2016. "Measuring the Macroeconomic Impact of Monetary Policy at the Zero Lower Bound." *Journal of Money, Credit and Banking* 48(2-3): 253-291.

---

## Tables

**Table 1. Summary statistics, national monthly series, 2002-2019**

| Series | Mean | Std. dev. | Min | Max | Skew. | Kurt. |
|---|---|---|---|---|---|---|
| Fed funds rate (level, %) | 1.420 | 1.581 | 0.07 | 5.26 | 1.226 | 0.424 |
| Δ Fed funds rate | −0.001 | 0.141 | −0.96 | 0.25 | −3.001 | 15.883 |
| Employment growth (Δlog × 100) | 0.068 | 0.158 | −0.62 | 0.40 | −1.998 | 5.194 |
| Inflation (Δlog CPI × 100) | 0.175 | 0.295 | −1.786 | 1.367 | −1.430 | 10.310 |

*Note.* Monthly series from FRED. The funds-rate change is near-degenerate over the sample (excess kurtosis 15.9) because it is pinned near zero throughout the 2008-2015 zero-lower-bound episode.

**Table 2. Effect of monetary policy on county employment**

| | (1) Contemporaneous | (2) Distributed lag |
|---|---|---|
| ΔFFR_t × Exposure | 0.0202*** (0.0045) | −0.0054 (0.0072) |
| ΔFFR_{t−1} × Exposure | | 0.0067 (0.0054) |
| ΔFFR_{t−2} × Exposure | | 0.0121 (0.0090) |
| ΔFFR_{t−3} × Exposure | | 0.0247*** (0.0065) |
| ΔFFR_{t−4} × Exposure | | 0.0039 (0.0139) |
| Cumulative effect | | 0.042 (0.011) |
| N | 155,757 | 132,674 |
| County FE / Quarter FE | Yes / Yes | Yes / Yes |
| R² | 0.9927 | 0.9930 |

*Note.* Standard errors clustered by county in parentheses. Exposure = 2002 CBP construction + manufacturing employment share. Cumulative effect = sum of contemporaneous and four lagged interactions. * p < 0.10, ** p < 0.05, *** p < 0.01.

**Table 3. Robustness — alternative base years and outcome**

| | (1) Main | (2) CBP 2003 | (3) CBP 2013 | (4) CBP 2014 | (5) Growth rate |
|---|---|---|---|---|---|
| ΔFFR_t × Exposure (CBP 2002) | 0.0202*** (0.0045) | | | | 0.0073*** (0.0012) |
| ΔFFR_t × Exposure (CBP 2003) | | 0.0227*** (0.0050) | | | |
| ΔFFR_t × Exposure (CBP 2013) | | | 0.0189*** (0.0043) | | |
| ΔFFR_t × Exposure (CBP 2014) | | | | 0.0188*** (0.0042) | |
| N | 155,757 | 152,895 | 151,684 | 151,738 | 155,757 |
| County FE / Quarter FE | Yes / Yes | Yes / Yes | Yes / Yes | Yes / Yes | Yes / Yes |

*Note.* Standard errors clustered by county in parentheses. Column 5 outcome = quarter-on-quarter log employment change. * p < 0.10, ** p < 0.05, *** p < 0.01.

**Table 4. Pre-trends / placebo test (leads specification)**

| | ln(Employment) |
|---|---|
| ΔFFR_t × Exposure | 0.0528*** (0.0095) |
| ΔFFR_{t+1} × Exposure | 0.0132 (0.0108) |
| ΔFFR_{t+2} × Exposure | −0.0070 (0.0072) |
| ΔFFR_{t+3} × Exposure | 0.0153*** (0.0057) |
| ΔFFR_{t+4} × Exposure | −0.0257*** (0.0096) |
| N | 132,674 |
| County FE / Quarter FE | Yes / Yes |

*Note.* Standard errors clustered by county in parentheses. Significant forward leads are inconsistent with anticipation and consistent with the Federal Reserve responding to employment conditions in rate-sensitive sectors. * p < 0.10, ** p < 0.05, *** p < 0.01.

**Table 5. Full-panel exposure interaction θ_h: endogenous rate vs. identified surprise**

| Horizon h (quarters) | 0 | 1 | 2 | 4 | 6 | 8 |
|---|---|---|---|---|---|---|
| ΔFFR × exposure (endogenous) | 0.20** | 0.45*** | 0.73*** | 1.07*** | 1.25*** | 1.16*** |
| (s.e.) | (0.08) | (0.10) | (0.14) | (0.21) | (0.26) | (0.32) |
| Surprise × exposure (identified) | −0.39 | −0.73 | −1.17 | −1.62 | −1.92 | −2.01 |
| (s.e.) | (0.50) | (0.71) | (0.99) | (1.85) | (2.63) | (2.96) |

*Note.* Outcome: 100 × (ℓ_{c,t+h} − ℓ_{c,t−1}). County and time fixed effects; standard errors clustered by quarter; exposure standardized. The endogenous-rate row reproduces the puzzle; swapping in the identified surprise — changing nothing else — flips the interaction negative at every horizon. * p < 0.10, ** p < 0.05, *** p < 0.01.

---

## Figures (supplied as separate files)

**Figure 1.** County construction-and-manufacturing employment share, 2002 (exposure measure). *File: Figure1_exposure_map.pdf*

**Figure 2.** Cumulative employment response to a contractionary monetary shock. Left: pre-ZLB benchmark (1976-2008), the textbook negative response. Right: 2002-2019, where the zero lower bound inverts the sign. Shaded bands are 95% bootstrap intervals. *File: Figure2_var_inversion.png*

**Figure 3.** The sign reversal. Holding the shift-share design fixed and swapping only the source of policy variation flips the exposure interaction from significantly positive (endogenous ΔFFR) to negative (identified surprise). Bands are 95%, quarter-clustered. *File: Figure3_sign_reversal.png*

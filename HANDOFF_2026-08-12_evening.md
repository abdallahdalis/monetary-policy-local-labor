# Handoff — paste this into a new chat

*Session of August 12, 2026, evening. **Supersedes `HANDOFF_2026-08-12.md` entirely.** That file listed five open items; all five are closed. Read this one.*

---

## Context

I'm Abdallah Dalis. Read `/Users/abdallahdalis/Documents/CLAUDE.md` and `MEMORY.md` first. This continues the SSRN paper (abstract ID 7000419), working folder `projects/monetary-policy-local-labor/`.

**The manuscript is assembled and compiles.** `Dalis_Abdallah_SpuriousPrecision.tex` → 21 pages, no undefined references, no overfull boxes. Committed and pushed as `5bf3b64`. Working tree clean.

**Read before doing anything:** this file, then `sections/` (four drafted sections, all banners cleared). `causal-did/EXPOSURE_DEFECT_2026-08-12.md` is still the diagnosis of record. `causal-did/PIPELINE_RECONCILIATION.md` is accurate on the Stata-versus-R question but its numbers are pre-rebuild — read it for reasoning, not values.

---

## The numbers, as they now stand

**Estimation sample is 3,127 counties, not 3,126.** Verify against tagged files, never untagged ones.

| quantity | value | source |
|---|---|---|
| Headline contemporaneous interaction | **0.0332** (SE 0.0066), t = 5.06 | `all_coefficients_R_zlb-full_pos-off.csv`, spec `main_spec` |
| Same, excluded window | 0.0318 (SE 0.0064) | `all_coefficients_R_zlb-excl_pos-off.csv` |
| **NOT** the headline | `placebo` is 0.0252 (SE 0.0060) | same file |
| Pre-trends, clustered | leads **1, 2, 3** reject, both windows | `tab_pretrends_both_windows.csv` |
| Pre-trends, reported count | **two of four — leads 2 and 3** | `randomization_inference_zlb-*.csv` |
| RI ratios, full window | 1.11 / **1.62 / 1.41 / 1.18** / 0.76 | same |
| RI ratios, excluded | 1.14 / 1.62 / 1.41 / 1.17 / 0.76 | same |
| SE ratio, full / excluded | **5.3–10.0** / 5.8–11.7 | `tab_signflip_zlb-*.csv` |
| Raw / identified significant | **8 of 13** / 0 of 13, both windows | same |
| Smallest p(difference) | 0.071 at h = 2 | computed |
| Growth-outcome robustness | 0.0116 (SE 0.0022) | `rob_growth` |
| Observations, joined | 224,952 full / 174,968 excluded | run logs |
| Observations, lead spec | 212,468 / 162,484 | run logs |
| Exposure distribution | n 3,127 · mean 0.221 · median 0.206 · sd 0.139 · p10 0.043 · p90 0.417 · ratio **9.77** · max 0.764 | `tab_exposure_descriptives.csv` |
| Zero-exposure counties | **143** (4.6%) | computed |

### Lead one is deliberately unsettled

Randomization inference now runs **2,000 draws**, not 200. At 200 the Monte Carlo standard error of a permutation *p* near 0.05 is about 0.015 — wider than the gap between the leads the paper counts and the ones it does not.

At 2,000 draws lead one is **p = 0.054 with an MCSE of 0.005**, still straddling the threshold. Separating it would take roughly 18,000 permutations. **It is reported as unsettled, which makes "two of four" an explicit lower bound rather than a measurement.** That is the right posture for a paper about overstated precision. Do not round it away.

The RI files now carry `n_reps` and `mcse_p` columns, and the script names any term whose verdict sits inside Monte Carlo noise.

---

## What closed today

1. **`SS999` re-run — done, and it had a second defect.** The filter dropping 50 statewide CBP residual records was also deleting the **District of Columbia**. In the 2002 CBP county file DC has no county-detail record: `11999` is its whole 418,755-employee jurisdiction, and it is the one state of fifty-one that writes a 999 record and nothing else. Recoded to `11001`. DC now joins the estimation sample for the first time in the program. Its exposure is 0.0201, lowest in the country — and the earlier claim that this was "roughly half its true value" was itself wrong; DC never had a second record to be dragged down by.
2. **Figures 5 and 6 — rebuilt.** No longer stale.
3. **Exposure map — done.** See the environment pin below.
4. **`adao2019` — verified.** And the real gap was bigger: the paper had six `\cite` keys and **no bibliography file at all**. `references.bib` created.
5. **Assembly — done.** Main `.tex`, eight float blocks, both-window tables, compile, proofread.

---

## Corrections made — do not reintroduce

1. **DC is not a residual record.** A blanket `grepl("999$")` filter deletes it. The rebuild script now derives the set of states with no non-999 area and refuses to run if it is not exactly `{11}`.
2. **`bauer2023` was pointing at the wrong paper.** The plan was to carry it from the Part 3 bibliography, where it is the AER *"An Alternative Explanation for the 'Fed Information Effect'"* (113(3), 664–700). The shock series this paper uses is the orthogonalized surprise published with **"A Reassessment of Monetary Policy Surprises and High-Frequency Identification," NBER Macroeconomics Annual 37, 87–155**. A verified entry is not the same as the right entry.
3. **`adao2019` is QJE 134(4), 2019, 1949–2010**, doi `10.1093/qje/qjz025`.
4. **The +0.54 exposure/county-size correlation did not reproduce.** It is **+0.16** and hump-shaped: mean exposure 0.08 in the smallest size decile, 0.29 in the middle, 0.18 in the largest. The monotone version was the NAICS over-count, which grows with the industry detail a county reports, which grows with county size. **The defect manufactured the confound the limitation was warning about.** The volatility gradient (10.6 → 2.5) survives and is not exposure-dependent. The fifth limitation is rewritten, not restated.
5. **The "32-row filter" influence item is dead.** `is.finite(ln_emp)` is a no-op on this panel — it stores `ln_emp` as 0 where employment is 0, so the check passes every row. 4.2–9.6 is a contaminated estimate, not a defensible referee variant. Methods states the screen is on levels and why.
6. **"11 of 13" and "6.3–12.0" never were this paper's numbers.** They were verified on August 11 against `School/Classes/DePaul/ECO_508_Time_Series/FinalProject/tables/tab_signflip.csv`, a June 5 class-project copy with the same filename. It reproduces 6.46 / 11.97 / 6.30 at h = 0, 3, 12 exactly, which is why the check read as passing. The paper's file gives 5.96 / 9.97 / 5.30 and 8 of 13.
7. **"The two windows agree to three decimal places" is false.** They agree to within 0.0015. This was wrong in §5.4 *and* hard-coded in the pre-trends caption generator; both now compute the gap.
8. **`plainsummary` does not exist.** The style file defines `summarybox`.
9. **`p_ri = 0` means 0 of 2,000 draws.** Report as p < 0.0005. Never print "p = 0.000".
10. **The influence check concedes what it found.** Raw significance erodes 8 → 7 → 5 → 4 of 13 as the smallest three deciles drop; SE ratio floor 4.5; 0 of 13 identified significant in every arm.

---

## Environment pins — both are required

```r
remotes::install_version("usmap",     version = "0.6.1")
remotes::install_version("usmapdata", version = "0.2.0")
```

**Downgrading `usmap` alone does nothing.** The boundaries live in the `usmapdata` companion package. With both pinned, Connecticut's eight legacy counties are present and unmatched falls 60 → 7. The residual seven are genuine post-2002 FIPS changes: five Alaska census areas (02201, 02232, 02261, 02270, 02280), Shannon County SD (46113 → 46102), and Bedford city VA (51515). The subtitle says so on the face of the figure.

---

## Float mapping — check before editing any block

| manuscript | file |
|---|---|
| Figure 1 | `causal-did/output/figures/exposure_map_2002_rebuilt.pdf` |
| Figure 2 | `figures/fig2_shock_comparison.png` |
| Figure 3 | `causal-did/output/figures/fig3_pretrends.png` |
| Figure 4 | `causal-did/output/figures/fig_randomization_inference_zlb-full.png` |
| **Figure 5** | **`figures/fig4_raw_vs_identified.png`** |
| **Figure 6** | **`figures/fig5_precision_collapse.png`** |
| Table 1 (`tab:main`) | `tables/tab2_main_both_windows.tex` |
| Table 2 (`tab:placebo`) | `tables/tab4_placebo_both_windows.tex` |

The filenames do not match the figure numbers and never will — they are named for what the writing script called them. Swapping Figures 5 and 6 exchanges the point-estimate panel with the standard-error panel, and both are plausible under either caption, so the error would not look like an error.

The tables render as **Table 1 and Table 2**, not 2 and 4. The 2-and-4 names refer to the `causal-did` output filenames. Everything is `\ref`-driven and internally consistent. Do not hard-code the numbering.

---

## Open

1. **The TEC2026 decision — DECIDED: do nothing until September 4.** The submitted abstract carries 0.022, "11 of 13," "6.3 to 12.0×," and "every horizon turns negative." Every conclusion survived; only magnitudes moved. Notification is **Friday September 4**; draft poster around **September 30**. The poster carries corrected numbers. `ABSTRACT_2026-08-11.md` has a correction notice appended and was deliberately **not** rewritten, because it records what the committee received.
2. **The orphan map.** `causal-did/output/figures/exposure_map_2002.pdf` — unreproducible, on the defective measure, superseded. Still on disk; retiring it needs Abdallah's word.
3. **`report.pdf` recompile.** One figure changed. Cosmetic; that document is not the paper.
4. **`TASKS.md` is 58.7 KB** against the 40 KB guard in CLAUDE.md. Needs a real pass, not a trim.
5. **The resume SSRN bullet and the NABE writing sample** still assert the sign flip retracted on August 11, across roughly 30 application folders including three Federal Reserve banks and the IMF.

### Parked, deliberately

- **AKM exposure-robust inference** remains untested and must stay *stated* as untested in Limitations. Do not quietly drop it.
- **Alternative base years 2003 / 2013 / 2014** are still built by the defective `build_cbp_exposure` program. Only 2002 was rebuilt. The base-year robustness claim is withdrawn from §5.3 — rebuild all four years or leave it withdrawn.
- `PipelineDiagnostic.R`, `PrecisionMechanism.R`, `LPReconciliation.R` remain on the defective measure by decision. They answered the Stata-versus-R question, which is closed.

---

## Working note — the shape of every defect in this project

Four rules now live in `CLAUDE.md`, and they are one rule at four levels of address:

- **Claim provenance** — which *file* does this number come from?
- **Row provenance** — which *specification inside* the file? (The standard error is no longer the discriminator; post-rebuild the coefficient is. A heuristic for telling two numbers apart can itself go stale.)
- **Path provenance** — which *directory*? Three files in the workspace are named `tab_signflip.csv`. And which *dependency*? The package that was pinned was not the package that held the data.

**The tell is the same every time: the check passed.** A wrong-copy verification does not error. A wrong-version pin does not warn. A caption that hard-codes a number keeps printing it after the number changes. `drop if exp_sens > 1` silently deleted 282 counties. `cairo_pdf` failed as a warning while `ggsave` wrote nothing and the script printed "wrote:".

**Silent success is the failure mode here, not silent failure.** The standing remedy is to assert the artifact has the shape you expect rather than trust the call that produced it. Every script touched on August 12 now does that.

# Handoff — paste this into a new chat

*Session of August 11, 2026, evening. Supersedes `HANDOFF_2026-08-11.md`, which covers the earlier session the same day. Read both if you want the full arc; this one is sufficient to continue.*

---

## Context for a new session

I'm Abdallah Dalis. Read `/Users/abdallahdalis/Documents/CLAUDE.md` and `MEMORY.md` first. This continues work on the SSRN paper (abstract ID 7000419), working folder `projects/monetary-policy-local-labor/`.

**Read these before doing anything:**

- `HANDOFF_2026-08-11_evening.md` (this file)
- `FIGURE_PLAN_2026-08-11.md`
- `causal-did/PIPELINE_RECONCILIATION.md`
- `sections/` (four drafted manuscript sections)

### Where the paper stands

**Title stands:** *Spurious Precision: Why Shift-Share Designs Overstate Monetary Policy Effects on Local Employment.* It rests on the **local projections**, not the DiD.

**Two independent diagnostics, failing for different reasons.**

1. **Local projections** — precision borrowed from the business cycle. This is the title claim. Identified standard errors run **6.3 to 12.0×** wider than raw in the full window, **6.1 to 12.9×** excluding 2009–2012.
2. **Shift-share DiD** — parallel trends fails. Its standard errors are fine; five separate tests confirmed it.

Do not conflate them. The precision claim is not about the DiD.

**TEC2026 application submitted August 11**, fifteen days early. Next date: **notification by Friday September 4**, then **draft poster / preliminary results ~September 30** (their form says "Monday, September 31," which is not a date; assume Sept 30, do not email to ask).

### The manuscript

**"Spurious Precision" is a merge of two existing papers.** The SSRN posting is `mennis-submission/` (DiD only). `report.tex` is a separate ECO 508 paper carrying the local projections. The merged manuscript is being written now and is **not** gated to any deadline.

Drafted, in `sections/`:

| file | status |
|---|---|
| `results_discussion.tex` | drafted figure by figure, every number carries a source comment |
| `methods.tex` | drafted |
| `introduction.tex` | drafted, includes the required Plain-Language Summary box |
| `conclusion.tex` | drafted |

**Not written:** the main `.tex` that assembles them, all figure and table float blocks (every `\ref` currently points at nothing), both-window Tables 2 and 4, and the `.bib`.

### Numbers you must not get wrong

| quantity | value | source |
|---|---|---|
| Headline contemporaneous interaction | **0.022** (`main_spec`, SE 0.0043) | `all_coefficients_R_zlb-full_pos-off.csv` |
| **NOT** the headline | 0.024 is `placebo` (SE 0.0037), the pre-trends regression | same file |
| Pre-trends, analytic | leads **1, 2, 4** reject, both windows | `tab_pretrends_both_windows.csv` |
| Pre-trends, reported count | **two of four** (only 2 and 4 also reject under randomization inference; lead 1 is p=0.055) | `randomization_inference_zlb-full.csv` |
| SE ratio, full window | 6.3 to 12.0 | `tab_signflip_zlb-full.csv` |
| SE ratio, excluded window | 6.1 to 12.9 | `tab_signflip_zlb-excl.csv` |
| Counties | 3,228 raw QCEW · 2,889 CBP · **2,887 estimation** | `Dalis_Abdallah_ExposureDescriptives.R` |
| Estimation n | 196,148 full · 150,004 excl | model output |
| Abstract length | **232 words** | recounted; 218 and 212 were both wrong |

### Corrections made this session — do not reintroduce

1. **The wrong-row error.** The headline had drifted to 0.024 across four files. That is the `placebo` spec, not `main_spec`. **The standard error is the tell: 0.0043 is the headline, 0.0036 is the pre-trends regression.** It went unnoticed because `main_spec` full-window (0.0223) and `placebo` excl-window (0.0222) round identically. A new rule was added to `CLAUDE.md` ("Row provenance").
2. **`EXCLUDE_ZLB` was a no-op.** `Dalis_Abdallah_RandomizationInference.R` never read it; the exclusion was hardcoded. The documented command would have returned the excluded-window result under a full-window label. Patched; outputs now tagged.
3. **A trap in that script's console output** told the reader that ratios near 1 mean "the title should change." That predates the §4g retraction and would have prompted a sixth retitle. It now prints the retraction inline.
4. **A geography sentence in §5.1 was invented.** It claimed exposure concentrates in the Midwest and interior South and thins in coastal metros. Four of the ten highest-exposure states are New England. Rewritten from `tab_exposure_by_state.csv`.
5. **"Every horizon turns negative" was falsified** in the excluded window: 12 of 13, with h=0 at +0.002 (SE 0.493). The submitted TEC abstract is defensible since the full window is the headline; the manuscript now says "no horizon rejects zero, in either window."
6. **Pre-trends parameterization settled.** Two objects existed and disagreed (`placebo` gives leads 1,2,4; `event_study` gives 3,4). The paper uses **`placebo`**, because the abstract's count and the randomization inference were computed on it. The event study is out of the pre-trends claim.

### The fragility you need to decide how to report

**32 rows out of 207,672 move the headline SE ratio by about 30 percent.** Changing the panel filter from `month3_emplvl > 0` to `is.finite(ln_emp)` takes the range from 6.3–12.0 to 4.2–9.6. The published filter is the defensible one, so **no published number is wrong**, but any referee rerunning this with a slightly different employment screen gets a visibly different ratio.

This is the third time the project has demonstrated its own thesis inside its own pipeline. Recommendation: report it deliberately as a strength rather than let it be discovered.

Separately, exposure runs from 0.000 to 0.9997. A county with essentially all employment in construction and manufacturing is more likely CBP suppression than a real economy. Unexamined.

### New evidence built this session

**Figure 2 (`figures/fig2_shock_comparison.png`)** — the endogeneity, measured. Raw ΔFFR correlates with national employment growth at **+0.470** (R² 0.22); the identified surprise at **−0.119** (R² 0.014); the two measures correlate at **−0.010**. The leverage objection was tested and *reversed*: excluding 2009–2012 the correlation **rises to +0.662**, and the rank correlation is +0.502. At the ZLB the funds rate was pinned while employment moved, so those quarters attenuate the reaction function. **The full-window headline is therefore the conservative choice.** Caveat to carry: `MPS_ORTH` is orthogonalized, so the −0.010 is partly by construction.

**Figure 3 (`causal-did/output/figures/fig3_pretrends.png`)** — pre-period leads, both windows in one panel, significance computed at run time rather than typed.

**Exposure descriptives** — mean 0.448, median 0.456, sd 0.252, p10 0.078, p90 0.787, ratio 10:1. The median cross-checks against the independent median-split value 0.455516.

### Open, in priority order

1. **Rebuild Figures 5 and 6.** `Dalis_Abdallah_SpuriousPrecision_Figures.R` still reads the superseded `tables/tab_signflip.csv` (single window, carries a small seam contamination). Rebuild from `tab_signflip_zlb-full.csv`. **Open design question:** thirteen horizons × two estimators × two windows is four bands in one frame and will be unreadable. My recommendation was to keep Figures 5 and 6 full-window and add a compact separate robustness figure for the excluded window. **Not yet decided.**
2. **Influence check** on the 32-row sensitivity.
3. **Exposure outliers** at 0.9997.
4. **Verify `adao2019`** (Adão, Kolesár & Morales, "Shift-Share Designs: Theory and Inference"). `PIPELINE_RECONCILIATION.md` §4b says verify before citing and it has not been done. It is cited three times.
5. **Assembly:** main `.tex`, float blocks, both-window Tables 2 and 4, `.bib`, compile, proofread.
6. **AKM remains parked**, by pre-commitment. It must be *stated* as untested in Limitations, which `results_discussion.tex` does. Do not quietly drop it.

### Housekeeping

`TASKS.md` is over 43 KB against a 40 KB guard and `MEMORY.md` is 29 KB. A triage pass is owed. `PROFILE.md` was not regenerated despite a `CLAUDE.md` change, because there is an open question about retiring it.

### Working note

Nine defects surfaced this session, and most of the pre-existing ones lived in records written at the end of long sessions. The two that mattered were caught the same way: **by insisting a rewrite reproduce a published table before trusting it.** The both-windows work took four runs and turned up three separate problems, none visible from reading the code.

Prefer running the test to arguing the mechanism. Check which file *and which row* a claim comes from. A self-check that fails for a known reason and says so is more useful than one quietly loosened.

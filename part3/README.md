# Monetary Policy, Local Labor Markets, and Racial Incidence (Part 3)

Independent research project. Third installment of the program "Monetary policy,
local labor markets, and who bears the cost" (Parts 1-2 were the ECO 510 and
ECO 508 papers). Self-contained: all inputs are in `data/`, nothing here depends
on the coursework folders.

## Question
Once monetary tightening is identified cleanly (Bauer-Swanson surprise) and shown
to be contractionary (Part 2), is the employment cost larger in higher-minority
counties? This is distributional *incidence*, not a claim the Fed targets by race.

## Method
Jorda local projections on the Part 2 county panel (2,884 counties, 2002Q1-2019Q4,
72 quarters). Identified surprise interacted with PREDETERMINED 2000 Census racial
shares. County + time fixed effects; SE clustered by quarter; horizons h = 0..12.
Mirrors Part 2's `lp_interaction` exactly.

## Findings so far (June 15, 2026)
1. **Baseline (surprise x Black share):** negative at most horizons, deepening to
   ~ -1.06 by h12, but statistically insignificant (|t| < 0.9).
2. **Control ladder:** the Black gradient survives netting out county size
   (log-pop), income (2000 median household income), and industry exposure, the
   confound that killed the Part 2 industry gradient. Income does NOT absorb it,
   it sharpens it at the long horizons (h12: -1.06 alone -> -1.19 net of pop+income),
   because poorer and higher-Black counties partly offset. Robust in sign/magnitude,
   still imprecise (peak |t| ~ 1.0).
3. **Within-CBSA (the decomposition that matters):** on the same metro counties,
   switching national-time FE -> CBSA x quarter FE flips the sign positive. The
   negative gradient is a BETWEEN-metro pattern; within metros, higher-Black
   counties do not contract more. All estimates remain imprecise.
   => Reframe the paper around between- vs within-metro incidence.

Hispanic share is a null throughout.

## Files
- `Dalis_Abdallah_Part3_Code.R` — full pipeline (Sections 1-6). RUN ON THE MAC to
  verify; the drafting sandbox has no R, results were confirmed in mirrored Python.
- `data/` — QCEW panel, CBP 2002 exposure, Bauer-Swanson surprises, FEDFUNDS,
  `county_race_2000.csv` (predetermined shares), `county_cbsa_2020.csv` (crosswalk).
- `figures/`, `tables/` — outputs.

4. **Robustness (draft-complete):** entering Black and Hispanic JOINTLY leaves the
   Black gradient essentially unchanged (it is not Hispanic in disguise); Hispanic
   is null. Driscoll-Kraay SE (serial + cross-sectional dependence) do not weaken
   it; if anything the long-horizon black coef edges closer to significance
   (h11 |t| ~ 1.5 under DK). The precision ceiling is the data (72 quarters), not
   the SE choice or omitted controls.

## Next
- Bauer-Swanson information-effect contamination (Nakamura-Steinsson) remains the
  deepest unresolved threat, carried over from Part 2 (discuss, do not "fix").
- Begin the LaTeX write-up reframed around between- vs within-metro incidence.
  Analysis is complete; four figures + result tables are in figures/ and tables/.

## Data sources (all keyless except income)
- Race/population: Census 2000-2010 intercensal county file (ESTIMATESBASE2000).
- CBSA crosswalk: Census 2020 delineation, list1.
- Income: Census 2000 SF3 P053001 via API endpoint `data/2000/dec/sf3` (needs key).

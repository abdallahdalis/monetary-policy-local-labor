# Exposure Measure Defect — CBP construction and manufacturing share

*Abdallah Dalis · August 12, 2026 · `causal-did/`*

**Status: CONFIRMED AND REBUILT. Downstream not yet re-run.** The diagnosis below
was inferred from the code on August 12 and then **measured** the same day, after
the 2002 CBP county file was downloaded and the rebuild executed. The corrected
measure is at `data/cbp_exposure_2002_rebuilt.dta`. The defective
`data/cbp_exposure_2002.dta` is unchanged and every downstream script still reads
it. See §2b for the measured result and §4 for two defects found in the rebuild
script itself.

---

## Plain-Language Summary

**What was asked.** The paper's key variable is the share of a county's 2002
employment in construction and manufacturing. A routine outlier check asked why
some counties showed shares near 100 percent.

**What was found.** The measure is built wrong. The code that adds up
construction and manufacturing employment counts the same workers several times,
because it accepts every level of the industry classification at once — the
sector, its sub-industries, and their sub-industries. The bottom of the fraction
counts each worker once. The top counts them repeatedly. Every county's share is
inflated, and by different amounts.

**What it means.** The descriptive section of the paper, the exposure map, and
the estimated coefficient are all computed on a variable that does not measure
what the paper says it measures. The paper's headline claim, which compares two
standard errors on a fixed sample, is likely to survive; the description of the
variable is not.

**The honest limitation.** The corrected measure now exists and the error is
measured: the typical county's share was roughly **twice** what it should have
been, and the exaggeration ran from no error at all up to nearly thirteen times.
What has not yet happened is the re-estimation. Every result in the paper is
still computed on the old variable, so nothing here says yet whether the paper's
conclusion changes.

---

## 1. The defect

`01_clean_data.do`, lines 206–228:

```stata
gen naics_clean = subinstr(naics, "-", "", .)
replace naics_clean = subinstr(naics_clean, "/", "", .)
gen naics2   = substr(naics_clean, 1, 2)          // <- takes a PREFIX
gen is_total = (naics_clean == "")

keep if is_total | naics2=="23" | inlist(naics2,"31","32","33")
...
collapse (sum) emp, by(area_fips ind)             // <- sums every level
gen exp_sens_`yr' = (empconstr + empmanuf) / emptotal
drop if exp_sens_`yr' > 1                         // <- the confession
```

CBP county files carry the full NAICS hierarchy. After the dash strip:

| raw code | cleaned | first two chars | kept? |
|---|---|---|---|
| `------` | `` | — | yes, as total |
| `23----` | `23` | 23 | yes — correct |
| `236---` | `236` | 23 | yes — **already inside `23`** |
| `2361--` | `2361` | 23 | yes — **already inside `236`** |
| `236115` | `236115` | 23 | yes — **already inside `2361`** |

`collapse (sum)` then adds all five. Construction and manufacturing employment
enters the numerator once per hierarchy level present. The denominator uses only
the `------` row and is correct.

**Line 228 is the tell.** A correctly constructed share cannot exceed one. That
line exists because the numerator overflows, and it deletes the worst-affected
counties — a non-random screen on how much industry detail a county reports.

## 2. The evidence

| observation | value | expected |
|---|---|---|
| median county share | **0.456** | ~0.19 nationally in 2002 |
| mean | 0.448 | — |
| San Bernardino County, CA (`06071`) | **0.9997** | large, diversified |
| Adams County, CO (`08001`) | 0.9974 | Denver suburb |
| Erie County, PA (`42049`) | 0.9901 | diversified |
| counties above 0.99 | 11 | — |
| counties above 0.90 | 102 | — |
| CBP counties retained | 2,889 | QCEW has 3,228 |

A share of 0.9997 says essentially every worker in San Bernardino County builds
things or makes things. The county's actual economy is logistics, health care,
retail and government.

## 2b. The measured result (August 12, rebuild executed)

`Cbp02co.txt`, 157 MB, downloaded from the Census URL in §4. Rebuild run from the
project root. Verified independently against the old file.

| quantity | value |
|---|---|
| median over-count factor | **2.11×** |
| interquartile range of the factor | 1.51× to 2.86× |
| maximum | **12.8×** |
| correlation, old vs rebuilt | 0.734 |
| **rank** correlation | **0.763** |
| counties in rebuilt file | **3,171** (old: 2,889) |
| counties returned by removing `drop if >1` | **282** |
| rebuilt median / mean share | 0.2043 / 0.2179 |
| rebuilt maximum share | 0.7641 |
| rebuilt shares above 1 | 0 |

| county | old | rebuilt |
|---|---|---|
| San Bernardino, CA | 0.9997 | **0.2154** |
| Adams, CO | 0.9974 | 0.2313 |
| Erie, PA | 0.9901 | 0.2785 |
| Kewaunee, WI | 0.9994 | 0.4410 |

**The diagnosis holds in every particular.** The rebuilt median of 0.2043 sits
just above the ~0.19 national anchor, exactly where a median county should. No
share exceeds 1, so the `drop if` line is not merely unnecessary — it never had a
legitimate case to handle.

**The factor varies from 1.0× to 12.8×.** That is the point. A constant factor
would wash out of a standardised regressor and change nothing. A varying one is
measurement error correlated with how much industry detail a county reports, and
that reporting depth tracks county size and industrial diversity.

**The rank correlation of 0.763 is the number that matters for re-estimation.**
The exposure ordering genuinely reshuffles. The shift-share coefficient, the
pre-trends leads, and the exposure map are all estimated on a different ranking
than the corrected data implies. They will move, and the direction is not
predictable from here.

## 3. What breaks, and what does not

**Likely survives.** The title claim is a comparison of two standard errors on a
fixed sample, changing only the shock measure. Both arms use the same exposure
variable, and the local projections standardise it. A mis-scaled regressor common
to both arms should not manufacture a 6-to-12 ratio between them. **This is an
argument, not a test.** It becomes a test when the rebuild is run.

**Does not survive, pending rebuild:**

- §5.1 in full: mean 0.448, median 0.456, sd 0.252, p10 0.078, p90 0.787, the
  "ten to one" spread, the state ranking, and DC at 0.082.
- Figure 1, the county exposure map.
- The 2,889 and 2,887 county counts in Methods. The rebuilt file carries
  **3,171** counties, so the estimation sample grows by roughly 282 counties and
  every reported $n$ changes with it.
- The shift-share coefficient 0.0223 and its standard error 0.0043.
- The pre-trends lead magnitudes.
- The +0.54 exposure-to-county-size correlation added to Limitations on
  August 12, and the 0.13 / 0.61 decile means beside it.

**Note the direction of the size correlation.** Large counties report deeper
industry detail, so they accumulate more hierarchy levels and a larger
over-count. The +0.54 correlation between exposure and log county size may be
partly or wholly an artifact of the defect rather than a feature of industrial
geography. Do not cite it until the rebuild settles it.

## 4. The fix

`causal-did/Dalis_Abdallah_RebuildExposure.R`. It selects sector-level rows only,
prints the file's actual code structure before filtering, and refuses to write
output if any share still exceeds one.

Source file, 157 MB unzipped, gitignored and never committed — GitHub rejects
blobs over 100 MB, so a commit would fail the push outright:

```
https://www2.census.gov/programs-surveys/cbp/datasets/2002/cbp02co.zip
```

Unzip to `causal-did/raw/CBP/`, then **run from the project root**, not from
`causal-did/`:

```
cd ~/Documents/projects/monetary-policy-local-labor
Rscript causal-did/Dalis_Abdallah_RebuildExposure.R
```

It writes `data/cbp_exposure_2002_rebuilt.dta` alongside the defective file and
does not overwrite it.

### 4a. Two defects in the rebuild script itself, found on first run

Recorded because the second one is this memo's own subject matter recurring
inside its own fix.

**(1) `print(df, n = 20)` on a data.frame.** `read.csv` returns a data.frame, and
`print.data.frame` has no `n` argument, so `n = 20` was forwarded to
`print.default` and partial-matched `na.print`. Hard stop at the first inspection
block. Fixed by wrapping the read in `as_tibble`.

**(2) `SECTOR_MANUF` included `"3133"`, and that was wrong.** The value was added
defensively, to catch a combined manufacturing sector encoded `"31-33"`. But this
vintage has no combined code — all manufacturing sits under `31----`, with no
`32----` or `33----` present at all. What `"3133"` actually matched is `3133//`,
**NAICS 4-digit Textile and Fabric Finishing Mills**, which is already inside
`313`, already inside `31`. It appeared in 524 counties, 46 with nonzero
employment, and was added on top of the sector total.

**That is the original defect, one level down, committed while fixing the
original defect.** The cause was identical: a code format was guessed rather than
inspected. Section 1 of the script exists to prevent exactly this, and the guess
was written before its output was read.

Fixed by matching on the **raw** code rather than the cleaned one, so stripping
separators can no longer conflate `31-33` with `3133`. Manufacturing rows kept
fell from 3,603 to 3,079. The effect on the estimates was small — the median
share is 0.2043 either way — but it was a genuine double count and the smallness
of its effect is not the point.

**The lesson, restated because twice in one day is a pattern and not an
accident:** a defensive clause guarding against a format you have not looked at
is not defensive. It is a second guess with more confidence attached.

## 5. Order of operations after the rebuild

1. Read the section 1 output. Confirm the hierarchy is what this memo claims. **If
   it is not, this memo is wrong and the rebuild must stop.**
2. Check the over-count factor. If it is near 1.0 and constant, the diagnosis is
   wrong and the original measure is fine.
3. Repoint `Dalis_Abdallah_ExposureDescriptives.R`, rerun, rewrite §5.1 from its
   output.
4. Repoint `Dalis_Abdallah_CausalDiD_Analysis.R`, rerun, update Table 2, the
   pre-trends, and the randomization inference.
5. Repoint the local-projection scripts, rerun both windows, rebuild Figures 5
   and 6. **The self-checks in those scripts compare against the OLD tables and
   will fail by construction.** Retire the old reference rather than loosen the
   tolerance.
6. Rebuild the exposure map.
7. Only then revisit whether the title claim held.

## 6. What this is an instance of

The same failure the pipeline reconciliation memo keeps recording: a format was
assumed rather than inspected, and the assumption was never tested because the
output looked plausible. `drop if exp_sens > 1` was the pipeline telling the
author the numerator was wrong, and it was read as a data-cleaning step.

The defect survived an ESC presentation, an SSRN posting, a conference abstract,
and roughly a dozen diagnostic scripts. None of them looked at the variable's
own distribution against an outside benchmark. The check that caught it was
asking what a share of 0.9997 would mean for a real county.

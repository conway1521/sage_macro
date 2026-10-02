# Audit 5: calibration (ownership, staleness, identification, acceptance)

## Summary

1. One calibration file on disk is stale and still read without warning: `calibration_country_IT_GA_I.txt` was committed 3.5 hours before the effort fix and carries chi0 = 0.0113 from a France G+A calibration that has since moved to 0.0011. The other 35 files post-date the fix and are consistent with their parents.
2. 13 of the 24 two-asset configurations have no file (all S configurations, all GSE/GSAE, IT GAE), and `country_config` returns the struct defaults for a missing file with no error (phi 14, sigma 0.40, kappa 10, chi0 0.05, illiquid premium 0). Two scripts read an inherited value (sigma, chi0) through that path with no existence check.
3. On two assets the fixed cost chi0 is not identified by the wealthy hand-to-mouth: the run logs show the moment moving by 0.001 when chi0 moves sevenfold. chi0 at its lower bound is a flat-Jacobian artefact, France's "four targets in band" is three moments resting on one patience parameter, and the value Germany and Italy borrow differs twelvefold between G and G+A.
4. The net-wealth moment is an uninterpolated grid median (steps of 3.6 to 5%, against a 5% band) and the S and E two-asset scripts take undamped quasi-Newton steps from a Jacobian differenced over a step about twenty times the band. Germany's two-asset G+S+A "not calibrated" is a period-two oscillation produced by this, not a failed target.
5. Acceptance has gaps: participation is checked on the scan, never on the solved economy (the E-on scan is 0.002 off the solve), a failed run leaves the old file in place beside the marker, and exit code 3 means both "time budget" and "preflight failed". No file currently on disk has a checked target outside its band.

Verified means read in the code or in a GitHub Actions log; "assumed" is marked where I rely on a script comment. Julia was not run.

## Table 1. Ownership by (assets, configuration), as the scripts implement it

Fixed by assumption in every row (neither fitted nor in any file): omega 0.30, R 1.02 (France's, all countries), rho 0.92, eta 0.10, psi 2, death 1/45, and on two assets the impatient type's effective patience 0.85.

| Assets | Config | Fitted (script) | Target each owns | Inherited, from | Untargeted, reported |
|---|---|---|---|---|---|
| 1 | G | phi; beta_spread, or beta_bar when the spread reaches 0 (`calibrate_country.jl`) | phi: effort of the employed (tol 0.005). spread/beta_bar: poor hand-to-mouth, KVW (tol 0.005) | none | participation, agency, hardship, median income |
| 1 | GA | as G | as G | none | as G |
| 1 | GS | phi, spread/beta_bar (up to 2 corrections for the cohesion gap), kappa | as G, plus kappa: overall participation (scan loss 0.005) | sigma_m from `calibration_country_<C>.txt` (GSA) | participation gap between cells |
| 1 | GSA | phi, spread/beta_bar, kappa, sigma_m | as G, plus (kappa, sigma): participation by education cell (scan root loss 0.035); multiplier gate 5 | none | four economies at GSA parameters |
| 1 | GE, GAE | as G, GA, solved over places | as G, GA (national) | none (E fits nothing) | place outcomes |
| 1 | GSE | as GS, place-aware scan | as GS | sigma_m from `calibration_country_<C>_GSAE.txt` | cell gap, place outcomes |
| 1 | GSAE | as GSA, place-aware scan | as GSA | none | place outcomes |
| 2 | G, GA (FR) | beta_bar, chi0, impatient_share, phi, joint damped Newton (`calibrate_two_asset.jl`) | beta_bar: median net wealth / median income (5% relative). chi0: wealthy htm (0.01). share: poor htm (0.005). phi: effort (0.005) | start only from the one-asset file of the same config | MPC, consumption drop, liquid/income, Gini |
| 2 | G, GA (DE, IT) | beta_bar, impatient_share, phi | net wealth, poor htm, effort | chi0 from `calibration_country_FR_<CFG>_I.txt` | wealthy htm |
| 2 | GS | 4 (or 3) G parameters re-fitted with the S-off Jacobian, kappa (`calibrate_two_asset_s.jl`) | G targets as above; kappa: overall participation | start and chi0 status from `_G_I.txt`; sigma_m from `_GSA_I.txt` | cell gap; wealthy htm if borrowed |
| 2 | GSA | 4 (or 3) G parameters, kappa, sigma_m | G targets; cell participation; gate | start and chi0 status from `_GA_I.txt` | wealthy htm if borrowed |
| 2 | GE, GAE | 4 (or 3) G parameters, quasi-Newton on E-on residuals with the E-off Jacobian (`calibrate_two_asset_e.jl`) | G targets, national | start and chi0 status from `_G_I.txt` / `_GA_I.txt` | place outcomes; wealthy htm if borrowed |
| 2 | GSE, GSAE | no script exists (`calibrate2.yml:106` routes them to `calibrate_two_asset.jl`, which errors at line 31) | | | |

Checks of the table against the code:

- No inherited value comes from the wrong file. GSE reads the GSAE sigma (`calibrate_country.jl:89`), two-asset GS reads the two-asset GSA sigma (`calibrate_two_asset_s.jl:55`), two-asset E starts from the two-asset E-off file (`calibrate_two_asset_e.jl:44-46`). Verified on disk: FR GS 1.02 = FR GSA, DE 1.04, IT 1.50, and GSE = GSAE (1.10, 1.06, 1.54).
- Inherited without an existence check: sigma in both GS paths and chi0 under `CHI_FROM` (Finding 2).
- A target effectively fitted by a parameter that does not own it, and one parameter carrying three targets: Finding 3.
- Parameters silently at defaults: none inside the calibration scripts when the parent files exist. Outside them, see Finding 2.

## Table 2. Staleness inventory

Fix commit: `94849c2`, 2026-09-29 21:21:10 -0400 (2026-09-30 01:21:10Z), "fix: effort moment averages over the employed". Dates are `git log -1 --format=%ci`. Provenance was cross-checked against the Actions runs (head SHA and job end time): every "yes" file was produced by a run on `94849c2` or later.

| File | Last commit (-0400) | Fresh? | Depends on | Dependency newer than file? |
|---|---|---|---|---|
| FR.txt (GSA) | 09-29 21:42 | yes (run 36654702242) | none | n/a |
| FR_G, FR_GA | 09-29 21:34, 21:30 | yes | none | n/a |
| FR_GS | 09-29 22:01 | yes (run on 3f06c80) | FR.txt | no |
| FR_GE | 09-29 22:37 | yes | none | n/a |
| FR_GAE, FR_GSAE | 09-30 11:23 | yes | none | n/a |
| FR_GSE | 09-30 15:34 | yes | FR_GSAE | no |
| DE.txt (GSA) | 09-30 11:23 | yes | none | n/a |
| DE_G, DE_GA | 09-29 21:30, 21:34 | yes | none | n/a |
| DE_GS | 09-30 15:34 | yes (run on 7b43e6c) | DE.txt | no |
| DE_GE, DE_GAE, DE_GSAE | 09-30 11:23 | yes | none | n/a |
| DE_GSE | 10-01 10:53 | yes | DE_GSAE | no |
| IT.txt (GSA) | 09-29 21:38 | yes | none | n/a |
| IT_G, IT_GA | 09-29 21:30, 21:34 | yes | none | n/a |
| IT_GS | 09-29 21:53 | yes (run on 6eb7156) | IT.txt | no |
| IT_GE, IT_GAE, IT_GSAE | 09-30 11:23 | yes | none | n/a |
| IT_GSE | 10-01 10:53 | yes | IT_GSAE | no |
| FR_G_I | 09-29 22:40 | yes (run 36654708277 on 94849c2) | none | n/a |
| FR_GA_I | 10-01 23:54 | yes (run 36879931844) | none | n/a |
| FR_GE_I | 10-01 10:53 | yes | FR_G_I | no |
| FR_GAE_I | 10-01 23:54 | yes | FR_GA_I (same commit; fetched as prereq) | no |
| DE_G_I | 09-30 15:34 | yes | FR_G_I (chi0 0.0134, matches) | no |
| DE_GA_I | 10-01 23:54 | yes | FR_GA_I (chi0 0.0011, matches) | no |
| DE_GE_I | 10-01 10:53 | yes | DE_G_I | no |
| DE_GAE_I | 10-01 23:54 | yes | DE_GA_I | no |
| IT_G_I | 09-30 15:34 | yes | FR_G_I (chi0 0.0134, matches) | no |
| **IT_GA_I** | **09-29 17:50** | **NO, 3.5 h before the fix** | FR_GA_I | **YES** (parent 10-01; file has chi0 0.0113, parent 0.0011) |
| IT_GE_I | 10-01 10:53 | yes | IT_G_I | no |
| US markers (4) | 09-28 02:04 | n/a (not calibrated by decision) | | |

Configurations with no file (13 of 48; all one-asset files exist):

- FR two assets: GS, GSA, GSE, GSAE. The FR GSA job in run 36881412891 ended after 2 h 05 with no step conclusion and its log is no longer retrievable.
- DE two assets: GS, GSA, GSE, GSAE. DE GSA ended "not calibrated" at 1.34 band (run 36930006465; see Finding 4). No marker file was committed.
- IT two assets: GAE, GS, GSA, GSE, GSAE. The post-fix IT GA job (run 36881409504) was killed by the runner after one solve (exit 143), so nothing replaced the stale file and nothing was chained.

Side note for whoever reads the logs: the committed `calibrate_FR_GSA.log`, `calibrate_FR_GS.log`, `calibrate_DE_GSA.log`, `calibrate_DE_GS.log` and `calibrate_IT_GS.log` are from 2026-09-28 and describe pre-fix runs (FR GSA phi 4.76 there, 6.15 in the file).

## Findings

### 1. `calibration_country_IT_GA_I.txt` is a pre-fix file with a superseded borrowed chi0

- Location: `SAGE_Bewley/scripts/calibration_country_IT_GA_I.txt` (commit `ae75ddd`, 2026-09-29 17:50 -0400).
- Severity: WRONG RESULTS. Confidence: CONFIRMED.
- It was fitted to the per-person effort moment and holds chi0 = 0.0113 "from FR", while France G+A is now 0.0011. It should have been replaced by run 36881409504, which died at exit 143. Every other IT/DE/FR two-asset file is post-fix.
- Scenario: `test_carbon2.jl IT`, `test_reporting2.jl IT`, `probe_hardship_by_place.jl IT` and `test_place_report.jl IT GA I` all call `country_config("IT"; config = "GA", ..., illiquid = true)` and get phi 2.389, beta_bar 1.0061, share 0.28. A manual dispatch of `calibrate2` for IT GSA or GAE passes its `isfile` check on this file and starts from it, keeping the stale chi0 as "borrowed".
- Smallest fix: delete the file (or rename it `.stale`) until IT GA is rerun with `chi_from=FR`. Any committed output for IT on two assets with A on should be treated as pre-fix.

### 2. A missing calibration file gives the struct defaults, silently; two inherited values go through that path unchecked

- Location: `sage_modular.jl:829-864` (`isfile` at 852, no `else`); `calibrate_country.jl:89`; `calibrate_two_asset_s.jl:55`; `calibrate_two_asset.jl:115-116`.
- Severity: WRONG RESULTS when triggered (not triggered by any file now on disk). Confidence: CONFIRMED by reading.
- Line by line, with the file absent the dictionary holds only the data-table entries (unemployment, share, alpha, alpha_off, B, delta, f_find, rr, e_ref, unemployed_ratio, median_to_mean, rho, eta_z, dread), then `country`, then `E = true` if the config string contains E, then the caller's keywords. Everything else is the `SAGEConfig` default: phi 14.0, beta_spread 0, beta_bar 0.96, kappa 10, sigma_m 0.40, impatient_share 0, chi0 0.05, illiquid_premium 0.0. There is no warning and no fallback to another configuration's file, so a run cannot pick up another configuration's parameters through `country_config` itself.
- It can still produce a plausible-looking economy: with `illiquid = true` and no `_I` file the model solves with a zero premium and chi0 0.05. A `.not_calibrated.txt` marker beside a file is ignored.
- A second trap in the same function: the config string selects the file and sets E, but not S or A. `country_config(c; config = "GA")` returns a G economy at G+A parameters, and `config = "GA", S = true` returns S on at kappa 10, sigma 0.40. All current callers pass matching switches (checked by grep).
- Unchecked inherits: two-asset GS without `_GSA_I.txt` fixes sigma at 0.40 and writes a normal-looking file (only the OFF file is checked, line 47). One-asset GS/GSE without the GSA/GSAE file does the same. `CHI_FROM` without the donor file borrows 0.05 and still writes "chi0 from FR" in the header.
- Scenario: dispatch `calibrate2` with configs `GS` for France today. `_G_I.txt` exists, `_GSA_I.txt` does not, the log prints "sigma 0.40 from G+S+A" and the run proceeds.
- Smallest fix: in `country_config`, `isfile(cal) || error(...)` unless the caller passes `allow_uncalibrated = true` (the calibration scripts' own starting points need that), and error if the marker exists. Add `isfile` guards at the three inherit sites.

### 3. chi0 is not identified by the wealthy hand-to-mouth; the lower bound is a flat-Jacobian artefact (symptoms a and d)

- Location: `calibrate_two_asset.jl:70-76, 86-89, 139-158`; same parameterisation in `_s.jl:68-72` and `_e.jl:58-62`.
- Severity: WRONG RESULTS for any statement that chi0 is calibrated to the wealthy hand-to-mouth. Confidence: CONFIRMED from logs.
- Evidence, France G+A, run 36805943146, steps 1 to 9 at near-constant patience: chi0 visited 0.0010, 0.0013, 0.0027 and 0.0074 while the wealthy hand-to-mouth stayed between 0.1255 and 0.1280 (band half-width 0.01). The moment is not even monotone in chi0 there (0.0010: 0.1278, 0.0027: 0.1280, 0.0074: 0.1270). Across all France runs the moment tracks patience: 0.07 at net wealth/income 17, 0.12 at 9, 0.17 at 3.9.
- Consequence for (a): the chi0 column of the Jacobian is finite-difference noise (log step 0.25, moment change about 0.001), so Newton sends chi0 wherever the other residuals push it, capped at a factor e per step and clamped at `LO[2] = log(1e-3)`. France G+A ended at 0.0011 and G+A+E at exactly 0.0010; France G ended at 0.0134 for the same target. These are stopping points, not estimates. The first France G+A run stalled at 1.40 band from the point (0.9842, 0.0030, 0.0021, 4.848), and a restart from the same point rounded to four digits converged in one step, which is the same noise.
- Consequence for France: the impatient share is also at its corner (0.0009 to 0.0046, lower bound 0), so net wealth, wealthy htm and poor htm are all carried by beta_bar. The accepted points sit where the three bands overlap: G+A has net wealth at -0.55 band, wealthy htm at -0.72, poor htm at +0.14. The fit is real but it is one parameter and three wide bands, not four parameters on four targets.
- Consequence for (d): Germany and Italy miss the wealthy hand-to-mouth (0.138 to 0.150 against 0.248, 0.054 to 0.071 against 0.155) because patience is pinned by their net-wealth target and nothing else moves the moment. Borrowing chi0 is not what causes the miss, and fitting it would not cure it. The borrowed value is 0.0134 in G and 0.0011 in G+A, so the G to G+A comparison in DE and IT also changes the fixed cost twelvefold (median liquid/income moves 0.236 to 0.210 in DE).
- Smallest fix: take chi0 out of the fitted set for France as well (fix one value for all countries and both configurations, state it as an assumption), report the wealthy hand-to-mouth as untargeted everywhere, or replace the target with one chi0 moves (the logs suggest median liquid wealth / income, HFCS Table F1, already quoted in `probe_two_asset_map.jl`).

### 4. Net-wealth moment is a grid step function and the S/E corrections are undamped: DE two-asset G+S+A fails by oscillation

- Location: `qmed` at `calibrate_two_asset.jl:55`, `_s.jl:63`, `_e.jl:53`; `NWGRID` at `egm2_core.jl:356`; `STEP[1] = 0.004` at `_s.jl:72`; correction loop `_s.jl:143-156`, `_e.jl:104-124`.
- Severity: WRONG RESULTS for the "not calibrated" verdict on DE GSA two assets; FRAGILE elsewhere. Confidence: CONFIRMED for the mechanics, LIKELY for the causal reading.
- `qmed` returns the first grid point whose cumulative mass reaches one half, with no interpolation. `NWGRID` is 80 (i/239)^3, so at the three countries' medians the spacing is 5.0% (DE), 4.2% (FR), 3.6% (IT), against a band of plus or minus 5%. The moment is biased up by about half a step and can only take two or three values inside the band. `cdf_quantile`, used for liquid wealth, would interpolate.
- The moment is very steep in patience near the target: in the DE logs d ln(NW)/d beta is 200 to 260 (0.9895: 2.30, 0.9900: 2.54), so the 5% band is about 0.0002 in beta. The Jacobian is differenced over 0.004, twenty times that, where the secant slope is about 100 to 170.
- `calibrate_two_asset.jl` has a backtracking line search, so it copes. `_s.jl` and `_e.jl` apply the full step with only the MAXMOVE cap and never keep the best iterate. DE GSA, run 36892899827: net wealth/income 2.79, 2.22, 2.59, 2.23 at beta_bar 0.9902, 0.9891, 0.9897, 0.9890 against a target of 2.38. Each step aimed at 2.38 and overshot by a factor of about two. The run ended at 1.34 band on net wealth with every other target inside 0.1 band.
- The same loop on France GAE made the fit slightly worse at each of three corrections (0.60, 0.63, 0.67, 0.70 band, about 75 minutes each) and wrote the last one.
- Smallest fix: interpolate the median (`cdf_quantile(NWGRID, Ntot, 0.5)`), cut `STEP[1]` to about 0.0005, and in `_s`/`_e` halve the step when a residual changes sign and write the best evaluated point.
- Related, SUSPECTED: the denominator is `r.median_income`, which under the default `poverty_line = :anchored` is the data ratio median/mean (equivalised net income) times the model mean (`sage_modular.jl:582`), not the model's median. The comment at lines 226-231 puts the model's own ratio near 0.98 against 0.87, so the moment is about 13% above the ratio of the model's two medians, and the data target is over gross household income. This is a definitional choice larger than the band; it should be stated or changed to `median_model`.

### 5. A failed, killed or budget-stopped run leaves the old `_I.txt` in place; the chain passes only one file

- Location: `calibrate_two_asset.jl:183-187`, `_s.jl:44-45`, `_e.jl:41-42`, `calibrate_country.jl:108` (marker written, output file not removed); `calibrate2.yml:113-120`, `calibrate.yml:108-115`; `.github/chain.sh:23-28, 36-40`.
- Severity: FRAGILE. Confidence: CONFIRMED.
- What was asked: can exit 2 pass a stale checkout file to dependents as new? Through the chain, no. `chain.sh` runs only when `steps.cal.outputs.code == '0'`, and every exit 0 path writes the file first (checked in all four scripts). The two FR GA starts in the logs fired only after "wrote".
- What does happen: on exit 2, exit 3 with hops exhausted, or a crash, the committed file stays on disk and is uploaded in the artifact (the glob `calibration_country_<C>_<CFG>_I*.txt` matches it), beside the marker on exit 2 and with no marker otherwise. The IT GA artifact of run 36881409504 contains the stale file this way. "Download and commit what you accept" then has a stale file that looks like output, and Finding 1 is the live instance.
- Second gap: a dependent receives one prereq file and takes everything else from the branch checkout. Two-asset GS is started by GSA with `_GSA_I.txt` but reads `_G_I.txt` (its starting point, and its chi0 when borrowed) from the repository. After any rerun of G and GA in which G is not yet committed, GS silently starts from, and for DE/IT keeps the chi0 of, the old G file. Also FR G is not chained to DE/IT G, so a new France G chi0 does not propagate.
- Third gap: dependents and resumes check out `--ref $GITHUB_REF_NAME`, the branch head at dispatch, not the parent's SHA. FR GAE and DE GSA began on `5558a95` and resumed on `a327844`. The two-asset checkpoint carries no code or target key, so this is accepted without notice.
- Smallest fix: in each "not calibrated" path `rm(OUTFILE; force = true)`; in both workflows delete the job's own output file after checkout and before the run; make `chain.sh` pass every file the dependent reads (or have the dependent fail if a parent is older than the prereq); dispatch dependents with the parent's SHA.

### 6. Participation is accepted on the scan, not on the solved economy

- Location: `calibrate_country.jl:425-443`; `calibrate_two_asset_s.jl:126-131, 160-163`; `place_layer.jl:311` (`nq = 500`); `sage_modular.jl:762-779` against `sage_modular.jl:554`.
- Severity: FRAGILE (a file can be written with solved participation outside the stated tolerance). Confidence: CONFIRMED for the gap, LIKELY for its cause.
- After the full-grid scan the scripts check hand-to-mouth, effort and the multiplier on the solved economy, but participation only through the scan's loss. With E off the two agree to four digits. With E on they do not: DE GSE scan 0.2769, solved 0.2752, target 0.2789, so the reported loss is 0.0020 and the true miss 0.0037 against a tolerance of 0.005; FR GSE 0.2322 against 0.2306; IT GSE 0.1247 against 0.1226; IT GSAE 0.1252 against 0.1231. The gap is always about -0.002. `scan_technology_places` defaults to 500 taste nodes while the solve uses `c.nq = 2000`, and the caller does not pass `nq`.
- Separately, `scan_technology` (E off) scores every stable crossing and keeps the best, while `_solve` selects the highest one. The calibration scripts never pass `selected_only = true` (`policy_tests.jl` does). With two stable crossings under the gate the scan could fit the lower and the file would describe a different equilibrium. Not observed in any log.
- The 0.035 standard for G+S+A is far looser than what is achieved (0.0002 to 0.003): it admits sigma from 0.62 to 2.5 in the France log. The file holds the argmin, so this matters only as a statement of what "calibrated" guarantees.
- Smallest fix: pass `nq = c.nq` in `scans_places`, pass `selected_only = true` in the calibration scans, and add a check of `r.pooled` (or `r.rate`) against the targets before `write_cal`.

### 7. Exit code 3 has two meanings

- Location: `calibrate_country.jl:175` (preflight failed) and `:150` (time budget); `calibrate.yml:107, 121-128`.
- Severity: FRAGILE. Confidence: CONFIRMED.
- The workflow treats 3 as "resume in a new run". A failed preflight therefore shows as a green job and starts up to five further runs that fail the same way. Exit 2 and exit 3 both leave the job green, so the Actions list cannot be read for "calibrated": the DE GSA job that ended not calibrated is listed as success.
- Smallest fix: exit 4 for the preflight and let the step fail on it.

### 8. Checkpoint keys do not cover what the checkpoints depend on

- Location: `calibrate_country.jl:117` with `sage_modular.jl:401-410`; `calibrate_two_asset.jl:104-114`, `_s.jl:83-92`, `_e.jl:76-85`.
- Severity: FRAGILE (local reruns; CI only restores checkpoints on a resume). Confidence: CONFIRMED.
- The one-asset key hashes `SOLVER_FILES`, which excludes `sage_modular.jl` (where the effort moment is computed and where the fix was made), `place_layer.jl` and the place data. A stage-1 checkpoint from before the fix has the same key after it. The damage is bounded because the final economy is re-solved and checked, so the outcome is a false "not calibrated" or a wasted correction, not a wrong file.
- The two-asset checkpoints have no key. They survive exit 2, take precedence over `SAGE_START`, and `_s` at stage 4 will repeat the same failed final stage on every local rerun. `checkpoint_two_asset_*.txt` is not in `.gitignore` (only `checkpoints/` is).
- Smallest fix: add `sage_modular.jl` and `place_layer.jl` to the digest used by `CKKEY`; write the same digest plus the targets into the two-asset checkpoint and ignore a mismatch; remove the checkpoint on exit 2; add the pattern to `.gitignore`.

### 9. Italy on two assets sits where stationarity rests on mortality (symptom c)

- Location: `calibrate_two_asset.jl:56-63, 73-74`.
- Severity: FRAGILE (identification). Confidence: LIKELY; the discounting convention is taken from the script's comments.
- beta_bar 1.004 is not a search bound: the bound is 0.995 on effective patience, which is beta_bar 1.0176. Effective patience is 1.0040 x 44/45 = 0.9817. With R = 1.02 for every country, effective patience times the liquid return is 1.0013, above one, and times the illiquid return (1.0415) is 1.022. The one-asset code caps beta R at 0.995 for this reason. The patient 73% therefore accumulate without limit while alive, and the median net wealth is set by death and by the grid tops (k_max 150, b_max 15). The stale G+A file is further out (1.0034).
- The impatient share of 27% is not a bound either (cap 0.4). It is large because the impatient type's patience is fixed at 0.85 with no source, and share and level cannot be separated by one target. Only about a third of the impatient are hand-to-mouth, so matching 8.3% takes 27% of households, which then drags the median and forces the patient group's beta up.
- The move with E on (0.999 and 17%) has a traceable cause: at the E-off point solved over Italy's 21 regions the poor hand-to-mouth is 0.116 against 0.083 (run 36768883567). Regional heterogeneity supplies part of the hand-to-mouth, so fewer impatient households are needed and the patient group needs less patience. The one-asset files show the same thing (spread 0.110 in G, 0.080 in GE). So "E fits nothing" holds as a statement about targets, but for Italy E moves the fitted preference parameters by about 40%.
- What to do: state the common R and the 0.85 as assumptions, report a sensitivity of IT to k_max and to the 0.85, and treat E-off against E-on parameter differences in Italy as a result.

### 10. France's zero spread is the designed corner, and the tolerance is wide there (symptom b)

- Location: `calibrate_country.jl:201-219, 102`.
- Severity: COSMETIC. Confidence: CONFIRMED.
- When equal patience at 0.96 already gives a hand-to-mouth share at or above the target, `fit_spread` sets the spread to zero and bisects beta_bar upward in [0.96, 0.975]. France's target (0.032) is at that kink: G+A and G+S+A take the patience branch (0.9633, 0.9642), G and G+S take the spread branch (0.005, 0.002). The two branches join continuously, so it is one parameter on one target and it is identified.
- Two things follow. The "spread" column for France compares different parameters across configurations. And `HTM_TOL = 0.005` is 16% of France's target, so spreads of 0.000 to about 0.010 are all inside the band and differences between France's configurations in this parameter are not information. On two assets the same corner appears as an impatient share of 0.001 to 0.005.

### 11. E-on technology refinement is a window around the coarse winner

- Location: `calibrate_country.jl:293-303`.
- Severity: FRAGILE. Confidence: SUSPECTED.
- With E on, sigma is scanned at step 0.06 and kappa at 0.1, then re-scanned within plus or minus 0.06 and 0.2 of the best point. The kappa search is global at each sigma, but the sigma refinement is local, which is the pattern `scan_technology`'s own docstring warns against. The loss surface is a long ridge (sigma 0.62 to 2.5 within 0.035), and re-scans in the logs move the best sigma by 0.04 to 0.06 at losses of 0.001. The written E-on sigma is therefore good to about 0.06, and GSE inherits it.

### 12. Two-asset files are rounded after the check

- Location: `calibrate_two_asset.jl:191`, `_s.jl:171`, `_e.jl:139`.
- Severity: COSMETIC. Confidence: CONFIRMED.
- The economy checked is at the unrounded point; the file stores beta_bar to four decimals. With d ln(NW)/d beta near 200 to 260 that is up to 1.3% of net wealth, a quarter of the band. chi0 at 0.0011 has two significant digits. A point accepted near the band edge can be outside it when read back. Writing six decimals removes it.

## Checked and found correct

- Effort fix is in the moment every script uses: `mean_effort_employed` divides by employed mass (`sage_modular.jl:613-614`); all four scripts target that field; the place aggregate weights it by the employed (`place_layer.jl:236, 270`).
- Family cache cannot return a pre-fix effort: families store `eff_E` and masses, the division happens in `_solve` after loading.
- All 24 one-asset files and 11 of 12 two-asset files were produced by runs on `94849c2` or later (run head SHAs and job end times against commit times).
- Parents precede dependents for every fresh file, and inherited values match on disk (sigma GS = GSA, GSE = GSAE; chi0 DE/IT G = FR G 0.0134, DE GA = FR GA 0.0011).
- Coarse to fine, one asset: the written kappa and sigma come from the `UGRID_DEFAULT` scan and the checked economy is solved on it (`calibrate_country.jl:424-443`); the ugrid reaches the place configs through `SAGEConfig(c; E = false)`. Logs show "5b ... 83 scales" before every "wrote". phi and spread are grid-independent (S-off fits).
- Coarse to fine, two assets with S: final scan and solve use `UGRID_DEFAULT` and the file takes `sc.best` from that scan (`_s.jl:160-172`). Two assets with E has no belonging grid (S off).
- No file is written while a checked G target is outside its band: every write is behind the tolerance test (`calibrate_country.jl:267-272, 431-443`; `calibrate_two_asset.jl:170, 183-187`; `_s.jl:161-163`; `_e.jl:126`). Logged final values agree with the files.
- Multiplier gate is applied in the scan and again on the solved economy, and the E-on scan and solve use the same population-weighted multiplier.
- Half-band rule: one-asset corrections trigger above half the tolerance (line 395), two-asset S/E stop correcting at 0.5 band and accept at 1.0.
- Exit 0 always follows a write, and `chain.sh` is reached only on exit 0; the `set -e` in `chain.sh` does not trip on the `[ ... ] && run2` line.
- Prereq fetch: the artifact root is `SAGE_Bewley/scripts/`, so `/tmp/pre/$file` resolves; resumes forward `prereq`; logs show "using calibration_country_FR_GA_I.txt from run 36879931844" in each dependent.
- Targets are read by header name and by (country, field): `effort_target`, `htm_target`, `part_low`, `part_high`, `ratio` from the country row; `whtm_target`, `nw_income_target`, `illiquid_premium` from `manual_inputs.csv` for `CODE`. With `CHI_FROM` only chi0 comes from the donor; targets and premium stay the country's own. Logged targets match the data files.
- `AGG` uses the national cell shares and the place scan's aggregate re-weights to the same shares (composition is rescaled to the national tertiary share).
- The SAGE_START unit bug (effective patience against beta_bar) is fixed in `db7292b`; the accepted FR GA run used the corrected reading (start reproduced the earlier point: 3.75, 0.1710).
- `fit_phi` and `fit_spread` monotonicity assumptions and brackets are consistent with the logs; a bracket miss is caught by the final tolerance check.

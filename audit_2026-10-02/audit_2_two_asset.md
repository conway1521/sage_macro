# Audit 2: the two-asset household problem

- WRONG RESULTS: 2 findings (one stale committed calibration, one quantised calibration moment).
- FRAGILE: 8 findings (smoothing scale against chi0, silent non-convergence, checkpoint provenance, target definition, unguarded corrections, rounding of written parameters, grid tops and the coarse illiquid grid, crash paths).
- COSMETIC: 1 finding (start values, stall averaging).
- The core economics (both budgets, the envelope, discounting with death, the newborn distribution, the branch walker against the distribution) derives correctly; see the last section.
- Nothing was run. Every statement is from reading the code, the committed calibration files, the logs in `scripts/logs_two_asset/` and `git log` (read-only). Magnitudes marked "estimated" are hand calculations, not solver output.

Paths are relative to `/Users/ali/Desktop/UNI/Paris 8/extra_papers/SAGE/`.

---

## 1. The committed Italy G+A two-asset calibration is stale on two counts

- Location: `SAGE_Bewley/scripts/calibration_country_IT_GA_I.txt` (whole file); mechanism in `SAGE_Bewley/scripts/calibrate_two_asset.jl:115-121`
- Severity: WRONG RESULTS
- Confidence: CONFIRMED (git history and file contents)

What is there. The file was written on 09-29 17:50 (commit `ae75ddd`) and has not been touched since. It says `chi0 = 0.0113` "from FR" and `phi = 2.389`.

Why it is wrong.
1. The effort moment was redefined at 09-29 21:21 (commit `94849c2`, "effort moment averages over the employed"). The comment in `sage_modular.jl:608-612` says every calibration was redone. This one was not. Its phi was fitted to per-person effort against an employed-person target. The France G+A file moved from phi 3.682 (before the fix, `git show 59fc531`) to 4.807 (after), a 30% change, and the Italian phi 2.389 against the Italy G value 3.176 shows the same gap.
2. France G+A was recalibrated on 10-01 (commit `108ff2d`) and its chi0 moved from 0.0113 to 0.0011. Germany G+A was redone in the same commit and carries 0.0011. Italy G+A still carries 0.0113, so "chi0 from FR" in its header is no longer true.

Size. A factor of ten in chi0, and phi about 25% too low. Anything that loads `country_config("IT"; config = "GA", illiquid = true)` uses it, including any later GSA or GAE run for Italy, which start from this file.

Smallest fix. Rerun `calibrate_two_asset.jl IT GA FR`. To stop the recurrence, write the borrowed country's chi0 and a date or commit into the header and have `country_config` or the S and E scripts compare it with the current donor file.

---

## 2. The net-wealth moment is read off NWGRID without interpolation; the grid step is as wide as the tolerance band

- Location: `calibrate_two_asset.jl:55, 82`; `calibrate_two_asset_s.jl:63, 73`; `calibrate_two_asset_e.jl:53, 63`; grid at `egm2_core.jl:356`
- Severity: WRONG RESULTS (moderate: bias of about half a band, noise of up to one band)
- Confidence: CONFIRMED BY DERIVATION

What the code does. `qmed(x, cm)` returns `x[k]` for the first node whose cumulative mass reaches one half, that is the upper bracketing node, with no interpolation. `NWGRID = exponential_grid(0, 80, 240, 3.0)`, so node x = 80 u^3 with u on 240 equal steps, and the relative spacing at x is 3 / (239 u).

Derivation. Median income is about 0.58 (France, `policy_results_FR.csv`). The target medians are then about 2.3 (FR), 1.4 (DE), 3.0 (IT), giving u = 0.307, 0.258, 0.335 and relative steps of 4.1%, 4.9% and 3.7%. The tolerance on this moment is 5% in logs (`TOL.nw = 0.05`).

Consequences.
- The reported ratio is biased upwards by about half a step on average (about 2%, or 0.4 of a band), because the upper node is always taken.
- The residual is a step function of the parameters. A finite-difference column whose true effect on median net wealth is below one step (the impatient share with h = 0.01, phi with h = 0.05) is either zero or one full step divided by h. For the share column one step is 0.8 band / 0.01 = 80 per unit, pure noise. This is a likely contributor to the "Newton step failed" and "no improving point" lines in the logs.
- "Calibrated" can flip on a grid snap: a point at 0.7 band and a point at 1.5 band can be the same economy to within 2%.
- The same function is used for the liquid validation line (`qmed(r.agrid, r.Wtot)`), where the liquid grid step near 0.15 is about 12%. The "median liquid over median income 0.253 against 0.249" comparison in `TWO_ASSET_DESIGN.md` therefore has a granularity of roughly 0.03.

Smallest fix. Replace `qmed(NWGRID, r.Ntot)` by the existing `cdf_quantile(NWGRID, r.Ntot, 0.5)` (`agency_core.jl:142`), which interpolates, in all three scripts, and the same for the liquid line. Existing calibrations should then be re-checked, since each may sit up to about 2% lower than reported.

---

## 3. At the calibrated chi0 of 0.001 the fixed cost is smaller than the keep-or-adjust smoothing, and it sits at its lower bound

- Location: `egm2_core.jl:147-169` (logit over targets and over keep or adjust, theta_adj = 0.01); `calibrate_two_asset.jl:73` (`LO[2] = log(1e-3)`); `calibration_country_FR_GA_I.txt`, `_FR_GAE_I.txt`, `_DE_GA_I.txt`, `_DE_GAE_I.txt` (chi0 0.0010 to 0.0011)
- Severity: FRAGILE (the code does what it says; the calibrated parameter is not identified where it landed)
- Confidence: LIKELY (derivation of magnitudes; not run)

Derivation. The adjuster's value is `Va = vmax + theta_adj log(sum_j exp((Vj - vmax)/theta_adj))` and the adjusting probability is `1 / (1 + exp((Vk - Va)/theta_adj))`. The utility cost of the fixed cost is about u'(c) chi0. With gamma = 2 and c about 0.6, u'(c) is about 2.8, so chi0 = 0.001 costs 0.0028 in utility, against theta_adj = 0.01. An adjuster who "adjusts" to the node it would have kept anyway is chosen with odds exp(-0.28), about 43%, and the inclusive value adds up to theta_adj log(n) for n near-equal targets (the lowest illiquid nodes are 0, 0.012, 0.099, 0.33, whose values differ by less than theta_adj for a household with little wealth). The taste noise is therefore larger than the friction the parameter is meant to represent.

The robustness statement in the design notes (0.01 and 0.02 agree, 0.05 moves the adjusting share from 9% to 22%) was established at chi0 = 0.05, where u'(c) chi0 is about 0.14, fourteen times theta_adj. It does not carry over to chi0 = 0.001.

Consequences.
- France G+A converged to chi0 = 0.0011 with the bound at 0.0010: the wealthy hand-to-mouth target is met by a parameter that is 10% from its bound and below the noise scale. Germany G+A and G+A+E borrow that value.
- At this cost the illiquid asset is close to a second liquid asset with a higher return. A household that holds b near zero and withdraws from k every year is counted as wealthy hand-to-mouth (`egm2_core.jl:550-551`) while behaving like an unconstrained saver, which matches the reported pattern of an MPC of 0.11 for the wealthy hand-to-mouth.
- France G (chi0 = 0.0134, utility cost about 0.037) is not affected.

Smallest fix. Repeat the theta_adj 0.01 against 0.02 comparison at the calibrated France G+A point and report the wealthy hand-to-mouth share and the adjusting share at both. If they differ, either raise `LO[2]` to about theta_adj / u'(c) (0.004 to 0.005) and treat chi0 below it as not identified, or exclude the degenerate "adjust to where keeping would have led" alternative from the logit.

---

## 4. A stalled or non-converged value function is never reported outside the solver

- Location: `egm2_core.jl:104, 188-199, 215, 236`; no reader in `unemployment_core.jl`, `agency_shock.jl`, `sage_modular.jl`, `place_layer.jl`
- Severity: FRAGILE
- Confidence: CONFIRMED (code and grep)

What the code does.
- Stall path: when relax has reached 1/16, the best bound of the last 50 iterations is not 10% below that of the 50 before, and `dist < 1e-2`, the solver averages two iterates and returns. `dist` is the MacQueen-Porteus span beta/(1-beta) (dmax - dmin), so the value function is known only to within about 5e-3. That equals the participation smoothing (theta 0.005) and is half of theta_adj, so choice probabilities at the affected states are not pinned down.
- maxit path: if `dist` stays above 1e-2 at relax 1/16, `stalled` is never set, the loop runs to `maxit = 5000` and returns with `stalled = 0.0`. There is no warning and no error; the result looks clean.
- `grep` finds `stalled`, `relax` and `iters` only in `egm2_core.jl`, `test_egm2.jl` and `probe_egm2_gridtop.jl`. `two_asset_cell_summary` and `two_asset_agency_summary` drop them, so `build_family_ag`, `_solve` and the calibration scripts never see them. `TWO_ASSET_DESIGN.md` line 72 says "the family builder reports the worst case"; that is not in the code.

Scenario. A calibration step lands on a parameter point where one (cell, patience type) problem cycles. Its moments enter the Jacobian and possibly the final written point with no trace in the log.

Smallest fix. In `solve_two_asset_egm`, after the loop, `iters == maxit && dist >= tol && !stalled` should raise an error or at least print. Carry `stalled` and `iters` into the cell summary (a max over types in `collapse_all`) and print the worst value in `report` of the calibration scripts; refuse to write a calibration file when it exceeds a chosen level (1e-4, say).

---

## 5. Checkpoints and SAGE_START carry no provenance and override the borrowed chi0

- Location: `calibrate_two_asset.jl:107-121, 183-187`; `calibrate_two_asset_s.jl:44-45, 103-117, 156`; `calibrate_two_asset_e.jl:41-42, 95-101`
- Severity: FRAGILE
- Confidence: CONFIRMED BY DERIVATION (control flow)

a) `calibrate_two_asset.jl`: with a third argument, `x[2] = log(chi_start)` is set from the donor country, then `read_start()` replaces the whole of `x`, including `x[2]`, with the checkpoint or with SAGE_START. Index 2 is not in `ACT`, so it is never corrected. The log line "chi0 taken from FR: ..." and the file header still say the value is the donor's. A restart from a log line (which prints chi0 to four decimals) or from a checkpoint written before the donor was recalibrated yields a chi0 that is not the donor's.

b) After `exit(2)` (not calibrated) the checkpoint is kept in all three scripts. In the S script the kept file has stage 4, so a later rerun skips stages 1 to 4, never re-reads the OFF calibration, and goes directly to the full grid at the old point with the old Jacobian. In the E script the kept file has stage 3, so a rerun evaluates the old point once and fails again, whatever has changed in the code or in the OFF calibration. Nothing in the checkpoint identifies the OFF point, the targets or the solver digest it belongs to.

c) `country_config(CHI_FROM; ...)` (`calibrate_two_asset.jl:115-116`) returns the default `chi0 = 0.05` without complaint when the donor's `_I` file does not exist.

d) A failed recalibration writes the `.not_calibrated.txt` marker but leaves an older successful `_I.txt` in place, and `country_config` reads the `_I.txt`.

Smallest fix. After `read_start()`, when `CHI_FROM` is set, reset `x[2] = log(chi_start)`. Write a first line into each checkpoint with the OFF point (or its file hash) and `SOLVER_DIGEST`, and ignore the checkpoint when they differ. Delete the checkpoint on `exit(2)`. Add `isfile` on the donor file. On `exit(2)` remove or rename an existing output file.

---

## 6. The denominator of the net-wealth target is not the object the data target uses

- Location: `sage_modular.jl:581-583, 602` (`median_income`); `egm2_core.jl:492-501` (income in the two-asset summary); target in `data/manual_inputs.csv:34-36`
- Severity: FRAGILE (a definitional gap that moves the fitted patience, not a coding slip)
- Confidence: CONFIRMED for what the code computes; SUSPECTED for the size, which depends on what the model's income is taken to represent

What the code computes. `r.median_income` is `median_to_mean * ymean` under the default `poverty_line = :anchored`. `ymean` is mean disposable income: labour income, plus the liquid return (R - 1) b, minus the lump-sum tax, plus the participation credit and transfers. The return on illiquid wealth is excluded by design. `median_to_mean` is the EU-SILC ratio for equivalised net income (0.857 for France). It is not the model's own median (that is `median_model`).

What the target is. HFCS median net wealth over HFCS median gross household income: before taxes and social contributions, per household and not equivalised, including rental and financial income.

Gaps. (i) Gross against net: if the model's income is read as net, the comparable data ratio is higher than 4.02 by the household gross-to-net factor, which I have not sourced and which could be several bands of 5%. (ii) The mean-to-median factor comes from a different income concept and survey than the numerator. (iii) Illiquid income is in neither the model denominator nor, for imputed rent and capital gains, the HFCS one, so that part is roughly consistent.

Smallest fix. Decide and state which income concept the model's income is, then either convert the target (HFCS reports net income for some countries; otherwise an official gross-to-net ratio) or document the choice next to the target in `manual_inputs.csv`. The header comment of `calibrate_two_asset.jl` ("median gross income") should say what is used.

---

## 7. The S and E corrections have no acceptance test and return the last point, not the best

- Location: `calibrate_two_asset_s.jl:143-155`; `calibrate_two_asset_e.jl:104-126`
- Severity: FRAGILE
- Confidence: CONFIRMED BY DERIVATION (control flow)

A correction is triggered when the worst owned target is above 0.5 band, and the result is accepted when it is within 1.0 band. Each correction is a full quasi-Newton step with a Jacobian from a different economy (S off, or E off at the E-off point), capped by MAXMOVE and clipped to the bounds, with no check that the residual fell. A start at 0.8 band, which is acceptable, can be moved three times and end at 1.3 band, and the run then reports "not calibrated" although an acceptable point had been evaluated. The noise in the net-wealth row from finding 2 makes this more likely.

The specific question in the brief, whether `stage >= 3` can end the loop with a point that was moved and never evaluated: no. In both scripts the break precedes the move, so the `s` used for the final check always belongs to the current `x`, also after a resume (a checkpoint at stage k holds the moved point and the loop starts by evaluating it). In the S script the stage-3 point is then evaluated again on the full grid before writing.

Smallest fix. Keep the best (x, s) seen and use it for the final check and the file; or accept a correction only when the sum of squared residuals falls, as `calibrate_two_asset.jl` does.

---

## 8. The written calibration is a rounded point that was never evaluated

- Location: `calibrate_two_asset.jl:191-192`; `calibrate_two_asset_s.jl:171-172`; `calibrate_two_asset_e.jl:139-140`
- Severity: FRAGILE
- Confidence: CONFIRMED BY DERIVATION

`chi0` is written with `%.4f`. At 0.0011 that is two significant digits: any value in [0.00105, 0.00115) is written as 0.0011, an error of up to 5%, or 0.05 in the log units the iteration works in (finite-difference step 0.25). `beta_bar` at `%.4f` is an error of up to 5e-5 in a parameter whose range of action is about 0.012 per step. The S and E scripts then start from the rounded file, so their step-1 economy is not the one that passed the OFF check. Whether this moves a target by more than a tenth of a band is not something I could measure without a solve.

Smallest fix. Write `%.6g` or more for chi0 and `%.6f` for beta_bar and the share, or re-evaluate the rounded point before writing.

---

## 9. Grid tops and the coarse illiquid grid

- Location: `egm2_core.jl:74-76` (keeper clamp), `:137, 289` (liquid clamp for adjusters), `:262-265` (lottery clamp for b'), `:356, 487-489` (NWGRID); `sage_modular.jl:206-208`
- Severity: FRAGILE
- Confidence: CONFIRMED BY DERIVATION for what happens; the masses involved are estimated, not measured

a) Keeper at the top illiquid node: `kn = min(Rk k, k_max)`, so the return (Rk - 1) k_max, about 8 for France, is lost every year at that node only (node 23 is 131, and 131 Rk < 150). Liquid wealth above b_max is likewise lost for adjusters (`be` clamped) and for b' above the top (the lottery puts all mass on the top node while consumption is computed with the unclamped b'). The solver and the distribution treat these the same way, so they are consistent with each other.

b) Italy is fitted at nominal beta_bar of 1.004 to 1.006, effective 0.982 to 0.984, so effective beta times R is about 1.003 and effective beta times Rk about 1.025, both above one for the patient group. Wealth then grows with age without bound and the tops are what stop it. Estimated: asymptotic growth of (1.025)^(1/2) - 1 = 1.2% a year needs about 300 years from the median to k_max, and survival over 300 years is below 0.1%, so the mass at the top should be negligible and the median unaffected. This was not checked on the solved distribution; `EGM2_TRACE=1` prints the row sums but not the top-node mass, and `test_egm2.jl` prints the top mass only for its own test point.

c) NWGRID stops at 80 while b + k can reach 165. Mass above 80 is put on the last node. The median is not affected. The net-wealth Gini and top 10% share printed by `calibrate_two_asset.jl:176-182` are biased down by whatever mass lies above 80.

d) The illiquid grid has 24 nodes with exponent 3: 0, 0.012, 0.099, 0.33, 0.79, 1.54, 2.66, 4.23, 6.31, ... Around the median household (net wealth 1.4 to 3) adjacent nodes are 50 to 70% apart. Adjusters can only choose nodes. Keepers are split between the two nodes around Rk k, which is mean-preserving and consistent with the value function (see "checked"), but it injects dispersion: a keeper at 2.66 moves to 4.23 with probability 9% and stays otherwise, a standard deviation of about 0.46 a year, 17% of the holding (estimated from the node values). The net-wealth Gini and top share quoted as validation against the HFCS include this artificial dispersion. The design's test 3 (convergence in nb and nk) is the check, and I found no record of it being run for nk.

Smallest fix. Extend NWGRID to b_max + k_max. Add the mass at the top illiquid node and at the top liquid node to the calibration report line. Run one solve at nk = 48 for the calibrated France point and compare the four targets and the Gini.

---

## 10. Two crash paths give exit code 1 where the scripts promise 2

- Location: `calibrate_two_asset.jl:88, 144-145`; same residual in the S and E scripts (`:74, 151` and `:64, 120`)
- Severity: FRAGILE
- Confidence: CONFIRMED BY DERIVATION (Julia semantics; not run)

a) `J \ F` on a square matrix goes through `lu`, which throws `SingularException` for an exactly singular matrix. It does not return non-finite numbers, so the `pinv` fallback on the next line is reached only when `J` already contains Inf or NaN, and `pinv` then fails as well. A zero column (possible for the net-wealth row because of finding 2, and for chi0 when the wealthy hand-to-mouth do not respond) ends the run with an uncaught exception. The S and E scripts have no fallback at all.

b) If the median household has zero net wealth, `qmed` returns `NWGRID[1] = 0` and `log(m.nw / NW_TARGET)` is -Inf. The first-run logs show net wealth to income of 0.3 to 0.5, so this region is not hypothetical.

The workflow that restarts on exit 3 and records exit 2 would see an unclassified failure. Smallest fix: wrap the solve in `try` with `pinv` in the `catch`, and floor `m.nw` at a small positive number in `resid`.

---

## 11. Start values and the stall average (no effect on the fixed point)

- Location: `egm2_core.jl:87-89, 196-198`
- Severity: COSMETIC
- Confidence: CONFIRMED BY DERIVATION

The cold start sets `Vb = R Gamma c^-gamma` without the division by pc that the one-asset start has (`egm_core.jl:212`) and that the iteration itself applies, and its flow value uses `tfl + e` without the commuting factor. Both only affect the number of iterations. On a stall, the level shift is added to `Vn` and the result is then averaged with the unshifted `V`, so half of the shift is lost; this moves only the level of V (the `vmass` welfare number), and only in a stalled solve.

---

# Checked and found correct

1. Keeper budget. `egm_branch!` is called with the plain liquid budget, pc c + b' = R b + w e + other, and the keeper is sent to illiquid Rk k (`kn`, `egm2_core.jl:74`). Resource identity pc c + b' + k' = R b + Rk k + y with k' = Rk k holds.

2. Adjuster budget. `shift[m, j] = (Rk k_m - chi0 - k_j) / R` and the inner budget at `be = b + shift` gives pc c + b' = R b + Rk k - chi0 - k_j + y, which is the design budget with the cost paid in the period of the change. The division by R is right because `be` is pre-return liquid wealth. The illiquid return is credited on the state k at the start of the period, for keepers and adjusters alike, and a newly chosen k_j earns from the next period.

3. The same identity in the summaries. `two_asset_distribution` (lines 277-278, 299-300) and `two_asset_welfare_parts` (line 427) both compute c = (R be + w e + other - b') / pc with be = b for keepers. `sbar` adds R (b - be) = k_j + chi0 - Rk k for an adjuster, so pc c + saving = R b + labour + other and the adding-up check (MPC + MPS = 1 + MPE) is exact up to the liquid clamp.

4. Keeper interpolation. `Vk = (1 - w) Vin[jl] + w Vin[jl+1]` is exactly the value of a mean-preserving lottery over the two nodes, revealed before consumption is chosen. The distribution sends mass to node jl with the policies of node jl and to node jl + 1 with the policies of node jl + 1 (lines 270-283), so value, marginal value, policies and distribution describe the same object. `j0`, `om` at k = 0 give (1, 0), so households without illiquid wealth stay at node 1.

5. Envelope. d/db of theta log(exp(Vk/theta) + exp(Va/theta)) is (1 - pa) Vk' + pa Va', and d/db of the inclusive value is sum_j q_j Vj'; the derivative terms of the probabilities cancel, as for any log-sum. With d be / d b = 1, `Mbar = (1 - pa) Mk + pa sum_j q_j Mj` and `Vbn = R Mbar` are right. `Mk` uses the same weights as `Vk`.

6. Consumption price. Euler: Gamma c^-gamma / pc = beta E Vb (`egm_core.jl:83-84`); intratemporal: phi kappa T^psi = (w / pc) c^-gamma (line 87 and `egm_constrained`); budget with pc c (line 90); `muin` divided by pc (`egm2_core.jl:121`); MPC multiplied by pc (line 556). Consistent throughout the iteration.

7. Discounting. The solver and `two_asset_welfare_parts` both use beta (1 - death), and the welfare transition omits death, which is the same as a zero continuation value at death. The distribution applies (1 - death) to the image and adds `death * born[s]` at (b node 1, k node 1, s).

8. Newborns and mass. `born = vec(born' * Pi)` iterated 10,000 times is the stationary distribution of a row-stochastic Pi. Rows of the decision operator sum to one up to the adjusting branches below 1e-12 (at most nk 1e-12 per state), and the result is renormalised. The damped update has the same fixed point.

9. `two_asset_distribution` against `each_branch_full`. Same order; same keeper weights and `wt <= 0` skip; same 1e-12 threshold; same clamp of `be` at the top; same bracket `r`; same clamp of p1 to [0, 1]; same floor of effort at zero and of b' at the lowest node; same `p1 < 1` and `p1 > 0` guards. I found no discrepancy.

10. Hand-to-mouth. Liquid wealth at most ybar / 52 is half of a fortnight's income (Kaplan, Violante and Weidner 2014). Illiquid wealth is always on a node in the distribution, and node 1 is exactly zero and absorbing for keepers, so `m == 1` is the right test for "no illiquid wealth". Any positive holding counts as wealthy, as in the source; note that node 2 is 0.012, about 2% of annual income (see finding 3).

11. MPC and propensities. The windfall is ybar / 12 added as Delta / R to liquid wealth at unchanged k, with extrapolation at the top, matching `reporting_core.jl:83-88`.

12. Patience groups. `betas_of` returns `[beta_low, beta_bar]` with weights `[share, 1 - share]`, both nominal; `params_of` passes them as beta; the solver multiplies by (1 - death). The scripts write `BETA_LOW_EFF / SURV` = 0.8693 with SURV = 1 - 1/45, so effective patience is 0.85. The share at zero falls back to a single type continuously.

13. Transforms and SAGE_START. `unpack` divides x[1] by SURV; `report` prints nominal beta_bar; `read_start` multiplies the first entry by SURV and takes logs of chi0 and phi. Consistent with the log format since commit `db7292b`.

14. Jacobian and step in `calibrate_two_asset.jl`. Forward difference with the sign of h flipped at the upper bound and divided by the signed h; residuals scaled by the tolerances; `Delta[ACT] = -(J \ F)` with rows and columns both restricted to `ACT`; per-coordinate cap; backtracking on the sum of squares; fallback to the best evaluated point. Signs and indices are right. With chi0 borrowed, row 2 and column 2 drop together.

15. Checkpoint round trip. `vec(J)` and `reshape(..., 4, 4)` are both column-major. `string` of a Float64 round-trips exactly. In the S and E scripts the full 4 by 4 matrix is stored with zero columns for parameters not in `ACT`, and only `J[ACT, ACT]` is used.

16. E script, end to end. The E-off Jacobian is computed once, at the E-off point, on the national economy, with all four residual rows; it is applied to the E-on residuals restricted to `ACT`; `all(iszero, J)` distinguishes "not yet computed" correctly, including after a resume. `solve_economy_places` returns national `Ntot`, `median_income`, `wealthy_htm`, `hand_to_mouth_kvw` (population weights) and `mean_effort_employed` (employment weights), which is what `mom` reads. Exit codes 2 and 3 are as documented. The reservations are findings 5b, 7 and 10.

17. Convergence criterion on the normal path. `dist` is computed on the full Bellman step before relaxation is applied, so a relaxed iteration cannot pass the 1e-9 test on a shortened step. The reservation is the stall and maxit paths in finding 4.

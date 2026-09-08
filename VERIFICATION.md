# Verification ladder

Built 2026-06-10 after a numerical defect in the S+A core was found while writing a diagnostics appendix. The rule is simple: no level is trusted until the level below it passes, and no result is quoted from an untrusted level. Scripts are `SAGE_Bewley/scripts/verify_L0_engine.jl`, `verify_L1_core.jl`, `verify_L2_bias.jl`.

## Level 0: the engine

| check | result |
|---|---|
| mass at top asset node | 0.000e+00, PASS |
| stationary distribution sums to one | 1.000000000000, PASS |
| no negative mass | PASS |
| consumption nondecreasing in assets | PASS |
| savings rule nondecreasing, crosses 45 degrees | PASS |
| social fixed point converges | PASS |
| grid convergence: Q, mean effort, wealth Gini | PASS, drift under 0.005 from na=200 to na=400 |

Two findings that reach beyond the S+A paper.

**Hand-to-mouth is not grid-converged.** Across na = 100, 200, 300, 400 it reads 0.439, 0.334, 0.304, 0.298 and is still falling. The figure 0.33 quoted in the S paper and the QuantEcon lecture is the production-grid value; the converged value is nearer 0.30. This is inherent to measuring mass exactly at the borrowing constraint on a discrete grid. The qualitative claim ("about a third") survives; the two-digit number does not.

**The S paper's financed-subsidy magnitudes carry grid noise.** Consumption +4.33, +6.13, +5.50 percent and public good -5.16, -5.71, -4.41 percent at na = 100, 200, 300. The sign and the decoupling are robust at every grid; the magnitudes move by about a percentage point and non-monotonically. The paper and the lecture both quote +5.5 and -4.7 as if converged. They should be stated as roughly +5 to +6 against -4 to -6.

## Level 1: the participation core

| check | result |
|---|---|
| cell response, grid convergence in (na, ne) | PASS, differences ~0.008 between 200/40 and 400/80 |
| cell response monotone in the belonging scale | PASS |

Structural finding: the cell response is a two-step function, with a plateau at exactly one half, because the two income states flip at different thresholds. All of the aggregate map's smoothness therefore comes from the taste distribution, not from within-cell heterogeneity. This justifies the threshold abstraction the paper's proposition uses, and it sharpens the criticism that a two-state income process is coarse for this model.

## Level 2: the response-family reduction

**2.1 pointwise fidelity: FAIL.** Family interpolation against direct solves at off-grid points gives errors up to 0.110 (at u = 6.10: interpolated 0.890, direct 0.779). This is a method limitation rather than a grid-size issue: the response is a step function and linear interpolation across a jump errs by up to the jump height at any resolution. Refinement narrows where the error occurs, not how large it can be. The reduction must not be used to read off individual cell responses.

**2.2 quadrature convergence: PASS.** The taste integral converges, but slowly, because the integrand is a near-step. It needs roughly 2000 nodes; the paper used 15. At the calibrated point the rate moves 0.35431, 0.35348, 0.35303, 0.35278, 0.35264 across 500 to 8000 nodes.

**2.3 aggregate bias: PASS.** Rebuilding the families at spacings 0.4, 0.2, 0.1, 0.05 moves the equilibrium only within +/- 0.002 (0.35377, 0.35303, 0.35097, 0.35276) and the map slope within +/- 0.001 (0.618 throughout). Integration against the taste distribution cancels the pointwise error. So the reduction is accurate to about 0.2 percentage points in the aggregate, which is the number to quote as its precision.

Apportioning the original error: at fixed fine families, moving the quadrature from 15 to 2000 nodes shifts the rate by 0.013; fixing the family grid at fixed quadrature shifts it by 0.005. The quadrature was the larger culprit. The original setup (uniform spacing 1.5 over [0,60], 15 nodes) sat outside the safe region; a spacing of 3.0 gives a catastrophic 0.66.

## Level 3: calibration

Converged: kappa* = 10.75, sigma_m* = 0.750, aggregate participation 0.353, group rates 0.295 / 0.411, map slope 0.618. Stable across 500 to 4000 quadrature nodes (0.3543, 0.3535, 0.3530, 0.3528).

Honest caveat: the fit is worse than the paper claims. The aggregate matches (0.353 against roughly 0.35) but the education gradient is about forty percent too flat (0.117 against an observed 0.20). The paper's "tight fit" sentence was itself a quadrature artifact.

## Level 4: results

Everything downstream was computed on the old footing and is being recomputed. The proposition is unaffected, because its bound uses observed participation rates rather than model output, and it strengthens on the corrected calibration: sigma-bar 0.4695 against sigma* 0.750, a ratio of 1.60 where the paper claimed 1.10.

## Tier 1 additions (2026-06-10)

Three checks the ladder was missing, plus resolution of the two Level 0 findings. Script `SAGE_Bewley/scripts/verify_T1.jl` and `verify_T1b.jl`.

**T1.1 Euler-equation errors: PASS.** Mean log10 error -3.12, -3.34, -3.38 at na = 200, 300, 400, improving with refinement; maximum around -1.8, which is the usual borrowing-constraint kink. The household problem is solved accurately. This is the standard accuracy measure for the model class and it had never been run.

**T1.2 stationary distribution invariance: PASS.** Pushing lambda through the Young lottery once returns it to itself with a maximum residual of 9.4e-13. Previously we only checked that lambda summed to one, which any correctly shaped vector does.

**T1.3 hand-to-mouth: definition replaced.** The old `frac_constrained` summed the mass on the first asset grid node, so refining the grid shrank the measured set rather than resolving it; that is the whole explanation for the 0.44, 0.33, 0.30, 0.30 sequence. Replaced with wealth below a stated fraction of mean labour income, following what Kaplan, Violante and Weidner actually measure. A FOUR-WEEK threshold is the stable one, giving 0.3141 and 0.3169 at the two finest grids, converging to about 0.315. Wider thresholds are less stable, not more. Report 0.315 at a four-week threshold; the 0.33 quoted in the S paper and the QuantEcon lecture is the grid artifact.

**T1.4 effort grid: resolved, and it was the cause.** Every quantity that depends on effort inherits the effort grid's resolution, because the engine recovers next-assets continuously but takes effort from the discrete grid (re-optimising effort against the interpolated continuation value collapses to a corner under the behavioural social term, so the engine deliberately does not). Since Q = E[1-e], the cohesion side is noisier than the consumption side throughout, which is exactly the pattern observed. At fixed na = 200 the oscillation damps cleanly as ne rises: dC +6.12, +5.51, +5.71, +5.61 and dQ -5.71, -4.92, -5.28, -5.24 for ne = 40, 80, 160, 320, with amplitude roughly halving per doubling. Budget residuals are ~1e-6 throughout, so the fiscal fixed point is not implicated.

**Converged S-paper policy result.** At ne = 320: na = 200 gives +5.61 / -5.24, na = 300 gives +5.39 / -4.84, na = 400 gives +5.61 / -5.23. The na = 300 outlier is grid-alignment sensitivity rather than a trend, since 200 and 400 agree closely. Best estimate: consumption **+5.5 percent** (robust, matches the quoted figure) and public good **-5.1 percent** with about +/- 0.25 of alignment noise. The paper and the lecture quote -4.7, which is too small; the social cost is slightly LARGER than claimed, so the correction strengthens the paper's substantive point while invalidating its precision.

Required settings for effort-dependent quantities: ne = 320. The production ne = 40 is adequate for consumption aggregates and inadequate for anything built on Q.

## Level 4: the S+A results recomputed (2026-09-03)

Everything the S+A paper reports is now produced by one script, `SAGE_Bewley/scripts/sa_level4.jl`, from one family cache, so no two numbers in that paper can sit on different footings again. Settings: concentrated belonging grid (83 nodes, spacing 0.2 across the transition), 2000 taste quadrature nodes, kappa = 10.75, sigma_m = 0.750, omega = 0.30, na = 200, ne = 40. Log in `sa_level4.txt`, machine-readable scalars in `sa_level4_results.txt`, figures from `sa_figures_l4.jl`, cross-country in `sa_countries_l4.jl`.

**Participation is effort-grid insensitive, unlike the companion paper's Q.** This was the one thing that could have made Level 4 as expensive as Tier 1. It did not: doubling and redoubling the effort grid moves the calibrated equilibrium from 0.35303 to 0.35305 to 0.35307 and the group rates in the fifth decimal. Mean labour income, which does inherit the effort grid, moves by at most 0.3 percent, so the GDP column of the ledger carries that accuracy and nothing else does. The reason is structural: participation is a mass under a discrete choice, not an average of a finely graded object.

**What moved.** Baseline 0.371 -> 0.353; group rates 0.265/0.476 -> 0.295/0.411; sigma-bar 0.454 -> 0.469; ratio to sigma* 1.10 -> 1.60; numerical multiplicity frontier 0.41 -> 0.30; proposition slope 0.91 -> 0.626 against a numerical 0.81 -> 0.618; subsidy direct effect -8pp -> -4.3pp; subsidy equilibrium effect -29pp -> -10.6pp; amplification 3.6 -> 2.47; empowerment +14pp -> +2.5pp; Gift Aid credit 83.3 percent at 4.1 percent cost -> 66.1 percent at 3.2 percent; France credit 99.7 at 12.7 -> 95.2 at 12.1.

**Two conclusions reversed, and both were reported the wrong way round in the previous draft.**

1. *Take-up incidence.* The old finding, that the credit stays equalising at every take-up rate, was itself an artefact of the coarse footing, so the refutation of my original hypothesis was wrong and the hypothesis was right. On the corrected numbers the baseline high/low ratio is 1.40, full take-up compresses it to 1.19, half take-up is neutral at 1.43, and quarter take-up is DISEQUALISING at 1.60 (Gift Aid) and 1.72 (France). The aggregate sign is unaffected: the credit is expansionary at every take-up rate.

2. *The GDP-B ledger.* The model's own shadow price of the fabric is 0.1447, which is 33 percent of baseline GDP for a fully participating society. The breakeven price at which the work subsidy's material gain exactly offsets its loss of fabric is 0.2158, which is 50 percent of GDP. The model price is BELOW its own breakeven, so at the model's own valuation the work subsidy RAISES GDP-B by 1.5 percent. The old claim that it lowers GDP-B by 2.2 percent does not survive. What survives, and does not depend on the price at all, is the RANKING: on GDP the subsidy beats the credit (+5.2 against -3.9), on GDP-B the credit beats the subsidy (+5.6 against +1.5). The paper now reports the breakeven and hands the sign question to the WELLBY valuation literature.

**A new analytical link, found in the course of the recomputation.** The equilibrium multiplier on any small policy shift is 1/(1 - G'(r*)), and G'(r*) is exactly the object the proposition bounds. At the corrected slope 0.618 that predicts 2.62 against the 2.47 measured on a ten-point move, the gap being map curvature. So the theorem that rules out coordination traps also caps the amplification factor, and the paper's two halves are one statement rather than two. This was not visible at the old numbers, where 1/(1-0.81) = 5.3 against a reported 3.6, an inconsistency nobody had checked.

**The gradient shortfall is now stated rather than hidden.** The model's group gap is 11.7 points against an observed 20, about forty percent too flat, and no pair in the searched range closes it while keeping the aggregate. Its direction favours caution: the bound is largest when rates sit at one half, so evaluating at the model's rates (0.469) is conservative relative to evaluating at the observed ones (0.458).

## Stage 5: the participation level, and why it would not converge (2026-09-06 to 09-08)

The Level 4 audit left one quantity unconverged: the participation rate itself moved by about two points across asset grids while every slope-based quantity was stable to under one percent. Fixing it took three steps, each of which was a real fault, and the third was structural. Scripts: `audit_theta.jl`, `audit_theta2.jl`, `wise_participation_logit.jl`; probes `naconv2.txt`, `ordtest.txt`, `pexptest.txt`.

**Fault 1: next-assets off the grid.** The engine's `solve_model` golden-sections next-assets against an interpolated continuation value and builds the distribution with the Young lottery. The participation core never did either; savings sat on grid points and the wealth distribution carried a sawtooth. Ported. Cut the na-spread of the level from 0.020 to 0.0065.

**Fault 2: a mis-scaled asset grid, and this one is the origin of most of the project's trouble.** `a_max` was 100 while mean labour income is 0.40 and the wealth distribution ends near 2. So 97 percent of the 200 nodes were empty and the entire distribution sat on SIX of them, 44 percent of it on node one. The participation threshold, at about three months of income, fell among those six. That is why each cell's response to the belonging payoff was a near-step with five distinct levels, why the taste quadrature needed 2000 nodes, and why the reduction layer was so fragile. The engine has the same grid and the same problem, less severely (fifteen nodes carry its distribution), which is a note for the S paper. Rescaled to a_max 4, pexp 3, with the top of the grid verified slack: 75 effective nodes.

**Fault 3, structural: mass above a cutoff on an atom.** Even so, the level would not settle: 0.334, 0.315, 0.339 at na = 200, 400, 800, while the gap, slope, bound and multiplier converged to 0.6 percent or better. The participation decision is a wealth threshold, the threshold sits just above the atom at the borrowing constraint (43 percent of households in the cell, 33 in the engine, normal for beta R < 1), and the aggregate is whatever mass lies between the atom and the cutoff. No grid resolves that; concentrating the grid harder (pexp 2.5 to 4) reduced the na-error but different concentrations gave answers 0.011 apart. The consequence for per-country use was fatal: across na the country ordering changed, Germany moving 0.028 while the OECD spread is 0.03. An attempt to fix it by bisecting the cutoff and interpolating the CDF was unsound (non-monotone in the belonging payoff) and was removed.

**The fix: the Brock and Durlauf (2001) form of the same model.** An i.i.d. type-1 extreme-value shock of scale theta on the participation payoff, on top of the persistent lognormal taste. The choice becomes a logit probability, the aggregate an integral of a smooth function over the wealth distribution, and theta -> 0 recovers the hard threshold, so the proposition (stated for the hard-threshold model) is its limit and is untouched. `solve_participation_logit` in `proto_participation_core.jl`, warm-started from the hard-max DiscreteDP.

| theta | r* na200 | r* na400 | na-error | slope | quadrature nodes for 0.002 |
|---|---|---|---|---|---|
| 0.10 | 0.4606 | 0.4609 | 0.00025 | 0.488 | |
| 0.05 | 0.4035 | 0.4038 | 0.00022 | 0.573 | |
| 0.02 | 0.3706 | 0.3707 | 0.00012 | 0.607 | 500 |
| **0.01** | **0.3645** | **0.3646** | **0.00009** | **0.614** | **500** |
| 0.005 | 0.3614 | 0.3617 | 0.00031 | 0.615 | 500 |
| 0.0025 | 0.3609 | 0.3614 | 0.00053 | 0.616 | |

Reading it: the level converges in theta (increments 0.057, 0.033, 0.006, 0.003, 0.0005) to about 0.360 and the slope to 0.616, which matches the hard-threshold slope that was always stable. The na-error bottoms at theta = 0.01 and climbs back below it as the regulariser weakens. So theta = 0.01 is the working value: the smallest before the grid reasserts itself, within 0.004 of the limit on the level, and a two-hundredfold improvement in na-convergence over the hard threshold. The quadrature requirement falls from 2000 to 500.

**Consequence for per-country use.** Country levels are now resolved to 0.0003 (shifts across na: FR +0.0001, DE +0.0002, IT 0.0000, US +0.0003, ZA -0.0002) and the OECD ordering ZA < FR < IT < US < DE is preserved. Germany and the US differ by 0.0007, about twice the noise, so that pair remains marginal; every other pair is clear.

**The WISE Solidarity comparison, restored.** On the hard threshold this had to be retracted because the ordering was inside the noise. On the logit core: participation vs WISE Solidarity +0.94, +0.49, +0.46 (all six, 2007/2017/2018) and +0.80, +1.00, +0.95 (OECD four), beating both calibrated inputs alone in every cell. Six countries, so suggestive; but now it is a real ordering being compared.

**What this changes upstream.** All S+A numbers are being recomputed on this core (stage 5, `cache_l5`). The S paper's engine shares the mis-scaled grid; its slope-based results were shown stable but its wealth-distribution statements should be rechecked on a rescaled grid before the next revision.

## Stage 5 results: what the corrected core changed (2026-09-08)

Every S+A scalar recomputed on the logit core (theta 0.01, a_max 4, pexp 3, `cache_l5`), against the hard-threshold stage 4 snapshot. Full table in `scripts/compare_stage4_stage5.txt`.

The participation levels all rise by about one point (baseline 0.353 to 0.364, groups 0.295/0.411 to 0.304/0.425) as the level moves to its converged value. Every conclusion is unchanged to within a percent: ratio 1.598 to 1.604, multiplier 2.474 to 2.465, slope 0.618 to 0.614, bound 0.470 to 0.468, gap 0.117 to 0.121, take-up ratios 1.19/1.43/1.60 to 1.19/1.42/1.56. The largest relative move is GDP-B under the work subsidy, +1.5 to +2.0 percent, a half-point in absolute terms with the sign and the ranking intact; the breakeven price moves from 50 to 54 percent of GDP against a model price of 33. Countries: subsidy down 7 of 7, credit up 7 of 7, levels up about 0.01 uniformly.

This is the end of the reversal record. A change to the solver's core structure, made for a structural reason, moved levels by one point and flipped nothing.

**The S paper survives the grid finding** (`scripts/verify_S_grid.jl`). On the rescaled grid the engine's effective resolution goes from 15 nodes to 155 (na 200) and 307 (na 400), and: Q 0.475 to 0.470, wealth Gini 0.549 to 0.544 to 0.549, hand-to-mouth 0.329 to 0.314 to 0.316, consumption response +5.61 to +5.58 to +5.64, public-good response -5.15 to -5.06 to -5.07. The decoupling result is now converged to two decimals at -5.1 rather than the -5.2 the paper quotes with a stated quarter-point band; that quarter point was the old grid. The paper's text needs 5.2 to become 5.1 and the engine default a_max/pexp should move to the rescaled values, which also corrects the live lecture at rebuild.

**The rescaled grid is France-specific, not global** (`scripts/verify_S_slack.txt`, 2026-09-08). At a_max = 5 the four OECD engine rows are slack (top-of-grid mass zero; maximum wealth 1.9 to 3.9), but Colombia, South Africa and China put 27 to 30 percent of their mass on the top node. That is not the beta-R knife edge: at the published a_max = 100 their top mass is zero and they are better resolved than France (64 effective nodes against 15), because those rows carry R = 1.03 and an effort disutility of 3.7 to 5.5 against France's 14.4, so their households hold about nineteen years of income rather than two. Consequences: (i) the engine default cannot be a_max = 5; the safe global change is pexp = 3 at a_max = 100, tested in `verify_S_pexp.txt`; (ii) the S+A participation cells are slack on the stage-5 grid for every country alpha, because the cells hold R and phi at the French values by design, so the stage-5 countries table stands; (iii) any future per-country engine work needs a_max set per row, which is a one-line addition to `country_params`.

**Engine default moved to pexp = 4 at a_max = 100** (`scripts/verify_S_pexp.txt`, 2026-09-08). France goes from 15 effective nodes to 75 (na 200) and 148 (na 400); Q, hand-to-mouth, and the decoupling response are converged in na to two decimals (dC +5.64/+5.64, dQ -5.08/-5.07) and match the France-only grid (a_max 5, pexp 3) to within 0.05 of a point. The full range is kept, so the three developing rows, which need about a_max 25, are unaffected. Both engine copies (repo `src/SAGEBewley.jl` and the lecture's `sage_engine.jl`) carry the change, `cell_params` follows it, and the lecture now builds from `country_params("FR")` rather than `SAGEParams()` so that it, the S paper and the engine share one calibration (phi 14.44, not the 14.0 default). Every script that does not pass a grid explicitly now produces slightly different, better-resolved numbers on rerun; that is intended.

**Stage 5 requires recalibration, and it moves the verdict back** (2026-09-08, `scripts/sa_omega_l4.txt` on the logit core; fine search in `sa_recalibrate_l5.jl` pending). The stage-5 Level 4 run held (kappa, sigma_m) fixed at the stage-4 values (10.75, 0.750). Recalibrating on the logit core at omega = 0.30 with the full protocol (`sa_recalibrate_l5.txt`) lands at (9.95, 0.490): group rates 0.254 / 0.429 against targets 0.25 / 0.45, root moment loss 0.021 against 0.060 at the stage-4 point on the same core, converged in taste nodes. At that point the map slope is 0.909, the multiplier 11, and the ratio sigma*/sigma-bar is 1.058. The loss surface is a valley running from (10.0, 0.50) to (11.5, 0.90) with the floor at its low-dispersion end and the stage-4 point on its flank; two moments identify that curve, not a point, and the verdict's margin varies along it (`sa_valley.txt`). The map is steep at the new point, so theta = 0.01 is no longer in the limit there (0.018 off on the level); the working theta becomes 0.005 and the recalibration is being redone on families built at that value (`sa_recalibrate_l5b.jl`). This is the original paper's calibration and verdict. The stage-4 move to (10.75, 0.750), and the "strengthening" of the discipline result from 1.10 to 1.60, was an artefact of the hard-threshold response: a five-level step cannot fit a 20-point gradient at low dispersion, so the calibration was pushed to high dispersion where the map is flat. The logit smooths the step, the low-dispersion region fits again, and the verdict returns to marginal. At omega = 0.15 the ratio is 1.015, at the boundary; at 0.50 it is 1.63 with an almost exact fit. Consequences: every stage-5 S+A number computed at (10.75, 0.750) is at the wrong point and must be recomputed at the recalibrated one; the multiplier at the central calibration is nearer 8 than 2.5; and the paper's staged edits were not applied. The rule that nothing is written until the parameter it is most sensitive to has been swept is what caught this.

**Final calibration on the logit core: (kappa, sigma_m, theta) = (10.00, 0.495, 0.005)** (`scripts/sa_recalibrate_l5b.txt`, 2026-09-08). Recalibrated on families built at theta = 0.005 and again at 0.0025: the point is identical on both, so it no longer moves with theta. At it: aggregate rate 0.354, group rates 0.267 / 0.441 against 0.25 / 0.45 (root loss 0.019, against 0.060 at the stage-4 point on the same core), map slope 0.903, multiplier 10.3, sigma-bar 0.462, ratio 1.071, one stable equilibrium. Halving theta to 0.0025 moves the level by 0.004 and the slope by 0.002; doubling na moves the level by 0.002. Every stage-5 S+A quantity is being recomputed at this point in a theta-keyed cache. The June paper's (10.0, 0.50) and its ratio of 1.10 were, to within the numerics of the time, right.

**The moments identify a curve, and the bound is constant along it** (`scripts/sa_valley_theta0.0100.txt`; rerun at theta 0.005 in `sa_valley.txt`). Tracing the floor of the moment fit, best kappa at each sigma_m, from sigma_m = 0.45 to 1.00: root loss rises monotonically from 0.029 at sigma_m = 0.50 to 0.078 at 1.00, so the valley has a definite bottom at low dispersion and the stage-4 point (0.75, loss 0.057) sits on its flank with twice the minimum loss. Along the whole floor sigma-bar moves only from 0.460 to 0.472, exactly as the proposition says it must, since it depends on the group rates and the moments pin those. What the moments do not pin is sigma_m itself, so the ratio runs 1.09, 1.18, 1.29, 1.39, 1.49, 1.60, 1.70, 1.81, 1.91, 2.01, 2.12 and the multiplier 8.9, 5.5, 4.1, 3.4, 2.9, 2.6, 2.4, 2.2, 2.1, 2.0, 1.9. At sigma_m = 0.45 the ratio dips to 0.977, inside the region, but with the worst fit on the floor (0.089). Reading: the verdict (outside the coordination region) holds at every calibration with a defensible fit; the margin is not identified by two participation moments and should be reported as a range with the best-fit value first; and the policy multiplier, which is the same slope read the other way, inherits that range. This is why the number has read 1.10, 1.60 and 1.07 across versions: each was a different point on one curve.

**WISE Solidarity at the final calibration** (`scripts/wise_participation_logit.txt`, theta 0.005, (10.00, 0.495)). Spearman of model participation against the WISE Solidarity Index: +0.94, +0.49, +0.46 across all six countries in 2007, 2017, 2018, and +0.80, +1.00, +0.95 across the OECD four, beating both calibrated inputs alone in every cell. Country levels ZA 0.086, CN 0.129, CO 0.153, FR 0.354, IT 0.431, US 0.452, DE 0.462: every adjacent gap at least 0.02 against a grid noise near 0.002, so the ordering is resolved. The steep map at this calibration amplifies the agency and belonging input differences about tenfold, which is what separates the countries; it also means the cross-country levels are an untargeted prediction sensitive to those inputs, and should be presented as a prediction rather than a fit.

## Stage 5b: the full run at the final calibration, and what it says about June (2026-09-08)

`sa_level4.txt` at (10.00, 0.495, theta 0.005). Baseline 0.354, groups 0.267 / 0.441, gradient 0.175 against 0.200. Slope 0.903 (proposition 0.934), sigma-bar 0.462, ratio 1.071, numerical frontier 0.41. Decomposition 34 / 67. Financed subsidy: direct -6.0, equilibrium -25.2 (0.354 to 0.102), amplification 4.2, income +7.0. Empowerment +12.9 (to 0.483). Gift Aid 0.863 at 4.2 percent of income, France 0.996 at 12.7. Take-up ratios 1.13 / 1.33 / 1.49 (Gift Aid) and 1.01 / 1.15 / 1.40 (France) against a baseline 1.65: the credit is EQUALISING at every take-up rate. GDP-B: the subsidy LOWERS it by 1.2 percent, breakeven 28 percent of GDP against a model price of 33. Countries 7 of 7 both signs, with the subsidy taking every country to about 0.10 and the credit to about 0.87, so both instruments are near saturation at this calibration.

Every one of these is the June paper's qualitative claim. Every stage-4 "reversal" (equalising to disequalising, GDP-B sign, amplification 3.6 to 2.5, empowerment 14 to 2.5) reverses back. Stage 4 was the wrong point on the valley, reached because the hard-threshold step response could not fit at low dispersion, and its reversals were consequences of being there, not findings.

**Not written up yet, because section I caught one more thing.** At this steep point the effort grid matters: the level is 0.354 at ne = 40 and 0.368 at ne = 80 and 160. At the flat stage-4 point ne moved the fifth decimal; here the multiplier of ten turns a 0.0014 family error into 0.014. The production ne for the participation core must rise, the calibration redone on the converged families, and the run repeated. `audit_ne_l5.jl` sweeps ne = 40 to 320 with the slope first, since two finer values agreeing to five decimals wants confirming before an hour of compute is spent on it.

**Effort grid at the final point: ne = 80** (`scripts/audit_ne_l5.txt`). Sweeping ne = 40, 60, 80, 120, 160, 240, 320 at (10.00, 0.495, theta 0.005): the level is 0.354, 0.366, 0.368, 0.369, 0.368, 0.369, 0.368 and the slope 0.9026, 0.8991, 0.8983, 0.8982, 0.8983, 0.8983, 0.8983. From 80 onward the slope is converged to four decimals and the level sits in a band of 0.0006, which at a multiplier near ten is a family error of 6e-5, the floor set by the taste quadrature and the asset grid. Production ne for the participation core is therefore 80; the value of 40 that was fifth-decimal at the flat stage-4 point is off by 0.014 here. The calibration is being redone on ne = 80 families and the full chain rerun.

## Safe operating region

Family spacing 0.2 or finer over the transition, at least 2000 taste quadrature nodes, na = 200 and ne = 40 for the household solve. Aggregate participation is then accurate to about 0.002. Do not quote cell-level responses from the reduction.

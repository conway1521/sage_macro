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

## Safe operating region

Family spacing 0.2 or finer over the transition, at least 2000 taste quadrature nodes, na = 200 and ne = 40 for the household solve. Aggregate participation is then accurate to about 0.002. Do not quote cell-level responses from the reduction.

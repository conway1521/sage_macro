# Audit 1: the one-asset household problem

## Summary

- WRONG RESULTS: 3 findings, all small in size (asset grid top binds at France's calibration; belonging part of welfare is non-zero with S off; top income state falls off YGRID).
- FRAGILE: 7 findings (employment mask read from the sign of the transfer; NaN and silent non-convergence; switches silently ignored by two solvers; negative time floor; time-propensity adding-up; carbon-tax recycling one step behind; hard-coded R).
- COSMETIC: 1 observation (logit noise dominates the participation choice of the unemployed).
- The core of the EGM solver (budget, Euler equation with pc, intratemporal condition, envelope, discounting, expectation orientation, logit mixing, lottery, UI budget, McQueen-Porteus stop) was derived line by line and found correct.
- One Julia run was used (France G+S+A calibration, both cells, belonging scale 0 and 6, EGM). Everything marked "measured" comes from it; everything else is from reading and derivation.

The budget constraint, written once from the code and used as the yardstick below:

    pc * c + a' = R * a + w * e + other,     a' >= a[1]
    w     = (1 + subsidy) * alpha[s] * z[s] * Z
    other = -lumptax + transfer[s] + d * (partcredit * alpha[s] * z[s] * Z * QBAR - pcost)
    T     = time_floor[s] + (1 + commute) * e + QBAR * d  <= 1
    flow  = Gamma * (c^(1-gamma)/(1-gamma) - phi * T^(1+psi)/(1+psi)) + belong[s] * d - D_s(a')

---

## Findings

### 1. The asset grid top (a_max = 4.0) binds at the current France calibration, and the EGM policy leaves the grid

- Location: `SAGE_Bewley/scripts/egm_core.jl:110-121` (monotone branch, `ap` never capped at `a[end]`), `egm_core.jl:153` (non-monotone branch caps `ap` but keeps the extrapolated `c`), `egm_core.jl:288-289` (lottery clamps to the top node), `SAGE_Bewley/scripts/sage_modular.jl:213` (`a_max = 4.0`).
- Severity: WRONG RESULTS (small, top tail only). FRAGILE in general.
- Confidence: CONFIRMED numerically for `country_config("FR"; S = true, A = true)`.
- What the code does. Above the last endogenous point the monotone branch extrapolates the last segment (t > 1), so `apd` can exceed `a[end]`. The value uses `interp_lin`, which holds EV flat beyond the top, and `egm_distribution` clamps the lottery weight, so all of that mass is put on node `na`. The household's consumption is the one consistent with saving `a_d > a_max`, while its assets next period are reset to `a_max`: the difference disappears from the economy.
- Measured (theta 0.005, na 200, nz 11, beta 0.9642, phi 6.15):
  - low-education cell: 0.65 percent of the cell's mass on the top node at belonging scale 0, 0.47 percent at scale 6; largest `a_d` 4.44 to 4.58.
  - high-education cell: 1.85 percent on the top node at scale 0, 1.19 percent at scale 6; largest `a_d` 4.75 to 4.82; mass whose chosen `a'` exceeds `a_max` is 1.6 to 1.8 percent.
- Consequence. The stationary wealth distribution is truncated at 4.0 rather than ending inside the grid. Bottom statistics (hand-to-mouth, asset poverty) are barely touched. Top-tail statistics (`Wtot` above about the 98th percentile, mean wealth, `Ktot`/`Ntot` analogues, any wealth Gini) and mean saving (`mps`, `abar`) are biased down, and roughly 0.3 to 0.7 percent of the high cell's yearly resources leak. The note in memory that the distribution "ends near 2" no longer holds after the alpha normalisation (alpha_high 1.27) and the lower phi.
- A by-construction disagreement with the grid solver follows: the reference restricts `a' <= a[end]`, the EGM does not, so the two cannot agree on the top nodes.
- Smallest fix: raise `a_max` (8 would be a first try, then confirm top-node mass below 1e-4), and add a check after `egm_distribution` that warns when `sum(lambda[na, :])` exceeds a tolerance. Optionally cap `ap` at `a[end]` and recompute `c` from the budget so that the plan and the lottery agree.

### 2. Employment status is inferred from the sign of the transfer

- Location: `SAGE_Bewley/scripts/sage_modular.jl:295` (`emp = ps[1].transfer .== 0`), `:355` and `:587` (`.transfer .<= 0`).
- Severity: FRAGILE (WRONG RESULTS as soon as `rr = 0`, or `levy_employed < 0`).
- Confidence: CONFIRMED BY DERIVATION.
- What the code does. `cell_params_u` sets the benefit to `rr * alpha * z_latent * Z * E_REF` in unemployed states and zero in employed ones, and three places then recover "employed" as "transfer is zero (or non-positive)". With `rr = 0` every transfer is zero, so every state is classed as employed.
- Scenario. A "no unemployment insurance" counterfactual (`rr = 0`) with unemployment on. `cell_summary` still accumulates `eff_E` over the true employed states (`zz > 0`, `unemployment_core.jl:186`), but `_solve` divides by `mass[emp]`, now the whole population. `mean_effort_employed` is then understated by the unemployment rate (about 4 to 8 percent), which is exactly the bug fixed on 2026-09-30. In addition `unemployment` reports 0, `rate_U` reports 0, `rate_E`, `consumption_drop`, `A_cond`, `dread_cost_E` and `welfare.status` are computed over the wrong sets, `search_time` and `belong_u` are applied to nobody, and `impose_unemployed_ratio` does nothing. A negative `levy_employed` (a payment to the employed) flips the mask at line 587 the other way.
- No script in `scripts/` currently sets `rr = 0` (grep), so nothing reported so far is affected.
- Smallest fix: define the mask once from the process, `emp = p.z_vals_override .> 0`, and use it in all three places.

### 3. With S off, the belonging part of welfare is computed at social_strength = 1

- Location: `SAGE_Bewley/scripts/sage_modular.jl:565-568` and `SAGE_Bewley/scripts/reporting_core.jl:50, 62`.
- Severity: WRONG RESULTS (small; decomposition only, total welfare unaffected).
- Confidence: CONFIRMED numerically.
- What the code does. In the S-off branch the household problem is solved with `update(job[2]; social_strength = 0.0)`, but the summaries receive the original `job[2]`, whose `social_strength` is the `SAGEParams` default 1.0. `welfare_parts` then prices every participation at `bel = 1.0 * Lambda * B * QBAR = 0.0876`, a payoff the household never received.
- Measured (France, scale 0): `Vb` per head is 0.0758 in the low cell and 0.0534 in the high cell where it should be exactly zero (against `Vc` of -52.9 and -39.0). It is fed almost entirely by the unemployed, who participate with probability 0.40 at zero payoff (finding 11).
- Consequence. In `welfare_ce` for G and G+A economies, `parts.belonging` is non-zero and `parts.choice_and_rest` carries the offsetting error. Only differences between two economies enter, so the size is of order 1e-4 in consumption-equivalent terms whenever unemployment or unemployed participation moves. `total`, `cells` and `status` use `sol.V` and are right.
- Smallest fix: build `pz = update(job[2]; social_strength = 0.0)` once and pass `pz` to the solver, `cell_summary` and `agency_summary`.

### 4. An infeasible state produces NaN that spreads silently, and neither solver reports reaching maxit

- Location: `SAGE_Bewley/scripts/egm_core.jl:230-233` and `:222-259`, `SAGE_Bewley/scripts/proto_participation_core.jl:375-376` and `:359-382`.
- Severity: FRAGILE.
- Confidence: CONFIRMED BY DERIVATION (not triggered in the measured run: `any(isnan, V)` false).
- What the code does. The log-sum is `m + theta * log(exp((b0 - m)/theta) + exp((b1 - m)/theta))` with `m = max(b0, b1)`. A single `-Inf` branch is handled correctly. If both branches are `-Inf`, `b0 - m` is `-Inf - (-Inf) = NaN`, `Vn` is NaN, and `mul!(EV, V, Pi')` spreads it to every state. `dist` is then NaN, `dist < tol` is false, the loop runs to `maxit = 5000`, and the function returns NaN policies with no message. Separately, nothing anywhere reads `iters` for the one-asset solvers (grep), so a run that stops at `maxit` for any reason is indistinguishable from a converged one.
- Scenario. An unemployed state at the lowest node with `transfer[s] - lumptax + (R - 1) * a[1] <= 0`: for instance `rr = 0` together with any positive lump-sum tax, or a levy/lump tax larger than the benefit. With `w = 0`, `egm_constrained` returns NaN for both d, and no endogenous point can cover the node.
- Smallest fix: `Vn[i] = m == -Inf ? -Inf : ...` plus an explicit `error` when any state has no feasible choice, and a warning (or a `converged` field) when `iters == maxit`.

### 5. Switches that two solvers ignore without refusing

- Location: `SAGE_Bewley/src/SAGEBewley.jl:451-458` (`solve_model`), `SAGE_Bewley/scripts/proto_participation_core.jl:57` (`solve_participation`, the hard-threshold reference).
- Severity: FRAGILE.
- Confidence: CONFIRMED BY DERIVATION.
- What the code does. `solve_model` refuses `transfer`, `pcost`, `belong_scale` and `time_floor`, but accepts and ignores `pc`, `commute`, `dread`, `partcredit`, `illiquid` and `solver`. `solve_participation` ignores `pc` and `commute` (its budget is `c = R a + w e - lumptax - a' + credit d + tr` and `T = tfl + e + QBAR d`), whereas `solve_participation_logit` refuses both for the grid solver (`:304-305`). A parameter set built by `params_of` with `ctax` or `commute` and passed to either function returns the economy without the tax or the commute.
- Smallest fix: add the same two `error` lines to `solve_participation`, and `p.pc == 1 && p.commute == 0 && p.dread == 0 || error(...)` to `solve_model`.

### 6. time_bonus is implemented as a negative time floor, so total time can be negative

- Location: `SAGE_Bewley/scripts/sage_modular.jl:313`, used in `egm_core.jl:45`, `:59`, `:100`, `:119`, and `reporting_core.jl:59-61`.
- Severity: FRAGILE.
- Confidence: CONFIRMED BY DERIVATION.
- What the code does. `tf = (employed ? 0 : search_time) - time_bonus`, so with `search_time = 0` the floor is `-h`. For an unemployed household not participating, `T = -h < 0`. With the default `psi = 2.0` the disutility term `phi * T^3 / 3` is then a small utility gain (about `phi * 1e-6 / 3` at h = 0.01), and the cost of participating is `((QBAR - h)^3 + h^3)` instead of `(QBAR - h)^3`, an error near 1e-6 that is harmless. With a non-integer `psi` (the config has a `psi` field and `probe_mpc_psi.jl` varies it) `T^(1 + psi)` raises a `DomainError`. In `egm_constrained` the gap `g(e)` is no longer monotone on the stretch where `T < 0`, which the bisection assumes, though that stretch (`e < h`) is not reached at calibrated parameters.
- Smallest fix: model the bonus as a larger endowment (`tmax = (1 + h - tfl - QBAR d)/kappa` with `T` unchanged), or evaluate disutility at `max(T, 0)`.

### 7. The top income state falls off YGRID

- Location: `SAGE_Bewley/scripts/agency_core.jl:67` (`YGRID = 0:0.002:1.5`), `SAGE_Bewley/scripts/unemployment_core.jl:195-199`.
- Severity: WRONG RESULTS (very small now), FRAGILE.
- Confidence: CONFIRMED numerically.
- What the code does. Income above 1.5 is dropped from `Y`, `Ys` and `ypoor` (`k <= length(YGRID)`), while `ymean` and the joint indicators still count it. The comment says mean labour income is near 0.44, which predates the alpha normalisation.
- Measured: France high-education cell loses 9.33e-4 of its mass (the top Rouwenhorst state, 0.5^10), the low cell loses nothing. `median_model` and `asset_poverty_by_quantile` (which normalises by `Y[end]`) are therefore computed on 99.97 percent of the population. The anchored poverty line does not use `Y`, so headline hardship is untouched. A country with higher alpha_high, eta or effort would lose the second state too (about 1 percent of the cell).
- Smallest fix: extend YGRID to 3.0, or put overflow mass in the last bin.

### 8. time_propensities mixes populations and ignores commuting

- Location: `SAGE_Bewley/scripts/sage_modular.jl:1069-1073`.
- Severity: FRAGILE (a sibling of the `mean_effort_employed` bug).
- Confidence: CONFIRMED BY DERIVATION.
- What the code does. `leisure_employed = 1 - work - part`, where `work` is the change in effort per employed household and `part = QBAR * (rP.rate - rB.rate) / h` uses the participation rate of everyone, unemployed included (and after the `unemployed_ratio` rule). The docstring claims the three add to one for the employed, which requires `rate_E`. `kappa = 1.0` is assigned and never used, so with `commute != 0` work time is `(1 + commute) * e` and the identity fails again.
- Size: the gap is `QBAR * (d rate - d rate_E) / h`, zero only when the two rates move together.
- Smallest fix: use `rate_E` and multiply `work` by the share-weighted `1 + commute`.

### 9. carbon_tax_economy returns an economy one step behind its reported recycling

- Location: `SAGE_Bewley/scripts/sage_modular.jl:1046-1052`.
- Severity: FRAGILE.
- Confidence: LIKELY (size not measured).
- What the code does. Each pass solves with the previous `rev` and then sets `rev = rev_new`. If the tolerance 1e-7 is not met within `iters = 4`, the returned economy was solved with the third revenue figure while `recycled` reports the fourth, and nothing says so. The government budget is then out of balance by the last step.
- Smallest fix: return the `rev` the economy was solved with, and the residual `t * r.consumption - rev` beside it.

### 10. hardship_at hard-codes R

- Location: `SAGE_Bewley/scripts/unemployment_core.jl:252` (`R = 1.02` keyword, used in `astar = (ypov - (transfer - lumptax)) / (R - 1)`).
- Severity: FRAGILE (legacy path, used by `sa_stage6.jl` and `sa_stage7.jl` only).
- Confidence: CONFIRMED BY DERIVATION.
- Correct while `SAGEParams.R` stays at its default, wrong for any other rate. Fix: take `R` from the pooled object.

### 11. Observation: at theta = 0.005 the participation choice of the unemployed is mostly noise

- Location: `SAGE_Bewley/scripts/egm_core.jl:232-233`, `sage_modular.jl:215`.
- Severity: COSMETIC under the country configurations (which all set `unemployed_ratio`), FRAGILE where the rule is `nothing`.
- Confidence: CONFIRMED numerically.
- The time cost of participating for a household with `T = 0` is `phi * QBAR^3 / 3 = 0.00205` at France's phi 6.15, less than theta. With zero belonging payoff the logit gives `1 / (1 + exp(0.41)) = 0.399`, and the run returns exactly 0.3989 for the unemployed against 0.0002 to 0.0041 for the employed. So theta is not a pure regulariser for non-working households, and a G or G+A economy reports a participation rate of 2 to 3 percent with no social payoff. Policies are unaffected (the option value is constant in assets), and the rule overwrites the rate, so only finding 3 is a consequence.

---

## Checked and found correct

1. Budget constraint, every use.
   - EGM inversion: `aend = (pc c + a[k] - w e - other) / R` (`egm_core.jl:90`). Matches.
   - Constrained region: `cash0 = R a[i] - a[1] + other`, `c = (cash0 + w e) / pc` (`egm_core.jl:197`, `:35-55`). Matches.
   - Reference grid solver: `c = R a + (1 + subsidy) alpha e z Z - lumptax - a' + credit d + tr` (`proto_participation_core.jl:87`, `:282`, `:404`), the same with pc = 1 and commute = 0, both of which it refuses otherwise.
   - Engine `solve_model`: `c = R a + (1 + subsidy) alpha e z Z - lumptax - a'` (`SAGEBewley.jl:537`, `:578`). Same timing.
   - Consumption in summaries: `agency_shock.jl:67` and `reporting_core.jl:58` divide the same expression by pc; `credit` there is `net_participation`, so pcost is included.
   - Disposable income in `cell_summary` (`unemployment_core.jl:190-191`): labour income plus `(R - 1) a` less lumptax plus credit plus transfer. Interest is on beginning-of-period assets everywhere (`R a` in the budget, `(R - 1) a` in income, `Delta / R` in the MPC, `R a'` in dread). pcost is left out of income by design.
   - Linear interpolation between endogenous points preserves the budget, because the budget is linear in (c, e, a', a) and all three are interpolated with the same weight.

2. First-order conditions.
   - Euler: maximising flow + beta EV(a') gives `Gamma c^-gamma / pc = beta E V_a - D'(a')`. Code: `m = beta EVa - Dp`, `c = (pc m / Gamma)^(-1/gamma)` (`egm_core.jl:83-84`). Matches.
   - Dread derivative: `D' = Gamma dread q R (xh^-gamma - xl^-gamma)` (`:190`), the derivative of `dread_at`, with the same 1e-4 floor. `dread_q` holds q(1 - q) (`sage_modular.jl:338`), as the docstring says.
   - Intratemporal: `(w / pc) c^-gamma = phi kappa T^psi`, so `T = (w c^-gamma / (phi kappa pc))^(1/psi)`, `e = (T - tfl - QBAR d) / kappa` clamped to `[0, tmax]`, `tmax = (1 - tfl - QBAR d) / kappa` (`:87-88`). Matches, Gamma cancels.
   - Constrained region: `g(e) = phi kappa T^psi - (w / pc) ((cash0 + w e) / pc)^-gamma`, increasing in e for T >= 0, corners handled at `e_lo` and `tmax` (`:45-47`). Matches.
   - Envelope: `Va = R Gamma ((1 - P1) c0^-gamma + P1 c1^-gamma) / pc` (`:236`). Correct, including at constrained points and with dread (D depends on a' only).

3. Discounting and expectations.
   - beta enters once: `m = beta EVa` and `v = flow + beta EV`; `Va` carries R and no beta. `death` is not used by the one-asset solver.
   - `mul!(EV, V, Pi')` gives `EV[k, s] = sum_s' V[k, s'] Pi[s, s']` (`egm_core.jl:223`, `proto_participation_core.jl:360`, `SAGEBewley.jl:569`), the row-stochastic orientation. The DiscreteDP and every lottery use `Pi[i_z, i_zn]`.
   - Kronecker: `Pi[(si-1) nz + i, (sj-1) nz + j] = Ps[si, sj] Pi2[i, j]` with `Ps = [1-f f; delta 1-delta]` (`unemployment_core.jl:34-39`). Employment is the outer index, unemployed first; rows sum to one. `dread_params`, `agency_summary` (`u + nh`) and `cell_summary` (`zz > 0`) all use that order. Education is not a state: each cell is its own economy.
   - Measured: stationary unemployment 0.077179 and 0.044865 against `delta / (delta + f)` to six digits.

4. Logit.
   - Log-sum with the max subtracted, `P1 = 1 / (1 + exp((b0 - b1) / theta))`, a single `-Inf` branch gives probability 0 or 1 and marginal utility 0 (`egm_core.jl:230-236`). Correct, apart from the both-infeasible case in finding 4.
   - Belonging `social_strength * Lambda * B * Q_agg * QBAR * belong_scale` is identical in the three solvers and enters the d = 1 branch only.

5. Upper envelope and limits.
   - Monotone endogenous grid: constrained candidate below `aend[1]`, interpolated Euler solution above. Correct.
   - Non-monotone: every segment is evaluated at the grid points it spans and the maximum kept, with the constrained candidate as the starting value. Every candidate is budget-feasible, so the maximum is a valid envelope.
   - Borrowing limit: `a' >= a[1]` enforced in both branches; `a[1]` (about 1e-10) is used consistently, and `liquid_grid_of` hard-codes the same 1e-10.
   - Extrapolation beyond the top: see finding 1.

6. Stationary distribution.
   - Young lottery weight `(a[k+1] - ap) / (a[k+1] - a[k])` on node k, mixed over d with `P1`, times `Pi[i_z, i_zn]` (`egm_core.jl:278-296`). The same P1 and a_d the solver returns. Rows sum to one. Measured mass 1.000000000000.
   - `welfare_parts` builds the same transition for its policy evaluation (`reporting_core.jl:64-70`).

7. Unemployment insurance.
   - Benefit: `rr * alpha * z_latent * Z * e_ref`, the earnings at the reference effort and the current latent productivity, not the last wage. Annual throughout (f and delta are annual rates, the period is a year).
   - Tax: lump sum on every household, the unemployed included. `ui_tax` uses default rho and eta, which is harmless because `E[z] = 1` under the normalisation, so the cost per head is `share * u * rr * alpha * e_ref` for any process. The `e_ref / E_REF` rescaling is applied to both benefit and tax.
   - Measured: outlay per head from the solved distribution equals the closed form to eight digits in both cells (0.02787012 and 0.02393994). The budget balances.
   - The subsidy-levy and credit financing in `policy_tests.jl:105` and `quarantine.jl:95-97` use the right bases (`mean_labour_income / (1 - unemployment)` per employed, `QBAR * partbase`).

8. Units and populations.
   - e in [0, 1], time endowment 1, QBAR 0.10, floor in the same units.
   - `mean_effort_employed`, `rate_E`, `rate_U`, `consumption_drop`, `A_cond`, `dread_cost_E`, `mpc_htm`, `mpc_wealthy`, `welfare.status`, `consumption_status` each divide by their own population (given a correct mask, finding 2). `mean_labour_income`, `partbase`, `mpc`, `mps`, `mpe`, `consumption` are per head and labelled or used as such. The only sibling found is finding 8.

9. Other.
   - `update` and the `SAGEConfig` copy constructor carry every field. The sentinels `phi != 14.0` and `psi == 2.0` agree with the `SAGEParams` defaults.
   - Scratch arrays and policy arrays are fully overwritten each iteration; no stale values.
   - The reward table shared across belonging scales depends on nothing that varies with the scale.
   - `impose_unemployed_ratio` is exact under the conditions `check_ratio` enforces: with w = 0 the unemployed household's participation is separable from consumption and its option value is constant in assets.

10. McQueen-Porteus.
   - `dist = beta / (1 - beta) * (dmax - dmin)` is the width of the bounds and the shift `beta / (1 - beta) * (dmin + dmax) / 2` is applied to the new iterate (`egm_core.jl:244-251`). Correct; the comment writes V where it means the new iterate. Choices depend on differences, so the shift does not move them.
   - The rule tests V only, not the marginal value. Measured: tightening tol from 1e-9 to 1e-13 moves P1 by at most 1.6e-10, a' by 5.4e-11 and the participation rate by 1.6e-12, so the rule is adequate at the default.

Not verified: the two-asset solver (`egm2_core.jl`), `sa_core.jl`, the place layer, and the size of findings 8 and 9.

# The fast household solver: design (2026-09-28)

## Why

One household problem takes about 7.6 s at the production grid (`bench_solver.jl`). The time goes to three places:
- the reward table: for every state and next-asset pair, the best of 80 effort levels (na² × nz × 2 × ne evaluations);
- a sparse policy-iteration warm start;
- logit value iteration over a discrete next-asset grid.

The family path already shares the table across belonging scales (2.7x). Native Julia gave nothing (`bench_julia.txt`). The remaining gain has to come from the algorithm.

**The standard answer is the endogenous grid method** (Carroll 2006), extended to a labour choice (Barillas and Fernandez-Villaverde 2007) and to discrete choices with taste shocks (DC-EGM: Iskhakov, Jorgensen, Rust and Schjerning 2017). It works per state in O(na) instead of O(na² × ne), and it gives continuous effort and next assets exactly rather than on grids. Expected gain: one to two orders of magnitude per household problem.

## The household problem it solves (unchanged economics)

- **State:** (a, s), with s = (z, employment status) on the Kronecker process.
- **Choices:** next assets a' >= a_min, effort e in [0, 1 - floor - QBAR d], and participation d in {0, 1}, the last with logit taste shocks of scale theta.

**Flow utility:**

\[ \Gamma\left(\frac{c^{1-\gamma}}{1-\gamma} - \phi \frac{T^{1+\psi}}{1+\psi}\right) + \text{belong}_s \, d - D(a', s), \qquad T = \text{floor} + e + \text{QBAR}\, d \]

**Budget:** c + a' = R a + (1 + subsidy) alpha e z Z - T_lump + credit d + transfer_s.

**Values:**

\[ V(a, s) = \theta \log \sum_d \exp(v_d(a, s)/\theta), \qquad v_d(a, s) = \max_{a', e} \{ u + \beta E[V(a', s') \mid s] \} \]

The dread term D enters only in `dread_mode = :behaviour`. In the baseline overlay it is zero in choices.

## The algorithm, for one participation branch d and one state s

1. **Marginal continuation value** on the exogenous next-asset grid a'_k: W_a(a'_k) = beta E[V_a(a'_k, s')]. By the envelope condition, V_a = R Gamma c^{-gamma}, using the logit-weighted mix of the branches' consumption at a'.
2. **Euler equation, inverted:** Gamma c^{-gamma} = W_a(a'_k) - D_a(a'_k), which gives c_k in closed form. D_a is the derivative of dread; zero in the overlay.
3. **Effort from the intratemporal condition:** phi T^psi = c^{-gamma} (1 + subsidy) alpha z Z, so T_k = (c_k^{-gamma} (1 + subsidy) alpha z Z / phi)^(1/psi). Then e_k = T_k - floor - QBAR d, clamped to [0, e_max]. The clamp is exact at the corners: unemployed states (z = 0) have e = 0, and a household at the time limit has e = e_max.
4. **Endogenous current assets:** a_k = (c_k + a'_k - labour(e_k) - other) / R. The pairs (a_k, c_k, e_k, a'_k) are interpolated back onto the fixed asset grid.
5. **The borrowing limit.** For grid points below the smallest endogenous a, a' = a_min. c and e then solve the budget and the intratemporal condition jointly, one equation in e by Newton with a bracket (monotone, so safe).
6. **Upper envelope.** The logit smoothing makes the value functions smooth. A future participation switch can still create non-concave regions in v_d (the secondary kinks of DC-EGM), so the upper-envelope step of Iskhakov et al. (2017) is applied to each branch's endogenous grid before interpolation. It is cheap and a no-op where the grid is monotone.
7. **Branch values:** v_d on the fixed grid from the flow utility plus the interpolated continuation value.
8. **Combining the branches:** V is the logit sum, P1 = 1 / (1 + exp((v_0 - v_1)/theta)), and the next iteration's marginal value is the P-weighted mix of the branches' Gamma c^{-gamma}.

**Iteration.**
- Repeat to the same tolerance as now, 1e-9 on V.
- Families keep the warm start from the neighbouring belonging scale.
- The reward table disappears: nothing depends on an (a, a') pair any more.

**Distribution:** unchanged. The Young (2010) lottery on the asset grid, using the continuous a' policy, which the current solver already refines to continuous values.

**Output:** the same NamedTuple as `solve_participation_logit`: a, lambda, P1, e_d, a_d, V, z_vals, rate, meaninc, partbase, Q. `cell_summary`, `agency_summary`, families and everything downstream are untouched.

## Two-asset readiness

The second, illiquid asset (Kaplan and Violante 2014; Kaplan, Violante and Weidner 2014) adds a state b and a choice b' with an adjustment cost, which makes the problem non-convex in b'. The design keeps three layers separate, so the second asset replaces one layer only:

1. **The problem:** preferences, budget, transitions and grids, as a struct.
2. **The savings step:** the EGM for one liquid asset now. For two assets it becomes the nested EGM of Druedahl (2021, Computational Economics, "A guide on solving non-convex consumption-saving models"): an outer choice between adjusting and not adjusting b, with an inner EGM for the liquid asset at each b'. G2EGM (Druedahl and Jorgensen 2017, JEDC) is the alternative.
3. **The distribution and summaries:** written for a state array of any dimension. The lottery generalises to two dimensions.

Effort and participation sit inside each savings step exactly as above, so the labour and social margins carry over to two assets unchanged.

## Validation before it becomes the default

- **A switch, `solver = :grid | :egm`,** in SAGEConfig and SAGEParams. The current solver stays as the reference implementation and the default until every check below passes.
- **Against the reference, on the suite's economies.** The reference chooses effort on an 80-point grid and next assets on a 200-point grid before refining, while EGM is continuous. So the benchmark is the reference's own convergence rows. The EGM answer should sit where the reference is heading as ne rises (the ne = 160 row), and within the suite's convergence tolerances of the ne = 80 answer.
- **Reductions:** every test in `test_modular.jl` with `solver = :egm`.
- **Speed:** a family in seconds, and a country calibration in minutes, measured on the laptop and on Actions.
- **Recalibration:** once it is the default, every configuration is recalibrated with it (fast by then) and compared with the committed calibrations.

## Build order

1. `egm_core.jl`: one branch, no dread, effort interior. Unit tests against a problem with a known solution (no effort margin, CRRA, a borrowing limit that never binds).
2. The effort corners and the borrowing-limit region.
3. The participation branches and the logit mix. Then the upper envelope.
4. Dread in behavioural mode (its derivative in the Euler equation).
5. Drop-in behind `solver = :egm`, the validation above, then the default switch.
6. Later: the two-asset savings step.

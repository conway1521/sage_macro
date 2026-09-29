# The illiquid-asset switch: design (draft, 2026-09-29)

Step 4 of `PLAN_MASTER.md`. `ASSESSMENT.md` shows the one-asset limit in three untargeted moments:

- the median household holds about two years of income in cash, against a quarter of a year in the HFCS;
- the MPC is a third of the data's;
- wealth concentration is far too low.

All three have the same cause. The wealthy hand-to-mouth are missing, households with housing or pension wealth and little cash (Kaplan and Violante 2014; Kaplan, Violante and Weidner 2014).

## The switch

`illiquid = false` gives today's model exactly. With it on, the household holds two assets:

- **liquid** b, return r_b, borrowing limit b_min (zero at first);
- **illiquid** k, return r_k > r_b, adjusted only at a cost.

**Budget:**

\[ c + b' + k' + \chi(k', k) = (1 + r_b) b + (1 + r_k) k + \text{labour and transfers, as now} \]

**Adjustment cost** (Kaplan and Violante 2014): \( \chi(k', k) = \chi_0 \mathbf{1}[k' \neq k] + \chi_1 |k' - k| \). The fixed part makes households adjust rarely, and that is what creates the wealthy hand-to-mouth. Only a fixed cost is used at first. The linear part is added only if the adjustment frequency needs it.

**Everything else is unchanged:** effort, participation with its logit, unemployment, the discount types, and agency with dread. The switch replaces the savings step only (`SOLVER_DESIGN.md`, "Two-asset readiness").

## New parameters and their targets

| parameter | target | source |
|---|---|---|
| illiquid return premium r_k - r_b | not fitted: the return gap on housing and pension wealth | to be sourced from a peer-reviewed or official estimate (e.g. Jorda et al. 2019 for housing returns) |
| fixed adjustment cost chi_0 | share of wealthy hand-to-mouth: DE 0.248, FR 0.173, IT 0.155, US 0.202 | Kaplan, Violante and Weidner (2014) Table 5, wealthy panel, baseline row, p. 120 (verified 2026-09-29; `data/manual_inputs.csv`) |
| discount spread (as now) | share of poor hand-to-mouth | same table, as now |
| mean patience beta_bar | median illiquid wealth to income | HFCS 2021 statistical tables (real assets and voluntary pensions) |

The median liquid wealth to income (HFCS 2021 Table F1: 0.25 FR, 0.30 DE, 0.27 IT) then becomes untargeted and is the first validation check. The MPC and wealth concentration are the second and third checks. Once the HFCS microdata arrive, the hand-to-mouth shares can be re-estimated on HFCS 2021 and by place.

## Solver

**Nested EGM (Druedahl 2021, Computational Economics).**
- **Outer step:** each period the household chooses between keeping k (k' = k) and adjusting.
- **Keeping:** the problem in b is today's EGM with k as a fixed state, with effort and the participation logit inside as now.
- **Adjusting:** the choice is over total cash on hand, split between k' and b' by a one-dimensional search over k' on a grid, with the keeper's value function reused as the continuation.

The two branches are combined with a small logit smoothing, as participation is now. That keeps the upper envelope well behaved and matches the treatment of the discrete participation choice (Iskhakov, Jorgensen, Rust and Schjerning 2017). G2EGM (Druedahl and Jorgensen 2017, JEDC) is the fallback if the nested version is too slow.

**Cost.** The state grows from na × ns to nb × nk × ns. At nb = 100 and nk = 40 that is 20 times today's state space. The EGM is about 19 times faster than the grid solver it replaced, so a two-asset household problem should cost roughly what a one-asset problem cost a week ago. Families and calibrations stay on GitHub Actions.

**Distribution:** the Young lottery in two dimensions.

## Tests before it counts

1. **Reduction:** switch off, and also chi_0 → infinity with k0 = 0, both give today's model to machine precision.
2. **Euler errors** in both branches (`euler_errors.jl` extended).
3. **Convergence** in nb and nk.
4. **The suite** with the switch on and off.
5. **Recalibration** of every configuration with the switch on, fitted to its own targets.

## Open points for the user

- The illiquid return premium should be taken from a published estimate, not fitted. A source still has to be chosen.
- Whether the second earner or a borrowing limit (`ASSESSMENT.md`, section 5) is built in the same step, since both touch the budget. My recommendation is a borrowing limit here, and a second earner later if protection if hit still misses once the illiquid buffer exists.

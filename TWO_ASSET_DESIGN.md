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

## Build log

**2026-09-29, stage 1: the household solver (`egm2_core.jl`, `test_egm2.jl`).**

- **Reduction.** With adjustment unaffordable and no illiquid wealth, the solver reproduces the one-asset EGM: values to 6e-10 (the solve tolerance), the distribution to 1e-11, participation and income to ten digits.
- **Returns and discounting.** The illiquid return premium is taken from the Jorda-Schularick-Taylor data (`data/jst_premium.py`: 1980-2015, FR 0.035, DE 0.022, IT 0.022, US 0.040). The liquid return R = 1.02 matches the real bill rate of about 2%.
- **Perpetual youth**, with death at 1/45 a year (Kaplan, Moll and Violante 2018). Without it, with beta Rk near one, the wealth distribution settled only over thousands of years, and the distribution iteration never converged. With it, the distribution converges in about 1,300 iterations. Discounting includes survival. It is used only with the switch on.
- **Adjusting choice.** It carries logit smoothing of scale 0.01. At 0.005 the iteration cycles. At 0.05 the smoothing itself moves the adjusting share from 9% to 22%. At 0.01 and 0.02 the results agree.
- **Relaxation.** It is applied when the iteration stops improving, with convergence still judged on the full Bellman step. A remaining tiny stall is averaged and recorded in the result (`stalled`).
- **Liquid grid for the two-asset model:** top 15, 120 points. At the one-asset modular grid (top 4, 200 points, spacing exponent 3) the iteration cycled at states with liquid wealth of about 1.1 to 1.7, two to three times mean income. Tops of 15 and 30 converge and give the same moments. Correction, 2026-09-29: an earlier line here said the cycling came from empty states near a top of 100. That was wrong, because the modular grid tops at 4, not 100. Why the top-4 grid cycles is not yet understood. Every solve records whether it stalled and how much relaxation it needed, and the family builder reports the worst case, so a recurrence is visible.
- **Upper envelope** (shared with the one-asset solver): rewritten to visit only the grid points each segment covers. Results are bit-identical on one-asset and two-asset problems.
- **Speed:** 10 to 27 seconds per household problem.
- **First uncalibrated look** (Italy, lower-education cell, fixed cost 0.05): wealthy hand-to-mouth 0.15 against the target of 0.155, and median liquid wealth about 0.3 of income against 0.27 in the HFCS. For France at the same fixed cost few households hold illiquid wealth, so the calibration of chi0 and mean patience will carry the weight.

**Next:** the two-asset summaries (poor and wealthy hand-to-mouth, liquid and illiquid medians, MPC out of liquid wealth, drop on job loss, room to manoeuvre on liquid wealth), the switch in SAGEConfig and the family builder, the suite, then the calibration on GitHub.

**2026-09-29, stage 2: the economy (summaries, switch, suite, calibration).**

- **Summaries** (`two_asset_cell_summary`, `two_asset_agency_summary` in `egm2_core.jl`): the same fields as one asset. Hand-to-mouth, room to manoeuvre, OECD asset poverty, the MPC and dread are on liquid wealth. Poor hand-to-mouth hold no illiquid wealth and wealthy hand-to-mouth some. Capital income is the liquid return only. New fields: the wealthy hand-to-mouth (and their MPC), and the illiquid and net-wealth distributions. A shared branch walker (`each_branch`) makes the expected loss follow exactly the branches the distribution uses.
- **Switch:** `SAGEConfig(illiquid = true, ...)`. Two-asset calibrations live in `calibration_country_<code>_<config>_I.txt`, so the one-asset ones are untouched.
- **Reduction, economy level:** with the illiquid asset inert, all 16 headline numbers equal the one-asset economy's to within 3e-10. It is in the suite as tests 20 and 21, and the suite passes 21 of 21.
- **Targets added** (`data/manual_inputs.csv`): median net wealth over median gross income, from the HFCS 2021 tables (June 2026 edition): DE 2.38, FR 4.02, IT 5.51. Also the wealthy hand-to-mouth shares, from Kaplan, Violante and Weidner (2014) Table 5 p. 120.
- **Calibration, first run:** none calibrated. The cap on nominal patience (0.998) held effective patience, with survival, at 0.976. With the wide discount spreads that the German and Italian poor hand-to-mouth need, the median household ran its illiquid wealth down, and net wealth to income stuck at 0.3 to 0.5. France G+A came within 2.8 bands (net wealth 3.5 against 4.0, the other three on target). The logs are kept in `scripts/logs_two_asset/`.
- **Second run:** the calibration now fits effective patience, capped at 0.995, with an L2 line search and a fallback to the best point evaluated.
- **Early economics, France G+A, not yet converged:**
  - net-wealth Gini 0.695 against 0.676 in the HFCS, and top 10% share 0.52 against 0.50;
  - drop on job loss 0.11 against 0.09 in the data;
  - median liquid over median income 0.25, matching Table F1.
  - The MPC stays at about 0.11 against survey MPCs of 0.42. That is the open gap: in the model even the hand-to-mouth spend only 20 to 25% of a one-month windfall within the year.

**2026-09-29, calibration run 2 (effective patience capped at 0.995):**

- **France calibrated.** G+A: net wealth to income 3.83 (target 4.02), wealthy hand-to-mouth 0.169, poor 0.031, effort 0.640.
- **France G+A, untargeted checks:**
  - median liquid over median income 0.254 against 0.249 (HFCS Table F1);
  - drop on job loss 0.108 against 0.09;
  - net-wealth Gini 0.704 against 0.676, and top 10% share 0.53 against 0.50;
  - the MPC stays at 0.11 against 0.42.
- **Germany and Italy not calibrated.** Their poor hand-to-mouth targets (0.074 and 0.083) needed a uniform spread of up to 0.15. With the top type capped, that put the median household at effective patience of about 0.92, and median net wealth stuck at 0.5 to 2 times income against 2.4 and 5.5.
- **Decision: two patience groups.** A patient majority at beta_bar, and an impatient minority at effective patience 0.85 whose share is fitted to the poor hand-to-mouth. The probe (`probe_twopoint.txt`) shows the German and Italian targets now bracketed: net wealth of 11 to 18 times income at high patience, with poor hand-to-mouth moving with the share.
- **Run 3** recalibrates all three countries with the two groups, so they share one structure. The one-asset model keeps the uniform spread for now. Aligning it is a later choice, and its calibrations are unaffected.

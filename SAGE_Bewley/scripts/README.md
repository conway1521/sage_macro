# Scripts

Generated 2026-10-02 from the include graph (which script loads which). Three kinds of file:

- **The engine**: the files the modular stack loads. Everything current runs through them.
- **Live scripts**: entry points that load the modular stack (`modular_workers.jl` or `sage_modular.jl`). They follow the current model: the corrected effort moment, the EGM solver, country calibrations.
- **Earlier footings**: scripts that do not load the modular stack. They belong to earlier stages (stages 4 to 7, the v1.1 S paper, Paper 3, the first prototypes) and to other products. Their numbers predate the modular engine and are not updated by it. They are kept where they are because some still serve those products; none is used by the current model.

Run a live script with `julia --project=scripts/run_env scripts/<name>.jl` from `SAGE_Bewley/`, or on GitHub through the `probe` workflow (script and arguments as inputs). Calibrations run through the `calibrate` (one asset) and `calibrate2` (two assets) workflows; the modularity suite through `suite`.

## The engine

| file | what it is |
|---|---|
| `agency_core.jl` | Agency as a dimension of experienced wellbeing: the hardship half of the SAGE agency object, computed inside the Bewley economy. |
| `agency_shock.jl` | Agency as protection against being knocked off course. |
| `egm2_core.jl` | The two-asset household problem (TWO_ASSET_DESIGN.md): liquid b, return R, and illiquid k, return Rk, which accrues to k and can be changed only at a fixed cost chi0. |
| `egm_core.jl` | The endogenous-grid solver for the household problem (SOLVER_DESIGN.md). |
| `modular_stack.jl` | The whole modular stack in load order, as one file, so that it can be sent to a worker with a single @everywhere include. |
| `modular_workers.jl` | Bootstrap for anything that uses the modular layer in parallel: start single-threaded worker processes and load the whole stack on every one of them, master included, so  |
| `place_layer.jl` | The place layer, E1 (E_PLACE_CONCEPT.md, economics specification version 1). |
| `proto_participation_core.jl` | Shared core for the participation-margin prototypes: household problem with work effort AND a discrete participation choice (lump QBAR), given the aggregate participation |
| `reporting_core.jl` | The reporting layer, per household solve (PLAN_MASTER.md, version 2.0, item 7). |
| `sa_core.jl` | Computational core of the S+A paper: agency meets the participation margin. |
| `sage_modular.jl` | The modular SAGE economy: one configuration type, one solver, one result. |
| `transition_core.jl` | Transitions and impulse responses (PLAN_MASTER.md, version 2.0, item 7b), one asset, the social dimension off (G and G+A) in this first version. |
| `unemployment_core.jl` | Stage 6 core: the four-state (z, s) household with unemployment risk, the per-cell summary everything downstream is read off, and the hardship categories. |

## Live scripts (61)

### Tests and convergence

| script | what it does |
|---|---|
| `conv_na400.jl` | The doubled asset grid convergence row, on its own. |
| `euler_errors.jl` | Euler-equation errors (Judd 1992) of a household solution: at every state and branch with next assets above the limit, how far consumption is from what the Euler equation |
| `grid_test.jl` | How many belonging scales does a family need? |
| `test_agency_kvw.jl` | Checks for the shock-protection agency measure and the poor hand-to-mouth statistic (agency_shock.jl), and a reachability map for the new targets, bef |
| `test_carbon.jl` | The carbon tax and the valuation of its emissions change, one country. |
| `test_carbon2.jl` | The carbon tax on two assets (the consumption price in egm2_core.jl). |
| `test_egm.jl` | The EGM solver against the reference on single household problems: France G+S+A parameters, both education cells, three belonging scales. |
| `test_egm2.jl` | The two-asset solver (egm2_core.jl): the reduction to the one-asset EGM, then a first look with the illiquid asset live. |
| `test_egm_dread.jl` | Behavioural dread in the EGM solver against the reference, on single household problems: France G+S+A, dread weight 1.5 in choices, both education cells. |
| `test_modular.jl` | The modularity suite: every switch, and every reduction it has to satisfy. |
| `test_mpc_economics.jl` | The economics of the propensities, household by household (one asset, S off). |
| `test_place_report.jl` | The group-by-place table (place_report): France at TL2, G+A parameters with E on, unemployment benefits 10% higher. |
| `test_places.jl` | The place layer (E1). |
| `test_reporting.jl` | The reporting layer (reporting_core.jl, welfare_ce): checks on France G+A. |
| `test_reporting2.jl` | The reporting layer on two assets (two_asset_welfare_parts, egm2_core.jl). |
| `test_transition.jl` | The transition solver (transition_core.jl), France G+A, one asset. |
| `test_transition_s.jl` | The transition solver with the social dimension on (transition_s), France G+S+A. |
| `test_two_asset_economy.jl` | The illiquid asset at the level of the economy: the reduction (adjustment unaffordable, no death, the one-asset liquid grid: every result must equal the one-asset economy |
| `verify_modular.jl` | The gate, on the modular layer and the corrected footing. |

### Calibration

| script | what it does |
|---|---|
| `calibrate_country.jl` | Calibrate one country and one configuration on the modular engine. |
| `calibrate_nz7.jl` | Recalibration at seven productivity states. |
| `calibrate_ratio.jl` | Calibrate the social technology with the unemployed at the INSEE ratio. |
| `calibrate_two_asset.jl` | Calibrate the two-asset model (TWO_ASSET_DESIGN.md) for one country and a configuration without the social dimension (G or GA; the S configurations fo |
| `calibrate_two_asset_e.jl` | Calibrate the two-asset model with E on (GE or GAE) for one country: the economy over places (place_layer.jl, TL2 by default), with the same four G targets as calibrate_t |
| `calibrate_two_asset_s.jl` | Calibrate the two-asset model with the social dimension on (GSA, or GS) for one country. |

### Results, reports and estimation

| script | what it does |
|---|---|
| `assessment_moments.jl` | Untargeted moments of each calibrated G+S+A economy against the validation benchmarks in PLAN_MASTER.md. |
| `estimate_epsilon.jl` | E's one parameter, the community elasticity epsilon (omega_p = omega x (infra_p / infra_national)^epsilon), estimated on Italy's 21 TL2 regions and te |
| `policy_equilibria.jl` | Stable participation equilibria of every economy in the policy tests. |
| `policy_tests.jl` | Policy tests on a country's calibrated configurations, with A on and off. |
| `report_policies.jl` | The reporting layer on a full economy: France G+S+A, three policies from the policy tests, each against the baseline. |
| `run_places.jl` | E with all channels, by country: composition, access to work, conversion, commuting and (France) community, each alone and all together, at both ends of the community ela |
| `run_places_tl2.jl` | E at the OECD TL2 level (E_PLACE_CONCEPT.md, "The standard"): each region its own economy with composition, access to work and conversion from Eurostat regional data, com |
| `stage7_nz7.jl` | Stage 7 again, on seven productivity states and on the modular layer. |
| `validate_countries.jl` | Cross-country validation of the agency column. |

### Probes (one question each)

| script | what it does |
|---|---|
| `probe_benefit.jl` | Can each country reach its hand-to-mouth target once the benefit is averaged over an unemployment spell instead of a fixed twelve months? |
| `probe_defect.jl` | The one known defect, retested on the corrected footing. |
| `probe_dread.jl` | Agency version 2, Gate 3: does dread behave? |
| `probe_drop.jl` | Why is the consumption drop on job loss too large in DE and IT? |
| `probe_drop_profile.jl` | Where does the consumption drop on job loss come from? |
| `probe_egm2_gridtop.jl` | Why does the two-asset solver cycle on the one-asset liquid grid (top 4) and not on tops of 15 or 30? |
| `probe_gradients.jl` | Does the multiplier band depend on the carried-over alpha and B gradients? |
| `probe_gs_identification.jl` | Can G+S identify its two social parameters (kappa, sigma) without the education gap? |
| `probe_hardship_by_place.jl` | Is hardship by place wrong-signed because of the one-asset model? |
| `probe_median.jl` | The modularity suite reports a baseline median disposable income of 0.530 against mean labour income of 0.450, which cannot be right. |
| `probe_memory.jl` | How many workers fit in memory on this machine. |
| `probe_mpc_one_asset.jl` | What the one-asset model's MPC does as the hand-to-mouth share rises (France G by default). |
| `probe_mpc_psi.jl` | The MPC against the wealth effect on effort (France G by default): for each inverse Frisch elasticity psi, the effort scale phi is refitted to the effort target (secant), |
| `probe_nz.jl` | How many productivity states does the poverty line need? |
| `probe_nz2.jl` | The one convergence row the modularity suite fails. |
| `probe_nz3.jl` | Does anchoring the poverty line on mean income settle the state-space sensitivity? |
| `probe_nz4.jl` | Where does the agency column actually settle in the state space? |
| `probe_place_fr.jl` | Place feasibility, modelling test: does the access-to-work channel alone make participation differ by place as the data do? |
| `probe_ratio_de.jl` | Germany's unemployed participation ratio: the refit of the social technology with the published Freiwilligensurvey figures in place of the unsourced 0.574. |
| `probe_two_asset_map.jl` | How mean patience and the fixed cost move the two-asset moments: France G+A, the committed G+A effort scale and spread, the FR illiquid premium. |
| `probe_twopoint.jl` | Two patience groups in the two-asset model: can a patient majority hold the German and Italian median net wealth while an impatient minority gives the poor hand-to-mouth? |
| `probe_unemployed_gap.jl` | Anatomy of the unemployed participation gap. |
| `quarantine.jl` | Does anything we report depend on the unemployed participating at one? |
| `quarantine2.jl` | Quarantine, second design: impose the data on one set of families. |

### Benchmarks

| script | what it does |
|---|---|
| `bench_family.jl` | The fast family path against the original: the same household problems, solved once with a shared reward table and neighbour warm starts, once from scratch. |
| `bench_julia.jl` | The same work on two Julia builds: one family by the fast path (France G+S+A, lower education cell, 83 belonging scales) and the full calibrated economy with the cache of |
| `bench_solver.jl` | Where does the time go? |

## Earlier footings (109)

Not on the modular stack. Listed so that nothing here is mistaken for a current result.

| script | what it was for |
|---|---|
| `agency_gate.jl` | The two gate rows the other checks do not cover. |
| `agency_na_check.jl` | Grid check for the agency column. |
| `agency_na_policies.jl` | Does the grid move the CHANGES, not just the level? |
| `agency_na_pooled.jl` | The pooled version of the agency grid check. |
| `agency_omega_table.jl` | Collate the agency column across the omega sweep. |
| `agency_second_path.jl` | Independent code path for the agency column. |
| `audit_ne_l5.jl` | Effort-grid convergence at the final calibration, with the slope. |
| `audit_nz.jl` | Is nz = 2 the root cause of everything that went wrong? |
| `audit_nz_l5.jl` | The income-process sweep, repeated on the stage-5 core. |
| `audit_oldfooting.jl` | Would the linearisation identity have caught the defect? |
| `audit_sa.jl` | Audit of the S+A core. |
| `audit_theta.jl` | The theta-sensitivity test. |
| `audit_theta2.jl` | Two follow-ups that decide the working theta. |
| `calibrate_phi_country.jl` | Per-country phi calibration: for each country, find the phi that makes the model's mean work share equal the country's time-use target. |
| `calibrate_tipping.jl` | Paper 1 decisive experiment: discipline the behavioural social weight, confirm the two solvers agree once off the knife-edge, then map the tipping boundary. |
| `calibration_dense_scan.jl` | Dense scan of the calibration neighbourhood, written 2026-09-08 after the nz sweep recalibrated to a DIFFERENT point than the headline on identical fo |
| `compare_stage4_stage5.jl` | Side by side: every S+A scalar on the hard-threshold footing (stage 4, snapshot in stage4_hardthreshold/) against the logit core (stage 5). |
| `countries_compare.jl` | Run the model for every country in COUNTRIES, print targeted and untargeted moments side-by-side with the data targets. |
| `het_types_scope.jl` | Scoping prototype (v2): heterogeneous social types. |
| `het_types_strong.jl` | Follow-up to het_types_scope.jl: the SIGN of the committed-minority effect. |
| `model_gdpb.jl` | The model's own GDP-B exercise (Plan phase 4.1). |
| `p3_family.jl` | Paper 3 (calibrated history): precompute the response family on a grid of agency levels alpha, so the entire multi-country, multi-year history is interpolation. |
| `p3_history.jl` | Paper 3: the calibrated history. |
| `p3_validate.jl` | Paper 3: validation, decomposition, WELLBY pricing, and figures. |
| `paper1_figures.jl` | Paper 1 figures: the social-cohesion tipping result. |
| `paper1_policy_figure.jl` | Paper 1 figure 4: the policy-induced decoupling. |
| `paper_agency_map.jl` | The clinching figure: the public-good map under unequal vs equal agency. |
| `paper_v11_figures.jl` | All numbers and figures for the v1.1 rewrite of the S paper, in one script, so the text and the code cannot drift apart. |
| `participation_model.jl` | The calibratable participation model: the designed S+A core. |
| `plots.jl` | Visual sanity check: reproduce the shapes of thesis Figures 2 (policy rules) and 4 (wealth distribution). |
| `policy_experiment.jl` | Paper 1 normative experiment: a budget-balanced make-work-pay labour subsidy, under behavioural social cohesion. |
| `probe_reduction.jl` | Does the participation solver, with the social dimension switched off, reproduce the baseline engine? |
| `proto_edu_income.jl` | Prototype: separate education (permanent type) from income (Markov state). |
| `proto_income_complete.jl` | Completing the income process: persistent x transitory shocks on the education-cell architecture, via the new process override. |
| `proto_participation.jl` | Prototype: discrete social-participation margin (Brock-Durlauf route to multiplicity under HONEST elasticities). |
| `proto_participation_taste.jl` | Participation margin with taste dispersion (Brock-Durlauf direction). |
| `prototype.jl` | Prototype run: solve the stationary SAGE/Bewley model and sanity-check it against the qualitative facts reported in the thesis (Figures 2, 4, 6). |
| `s6_check_identity.jl` | STAGE6.md Part 6, check 5: the stationarity identity with four states and the union hardship event. |
| `s6_check_na.jl` | STAGE6.md Part 6, check 6: the asset grid, na 200 against 400, on the pooled baseline and on the two policies whose agency effects run through wealth (the subsidy) and th |
| `s6_check_theta.jl` | STAGE6.md Part 6, check 7: theta halved at the calibrated point, four belonging scales per cell placed where the taste mass sits. |
| `s6_common.jl` | Shared constants for stage 6. |
| `s6_diag_block.jl` | Diagnostic: how much of the recalibration shift is the unemployed block? |
| `s6_diag_decomp.jl` | Why did the map steepen? |
| `s6_omega_table.jl` | Collate stage 6 across the omega sweep (STAGE6.md Part 6, check 9). |
| `s6_pop.jl` | Population machinery for stage 6, shared by the driver and every check. |
| `s6_second_path.jl` | STAGE6.md Part 6, check 10: every taste node solved directly at its own belonging scale, no response family and no interpolation, pooled by mass. |
| `s6_test_grid.jl` | STAGE6.md Part 6, check 3: is a_max = 4 still scaled to the wealth distribution once households save against job loss? |
| `s6_test_parallel.jl` | STAGE6.md Part 6, check 2 (P2), redone for process parallelism: the pmap build must be identical to the serial build to the last bit. |
| `s6_test_switchoff.jl` | STAGE6.md Part 6, check 1 (P1): with delta = 0 the four-state model must reproduce the stage-5b two-state family to solver tolerance. |
| `s6_workers.jl` | Start single-threaded worker processes and load the stage-6 code on all of them (master included, via @everywhere, so that every process holds ONE cop |
| `s7_check_identity.jl` | STAGE7.md Part 6, check 5: the stationarity identity with four states and the union hardship event. |
| `s7_check_na.jl` | STAGE7.md Part 6, check 6: the asset grid, na 200 against 400, on the pooled baseline and on the two policies whose agency effects run through wealth (the subsidy) and th |
| `s7_check_theta.jl` | STAGE7.md Part 6, check 7: theta halved at the calibrated point, four belonging scales per cell placed where the taste mass sits. |
| `s7_common.jl` | Stage 7 constants. |
| `s7_diag_nbeta.jl` | The jagged map is the discount distribution, not the belonging grid. |
| `s7_diag_quad.jl` | Last suspect for the jagged loss surface: the taste quadrature. |
| `s7_diag_slope.jl` | Is the map slope of 0.9908 a property of the economy or of the exact minimiser? |
| `s7_diag_ugrid.jl` | Is the jagged slope an economy or a grid? |
| `s7_omega_table.jl` | Collate stage 7 across the omega sweep (STAGE7.md Part 6). |
| `s7_pop.jl` | Population machinery for stage 7: stage 6 with a population of permanent discount-factor types behind every cell. |
| `s7_probe.jl` | Stage 7 probe: what magnitudes do the two new parameters need? |
| `s7_probe2.jl` | Stage 7, second probe. |
| `s7_probe3.jl` | Stage 7, third probe. |
| `s7_second_path.jl` | STAGE7.md Part 6, check 10: every taste node solved directly at its own belonging scale, no response family and no interpolation, pooled by mass. |
| `s7_workers.jl` | Start single-threaded worker processes and load the stage-6 code on all of them (master included, via @everywhere, so that every process holds ONE cop |
| `sa_agency.jl` | A on its own, and A alongside S: the agency dimension of the SAGE dashboard computed on the S+A model, at the stage-5b calibration, without touching behaviour. |
| `sa_countries.jl` | Cross-country robustness for the S+A policy results. |
| `sa_countries_l4.jl` | Cross-country robustness for the S+A policy results, on the Level 4 footing. |
| `sa_diagnostics.jl` | Numerical accuracy for the S+A paper. |
| `sa_families_fine.jl` | Rebuild the response families on a grid concentrated where the response actually moves. |
| `sa_figures.jl` | Figures and final numbers for the S+A paper. |
| `sa_figures_l4.jl` | Figures for the S+A paper on the Level 4 footing. |
| `sa_level4.jl` | Level 4: every S+A result recomputed on the verified numerical footing. |
| `sa_main.jl` | S+A paper, main analysis. |
| `sa_omega_l4.jl` | Robustness of the verdict to the private share omega (stage 5: reads the logit-core families written by sa_figures_l4.jl), the one parameter with no point estimate. |
| `sa_partcredit.jl` | Participation tax credit (Paper 2's NEW experiment): the model analogue of France's 66 percent charitable-donations deduction and the UK's Gift Aid. |
| `sa_partcredit_figure.jl` | Figures for the policy section: (a) four policies on one participation axis at their real fiscal cost; (b) the GDP versus GDP-B ledger. |
| `sa_partcredit_real.jl` | Participation tax credit at REAL rebate rates, implemented in the budget constraint (Plan phase 5.1). |
| `sa_partcredit_takeup.jl` | Take-up incidence in the participation credit. |
| `sa_policy_compare.jl` | S+A paper, policy comparison: the same financed-subsidy experiment Paper 1 ran now expressed in the participation framework, plus a new policy designed to act DIRECTLY on |
| `sa_proposition_boundary.jl` |  |
| `sa_proposition_check.jl` | calibrated point from sa_main |
| `sa_recalibrate.jl` | Recalibrate on the fine-grid families, and check the taste quadrature is actually converged this time. |
| `sa_recalibrate_final.jl` | Definitive recalibration: fine-grid families, converged taste quadrature. |
| `sa_recalibrate_l5.jl` | Recalibration of (kappa, sigma_m) on the stage-5 core. |
| `sa_recalibrate_l5b.jl` | The calibrated point on the logit core sits where the map is steep, and there theta = 0.01 is not yet in the limit (0.018 off on the level). |
| `sa_stage6.jl` | Stage 6 driver: the S+A dashboard with unemployment risk. |
| `sa_stage7.jl` | Stage 7 driver: stage 6 plus permanent discount-factor heterogeneity, the one of the two stage-7 fixes that the probes accepted. |
| `sa_valley.jl` | The moment fit is a valley in (kappa, sigma_m), not a point. |
| `social_cohesion.jl` | Paper 1 (S): behavioural social cohesion, via the engine's social_mode flag. |
| `test_notebook.jl` | Headless test: open and fully run the Pluto notebook, report any cell errors. |
| `v11_battery_grids.jl` | v1.1 validation battery A: grid convergence and sanity. |
| `v11_battery_policy.jl` | v1.1 validation battery C: does the make-work-pay decoupling result survive the literature parametrization? |
| `v11_battery_window.jl` | v1.1 validation battery B: re-locate the multiplier bistable window under the literature-disciplined parameters (gamma=2, psi=2, phi=1.861), heterogeneous agency. |
| `v2_correlated.jl` | Correlated types: does it matter WHO the givers are? |
| `v2_homophily.jl` | Homophily belonging channel: experiments under the honest (v1.1) parameters. |
| `v2_homophily_confirm.jl` | Confirmation run for the group-level bistability claim: kappa = 20, h = 1, tighter tolerance and more iterations, starting from each of the two candidate attractors for t |
| `v2_types_honest.jl` | v2 re-verification under the honest (v1.1) parametrization, plus the literature-disciplined type distribution. |
| `verify_L0_engine.jl` | VERIFICATION LADDER, LEVEL 0: the engine itself. |
| `verify_L1_core.jl` | VERIFICATION LADDER, LEVELS 1 AND 2: the participation core, and whether the response-family reduction is a faithful stand-in for a direct solve. |
| `verify_L2_bias.jl` | LEVEL 2, decisive test: does the pointwise interpolation error bias the AGGREGATE? |
| `verify_S_grid.jl` | Does the S paper survive the grid finding? |
| `verify_S_table.jl` | The S paper's policy table (Table 1: financed 20 percent work subsidy under warm-glow cohesion, ne = 320) reproduced on the rescaled asset grid, so the paper can be updat |
| `verify_T1.jl` | TIER 1 verification. |
| `verify_T1b.jl` | TIER 1 follow-up. |
| `wellby_bridge.jl` | The WELLBY bridge: policy effects in life-satisfaction points and in money, priced from published coefficients rather than from the model's own internal shadow price. |
| `wise_benchmark.jl` | WISE benchmark (collaboration plan, task 3.1). |
| `wise_participation.jl` | Does the S+A paper's cohesion object fix the S paper's validation failure? |
| `wise_participation_logit.jl` | The WISE Solidarity comparison, redone on the logit core at small theta. |

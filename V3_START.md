# SAGE version 3: starting point

Written 2026-10-02. This is the one state document for the start of version 3. It replaces nothing in `PLAN_MASTER.md`, which keeps the version 2.0 record. It says what was audited, what was wrong and is now fixed, what is still open, what the model should match, what is ready for the HFCS, and what can be run.

Supporting documents, all in the repository:

| document | what it holds |
|---|---|
| `audit_2026-10-02/` | five audit reports: household problem, two assets, aggregation and reporting, data and place, calibration. Line numbers in them refer to the code before the fixes below |
| `research/MPC_EVIDENCE.md` | the evidence on propensities to consume, save and earn, with a verification tag on every number |
| `research/SAE_LITERATURE.md` | the literature and official data behind S, A and E |
| `hfcs_protocol/` | the HFCS readiness brief and `hfcs_moments.py` (no data) |
| `SAGE_Bewley/scripts/README.md` | every script: engine, live, earlier footing |

## 1. Where the model stands

**Sound.** Five independent audits derived the household problem from the code and found it correct:
- the budget constraint is the same in the solver, the constrained region, the distribution and the summaries;
- the Euler equation, the effort condition and the envelope condition are right, with the consumption price;
- discounting, the orientation of the transition matrix and the ordering of states are right;
- the unemployment insurance budget balances (measured to eight digits);
- the two-asset budgets, the timing of the illiquid return, the resource identity and the envelope formula are right;
- pooling across patience types, belonging scales and education cells applies each weight once, as ratios of sums;
- target ownership in the calibration scripts matches the design, and no value is inherited from the wrong file;
- every national data value that was re-queried from Eurostat and the OECD matches, and the hand-to-mouth and HFCS figures match their published tables.

**The economics of the propensities has the right shape.** `test_mpc_economics.jl` checks eight properties household by household, and all hold for France G: the MPC falls with liquid wealth (0.25 in the bottom fifth to 0.04 at the top, against a permanent-income benchmark of 0.02), is higher for the hand-to-mouth and the unemployed, falls with the size of the windfall, is larger for a loss than for a gain, falls with patience, and consumption, saving and earnings add up exactly.

**The level is wrong.** The annual MPC is 0.10 to 0.13 against 0.4 to 0.5 in the data, and the earnings response to a windfall is minus 0.10 to minus 0.17 against about minus 0.01. Section 3 sets out why and what to decide.

## 2. Audit ledger

### Fixed on 2026-10-02

| what was wrong | consequence | fix |
|---|---|---|
| Net wealth median read as the grid node above it, a step of 3.6 to 4.9% against a 5% band | two-asset calibrations could pass or fail on a grid snap (France G+A and Germany G+S+A missed narrowly) | interpolated quantile in all two-asset calibration scripts |
| Belonging welfare not zero with S off (summaries read parameters with the belonging weight at its default) | the welfare decomposition was wrong with S off, and the reduction to G failed on that field; total welfare was unaffected | summaries read the parameters the household was solved with |
| Welfare ignored the participation rule for the unemployed | welfare by employment status counted the unemployed as participating at the model's rate (near one with S on) where the rule reports about 0.13 for France | what participating while unemployed contributes is evaluated separately and scaled to the rule |
| A missing calibration file gave engine defaults silently | any script asking for an uncalibrated configuration returned a plausible economy that was never fitted | `country_config` raises an error; calibration scripts opt out explicitly |
| Italy two-asset G+A file predated the effort correction and carried an outdated French fixed cost | a stale calibration was live | removed |
| Household footprint left out direct emissions (heating, car fuel) | emissions per head 28% too low for France | Eurostat total including households; France 6.0, Germany 7.9, Italy 6.8 tonnes per head in 2021 |
| Regional job finding normalised with population weights | mean job finding 1 to 5 points below the national figure with E on | weights by the unemployed |
| Quarterly flow rates used as annual (degree of urbanisation) | the rural to city gap in job finding overstated by half | compounded to a year |
| Regional conversion netted out unemployment only | low employment loaded into the pay of those in work (Campania against Bolzano 0.61 where about 0.86 remains) | net of the regional employment rate, added to the regional table |
| Community scaling did not preserve the national mean | national belonging about 1 to 2% low with the community channel | rescaled |
| Regional table mixed years and filled gaps silently | invisible gaps | the build prints every missing series and every older year |
| Transitions netted the employed levy into the insurance tax path | a zero shock would not return the steady state with a levy | benefits summed over unemployed states only |
| S transitions returned unconverged paths without saying so, with participation from a later iterate than the rest | the logged recession run had stopped at its iteration limit | all paths from one iterate; a warning and a `converged` field |
| Employment read from "receives no benefit" | at a zero replacement rate everyone would be classed as employed, reintroducing the effort error | read from the productivity state |
| Calibration scans scored any stable equilibrium | a fit could sit on a lower equilibrium than the one the economy selects | the selected equilibrium only |
| Failed two-asset calibrations left the earlier file and the checkpoint in place | a stale file could be uploaded as if new; a rerun would resume the failure | both removed on failure |
| The fixed cost written with four decimals | 5% rounding at 0.0011 | five decimals |
| Preflight failure used the time-budget exit code | a failed preflight would trigger five resumes | its own exit code |
| Solvers returned silently at the iteration limit, on an accepted stall, or with an infeasible state | no signal of a bad solve | warnings and an error |
| Poverty comparisons nominal under a consumption tax | the rebate's effect on income poverty overstated | income and wealth deflated |
| The reduction suite: three rows compared an economy with itself, two were vacuous, NaN passed, welfare and propensities were not compared | the suite covered less than it appeared to | rows now take each switch through its code path at a negligible value; NaN fails; welfare and propensities compared; new rows for the consumption tax, the effort curvature, extra time, commuting and two patience groups |
| Smaller items | | time propensities on one population; the carbon tax returns the economy solved with the rebate it reports; protection among the employed weighted by employed mass; the place scan uses the solver's quadrature |

The strengthened suite is running on GitHub at the time of writing; its result is recorded in section 7.

### Open, and why each is left

| item | why it is not fixed here |
|---|---|
| France's liquid grid top (4) binds: 1.9% of the higher-education cell sits on the top node | a longer grid changes every one-asset calibration; it goes into the version 3 recalibration |
| The net wealth target divides by gross income in the data and by disposable income in the model | a choice of concept; see decision D5 |
| The fixed cost of adjusting illiquid wealth is not identified by the wealthy hand-to-mouth share: in the logs it moved sevenfold while the moment stayed within 0.003. At 0.001 it is below the smoothing of the keep-or-adjust choice | the target has to change; see section 3 and decision D1 |
| The corrections in the two-asset S and E calibrations keep the last point, with no line search | to be rebuilt with the new targets |
| The illiquid grid is coarse near the median (nodes 50 to 70% apart) and the net wealth grid tops at 80 | a convergence test in nk and a longer grid, with the recalibration |
| The replacement rate does not vary by place while job finding does | a consistency choice for E |
| Epsilon was estimated on the Italian volunteering data that is also the regional test | see decision D7 |
| The carbon value mixes price years and currencies | policies are parked |
| Transitions do not refuse the two-asset model | to be built or refused when transitions resume |
| Welfare along a transition does not apply the participation rule | consistent on both sides of the comparison, noted |

### Calibration files after the fixes

| set | state |
|---|---|
| One asset, E off (G, G+A, G+S, G+S+A, three countries) | fitted after the effort correction. The fixes above do not move their targeted moments. To be redone in version 3 for the new targets |
| One asset, E on (G+E, G+A+E, G+S+E, G+S+A+E) | fitted before the place-layer fixes: stale |
| Two assets, all | fitted before the net wealth interpolation: stale. Present: G and G+E for the three countries, G+A and G+A+E for France and Germany. Absent: Italy G+A and G+A+E, every G+S and G+S+A |

## 3. What the model should match

Full evidence in `research/MPC_EVIDENCE.md`. The numbers that matter:

| moment | France | Germany | Italy | source |
|---|---|---|---|---|
| Annual MPC out of a one-month windfall | 0.42 | 0.51 | 0.48 | Drescher, Fessler and Lindner (2020), from the HFCS 2017 wave; self-reported, includes durables |
| Benchmark from registry data | 0.52 within the year, falling with liquid assets and with prize size | | | Fagereng, Holm and Natvik (2021), Norway |
| Earnings response in the first year | about minus 0.01, range 0 to minus 0.04 | | | Cesarini and co-authors (2017); Auclert, Bardóczy and Rognlie (2023); no evidence for the three countries |
| Hand-to-mouth, poor and wealthy | 0.032 and 0.173 | 0.074 and 0.248 | 0.083 and 0.155 | Kaplan, Violante and Weidner (2014), Table 5 |
| Hand-to-mouth, total | 0.205 | 0.322 | 0.238 | the same, summed |

**Why the model's MPC is low.** Two causes, and one that was tested and ruled out:

1. **Too few constrained households on one asset.** The one-asset model targets the poor hand-to-mouth share only. If its single asset is read as liquid wealth, the consistent target is the total share. Kaplan and Violante (2022) obtain an annual MPC of 0.15 with a 2.5% hand-to-mouth share and 0.41 to 0.59 once the model is calibrated to liquid wealth or to a 14% share.
2. **The effort margin.** With separable preferences the ratio of the earnings response to the MPC is about the Frisch elasticity over the elasticity of intertemporal substitution, which is one at the model's values. A constrained household therefore splits a windfall about half into spending and half into working less. `probe_mpc_psi.jl` confirms the cap: the MPC of the hand-to-mouth rises from 0.52 to 0.82 as the Frisch elasticity falls from 0.5 to 0.06. Auclert, Bardóczy and Rognlie (2023) show that the MPC and the earnings response cannot both match the data with freely chosen hours and separable preferences, and recommend taking households off their labour supply curve.
3. **Not the annual period.** `probe_mpc_period.jl` solves the same French household problem at a quarterly period whose four quarters reproduce the annual income and employment process exactly (the fourth root of the transition matrix, to 1e-14), and measures the consumption response over the four quarters after a windfall. The annual MPC is the same at every hand-to-mouth share: 0.130 against 0.127 at the calibration, 0.182 against 0.183 at a 21% share, with effort, wealth and the hand-to-mouth share matching. The higher figures of quarterly models in the literature therefore come from their income process and wealth targets, which this model can adopt at an annual period.

With a 22% hand-to-mouth share and nearly inelastic effort the model reaches about 0.29. The rest of the distance to the data has to come from more households being near the constraint (the impatient share, or the income process), which is what an MPC target would discipline.

The two-asset model does not escape the first two: its fixed cost collapses to the bound, so illiquid wealth is in effect liquid, and it shares the effort margin.

**Untargeted checks to report** once the level is addressed: the MPC by liquid-wealth quartile (0.62, 0.52, 0.46, 0.46 in Norway), by windfall size, by hand-to-mouth status, a loss against a gain, and how spending is spread over the following years.

## 4. Corroboration of S, A and E

Full brief in `research/SAE_LITERATURE.md`.

**S.**
- Grounded: the functional form is Brock and Durlauf (2001); the multiplier of 1.3 to 1.8 sits inside the 1.3 to 2.2 reported for group membership, voting and giving; the education gradient in volunteering is in official data.
- Thin: no direct estimate of a multiplier for volunteering; the selection of the highest equilibrium has no argument in the source paper.
- Open, with data now collected (`data/validation/timeuse_by_status.csv`): on a diary day the unemployed do organisational work about as often as the full-time employed (France 1.3% against 1.5%, Germany 3.8% against 3.6%, Italy 1.6% against 0.7%, 2010) and about twice as much informal help. The model's rule for the unemployed comes from twelve-month prevalence, which shows a gap in France and Germany. The two measure different things (who takes part at all, against how often), but the choice of counterpart for the model's yearly participation has to be argued.

**A.**
- Grounded: two official counterparts exist. OECD labour market insecurity (expected earnings loss, 2016): France 3.1%, Germany 1.4%, Italy 8.6%. For France, INSEE reports a 15% consumption drop six months after job loss, with consumption absorbing 58% of the income loss in the lowest liquidity quartile and 17% in the highest.
- Thin: no verified consumption-drop estimate for Germany or Italy.
- Run on 2026-10-02 (`corroborate_agency.jl`, G+A, one asset; benchmarks in `data/validation/agency_benchmarks.csv`), both untargeted:

| France, on job loss | model | INSEE |
|---|---|---|
| income falls | 33% | 31% |
| consumption falls | 9% | 15% at six months |
| share of the income loss absorbed by consumption | 26% | 35% |
| the same, lowest quartile of liquid wealth | 63% | 58% |
| the same, highest quartile | 4% | 17% |

| expected income loss to unemployment | model | OECD labour market insecurity |
|---|---|---|
| France | 2.3% | 3.1% |
| Germany | 1.6% | 1.4% |
| Italy | 4.6% | 8.6% |

  The income drop and the liquidity gradient are reproduced, and the bottom quartile matches. Households above the bottom quartile smooth too well, the same weakness as the low MPC. The country ordering of expected loss is right, with Italy too low.
- Open: the consumption drop on job loss is 31% in Germany and 40% in Italy in the model, against 10% in France and 7 to 16% in the literature for other countries. This is too large and needs an explanation before any agency number for those two countries is reported.

**E.**
- Grounded: civic capital as a persistent local stock, a local supply channel from organisations to volunteering, a quasi-experiment on lost infrastructure, and a rural premium in official volunteering data for France and Germany.
- Thin: no published elasticity benchmarks epsilon. Non-profit institutions per head in Italy is close to the outcome it explains, and epsilon was estimated on the same regional data, so the fit with the community channel is in sample.
- Run on 2026-10-02 after the place-layer fixes (`run_places_tl2_DE.txt`, `run_places_tl2_IT.txt`; G+S+A parameters from before the fixes, so provisional):

| regional participation against volunteering | correlation | spread of log participation, model against data |
|---|---|---|
| Germany, 16 Länder, economic channels (untargeted in every channel) | 0.36 | 0.059 against 0.084 |
| Italy, 21 regions, economic channels (untargeted) | 0.31 | 0.045 against 0.309 |
| Italy, with community, epsilon 0.3 (in sample) | 0.82 | 0.104 against 0.309 |
| Italy, with community, epsilon 0.5 (in sample) | 0.83 | 0.163 against 0.309 |

  **The untargeted regional fit is weak.** Before the fixes the Italian economic channels gave 0.67. Most of that came from the conversion channel loading the south's low employment rate into the pay of those in work; with the employment rate netted out, the economic channels explain little of Italy's north to south gradient (a seventh of the spread) and a third of Germany's variation. What reproduces the Italian pattern is the community channel, and that is in sample. E's claim on regional participation therefore rests, for now, on one in-sample elasticity.
- A likely reason, to examine: regional differences in participation in the data follow employment rates (people outside the labour force), and the model has no state outside the labour force.
- Already in hand (`estimate_epsilon_IT.txt`, run before the effort correction and the place-layer fixes, to be redone): Italy's regions prefer an epsilon of 0.5; France by degree of urbanisation, with facilities built before 1990, prefers about 0.3 (rural over cities 1.34 in the model against 1.37 in the data at 0.3, and 1.69 at 0.5). Three places is too few to estimate on.
- To run: epsilon re-estimated on France with sports facilities built before 1990 at a finer geography; the regional prediction on German Länder against the Freiwilligensurvey, where infrastructure did not enter the calibration.

**Hardship by place** remains the model's one failed prediction: negatively correlated with official regional poverty in Italy on one asset (minus 0.61). The HFCS by Italian region is the test.

## 5. HFCS readiness

`hfcs_protocol/HFCS_READINESS.md` and `hfcs_protocol/hfcs_moments.py`. The script's self-test passes on synthetic data (20 of 20 checks); a self-test cannot catch a wrong variable name, and those marked to confirm are in one dictionary at the top.

On the day the data arrive: put the files in `~/hfcs_secure` (never in the repository, never in a synced folder), run `HFCS_DIR=~/hfcs_secure python3 hfcs_protocol/hfcs_moments.py OUTDIR`, and open `hfcs_coverage.csv` first.

What it will give:
- hand-to-mouth shares, poor, wealthy and total, under the published definition and the model's, by country and wave;
- net and liquid wealth over income, the Gini and the top share;
- liquid-asset poverty and income poverty and their overlap;
- all of these by education, labour status and place;
- the self-reported MPC by country, by liquid wealth and by hand-to-mouth status, which is the country target of section 3 and a test of the MPC falling with liquid wealth.

What it cannot give, known in advance:
- region: 20 regions in Italy (the only country where the regional test can run), the 8 former ZEAT in France, four groups of Länder in Germany; region only from the 2017 wave, degree of urbanisation only from 2021;
- income is gross only (net for Italy possibly);
- no cash holdings and no credit limits.

One finding to settle with the data: the published hand-to-mouth shares appear to treat all saving accounts as illiquid. If the wealthy hand-to-mouth share falls sharply when they are counted as liquid, the German and Italian targets the two-asset model cannot reach are partly a classification choice.

## 6. What can be run

From `SAGE_Bewley/`, `julia --project=scripts/run_env scripts/<name>.jl`, or on GitHub through the `probe` workflow. Times are for the laptop unless stated.

| purpose | script | time | needs |
|---|---|---|---|
| Reductions and convergence | `test_modular.jl` (workflow `suite`) | 15 to 60 min on GitHub | nothing |
| MPC economics | `test_mpc_economics.jl [CODE] [CONFIG]` | 1 min | a one-asset S-off calibration |
| Why the MPC is low | `probe_mpc_one_asset.jl`, `probe_mpc_psi.jl`, `probe_mpc_period.jl` | 5 to 10 min | France G |
| Reporting layer | `test_reporting.jl`, `test_reporting2.jl` | 2 and 10 min | France G+A, one and two assets |
| Solver against the reference | `test_egm.jl`, `test_egm2.jl`, `euler_errors.jl` | minutes | nothing |
| Transitions | `test_transition.jl`, `test_transition_s.jl` | minutes; 2 hours on GitHub with S | France G+A, G+S+A |
| Place layer | `test_places.jl`, `test_place_report.jl [CODE] [CONFIG] [I]` | 2 to 75 min | E recalibrated |
| Regional runs | `run_places_tl2.jl`, `estimate_epsilon.jl` | GitHub | E recalibrated |
| One-asset calibration | workflow `calibrate` (countries, configs) | 20 min to 5 hours each | chains G+S+A to G+S, G+S+A+E to G+S+E |
| Two-asset calibration | workflow `calibrate2` | 10 min to 4 hours each | chains G to G+E, G+A to G+S+A and G+A+E, France G+A to Germany and Italy |
| Agency against INSEE and the OECD | `corroborate_agency.jl [CONFIG]` | 2 min | one-asset G+A, three countries |
| Policies, equilibria | `policy_tests.jl`, `policy_equilibria.jl`, `report_policies.jl` | GitHub | parked |
| Carbon | `test_carbon.jl`, `test_carbon2.jl` | 2 and 20 min | parked |
| Validation data | `data/validation/timeuse_by_status.py`, `data/place/build_tl2.py`, `data/sustainability/footprint_intensity.py` | seconds | network |
| HFCS moments | `hfcs_protocol/hfcs_moments.py` (`--selftest` today) | seconds | the data |

Not to be run for current results: the 109 scripts listed under "Earlier footings" in `SAGE_Bewley/scripts/README.md`.

## 7. Suite result

Run 36964671870 on GitHub, on the code with every fix above (2026-10-02): **32 of 32 reductions and 8 of 8 convergence checks pass.**

- Every row now compares welfare (total and its three parts) and the four propensities as well as the indicators.
- The rows that used to compare an economy with itself take the switch through its own code path at a negligible value: unemployment, the discount spread, two patience groups, the participation cost, the policy instruments, the consumption tax, the effort curvature, extra time and commuting. Largest gap 8e-9.
- Belonging welfare is exactly zero with S off.
- The four E reductions and the identical-places reduction hold to 1e-16; the inert illiquid asset to 3e-9.

The regression tests on the same code also pass: the reporting layer (adding-up exactly one, a positive remainder), the transition test, and the place-layer test.

Not covered by any reduction yet: the transitions, the illiquid asset with S on, E with the illiquid asset, the employed levy.

## 8. Decisions

Each changes the calibration, so they are best settled together, before the grid is run again.

| | decision | options | recommendation |
|---|---|---|---|
| D1 | The labour margin, which caps the MPC and inflates the earnings response (option (a) is built as a switch, section 10) | (a) hours set by the job, not chosen household by household within the year: the earnings response to a windfall is then zero, and effort still responds to policy on average; (b) a lower Frisch elasticity, 0.25, inside the micro range; (c) preferences with a weak wealth effect | (a), which is the literature's recommendation and keeps effort as a policy margin; (b) as the fallback that needs no new code |
| D2 | The one-asset hand-to-mouth target | poor share only (as now), or the total share | the total share, with the asset read as liquid wealth |
| D3 | The period | annual (as now), or quarterly | settled by `probe_mpc_period.jl`: the period does not move the annual MPC. Stay annual |
| D4 | An MPC target | none (as now), or the country values of section 3 with a band of 0.10, carried by the impatient share on one asset and by the fixed cost on two assets | add it; on two assets it replaces the wealthy hand-to-mouth share as the target that identifies the fixed cost, and frees Germany and Italy from the French value |
| D5 | Income concept in the net wealth target | gross in the data and disposable in the model (as now), or one concept on both sides | compute the model's gross income for this ratio |
| D6 | Regional conversion | net of the employment rate (done), or a pay-per-worker measure by region | keep the first, test the second |
| D7 | Epsilon | the Italian estimate (in sample), or France's facilities built before 1990 | re-estimate on France and treat Italy and Germany as tests |
| D8 | The rule for the unemployed | twelve-month prevalence (as now), or diary-day participation | keep prevalence, and say why |
| D9 | Scripts and notes from earlier footings | leave in place with the index (as now), or move to an archive folder | move, after checking the S paper and Paper 3 pipelines still run |
| D10 | Liquid grid top | 4 (as now), or longer | longer, with a warning on top-node mass |

## 9. Order of work for version 3

1. Settle D1, D2, D4 and D5 (D3 is settled).
2. Implement the labour margin and the targets; extend `test_mpc_economics.jl` with the untargeted checks of section 3.
3. HFCS on arrival: coverage, the hand-to-mouth replication, the MPC by country, Italy by region.
4. Recalibrate the grid once: one asset, then two assets, then E.
5. Run the corroborations of section 4.

## 10. Effort set by the job (built 2026-10-02)

`effort_mode = :job` in the configuration (`:free` is unchanged and remains the default). Each state has one level of effort, at which the effort condition holds on average over the households in that state; a household's own wealth does not move its hours. Found by a fixed point around the household solver (`solve_job_effort`, `egm_core.jl`). One asset; the two-asset version is not built.

`test_effort_mode.jl`, France G, six checks hold:
- the average effort condition holds in every employed state (3e-8);
- the earnings response to a windfall is exactly zero (minus 0.10 under free effort), and consumption and saving add up to one;
- a 10% wage subsidy moves effort by minus 2.46% (minus 2.45% under free effort): the policy margin is kept;
- with effort nearly inelastic the two modes agree.

What it does to the MPC (`probe_mpc_job.jl`, France G, effort not refitted):

| hand-to-mouth share | MPC, free effort | MPC, job effort, impatient group at 0.85 | at 0.70 |
|---|---|---|---|
| 0.03 (calibrated) | 0.13 | 0.18 | |
| 0.13 | 0.15 | 0.22 | 0.25 |
| 0.22 (France's total is 0.205) | 0.18 | 0.27 | 0.33 |
| 0.32 (Germany's total is 0.322) | 0.22 | 0.32 | 0.42 |
| 0.42 | 0.25 | 0.37 | 0.50 |

With job effort and the total hand-to-mouth share the model reaches the lower part of the target bands (France 0.42, Germany 0.51, Italy 0.48, each plus or minus 0.10). How impatient the impatient group is then has a target of its own, the MPC, where today it is fixed at 0.85 by assumption. The cost is visible in the same runs: the consumption drop on job loss rises (0.15 to 0.20 for France) and median liquid wealth falls.

Open: the fixed point takes up to 18 steps; with S on, France G+S+A solves in about three minutes. Transitions hold job effort at its steady-state level for now.

## 11. Parameters by status

A parameter is acceptable in one of four ways: it is measured, it is taken from the literature, it is fitted to a target it owns, or the results do not depend on it. Anything else is free, and a free parameter is a result assumed.

| status | parameters |
|---|---|
| Measured, by country | education shares; pay by education (alpha); belonging taste by education (B); separation and job finding; the replacement rate; the reference effort in benefits; the unemployed participation ratio; the median-to-mean income ratio; the income process (rho, eta); the illiquid premium; everything by place in E |
| From the literature | risk aversion 2; the Frisch elasticity 0.5; patience 0.96 and the return 1.02 on one asset; the dread weight 1.5; the death rate 1/45; the three-month asset-poverty horizon |
| Fitted to an owned target | the effort scale phi (effort of the employed); the patience spread or impatient share (hand-to-mouth); kappa (overall participation); sigma (the education gap in participation, in G+S+A; inherited in G+S); on two assets, patience (net wealth to income) and the fixed cost (wealthy hand-to-mouth, which does not identify it) |
| Results do not depend on it (tested) | the logit scale theta; the grids and quadrature, within the convergence rows of the suite |
| **Free** | **omega**, the private share of the belonging payoff (0.30); **epsilon**, the community elasticity in E (0.4, estimated in sample); **the patience of the impatient group** (0.85); **the time participation takes**, QBAR (0.10 of time); the weight Lambda on belonging, carried from the thesis; the stability gate (a multiplier of at most 5) |

**Omega decides the multiplier, and nothing identifies it** (`probe_omega.jl`, France G+S+A): refitting kappa and sigma to the same two participation targets at each omega, the fit is equally good from 0.15 to 0.90 (root loss 0.0001 to 0.001) and the multiplier runs from 3.2 to 1.03. At zero the targets cannot be met with a stable equilibrium. The multiplier of 1.3 to 1.8 reported so far is therefore the value of omega assumed, 0.30, and no more. Kappa absorbs the difference; sigma does not move.

| omega | kappa | sigma | fit (root loss) | multiplier |
|---|---|---|---|---|
| 0.15 | 7.25 | 1.02 | 0.0001 | 3.24 |
| 0.30 | 5.45 | 1.02 | 0.0002 | 1.75 |
| 0.50 | 4.10 | 1.02 | 0.0010 | 1.30 |
| 0.70 | 3.30 | 1.04 | 0.0010 | 1.12 |
| 0.90 | 2.75 | 1.04 | 0.0011 | 1.03 |

What could give each free parameter a target:

| parameter | a target that would own it |
|---|---|
| omega | the dispersion of participation across regions relative to what regional fundamentals explain (the excess-variance approach of Glaeser, Sacerdote and Scheinkman 2003): a larger multiplier spreads regions further apart. The model's regional spread is too small today (0.06 against 0.08 in Germany, 0.05 against 0.31 in Italy), which points to an omega below 0.30. Or a published multiplier for a neighbouring behaviour (1.4 to 2.2), stated as an assumption |
| epsilon | facilities built before 1990 in France, at a finer geography than three place types |
| patience of the impatient | the MPC (section 10) |
| QBAR | the time participants spend, from the time-use surveys already downloaded. On organisational work alone the population spends 2 minutes a day in France and Italy and 7 in Germany, which at the yearly participation rates is roughly one to three hours a week per participant; 0.10 of committed time looks several times larger. To be measured properly before it is changed |

## 12. Each dimension's economics

| dimension | what it claims | what supports it | where it is weak |
|---|---|---|---|
| **G** | households save against income and job risk; effort responds to pay | budget, Euler and effort conditions verified in the audit; eight MPC properties hold; the income drop on job loss matches INSEE for France (33% against 31%); the liquidity gradient in the consumption response is reproduced | the MPC level (addressed by job effort, the total hand-to-mouth share and an MPC target); the consumption drop on job loss is too large in Germany and Italy (31%, 40%); liquid-asset poverty rises when insurance improves, so hardship cannot be read as a welfare indicator on one asset |
| **S** | participation is a choice whose payoff rises with others' participation; one stable equilibrium at the data | the form is Brock and Durlauf's; overall participation and the unemployed gap are matched; the multiplier is inside the published range for neighbouring behaviours; unique equilibrium in every calibrated economy | the multiplier is set by omega, which is free; no direct estimate for volunteering; the unemployed rule rests on twelve-month prevalence while diary data show no gap; with S off there is no participation at all, so S carries the whole level |
| **A** | pay and protection differ by education, which generates the education gradient in participation and an agency indicator | the education gap in participation is matched in G+S+A and is not produced by S alone (0.02 against 0.09 in France), so A is doing identifiable work; expected income loss has the right country ordering against the OECD | national agency is close to one everywhere, so it discriminates little; the gap is fitted through sigma, a taste dispersion, so part of what is called agency is fitted taste; no consumption-drop benchmark for Germany or Italy |
| **E** | where people live changes access to work, what work pays, and the payoff to taking part | national aggregates are preserved exactly; reductions hold to 1e-16; agency by region varies plausibly | the untargeted regional fit of participation is weak (0.31 Italy, 0.36 Germany); the community channel rests on one in-sample elasticity; hardship by place is wrong-signed; no state outside the labour force, which is what regional participation follows in the data |
| **Two assets** | wealth can be large and illiquid, so households can be wealthy and constrained | budgets and the resource identity verified; reduces exactly to one asset | the fixed cost sits at its bound, so illiquid wealth is in effect liquid; Germany's and Italy's wealthy hand-to-mouth are far below the data; not yet a result |

In one line each: G is sound in structure and wrong in one level that now has a fix; S is sound in form and carries one free parameter that decides its headline; A does identifiable work on the education gap and little at the national level; E preserves the national economy but has not yet earned its regional claims; two assets is unfinished.

## 13. The version 3 build: order and gates (started 2026-10-02, evening)

Agreed with the user: the base is made standard, line by line, and S, A and E are what the model adds. Every step ends in a gate; nothing moves on until its gate holds, and a gate that fails is written here as a failure.

**The base, in standard terms**

| piece | standard treatment | where |
|---|---|---|
| Effort | hours set collectively for each type of worker, so that the effort condition holds on average; a household's wealth does not move its hours | built, `effort_mode = :job` |
| MPC | the single asset read as liquid wealth: the total hand-to-mouth share as target, an impatient group, the MPC as the target of that group's patience | pilot running |
| Job loss | a means-tested consumption floor (Hubbard, Skinner and Zeldes 1995) and replacement rates at the level of the household | to build |
| Hardship | asset poverty reported as a measure of buffers; income poverty and the consumption drop on job loss as the hardship indicators | reporting change |
| Multiplier | omega from the dispersion of participation across regions, or every S result as a band over omega | to build |

**Order**

| step | what | gate |
|---|---|---|
| 1 | HFCS moments, FR, DE, IT, five waves, with disposable income (EUROMOD files) | the published figures are reproduced within stated tolerances: hand-to-mouth shares (Kaplan, Violante and Weidner 2014, Table 5, 2010 wave), median net wealth and income (ECB tables), the self-reported MPC (Drescher, Fessler and Lindner 2020), asset poverty (Balestra and Tonkin 2018). Where they are not, the reason is found before any number is used |
| 2 | Targets table for version 3 from the HFCS: total hand-to-mouth, MPC, median liquid wealth over disposable income, net wealth over disposable income | each target has a source, a wave, a standard error and a model counterpart on the same concept |
| 3 | Base economics: the consumption floor, household replacement rates, QBAR from time-use data | reductions (floor at zero is no floor); the budget balances; `test_mpc_economics.jl` and `test_effort_mode.jl` hold; the consumption drop in Germany and Italy against the literature's range |
| 4 | Identification check for every configuration before it is calibrated | each parameter moves its own target most; the owned block is well conditioned; no flat column |
| 5 | One-asset recalibration: G, G+A, G+S, G+S+A, three countries, then E | all owned targets inside their bands; multiplier gate; the untargeted list below |
| 6 | Two assets with job effort, the MPC and the liquid and illiquid medians as targets | the same |
| 7 | S, A, E in depth: omega, the unemployed, the decomposition of the education gap, inactivity by place, epsilon out of sample, hardship indicators by place against the HFCS by region | each claim has an untargeted test |
| 8 | The suite, the regression tests, and a full pass with every dimension switched on and off | every reduction exact; every configuration solves and reports the full set of indicators |

**Untargeted tests, fixed before recalibrating** (pass bands in brackets)

- MPC falling across liquid-wealth quartiles, and the HFCS's own gradient by liquid wealth (sign and monotone);
- the earnings response to a windfall (0 to minus 0.04);
- France: the income drop on job loss (31%), the share of the income loss absorbed by consumption by liquidity quartile (58% lowest, 17% highest; within 15 points);
- expected income loss against OECD labour market insecurity (country ordering);
- the consumption drop on job loss (7 to 20%);
- the net wealth Gini and top 10% share on two assets (HFCS, within 0.05);
- regional participation against volunteering by region, Germany and Italy, without the community channel (reported, whatever it is);
- the education gap in participation produced by S alone (reported).

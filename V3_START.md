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

## 14. The HFCS, step 1 and step 2 (2026-10-02, night)

The microdata are in `~/hfcs_secure` (five waves, France, Germany, Italy). `hfcs_protocol/hfcs_moments.py` reads them there and writes aggregate tables only; `data/hfcs_targets.csv` holds the moments the model uses, with standard errors. Source: Eurosystem Household Finance and Consumption Survey.

**Gate 1 holds: the published figures are reproduced.**

| benchmark | published | computed |
|---|---|---|
| Net wealth over gross income, 2021, FR / DE / IT (ECB tables) | 4.02 / 2.38 / 5.51 | 4.02 / 2.38 / 5.50 |
| Self-reported MPC, 2017 (Drescher, Fessler and Lindner 2020) | 0.418 / 0.513 / 0.481 | 0.419 / 0.513 / 0.481 |
| Poor hand-to-mouth, 2010 (Kaplan, Violante and Weidner 2014) | 0.032 / 0.074 / 0.083 | 0.030 / 0.079 / 0.084 |
| Wealthy hand-to-mouth, 2010 | 0.173 / 0.248 / 0.155 | 0.158 / 0.226 / 0.150 |
| Asset poverty, persons, 2014 (Balestra and Tonkin 2018) | 0.405 / 0.424 / 0.387 | 0.395 / 0.425 / 0.424 |

The 2010 wave has been revised since the hand-to-mouth paper, which accounts for the small gaps there. Italy's asset poverty is 0.04 above the OECD figure; Italian income in the HFCS is recorded differently (taxes are a separate variable), and the difference is not resolved.

**After-tax income exists.** The delivery includes household disposable income simulated by the ECB with EUROMOD (France and Germany, waves 2014 to 2021); Italy records its own taxes in every wave. Every ratio is therefore available on the model's income concept, which settles decision D5 from the data side.

**What the survey says, 2021 unless stated**

| | France | Germany | Italy |
|---|---|---|---|
| Self-reported MPC (2017 / 2021 / 2023) | 0.42 / 0.39 / 0.39 | 0.51 / 0.47 / 0.46 | 0.48 / 0.47 / 0.44 |
| Hand-to-mouth, published definition, total | 0.206 | 0.190 | 0.164 |
| Hand-to-mouth, the model's rule (one week of income), narrow liquid wealth | 0.222 | 0.225 | 0.179 |
| The same, broad liquid wealth (saving accounts counted as liquid) | 0.114 | 0.146 | 0.141 |
| Median liquid wealth over median after-tax income, narrow | 0.059 | 0.140 | 0.272 |
| The same, broad | 0.380 | 0.442 | 0.316 |
| Median net wealth over median after-tax income | 4.78 | 3.15 | 6.82 |
| Net wealth Gini | 0.68 | 0.73 | 0.64 |
| Income poverty (half the median, after tax, persons) | 0.097 | 0.109 | 0.145 |
| Liquid-asset poverty (OECD definition, after-tax line) | 0.335 | 0.321 | 0.341 |

**Three findings that change the design**

1. **The self-reported MPC is high at every level of liquid wealth.** By quintile of liquid wealth, 2017: Italy 0.56 falling to 0.42; Germany 0.55 to 0.47; France 0.35 rising to 0.50. A quarter of households answer one half. The level cannot come from a small group of constrained households; it needs most households to be short of liquid wealth, which is what the narrow definition shows.
2. **Narrow against broad liquid wealth is the choice that decides the one-asset model.** With saving accounts counted as illiquid (the published definition), median liquid wealth is 6% of annual income in France and the model's rule puts 22% hand-to-mouth; with them counted as liquid, 38% and 11%. A one-asset model can be calibrated to one or the other.
3. **Liquid-asset poverty runs with income poverty across places, against the version 2 model.** Italy, 2021, North / Centre / South and Islands: liquid-asset poverty 0.25 / 0.27 / 0.51; hand-to-mouth (broad) 0.09 / 0.10 / 0.25; income poverty 0.06 / 0.10 / 0.29; median liquid wealth EUR 13,000 / 8,200 / 3,000; self-reported MPC 0.43 / 0.46 / 0.53. Germany: the East is the most asset-poor (0.40 against 0.25 in the South-West). The version 2 model put the thinnest buffers where jobs are safest. That prediction is rejected. The test for version 3 is the same table.

**The one-asset base, decided on this evidence.** The single asset is liquid wealth on the narrow definition (the standard liquid-wealth calibration, Kaplan and Violante 2022). `probe_liquid_calibration.jl`, France: lowering patience from 0.96 to about 0.925 moves median liquid wealth over income from 0.39 to 0.07, the hand-to-mouth share from 0.03 to 0.25 and the MPC from 0.17 to 0.34, with no impatient group and no MPC target; the MPC of households that are not hand-to-mouth rises to 0.30, as in the survey. The cost, stated: the one-asset economy then holds almost no wealth, and the consumption drop on job loss is about twice the French benchmark. Wealth and the MPC together are what two assets are for.

**Other inputs measured the same night**

- Replacement rates at the level of the household (OECD TaxBEN 2023, `data/benefits/`): France 0.704, Germany 0.585, Italy 0.527, of which the state pays 0.476, 0.361, 0.291; the rest is a partner's earnings and is not taxed in the model. Used in version 3.
- A means-tested floor is built as a switch (`cfloor`, `test_floor.jl`) and is OFF in the baseline: Germany's and France's minimum income is already inside the OECD replacement rate, and Italy's scheme excludes childless households. In the model the floor does not reduce the consumption drop on job loss (households give up the buffers that cushioned it) and raises the hand-to-mouth share sharply, which is the result of Hubbard, Skinner and Zeldes (1995). Open: some household problems do not converge with the floor on.
- The time participation takes: 0.04 of committed time from the time-use surveys (0.02 to 0.07), against 0.10 assumed (`data/timeuse/`). Now a parameter, 0.04 in version 3.
- People outside the labour force by place: adding them rescales participation by 5 to 11% almost uniformly and explains almost none of the regional spread. Not the missing channel in E.
- The literature check (`research/STANDARD_TREATMENTS.md`): effort set by the job is a state-by-state variant of the union rule of Auclert, Rognlie and Straub (2024), where one average condition sets hours for everyone; no published precedent for the state-by-state form was found, so it is presented as this model's variant. The excess-variance strategy for the multiplier is Glaeser, Sacerdote and Scheinkman (1996), not their 2003 paper. Blundell, Pistaferri and Saporta-Eksten (2016) is about permanent wage shocks, not job loss.

**Version 3 runs beside version 2** (`country_config(...; v3 = true)`): effort set by the job, the household replacement rate, participation time 0.04, its own calibration files `calibration_v3_*`. Version 2 is unchanged to the last digit and stays until version 3 is complete.

## 15. The version 3 base, as calibrated (2026-10-03, early hours)

**Specification.** `country_config(...; v3 = true)` and `SAGE_V3=1` for `calibrate_country.jl`.

| piece | version 2 | version 3 |
|---|---|---|
| Effort | chosen household by household | set by the job, state by state, where the effort condition holds on average |
| The single asset | unspecified wealth, patience 0.96 | liquid wealth, narrow definition (HFCS) |
| Replacement rate | single person (0.653 / 0.456 / 0.374) | household-weighted (0.704 / 0.585 / 0.527), state-paid part taxed (0.476 / 0.361 / 0.291) |
| Participation time | 0.10 assumed | 0.04 measured |
| Income process | innovation s.d. 0.10 (hourly wages, persistent part) | fitted to the official income quintile ratio |

| parameter | owns | source of the target |
|---|---|---|
| phi | effort of the employed | HETUS |
| top patience | median liquid wealth over after-tax income | HFCS 2021 |
| spread of patience | hand-to-mouth share, total, one-week rule | HFCS 2021 |
| eta (income dispersion) | S80/S20 of disposable income, people under 65 | EU-SILC 2021, `data/validation/income_distribution.csv` |

Top patience and the spread move the two wealth moments along nearly one line (the search's map has one singular value near zero), so the fit is a best fit by damped least squares and the misses are reported in bands. The MPC is not targeted.

**France G** (`calibration_v3_FR_G.txt`: phi 8.38, top patience 0.873, spread 0.001, eta 0.266)

| moment | model | data | |
|---|---|---|---|
| Effort of the employed | 0.643 | 0.643 | target |
| Hand-to-mouth share | 0.223 | 0.222 | target |
| Median liquid wealth over income | 0.069 | 0.059 | target |
| S80/S20, under 65 | 4.70 | 4.72 | target |
| **MPC, one-month windfall** | **0.34** | **0.39** (self-reported, HFCS) | untargeted |
| MPC of the hand-to-mouth, of the others | 0.50, 0.29 | 0.46, 0.39 | untargeted |
| Earnings response to a windfall | 0.00 | about minus 0.01 | by construction |
| Gini of disposable income | 0.299 | 0.296 | untargeted |
| Below half the median income | 0.076 | 0.097 (HFCS, after tax, persons) | untargeted |
| Consumption drop on job loss | 0.15 to 0.22 | 0.15 at six months (INSEE) | untargeted |
| In-work poverty, 60% of the median | 0.17 | 0.067 | untargeted, MISSED |
| Income drop on job loss | 0.21 | 0.31 (INSEE) | untargeted, low |
| Share of the income loss absorbed by consumption | 0.66 (0.96 lowest liquidity quartile, 0.25 highest) | 0.35 (0.58, 0.17) | untargeted, too high |

All eight MPC properties hold (`test_mpc_economics_FR_v3.txt`): the MPC falls from 0.50 in the bottom fifth of liquid wealth to 0.15 at the top, with the size of the windfall (0.38 at 2% of annual income, 0.24 at a year's income), is larger for a loss than a gain, 0.70 for the unemployed against 0.32 for the employed.

**What the base now gets right that it did not:** the MPC (0.34 against 0.10), the earnings response (zero against minus 0.10), the income distribution (Gini 0.30 against 0.12), income poverty (7.6% against 0.4%), the consumption drop on job loss in line with the French benchmark.

**What it costs, stated:**
- patience of 0.87 a year, which is what liquid-wealth calibrations give and is low against the 0.96 of total-wealth calibrations;
- the economy holds almost no wealth (the 90th percentile of liquid wealth is a third of annual income), so the one-asset model says nothing about wealth; that is the two-asset model's job;
- households absorb too much of an income loss in consumption, for the same reason;
- in-work poverty is too high: all income dispersion sits on workers, where in the data much of it comes from people out of work part of the year;
- all dispersion is persistent risk, with no permanent differences beyond education and no transitory shocks.

**Italy's liquid wealth** is the open misfit in the pilots (0.18 against 0.27 with patience at its bound): Italian deposits sit in sight accounts, so its narrow liquid wealth is high while its hand-to-mouth share is also high, which one patience distribution cannot give.

## 16. The version 3 one-asset grid, three countries (2026-10-03)

**The rule that stands.** The hand-to-mouth share owns the patience parameters (band 0.02) and is required, with effort. Median liquid wealth over income stays in the fit at a low weight (band 0.09) and is reported with its miss. Income persistence stays at the country table's 0.92.

**What was tried on the way, and why it was dropped.**

| rule | France | Germany | Italy |
|---|---|---|---|
| both wealth moments required, bands 0.02 and 0.03 (run 37094996963) | calibrates | hand-to-mouth 0.255 against 0.225, liquid 0.18 against 0.14, spread at 0 | 0.13 against 0.18, 0.21 against 0.27, spread at 0.15 |
| both required, bands of two survey standard errors with a floor (run 37140582030) | not rerun | none of G, G+A, G+S+A: 0.25 and 0.18 | none: liquid inside (0.24 to 0.26), hand-to-mouth 0.11 against 0.18 |
| the same with income persistence fitted in 0.90 to 0.97 (commit 9e9175a, laptop, Germany G) | | stalled at 0.261 and 0.173, persistence 0.915 | |
| hand-to-mouth owns, liquid reported (run 37139922996) | files from the first rule stand | calibrates | calibrates |

`probe_wealth_shape.jl` (outputs for the three countries beside it): patience, its spread and the dispersion of the shocks move the two wealth moments along one line in every country. Persistence looked independent at Germany's point (51 degrees off the line) but is close to collinear in France (12 degrees) and did not move the fit when freed. One patience distribution over one asset does not give both moments in Germany and Italy. The survey says why: most hand-to-mouth households are wealthy ones (France 0.17 of 0.21, Germany 0.12 of 0.19, Italy 0.09 of 0.16), which one asset cannot represent (Kaplan and Violante 2014).

**The grid.** Targets: effort, hand-to-mouth, S80/S20; with S, participation by cell. Liquid wealth and the MPC are not required.

| | hand-to-mouth (data) | liquid / income (data) | MPC (survey) | participation, multiplier |
|---|---|---|---|---|
| FR G | 0.223 (0.222) | 0.069 (0.059) | 0.34 (0.39) | |
| FR G+A | on target | | 0.36 | |
| FR G+S+A | on target | | 0.36 | 0.233, 1.9 |
| FR G+S | on target | | 0.34 | 0.235, 1.9 |
| DE G | 0.234 (0.225) | 0.218 (0.140) | 0.27 (0.47) | |
| DE G+A | 0.229 | 0.203 | 0.27 | |
| DE G+S+A | 0.231 | | | 0.278, 1.8 |
| IT G | 0.172 (0.179) | 0.158 (0.272) | 0.31 (0.47) | |
| IT G+A | 0.173 | 0.152 | 0.32 | |
| IT G+S+A | 0.172 | | | 0.125, 1.3 |

Germany and Italy G+S: the chained runs picked up the survey-band code and failed on it; rerun under the standing rule (run 37174463994).

**Stated misses.** Liquid wealth in Germany (half as much again as the data) and Italy (a little over half the data). The MPC in Germany and Italy, 0.27 to 0.32 against 0.47 self-reported. In-work poverty, 0.14 to 0.17 against 0.07 to 0.12, in all three. Italy's survey moments are imprecise (standard errors 0.029 on the hand-to-mouth share and 0.028 on liquid wealth over income).

**France's checks at the version 3 point.** Eight of eight MPC properties in G+A (MPC 0.60 in the bottom fifth of liquid wealth, 0.16 at the top; 0.71 unemployed, 0.33 employed). Agency: expected income loss to unemployment 1.9% against the OECD's 3.1%; consumption absorbs 67% of the income loss on job loss against 35% (INSEE), 97% in the lowest liquidity quartile against 58%. Identification (`identification.jl FR G v3`): effort and S80/S20 are owned cleanly; the owned block has condition number 97 because the spread and top patience are one dial.

**Two assets, version 3: not calibrated, and a numerical doubt.** France G, three steps of the fit: net wealth over income 4.5 (4.78), liquid over income 0.21 (0.059) unchanged while the fixed cost fell from 0.05 to 0.002, wealthy hand-to-mouth 0.13 (0.18), MPC 0.16. An adjuster chooses illiquid wealth among 24 grid nodes and holds the remainder as liquid; near the median the nodes are more than a year of income apart, so the liquid median may be grid remainder. `probe_two_asset_grid.jl` solves the same economy on 24 and 48 nodes. Until it is read, the liquid moments of the two-asset model, version 2 included, are not results.

## 17. On/off pass, places, and the laptop (2026-10-04)

**The laptop is out of the loop.** The Mac restarted three times on 3 October (01:08, 13:46, 23:59), each time under a two-asset run with 6 to 10 worker processes; the system log shows memory kills before the last. No Julia on the laptop. Everything runs on GitHub; the laptop only starts runs and reads results.

**One asset, version 3: all twelve configurations calibrated** (G, G+A, G+S, G+S+A in France, Germany, Italy). Germany G+S: participation 0.279, hand-to-mouth 0.235, multiplier 1.8. Italy G+S: 0.125, 0.171, 1.3.

**On/off pass (`onoff_v3.jl`, one run per country).** France 15 of 16, Germany and Italy 12 of 14 on the first run; the failures were the check itself and files not yet there, not the model:
- S off gives participation of order 1e-5 or less, the logit's tremble, where the check asked for exactly zero (now: below 1e-4);
- Germany and Italy G+S had no file yet (now calibrated; rerun started).
What holds in all three countries: belonging adds to welfare and moves the hand-to-mouth share by less than 0.03 and effort by less than 0.01; A widens the participation gap between the education cells (France 0.02 to 0.09, Germany 0.01 to 0.10, Italy 0.01 to 0.05); every calibrated configuration hits its own targets, balances its budget and has an MPC between 0.27 and 0.36.

**Open, seen in the pass: income poverty is a step function of the income grid.** Germany G at its own calibration has 0.174 below half the median; the same economy at the G+S+A parameters has 0.064, with nothing else moving. France goes from 0.076 to 0.144 when A is switched on. With eleven income states a state crossing the line moves the rate by several points. Not usable as an indicator until the line is interpolated or the grid is finer. The same applies to in-work poverty.

**Places (E) in version 3.** Germany G+S+A+E calibrated (participation 0.279, cells on target, multiplier 1.7 to 1.8, hand-to-mouth 0.232; five hours over two jobs). Germany G+E and G+A+E fitted and then crashed on a missing field in the report line; France and Italy were cancelled at the six-hour limit inside the fit. Fixed: the fit stops on the moments it owns (it had been running all sixteen steps after liquid wealth, which is not required), keeps its place across jobs, and starts a place configuration from the same one without places. Relaunched (runs 37213300219, 37213302262).

**Two assets.** The moments move with the illiquid grid: liquid wealth over income 0.213 at 24 nodes and 0.163 at 48, wealthy hand-to-mouth 0.134 and 0.176, net wealth over income 4.53 and 5.17 (`probe_two_asset_grid_FR.txt`). 96 and 192 nodes do not fit on a runner. The solver now lets an adjuster choose targets between the nodes (`k_sub`; 1 is the old behaviour and the default), with the value interpolated linearly between the two nodes' inner solutions and the mass split between them. Under test on a runner (24 nodes with 1, 4 and 16 targets per interval; the first must reproduce 0.213).

## 18. The place layer fails the wealth test (2026-10-04)

`test_place_wealth.jl`, Italy, version 3, G+E and G+A+E, 21 TL2 regions, nothing in E fitted to wealth. Against the HFCS 2021:

| | North | Centre | South and Islands | by region (19), correlation |
|---|---|---|---|---|
| Hand-to-mouth, model (G+A+E) | 0.247 | 0.152 | 0.102 | minus 0.66 |
| Hand-to-mouth, HFCS | 0.096 | 0.151 | 0.316 | |
| Liquid-asset poverty, model | 0.488 | 0.447 | 0.320 | minus 0.83 |
| Liquid-asset poverty, HFCS | 0.248 | 0.273 | 0.505 | |
| Income poverty, model | 0.165 | 0.171 | 0.207 | plus 0.86 |
| Income poverty, HFCS | 0.058 | 0.096 | 0.291 | |

The model orders the regions the wrong way round on both buffer indicators. Where unemployment risk is high, its households hold more liquid wealth, and where jobs are safe they hold less: the precautionary motive, working as it should, against the data. Income poverty has the right order and a quarter of the spread. This is the same failure the HFCS showed for version 2 (section 14), now measured region by region. The regional comparison reads the HFCS codes IT1 to IT20 as ISTAT's; the three macro-regions do not depend on that.

What the literature says is missing: a means-tested floor, under which low-income households have no reason to save (Hubbard, Skinner and Zeldes 1995). The floor is built and off in the baseline. Italy had one in 2021 (Reddito di cittadinanza, 0.27 of the gross average wage). The test takes the floor as a second argument; run with it on next.

## 19. Two assets: what killed the runs, and what the grid does (2026-10-04)

**Memory.** `two_asset_welfare_parts` assembled the decision operator times the income transition (every branch times every income state, about 140 million entries on 24 nodes) and factorised it. One household problem went from 0.9 GB after the solve to 8 GB, or 16 GB on a shorter grid. That step, not the solver, killed the two-asset jobs on the runners and restarted the laptop three times on 3 October. It now evaluates the policy by iteration and never forms that operator: 1.0 GB a worker at 24 nodes, 1.5 at 48, 3.9 at 96, and 48 and 96 nodes complete on a runner for the first time. The transition triplets of the distribution are also released instead of being returned.

**The adjuster's target.** An adjuster used to choose illiquid wealth among the nodes and hold the remainder as liquid, so median liquid wealth was mostly remainder. Now (`k_sub` > 1): targets between the nodes, the value between two nodes interpolated linearly as for a keeper; one smoothed option per node, the best target in its interval; the value iteration on `k_sub` steps, then the targets refined by golden section and the value iteration continued at the refined targets, two rounds, so the value is that of the refined policy. `k_sub = 1` reproduces every earlier number exactly. Tried and dropped on the way: smoothing over every target (the branches multiplied), refining inside the value iteration (no convergence in 5000 iterations), a single refining pass (value and policy disagreed, and the result moved with the number of steps).

France G, effective patience 0.9595, fixed cost 0.0022 (`probe_two_asset_grid.jl`; liquid wealth over income, wealthy hand-to-mouth share):

| illiquid grid | nodes alone | 4 steps | 8 steps | 16 steps |
|---|---|---|---|---|
| exponential, 24 nodes | 0.213, 0.134 | 0.074, 0.267 | 0.068, 0.284 | 0.076, 0.264 |
| exponential, 48 | 0.163, 0.176 | 0.041, 0.380 | 0.042, 0.369 | |
| exponential, 96 (one refining pass) | 0.154, 0.208 | 0.042, 0.380 | | |
| dense to 8 (`k_mid`), 24 | 0.191, 0.150 | 0.046, 0.341 | 0.047, 0.336 | |
| dense to 8, 32 | | 0.033, 0.385 | | |
| dense to 8, 40 | | 0.029, 0.413 | | |

What stands: the number of steps no longer matters; on the nodes alone liquid wealth is three to five times too high at any grid that can be run; with targets it is 0.03 to 0.05 at this point and the wealthy hand-to-mouth share 0.34 to 0.41. What is left open: about 0.01 on liquid wealth over income, 0.04 on the wealthy hand-to-mouth share, 4% on net wealth over income, depending on the grid. The MPC falls with the grid, 0.15 at 24 exponential nodes to 0.09 at 96: at this fixed cost the wealthy hand-to-mouth withdraw almost for free and are not constrained.

Consequence for version 2: its two-asset calibrations were fitted on the nodes alone. Their liquid moments and wealthy hand-to-mouth shares are remainder between nodes, and their fixed costs are not estimates of anything. They are not to be used.

The version 3 calibration (`calibrate_two_asset_v3.jl`) runs on the dense grid with 32 nodes and 4 steps, with the band on the wealthy hand-to-mouth share widened to 0.04. France G launched (run 37231504506).

**The floor with places.** The regional wealth test with Italy's 2021 floor ran three hours, with 9410 household problems at the iteration limit and the floor's tax unsettled 36 times, and then failed on a print line. Its numbers would not have been usable. The one-asset iteration now relaxes when it stops improving, with the floor on only. Rerun started.

## 20. Two assets, France G, the first calibration on the corrected solver (2026-10-04, run 37231504506)

Dense illiquid grid, 32 nodes, 4 targets to an interval; four hours, 13 solves at 16 to 18 minutes on a runner.

| | start (fixed cost 0.006) | best fit (fixed cost 0.013) | HFCS 2021 |
|---|---|---|---|
| Net wealth over income | 4.63 | 4.81 | 4.78 |
| Liquid wealth over income | 0.055 | 0.112 | 0.059 |
| Poor hand-to-mouth | 0.047 | 0.044 | 0.038 |
| Wealthy hand-to-mouth | 0.324 | 0.250 | 0.184 |
| **MPC, untargeted** | 0.147 | **0.146** | **0.39** (self-reported) |
| MPC of the poor, of the wealthy hand-to-mouth | | 0.34, 0.17 | |
| Net wealth Gini, untargeted | | 0.652 | 0.676 |
| Top 10% share of net wealth, untargeted | | 0.461 | 0.499 |
| Consumption drop on job loss | | 0.07 | 0.15 (INSEE) |

Not calibrated: liquid wealth is at 1.8 bands and the wealthy hand-to-mouth share at 1.7, and the search found no better point. The two pull against each other through the fixed cost: a low cost gives little liquid wealth and many households at zero, a high cost the reverse, and the data have little liquid wealth and few at zero.

What it settles. The two-asset model gets the wealth distribution about right without being asked to (Gini, top share, net wealth) and does NOT deliver the MPC: 0.15 against 0.34 in the one-asset liquid model and 0.39 in the survey. With a year as the period and a fixed cost of 3% of annual income, the wealthy hand-to-mouth adjust within the year and spend 17% of a windfall. So the division of labour stands as decided on 3 October: one asset for spending behaviour and for the S, A and E switches, two assets for the wealth distribution. Two assets is not a route to a higher MPC in this model.

## 21. The regional wealth test, what was tried (2026-10-04, evening)

Italy G+A+E, hand-to-mouth share by macro-region (HFCS: North 0.096, Centre 0.151, South and Islands 0.316):

| | North | Centre | South | by region, correlation | national |
|---|---|---|---|---|---|
| base | 0.247 | 0.152 | 0.102 | minus 0.66 | 0.180 |
| floor 0.15, financed nationally | 0.343 | 0.306 | 0.232 | minus 0.85 | 0.298 |
| floor 0.20 | 0.354 | 0.342 | 0.260 | minus 0.84 | 0.321 |
| South poorer (`:conversion_hh`: income 0.77 of the North's; Eurostat 0.68) | 0.278 | 0.178 | 0.093 | minus 0.76 | 0.196 |
| South poorer, floor 0.15 | 0.339 | 0.311 | 0.224 | minus 0.84 | 0.295 |
| South poorer, floor 0.20 | 0.367 | 0.322 | 0.352 | minus 0.28 | 0.353 |

Neither a floor nor a poorer South reverses the order, alone. Together, at the higher floor, the South catches up with the North and the correlation goes from minus 0.84 to minus 0.28: the mechanism of Hubbard, Skinner and Zeldes (1995) is there, but at these levels the national share is twice the data's, so the test is not a fair one until patience is recalibrated with the floor on.

What had to be fixed to run it: the floor is financed by the nation (each place had been raising the tax for its own, which a poor place cannot); the tax iteration no longer starts from a failed run's NaN and is damped; with a floor the job's effort levels are the no-floor economy's (`floor_effort`); the household iteration relaxes when it stops improving, floor on only. With the floor off nothing changes (on/off pass 16 of 16 in France and Italy on the new code).

Why the order is wrong in the base: the model's South is riskier, not poorer, and an unemployed household keeps its replacement income for as long as it is unemployed. Long-term unemployment enters only as a lower job-finding rate (`f_find` is one minus the long-term share). A household facing a long spell saves for it and is never destitute. In Italy benefits end after at most two years and 60% of the unemployed in the South are long-term.

Two candidate changes to the base, for decision, neither made:
1. The floor on in the base, its level from the share of households on minimum-income support, patience recalibrated with it, and regional income on the household's view.
2. Benefit exhaustion: a long-term unemployed state with assistance in place of insurance.

**Places, version 3, calibrated today:** Germany G+E, G+A+E, G+S+E, G+S+A+E; France the same four; Italy G+E, G+A+E, G+S+A+E (G+S+E running). Twenty-three version 3 files in all.

## 22. The floor in the base: the floor regime (2026-10-04 night, 2026-10-05)

Decided by the user on 4 October: the means-tested floor first. `SAGE_V3=1 SAGE_FLOOR=1` for `calibrate_country.jl`, `-f v3=1 -f floor=1` for the workflow, `country_config(...; v3 = :floor)`, files `calibration_v3f_<CODE>_<CFG>.txt`. The 23 no-floor files stay as the comparison.

**Specification.** A means-tested floor (Hubbard, Skinner and Zeldes 1995) financed by the lump-sum tax, nationally when places are on. Patience the same for all, no spread. With a floor the job's effort levels are the no-floor economy's. In G the floor's level is a parameter and median liquid wealth is the moment it owns, beside the hand-to-mouth share that patience owns: at a given hand-to-mouth share a higher floor goes with more patient households holding more liquid wealth, which the spread could not give. In every other configuration the floor is the country's, read from its G file. Where the fit ends with the floor at zero it goes on without it (the hand-to-mouth share owns patience, liquid wealth is reported). A floor that cannot be financed is a point the fit steps away from. With places, regions differ by the household's income per head (`:conversion_hh`).

Not done as first proposed: the level was to come from the share of households on minimum-income support. That series was not found in the OECD data service, and no remembered figure was used. The recipient share is an untargeted check to add from an official source.

**G, three countries.**

| | floor chosen (share of reference earnings) | hand-to-mouth (data) | liquid wealth over income (data) | MPC (survey) |
|---|---|---|---|---|
| France | 0 | 0.223 (0.222) | 0.069 (0.059) | 0.34 (0.39) |
| Germany | 0 | 0.234 (0.225) | 0.217 (0.140) | 0.28 (0.47) |
| Italy | 0.147 | 0.183 (0.179) | 0.275 (0.272) | 0.29 (0.47) |

France and Germany want no floor, so their version 3 calibrations stand and are written out as floor-regime files with a floor of zero (Germany's minimum income is already inside its replacement rate, `data/benefits/`). Italy with a floor meets both wealth moments, which nothing else had done (0.158 against 0.272 without it). Italy G+A (0.177, 0.298) and G+S+A (participation 0.121, multiplier 1.3) are calibrated in the regime; G+S and G+E running.

What the floor does not do: the MPC (Italy 0.29, down from 0.31) and Germany's liquid wealth.

**The regional test in the regime.** At Italy's calibrated floor and patience (0.147, 0.882), G parameters with A and places on: still the wrong order, North 0.242, South 0.174, correlation minus 0.70. Pilots with a higher floor and more patience give the right one:

| floor | patience | national hand-to-mouth | North | South | correlation, hand-to-mouth | correlation, asset poverty |
|---|---|---|---|---|---|---|
| 0.20 | 0.891 | 0.259 | 0.256 | 0.293 | plus 0.39 | minus 0.56 |
| 0.20 | 0.911 | 0.197 | 0.181 | 0.245 | plus 0.62 | minus 0.02 |
| 0.20 | 0.931 | 0.137 | 0.115 | 0.186 | plus 0.79 | plus 0.57 |
| 0.25 | 0.921 | 0.232 | 0.212 | 0.261 | plus 0.89 | plus 0.59 |

Along the line that keeps the national hand-to-mouth share near its target, a low floor with low patience matches national liquid wealth and gets the regions wrong, a higher floor with more patience gets the regions right and (to be measured) puts national liquid wealth above the data. Italy's national wealth moments are imprecise in the survey (standard errors 0.028 and 0.029) and the regional gap is not (North 0.096 with 0.014, South 0.316 with 0.033). Six runs along the line measure whether a point exists with the regions right and both national moments within two standard errors; if so the regional gap is the better moment for the floor.

Also seen: the model's North has 16% below half the median income against 6% in the data. Every place has the same dispersion of income, so the North has too many low-income households, which holds its hand-to-mouth share up. Not addressed.

**The six runs along the line (Italy G+A+E, regions by household income, national hand-to-mouth share held near 0.18).**

| floor | patience | national hand-to-mouth | national liquid wealth over income | correlation, hand-to-mouth | correlation, asset poverty | MPC |
|---|---|---|---|---|---|---|
| 0.147 | 0.895 | 0.178 | 0.34 | minus 0.50 | minus 0.76 | 0.27 |
| 0.17 | 0.900 | 0.189 | 0.38 | minus 0.61 | minus 0.77 | 0.27 |
| 0.185 | 0.908 | 0.191 | 0.47 | plus 0.46 | minus 0.50 | 0.24 |
| 0.20 | 0.916 | 0.182 | 0.60 | plus 0.67 | plus 0.17 | 0.24 |
| 0.22 | 0.925 | 0.176 | 0.79 | plus 0.82 | plus 0.59 | 0.22 |
| 0.25 | 0.936 | 0.184 | 1.12 | plus 0.90 | plus 0.66 | 0.19 |

No admissible point. The regions come out the right way round only where national liquid wealth is 0.47 of income or more, against 0.27 in the survey with a standard error of 0.028; and the MPC falls further. In the model the order turns when the patient households of the North hold half a year's income in liquid form, which they do not.

So the floor settles Italy's national wealth moments and does not settle the regional order. What the runs point to instead: the regions' income distributions are too alike in the model. Its North has 16% below half the median against 6% in the survey, its South 21% against 29%. The mean gap is 0.77 where Eurostat has 0.68, and the eleven income states are 45% apart, so a place a quarter poorer moves at most one state across the line or the floor. Three runs with twenty-one income states test that (2026-10-05).

## 23. A long-term out-of-work state, and where the regional order stands (2026-10-05)

**Why.** Eurostat's share of people under 65 in households with very low work intensity (ilc_lvhl21n, 2021): Lombardy 4.9%, Veneto 4.6%, Emilia-Romagna 3.8%, Campania 27.6%, Sicily 22.1%, Sardinia 18.6%. The model had no such households: everyone out of work was unemployed on a benefit that never ended (the replacement rate is the average over a five-year spell, `data/benefits/`).

**What was built, off by default** (`f_long`, `assist_long`; `unemployment_process` with `fL`; place channel `:jobless`; `probe_longterm.jl`). Three blocks of states, (U, E, L). U is the first year out of work, insured as before; it ends in work with the job-finding rate and in L otherwise. L pays assistance, a flat transfer at the floor's level, taxed like insurance, and ends in work with a yearly probability. By place the mass of L is the quasi-jobless share beyond the first-year unemployed, split between the education cells in proportion to their unemployment; the exit rate follows from the two masses. Nothing is fitted. Without the state every result is unchanged (on/off pass 16 of 16 for Italy on the new code). The code that assumed two blocks (dread, the agency summary) is general; two assets refuse the state.

Two failures on the way: with no income of their own the L households had negative resources after the lump-sum tax and the household problem returned nothing finite, so assistance is a transfer and not the floor's top-up; and the job's effort levels cannot come from the economy without the floor when the state is on, so they come from the economy without either.

**Italy G, floor regime, the state on nationally (exit 0.20, masses 9% and 4% by cell):** hand-to-mouth 0.156 (0.183 without), liquid wealth over income 0.74 (0.275), MPC 0.22 (0.29). Households save against it. It is not a switch to add to a calibrated economy: patience has to be refitted.

**Italy G+A+E, the state by place, floor 0.147:**

| patience | national hand-to-mouth | national liquid wealth over income | North | South | correlation, hand-to-mouth | income poverty, North and South (HFCS 0.058, 0.291) |
|---|---|---|---|---|---|---|
| 0.80 | 0.46 | 0.04 | 0.55 | 0.33 | minus 0.85 | 0.145, 0.293 |
| 0.84 | 0.31 | 0.18 | 0.37 | 0.23 | minus 0.80 | 0.145, 0.292 |
| 0.87 | 0.21 | 0.41 | 0.25 | 0.17 | minus 0.68 | 0.176, 0.290 |
| 0.895 | 0.15 | 0.73 | 0.16 | 0.13 | minus 0.48 | 0.178, 0.289 |

The state gives the South its income poverty (0.29 against 0.291) and does not turn the order of the buffers at any patience. More households are in the state in the South, and the rest of the South saves against ending there.

**Where this leaves the regional order.** Four things tried, in this order: a floor (turns it only with national liquid wealth at 0.47 of income or more), a poorer South (no), twenty-one income states (no solution as the process stands), the long-term state (no). In every one the model holds more buffers where risk is higher, which is what a Bewley household does. The survey has fewer buffers where incomes are lower. What the model lacks is a reason for richer households to hold liquid wealth that is not precaution: its North is hand-to-mouth because its jobs are safe and its patience is the low one the national share needs. The literature's answer is saving that rises with permanent income (Dynan, Skinner and Zeldes 2004; a wealth motive as in Carroll 2000 and De Nardi 2004; Straub 2019), beside the floor for the poor (Hubbard, Skinner and Zeldes 1995). That is a change to preferences and a new set of moments (liquid wealth by income), not built, for decision.

**Dead end:** twenty-one income states. The Rouwenhorst grid widens with the number of states, the lowest then earn 3% of the mean, cannot pay the lump-sum tax, and the floor cannot be financed.

## 24. Who is hand-to-mouth: patience by education (2026-10-05)

**The test that located the problem** (`test_cell_wealth.jl`). The regional question, asked inside each country on well-measured data: the model's two education cells are the HFCS's two groups.

| G+A, version 3 | model, below tertiary | model, tertiary | HFCS, below tertiary | HFCS, tertiary |
|---|---|---|---|---|
| France | 0.066 | 0.534 | 0.256 (s.e. 0.009) | 0.151 (0.009) |
| Germany | 0.196 | 0.316 | 0.285 (0.015) | 0.118 (0.015) |
| Italy | 0.108 | 0.481 | 0.196 (0.034) | 0.095 (0.030) |

0 of 3, in G as in G+A. The national hand-to-mouth share was on target and made of the wrong households: with one patience for all, the cell with the safer jobs holds no buffer and the cell with the riskier jobs saves. The same mechanism as the regions, in every country, in the core of the model. It bears on A (who is exposed when hit) and on where the MPC comes from.

**The regime** (`SAGE_EDU=1` with `SAGE_V3=1`, workflow `-f edu=1`, `country_config(...; v3 = :edu)` or `:floor_edu`, files `calibration_v3e_*` and `calibration_v3fe_*`; `beta_cell` in the configuration, `beta_gap` in the files). The lower-education cell's discount factor lies a gap below the other's. The gap is a parameter of the fit and the difference between the cells' hand-to-mouth shares in the HFCS is the moment it owns. No spread within a cell. With places the gap is the one found without them. Estimated patience rises with education and income: Cagetti (2003, Journal of Business and Economic Statistics 21(3), 339 to 353) estimates time preference by education group from wealth profiles, and Lawrance (1991, Journal of Political Economy 99(1), 54 to 77) from consumption panels. Both references were confirmed to exist with these details on 2026-10-05; the papers were not reread, so their numbers are not quoted.

**G, with the gap.**

| | patience, tertiary | gap | hand-to-mouth by cell, model (HFCS) | national (data) | liquid wealth over income (data) | MPC (survey) |
|---|---|---|---|---|---|---|
| France | 0.912 | 0.050 | 0.255, 0.154 (0.256, 0.151) | 0.220 (0.222) | 0.089 (0.059) | 0.31 (0.39) |
| Germany | 0.929 | 0.041 | 0.278, 0.118 (0.285, 0.118) | 0.234 (0.225) | 0.220 (0.140) | 0.27 (0.47) |
| Italy | 0.885 | 0.079 | 0.192, 0.087 (0.196, 0.095) | 0.175 (0.179) | 0.044 (0.272) | 0.39 (0.47) |
| Italy, floor too (0.215) | 0.928 | 0.047 | gap 0.087 (0.102) | 0.198 (0.179) | 0.277 (0.272) | 0.30 (0.47) |

Not right, untargeted: liquid wealth of the tertiary cell is far too high (France 0.34 of the national median income against 0.07 of its own in the HFCS, Germany 0.84 against 0.28). The patient cell holds in liquid form what graduates hold in houses and pensions; one asset cannot separate them.

**The regional order, at calibrated parameters.** Italy, the floor and the gap as fitted in G (floor 0.215, patience 0.928 and 0.881), with A and places on and nothing refitted:

| | North | Centre | South and Islands | by region, correlation |
|---|---|---|---|---|
| Hand-to-mouth, model | 0.246 | 0.263 | 0.303 | plus 0.62 |
| Hand-to-mouth, HFCS | 0.096 | 0.151 | 0.316 | |
| Liquid-asset poverty, model | 0.423 | 0.414 | 0.421 | minus 0.38 |
| Liquid-asset poverty, HFCS | 0.248 | 0.273 | 0.505 | |

National liquid wealth over income 0.234 (HFCS 0.272, s.e. 0.028): inside two standard errors. The order of the hand-to-mouth is right for the first time at parameters that were fitted and not set by hand, and with national liquid wealth in range. Still wrong: the spread is a third of the survey's, the North's level is two and a half times the survey's, asset poverty is flat across regions, and the national hand-to-mouth share is 0.27 here because A and places were switched on without refitting. The run that counts is the same test at Italy's own G+A+E calibration in this regime (calibrations launched).

## 25. The combined regime as a candidate base (2026-10-05, 05:00)

`calibration_v3fe_*`: version 3 with the means-tested floor and patience by education. Twelve files: G, G+A, G+S, G+S+A in the three countries. France and Germany want no floor, so theirs are their education-regime calibrations with the floor written as zero; Italy's floor is 0.215 of reference earnings.

| | patience, tertiary | gap | hand-to-mouth, model (data) | by education, model (HFCS) | liquid wealth over income (data) | MPC (survey) | participation, multiplier in G+S+A |
|---|---|---|---|---|---|---|---|
| France G+A | 0.929 | 0.074 | 0.223 (0.222) | 0.260, 0.153 (0.256, 0.151) | 0.077 (0.059) | 0.31 (0.39) | 0.233, 1.8 |
| Germany G+A | 0.942 | 0.050 | 0.231 (0.225) | 0.277, 0.113 (0.285, 0.118) | 0.208 (0.140) | 0.26 (0.47) | 0.280, 1.7 |
| Italy G+A | 0.934 | 0.047 | 0.179 (0.179) | 0.197, 0.094 (0.196, 0.095) | 0.302 (0.272) | 0.29 (0.47) | 0.121, 1.3 |

**Validation, all on runners.** On/off pass (`onoff_v3.jl floor edu`): 16 of 16 in each country. By education (`test_cell_wealth.jl GA v3fe`): 3 of 3. MPC properties (`test_mpc_economics.jl <CODE> GA v3fe`): 7 of 7 in each country, the floor's withdrawal counted in the adding up. Participation and the multiplier are as in version 3.

**What it gets right that version 3 did not:** who is hand-to-mouth, in every country; Italy's liquid wealth with its hand-to-mouth share; the order of the hand-to-mouth across Italian regions (plus 0.62, at G parameters with A and places on; the run at Italy's own G+A+E calibration is pending).

**What it does not, stated:**
- the MPC is no higher (France lower, 0.31 against 0.34 in version 3);
- Germany's liquid wealth (0.21 against 0.14);
- the liquid wealth of the tertiary cell, untargeted, several times too high (France 0.75 of the national median income, Germany 1.58, Italy 1.51, against 0.07, 0.28 and 0.42 of the group's own income in the HFCS): the patient cell holds in liquid form what graduates hold in houses and pensions;
- the spread across Italian regions (a third of the survey's) and regional asset poverty (flat);
- income poverty and in-work poverty remain step functions of the income grid;
- the multiplier still rests on the private share of belonging.

**Not yet in the regime:** the place configurations (Italy G+E and G+A+E running; France and Germany not started), two assets.

**For decision:** whether this regime becomes the base in place of version 3. It costs one preference parameter per country, identified by one well-measured moment, and for Italy the floor. The alternative that addresses the same failure without preference differences is saving that rises with permanent income (section 23), not built.

**Italy with places in the combined regime does not calibrate (2026-10-05, 08:40, run 37279073188).** G+A+E, the floor (0.215) and the gap (0.047) held from the configurations without places: the fit stops at a hand-to-mouth share of 0.211 against 0.179 with liquid wealth over income at 0.41 against 0.27. More patience would lower the first and raise the second. G+E is at the same place after three steps (0.214, 0.42) and has handed over to a new job.

So the statement in section 24 needs its limit. The order of the hand-to-mouth across Italian regions is right (plus 0.62) at the G parameters with A and places switched on, where the national share is 0.27 and liquid wealth 0.23. There is no point yet at which the regions are in the right order AND both national moments are met with places on: the tension of section 22 is smaller with patience by education (liquid wealth 0.41 where the floor alone needed 0.60 for the same hand-to-mouth share) and is not gone. What would close it is in the list already: regions whose income distributions differ as the survey's do, or a reason other than precaution for the better-off to hold liquid wealth.

The floor's level with places on is the open design question for Italy: fitted in G it is too high once the poorer regions are in. Options, not tried: fit the floor in G+E, or give the national hand-to-mouth share with places a wider band (the survey's standard error is 0.029).

## 26. Closing out: the base adopted, and the order of the last work (2026-10-05, decided by the user)

**The base is the combined regime** (`calibration_v3fe_*`, `BASE_REGIME = :floor_edu`, `base_config(code; ...)` in `sage_modular.jl`): version 3 with the means-tested floor and patience by education. Version 3 without them stays as the stated alternative, and headline results are reported under both. The patience gap is to be described as standing for whatever makes graduates save more (pensions, life-cycle saving, bequests), not as a claim about people.

**Scope, stated.** One asset: spending behaviour and liquid buffers at the bottom of the distribution. Not claimed: the MPC's level beyond about 0.3, the liquid wealth of graduates, buffers by region. E: participation, income and risk across places. Two assets: the wealth distribution, when someone asks for it.

**The order, and where each stands.**

| | step | state |
|---|---|---|
| 1 | Adopt the base and freeze it | done in code and here; the tag follows once Italy with places is settled |
| 2 | Indicators: shares below an income line from each income state spread over its interval (`ysmooth`, 9 sub-points in the version 3 regimes) | built; no calibration target reads these shares; check running |
| 3 | The floor fitted on the configuration with places (`SAGE_FLOOR_FROM=GE`, workflow `floor_from`), one rule for every country | running for the three countries (run 37353825682); Italy's other configurations follow from its result |
| 4 | The policy layer on the base (`policy_tests.jl` with `SAGE_REGIME`, workflow `policy.yml -f regime=v3fe`): subsidy, empowerment, insurance up and down, and the floor as a policy | running for France and Germany; Italy after step 3 |
| 5 | The multiplier as a band: the policy tests carry the private share of belonging at 0.15 and 0.60 beside the calibrated 0.30; `estimate_omega.jl` sets the spread of participation across regions against the data's | running for Germany; Italy after step 3 |
| 6 | The income process of the next version: a transitory shock beside the persistent one, and a proportional tax in place of the lump sum | planned, not started; it changes every calibration |
| 7 | Two assets | left until asked for |

## 27. The gold standard and the readiness scorecard (proposed 2026-10-05, for the user's agreement)

**The product.** A Bewley economy (G) on which S, A and E switch on in any order, each fitted to its own data, in which a policy or a shock can be run and its effects read on wellbeing indicators. Three audiences have to accept it.

**What "ready" means.** A calibrated stationary equilibrium in every configuration and country; transition paths for a policy or a one-off shock; no aggregate uncertainty. Partial equilibrium with the interest rate given (a member of a currency union), stated as such. Every status update reports against the table below.

| | criterion | state on the base, 2026-10-05 | what is being done |
|---|---|---|---|
| **Macroeconomists** | | | |
| M1 | Stationary equilibrium, budget balanced, closure stated | met | |
| M2 | Standard building blocks: CRRA, persistent and transitory income risk, unemployment, a proportional tax | partly: no transitory shock, lump-sum tax | next version (section 26, step 6) |
| M3 | Every parameter from a source or identified by a named moment; identification shown | partly: the private share of belonging is a band; identification table not yet on the base | band in place; table to run |
| M4 | Every configuration hits its own targets in every country | partly: France and Germany 8 of 8, Italy 4 of 8 | the floor fitted with places, running |
| M5 | Spending behaviour untargeted: MPC and its properties, consumption on job loss | partly: properties hold, level about 0.3, consumption absorbs too much of a loss | level accepted and stated |
| M6 | Who holds no buffer | met by education (targeted); not by region | regional buffers a stated limit |
| M7 | The wealth distribution | not met on one asset; two assets not calibrated | left until asked for |
| M8 | Transitions for policies and shocks | built on version 2, not run on the base | to run |
| **Numerical economists** | | | |
| N1 | A standard, documented method (endogenous grid with upper envelope, non-stochastic simulation) | met | |
| N2 | Exact reductions when a switch is off | met (on/off pass 16 of 16 in each country) | |
| N3 | Accuracy on the base: Euler errors, convergence in the asset grid, its top, and the income grid | partly: France 7 of 7, Germany 6 of 7 (section 28); Italy and the income grid not run | Italy with its base; income grid in the next version |
| N4 | An independent solver agrees | on version 2 only | to check what carries over |
| N5 | Reproducible: public code, continuous integration, one command per result, data manifest | mostly met | |
| N6 | Equilibria with S counted and stable | met in France and Germany: one stable equilibrium, the solver's (section 28) | Italy with its base |
| **Beyond-GDP** | | | |
| B1 | The dimensions are a recognised framework's | S and A yes; E is place here, where the framework's E is the environment | for the user's decision |
| B2 | Each dimension measured on official data | met | |
| B3 | Recognised indicators, stable and checked against official figures | partly: income poverty smoothed today; checks to tabulate | table to build |
| B4 | Welfare split by dimension and by group | computed; not tabulated on the base | table to build |
| B5 | Accessible: switches, a notebook, a site | switches yes; the site is the first baseline only | later |
| **Use** | | | |
| U1 | Any order of switches, each calibrated | France and Germany | Italy with places |
| U2 | Policy levers with honest bands | band in place; check running | read as a model check only |
| U3 | A new country added by the checklist | not tried | later |

Count: 7 met, 11 partly, 4 not, of 22 (evening of 2026-10-05: N3 from not to partly, N6 to met; 6, 11, 5 before).

**The user's direction on this table (2026-10-05, afternoon).**
- The macroeconomists' rows come first, each to be met as far as it can be, the wealth distribution included. So M7 is no longer left: two assets come back as the route to it.
- The numerical rows can be extended later, once the model works and has no bugs. The accuracy run already started is read and not extended.
- E is the lived environment in both senses: the opportunities of a place, and the climate and natural environment. The environmental side returns to E as part of the dimension (the indicators: footprint, exposure), not as policy.
- Welfare tables and accessibility come later.
- The interest rate is given, an assumption that fits a currency union. A version in which it is determined inside the model is a validation test for afterwards, to be noted and not built now.
- Transitions are part of ready.

What this changes in the order: three changes to the base are now implied by the macro rows (a transitory shock and a proportional tax; two assets for wealth; possibly a shorter period for the MPC on two assets). Each changes every calibration, so the architecture is to be settled first, on probes, and calibrated once.

## 28. The probes before the build, and what else came in (2026-10-05, evening)

**Numerical evidence on the base (rows N3 and N6), France and Germany.** `numerics_base.jl`, runs 37361581090 and 37361588838. Mean Euler error 10^-5.5 to 10^-5.8 in every household problem, worst 10^-3.6 (over the 80 to 94% of households neither constrained nor on the floor). Doubling the asset grid moves no moment by half its tolerance. Doubling its top passes everywhere except one row: Germany G+S+A, where participation moves by 0.0036 (the top of the grid at 4 years of mean income is slightly low for Germany's patient group). One stable participation equilibrium in G+S and G+S+A in both countries, and it is the solver's. France 7 of 7, Germany 6 of 7. Not extended, by the user's ordering. The income grid is not in this run.

**The private share of belonging, Germany.** `estimate_omega.jl DE v3fe`, 16 Länder. The model's regional spread of participation equals the data's (0.084) at a private share between 0.15 and 0.30, about 0.2. Because common regional causes also spread participation (Manski 1993), this is a lower bound on the private share, so an upper bound on the multiplier of about 2.3. The band for Germany narrows from 1.2 to 2.8 to 1.2 to 2.3. Italy's run did not start (it asked for a v3e file that does not exist) and waits for Italy's base.

**The floor fitted with places.** Germany G+E under the rule `floor_from=GE` chose no floor (hand-to-mouth 0.231 against 0.22, in band) and France likewise, so the rule changes nothing there. Italy G+E under the rule (run 37353825682, 236 minutes): calibrated. The floor is 0.145 of reference earnings (0.215 when fitted in G), hand-to-mouth 0.180 against 0.18, liquid wealth over income 0.272 against 0.272, MPC 0.283 untargeted. So Italy with places does calibrate when the floor is fitted where the places are. Its other configurations are not refitted on this base, because the income process is about to change (probe 3) and every calibration with it.

**Probe 1. Two assets with patience by education: it does not give the wealth distribution by education.** `probe_two_asset_grid.jl FR 0.9578|0.9650|0.9720 0.0131 32:4 150 8 gap`, not recalibrated.

| | gap 0 | gap 0.03 | gap 0.05 | HFCS |
|---|---|---|---|---|
| Net wealth over income | 5.06 | 2.70 | 1.89 | 4.78 |
| Liquid over income | 0.118 | 0.128 | 0.136 | 0.059 |
| Poor, wealthy hand-to-mouth | 0.029, 0.258 | 0.032, 0.216 | 0.036, 0.183 | 0.038, 0.184 |
| MPC | 0.138 | 0.140 | 0.150 | 0.39 to 0.47 |
| Net wealth Gini | 0.642 | 0.706 | 0.776 | 0.676 |
| Top 10% share | 0.460 | 0.553 | 0.652 | 0.499 |
| Hand-to-mouth, below tertiary and tertiary | 0.275, 0.309 | 0.219, 0.305 | 0.203, 0.248 | 0.256, 0.151 |
| Net wealth by education | 5.08, 5.02 | 1.78, 6.95 | 0.95, 9.02 | 4.45, 5.44 |

Without a gap the Gini (0.64 against 0.68) and the top share (0.46 against 0.50) are close, which is the case for two assets as the reference for wealth. The gap, which on one asset puts the hand-to-mouth in the right group, here empties the less educated of net wealth and leaves graduates hand-to-mouth at 0.25 to 0.31 against 0.15: on two assets a graduate who is hand-to-mouth is one who has put wealth in the illiquid asset, and patience raises that. The education pattern on two assets therefore needs something other than patience (a candidate: the fixed cost or the return by education, since access to the illiquid asset differs by education). The MPC stays at 0.14 to 0.15 whatever the gap.

**Probe 2. The period on two assets** (`probe_two_asset_period.jl`, runs 37379989414 and 37379993283, started 22:03 UTC). On one asset the period was settled as irrelevant to the annual MPC (section 3, `probe_mpc_period.jl`). On two it can matter because the period is also how often the fixed cost can be paid. The quarterly problem is the annual one disaggregated (fourth roots of the transition matrix, the discount factor, the returns and survival; flows a quarter; the fixed cost and wealth unchanged in goods), at the same fixed cost and at three times it. It reports the MPC within the period and over the year for the poor hand-to-mouth, the wealthy hand-to-mouth and the rest, and how many of the wealthy hand-to-mouth adjust in a period, which is the diagnosis of the 0.15.

**Probe 3. A transitory shock and a proportional tax on one asset: the transitory shock is the missing piece.** `probe_transitory_tax.jl FR`, run 37379996565, France G, v3e, not recalibrated. A three-node independent draw on the income of the employed (standard deviation 0, 0.15, 0.25, probe values, not yet sourced), the benefit bill raised lump-sum or in proportion to labour income (3.8% of it), each at three levels of patience and once with the benefit rate ten points higher. Liquid wealth is over mean income here.

| transitory | tax | patience | htm | MPC | MPC of htm | liquid/income | fall on job loss | htm, benefit rate +10 points |
|---|---|---|---|---|---|---|---|---|
| none | lump-sum | fitted | 0.221 | 0.305 | 0.436 | 0.075 | 0.205 | 0.432 (+0.211) |
| none | lump-sum | -0.02 | 0.470 | 0.369 | 0.487 | 0.023 | 0.240 | |
| none | proportional | fitted | 0.439 | 0.366 | 0.541 | 0.034 | 0.195 | 0.546 (+0.107) |
| sd 0.15 | lump-sum | fitted | 0.132 | 0.339 | 0.574 | 0.161 | 0.160 | 0.165 (+0.033) |
| sd 0.15 | lump-sum | -0.02 | 0.188 | 0.398 | 0.576 | 0.104 | 0.181 | |
| sd 0.15 | lump-sum | -0.04 | 0.265 | 0.452 | 0.589 | 0.072 | 0.199 | |
| sd 0.15 | proportional | fitted | 0.193 | 0.366 | 0.574 | 0.127 | 0.146 | 0.235 (+0.042) |
| sd 0.15 | proportional | -0.02 | 0.270 | 0.425 | 0.588 | 0.085 | 0.163 | |
| sd 0.25 | lump-sum | fitted | 0.104 | 0.321 | 0.567 | 0.277 | 0.126 | 0.104 (-0.001) |
| sd 0.25 | lump-sum | -0.04 | 0.159 | 0.419 | 0.585 | 0.151 | 0.155 | |
| sd 0.25 | proportional | fitted | 0.122 | 0.342 | 0.565 | 0.238 | 0.114 | 0.130 (+0.008) |
| sd 0.25 | proportional | -0.04 | 0.198 | 0.438 | 0.576 | 0.126 | 0.139 | |

Read at a like hand-to-mouth share of 0.22 (interpolating in patience):
- **The MPC.** 0.305 without the transitory part, about 0.42 with a standard deviation of 0.15 under the lump-sum tax and about 0.39 under the proportional one, against a target of 0.39 to 0.47. Liquid wealth at that point is about 0.09 to 0.11 of mean income against 0.075 at the base.
- **The response to the benefit rate.** Ten points more put 21 points more of households hand-to-mouth in the base. With the transitory part it is 3 to 4 points at 0.15 and nil at 0.25 (at fitted patience, so at a lower hand-to-mouth share; to be confirmed at the recalibrated point). The base's buffers exist only against job loss, so anything that changes income out of work moves them at once. The same knife edge shows in the tax row: moving a tax of 2% of mean pay off the unemployed doubles the hand-to-mouth share (0.221 to 0.439) without the transitory part, and moves it by 0.06 (0.15) or 0.02 (0.25) with it.
- **The fall in consumption on job loss.** 0.205 at the base, about 0.19 at a like hand-to-mouth share with 0.15 and 0.15 to 0.16 with 0.25. Better, not repaired.
- **The proportional tax** does not by itself reduce the response to the benefit rate once the transitory part is in (0.042 against 0.033). Its case is the standard one (row M2) and that the lowest income states can pay it, which the lump-sum tax prevented on a finer income grid (section 21).

Limits of the probe: not recalibrated (the transitory part widens the cross-section, so the persistent dispersion will fall when refitted to S80/S20, and patience was shifted for everyone alike); three nodes; the size of the transitory part is still to be taken from a source for each country and must not be fitted to the MPC, which stays untargeted.

**The same probe in Germany and Italy** (runs 37380370200 and 37380374464). The result holds in all three countries. At a like hand-to-mouth share the MPC goes from 0.27 to about 0.40 in Germany and from 0.39 to about 0.42 in Italy. Ten points of benefit rate add 0.06 of hand-to-mouth households in Germany's base and 0.38 in Italy's, against 0.02 and 0.05 with a transitory part of 0.15. Two things to watch at the recalibration: Germany's liquid wealth at a like hand-to-mouth share falls to about 0.10 of mean income from 0.19, and Italy's rises to 0.10 from 0.04 without a floor (so the transitory part does some of the floor's work there). The fall in consumption on job loss stays high in Italy (0.35 against 0.39).

**The size of the transitory part, from the model's existing source.** Bayer and Juessen (2012, Economics Letters 117(3), 831-833), Table 1, read from the discussion-paper version (IZA DP 4402, to be checked against the published table): for household hourly wages, the variance of the transitory term (or measurement error) is 0.0316 in Germany (GSOEP), 0.0404 in the United Kingdom (BHPS) and 0.0440 in the United States (PSID), beside a persistence of 0.919, 0.925 and 0.925 and a variance of the persistent innovation at trend of 0.0102, 0.0192 and 0.0252. A standard deviation of 0.18 for Germany, so the probe's 0.15 was of the right size. The country table already takes the persistence from this table and had set the transitory term aside as measurement error (Floden and Linde 2001); it now comes in. Because it includes measurement error it is an upper bound on the risk, to be stated with a sensitivity row at half the variance.

**A weakness this exposes (row M3).** The persistent innovation fitted to S80/S20 has a standard deviation of 0.26 to 0.29 in the three countries, against 0.10 in the source. The fitted shock carries permanent differences between households that the two education cells do not (the source estimates a fixed effect beside the shock). This is common in Bewley models whose process is estimated without fixed effects, but it overstates persistent risk, and it is one reason fitted patience is as low as 0.91 to 0.93. To be decided in the architecture: keep the fit and say so, with the model's one-year and five-year income changes checked against the Global Repository of Income Dynamics (Guvenen, Pistaferri and Violante 2022, Quantitative Economics 13(4)) as an untargeted test, or add a permanent type.

**Two assets with the transitory part: the MPC does not move, and why.** `probe_two_asset_period.jl FR 0.9578 chi0 32:4 150 8 1 0.18`, France G, annual, transitory standard deviation 0.18, not recalibrated (runs 37386740426, 37389076438, 37389079348).

| fixed cost | net wealth | liquid | poor htm | wealthy htm | MPC, all | MPC, poor htm | MPC, wealthy htm | adjusting, all | adjusting, wealthy htm |
|---|---|---|---|---|---|---|---|---|---|
| 0.0131 | 4.72 | 0.113 | 0.038 | 0.226 | 0.139 | 0.335 | 0.154 | 0.51 | 0.73 |
| 0.05 | 4.24 | 0.284 | 0.040 | 0.120 | 0.139 | 0.360 | 0.156 | 0.28 | 0.72 |
| 0.15 | 3.71 | 0.543 | 0.042 | 0.067 | 0.133 | 0.375 | 0.129 | 0.15 | 0.73 |

(Ratios to mean annual income.) The transitory part, which lifts the one-asset MPC to 0.4, leaves the two-asset one at 0.14. The wealthy hand-to-mouth have the MPC of everyone else, and three in four of them adjust their illiquid wealth within the year, at every fixed cost: a higher cost makes fewer of them and does not make them constrained. So the households the model counts as wealthy hand-to-mouth are households about to withdraw, whose liquid wealth is low because the withdrawal is due, and not households sitting at zero liquid wealth and spending their income, which is what the term means in Kaplan and Violante (2014). My first reading (a fixed cost too low) is refuted by the second and third rows.

**The illiquid return paid out as liquid income, and the return on liquid wealth.** The illiquid return accrues inside the illiquid asset in the solver, so a household can spend its capital income (a quarter of labour income at these wealth levels) only by paying the fixed cost, and withdrawing is routine for anyone with illiquid wealth. In Bayer, Luetticke, Pham-Dao and Tjaden (2019, Econometrica 87(1)) the illiquid asset pays its return as a liquid dividend, and in Kaplan and Violante (2014, Econometrica 82(4)) part of it is a flow of housing services (both from memory, to be checked when written up). The solver has a switch for this since commit 7acd301 (`k_payout`, off by default: the keeper holds k' = k and receives (Rk - 1) k in cash, the adjuster is as before). Same economy, transitory standard deviation 0.18:

| return paid out | fixed cost | liquid return | net wealth | liquid | poor htm | wealthy htm | MPC, all | MPC, poor htm | MPC, wealthy htm | MPC, the rest | adjusting, all | adjusting, wealthy htm |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| no | 0.0131 | 2% | 4.72 | 0.113 | 0.038 | 0.226 | 0.139 | 0.335 | 0.154 | 0.124 | 0.51 | 0.73 |
| no | 0.05 | 2% | 4.24 | 0.284 | 0.040 | 0.120 | 0.139 | 0.360 | 0.156 | 0.126 | 0.28 | 0.72 |
| yes | 0.0131 | 2% | 4.43 | 0.124 | 0.037 | 0.207 | 0.148 | 0.330 | 0.204 | 0.123 | 0.31 | 0.25 |
| yes | 0.05 | 2% | 4.16 | 0.218 | 0.040 | 0.141 | 0.161 | 0.355 | 0.305 | 0.127 | 0.13 | 0.06 |
| yes | 0.05 | 0% | 3.60 | 0.138 | 0.045 | 0.203 | 0.188 | 0.389 | 0.335 | 0.136 | 0.15 | 0.07 |
| yes | 0.05 | -1% | 3.43 | 0.112 | 0.048 | 0.228 | 0.199 | 0.397 | 0.340 | 0.141 | 0.16 | 0.07 |
| HFCS | | | 4.78 | 0.059 | 0.038 | 0.184 | 0.39 to 0.47 (survey) | | | | | |

(Runs 37397134555, 37397137046, 37399085766, 37399088702. The HFCS ratios are to median income, the model's here to mean income.)

- With the return paid out and a cost of 5% of annual income, the wealthy hand-to-mouth are what the term means: 6 to 7% of them adjust in a year and their MPC is that of the poor hand-to-mouth (0.31 to 0.34 against 0.36 to 0.40). Without the payout the same cost left 72% adjusting.
- A return on liquid wealth of zero or minus one percent in real terms, in place of two, brings the hand-to-mouth shares to the data's (0.045 and 0.20 against 0.038 and 0.184) and the liquid median down, with no other change.
- The MPC of the whole economy is then 0.19 to 0.20. The three quarters of households that are not hand-to-mouth have an MPC of 0.13 to 0.14, as they should with three to four years of income in wealth; on one asset every household is impatient and holds little, which is where its 0.4 comes from. Raising patience to restore net wealth (3.4 to 3.6 against 4.78) will lower the MPC a little. So the two-asset reference will give an MPC near 0.2, about half the survey figure, and that is a property of holding realistic wealth, not a fault to fit away.
- The hand-to-mouth themselves have an MPC of 0.33 to 0.40, not one: at an annual period a household that starts the year with a week of income in liquid wealth still plans to end it with some.

**The quarterly runs: the period is not the cause** (37379989414, 37379993283; they ended after 5 h 15 min by reaching the iteration limit, so they are not converged and are indicative only). France G, no transitory part, same parameters:

| period | fixed cost | net wealth | liquid | poor htm | wealthy htm | MPC over the year | MPC within the period | adjusting in a period, all | adjusting, wealthy htm |
|---|---|---|---|---|---|---|---|---|---|
| annual | 0.0131 | 4.20 | 0.098 | 0.029 | 0.258 | 0.138 | 0.138 | 0.49 | 0.81 |
| quarterly | 0.0131 | 4.23 | 0.213 | 0.010 | 0.049 | 0.116 | 0.036 | 0.28 | 0.49 |
| quarterly | 0.0393 | 4.05 | 0.337 | 0.011 | 0.032 | 0.115 | 0.036 | 0.13 | 0.48 |

At a quarterly period the MPC over the year is lower (0.116 against 0.138), the hand-to-mouth nearly vanish and liquid wealth doubles: with four chances a year to reach the illiquid asset it is more liquid, not less. A quarterly solve also takes over five hours against ten minutes, so it could not be calibrated on these runners in any case. The period stays annual, on this result for two assets and on `probe_mpc_period.jl` for one. The transitory run at lower patience (37386744233) did not converge in three hours and was cancelled.

**The transitory part at a refitted point: the MPC holds** (`probe_transitory_tax.jl CODE 0,0.126,0.178 fit`, runs 37511452534, 37511456560, 37511460253, 2026-10-06). For each variant the persistent innovation is lowered so the variance of log income is unchanged, the job's effort levels are found again, and patience and its gap by education are refitted to the hand-to-mouth share and its difference by education (both hit to 0.001 except one Italian row at 0.169). G, v3e (no floor). The rows at the sourced variance (standard deviation 0.178) and at half of it:

| | tax | top patience, gap | MPC | survey | MPC of htm | liquid/income | fall on job loss | htm, benefit rate +10 points |
|---|---|---|---|---|---|---|---|---|
| France, base | lump-sum | 0.913, 0.050 | 0.305 | 0.392 | 0.436 | 0.075 | 0.205 | +0.211 |
| France, 0.178 | proportional | 0.893, 0.042 | 0.412 | | 0.577 | 0.109 | 0.149 | +0.041 |
| France, 0.178 | lump-sum | 0.877, 0.049 | 0.440 | | 0.580 | 0.092 | 0.182 | +0.050 |
| France, 0.126 | proportional | 0.906, 0.038 | 0.376 | | 0.577 | 0.101 | 0.157 | +0.051 |
| Germany, base | lump-sum | 0.932, 0.042 | 0.267 | 0.468 | 0.529 | 0.212 | 0.243 | +0.060 |
| Germany, 0.178 | proportional | 0.906, 0.062 | 0.400 | | 0.588 | 0.117 | 0.247 | +0.020 |
| Germany, 0.178 | lump-sum | 0.902, 0.064 | 0.404 | | 0.584 | 0.114 | 0.260 | +0.018 |
| Germany, 0.126 | proportional | 0.916, 0.055 | 0.369 | | 0.595 | 0.114 | 0.253 | +0.034 |
| Italy, base | lump-sum | 0.884, 0.078 | 0.388 | 0.469 | 0.552 | 0.038 | 0.391 | +0.377 |
| Italy, 0.178 | proportional | 0.891, 0.063 | 0.408 | | 0.622 | 0.123 | 0.306 | +0.054 |
| Italy, 0.178 | lump-sum | 0.876, 0.070 | 0.433 | | 0.628 | 0.107 | 0.341 | +0.038 |
| Italy, 0.126 | proportional | 0.897, 0.061 | 0.386 | | 0.622 | 0.109 | 0.317 | +0.083 |

- The MPC is 0.40 to 0.41 in the three countries at the sourced variance with the proportional tax, untargeted: 0.02 above France's survey figure, 0.06 to 0.07 below Germany's and Italy's. At half the variance 0.37 to 0.39. The proportional tax costs about 0.03 of MPC against the lump-sum one and takes 0.01 to 0.04 off the fall in consumption on job loss.
- The response of the hand-to-mouth share to the benefit rate is 0.02 to 0.05 for ten points, from 0.06 to 0.38.
- The fall in consumption on job loss is repaired only in part: France 0.15, Germany 0.25 (unchanged), Italy 0.31.
- The cost is in patience and in Germany's liquid wealth. Patience falls by 0.02 to 0.03 at the top (0.89 to 0.91) and the less educated sit at 0.83 to 0.85. Germany's liquid wealth over mean income halves, from 0.21 to 0.12, which at the full calibration will be at the edge of its band.
- Still not the full calibration: the effort scale and the floor are not refitted, the dispersion is held by formula and not by S80/S20, and this is G alone.

## 29. The architecture, proposed for the user's decision (2026-10-06)

Built on the probes of section 28. Nothing below is built yet except the two switches named.

**A. The household's income (one asset and two).** Persistent part as now (persistence 0.92, innovation fitted to S80/S20) plus an independent transitory draw each year on the income of the employed, three nodes, variance 0.0316 (Bayer and Juessen 2012, Table 1, Germany; a common European value, as their persistence already is). Benefits follow the persistent part. A sensitivity row at half the variance, since the estimate includes measurement error. The model's one-year and five-year income changes are checked against the Global Repository of Income Dynamics (Guvenen, Pistaferri and Violante 2022) as an untargeted test, which is also where a new country's process would come from.

**B. The tax.** The benefit bill and the floor are paid by a proportional tax on labour income in place of the lump-sum tax. It is the standard closure, the unemployed and the lowest paid can pay it, and it frees the income grid.

**C. The period.** Annual. A quarterly period lowers the two-asset MPC over the year and does not move the one-asset one (section 28).

**D. One asset is the base.** S, A, E and places, every country, policy checks and transitions run on it, with the floor and patience by education refitted as in section 25. Wealth on it is liquid wealth. The MPC, the fall in consumption on job loss and the response of buffers to the benefit rate are untargeted and are the test of A at the recalibrated point.

**E. Two assets are the reference for wealth.** G only at first, per country, with three changes from the version of section 20: the illiquid return paid out as liquid income (`k_payout`); the return on liquid wealth at zero in real terms, from a source to be fixed (deposit rates less inflation), the illiquid return unchanged; the fixed cost fitted to the wealthy hand-to-mouth share, which now identifies it. Patience fitted to net wealth over income. Untargeted: the Gini, the top 10% share, liquid wealth, the MPC. No device for education on two assets: patience fails there (probe 1) and the split is reported as it comes out.

**What this is expected to deliver, and what it will not.**

| | now | expected | data |
|---|---|---|---|
| MPC, one asset | 0.27 to 0.39 | 0.40 to 0.41 at a refitted point (section 28) | 0.39 to 0.47 (survey) |
| Hand-to-mouth for ten points of benefit rate, one asset | +0.06 to +0.38 | +0.02 to +0.05 | small |
| Fall in consumption on job loss, one asset | 0.21 to 0.39 | a little lower, still high | about 0.1 |
| Wealth Gini and top 10% share, two assets | 0.64, 0.46 | to be seen after the three changes | 0.68, 0.50 |
| MPC, two assets | 0.14 | about 0.2 | 0.39 to 0.47 (survey) |
| Wealth by education, two assets | flat | flat | graduates richer, less often hand-to-mouth |

Not addressed by this build: the persistent shock is larger than its source says (it carries permanent differences between households; a permanent type is the repair, noted for later); the regional order of buffers; the two-asset MPC, which stays at about half the survey figure.

**Order and gates.**
1. Engine: the transitory part and the tax as two settings, with the old economy reproduced exactly when they are off (the regression test). Tested on GitHub.
2. Gate: recalibrate G in the three countries and read the three untargeted rows at the recalibrated point. If the probe's result does not survive recalibration, stop and report.
3. The other configurations (France and Germany eight each; Italy eight, the floor fitted with places).
4. On/off, accuracy, the policy check, the private share, the regional test; the scorecard.
5. The two-asset reference, G in three countries.
6. Transitions on the base; the environment side of E as indicators.

**Risks.** The state space triples (66 income states for 22). The longest calibration today (Italy with places, 236 minutes) would pass the runner's six hours; the checkpoint and resume chain exists for this, and two transitory nodes instead of three is the fallback. Germany's liquid wealth may come under pressure once patience is refitted (section 28).

**For the user to decide.** (1) Go ahead with A to E in this order. (2) The persistent shock: keep the fit and state it, with the GRID test (recommended), or add a permanent type now. (3) Accept that the two-asset reference will carry an MPC of about 0.2 and no education split, stated as limits.

## 30. The build, steps 1 and 2: the engine, and G calibrated in the new regime (2026-10-06)

**Step 1, the engine** (commits 8d266f9 to a50a3b3). Two settings of the configuration, both off by default: `sd_eps`, `n_eps` (the transitory part: every state becomes n_eps states, `expand_transitory`, applied last in `params_of`) and `tax_mode = :prop` (the amount in `lumptax` raised at the rate lumptax / `labour_base(c)`, mean labour income per head at the job's effort levels). With either on, the job's effort levels are those of the economy without both (`floor_effort`, which already did this for the floor), so effort does not follow the year's draw. The regimes `:trans`, `:floor_trans`, `:edu_trans`, `:floor_edu_trans` of `country_config` switch both on, with the size from `data/manual_inputs.csv` (field `sd_eps`, 0.178) and files tagged with a t (`calibration_v3fet_*` for the base); `SAGE_TRANS=1` and the workflow input `trans=1` in the calibration. The place layer refuses the proportional tax for now (one national rate on a national base is step 3).

`test_transitory_engine.jl` (run 37515253263), 11 of 11: with both off France G reproduces its numbers; with them on the engine gives the probe's numbers at the probe's refitted points (MPC 0.413 against 0.412, 0.443 against 0.440, 0.266 against 0.265, 0.376 against 0.376); the tax raises the benefit bill to 2e-13; G+S, G+S+A, G+A and Italy with the floor solve with both on; the place layer refuses with its message. The on/off pass of the old base is unchanged, 16 of 16 (run 37514447549).

**Step 2, the gate: G in the three countries, full calibration** (run 37526231562, files `calibration_v3fet_{FR,DE,IT}_G.txt`; readout `gate_readout.jl`, run 37528263359). Every owned target is met in the three countries (effort, the hand-to-mouth share, its difference by education, S80/S20, and in Italy liquid wealth through the floor).

| | top patience, gap, floor | htm | MPC | survey MPC | liquid/income | HFCS | fall on job loss | htm, benefit rate +10 points |
|---|---|---|---|---|---|---|---|---|
| France, old base | 0.912, 0.050, 0 | 0.221 | 0.305 | 0.392 | 0.089 | 0.059 | 0.205 | +0.223 |
| France, new | 0.889, 0.043, 0 | 0.223 | 0.415 | | 0.124 | | 0.152 | +0.041 |
| Germany, old base | 0.929, 0.041, 0 | 0.234 | 0.274 | 0.468 | 0.220 | 0.140 | 0.248 | +0.073 |
| Germany, new | 0.904, 0.064, 0 | 0.226 | 0.405 | | 0.128 | | 0.251 | +0.021 |
| Italy, old base | 0.928, 0.047, 0.156 | 0.198 | 0.304 | 0.469 | 0.276 | 0.272 | 0.251 | +0.066 |
| Italy, new | 0.920, 0.051, 0.136 | 0.179 | 0.313 | | 0.273 | | 0.238 | +0.004 |

- France and Germany pass: the MPC is 0.41 and 0.40 untargeted at the full calibration, as the probe said. Germany's liquid wealth, which I had flagged, moves towards its target (0.128 against 0.140, from 0.220). France's moves away (0.124 against 0.059, inside the band of 0.09).
- The response of the hand-to-mouth share to the benefit rate is 0.00 to 0.04 in the three countries.
- **Italy's MPC does not rise (0.31 against a survey 0.47).** The reason is identified: Italy's liquid wealth target is high (0.27 of income, against 0.06 and 0.14), the floor is the parameter that meets it, and it does so by raising patience (0.92). Without the floor Italy's MPC is 0.41 and its liquid wealth 0.12 (section 28). On one asset Italy has either its liquid wealth or its MPC; the rule keeps the targeted moment.
- The fall in consumption on job loss: France 0.15, Germany 0.25, Italy 0.24. Improved in France only.
- In-work poverty, untargeted, is too high in all three (0.16, 0.18, 0.19 against 0.07, 0.09, 0.12).
- The persistent dispersion did not fall when refitted (eta 0.263, 0.275, 0.295, as before), so the transitory part adds to the cross-section less than the formula of the probe assumed.

**Step 3 started**: G+A and G+S+A in the three countries (G+S follows G+S+A by the chain). The place configurations wait for the proportional tax in the place layer.

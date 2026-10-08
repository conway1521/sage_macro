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

**Step 3, the other configurations** (2026-10-06, evening).

| | G+A: MPC, htm, liquid | G+S+A: MPC, htm, liquid | participation, multiplier (band) |
|---|---|---|---|
| France | 0.415, 0.219, 0.119 | 0.414, 0.217, 0.120 | 0.233, 1.9 (1.3 to 3.7) |
| Germany | 0.401, 0.222, 0.123 | 0.403, 0.225, 0.121 | 0.279, 1.8 (1.3 to 2.7) |
| Italy | 0.319, 0.178, 0.262 | 0.319, 0.178, 0.262 | 0.125, 1.3 (1.1 to 1.9) |

All owned targets met (runs 37529086794 for G+A, 37530240230 for G+S+A; files `calibration_v3fet_*_GA.txt`, `*_GSA.txt`). G+S is running, started by the chain. The first G+S+A run failed at the guard: the calibration's scans build the response families themselves and reached the household problem without the job's effort levels. `build_families` and `employment_mask` now take the levels as `_solve` does (commit b3d894b); this also holds for the old floor regime, whose scans had found effort with the floor on.

**The proportional tax with places** (commit 773fff6): one national rate, the national total per head over the nation's mean labour income per head (`national_base`), handed to every place as `tax_base`. `test_transitory_engine.jl`, 12 of 12 (run 37529268427): France (14 places) at a rate of 0.0378 and Italy (21 places) at 0.0241 raise the benefits and the floor to 1e-13 per head.

**The place configurations**: G+E started for the three countries with the floor fitted there (`floor_from=GE`, run 37536039819). At three times the income states a place calibration will pass the six-hour limit and resume from its checkpoints. Italy's four configurations without places are then to be refitted with the floor of G+E, as on the old base.

**Later the same evening.**
- G+S calibrated in the three countries (MPC 0.413, 0.403, 0.313; multipliers 1.9, 1.8, 1.3), so the four configurations without places are done in the new regime.
- The on/off pass in the new regime: 16 of 16 in France, in Germany and in Italy (runs 37538440810, 37538444721, 37538448491; `onoff_v3.jl floor edu trans CODE`).
- G+E calibrated in the three countries with the floor fitted there (run 37536039819), in 28, 53 and 91 minutes, well inside the runner's limit. France MPC 0.415, hand-to-mouth 0.224, liquid 0.123; Germany 0.402, 0.222, 0.130; Italy 0.317, 0.178, 0.270. Italy's floor comes out at 0.137 with places against 0.136 without, so in this regime the two rules agree, where on the old base they did not (0.105 against 0.156 in the file's units).
- Started: G+A+E and G+S+A+E in the three countries (G+S+E by the chain), run 37546002483; Italy's four configurations without places again with the floor of G+E, run 37546005118; accuracy, the private share and the spending tests for France and Germany in the new regime.

**Night of 6 to 7 October: the checks in the new regime, and steps 5 and 6 started.**

| check | France | Germany | Italy |
|---|---|---|---|
| on/off pass (`onoff_v3.jl floor edu trans`) | 16 of 16 | 16 of 16 | 16 of 16 (again on the refitted files) |
| accuracy (`numerics_base.jl CODE v3fet`) | 7 of 7 | 7 of 7 | 7 of 7 |
| seven properties of the MPC (`test_mpc_economics.jl CODE G v3fet`) | pass | pass | pass |

Germany's one accuracy failure on the old base (participation moving with the top of the asset grid) is gone. The private share of belonging for Germany: the model's regional spread is 0.114 at 0.15 and 0.066 at 0.30 against 0.084 in the data, so about 0.24 and a multiplier of at most about 2.2 (2.3 on the old base). France has no regional volunteering series, so no bound of this kind.

G+A+E calibrated in the three countries (MPC 0.417, 0.401, 0.317), and Italy's four configurations without places refitted at the floor of G+E (0.137; MPC 0.31 to 0.32, every target met). The untargeted readout for G+S+A repeats G's: MPC 0.414, 0.403, 0.319; ten points of benefit rate add 0.05, 0.02, 0.02 of hand-to-mouth households; the fall in consumption on job loss is 0.154, 0.255, 0.243 (France on the INSEE benchmark of 0.15 of section 14; Germany and Italy above the 0.07 to 0.16 of the literature).

**The regional test, Italy, at its own calibration with places** (`test_place_wealth.jl GE base_trans`, run 37560238399): 3 of 3. This test failed on every earlier version (sections 18, 21, 23).

| | North | Centre | South and Islands | South over North | by region (19): correlation, spread |
|---|---|---|---|---|---|
| hand-to-mouth, model | 0.167 | 0.179 | 0.194 | 1.16 | 0.83, 0.040 |
| hand-to-mouth, HFCS | 0.096 | 0.151 | 0.316 | 3.28 | , 0.353 |
| liquid-asset poverty, model | 0.356 | 0.357 | 0.366 | 1.03 | -0.17, 0.068 |
| liquid-asset poverty, HFCS | 0.248 | 0.273 | 0.505 | 2.04 | , 0.589 |
| income poverty, model | 0.134 | 0.166 | 0.253 | 1.89 | 0.91, 0.157 |
| income poverty, HFCS | 0.058 | 0.096 | 0.291 | 4.98 | , 0.350 |

The order is now right in the three indicators and the regions line up for the hand-to-mouth share and income poverty (correlations 0.83 and 0.91). The spread is far too small: the South has 1.16 times the North's hand-to-mouth share against 3.28. So row M6 moves from "not by region" to "the order, not the size".

**Step 5, the two-asset reference** (`calibrate_two_asset_ref.jl`, runs 37566750589, 37566752617, 37566754669): the base's G with the illiquid asset, the return paid out (`k_payout`), liquid wealth earning nothing in real terms (`r_liquid = 1`, an assumption whose source is still to be fixed), one patience for everyone. Patience fitted to net wealth over income and the fixed cost to the wealthy hand-to-mouth share, by Broyden steps because a solve takes half an hour. Everything else is the test.

**Step 6.** Transitions on the new base (`transition_core.jl`: the period's tax rate on the period's labour income, the job's effort levels held along the path, the floor's tax held at its steady-state amount; `test_transition_base.jl`, runs 37566865142 and 37566867174). E's environmental side as indicators (`e_environment.jl`, run 37566987193): the household footprint per head by education, status and place, the function that existed for version 2, on the base.

## 31. The income process against published earnings dynamics, and a more persistent process as an option (2026-10-07)

**The test promised in section 29, run on what the published paper gives.** Guvenen, Pistaferri and Violante (2022, Quantitative Economics 13(4), 1321-1360): the standard deviation of one-year changes in residual log earnings is 0.50 on average across the GRID countries and ranges from 0.38 for Germany to 0.66 for Mexico (p. 1339); the five-year rank-rank slope (the rank at t + 5 on the rank of permanent income at t) is 0.83 in France, 0.76 in Germany and 0.86 in Italy (Table 4, p. 1354). The model's counterparts for a household continuously in work follow from the process (persistent part with persistence rho and stationary variance s2, transitory variance e2): the variance of a one-year change is 2 s2 (1 - rho) + 2 e2, and the rank slope is the Spearman correlation implied by the correlation of a three-year average with the level five years on.

| | model, base | GRID |
|---|---|---|
| Germany, standard deviation of one-year changes | 0.377 (0.281 without the transitory part) | 0.38 |
| France, the same | 0.368 | not in the text of the paper |
| Italy, the same | 0.393 | not in the text of the paper |
| five-year rank slope, France, Germany, Italy | 0.59 to 0.61 | 0.83, 0.76, 0.86 |

The transitory part puts Germany's one-year volatility on the published figure, untargeted. The five-year persistence of ranks is too low in the three countries: households move through the income distribution too fast. This is the weakness of section 28 seen from the other side. The table's persistence of 0.92 is Bayer and Juessen's, estimated beside a household fixed effect; the model has no fixed effect, so the persistence it needs is the one of a process without it, which is higher (Krueger, Mitman and Perri 2016 estimate 0.97 for the United States on that basis; from memory, to be checked).

**The option this opens, with no new machinery.** A persistence of about 0.97 and a transitory standard deviation of about 0.24 reproduce both of Germany's GRID figures at the same variance of log income (by hand: one-year standard deviation 0.38, rank slope 0.78 against 0.76). France and Italy need about 0.98 and 0.985 for their rank slopes; their transitory size needs their one-year figure from the GRID database, which the paper's text does not give.

**What it does to the model, at a refitted point** (`probe_transitory_tax.jl CODE 0.178,0.24 fit RHO`, runs 37567304305 and 37567306459; proportional tax; not the full calibration):

| | persistence, transitory sd | top patience, gap | MPC | survey | liquid/income | fall on job loss | htm, benefit rate +10 points |
|---|---|---|---|---|---|---|---|
| Germany, base | 0.92, 0.178 | 0.906, 0.062 | 0.400 | 0.468 | 0.117 | 0.247 | +0.020 |
| Germany | 0.97, 0.178 | 0.923, 0.056 | 0.430 | | 0.082 | 0.272 | +0.049 |
| Germany | 0.97, 0.24 | 0.910, 0.078 | 0.462 | | 0.094 | 0.254 | +0.036 |
| France, base | 0.92, 0.178 | 0.893, 0.042 | 0.412 | 0.392 | 0.109 | 0.149 | +0.041 |
| France | 0.98, 0.178 | 0.920, 0.041 | 0.445 | | 0.077 | 0.154 | +0.061 |
| France | 0.98, 0.24 | 0.903, 0.056 | 0.471 | | 0.087 | 0.143 | +0.043 |

With the more persistent process Germany's MPC reaches its survey figure (0.46 against 0.47), patience rises by 0.01 to 0.03, and liquid wealth falls a little further below Germany's target. France's MPC goes above its survey figure (0.45 to 0.47 against 0.39) while its liquid wealth moves towards its target (0.08 against 0.06). Italy's run at 0.985 failed (an economy without a solution in the fit); to be rerun at 0.97. Full calibrations of G at these processes are running (`calibrate_trial.jl`, runs 37569204890 to 37569211661) and are evidence for the user's decision, not a change of base: files tagged v3fetr are not read by anything.

**E's environmental side as indicators on the base** (`e_environment.jl GAE`, run 37566987193, 6 of 6): the household footprint per head is the official one nationally (France 6.03 tonnes of CO2 equivalent, Germany 7.94, Italy 6.80; Eurostat env_ac_ghgfp, consumption-based) and differs across groups and places by their consumption.

| | below tertiary | tertiary | employed | out of work | lowest place | highest place |
|---|---|---|---|---|---|---|
| France | 5.34 | 7.36 | 6.09 | 5.18 | 4.88 (FRY) | 7.04 (FR1) |
| Germany | 6.92 | 10.62 | 8.00 | 5.96 | 7.26 (DEE) | 8.59 (DE2) |
| Italy | 6.29 | 9.21 | 6.96 | 4.75 | 5.60 (ITF6) | 8.49 (ITH1) |

Two things it does not carry: the composition of consumption by group (one intensity per euro for everyone), and exposure to the local environment by place, for which no regional series is in the repository yet.

**Transitions on the base: two faults found by the zero-shock test and repaired** (commit after f222ee9). With the household replacement rate of version 3 the path's tax was computed on the whole transfer, where the steady state taxes for the state-paid part only, so a zero shock drifted (consumption by 0.2 to 1%); and the backward step left dread at zero, so a path with A on did not start from its own steady state. Both predate this build and affected every version 3 transition. The first recession numbers (runs 37566865142, 37566867174) are void; the tests are running again.

## 32. Transitions on the base, the two-asset reference for France, and the trial processes at the full calibration (2026-10-07, early morning)

**Transitions (row M8), G+A, the three countries: 12 of 12** (`test_transition_base.jl GA FR DE IT`, run 37570221531). Three faults were found by the zero-shock test and repaired on the way: the path's tax was on the whole household transfer where the steady state taxes for the state-paid part; the backward step left dread at zero; and it had no means-tested floor. With them repaired a zero shock stays at the steady state to 1e-10 in the three countries, Italy with its floor included, and the path's first period is the steady-state economy.

A recession (job-loss rates 50% higher for two years), and the same recession with the benefit rate ten points higher in its first three years, paid by the period's tax (`rr_add`, a temporary policy along the path):

| | unemployment at its peak | consumption at its trough | tax rate at its peak | welfare of living through it | with the higher benefit | below tertiary, tertiary, with the benefit |
|---|---|---|---|---|---|---|
| France | +2.9 points | -0.95% | +1.74 points | -0.39% of consumption | -0.25% | -0.21%, -0.32% (from -0.45%, -0.28%) |
| Germany | +1.3 | -0.43% | +0.52 | -0.21% | -0.07% | -0.07%, -0.08% (from -0.26%, -0.10%) |
| Italy | +2.4 | -0.73% | +0.88 | -0.33% | -0.18% | -0.17%, -0.24% (from -0.36%, -0.20%) |

The temporary benefit takes a third to two thirds off the welfare cost of the recession, all of it for the less educated; graduates in France and Italy lose a little, because they pay more of the tax than they receive. Consumption returns to within 0.1% of the steady state by year 40 in every case. Covered: S off, E off, one asset, a shock to job-loss rates and a temporary benefit rate. Not covered: a permanent reform (the path would end in another steady state), places, and S on (France running, run 37569143613).

**The two-asset reference, France** (`calibrate_two_asset_ref.jl FR 0.962 0.06`, run 37566750589; file `calibration_v3fet_FR_G_I.txt`, saved from the run log). Calibrated at its starting point: patience 0.962, fixed cost 0.06 of mean annual income.

| | model | HFCS 2021 | |
|---|---|---|---|
| net wealth over income, median | 4.66 | 4.78 | targeted |
| wealthy hand-to-mouth | 0.191 | 0.184 | targeted |
| poor hand-to-mouth | 0.048 | 0.038 | untargeted |
| liquid wealth over income, median | 0.170 | 0.059 | untargeted |
| net wealth Gini | 0.655 | 0.676 | untargeted |
| top 10% share of net wealth | 0.469 | 0.499 | untargeted |
| MPC | 0.170 (0.41 poor hand-to-mouth, 0.31 wealthy) | 0.392 (survey) | untargeted |
| fall in consumption on job loss | 0.069 | 0.15 (INSEE), 0.07 to 0.16 (literature) | untargeted |
| hand-to-mouth, below tertiary and tertiary | 0.237, 0.243 | 0.256, 0.151 | untargeted |
| net wealth over income, the same | 4.70, 4.59 | 4.45, 5.44 | untargeted |

The wealth distribution is close without being fitted (row M7 for France). The reference also gives the small fall in consumption on job loss that the one-asset base cannot: households with illiquid wealth behind them absorb a job loss. Its limits are the three stated in section 29: liquid wealth too high, an MPC of 0.17, no difference by education. Germany and Italy are still running.

**The trial processes at the full calibration of G** (`calibrate_trial.jl`, runs 37569204890 to 37569211661): every owned target met in each.

| | persistence, transitory sd | persistent innovation | top patience, gap | MPC | survey | liquid/income | HFCS | fall on job loss |
|---|---|---|---|---|---|---|---|---|
| Germany, base | 0.92, 0.178 | 0.275 | 0.904, 0.064 | 0.405 | 0.468 | 0.128 | 0.140 | 0.251 |
| Germany, trial | 0.97, 0.24 | 0.166 | 0.917, 0.085 | 0.453 | | 0.111 | | 0.248 |
| France, base | 0.92, 0.178 | 0.263 | 0.889, 0.043 | 0.415 | 0.392 | 0.124 | 0.059 | 0.152 |
| France, trial | 0.98, 0.178 | 0.136 | 0.918, 0.041 | 0.445 | | 0.088 | | 0.153 |
| France, trial | 0.97, 0.24 | 0.158 | 0.892, 0.054 | 0.476 | | 0.100 | | 0.147 |
| Italy, base | 0.92, 0.178 | 0.295 | 0.920, 0.051 | 0.313 | 0.469 | 0.273 | 0.272 | 0.238 |
| Italy, trial | 0.97, 0.24 | 0.185 | 0.937, 0.037 | 0.309 | | 0.270 | | 0.218 |

The more persistent process halves the persistent innovation (to 0.14 to 0.19, from 0.26 to 0.30), which answers the weakness of section 28 without a permanent type, and it is what the published rank persistence asks for. Germany's MPC then reaches its survey figure; France's rises above its own (0.445 against 0.392, inside the band of plus or minus 0.10 that section 10 gave the MPC); Italy's does not move, held by its floor as before. For the user to decide: adopting it means fixing each country's two numbers from the GRID database and recalibrating the 24 configurations, about half a day of runner time.

**Identification on the base (row M3)** (`identification.jl CODE G base`, runs 37570816616, 37570819021, 37570821883): how each moment moves, in tolerance bands, for one step in each fitted parameter (effort scale +10%, top patience +0.005, persistent innovation +0.02, patience gap +0.01, floor +10%).

| | effort scale on effort | top patience on the hand-to-mouth share | innovation on S80/S20 | patience gap on the difference by education | floor on liquid wealth | condition number of the owned block |
|---|---|---|---|---|---|---|
| France | -2.92 | -0.77 | +2.24 | +1.34 | no floor | 8.1 |
| Germany | -2.83 | -0.82 | +2.42 | +0.96 | no floor | 11.0 |
| Italy | -3.15 | -0.49 | +2.88 | +0.75 | -0.39 | 11.8 |

No column is flat and the owned blocks are well conditioned in the three countries, so every fitted parameter of the base is identified by the moments it owns. In Italy the floor and patience are identified together and not one by one: at given patience a higher floor lowers median liquid wealth a little and raises the hand-to-mouth share (+0.59 bands), and it is the refit of patience that then raises liquid wealth; patience moves liquid wealth by +1.18 bands. The MPC and the fall in consumption on job loss respond to every parameter by less than half a band a step, which is why they are tests and not targets. What is still not identified by any of these moments is the private share of belonging (a band, section 26).

**Convergence in the income grid (row N3, the part that could not be run before)** (`probe_income_grid.jl G FR DE IT`, run 37571355353). With the lump-sum tax a finer income grid had no solution (section 21); under the proportional tax it has. The base at 11, 15 and 21 persistent states, nothing refitted, the job's effort levels interpolated from the eleven-state ones:

| | htm at 11, 15, 21 | MPC | S80/S20 | liquid/income | largest change from 11, in tolerance bands |
|---|---|---|---|---|---|
| France | 0.223, 0.223, 0.221 | 0.415, 0.415, 0.416 | 4.72, 4.62, 4.62 | 0.124, 0.123, 0.122 | 0.41 |
| Germany | 0.226, 0.225, 0.225 | 0.405, 0.404, 0.404 | 5.08, 4.99, 4.94 | 0.128, 0.128, 0.130 | 0.53 |
| Italy | 0.180, 0.171, 0.162 | 0.309, 0.310, 0.313 | 6.03, 6.01, 5.98 | 0.280, 0.283, 0.283 | 0.88 |

No moment moves by a tolerance band on doubling the income grid. The MPC is unchanged to 0.004. Italy's hand-to-mouth share is the one that moves most (0.018, where the floor meets the lowest incomes), and S80/S20 falls by 0.1 in France and Germany; both would be absorbed by a refit on the finer grid. Eleven states stay.

**Italy's choice on one asset, as a frontier** (`probe_floor_frontier.jl IT G`, run 37572097240): for each level of the floor, patience refitted to the hand-to-mouth share (0.179 in every row), everything else at the calibration.

| floor, share of the base's | patience | liquid wealth over income (target 0.272) | MPC (survey 0.469) | fall in consumption on job loss |
|---|---|---|---|---|
| 1.0 | 0.924 | 0.283 | 0.307 | 0.235 |
| 0.8 | 0.897 | 0.175 | 0.378 | 0.283 |
| 0.6 | 0.891 | 0.159 | 0.388 | 0.297 |
| 0.4 | 0.883 | 0.140 | 0.406 | 0.309 |
| 0 | 0.881 | 0.136 | 0.410 | 0.312 |

The frontier is steep at the top: the last fifth of the floor carries most of Italy's liquid wealth (0.175 to 0.283) and costs 0.07 of MPC. Giving Italy the liquid-wealth band of France and Germany (0.09) would put it near the second row: an MPC of about 0.37, liquid wealth at the edge of the band, and a larger fall in consumption on job loss. No level of the floor reaches the survey's 0.47. So the recommendation of section 30 stands: keep liquid wealth as Italy's target and state its MPC of 0.31 as a limit of the one-asset base for a country whose households hold much liquid wealth and report spending much of a windfall.

**Transitions with S on do not pass on the base** (`test_transition_s.jl 40 full FR base`, run 37569143613): participation stays at the steady state under a zero shock (2e-12) but consumption and assets drift (0.02 and 0.11) and the welfare of the zero path is not zero, so the backward step does not return the steady state of a household with a belonging payoff in this regime. The recession it printed is void. S off is exact (above). The cause is not found yet; the version 2 zero-shock test is running again as a check on whether the repairs of tonight changed it.

## 33. The scorecard on the new base (2026-10-07, morning)

The base is now the regime with the floor, patience by education, the transitory part and the proportional tax (files `calibration_v3fet_*`). Calibrated at the time of writing: France and Germany in seven of eight configurations (G+S+E running), Italy in six (G+S+A+E and G+S+E running). The table of section 27, row by row:

| | criterion | state on the new base | what moved, and what is left |
|---|---|---|---|
| **Macroeconomists** | | | |
| M1 | Stationary equilibrium, budget balanced, closure stated | met | the proportional tax raises the benefit bill to 1e-13, with places too |
| M2 | Standard building blocks | **met** (was partly) | CRRA, persistent and transitory income risk, unemployment, a proportional tax |
| M3 | Every parameter from a source or identified; identification shown | partly, closer | identification table on the base, no flat column, in three countries. Left: the private share of belonging (a band); the persistent shock larger than its source (a more persistent process answers it, the user's decision, section 32); the liquid return of the two-asset reference (an assumption) |
| M4 | Every configuration hits its own targets in every country | partly: 22 of 24 | France and Germany eight of eight; Italy six, its two with S and places running; every finished one meets every owned target |
| M5 | Spending behaviour untargeted | partly, much closer | MPC 0.41 and 0.40 against 0.39 and 0.47 in France and Germany; seven MPC properties in three countries; the benefit rate no longer moves buffers by tens of points. Left: Italy's MPC 0.31 against 0.47 (a limit of one asset there, section 32); the fall in consumption on job loss in Germany and Italy (0.25, 0.24 against 0.07 to 0.16) |
| M6 | Who holds no buffer | partly, closer | by education met (targeted); by region the order is now right in Italy at its own calibration (correlation 0.83), the spread a fifth of the data's; by type of place in France the order is the wrong way round (rural highest in the model, cities in the HFCS) |
| M7 | The wealth distribution | partly (was not met) | the two-asset reference in three countries, untargeted: Gini 0.655, 0.658, 0.664 against 0.676, 0.727, 0.640; top 10% 0.47 to 0.48 against 0.50, 0.56, 0.50. Left: the difference between countries (Germany); liquid wealth too high, an MPC of 0.11 to 0.17 and no split by education on the reference |
| M8 | Transitions for policies and shocks | **met** on one asset without places (was not run) | G and G+A in three countries: a zero shock exact, a recession, a temporary benefit along the path, 12 of 12; G+S+A exact in the three countries as well. Left: places, a permanent reform |
| **Numerical economists** | | | |
| N1 | A standard, documented method | met | |
| N2 | Exact reductions when a switch is off | met | 16 of 16 in three countries on the new base; both new settings off reproduce the old base |
| N3 | Accuracy on the base | **met** (was partly) | Euler errors, the asset grid and its top, 7 of 7 in three countries; the income grid, which could not be refined before, converged at 11 states |
| N4 | An independent solver agrees | on version 2 only | not looked at |
| N5 | Reproducible | mostly met | |
| N6 | Equilibria with S counted and stable | **met** in three countries | one stable equilibrium, the solver's |
| **Beyond-GDP** | | | |
| B1 | The dimensions are a recognised framework's | partly (was a decision) | E now carries the household footprint by education, status and place, and official exposure to pollution by type of place, as indicators. Left: consumption baskets by group; exposure by region; neither enters behaviour |
| B2 | Each dimension measured on official data | met | |
| B3 | Recognised indicators, stable and checked against official figures | partly | the table is built (below): 14 of 23 untargeted rows within a quarter of the official figure. Off: in-work poverty in three countries, liquid-asset poverty in France and Germany |
| B4 | Welfare split by dimension and by group | computed, not tabulated | later, by the user's ordering |
| B5 | Accessible | switches only | later |
| **Use** | | | |
| U1 | Any order of switches, each calibrated | France and Germany 8 of 8, Italy 6 of 8 | Italy's two with S and places running |
| U2 | Policy levers with honest bands | partly | multiplier bands; Germany's capped near 2.2 by regional spread; a temporary benefit along a recession as a model check |
| U3 | A new country added by the checklist | not tried | later. The transitory size and persistence would come from the GRID database, which covers thirteen countries |

Count: 9 met, 11 partly, 2 not, of 22 (7, 11, 4 before the build). The rows that changed class: M2, N3 and M8 to met, N6 met in the third country, M7 from not to partly.

**What the build did not repair, in order of weight for a macroeconomist.** (1) Italy's MPC. (2) The fall in consumption on job loss in Germany and Italy on one asset; the two-asset reference gives 0.07 to 0.11 in the three countries, so it is a limit of one asset. (3) The size of the persistent shock, with a sourced repair on the table. (4) In-work poverty. (5) The difference in wealth inequality between countries on the two-asset reference.

**The two-asset reference in the three countries** (`calibrate_two_asset_ref.jl`; Germany run 37566752617, Italy 37566754669, four solves each by Broyden steps; files `calibration_v3fet_{FR,DE,IT}_G_I.txt`). Patience fitted to net wealth over income and the fixed cost to the wealthy hand-to-mouth share; everything else untargeted.

| | France | Germany | Italy |
|---|---|---|---|
| patience, fixed cost (share of mean annual income) | 0.962, 0.060 | 0.960, 0.040 | 0.978, 0.125 |
| net wealth over income, model and HFCS (targeted) | 4.66, 4.78 | 3.16, 3.15 | 6.87, 6.82 |
| wealthy hand-to-mouth (targeted) | 0.191, 0.184 | 0.135, 0.151 | 0.114, 0.114 |
| poor hand-to-mouth | 0.048, 0.038 | 0.053, 0.074 | 0.036, 0.065 |
| net wealth Gini | 0.655, 0.676 | 0.658, 0.727 | 0.664, 0.640 |
| top 10% share of net wealth | 0.469, 0.499 | 0.477, 0.556 | 0.479, 0.495 |
| liquid wealth over income | 0.170, 0.059 | 0.198, 0.140 | 0.441, 0.272 |
| MPC, model and survey | 0.170, 0.392 | 0.166, 0.468 | 0.106, 0.469 |
| fall in consumption on job loss | 0.069 | 0.112 | 0.109 |
| hand-to-mouth, below tertiary and tertiary, model | 0.237, 0.243 | 0.187, 0.191 | 0.149, 0.155 |
| the same, HFCS | 0.256, 0.151 | 0.285, 0.118 | 0.196, 0.095 |

- **The wealth distribution (row M7).** The Gini is within 0.02 to 0.03 of the data in France and Italy and 0.07 below it in Germany; the top 10% hold 0.47 to 0.48 against 0.50, 0.56 and 0.50. The model gives about the same inequality of wealth in the three countries (0.66), so it has the level and not the difference between countries: Germany's wealth is more unequal than its income process and patience alone produce.
- **The fall in consumption on job loss** is 0.07 to 0.11 in the three countries, inside the 0.07 to 0.16 of the literature, where the one-asset base gives 0.15, 0.25 and 0.24. With illiquid wealth behind them households absorb a job loss. The base's excess in Germany and Italy is therefore a limit of one asset and not of the income process or the benefits.
- **The limits, as expected.** The MPC is 0.11 to 0.17; liquid wealth is 1.4 to 3 times the data's; the poor hand-to-mouth are too few in Germany and Italy; the two education groups are alike.

So the two versions divide the evidence between them: the one-asset base carries the hand-to-mouth by education, the MPC and everything S, A and E are fitted to; the two-asset reference carries the distribution of wealth and the response to a job loss. Neither does both, and the document should say so wherever a number is quoted.

**Transitions with S on: the cause found** (run 37573981971). In `transition_s` the tax-rate vector was named `rate`, the name the participation loop assigns to, so from the first iteration the path was taxed at the participation rate (0.233 in place of 0.038). My error of last night, in the adaptation to the proportional tax; renamed, and the test is running again (run 37579944854).

**Later the same morning.**
- G+S+E calibrated in France and Germany (MPC 0.414 and 0.402, multipliers 1.7 and 1.7 with places): **all eight configurations of the new regime in both countries.** Italy has six; its G+S+A+E was caught in a loop (a resumed job repeated 151 minutes of scans and then had too little budget left for the full-grid stage, three times). The script now keeps a checkpoint at the door of that stage (`pre5b`), and the run was started again (37580113063); G+S+E follows it by the chain.
- `BASE_REGIME` is now `:floor_edu_trans`.
- **Transitions with S on pass** (`test_transition_s.jl 40 full FR base`, run 37579944854): a zero shock stays at the steady state (participation to 2e-12, consumption to 3e-11, the first period the steady-state economy). The same recession in France G+S+A: participation falls by 0.5 points at the peak of unemployment and is back within three years; consumption -0.95% at the trough; welfare -0.37% of consumption (-0.39% without S). So row M8 holds with S on and off, one asset, places off.

**Transitions with S on, Germany and Italy** (runs 37585044718, 37585047764): a zero shock exact in both (consumption to 3e-11 and 5e-11). The recession: participation falls by 0.28 points at the peak in Germany and by 0.02 in Italy, where few of the unemployed took part to begin with; welfare -0.21% and -0.32% of consumption, as without S. Row M8 holds in the three countries with S on and off.

**The base's indicators against official figures (row B3)** (`indicator_table.jl GSA FR DE IT`, run 37585133233; G+S+A; Eurostat 2021 and the HFCS 2021):

| | France: model, official | Germany | Italy | |
|---|---|---|---|---|
| S80/S20, under 65 | 4.71, 4.72 | 5.07, 5.08 | 6.02, 6.04 | targeted |
| Gini of disposable income | 0.306, 0.296 | 0.320, 0.304 | 0.347, 0.324 | test, within a quarter |
| below 50% of median income | 0.112, 0.097 | 0.116, 0.109 | 0.142, 0.145 | test, within a quarter |
| below 60% of median income | 0.187, 0.156 | 0.198, 0.170 | 0.218, 0.209 | test, within a quarter |
| in-work poverty (60%) | 0.173, 0.067 | 0.189, 0.086 | 0.193, 0.117 | test, off in the three |
| liquid-asset poor (three months) | 0.511, 0.335 | 0.506, 0.320 | 0.361, 0.341 | test, off in France and Germany |
| income and asset poor | 0.095, 0.064 | 0.116, 0.073 | 0.131, 0.107 | test, off in France and Germany |
| hand-to-mouth | 0.217, 0.222 | 0.225, 0.225 | 0.179, 0.179 | targeted |
| liquid wealth over income | 0.120, 0.059 | 0.121, 0.140 | 0.263, 0.272 | test (Italy: targeted); off in France |
| MPC out of a month's income | 0.414, 0.392 | 0.403, 0.468 | 0.318, 0.469 | test; off in Italy |

14 of 23 untargeted rows are within a quarter of the official figure (or 0.02 for a small share). Income poverty at both lines and the Gini pass in the three countries with only S80/S20 fitted. Two things are systematically off. In-work poverty is about twice the official rate: the model's low incomes are low earnings, where in the data many of the poor are not in work, and a statutory minimum wage compresses the bottom of earnings; a lognormal process fitted to S80/S20 cannot do both. And liquid-asset poverty is 0.51 against 0.33 in France and Germany: the model's single asset is liquid wealth on the narrow definition, whose median sits at the three-month line, while the survey's asset-poverty rate is on equivalised liquid financial wealth per person (Balestra and Tonkin 2018; `hfcs_protocol/HFCS_READINESS.md`), a broader set of assets; the two rows are not on the same definition and the comparison should be rebuilt on one.

**Regression on the final code (2026-10-07, 09:15 UTC).** After the night's changes to the engine, the place layer, the calibration script and the transition solver: the old base's on/off pass is 16 of 16 in France, Germany and Italy (runs 37595447954, 37595451696, 37595454882); the engine test is 12 of 12 (37595458150); the version 2 transition tests are exact again with S off and on (37595408774, 37595404822: drift 1e-9; the run of 04:52 had failed on the variable-name error, which broke version 2 too while it lasted). So nothing that worked before the build is broken by it.

**Italy's last two configurations.** G+S+A+E reached the door of the full-grid stage at 08:47 with the new checkpoint and handed over; the job now running (37596094530) starts at that stage. G+S+E follows by the chain. Their files are to be fetched from the artifacts, read and committed by hand; a release tag for the base waits for them.

**E's environmental side by type of place** (`e_environment.jl GAE`, second part, run 37599561026, 9 of 9). I had written in section 31 that no series on exposure was in the repository; that was wrong for the degree-of-urbanisation typology, where `data/place/place_by_degurba.csv` has the share of people reporting pollution, grime or other environmental problems where they live (Eurostat ilc_mddw05, 2023). The place layer on that typology at the base's parameters (calibrated on regions, nothing refitted; the national hand-to-mouth share stays at 0.220, 0.221, 0.178):

| | footprint, t CO2e per head: cities, towns, rural | exposure to pollution, %: cities, towns, rural | hand-to-mouth, model | hand-to-mouth, HFCS |
|---|---|---|---|---|
| France | 6.12, 5.93, 6.02 | 24.1, 14.5, 8.6 | 0.207, 0.212, 0.243 | 0.244, 0.217, 0.154 |
| Germany | 7.76, 8.05, 8.10 | 22.3, 14.7, 8.5 | 0.195, 0.232, 0.252 | not in the targets file |
| Italy | 6.97, 6.73, 6.66 | 14.2, 8.6, 4.7 | 0.171, 0.181, 0.183 | not in the targets file |

Two readings. The two environmental sides do not coincide: the footprint is nearly the same in the three types of place, since it follows consumption, while exposure is nearly three times higher in cities than in the countryside in the three countries. And an untargeted test the place layer fails: in France the HFCS has the most hand-to-mouth households in cities and the fewest in rural areas, and the model has the reverse, because its rural places have lower incomes and less safe jobs and nothing in it makes city households hold less liquid wealth (housing costs, younger households). Exposure is an indicator here and enters no decision; whether it should enter welfare is a question for the Beyond-GDP side.

**Italy G+S+A+E calibrated** (run 37596094530, 13:15 UTC on 7 October): the checkpoint at the door of the full-grid stage worked, and the job spent its 267 minutes on that stage alone. Participation 0.125 (multiplier 1.3, band 1.1 to 1.7), hand-to-mouth 0.178 against 0.18, liquid wealth over income 0.263 against 0.272, MPC 0.317. Italy has seven of eight; G+S+E was started by the chain (run 37627069210). 23 of 24 configurations of the base are in.

## 34. The rule on parameters, the provenance audit, and the MPC as a target (2026-10-07, decided by the user)

**The rule.** Every parameter of the model is one of four things: (a) a published or official figure, cited with table and row and checked against the published source; (b) fitted by the calibration to a named data moment, with the identification shown; (c) a stated normalisation or definitional convention; (d) a numerical setting, tested for convergence. Nothing else is allowed: no value worked out by hand to make a result come right, no round number that looks reasonable, no parameter tuned to an untargeted outcome, no assumption without a source. An estimate for one country used for another is a transfer and is flagged as one. A new field in `SAGEConfig` or `SAGEParams` needs an entry below.

**What this withdraws.** The persistence of 0.97 to 0.98 of sections 31 and 32 was solved by hand from two GRID figures. It is not an estimate and is withdrawn as an option; the files tagged v3fetr are not to be used. The finding stands (five-year rank persistence too low), the remedy has to be a published process.

**The audit** (read from the repository on 2026-10-07 by a separate pass over the configuration, the engine defaults, `data/manual_inputs.csv`, the country table and its builder, the calibration script and the source notes; four of its entries checked against the code by hand). Class (a) or (b) with nothing to add: the replacement rates (OECD TaxBEN 2023), separation rates and the tertiary share (OECD, Eurostat), agency shares and belonging tastes (SES 2014, EU-SILC 2015, normalised to mean one), the effort target (HETUS 2010), the participation targets (EU-SILC 2015), the unemployed ratio (INSEE, Freiwilligensurvey, ISTAT; three concepts and years), dread (Pagel 2017, verified), the illiquid premium (Jorda-Schularick-Taylor), median to mean (Eurostat), the footprint (Eurostat), and the fitted parameters (effort scale, top patience, patience gap, persistent innovation, floor, participation technology, and on two assets patience and the fixed cost), each with its moment.

**Without a source, or an assumption, or a transfer (class e), thirteen items:**

| | item | value | what the repository says | remedy under the rule |
|---|---|---|---|---|
| 1 | private share of belonging, omega | 0.30 | "not identified"; it sets the multiplier | fit it where the data exist (regional spread: a lower bound, section 28) and report the multiplier as a band everywhere; never a point value |
| 2 | return on liquid wealth, two assets | 1.00 | "an assumption whose source is still to be fixed" | deposit rates less inflation by country, from an official series |
| 3 | return, one asset | 1.02 | "long-run r*", one value for three countries; the illiquid return is built on it | a country series (the bill rate of the same Jorda-Schularick-Taylor data as the premium), or one cited euro-area figure stated as the currency union's rate |
| 4 | income persistence, rho | 0.92 | Bayer and Juessen (2012), Germany 0.919, applied to France and Italy; estimated beside a fixed effect the model lacks | the whole of their process for Germany (below); for France and Italy a published estimate, or the transfer accepted by the user as a transfer |
| 5 | transitory standard deviation | 0.178 | the same table, Germany, applied to France and Italy; read from the discussion paper | the same; and the published table checked |
| 6 | place elasticity, epsilon | 0.4 | "0.3 to 0.5, estimated in sample" | the estimate with its standard error, or a published one |
| 7 | weight on social cohesion, Lambda | 0.8758 | "thesis, OECD BLI 2017, flagged for re-estimation" | re-derive from the cited source or normalise to one (kappa absorbs it in choices; it enters welfare) |
| 8 | time cost of participation, qbar | 0.04 | a common point inside a measured band (0.02 to 0.07); the diary gives 0.012, 0.047, 0.022 by country | the country's own measured value |
| 9 | risk aversion and effort curvature | 2, 2 | Havranek 2015, Chetty et al. 2011, no table or page | verify and record table and page |
| 10 | tolerance bands of the fit, the multiplier gate, the search bounds | several | hand-set | tie the bands to the targets' standard errors; state the gate and the bounds as numerical rules and show they do not bind |
| 11 | the window of the illiquid premium | 1980 to 2015 | chosen; 1950 to 2015 gives France 0.087 against 0.035 | state the rule that picks the window, or use the full sample |
| 12 | job-finding rate | 1 less the long-term share | a mapping, not a measured rate | a measured annual transition rate (labour force flows), or the mapping cited |
| 13 | the persistent innovation, eta | 0.26 to 0.30 | fitted to S80/S20, where the cited table says 0.10 | below |

**Cited but not verified:** Bayer and Juessen's Table 1 (read from IZA DP 4402); Cappellari (2004) for Italy's persistence (no table); Krueger, Mitman and Perri (2016) (from memory, and only the withdrawn trial used it); Cagetti (2003) and Lawrance (1991) (not reread); Havranek, Chetty et al., Holston-Laubach-Williams, Kaplan-Moll-Violante (no page or table recorded); the Freiwilligensurvey figures; Italy's replacement after month 24. The HFCS definition of narrow liquid wealth (saving accounts counted as illiquid, after Kaplan, Violante and Weidner 2014) is marked in `hfcs_protocol/HFCS_READINESS.md` as inferred from their Table 2 and to confirm.

**Other mismatches the audit found:** the fitted floors (0, 0, 0.19 of reference earnings) are not the statutory ones (0.23, 0.20, 0.27 of the average wage); vintages are mixed (2010 to 2023); the committed country table's two replacement-rate columns are not what the builder would write; `AUDIT_INPUTS.md` is out of date.

**The income process from the field.** Bayer and Juessen's Table 1 gives the whole process for Germany: persistence 0.919, variance of the persistent innovation 0.0102, of the transitory term 0.0316, of the household fixed effect 0.0280. The model takes the first and the third, overrides the second by a factor of seven in variance to reach S80/S20, and has no fixed effect. The version consistent with the source: all four as published, the fixed effect entering as a permanent type of household, and the dispersion that S80/S20 still asks for (more than one earner, hours, what the two education groups do not carry) carried by the permanent type and fitted to S80/S20, not by risk. Households then face the risk the source measures.

**The MPC as a target (the user: "let's target the MPC, let's do it properly").** The moment: the mean self-reported MPC out of a windfall of one month's income, HFCS 2021 (France 0.392, Germany 0.468, Italy 0.469; published for the 2017 wave by Drescher, Fessler and Lindner 2020, to be checked), which the model's statistic is already defined to match. The parameter: a spread of patience within a group, the device of Krusell and Smith (1998) and of Carroll, Slacalek, Tokuoka and White (2017), which the engine has and the base sets to zero. Feasibility is being probed before anything is built (`probe_spread_frontier.jl`, runs 37675865482, 37675869051, 37675872960): whether the spread reaches the survey figure with the hand-to-mouth share held, in each country, and what it does to liquid wealth. Two things the target will not settle and that are to be reported beside it: in the survey the MPC is nearly flat across liquid wealth (France 0.35 in the lowest fifth to 0.48 in the highest, Germany 0.50 to 0.44, Italy 0.53 to 0.40) where the model's falls steeply; and the three countries' liquid wealth on the narrow definition (0.059, 0.140, 0.272 of income) differs by where savings are kept, since on the broad definition it is 0.380, 0.442, 0.316.

## 35. The citations checked, the income process in the literature, and what targeting the MPC takes (2026-10-07, evening)

**The base is complete**: Italy G+S+E calibrated (run 37658556400; hand-to-mouth 0.178, liquid wealth 0.271 against 0.272, MPC 0.316), so all 24 configurations of `calibration_v3fet_*` are in. It is the base of record until the rule-compliant one below replaces it; no release tag yet.

**Citations read in the source** (two separate passes on 2026-10-07; every number below was read in the paper's text, the version named; extracts kept outside the repository).

| item | what the model says | what the source says | verdict |
|---|---|---|---|
| risk aversion 2 | Havranek (2015) | Havranek's preferred elasticity of intertemporal substitution is 1/3 (risk aversion 3); 0.5 is the uncorrected mean he attributes to reporting bias (working-paper version, Table 3 and conclusion) | not supported by the citation |
| | | McKay, Nakamura and Steinsson (2016, AER 106(10)): "We set the coefficient of risk aversion to 2" (NBER WP 20882, p. 16, table p. 15) | supported by this source |
| effort curvature 2 (Frisch 1/2) | Chetty et al. (2011) | Table 1: micro Frisch 0.54 on the intensive margin; they recommend 0.5 intensive, 0.25 extensive (authors' manuscript). McKay, Nakamura and Steinsson set 1/2 as well | supported |
| return 1.02 | Holston, Laubach and Williams (2017) | euro-area natural rate 2.1 in 2007, -0.3 in 2016, 0.6 to 0.7 in 2019 to 2022: two percent is a pre-2008 level | not supported for the model's years |
| | | Kaplan, Moll and Violante (2018, AER 108(3)), p. 722: "We set the steady-state real return on liquid assets at 2 percent per annum"; McKay, Nakamura and Steinsson: a 2% annual interest rate | supported by these, as the literature's value, not as a measured euro-area rate |
| death 1/45 | Kaplan, Moll and Violante (2018) | p. 722 and Table 6: quarterly death rate 1/180, "average lifespan of a household is 45 years" | supported |
| hand-to-mouth rule and shares | Kaplan, Violante and Weidner (2014) | half a pay period of income, pay every two weeks (pp. 88 to 90, 101); HFCS liquid assets: cash, sight accounts, mutual funds, shares, bonds; certificates of deposit and saving bonds illiquid (pp. 94 to 96); Table 5: poor 0.032, 0.074, 0.083, wealthy 0.173, 0.248, 0.155 | supported; saving accounts are not named either way |
| survey MPC | Drescher, Fessler and Lindner (2020) | Table 2, HFCS 2017: France 41.8, Germany 51.3, Italy 48.1; the question is on a lottery win of one month's income, spent "over the next 12 months" | supported |
| patience by education | Lawrance (1991), Cagetti (2003) | Lawrance: time preference 12% to 19% across income, race and education (abstract only). Cagetti: not opened; second-hand 0.948 and 0.989 by education | partly; Cagetti not verified |
| spread of patience | Carroll, Slacalek, Tokuoka and White (2017) | seven types, uniform; annual MPC 0.42 to 0.44 when matched to liquid assets, 0.21 to 0.23 when matched to net worth (Table 3, p. 23) | supported |
| floor | Hubbard, Skinner and Zeldes (1995) | a floor of 7,000 dollars of 1984 | supported |
| asset poverty | Balestra and Tonkin (2018) | three months of the 50% poverty line, over individuals (p. 56, Table 6.1) | supported |
| Bayer and Juessen (2012), Table 1 | | the discussion-paper numbers confirmed exactly; the published letter could not be opened | not yet verified in the published version |

So risk aversion, the effort curvature and the two percent return keep their values and change their citation, to McKay, Nakamura and Steinsson (2016) and Kaplan, Moll and Violante (2018), whose published tables are still to be checked against the working papers read. The return is then "the literature's value" and is the same in the three countries because it is the currency union's.

**The income process in the literature.** No seminal paper gives France, Germany and Italy a process on one method. The seminal ones are for the United States: Krueger, Mitman and Perri (2016): persistence 0.9695, persistent innovation variance 0.0384, transitory 0.0522, household earnings after tax, no fixed effect (confirmed in NBER WP 22319); Kaplan, Moll and Violante (2018): two jump-drift components fitted to US earnings changes, no annual persistence printed. The 2010 Review of Economic Dynamics issue has Germany and Italy with a unit root and prints no usable table; France is not in it. Bayer and Juessen (2012) cover Germany, the United Kingdom and the United States, on wages, with a fixed effect.

The one published source with the three countries on one method is Ampudia, Cooper, Le Blanc and Zhu (2024, AEJ: Macroeconomics 16(3), "MPC heterogeneity and the dynamic response of consumption to monetary policy"; read as BIS WP 1102, Table 16, p. 48): household after-tax non-asset income including transfers, ECHP 1994 to 2001, an AR(1) plus a transitory shock with no fixed effect, by education.

| | persistence: no college, college | persistent innovation variance | transitory variance |
|---|---|---|---|
| Germany | 0.895, 0.937 | 0.022, 0.020 | 0.016, 0.011 |
| France | 0.971, 0.941 | 0.031, 0.023 | 0.006, 0.018 |
| Italy | 0.944, 0.921 | 0.072, 0.029 | 0.020, 0.022 |

It is the model's own income concept (household, after tax and transfers), its own structure (persistent plus transitory, no fixed effect) and its own two groups. The same paper estimates discount factors of about 0.79 for the less educated and 0.85 to 0.90 for graduates in these countries, close to the base's fitted 0.83 to 0.87 and 0.89 to 0.92, and takes its difference by education from Cooper and Zhu (2015). Costs: the ECHP has eight waves; it is not a seminal paper; and the two working-paper versions label the two variance columns in opposite order (the text settles it: the persistent variance is the larger, lower for graduates), so the published table has to be read before it is cited. GRID's published Table 2 (p. 1341) gives the standard deviation of one-year earnings changes as France 0.45, Germany 0.38, Italy 0.45, for the untargeted test.

With this process the persistent innovation is no longer fitted, and S80/S20 becomes a test.

**What targeting the MPC takes on one asset.** Two probes on the base's G (`probe_spread_frontier.jl`, runs 37675865482 to 37675872960; `probe_mpc_target.jl`, runs 37684513986 to 37684521398).

A spread of patience within a group, the device I proposed, does not move the MPC when the hand-to-mouth share is held: France 0.414 at no spread to 0.393 at 0.12, Germany 0.404 to 0.392, Italy 0.307 to 0.303. The patient end rises to keep the share, and the mean MPC falls a little. So on one asset the MPC and the hand-to-mouth share are one decision, patience, and they cannot both be targets with nothing else free.

Patience fitted to the survey MPC in place of the hand-to-mouth share:

| | patience | MPC | hand-to-mouth, model and HFCS | liquid wealth over income, model and HFCS | fall on job loss |
|---|---|---|---|---|---|
| France | 0.898 (from 0.889) | 0.392 | 0.196, 0.222 | 0.142, 0.059 | 0.145 |
| Germany | 0.881 (from 0.904) | 0.468 | 0.300, 0.225 | 0.087, 0.140 | 0.278 |
| Italy, floor kept | 0.867 (from 0.924) | 0.469 | 0.319, 0.179 | 0.093, 0.272 | 0.306 |
| Italy, no floor | 0.858 | 0.469 | 0.243, 0.179 | 0.091, 0.272 | 0.336 |

The literature's own benchmark is in the same place: a model with a spread of patience matched to liquid assets gives an annual MPC of 0.42 to 0.44, and matched to net worth 0.21 to 0.23 (Carroll et al. 2017, Table 3). The base's 0.41 and 0.40 for France and Germany are what the field gets from matching liquid wealth; Italy's 0.31 comes with liquid wealth two to four times theirs.

**The choice this leaves, for the user.** (A) The MPC is the target and the hand-to-mouth share and liquid wealth are reported (the table above). (B) The wealth side is the target and the MPC is reported (the base). (C) All of them enter one criterion weighted by their sampling variances, the simulated method of moments of the paper above (its equation 10: a diagonal weighting matrix of inverse variances), which also replaces the hand-set tolerance bands of the audit's item 10; each country then lands between (A) and (B) where its standard errors put it.

## 36. Version 4: the model under the rule (2026-10-07 and 08, decided by the user)

**The user's decisions.** (1) The MPC is a target, by option C of section 35: one criterion over all the moments, each HFCS moment weighted by the inverse of its sampling variance. (2) The income process is the published one of Ampudia, Cooper, Le Blanc and Zhu (2024), by country and education. (3) Then, once every version 4 configuration is calibrated: every remaining parameter at its measured value (the open items of section 34), and the MPC and the rest made to work in every country, not only France.

**What version 4 is** (`country_config(code; v3 = :v4)`, files `calibration_v4_*`, calibration with `SAGE_V4=1`, workflow input `v4=1`; the earlier regimes and their files are untouched and still reproduce: engine test 12 of 12 after every step below).

| piece | in the code | source or moment |
|---|---|---|
| income process by education cell: persistence, persistent innovation, transitory shock | `rho_cell`, `eta_cell`, `sd_eps_cell`; `data/manual_inputs.csv` rows `rho_low`, `var_persistent_low`, `var_transitory_low` and `_high` | Ampudia et al. (2024), Table 16 of BIS WP 1102; nothing fitted. **The published table is still to be read by the user** |
| permanent component of income | `perm_sd`, `n_perm = 3`: types of household inside a cell (`perm_nodes`, `betas_of`), earnings and benefits scaled, no risk | fitted to S80/S20 (Eurostat, under 65), to a numerical tolerance |
| time cost of participation | `measured_qbar`: France 0.0119, Germany 0.0466, Italy 0.0216 | each country's diary measure for formal volunteering (`data/timeuse/qbar_from_data.csv`, definition A, wave 2010) |
| weight on social cohesion | `Lambda = 1` | a normalisation |
| the job's effort levels | `ref_prop = true`: found in the economy without floor and transitory part, taxed in proportion like the economy itself (rate and levels found together) | per head, the lowest states of Italy's process could not pay and the levels were erratic |
| the fit | `fit_v3` in version 4: parameters effort scale, top patience, patience gap, permanent dispersion, floor (where fitted); criterion over effort and S80/S20 (numerical tolerance), and the hand-to-mouth share, its gap by education, median liquid wealth and the MPC in standard errors (`SE_HTM`, `SE_GAP`, `SE_LIQ`, `SE_MPC`) | simulated method of moments, diagonal inverse-variance weights (Ampudia et al. 2024, equation 10) |
| risk aversion 2, effort curvature 2, return 2% | unchanged | re-cited to McKay, Nakamura and Steinsson (2016) and Kaplan, Moll and Violante (2018); published tables to check |

Transitions refuse an economy with permanent types (their tax and benefit sums read one type); the two-asset reference is not moved to version 4 yet.

**G under version 4** (run 37697334357; France and Germany committed, Italy still running at the time of writing). Misses in standard errors in brackets.

| | France | Germany |
|---|---|---|
| top patience, gap | 0.926, 0.029 | 0.941, 0.044 |
| permanent dispersion (sd of log) | 0.19 | 0.48 |
| S80/S20, model and official | 4.73, 4.72 | 5.08, 5.08 |
| MPC, model and survey | 0.388, 0.392 (-0.7) | 0.393, 0.468 (-7.1) |
| hand-to-mouth, model and HFCS | 0.237, 0.222 (+2.3) | 0.263, 0.225 (+3.4) |
| liquid wealth over income | 0.063, 0.059 (+1.7) | 0.082, 0.140 (-5.1) |
| gap by education | 0.093, 0.105 (-0.9) | 0.175, 0.167 (+0.4) |
| criterion (6 moments, 4 parameters) | 9.6 | 87.6 |
| fall in consumption on job loss | 0.177 | 0.289 |
| in-work poverty, model and official | 0.171, 0.067 | 0.194, 0.086 |

- **France** is the best fit of any version: the MPC and liquid wealth on target together, which the old base could not do (liquid wealth twice its target), at a patience of 0.93.
- **Germany** is rejected on the MPC by seven standard errors: it cannot be raised without more hand-to-mouth households and less liquid wealth, both already off. Without the permanent component Germany's S80/S20 was 2.38 against 5.08 (the published process alone is far too compressed); with it inequality is right.
- **Italy** without the permanent component (first pass, run 37687657872): the criterion drops the floor, MPC 0.412 against 0.469, hand-to-mouth 0.194 against 0.179, liquid wealth 0.101 against 0.272, S80/S20 5.76 against 6.04. With the permanent component the first fit failed on the effort levels (the per-head reference), which `ref_prop` repairs.

**Started**: France and Germany G+A and G+S+A (run 37707846432; G+S by the chain) and G+E with the floor fitted there (run 37707849048). Italy follows its G. Version 4 has three types of household per cell, so about three times the compute of the old base; the checkpoint at the door of the full-grid stage (`pre5b`) carries the long ones over the six-hour limit.

**Open under version 4, for the stage the user asked for next.**
1. The MPC in Germany (and Italy at its liquid wealth): on one asset the MPC, the hand-to-mouth share and liquid wealth are tied by patience (section 35). What is left to examine, each from a source and not by hand: the definition of liquid wealth across countries (narrow 0.059, 0.140, 0.272 against broad 0.380, 0.442, 0.316: the narrow one counts where savings are kept); the survey MPC's flat profile across liquid wealth; a spread of patience fitted jointly (it did not move the MPC at a given hand-to-mouth share, but it is free in the criterion); the 2017 wave against the 2021 one.
2. The audit's remaining items (section 34): the private share of belonging, the place elasticity, the job-finding rate, the window of the illiquid premium, the liquid return of the two-asset reference, Cagetti (2003), the published versions of every table read as a working paper.
3. In-work poverty about twice the official rate in every version.
4. Transitions and the two-asset reference on version 4.

**Italy G under version 4, and G+A in France and Germany** (runs 37697334357 and 37707846432, committed 2026-10-08).
- Italy G: top patience 0.939, gap 0.106, permanent dispersion 0.11, a small floor (0.042); S80/S20 6.03 against 6.04; MPC 0.410 against 0.469 (-3.2 standard errors); hand-to-mouth 0.196 against 0.179 (+0.6); liquid wealth 0.101 against 0.272 (-6.1); criterion 47.9. The criterion gives up Italy's liquid wealth for its MPC, as the standard errors tell it to, and reaches neither. Fall in consumption on job loss 0.32.
- France G+A: criterion 4.8, MPC 0.388, hand-to-mouth 0.233, liquid wealth 0.061, S80/S20 4.73; the permanent dispersion falls to 0.08 because the agency shares already separate the two education groups.
- Germany G+A: as G (MPC 0.394, criterion 87.5).

Running: France and Germany G+S+A and G+E (37707846432, 37707849048), Italy G+A, G+S+A and G+E (37710406114, 37710408485). Then G+A+E and G+S+A+E for each (G+S and G+S+E by the chain).

**Germany G+S+A, Italy G+A and G+S+A under version 4** (runs 37707846432 and 37710406114, committed 2026-10-08, 01:50 UTC).
- Germany G+S+A: participation 0.278 with both education cells on target (0.251, 0.350 against 0.252, 0.349), multiplier 1.9 (band 1.3 to 3.1); the G+A moments unchanged (MPC 0.394 against 0.468, hand-to-mouth 0.264 against 0.225, liquid wealth 0.081 against 0.140, criterion 87.4).
- Italy G+A: top patience 0.935, gap 0.104, **permanent dispersion at its lower bound of zero and S80/S20 6.35 against 6.04**. With A on, the agency shares differ by education and add dispersion between the two groups, as in France, where the permanent dispersion fell from 0.19 to 0.08. In Italy the published process and those shares together already give more inequality than the official figure, so nothing is left for the fit to take away. MPC 0.415 against 0.469 (-2.9), hand-to-mouth 0.197 against 0.179 (+0.6), liquid wealth 0.097 against 0.272 (-6.3), criterion 86.8, of which about 38 is the S80/S20 miss. In-work poverty 0.211 against 0.117; fall in consumption on job loss 0.33.
- Italy G+S+A: participation 0.124 with both cells on target (0.116, 0.165), multiplier 1.2 (band 1.1 to 1.6).

A fifth item for the stage after the calibrations: **Italy's income inequality with A on** (5% above the official figure with no parameter left to lower it). The low-education persistent variance read for Italy (0.072) is three times that of the other cells, which makes the check of the published table of Ampudia et al. (2024) the first thing to do there.

**The scorecard on version 4 (2026-10-08, 02:00 UTC).** The old base (files `v3fet`) stays at 9 met, 11 partly, 2 not, of 22 (section 33), but it carries parameters the rule of section 34 excludes. Version 4 is the line that can be defended, and it has to earn each row again:

| | on version 4 now | what closes it |
|---|---|---|
| M1 budget and closure | to retest | the engine test with permanent types and the cell processes |
| M2 standard blocks | met | a published income process by education, permanent types |
| M3 every parameter sourced or identified | partly, closer | income process, cohesion threshold and weight now sourced or normalised; the audit's items of section 34 left |
| M4 every configuration on its targets | partly: 8 of 24 calibrated | France passes the criterion; Germany rejected (MPC, liquid wealth); Italy rejected (liquid wealth, MPC, S80/S20 with A) |
| M5 spending behaviour | partly | MPC now a target: France on it, Italy 0.41 (was 0.31), Germany 0.39 against 0.47; the fall on job loss 0.18, 0.29, 0.33 against 0.07 to 0.16 |
| M6 who holds no buffer | partly | by education fitted; regions and types of place to rerun |
| M7 wealth distribution | to rerun | the two-asset reference is on the old base |
| M8 transitions | not on version 4 | the code refuses permanent types; sums over types to write |
| N1 method | met | |
| N2 exact reductions | to rerun | on/off pass with the new settings |
| N3 accuracy | to rerun | Euler errors and grids with three types per cell |
| N4 independent solver | not | version 2 only |
| N5 reproducible | mostly met | |
| N6 equilibria with S | to rerun | the count in three countries |
| B1 recognised dimensions | partly | unchanged |
| B2 official data | met | |
| B3 indicators against official figures | to rerun | in-work poverty still about twice official (0.17 to 0.21 against 0.07 to 0.12) |
| B4 welfare tables, B5 accessible | partly | later, by the user's ordering |
| U1 any order of switches | partly: 8 of 24 | |
| U2 policy levers with bands | partly | multipliers 1.9 (Germany), 1.2 (Italy) with bands |
| U3 a new country | not tried | later |

Count on version 4: 4 met, 9 partly, 6 to rerun (met or partly on the old base; the reruns are tests, not builds), 3 not. The rows that decide whether version 4 passes the old base are M4 and M5 in Germany and Italy, and M8.

**France G+S+A and Germany G+S under version 4** (runs 37707846432 and 37713471498, committed 2026-10-08, 02:40 UTC). France G+S+A: participation 0.232 with both cells on target (0.201, 0.290 against 0.203, 0.291), multiplier 1.6 (band 1.2 to 2.3), the G+A moments unchanged. Germany G+S: participation 0.279, multiplier 1.9; the two cells are not separated without A (0.277, 0.284 against 0.252, 0.349), as on the old base. 10 of 24 configurations of version 4 are in; G+S in France and Italy and G+E in the three countries are running.

**G+E in France and Germany, G+S in Italy under version 4** (runs 37707849048 and 37713633280, committed 2026-10-08, 03:35 UTC).
- France G+E (14 regions, national moments): MPC 0.388 against 0.392, hand-to-mouth 0.238 against 0.222, liquid wealth 0.063 against 0.059, S80/S20 4.73; criterion 11.0. The floor fitted with places is zero, as in G, so the configurations without places need no refit.
- Germany G+E: as G (MPC 0.393, hand-to-mouth 0.262, liquid wealth 0.082, criterion 86.3); floor zero as in G.
- Italy G+S: participation 0.124, multiplier 1.2; without A the permanent dispersion is 0.12 and S80/S20 is on target (6.05 against 6.04), which confirms that Italy's overshoot of inequality comes with the agency shares.
- 13 of 24 configurations of version 4 are in. Started: G+A+E and G+S+A+E in France and Germany with the floor from G+E (G+S+E by the chain). Running: Italy G+E, France G+S.

## 37. Measured values prepared for the stage after the calibrations (2026-10-08)

The user's order: finish every version 4 configuration, then put every remaining parameter at its measured value, then make the MPC and the rest hold in every country. This section collects the measured values while the calibrations run; **nothing here is in the model yet**, and every change below means one more calibration of everything.

**Audit item 12, the job-finding rate.** The model uses 1 less the share of the unemployed out of work a year or more (OECD 2023): 0.755, 0.689, 0.440 for France, Germany and Italy. Eurostat measures the annual transition itself in the Labour Force Survey's longitudinal data (table `lfsi_long_a`, status a year apart, both sexes; read through the Eurostat API on 2026-10-08; 2021 is missing in the three countries, the survey's break year):

| share of those unemployed a year earlier | France 2019, 2023 | Germany 2019, 2023 | Italy 2019, 2023 |
|---|---|---|---|
| in work | 0.361, 0.410 | 0.409, 0.467 | 0.247, 0.288 |
| still unemployed | 0.398, 0.337 | 0.317, 0.264 | 0.390, 0.363 |
| out of the labour force | 0.241, 0.254 | 0.274, 0.269 | 0.362, 0.349 |
| in work, among those still in the labour force | 0.475, 0.549 | 0.563, 0.639 | 0.388, 0.443 |
| the model's mapping (OECD 2023) | 0.755 | 0.689 | 0.440 |
| employed a year earlier, now unemployed (labour force) | 0.029, 0.030 | 0.012, 0.013 | 0.021, 0.015 |

The model has no state out of the labour force, so the row to use is the one among those still in the labour force: 0.55, 0.64 and 0.44 in 2023. Italy's mapping agrees with the measured rate; France's and Germany's are above it (0.755 against 0.55, 0.689 against 0.64). Why the mapping differs is not established here; one candidate is that the share of spells under a year reflects every exit from unemployment in a stationary state, exits from the labour force included, and not exits to work alone. EU-SILC's table of the same transition (`ilc_lvhl30`, self-declared status) gives lower rates still (0.31, 0.25, 0.25 in work a year later) and is the less suitable one: its status is the main activity over the income year. Under the rule the measured rate replaces the mapping; the separation rate by education then follows from the unemployment rates as now (u f / (1 - u)). For France this lowers both rates by about a quarter: spells are fewer and longer, which bears on the precautionary motive and on the fall in consumption on job loss. The year (2023, as the unemployment rates, or an average of years around the HFCS wave) is to be fixed by one rule for every labour-market input.

**Italy's inequality with A on (section 36).** The agency shares are the pay premium by education (below tertiary 0.90, tertiary 1.46 of mean pay in Italy). With A off the two groups have the same mean pay and the permanent dispersion fitted to S80/S20 stands in for the premium (0.11 in Italy, 0.19 in France); with A on the premium is in, and in Italy the published process within the groups plus the premium gives 6.35 against 6.04. The published persistent variance for Italy's lower group (0.072 a year at a persistence of 0.944) implies a stationary variance of the log of 0.66, against 0.19 for the tertiary group and 0.11 to 0.52 in the other cells. Two things to settle before any remedy: the published table (whether 0.072 is the number in the journal version), and the income concept of the estimate (the model sets its income after a proportional tax against an official ratio of disposable income, which progressive taxes compress).

## 38. Version 4: the tests taken again (2026-10-08, from 03:30 UTC)

France G+S is in (run 37718053816: participation 0.233, multiplier 1.6): **14 of 24 configurations**. France and Germany have G, G+A, G+S, G+S+A and G+E; Italy the first four, its G+E running.

**Transitions on version 4 (row M8).** The solver refused permanent income types because the path's benefit bill and tax base were summed over one type of a cell. They are now summed over the types with their weights (`transition_core.jl`, commit f994c30). `test_transition_base.jl` with `V4` among its arguments, G and G+A, three countries (runs 37722896985, 37722894894): 12 of 12 each.
- A zero shock stays at the steady state to 1e-10 (consumption, assets, hand-to-mouth), the tax rate exactly, and the first period is the steady-state economy to six decimals.
- The recession (job-loss rates half as high again for two years), G+A: consumption -1.0%, -0.5%, -0.9% at the trough in France, Germany and Italy; welfare -0.33%, -0.15%, -0.57% of consumption, the lower education group losing two to four times what the tertiary group loses. A higher benefit along the path takes the loss to -0.20%, -0.04%, -0.08%.
- The old base as a regression (run 37722901694): 12 of 12, so the change breaks nothing there.
- With S on (France G+S+A, run 37722899172): running.

**The MPC's properties (row M5)** (`test_mpc_economics.jl CODE G v4`, runs 37722995777, 37722997979, 37723000071). Every economic property holds in the three countries: the MPC falls across wealth quintiles (0.56 to 0.18 in France, 0.58 to 0.17 in Germany, 0.64 to 0.17 in Italy), is higher for the hand-to-mouth (0.53, 0.56, 0.62 against 0.34, 0.33, 0.36), falls with the size of the windfall, is larger out of a loss, higher for the unemployed (0.78, 0.85, 0.77), and consumption, saving and earnings add up. The three permanent income types of a cell have the same MPC to 0.001, as scaling implies; the check that ranked types by patience read them as patience types and is now skipped where the types share one patience. For the survey's flat profile this matters: the model's MPC falls by a factor of three across liquid wealth where the survey's does not fall.

**Indicators against official figures (row B3)** (`indicator_table.jl GSA V4`, run 37722993449). Liquid wealth and the MPC are targets in version 4 and no longer count as tests (the script's labels are corrected after this run). Of the 18 rows left as tests, 7 are within a quarter (9 of the same 18 on the old base):

| | France: model, official | Germany | Italy |
|---|---|---|---|
| Gini of disposable income | 0.295, 0.296 | 0.317, 0.304 | 0.345, 0.324 |
| below 50% of median income | 0.136, 0.097 (off) | 0.119, 0.109 | 0.168, 0.145 |
| below 60% of median income | 0.201, 0.156 (off) | 0.192, 0.170 | 0.235, 0.209 |
| in-work poverty | 0.186, 0.067 (off) | 0.182, 0.086 (off) | 0.211, 0.117 (off) |
| liquid-asset poor (three months) | 0.678, 0.335 (off) | 0.606, 0.320 (off) | 0.559, 0.341 (off) |
| income and asset poor | 0.118, 0.064 (off) | 0.128, 0.073 (off) | 0.174, 0.107 (off) |

The bottom of the income distribution is too heavy in the three countries with S80/S20 on target, and more so than on the old base in France (below half the median 0.136 against 0.112 there and 0.097 officially). It is the same reading as Italy's inequality with A: the published processes describe income before the tax and transfer system compresses it, and the model's fitted floor is zero in France and Germany and 0.04 in Italy where the statutory minimum incomes are 0.20 to 0.27 of the average wage (the audit's list of mismatches, section 34). A floor set from official figures in place of a fitted one, with the permanent dispersion refitted to S80/S20, is a candidate for the parameter stage, but not a simple one: `data/benefits/floor_and_replacement.md` (2 October) shows that Germany's minimum income is already inside its replacement rate, that Italy's excludes childless households from 2024, and that France's (0.23 of the gross average wage for a jobless single person) comes with an in-work supplement the model has no counterpart for. Which official figure the floor would take, and for whom, has to be settled from that note before any run; the measured job-finding rate goes to the same stage.

**On and off, Italy (rows N2, M1)** (`onoff_v3.jl v4 IT`, run 37722986449): 15 of 16. The budget balances to 1e-16 in the four configurations, each meets its effort, participation and the 0.02 band on the hand-to-mouth share, A widens the gap in participation between the education groups, belonging adds to welfare. The one failure: with S off participation is 3e-4 against the test's bound of 1e-4 (0.002 in France). With no payoff from taking part, what is left is the logit's residual at the time cost, and the time cost is now the measured one (0.022 of time in Italy, 0.012 in France, where 0.04 was used before). Its size is small (3e-4 of households giving 0.022 of their time, 0.002 giving 0.012 in France; not measured against an economy with participation shut), but a switch that is off should be exactly off: participation set to zero when the social payoff is zero, in the household's problem. That is a solver file, so it waits for the calibrations that may resume.

**Later (06:10 UTC).**
- **Transitions with S on, version 4** (France G+S+A, run 37722899172): a zero shock stays put (participation to 1e-11, consumption to 7e-11, the first period the steady-state economy to six decimals, tax per head equal). The recession: participation -0.45 points at the peak, consumption -1.03% at the trough, welfare -0.33% of consumption, back within eight years. **Row M8 is met on version 4** for France with S on and for the three countries with S off; Germany and Italy with S on are started.
- **On and off, Germany and France** (runs 37722984310, 37726440251). Germany 12 of 16: reductions exact (participation 1e-12 with S off), the budget balanced in the four configurations, A widens the gap between the groups; the four failures are one fact, the hand-to-mouth share 0.26 against 0.225, outside the old band of 0.02, which is the rejection of section 36 and not a reduction. France 15 of 16: all but the residual participation with S off (0.002), as in Italy. So rows M1 and N2 hold on version 4 but for that residual in France and Italy, whose repair is a line in the household's problem.
- **Accuracy and equilibria, Italy** (`numerics_base.jl IT v4`, run 37722991009): 7 of 7. Mean Euler errors 10^-5.3 and 10^-5.7; doubling the asset grid or its top moves the hand-to-mouth share by 0.0001, liquid wealth by 0.001 and the MPC by 0.0002; one stable participation equilibrium in G+S and G+S+A, the solver's. Germany and France are running.
- **Germany G+A+E** (run 37722782934, 136 minutes): as G+A (MPC 0.395, hand-to-mouth 0.263, liquid wealth 0.080, S80/S20 5.07, criterion 86.4). **15 of 24.**

**07:00 UTC.**
- **Italy G+E was cancelled at the six-hour limit** (run 37710408485) inside the first step of its fit, with nothing kept: with 21 regions, the floor on (and fitted there) and three types per cell, one step (the point, a column per free parameter, the trial steps) is longer than a job, and the fit's checkpoint was per step. The fit now appends the moments of every point it evaluates to a checkpoint file, reads them back when resumed, and hands over before an evaluation that would not finish inside the budget (`fit_v3`, commit 4e9adc0; the script is not a solver file, so no running checkpoint is touched). Italy G+E restarted with a budget (run 37740255946). The same risk holds for France G+A+E and the two G+S+A+E now running on the earlier script, whose first step may not finish in six hours; if one is cancelled it is restarted on the new script.
- **Accuracy and equilibria, France** (`numerics_base.jl FR v4`, run 37726443040): 7 of 7. Doubling the asset grid moves the hand-to-mouth share by 0.0016, liquid wealth by 0.001, the MPC by 0.0001; one stable equilibrium in G+S and G+S+A. Germany is running.
- **Transitions with S on, Italy** (run 37735364378): a zero shock exact (participation to 4e-12, consumption to 8e-11); the recession takes consumption down 0.9% and welfare 0.57% of consumption, participation hardly moving (-0.02 points), as on the old base. Germany is running.

**08:40 UTC.**
- **France G+A+E** (run 37722782934, 302 minutes): criterion 6.8; MPC 0.387 against 0.392, hand-to-mouth 0.234 against 0.222, liquid wealth 0.062 against 0.059, S80/S20 4.73. **16 of 24.**
- **Accuracy and equilibria, Germany** (run 37722988733): 7 of 7 (mean Euler errors 10^-5.3 to 10^-6.0 over the six household types; the grid doubled moves the hand-to-mouth share by 0.0009, liquid wealth by 0.0016, the MPC by 0.0001; one stable equilibrium). **Rows N3 and N6 are met on version 4 in the three countries.**
- **Transitions with S on, Germany** (run 37735361758): a zero shock exact (participation to 9e-14); the recession takes participation down 0.30 points at the peak, consumption 0.5%, welfare 0.14% of consumption. **Row M8 is met on version 4 in the three countries, S off and on.**

**The scorecard on version 4 at 08:40 UTC: 8 met, 11 partly, 1 to rerun, 2 not, of 22** (the old base: 9, 11, 2).
- Met: M1 (budget), M2 (blocks), M8 (transitions), N1 (method), N3 (accuracy), N5 (reproducible), N6 (equilibria), B2 (official data).
- Partly: M3 (parameters: the audit's remaining items), M4 (16 of 24 calibrated; Germany and Italy rejected by the criterion), M5 (the MPC's properties hold; its level in Germany and Italy and the fall on job loss do not), M6 (regions to rerun), N2 (exact but for the residual participation with S off in France and Italy), B1, B3 (7 of 18), B4, B5, U1 (16 of 24), U2.
- To rerun: M7 (the two-asset reference, still on the old base).
- Not: N4 (independent solver), U3 (a new country).

**09:30 UTC.** Germany G+S+A+E handed over at the door of the full-grid stage after 313 minutes (run 37722782934 to 37751641948), as the `pre5b` checkpoint intends. France G+S+A+E was cancelled at the six-hour limit: its first stage ended at 301 minutes, the budget check before the scans let it go on by five minutes' margin (301 + 39 against 345), and the scans did not finish. Its stage-one checkpoint was kept, so it is restarted from there with a budget of 330 (resumed from run 37722782934).

## 39. Notes towards the MPC in Germany and Italy (2026-10-08; nothing adopted)

What the runs of sections 36 and 38 establish, set side by side:

| | France | Germany | Italy |
|---|---|---|---|
| survey MPC (HFCS 2021) | 0.392 | 0.468 | 0.469 |
| hand-to-mouth share | 0.222 | 0.225 | 0.179 |
| median liquid wealth over income | 0.059 | 0.140 | 0.272 |
| model MPC at the fitted point | 0.388 | 0.393 | 0.410 |
| model MPC, lowest to highest fifth of liquid wealth | 0.56 to 0.18 | 0.58 to 0.17 | 0.64 to 0.17 |
| survey MPC across liquid wealth (section 35) | 0.35 to 0.48 | 0.50 to 0.44 | 0.53 to 0.40 |

Across the three countries the survey MPC is higher where liquid wealth is higher and the hand-to-mouth share no larger. A buffer-stock household does the reverse, so no value of patience, and no mapping applied alike in the three countries, fits the three at once: whatever raises Germany's and Italy's MPC to the survey's at their liquid wealth takes France's above its own. The gap sits with households that hold liquid wealth: the survey has them spending 0.40 to 0.48 of a windfall, the model 0.17 to 0.30.

Candidates to examine at that stage, each to be read at its source before any use:
1. **Spending against consumption.** The survey asks what share of the windfall would be spent on goods and services within twelve months, durables included; the model's MPC is out of a flow of consumption. Laibson, Maxted and Moll (2022, NBER Working Paper 29664, "A Simple Mapping from MPCs to MPXs") give the mapping from one to the other with the durable share of spending, the real rate and the depreciation rate of durables; the durable share is in the national accounts by country. It raises the model's figure for every household, the wealthy included, which is where the gap is. Two limits known before reading it: it is a working paper (I found no journal version on 2026-10-08), so its use needs the user's acceptance; and a factor of about the same size in the three countries moves France off its target as it moves Germany towards its own.
2. **The survey question by country.** The MPC question is not a core HFCS variable and national questionnaires differ; Drescher, Fessler and Lindner (2020) is the published comparison for the 2017 wave. Whether France's lower figure is a difference of wording or of households is to be read there, with the 2017 wave against the 2021 one (collected during and after the pandemic, when liquid balances were unusually high).
3. **What the criterion weights.** The standard errors used are sampling errors of the survey mean. They do not carry the distance between a hypothetical question and the model's object, so the criterion treats the MPC as known to 0.006 to 0.019. Reporting the fit with and without the MPC row, and the MPC by hand-to-mouth status against the survey's, is a presentation that hides nothing and claims no more than the data support.

**The two-asset reference on version 4 (row M7)** waits for the parameter stage: with three types of household per cell a solve takes about three times the old 35 minutes, the script's search does not resume across jobs, and its liquid return is the audit's unsourced item 2, to be replaced before the reference is run again.

## 40. Version 4 at 18 of 24 (2026-10-08, 16:50 UTC)

- **Germany G+S+A+E** (runs 37722782934 and 37751641948, two jobs through the `pre5b` checkpoint): participation 0.280 with both education groups on target (0.254, 0.349 against 0.252, 0.349), multiplier 1.8 with places (band 1.3 to 2.6); the household moments as G+A+E (MPC 0.395, hand-to-mouth 0.263, liquid wealth 0.080). G+S+E follows by the chain (run 37788483241).
- **Italy G+E** (runs 37740255946 and 37772002755): the fit that keeps every evaluation handed over after four evaluations (288 minutes, about 70 minutes each with 21 regions and the floor on) and finished in the second job. Floor 0.035 of reference earnings with places against 0.058 in G (0.025 against 0.042 in the model's income units), an outlay of the order of 1e-5 per head in G; MPC 0.403 against 0.469 (-3.5), hand-to-mouth 0.210 against 0.179 (+1.1), liquid wealth 0.107 against 0.272 (-5.9), S80/S20 6.03 against 6.04; criterion 48.4, as G. The two floors differ (by 0.02 of reference earnings), and by the rule of section 36 the configurations without places would be refitted with the floor from G+E; they are not refitted now, since the floor pays out almost nothing at either value and everything is calibrated again at the parameter stage. Italy's G+A+E and G+S+A+E take the floor from G+E.
- France G+S+A+E is in its last job (run 37775745111). Italy G+A+E and G+S+A+E are started with the floor from G+E.
- **18 of 24**: France and Germany have six and seven (G, G+A, G+S, G+S+A, G+E, G+A+E; Germany also G+S+A+E), Italy five.

## 41. Where the base goes wrong on income, measured (2026-10-08, 17:30 UTC)

The user's question (8 October): are the misfits at the base or in S, A and E; why is the bottom of the income distribution too heavy; can each country's income distribution be reproduced. The misfits are at the base: the household moments are the same to the second decimal with S, A and E on (Germany's MPC 0.393 in G, 0.395 with every switch on).

**The official distribution** (Eurostat 2021, read through the API on 8 October into `data/validation/income_shape.csv`: decile cut-offs and shares of equivalised disposable income, `ilc_di01`; the share of people under 65 below 40, 50, 60 and 70% of the median, `ilc_li02`; people under 65 in households with very low work intensity, `ilc_lvhl11n`) **against the model** (`probe_income_shape.jl`, runs 37815707110 for G and 37815698521 for G+A; raw income states, not smoothed, so the model's quantiles are lumpy):

| G+A | France: model, official | Germany | Italy |
|---|---|---|---|
| first decile over the median | 0.44, 0.54 | 0.48, 0.50 | 0.42, 0.44 |
| second decile | 0.62, 0.67 | 0.58, 0.65 | 0.51, 0.60 |
| eighth decile | 1.59, 1.45 | 1.66, 1.53 | 1.62, 1.55 |
| ninth decile | 1.97, 1.83 | 2.05, 1.95 | 2.25, 1.99 |
| share of the top tenth, % | 21.8, 24.2 | 23.8, 24.7 | 24.7, 24.9 |
| below 40% of the median | 0.072, 0.042 | 0.054, 0.052 | 0.088, 0.101 |
| below 50% | 0.128, 0.092 | 0.135, 0.094 | 0.149, 0.145 |
| below 60% | 0.172, 0.152 | 0.204, 0.151 | 0.212, 0.214 |
| of the model's share below 50%: the unemployed | 0.020 | 0.011 | 0.041 |
| variance of the log of income, model | 0.32 | 0.33 | 0.46 |
| the same implied by the official cut-offs (a lognormal through each) | 0.19 to 0.26 | 0.25 to 0.33 | 0.27 to 0.58 |
| not in work: model; official very low work intensity | 0.066, 0.108 | 0.029, 0.095 | 0.072, 0.108 |

What it shows.
1. **S80/S20 is the wrong single target.** The official distributions have a body close to a lognormal with a standard deviation of the log of 0.43 to 0.51 in France and 0.50 to 0.58 in Germany, and a top tenth that holds more than such a body gives (24 to 25%). The model reaches the same S80/S20 with a symmetric distribution that is wider everywhere (0.56 and 0.57): the eighth and ninth deciles are too high in the three countries, the first and second too low in France and Germany, and the top tenth's share too low. The ratio is matched and the shape is not.
2. **Where the excess width comes from differs by country.** In Germany it is the permanent component: three symmetric nodes at a dispersion of 0.45 to 0.48 put a quarter of households at about half the typical income, and that node is 83 to 88% of the lowest fifth. In France it is the published process of the lower education group itself: the variance of the log of income among its employed is 0.32 to 0.35 with a small permanent component, more than the whole official body (0.19 to 0.26). In Italy the bottom is right (the shares below 40 to 70% of the median are within a point of the official ones) and the upper half is too wide.
3. **The unemployed are a small part of the model's poor**: 1 to 4 points of the 13 to 15% below half the median. The heavy bottom is among the employed of the lower education group. The model has too few households out of work against the official count of people in households with very low work intensity (3 to 7% against 9.5 to 10.8%), which bears on in-work poverty (the model's poor are workers, the data's largely are not) more than on the shape.
4. **Not a missing tax.** The published process is household income after tax with transfers (ECHP 1994 to 2001), so the reading of sections 37 and 38, that taxes and transfers were not compressing it, was wrong.

**What follows for the design, proposed to the user and not built.**
- The income distribution is fitted to the official deciles, not to S80/S20: the permanent component takes free nodes and weights (an asymmetric distribution, with a small top type for the top tenth's share, the device of Castaneda, Diaz-Gimenez and Rios-Rull 2003), chosen so that the model's deciles are the official ones. Every EU country has the same table.
- The pay premium by education belongs to the base in every configuration; A's switch then adds only protection and dread, and no switch moves the income distribution.
- A permanent component can only add dispersion. Where the published risk alone is wider than the official body (France's lower education group, the upper half in Italy), the decile fit will not close the gap, and the cause is upstream: a process with a persistence of 0.94 to 0.97 and no fixed effect, used as the stationary process of a household that lives for ever, spreads further than the cross-section of people of working age does. How the field handles that in a model without a life cycle, and the journal version of the table, are the two things to read before building.
- The state out of work sized to the official count of jobless households is needed for in-work poverty and is second in order.

**The fit without the MPC** (`probe_fit_no_mpc.jl`, runs 37815710565, 37815714541, 37815727578): running; it shows whether the hand-to-mouth share and median liquid wealth can be met together in Germany and Italy once the MPC is out of the criterion.

## 42. The user's decisions of 8 October (evening), the compute question, and a doubt on the income inputs

**Decided by the user.** (1) The MPC is a test and not a fitted target, for now: the fit is on the hand-to-mouth share, its gap by education, median liquid wealth, effort and the income distribution; the MPC is reported against the survey and the evidence. This reverses option C of section 35. (2) The income side of G is redesigned (section 41). The user's standard, per country, in G: the income distribution (deciles, shares below 50 and 60% of the median), the labour market (unemployment, the measured job-finding rate, households out of work), the hand-to-mouth share in total and by education, median liquid wealth over income, the MPC (level and pattern, as a test), the fall in consumption on job loss, hours, and the wealth distribution on the two-asset reference; switching S, A or E on leaves these unchanged within tolerance, and each dimension adds only its own targets.

**One point to return to the user.** I proposed putting the pay premium by education in the base in every configuration. In this model that premium is what the A switch is (the agency share by education, with dread); in the base it would leave A with dread alone and take away A's tested prediction, that it widens the gap in participation between the education groups. The same end (an income distribution no switch moves) is reached by fitting the deciles in every configuration, with the permanent component standing in for the premium where A is off, as it does now. That is what I recommend; the user decides.

**Two assets as the base: the compute** (measured on the runs of this project).
- One household problem: 3 core-seconds with one asset (Germany with every switch on: 7,968 problems in 143 minutes on three workers); 35 core-minutes with two (the reference: two problems, two workers, 34 to 45 minutes a solve). A factor of about 650.
- G, two assets, version 4 (six household problems): 3.5 core-hours a solve, 35 to 100 for a calibration. Fits on GitHub now.
- G+S+A: a family is 83 belonging scales by six problems, about 290 core-hours a build, and a calibration needs several. The repository is public, so GitHub gives four cores a job and up to twenty jobs at once: 80 cores, a build in about four hours if it is split across jobs (it is not built for that today). A 12-core machine takes a day a build.
- With places: 14 to 21 times that, 4,000 to 6,000 core-hours a build. Two to three days on all of GitHub's free capacity, or two to three weeks on a 12-core machine, for each build of each country. A rented 96-core machine does it in two days a build.
- So staging is possible for G and for G+S+A, and not for places without either a rented machine or a faster solver. And compute is not the first obstacle: the two-asset reference as it stands gives an MPC of 0.11 to 0.17, liquid wealth 1.4 to 3 times the data's and no difference between the education groups (section 33), so it would have to match the base's moments before it could replace the base.
- Proposed: one asset stays the base; the two-asset reference is calibrated per country on the redesigned income side; the two-asset solver is profiled for speed; and once it matches, G+S+A is run on two assets once per country at the calibrated point, as a robustness check of the multiplier and welfare, not as a calibration.

**A doubt on the income inputs, found while reading the source for the redesign.** The 2018 version of the source (Ampudia, Cooper, Le Blanc and Zhu, NBER Working Paper 25082, Table 2 and equation 12) writes income as z + epsilon with z persistent and eta its innovation, and heads the table's columns rho, sigma2 epsilon, sigma2 eta: by the equation the first variance column is the transitory shock and the second the persistent innovation. The repository took the first as persistent (`data/manual_inputs.csv`, on the text's wording and the later version's headings, section 35). The magnitudes speak for the equation's reading. The estimation matches the autocovariance at lag zero, the cross-sectional variance of residual income, which for a stationary process is the persistent variance over 1 less rho squared, plus the transitory one:

| implied cross-sectional variance of the log | as in the repository | exchanged |
|---|---|---|
| Germany, no college and college | 0.13, 0.18 | 0.10, 0.11 |
| France | 0.55, 0.22 | 0.14, 0.18 |
| Italy | 0.68, 0.21 | 0.26, 0.17 |
| Spain (not in the model) | 0.98, 2.08 | 0.26, 0.20 |

A variance of the log of residual income of 2 within Spain's college group, or of 0.55 within France's lower group when the whole French distribution has 0.19 to 0.26 (section 41), is not a cross-section that exists; the exchanged reading gives 0.10 to 0.26 everywhere, and its sizes (persistent innovations of 0.004 to 0.022, transitory shocks of 0.02 to 0.09) are those of the field (Cocco, Gomes and Maenhout 2005; Guvenen 2009, whom the source follows). Against it: the source's own sentences describe the first column as the permanent shocks. Not settled by reading. Two things settle it: the journal's table (the user's check, now the first thing needed), and the test started here: `probe_income_shape.jl GA NOPERM` and `GA SWAP NOPERM` (runs 37818338053, 37818342997), the published process alone under each reading against the official deciles. If the exchanged reading is right, every version 4 calibration stands on inputs with too much persistent risk and too little transitory risk in France and Italy, and section 41's finding that France's published process is wider than the official distribution is this error and not a property of the source.

## 43. The two readings of the published variances, tested (2026-10-08, 17:45 UTC)

`probe_income_shape.jl GA NOPERM` and `GA SWAP NOPERM` (runs 37818338053, 37818342997): the published process alone, no permanent component, under each reading, against Eurostat's deciles.

| variance of the log of household income; first and ninth decile over the median | France | Germany | Italy |
|---|---|---|---|
| official (lognormal through each cut-off; D1, D9) | 0.19 to 0.26; 0.54, 1.83 | 0.25 to 0.33; 0.50, 1.95 | 0.27 to 0.58; 0.44, 1.99 |
| as version 4 read the table (first column persistent) | 0.31; 0.41, 1.84 | 0.13; 0.68, 1.70 | 0.46; 0.42, 2.25 |
| in the order of the source's equation (second column persistent) | 0.12; 0.62, 1.50 | 0.11; 0.66, 1.61 | 0.21; 0.56, 1.79 |

The process is estimated on residuals within an education group, after age and household composition are taken out. It has to be narrower than the whole distribution, which also holds what was taken out. In the equation's order it is, in the three countries and on both sides of the median, by a similar margin; as version 4 read it, France's and Italy's residual risk alone is as wide as or wider than everything. Three lines now agree (the equation and heading of the 2018 version, the implied cross-sectional variances of section 42, this test) against one (the paper's sentences). **The redesign proceeds on the equation's order; the journal's table remains the user's check and the record is corrected if it says otherwise.** Version 4's files stay as fitted, on the reading now thought wrong.

What that changes in what was reported: France's "published process wider than the official distribution" (section 41) and Italy's inequality above the official figure with A on (section 36) come from the reading and not from the source; persistent risk in version 4 is three to five times too large in France's and Italy's lower education groups and transitory risk three to five times too small; the calibrated patience, permanent dispersion, MPC and fall in consumption on job loss of every version 4 file are affected.

**Germany without the MPC in the criterion** (`probe_fit_no_mpc.jl DE`, run 37815714541; version 4's inputs): criterion 7.0 where it was 87.6. Hand-to-mouth 0.207 against 0.225 (-1.6 standard errors), liquid wealth 0.118 against 0.140 (-1.9), S80/S20 on target, top patience 0.954; the MPC the model then gives is 0.34 against the survey's 0.47. So in Germany the wealth moments are met together to within two standard errors once the MPC is not pulling on them, which is the user's decision of section 42 seen at work. France and Italy are running. All three are to be redone on the corrected inputs.

**Started: the permanent component fitted to the deciles** (`probe_decile_fit.jl`, a design probe). With effort set by the job and benefits and tax in proportion, a household with permanent factor f is the household of factor one scaled, so one solve per education cell gives the income distribution of any permanent distribution as a mixture. Three forms are fitted to the decile cut-offs, P5, P95 and the top tenth's share: three symmetric nodes (version 4's form), three free nodes, five free nodes. It says how many types the redesign needs, which sets its compute with S on.

## 44. Version 5: the corrected inputs, the income distribution fitted to the deciles, the MPC a test (2026-10-08, evening)

**The design probe** (`probe_decile_fit.jl`, runs 37819067289 for G+A and 37819083403 for G; corrected variances, no floor). The published process alone is narrower than the official distribution in the three countries (variance of the log 0.08 to 0.21 against 0.19 to 0.58); a permanent component fills the difference. Three forms of it fitted to Eurostat's cut-offs (P5, the deciles, P95, over the median) and the top tenth's share:

| G+A | France | Germany | Italy |
|---|---|---|---|
| loss: three symmetric types, three free, five free | 0.020, 0.014, 0.0007 | 0.018, 0.012, 0.0003 | 0.109, 0.046, 0.004 |
| five types: factors on income (mean one) | 0.39, 0.82, 0.91, 1.17, 3.38 | 0.39, 0.71, 0.93, 1.30, 3.39 | 0.35, 0.88, 0.99, 1.14, 3.18 |
| their weights | 0.08, 0.32, 0.26, 0.30, 0.03 | 0.11, 0.29, 0.28, 0.30, 0.03 | 0.12, 0.29, 0.25, 0.31, 0.03 |
| first and ninth decile over the median: model, official | 0.54, 0.54; 1.84, 1.83 | 0.50, 0.50; 1.95, 1.95 | 0.43, 0.44; 2.04, 1.99 |
| top tenth's share, % | 24.0, 24.2 | 24.7, 24.7 | 25.0, 24.9 |
| below 50% of the median, not fitted (official under 65) | 0.075, 0.092 | 0.094, 0.094 | 0.142, 0.145 |
| below 60%, not fitted | 0.132, 0.152 | 0.163, 0.151 | 0.207, 0.214 |
| in-work poverty, not fitted (official) | 0.119, 0.067 | 0.154, 0.086 | 0.182, 0.117 |

- Five types reproduce every cut-off to within 1 to 3% and the top tenth's share, in the three countries; the shares below 40 to 70% of the median for people under 65, which are not in the fit, come within 2 points. Three types, symmetric or free, do not (losses 20 to 60 times larger).
- The five types have the same form in the three countries without being asked to: a low type of 8 to 12% of households at 0.35 to 0.4 of mean income, three types in the middle, and a top type of 3% at over three times the mean (the device of Castaneda, Diaz-Gimenez and Rios-Rull 2003 for the top). The low type's weight is the official share of people under 65 in households with very low work intensity (0.108, 0.095, 0.108). That is an observation and not yet a result; it says what the state out of work should be when it is built, and why in-work poverty is still half as high again as the official rate: in the model the low type works.
- Limits. The cut-offs are of all persons, pensioners included (the table has no breakdown by age); S80/S20 for people under 65 (4.72, 5.08, 6.04) is above what the fit gives (4.25, 4.73, 5.76), close to the all-person ratio the same table implies (4.39, 4.99, 5.80). Income in the model is the household's; the official figure is equivalised.

**Version 5, built** (commit d2090a4; no solver file touched, so no running checkpoint is disturbed).
- `data/manual_inputs.csv`: the two variances in the order of the source's equation. `country_config` with `v3 = :v5` reads them so; `:v4` reads them crosswise, as it always did, so that the version 4 files reproduce (checked by loading: version 4 France 0.031, 0.023 persistent; version 5 0.006, 0.018).
- `SAGEConfig.perm_f`, `perm_w`: explicit permanent types; `perm_nodes` returns them when given.
- `decile_fit.jl`: `fit_permanent` (one solve per education cell without permanent component or floor, the mixture, Nelder-Mead on five types) and its table.
- `calibrate_country.jl` with `SAGE_V5=1` (workflow input `v5=1`): in G and G+A the types are fitted at the starting point, the other parameters fitted, the types fitted again at the fitted point and the fit repeated; every other configuration reads the types from the file of G (A off) or G+A (A on). The criterion: effort, the hand-to-mouth share, its gap by education and median liquid wealth, the last three in standard errors; the MPC and S80/S20 reported. Files `calibration_v5_*` with lines `perm_f`, `perm_w`.
- The pay premium by education stays with A (section 42): with A off the types stand in for it, with A on they are refitted around it, and in both the income distribution is the official one.

**Started**: G in the three countries (run 37820079148). Then G+A, which reads G's floor.

Not in version 5 yet: the state out of work sized to the official count; the measured job-finding rate and the audit's other items (section 37); S's residual participation when off; the two-asset reference; every test of section 38 to rerun.

**The source read again, from the copy the user supplied** (BIS Working Paper 1102, May 2023; a working paper, the same version the inputs were first read from; 2026-10-08, 18:10 UTC).
- Table 16 (p. 48) is headed rho, sigma2 epsilon, sigma2 eta, with equation 16 writing income as z + epsilon, z persistent with innovation eta: the first variance column is the transitory shock by the paper's own notation. The 2018 version (NBER 25082, Table 2, equation 12) has the same heading and the same numbers. The note of section 35 and of `data/manual_inputs.csv`, that the two versions head the columns in opposite order, was wrong: they agree.
- The paper's sentences (pp. 12 and 47, the same in both versions) say the opposite of its heading: "permanent shocks to income are lower for college graduates" holds in the four countries only for the first column, and "the transitory component is usually lower for households with a college degree (with the exception of France)" only for the second. So the paper contradicts itself, and it cannot settle the question alone.
- Its robustness table (Table 23, p. 57) re-estimates the process with government transfers left out of income. Both variance columns rise in most cells (the first from 0.092 to 0.135 in Spain's lower group, 0.031 to 0.047 in France's, 0.072 to 0.117 in Italy's; the second from 0.016 to 0.031 in Germany's and 0.020 to 0.039 in Italy's), so it does not tell the two readings apart.
- With the evidence outside the paper (the cross-sectional variances the estimates imply, section 42; the official distribution, section 43; the sizes found in the field) three lines favour the heading (with the heading itself, four) and one, the sentences, the first reading. Version 5 stays on the heading's order. The journal version (AEJ: Macroeconomics 16(3), 2024) is the one copy not yet seen.

**The fit without the MPC, France and Italy** (`probe_fit_no_mpc.jl`, runs 37815710565 and 37815727578; version 4's inputs, so the old reading of the variances). With Germany (section 43), the three countries:

| | France | Germany | Italy |
|---|---|---|---|
| criterion (with the MPC in: 9.6, 87.6, 47.9) | 8.8 | 7.0 | 0.05 |
| hand-to-mouth, model and HFCS | 0.235, 0.222 | 0.207, 0.225 | 0.175, 0.179 |
| liquid wealth over income | 0.063, 0.059 | 0.118, 0.140 | 0.271, 0.272 |
| floor, share of reference earnings | 0 | 0 | 0.20 |
| MPC the model then gives, and the survey's | 0.386, 0.392 | 0.342, 0.468 | 0.290, 0.469 |
| fall in consumption on job loss | 0.18 | 0.26 | 0.23 |

With the MPC a test, the wealth moments are met in the three countries to within two standard errors, Italy's exactly and with its floor back at 0.20 of reference earnings (the MPC in the criterion had driven it to 0.04). The MPC as a test is then on the survey's figure in France and below it by 0.13 in Germany and 0.18 in Italy. This is the picture of section 39 with the roles of target and test exchanged, on inputs now known to be wrong; version 5 gives the figures to keep.

**Version 4 stopped at 18 of 24 committed (2026-10-08, 18:10 UTC).** Its last runs were cancelled (France G+S+E, Germany G+S+E, Italy G+A+E and G+S+A+E; runs 37818626882, 37788483241, 37811924978): they were fitting inputs with the variances misread (section 43) and would have been neither committed as the base nor compared against. France G+S+A+E had finished (runs 37756647060 and 37775745111) and is left in its artifact, uncommitted. What version 4 leaves that carries over: the engine and its tests (sections 38 and 40), the resumable fit and the checkpoint before the full-grid stage, both exercised with places and three types of household, and the 18 files as the record of what the misreading gave.

## 45. Version 5, first result: France G does not calibrate (2026-10-08, 18:20 UTC)

Run 37820079148, France G (Germany and Italy still running).
- **The income distribution holds in the calibration itself**: every cut-off within 1% (first decile 0.536 against 0.540, ninth 1.825 against 1.827), the top tenth 24.1 against 24.2%, below half the median 0.082 to 0.085 against 0.092 for people under 65. The types moved by 0.03 in the log between the two passes, so two passes are enough.
- **The wealth moments are not met together.** Hand-to-mouth 0.262 against 0.222 (+5.8 standard errors), liquid wealth over income 0.068 against 0.059 (+4.5), the gap by education 0.069 against 0.105 (-2.8), effort 0.649 against 0.643 (outside its band, so no file is written); criterion 64. Both wealth moments are too high at once: more patience lowers the hand-to-mouth share and raises liquid wealth, so one patience cannot repair both. The MPC, a test, is 0.466 against the survey's 0.392; the fall in consumption on job loss 0.17.
- **What changed from version 4's France, which fitted** (hand-to-mouth 0.237, liquid wealth 0.063, MPC 0.388): the inputs. With the variances in the source's order the lower education group's transitory shock has a variance of 0.031, not 0.006, and its persistent innovation 0.006, not 0.031. Larger transitory shocks put more households at the constraint in a given year at any median buffer, and raise the MPC. Version 4's fit of France was a fit to the misreading.
- **Open, in order.** (1) Whether the fit stopped at its minimum: it moved once and then found no better step, with effort traded against the wealth moments although effort has a parameter of its own; effort should be held as a constraint, not weighed. (2) What the published transitory variance holds: it is the residual of annual household income, measurement error included, and the model treats all of it as risk the household faces within the year. How the field splits it is the next thing to read, before any change. (3) Germany and Italy, to see whether the tension is France's or general.

**Germany and Italy, G on version 5** (run 37820079148, committed 2026-10-08, 19:20 UTC). Both calibrate.

| G, version 5 | France (not calibrated) | Germany | Italy |
|---|---|---|---|
| criterion | 64 | 7.1 | 0.08 |
| hand-to-mouth, model and HFCS | 0.262, 0.222 | 0.208, 0.225 | 0.184, 0.179 |
| liquid wealth over income | 0.068, 0.059 | 0.116, 0.140 | 0.275, 0.272 |
| first and ninth decile over the median, model (official in section 44) | 0.54, 1.83 | 0.50, 1.92 | 0.43, 1.98 |
| below half the median (official under 65: 0.092, 0.094, 0.145) | 0.085 | 0.102 | 0.146 |
| MPC, a test (survey 0.392, 0.468, 0.469) | 0.466 | 0.369 | 0.330 |
| fall in consumption on job loss | 0.17 | 0.26 | 0.23 |
| in-work poverty (official 0.067, 0.086, 0.117) | 0.135 | 0.153 | 0.181 |

Germany and Italy meet their wealth moments and their income distributions together on the corrected inputs; France is the one that does not (section 45), so the tension there is France's and not general. In-work poverty has come down from about twice the official rate to about 1.6 to 1.8 times, with the state out of work still to build. Started: G+A for Germany and Italy.

## 46. The specs of S, A and E (2026-10-08, 19:30 UTC)

`DIMENSIONS_SPEC.md` (copied to the vault): one page a dimension, the designs of 27 and 29 September as they stand in the code, what tests each, and what is open. I had told the user that A and E were "not closed"; more exactly, each has an agreed design and specific open questions. The decisions put to the user: A1, what the A switch is (as today, the pay premium by education with dread measured; or the premium in G and A as dread, measured or acting on choices; recommended: test dread in choices on the corrected inputs, adopt it if the wealth moments still hold, keep today's switch if not); E1, the natural environment (indicators now, into wellbeing once a published valuation is chosen); E2, housing cost by place as a sixth channel from official data, for the failed test by type of place and the short regional spread; S1, the private share of the fabric stays a band; S2, S exactly off. Nothing is built on these until the user decides.

## 47. The user's decisions on S, A and E, and France (2026-10-08, 19:45 UTC)

**Decided** (recorded in `DIMENSIONS_SPEC.md`): A1, dread in choices is tested on the corrected inputs and adopted if the wealth moments still hold, with the pay premium then moving to G; otherwise the switch stays. E1, the natural environment as consequences for wellbeing and not decisions (the user: "not a decision but a wellbeing consequence, similar to dread"): exposure to pollution in the household's own wellbeing once a valuation is chosen, the footprint beside it since others bear it. E2, housing cost by place as a sixth channel. S1, the multiplier stays a band. S2, S exactly off. Then: France.

**France: where its pair of wealth moments comes from.** The HFCS aggregates for 2021, narrow and broad liquid wealth (broad counts saving accounts):

| | France | Germany | Italy |
|---|---|---|---|
| median liquid wealth, narrow, euro and over income | 1,552; 0.059 | 4,739; 0.140 | 6,014; 0.272 |
| the same, broad | 10,000; 0.380 | 15,000; 0.442 | 7,000; 0.316 |
| broad over narrow | 6.4 | 3.2 | 1.2 |
| hand-to-mouth, narrow (below tertiary, tertiary) | 0.222 (0.256, 0.151) | 0.225 (0.285, 0.118) | 0.179 (0.196, 0.095) |
| hand-to-mouth, broad | 0.114 (0.143, 0.054) | 0.146 (0.190, 0.067) | 0.141 (0.151, 0.092) |

On the narrow definition France is the outlier: a median of three weeks of income in liquid form, with only 22% under one week. Half of French households then hold between one and three weeks of income, which is a current-account working balance and not a buffer. France's liquid savings sit in regulated saving accounts with instant access, which the narrow definition counts as illiquid because the HFCS pools them with time deposits (Kaplan, Violante and Weidner 2014; `hfcs_protocol/HFCS_READINESS.md`). On the broad definition the three countries are alike (medians 0.32 to 0.44, hand-to-mouth 0.11 to 0.15). Italy's narrow and broad nearly coincide, and Italy is the country that fits exactly. So the hypothesis for France: the narrow moments describe where the French keep their money, and a buffer-stock household facing France's income risk cannot hold that distribution. It bore on version 4 too, hidden by the misread inputs.

**Two diagnostics started.**
- `probe_wealth_frontier.jl FR` (run 37831856634): G of version 5 on a grid of top patience (0.90 to 0.97) by patience gap (0 to 0.12), the types and effort scale given: the hand-to-mouth share in total and by education, median liquid wealth, the MPC. Whether France's narrow pair, or its broad one, lies on the surface the model spans.
- `probe_fit_broad.jl` for the three countries (runs 37831843814, 37831847860, 37831851952): the version 5 fit of G on the broad moments (`SAGE_LIQ_DEF=broad` in the calibration script, a diagnostic setting). What the three countries look like on one definition under which they are comparable, and the MPC that then comes out.

Which definition the model is fitted to is the user's decision, with a published definition behind it in either case; nothing is changed until the diagnostics are read. Also to check before proposing anything: the definition used for the euro area in Slacalek, Tristani and Violante (2020), which I recall as counting all deposits and have not verified.

## 48. The pay premium by education moves to G (2026-10-08, 20:20 UTC; decided by the user)

**Decided.** "yes move the premium to G, go ahead." The reasons put to the user: pay by education is the skill premium, a fact about the economy; with hours set by the job it cannot stand for influencing one's fortunes through one's own effort; A's tested prediction on participation was a prediction about income. A is then the security dimension (dread, protection, expected loss, room to manoeuvre), and the other half of the concept is to be restored later by whether a household can choose its hours, which needs official data on who decides working time (to scope, not built). Agreed in the same exchange, as a rule: a dimension or a named combination may bring the theory it needs, declared beforehand in `DIMENSIONS_SPEC.md`, the same in every country, with off still exactly the base; the base does not change with what is combined.

**Built** (version 5; no solver file touched).
- `SAGEConfig.premium_base` (true under `v3 = :v5`): the two education cells earn `alpha` with A on or off. Version 4 and earlier are unchanged (checked by loading: version 4 G pays 1.0 and 1.0, version 5 G 0.86 and 1.27 in France).
- A configuration with A reads the calibration file of the same one without A (`country_config`), since A adds no parameter while dread is measured without entering choices. `calibrate_country.jl` refuses a version 5 configuration with A.
- G+S owns the participation of both cells (`OWN_GAP`), as G+S+A did: the taste dispersion is fitted there and not carried over.
- The permanent types are fitted in G only and read by the others.
- So a country has four calibrations, G, G+S, G+E and G+S+E, and each dimension depends on G alone.

**Consequences for what was run.** The two version 5 G files of section 45 (Germany, Italy) were fitted without the premium; they are removed from the repository, their numbers staying in section 45. The G+A runs for the two countries (run 37830479778) had finished before they could be cancelled; they have the premium but took the floor from the old G, so they are not committed, and they show what the new G will give (below). G is started again for the three countries on the new definition. The broad-definition and frontier diagnostics of section 47 were launched before the change and describe G without the premium; they are read for the mechanism, and France's is redone if it decides anything.

**What the premium in the base does to the fit: Germany and Italy** (run 37830479778, G+A of the old definition, which is G of the new one but for the floor's origin).

| the pay premium in | Germany | Italy |
|---|---|---|
| criterion | 8.7 | 0.03 |
| hand-to-mouth, model and HFCS | 0.207, 0.225 | 0.176, 0.179 |
| liquid wealth over income | 0.112, 0.140 | 0.273, 0.272 |
| first and ninth decile over the median (official 0.50, 1.95; 0.44, 1.99) | 0.49, 1.95 | 0.42, 2.01 |
| S80/S20 (official under 65: 5.08, 6.04) | 4.87 | 5.81 |
| MPC, a test (survey 0.468, 0.469) | 0.370 | 0.323 |
| fall in consumption on job loss | 0.27 | 0.23 |

Both fit with the premium in as they did without it, and Italy's inequality, which stood at 6.35 against 6.04 with A on in version 4 with nothing left to lower it (section 36), is 5.81: the misread variances were its cause, as section 43 supposed.

**Italy on broad liquid wealth** (`probe_fit_broad.jl IT`, run 37831851952): criterion 0.14; hand-to-mouth 0.147 against 0.141, liquid wealth 0.324 against 0.316; MPC 0.30. Italy fits on either definition, as its two definitions nearly coincide. France and Germany on the broad definition, and France's frontier, are still running.

## 49. France's wealth moments on the surface one asset spans (2026-10-08, 21:15 UTC)

`probe_wealth_frontier.jl FR` (run 37831856634): G of version 5 without the premium, effort scale 7.0, forty points of top patience by patience gap. The rows near France's data:

| top patience, gap | hand-to-mouth (below tertiary, tertiary) | median liquid wealth over income | MPC | fall on job loss |
|---|---|---|---|---|
| HFCS narrow | 0.222 (0.256, 0.151) | 0.059 | survey 0.392 | |
| 0.92, 0.03 | 0.233 (0.259, 0.183) | 0.081 | 0.447 | 0.165 |
| 0.93, 0.03 | 0.197 (0.223, 0.145) | 0.101 | 0.417 | 0.155 |
| HFCS broad | 0.114 (0.143, 0.054) | 0.380 | | |
| 0.96, 0.03 | 0.124 (0.164, 0.047) | 0.219 | 0.298 | 0.111 |
| 0.96, 0.00 | 0.061 (0.069, 0.047) | 0.424 | 0.184 | 0.078 |

- **On the narrow definition the model reaches France's hand-to-mouth share and its split by education** (between the two rows: about 0.22, with 0.25 and 0.16), and its median liquid wealth is then about 0.09 of annual income against 0.059: four and a half weeks of income against three. The MPC there is about 0.43 against the survey's 0.39.
- **The broad definition does not fit better.** At the broad hand-to-mouth share the model's median is about 0.25 against 0.38, and the MPC about 0.29. France's narrow pair is more compressed than the model's and its broad pair more spread; the model's surface passes between them, nearer the narrow. So the definition explains why France's narrow figures look odd (section 47) and changing it is not the repair. The narrow definition stays.
- **Why the fit failed.** The criterion weighs each moment by its sampling error. France's median is measured to 0.002, its hand-to-mouth share to 0.007, so the fit gave up four points of the share (0.262 against 0.222) to bring the median from about 0.09 to 0.068. A distance of a week and a half of income in a current-account balance was bought with a fifth of the hand-to-mouth households. The sampling error of the median does not contain what makes the two objects differ (which accounts the money sits in), so its weight is too large for what it measures.

**A variant put to the user: the hand-to-mouth share first** (`SAGE_HTM_FIRST=1`, `probe_fit_htm_first.jl`). Patience and its gap are identified by the hand-to-mouth share and its split; the floor by median liquid wealth. The floor is searched from 0.10 in every country (in Germany and France it had started at zero, from the version 4 file, and was never tried). Where it stays positive the four moments are met together, as in Italy; where it goes to zero the median has no parameter left and is reported as a test with its miss, as the MPC is. This is the rule the calibration had before version 4, and it rests on what the moment is for: the share and kind of hand-to-mouth households is what determines the average MPC in this class of model (Kaplan and Violante 2022). Started for the three countries; the standard criterion's G is running beside it (run 37841169403), and the two are shown to the user side by side.

**An error of mine, found at 22:05 UTC.** The commit announced in section 48 (8e4c722) held only the removal of the two files: the `git add` that should have staged `sage_modular.jl` and the spec failed on the two paths already removed, with its error message silenced, and the commit went ahead without them. So the premium was not in the repository until commit fcaa705 (22:10 UTC), and every run started in between was without it: the three G calibrations of run 37841169403 (their numbers are those of section 45 to the last digit, which is how it was noticed; the two files they wrote are not committed) and the first three runs of the hand-to-mouth-first variant (37845395417, 37845399249, 37845403024), which stand as the variant on G without the premium. What section 48 says about the G+A runs of the old definition holds: they did have the premium, by A. Started again with the premium in: G on the standard criterion for the three countries, and the variant for the three. Checked this time on the remote before launching (`premium_base` in `origin/main`), and the runs' commit is fcaa705.

# Stage 6: unemployment risk, and agency with an income channel

Specification written 2026-09-10, before any code was run. The point of
writing it first is that every assumption, every calibration input and every
prediction is fixed here, so that when the numbers arrive they are read
against this document and not against whatever seemed plausible at the time.
Deviations from the predictions in Part 5 are reported as deviations. Nothing
in Parts 1 to 4 changes after the fact; if something has to, the change and
the reason are appended in Part 8, dated.

## 1. Why

`AGENCY.md` built the agency column as Snower and Lima de Miranda's
U^a = alpha (1 - p), with hardship the OECD asset-poverty event. It closed
with the gap: the model has no unemployment, so p is driven entirely by
wealth, and the labour-market insecurity that heads their own empirical
Agency index has no object in the model. Every policy the SAGE literature
calls an agency policy, unemployment insurance above all, was unaskable.

Stage 6 adds an employment state with exogenous separation and finding rates
and an earnings-related benefit. That is the minimal version: it puts the
job-loss event in, gives hardship an income half, and makes unemployment
insurance a policy the model can evaluate. It does not make separation or
finding depend on anything the household does. The behavioural channels,
networks raising the finding rate and hardship eroding agency, are the next
stage and are not in this one.

## 2. The model change, exactly

Household state becomes (a, z, s) with s in {U, E}. The productivity z keeps
its two-state Rouwenhorst process with rho 0.9 and eta 0.1, evolving whether
or not the household is employed (the latent productivity persists through
unemployment and is resumed on re-employment; Krusell, Mukoyama and Sahin
2010 make the same assumption). Employment transitions are independent of z:

    E -> U with probability delta_g     (separation, by education cell)
    U -> E with probability f           (finding, common)

so the four-state process on (z, s) has transition matrix

    P[(z,s) -> (z',s')] = Pi_z(z, z') * P_s(s, s'),

with P_s = [1-f f; delta 1-delta] in the order (U, E). The stationary
unemployment rate in cell g is u_g = delta_g / (delta_g + f), and the joint
stationary distribution over (z, s) is the product of the Rouwenhorst
stationary distribution and (u_g, 1 - u_g), since the two chains are
independent.

Employed households are as before: labour income alpha_g e z Z, effort e on
the grid, participation d at time cost QBAR, budget

    c + a' = R a + (1 + subsidy) alpha_g e z Z - T + credit d,

with credit = partcredit alpha_g z Z QBAR.

Unemployed households have no return to effort, so their optimal effort is
zero, and receive a benefit in place of labour income:

    c + a' = R a + b_{g,z} - T,           b_{g,z} = rr * alpha_g * z * Z * E_REF,

where rr is the net replacement rate and E_REF = 0.53 is the paid-time share
the engine already uses to calibrate effort disutility (INSEE Enquete Emploi
du temps 2010), so that alpha_g z Z E_REF is the reference previous earnings
of a household of that type. The benefit is therefore earnings-related, as
French unemployment insurance is. The unemployed still face the participation
choice at time cost QBAR with the same belonging payoff as everyone else, and
receive neither the work subsidy nor the participation credit, since both are
rebates on earnings they do not have.

Unemployment insurance is financed by a lump-sum tax on everyone, the same
instrument the S and S+A papers use for their policies:

    T_UI = sum_g share_g * u_g * sum_z pi_z * b_{g,z},

which is exact and closed-form because the joint distribution is a product.
Total lump tax T = T_UI + T_policy. Financing by a proportional tax on labour
income would be closer to French practice and is a stated limitation.

Implementation: one field `transfer::Vector{Float64}` is added to
`SAGEParams`, default empty, read by the participation core only; the engine's
own solver refuses a non-empty transfer rather than silently ignoring it. The
four-state process enters through the existing `z_vals_override` and
`Pi_override` fields with z = 0 in the unemployed states, so the household
solver is unchanged apart from the transfer term in its budget. With
delta_g = 0 the unemployed states are unreachable and the model is stage 5b
exactly; that is the first test in Part 6.

## 3. Hardship, extended

The OECD's two tests, both from Balestra and Tonkin (2018):

    income-poor:  disposable income y < 0.5 * median(y)
    asset-poor:   wealth a < (3/12) * 0.5 * median(y)

and the categories of their Figure 6.1: income-poor, economically vulnerable
(asset-poor and not income-poor), and both. Hardship for the agency object is
the union, poor now or one shock from poor, and

    A_g = alpha_g * (1 - Pr_g[income-poor or asset-poor]),

which by the stationarity identity of `agency_core.jl` is still the aggregate
of the forward-looking household probability. With delta_g = 0 nobody is
income-poor and this is `AGENCY.md` exactly. Disposable income is labour
income gross of the subsidy plus benefit plus credit plus capital income less
the lump tax. Employed households are never income-poor at these parameters,
which the driver verifies rather than assumes; income poverty is then a
per-state wealth threshold for the unemployed, so every category is exact
from per-state wealth distributions and no joint distribution has to be
stored. The poverty line is anchored at the stage-6 baseline median.

## 4. Calibration inputs, and what is held fixed

| input | value | source |
|---|---|---|
| unemployment, tertiary | 0.050 | INSEE, Emploi, chomage, revenus du travail 2025, "Inegalites face au chomage", 2024 annual average, Bac+2 ou plus |
| unemployment, all | 0.074 | same source, all active persons |
| tertiary share of employment | 0.472 | INSEE, Activite, emploi et chomage en 2024, Enquete Emploi |
| unemployment, non-tertiary | 0.094 | implied by the three rows above: with s the active tertiary share, 0.074 = 0.050 s + u_N (1 - s) and 0.472 = 0.95 s / (0.95 s + (1 - u_N)(1 - s)) give s = 0.46, u_N = 0.094 |
| long-term share of unemployment | 0.233 | Eurostat une_ltu_a, France, 2024, 12 months or more as a share of unemployment |
| net replacement rate, initial | 0.68 | Tresor-Eco 188 (Direction generale du Tresor, December 2016), single person without children, from OECD (2016) Tax-Benefit Models on 2014 rules; France shows no variation between 67 and 150 percent of the average wage |
| statutory ARE floor | 0.57 of reference wage | OECD, Tax and benefit policy descriptions for France 2025: max(40.4 percent of SJR + 13.11 euro per day, 57 percent of SJR), floor 57, ceiling 75 percent |

From these, with annual periods: the finding rate is f = 1 - 0.233 = 0.767,
because in a stationary flow with constant annual exit probability the share
of the unemployed stock that has been unemployed at least a year is 1 - f.
Then delta_g = u_g f / (1 - u_g): delta_low = 0.0796, delta_high = 0.0404.
The model's two cells are equal halves, so its aggregate unemployment rate is
0.072 against 0.074 observed, the difference being the 46/54 split in the
data.

The replacement rate is 0.68, the first-phase net rate. It is applied for the
whole spell because the model period is a year and 77 percent of spells end
within one; the fall after 24 months to a post-exhaustion rate above 50
percent (Tresor-Eco 188, section 2.4) is not modelled. Sensitivity is run at
0.57, the statutory floor.

Held fixed, and why: beta, R, gamma, psi, phi, rho, eta, and the grid family
(a_max, pexp, na, ne, theta) at their stage-5b values, subject to the grid
checks in Part 6. The effort-disutility scale phi was calibrated to a
population mean paid-time share of 0.53; with the unemployed at zero effort
the employed mean will sit above 0.53, and that is reported, not re-tuned,
because re-tuning phi would change the S paper. The social technology
(kappa, sigma_m) is recalibrated by the dense scan, kappa free at each sigma,
to the same two participation moments as before, 0.25 and 0.45 by education
cell, population rates including the unemployed. omega has no point estimate
and is swept with recalibration at each value, as `sa_omega_l4.txt` does.

Validation targets, none of them targeted:

| target | value | source |
|---|---|---|
| hand-to-mouth share | 0.30 | as in stage 5b |
| income poverty, 50 percent line | 0.088 | INSEE, Taux de pauvrete selon le seuil, 2024 |
| income poverty among the unemployed, 50 percent line | 0.243 | INSEE, Pauvrete selon le statut d'activite et le seuil, 2024 |
| income poverty among salaried employees, 50 percent line | 0.034 | same |
| asset poverty (financial fragility), France | below 0.40 | OECD (2025), Household financial fragility and asset poverty in OECD regions |
| association membership, employed / unemployed | 0.35 / 0.17 | INSEE Premiere 1327, SRCV-SILC 2008 |

## 5. Predictions, written before running

P1. With delta_g = 0 the per-node participation rate, mean income and wealth
distribution reproduce stage 5b to 1e-6.

P2. The threaded family build is identical to the serial build to the last
bit.

P3. At the stage-5b social technology, aggregate participation rises above
0.353, because the unemployed have the time and participate at a higher rate
than the employed. Recalibration lowers kappa.

P4. In both cells the unemployed participate at a higher rate than the
employed. INSEE finds the opposite, 17 against 35 percent. The model gets
this sign wrong, and it does so because participation is a time choice and
the unemployed are time-rich. This is the designed test of that assumption,
and it is to be reported as a limitation that motivates the bandwidth
channel, not repaired with a parameter.

P5. Asset poverty among the employed falls relative to stage 5b, from
precautionary saving; asset poverty among the unemployed is higher than among
the employed, from decumulation. The net effect on the aggregate is not
predicted, and is to be read.

P6. Income poverty is confined to the unemployed and lands between 2 and 5
percent of the population, below INSEE's 8.8, because the model has no
self-employed, no inactive, no part-time and no households. Poverty among the
unemployed lands well below INSEE's 24.3 percent for the same reasons and
because a single first-phase replacement rate is applied. Both are expected
shortfalls and are not calibration failures.

P7. The work subsidy still raises A and lowers participation. The unemployed
pay its tax and receive nothing from it, so the low cell's hardship gain is
smaller than in `AGENCY.md`.

P8. Raising the replacement rate lowers income poverty and raises A. Employed
households save less against a better-insured risk, so their asset poverty
rises; the sign of the net effect on A is not predicted, though the
income-poverty channel is expected to dominate at a ten-point change. The
effect on participation runs through the unemployed's budget and is small.

P9. Empowerment remains almost entirely the mechanical alpha channel.

P10. The participation credit's agency effect remains small and positive,
and none of it reaches the unemployed.

## 6. Verification, before any number is quoted

In this order, each gating the next.

1. Switch-off: delta_g = 0 against the stage-5b family cache, five belonging
   scales per cell (P1).
2. Threading: three nodes serial against threaded (P2).
3. Grid scaling: the wealth distribution's upper tail against a_max, at the
   low cell mid-transition, a_max 4 against 8 at matched node spacing. The
   rule from `MODEL_READINESS.md`: the grid is scaled to the distribution, not
   the other way round. If mass above a_max / 2 exceeds 1e-4, a_max is raised
   and this is recorded in Part 8.
4. Baseline families, the closed-form UI tax, the dense recalibration, and the
   valley it implies.
5. The stationarity identity with four states and the union event.
6. The asset grid on the pooled baseline, na 200 against 400.
7. theta halved at the calibrated point, four nodes per cell.
8. The linearisation identity at a one percent shock, as in `audit_sa.jl`.
9. omega at 0.15 and 0.50 with recalibration, baseline and all policies.
10. The independent path: every taste node solved directly, no family.

## 7. Reporting rules

The state document is this file, Part 8 onward, and `sa_stage6_results.txt`.
No number is quoted to more precision than the checks in Part 6 support. Each
prediction in Part 5 is scored: held, held with a stated qualification, or
failed, with the number beside it. A failed prediction is a finding about the
model or about my reasoning and is reported as such.

## 8. Record

Appended as the stage runs. Nothing above this line changes.

### 2026-09-10, pre-flight (Part 6, checks 1 to 3)

Code: one field `transfer` on `SAGEParams` with a guard in the engine solver;
the transfer term in the four budget lines of the participation core;
`unemployment_core.jl` for the process, the cell parameters, the closed-form
tax, the per-cell summary and the categories; `s6_common.jl` for the sourced
constants; `s6_pop.jl` for pooling, equilibrium and the family cache;
`sa_stage6.jl` as the driver.

| check | result | verdict |
|---|---|---|
| Budget-line patch on the stage-5b footing | rate, mean income and participation base identical to the cache to the last bit at two scales | inert |
| Engine guard | fires on a non-empty transfer | as intended |
| Switch-off, delta = 0, five scales per cell | largest difference from the stage-5b family 7e-13; mass in the unemployed states below 1e-80 | P1 holds |
| Threaded family build against serial, three scales | identical to the last bit; 5.0 s serial, 0.8 s threaded on 14 threads | P2 holds |
| Grid scaling, low cell, a_max 4 against 8 at matched spacing | mass above a_max / 2 is zero at both; 99th percentile of wealth 1.054 against 1.054, 99.9th 1.157 against 1.156; rate and asset poverty agree to 4e-4 | a_max 4 kept |

One number from the grid probe is recorded now so that it is not read as a
surprise later. At the low cell's mid-transition scale the share below the
stage-5b asset threshold is 0.086, where the stage-5b model gave about 0.43
at the same scale. Households save against job loss, and the 99th wealth
percentile has moved from 0.68 to 1.05. That is P5's direction with a larger
magnitude than the prediction had in mind, and it will reach the
hand-to-mouth validation. Nothing in Parts 1 to 5 is changed for it.

The closed-form unemployment-insurance tax is 0.02117, 4.8 percent of
stage-5b mean labour income.

### 2026-09-11, a deadlock, not a result

The first smoke run of the driver hung for sixteen hours with no output. A
stack sample showed the main thread spinning in the allocator and the worker
threads inside method compilation: the Julia 1.7 deadlock that arises when
methods are first compiled inside `Threads.@threads`. The threading test had
passed only because it ran the serial build first, which compiled everything
on the main thread. Fix: `build_family_u` and the second-path check now solve
their first node serially before threading. Recorded here because a hang that
looks like a slow run is exactly the kind of thing that gets misread.

### 2026-09-12, the second hang, and the move to processes

The warm-up did not hold. A second smoke run stopped at the eighth family
with the same stack: every thread spinning in the allocator. So the fault is
the threaded garbage collector under Rosetta, not first compilation, and it
can strike at any point in a long run. Threads are abandoned. The family
build now uses `Distributed.pmap` over thirteen single-threaded worker
processes (`s6_workers.jl`), which share no collector. The bit-identity test
(`s6_test_parallel.jl`) passes on four scales with two threshold pairs: P2
holds under process parallelism.

Also from the smoke runs, and recorded because it changes the driver rather
than the model: the sensitivity tables need joint income-and-asset indicators
at every threshold pair they report, since under the work subsidy's lump tax
some employed households fall below the poverty line and the per-state wealth
trick stops being exact. Each family now stores the joint indicators at six
pairs (anchored, three other horizons, the line moved ten percent either way),
so every sensitivity row is exact. The floating line remains approximate and
is labelled as such.

### 2026-09-12, the production run at omega 0.30

Grid a_max 4, pexp 3, na 200, ne 80, theta 0.005, 83 belonging nodes, 2000
taste nodes, thirteen worker processes. Log `sa_stage6.txt`, numbers
`sa_stage6_results.txt`, valley `sa_stage6_valley.txt`. The robustness rows
at the end of this entry are filled in as the checks land; nothing above them
is changed by the checks, only qualified.

**Recalibration.** The dense scan puts the minimum at kappa 9.80, sigma_m
0.395, root loss 0.024. Equilibrium rate 0.3517, group rates 0.2686 and
0.4349 against 0.25 and 0.45. One stable equilibrium. Map slope 0.947,
multiplier 18.7, bound ratio sigma_m over sigma-bar 0.852.

CORRECTION, same day. The first version of this entry compared those against
the stage-5b headline (10.00, 0.510, slope 0.879, multiplier 8.3, ratio
1.103) and attributed the whole move to the unemployed block. Both halves
were wrong, and `s6_diag_block.jl` and `s6_diag_decomp.jl` are the record.

The baseline was wrong. The stage-5b headline came from a calibration search
already known to be faulty: `calibration_dense_scan.jl` (2026-09-08) found
sigma_m near 0.470 fits better, root loss 0.0137 against 0.0200, and the
headline was never moved. Running the stage-6 code with delta = 0, which
reproduces stage-5b households to 7e-13, and recalibrating with a clean
global scan gives kappa 9.95, sigma_m 0.475, slope 0.9369, multiplier 15.9,
ratio 1.030. That is the honest stage-5b comparator, and it independently
confirms the dense scan rather than the headline.

The attribution was wrong. Removing the unemployed block makes the map
STEEPER, not flatter: slope 0.9652 against 0.9466, because a block that
participates at one whatever the social scale multiplies the aggregate
response by (1 - u) and so damps it. The block does drive the fall in
sigma_m, because the employed must carry a wider education gradient, 0.212
against 0.172, to hit the same population moments.

The decomposition, each case its own family build, all recalibrated the same
way:

| case | kappa | sigma_m | slope | multiplier | ratio |
|---|---|---|---|---|---|
| A, no job-loss risk, no UI tax (stage 5b) | 9.95 | 0.475 | 0.937 | 15.9 | 1.030 |
| B, add the UI lump-sum tax | 10.45 | 0.480 | 0.923 | 13.0 | 1.043 |
| C, add job-loss risk, employed only | 10.50 | 0.455 | 0.965 | 28.7 | 0.994 |
| D, add the unemployed block (headline) | 9.80 | 0.395 | 0.947 | 18.7 | 0.852 |

So the slope barely moves from A to D, 0.937 to 0.947. What moves is sigma_m
and with it the ratio, from 1.030 to 0.852, across the S+A paper's
sufficient condition for uniqueness. The margin was never 1.10. It was about
1.03, and job-loss risk pushes it just under one.

Behind case C is the change that dominates everything else in this stage.
At a common belonging scale the low cell's mass at the borrowing constraint
falls from 0.398 with no risk to 0.028 with it, and the median employed
household's wealth rises from 0.144 to 0.253. Households save against job
loss, the hand-to-mouth atom dissolves, and every statistic read off the
wealth distribution moves with it.

**Predictions scored.**

| | prediction | outcome | score |
|---|---|---|---|
| P1 | switch-off reproduces stage 5b to 1e-6 | 7e-13 | held |
| P2 | parallel build bit-identical to serial | identical, under processes | held |
| P3 | participation rises at the stage-5b technology | 0.4136 against 0.3526 | held |
| P4 | unemployed participate more than employed, against INSEE | 1.000 against 0.301; INSEE 0.17 against 0.35 | held, and it is the model's central limitation |
| P5 | employed asset poverty falls; unemployed above employed; aggregate not predicted | 0.213 from 0.428; 0.217 against 0.213; aggregate 0.213 | held on both parts |
| P6 | income poverty confined to the unemployed, population 2 to 5 percent, unemployed well below INSEE's 24.3 | confined, yes; population 1.8 percent; unemployed 25.1 percent | failed on both numbers, one low, one a near match |
| P7 | subsidy raises A, lowers S; low cell gains less than in AGENCY.md | A +0.158, S 0.352 to 0.156; low-cell hardship down 0.054 against 0.042 | held on signs; the low cell gains MORE, see below |
| P8 | higher replacement rate raises A | A falls 0.094 | failed, see below |
| P9 | empowerment mostly mechanical | 0.032 of 0.037 from alpha | held |
| P10 | credit small positive on A, none reaching the unemployed | +0.004; unemployed pay 0.018 and receive nothing | held |

**P6, in detail.** Income poverty among the unemployed is 25.1 percent
against INSEE's 24.3, which looks like a match and is not one. With two
productivity states the unemployed sit in four cells, and the low-education
low-productivity cell's net benefit is 1.7 percent below the poverty line;
the other three are 19 to 95 percent above it. So exactly one cell in four
is income-poor, and the 25 percent is a count of cells, not a fit. A poverty
line two percent lower puts it at zero. This is the nz = 2 income process
being too coarse for a threshold statistic, a limitation that the
participation results never exposed because they are not threshold
statistics. It is why the income-concept column below moves in jumps.

**P8 and the finding of this stage.** Raising the replacement rate from 0.68
to 0.78 removes income poverty entirely and lowers agency by 0.094, because
employed households hold smaller buffers against a better-insured risk and
asset poverty rises from 0.213 to 0.345. Lowering it to the statutory floor
of 0.57 does the reverse and raises agency by 0.128. Under the OECD union
definition the model says unemployment insurance is bad for agency. That is
the asset test measuring buffers, and buffers are what insurance replaces.

Under the source's own concept, p = Pr[income below the line], the signs
reverse:

| policy | A, OECD union | A, income only |
|---|---|---|
| baseline | 0.640 | 0.824 |
| work subsidy | +0.158 | -0.016 |
| empowerment | +0.037 | +0.050 |
| participation credit | +0.004 | -0.004 |
| UI replacement +0.10 | -0.094 | +0.014 |
| UI replacement at floor | +0.128 | -0.006 |

Every policy that moves risk changes sign between the two columns; only
empowerment, which is mechanical, agrees. The agency column as built in
`AGENCY.md` is therefore not one object once insurance exists in the model.
At stage 5b the two concepts could not be told apart, because without job
loss nobody is income-poor and the asset test was the only hardship there
was. With job loss in the model, the OECD asset test embeds an assumption,
that a household without a buffer is exposed, which the model's own insurance
contradicts. Which concept belongs in the SAGE column is a decision about
what agency means, not a numerical question, and it is put to the user
rather than settled here. The spec's Part 3 chose the union; the results
under that choice stand as reported, with the income column beside them.

**P7, in detail.** The work subsidy's agency gain is +0.158, five times its
stage-5b value, and the split by employment status shows why: hardship among
the employed falls from 0.213 to 0.013 while hardship among the unemployed
rises from 0.398 to 0.509, half of them now income-poor. The lump-sum tax
that finances the subsidy falls on the unemployed, who receive nothing from
it, and the harsher unemployed state makes the employed save. The aggregate
gain is a redistribution of hardship from the many to the few, and only the
split by status shows it. The low cell gains more than in `AGENCY.md`, not
less as P7 expected, for the same reason: its employed save hardest.

**Validation, untargeted.**

| target | data | model |
|---|---|---|
| hand-to-mouth share | 0.30 | 0.116 |
| income poverty, 50 percent | 0.088 | 0.018 |
| income poverty among the unemployed | 0.243 | 0.251, a knife-edge |
| income poverty among the employed | 0.034 | 0.000 |
| asset poverty (financial fragility) | below 0.40 | 0.213 |
| economically vulnerable | 0.36 OECD average | 0.208 |
| membership, employed against unemployed | 0.35 against 0.17 | 0.30 against 1.00 |
| unemployment rate | 0.074 | 0.072 |
| mean paid-time share, employed | 0.53 population | 0.543 |

The hand-to-mouth miss is P5's magnitude. With job-loss risk at French rates
the one-asset buffer-stock model holds about a third of the liquid wealth
shortfall the data show, and asset poverty falls below the OECD range from
above it. This is the standard over-saving of a single-asset model under
realistic risk, and the standard remedies, an illiquid asset (Kaplan and
Violante 2014) or discount-factor heterogeneity (Carroll, Slacalek, Tokuoka
and White 2017), are both outside this stage. Beta and the income process
were held fixed by Part 4 and stay fixed; the miss is reported, not tuned.

**Linearisation identity.** Map shift at fixed rate +0.00739, slope 0.947,
predicted move +0.1386, measured +0.1370, ratio 0.989. Holds at a one
percent shock even this close to the fold.

**Robustness.**

| check | result |
|---|---|
| stationarity identity, four states, union event, ten points | holds to 7e-13; stored indicators to 1e-16 |
| independent path, no family, 61 taste nodes solved directly | agency 0.6397 against 0.6401; every category within 0.0011 |
| asset grid na 200 against 400, baseline, subsidy, UI | reported differences move at most 0.0033; baseline A moves 0.0009 |
| omega 0.15 and 0.50, recalibrated at each | all five policy effects keep their sign; baseline A spans 0.6396 to 0.6402 |
| theta halved at the calibrated point | rate moves 0.014, hardship 0.020 |

Four of the five are as tight as stage 5b or tighter. The omega row is
remarkably flat: agency varies by 0.0006 across the range, because the
calibration pins the participation rate and the wealth distribution follows.

The theta row is the exception and it is a real weakness. At stage 5b halving
the choice-smoothing scale moved the level by 0.001; here it moves the
participation rate by 0.014 and hardship by 0.020. That is the model sitting
closer to the fold, where every family error is multiplied. It means levels
in this stage are quotable to two decimals, not three, and it is a reason to
treat the uniqueness margin as marginal rather than settled in either
direction.

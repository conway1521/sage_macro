# Stage 7: two fixes, and what they do to S and to A

Specification written 2026-09-12 before any code was run, on the same terms as
`STAGE6.md`. Parts 1 to 5 are fixed in advance. Calibrated parameter VALUES
are not predicted, since they are what the calibration is for; outcomes are.
Deviations are scored in Part 7 and nothing above it is edited after the fact.

## 1. What stage 6 established, and why these two fixes

Stage 6 put job loss in the model and produced one finding, one artefact and
one failure.

The finding: once insurance exists, the agency column is two objects. Under
the OECD asset test a higher replacement rate LOWERS agency, because insured
households hold smaller buffers; under Snower and Lima de Miranda's own
income test it raises it. Every policy that moves risk changes sign between
the two. That finding is independent of everything below and is carried
forward unchanged.

The failure: households save far too much against job loss. The hand-to-mouth
share falls from 0.32 to 0.116 against 0.30 in the data, and the mass at the
borrowing constraint from 0.40 to 0.028. Every hardship statistic, and so the
whole agency column, is read off that distribution. This is the standard
over-saving of a one-asset buffer-stock model under realistic risk.

The artefact: the unemployed participate at a rate of one at every belonging
scale, because participation costs only time and they have no return to
effort. The data say the reverse, 17 percent membership among the unemployed
against 35 among the employed (INSEE Premiere 1327, SRCV-SILC 2008). A model
whose social margin has the wrong sign on the largest observable shock to
participation cannot be used to evaluate policies that move people between
those states.

Both failures have the same character: the model lacks a reason for poor
households to look different from rich ones in the relevant dimension. Stage
7 supplies two, one for wealth and one for participation.

## 2. Fix 1, discount-factor heterogeneity

Each household draws a permanent discount factor. Following Carroll, Slacalek,
Tokuoka and White (2017), *The distribution of wealth and the marginal
propensity to consume*, Quantitative Economics 8(3), who call it the beta-dist
specification and calibrate the spread to wealth data, beta is uniform on

    [beta_bar - nabla, beta_bar + nabla],    beta_bar = 0.96,

discretised to five equal-mass points, independent of education cell and of
employment status. The spread nabla is calibrated to the hand-to-mouth share.
Krusell and Smith (1998) is the earlier use of the same device.

A hard constraint applies. `MODEL_READINESS.md` records that a discount
factor times gross return near one makes the wealth distribution
truncation-driven rather than stationary, which is why the thesis pair was
abandoned. With R = 1.02 this caps the patient end at beta R below about
0.995, so nabla is capped at 0.0155. If the calibration wants more than that,
the cap binds and is reported as a binding constraint, not slipped.

This is also the fix the S+A paper itself asks for. Section 4 of
`paper/sage_sa.tex` reports the education gradient falling 17.2 points short
of the observed 20, and says: richer within-cell income heterogeneity, which
would spread each group's response, is the obvious route to a steeper
gradient and is left to the next version.

## 3. Fix 2, a monetary cost of participation

Participating costs `pcost` units of the consumption good as well as the time
lump `QBAR`, so the budget when d = 1 loses `pcost`. It is a fixed amount, not
a proportion of income, and that is the whole point: a proportional cost
cannot make the poor participate less than the rich, and the fact to be
matched is that the unemployed, who have the most time and the least money,
participate least. Fees, transport, kit and the cost of turning up are fixed
costs in the obvious sense.

`pcost` is calibrated to the RATIO of unemployed to employed membership,
0.17 / 0.35 = 0.486 (INSEE Premiere 1327). The ratio rather than the level,
because the levels come from a different survey year and definition than the
education moments the model already targets: INSEE Premiere 1327 (2008) puts
overall membership at 32.6 percent, INSEE Premiere 1580 (2013) at 42 percent
with 56 against 22 by diploma. Ratios travel across those definitions; levels
do not.

The participation credit is kept exactly as the S+A paper defines it, a
rebate on the foregone earnings of the time lump, so that stage 7 stays
comparable. A second credit is added beside it, a rebate of a fraction rho of
`pcost`, which is what France's 66 percent charitable-donations deduction and
the United Kingdom's 25 percent Gift Aid top-up actually are: a rebate on
money given, not on time. Both are reported. Implementation of the money
credit needs no new parameter, being `pcost` times one minus rho with the
fiscal cost rho times `pcost` times the participation rate.

## 4. Calibration

Four parameters on four moments, jointly, since none is separable:

| parameter | moment | source |
|---|---|---|
| kappa | group participation, lower education 0.25 | INSEE, as in the S+A paper |
| sigma_m | group participation, higher education 0.45 | same |
| pcost | unemployed-to-employed membership ratio 0.486 | INSEE Premiere 1327 |
| nabla | hand-to-mouth share 0.30 | as inherited from the S paper |

Procedure: an outer coarse probe over (nabla, pcost) evaluated at a few
belonging scales, which is cheap because the hand-to-mouth share barely
depends on the social scale; then full families at the candidate points with
an inner dense scan over (kappa, sigma_m), which is interpolation and costs
seconds. The inner scan is the same global scan stage 6 used, kappa free at
every sigma, never a local refinement, because a local refinement is what
produced the stage-5b headline this project had to retract.

Everything else is held at its stage-6 value: beta_bar, R, gamma, psi, phi,
the income process, the labour-market rates, the replacement rate, the grid
family, theta, omega at 0.30 with 0.15 and 0.50 in robustness.

## 5. Predictions

Parameter values are not predicted. Outcomes are.

P1. With nabla = 0 and pcost = 0 the model reproduces stage 6 per node to
1e-9.

P2. pcost can hit the membership ratio within a range that is small relative
to income, under five percent of mean disposable income. If it cannot, the
time-cost model of participation is wrong in a way one fixed cost does not
repair, and that is a finding.

P3. The unemployed participate LESS than the employed at the calibrated
point. This is the sign stage 6 got wrong and the direct purpose of fix 2.

P4. sigma_m FALLS below stage 6's 0.395. Both fixes spread the within-cell
response, and the participation moments pin the TOTAL spreading of the
aggregate response, so dispersion supplied by wealth and by the money cost
substitutes for dispersion supplied by tastes. The naive expectation, that
fixing an artefact restores the stage-5b dispersion, is wrong for this
reason.

P5. Because the moments pin total spreading, the map slope moves much less
than sigma_m does: it stays within 0.03 of stage 6's 0.947. The corollary
matters more than the number. Once within-cell heterogeneity is present, the
ratio sigma_m over sigma-bar stops being an informative statistic, because
sigma-bar is derived for a model in which tastes are the only source of
dispersion. The quantities to read are the measured map slope and multiplier.
The S+A paper's own defence, that the threshold version overstates the true
slope so the verdict is conservative, is what survives; the ten percent
margin is not a quantity this stage can report.

P6. Asset poverty rises from stage 6's 0.213 into the 0.35 to 0.45 band, and
the hand-to-mouth share hits 0.30 by construction.

P7. Agency A falls from 0.640 to between 0.48 and 0.58, since A is alpha
times one minus hardship and hardship rises.

P8. The work subsidy still raises A and lowers participation.

P9. The higher replacement rate still lowers A under the OECD union test, but
by at least a third less than stage 6's 0.094, because households that hold
nothing whatever the risk cannot reduce their buffers further.

P10. The two hardship concepts still disagree in sign on the replacement
rate. This is the stage-6 finding and it should be robust to both fixes; if
it is not, the finding was an artefact of the wealth distribution and must be
withdrawn.

P11. The money credit moves participation more per unit of fiscal cost than
the time credit, because it rebates a cost that binds on the households at
the margin rather than on those with the most to forego.

## 6. Verification

Each gating the next, as in stage 6: switch-off to stage 6; parallel build
bit-identical to serial; the stationarity identity with five beta types and
the union event; the asset grid at na 200 against 400; theta halved, which
stage 6 failed at 0.014 and which should improve if the map flattens; an
independent path with no response family; omega at 0.15 and 0.50 with
recalibration.

## 7. Record

Appended as the stage runs. Nothing above this line changes.

### 2026-09-12, the probes: one fix accepted, one rejected

Three probes, before any production run. Logs `s7_probe.txt`, `s7_probe2.txt`,
`s7_probe3.txt`. Both mechanisms were implemented as specified and both were
put to the data before anything was calibrated on them.

**Fix 2, the monetary cost of participation, is rejected.** It moves the
employed-to-unemployed participation ratio the WRONG WAY. From a baseline of
3.3, where the target is 0.486, raising the money cost takes it to 5.4, 9.3
and 43.6. The employed rate collapses from 0.30 to 0.02 while the unemployed
rate stays at 0.95.

The reason is not that the poor are not poorer. It is that consumption
smoothing works. An unemployed household on a 68 percent replacement rate,
drawing on a buffer, consumes nearly what it did in work, so a fixed money
cost bites almost equally on both. What differs between the two states is
time, and there the employed, who sit near indifference already, drop out
first.

The obvious repair, scaling the belonging payoff when unemployed, fails too,
and the failure is quantitative rather than marginal. At a scale of 0.30, 0.15
and 0.10 the unemployed rate does not move at all. At 0.01, belonging worth
one percent of its employed value, the ratio is still 1.66, on the wrong side
of the target 0.486. No admissible parameter reproduces the data.

The arithmetic behind it, at the calibrated belonging payoff of 0.438:

| time already committed | utility cost of the participation lump |
|---|---|
| 0.00 | 0.0047 |
| 0.10 | 0.0327 |
| 0.16 | 0.0629 |
| 0.30 | 0.1727 |
| 0.54, the calibrated work share | 0.4885 |

With a convex time cost, phi = 14 and psi = 2, the participation lump costs a
household at the calibrated work share a hundred times what it costs one at
zero. Participation is therefore nearly free to anyone not working, and the
surplus is far too large for any reduction in the payoff to close.

**That is the finding, and it is larger than the fix it replaces.** The
participation margin of the S+A paper models the cost of joining as forgone
work time alone. That specification cannot represent the best-documented fact
about participation and unemployment, that membership falls by half on job
loss, and it cannot do so for a structural reason rather than a calibration
one. Repairing it means giving participation a cost that does not vanish when
market work does: a search or home-production commitment that keeps the
unemployed on the steep part of the disutility curve, or a payoff that depends
on work-linked networks rather than on time alone. Both are redesigns of the S
margin and neither is a parameter. Stage 7 leaves the defect standing and
flagged rather than tuned around, and the unemployed continue to participate
at one.

**Fix 1, discount-factor heterogeneity, is accepted, in a modified form.** The
symmetric specification of Carroll, Slacalek, Tokuoka and White is capped by
stationarity at a spread of 0.019 around 0.96, and the whole admissible range
moves the hand-to-mouth share from 0.105 to 0.132 against a target of 0.30.
The binding direction is impatience and impatience faces no stationarity
limit, so the spread was made one-sided and downward: uniform on
[0.96 - nabla, 0.96], five equal-mass points, the patient end left at the
inherited discount factor so that no household sits closer to the
stationarity boundary than the model already did. That works:

| nabla | discount factors | hand-to-mouth |
|---|---|---|
| 0.000 | 0.960 | 0.075 |
| 0.020 | 0.942 to 0.958 | 0.237 |
| 0.030 | 0.933 to 0.957 | 0.298 |
| 0.040 | 0.924 to 0.956 | 0.347 |
| 0.060 | 0.906 to 0.954 | 0.464 |

nabla = 0.030 is taken, giving discount factors from 0.933 to 0.957, a mean
of 0.945. That is inside the annual-equivalent range Carroll and co-authors
use, and the aggregate participation rate barely moves across the whole
column, 0.340 to 0.354, so the wealth fix does not itself disturb the social
margin.

### 2026-09-12, the first production run, and what it forced

Run at nabla = 0.030, the value probe 3 gave. Log `sa_stage7.txt` (since
overwritten by the rerun at 0.036; the numbers below are the 0.030 run).

**The accepted fix does what it was for.** Hand-to-mouth 0.271 against 0.116
at stage 6 and a target of 0.30; asset poverty 0.354 against 0.213, back
inside the OECD band for France; agency 0.5212, inside the [0.48, 0.58] that
Part 5 predicted before anything was run. P6 and P7 hold. The family-weighted
hand-to-mouth came out 0.027 below the single-scale probe, so nabla is moved
to 0.036 for the headline.

**The stage-6 finding survives, which was the thing most at risk.** P10 holds:
the two hardship concepts still disagree in sign on the replacement rate,
minus 0.132 on the OECD union against plus 0.016 on the source's income test.
It was not an artefact of the broken wealth distribution.

**The run failed the gate's sharpest test.** The linearisation identity came
back at 0.269 against a required 1, the calibrated map slope was 0.9908 and
the implied policy multiplier 109. Four convergence checks were run rather
than reporting that, and every discretisation is clean:

| check | result |
|---|---|
| belonging grid at spacing 0.05 against 0.2 | identical to four decimals for sigma at or above 0.40 |
| discount points, 15 against 5 | identical to four decimals at every sigma |
| taste quadrature, 32000 against 2000 nodes | slope within 0.003 |
| equilibrium grid, 25601 against 401 points | slope within 0.001 |

So the roughness is the model, not the numerics, and what it means is this.
The loss surface has a narrow dip at sigma 0.375, root loss 0.0184, sitting
between neighbours at 0.0667 and 0.0335. The slope there is 0.99; one step
either side it is 0.94 to 0.98. The difference in FIT across that region is
trivial. The difference in the implied MULTIPLIER is 109 against 17.

**The participation moments do not identify the policy multiplier.** That is
the sharper form of a problem the S+A paper already documents as a valley in
its calibration, and correcting the wealth distribution has made it much
worse. The uniqueness ratio sigma_m over sigma-bar is below one across the
whole acceptable-fit region, 0.81 to 0.86, so the paper's central margin does
not survive the correction either.

P5 is therefore scored FAILED, and its corollary is the one that matters: the
quantity to read is not the ratio, and it is not a single multiplier. It is a
range, and the range is wide enough that no policy magnitude on either the S
or the A side is quotable from this stage. The driver now computes and prints
that range rather than leaving a reader to find it, and takes an optional
pinned (kappa, sigma_m) so the headline can be checked at a point the moments
fit almost as well.

What is NOT affected: the baseline agency level. The equilibrium participation
rate moves from 0.3497 to 0.3513 across the region, so the baseline wealth
distribution, and every hardship statistic read off it, is stable. It is the
policy RESPONSES that inherit the non-identification.

### 2026-09-12, the headline at nabla = 0.036, and what the non-identification does and does not touch

Two full runs at omega 0.30, identical except for the social technology: one
auto-calibrated, landing at kappa 9.92, sigma_m 0.380, map slope 0.9811, and
one pinned at kappa 9.90, sigma_m 0.405, slope 0.9313, which the moments fit
almost as well, root loss 0.0275 against 0.0198. The multiplier differs by a
factor of three and a half between them, 53 against 15. Logs `sa_stage7.txt`
and `sa_stage7_pin405.txt`.

**The wealth fix delivers, and agency returns to where it was.**

| | stage 5b, no job loss | stage 6 | stage 7 |
|---|---|---|---|
| hand-to-mouth, target 0.30 | 0.32 | 0.116 | 0.294 |
| asset poverty, France below 0.40 | 0.428 | 0.213 | 0.401 |
| income poverty, INSEE 0.088 | 0 by construction | 0.018 | 0.022 |
| agency A | 0.480 | 0.640 | 0.483 |

Agency comes back to 0.483 against 0.480 before unemployment was ever added.
The stage-6 reading of 0.640 was the over-saving and nothing else. That is the
strongest evidence so far that the agency column measures a property of the
economy rather than tracking whatever the wealth distribution happens to be,
because it survived being moved a long way and brought back.

**The non-identification of the multiplier does not reach the agency column.**
This was the thing at risk, and the two runs settle it.

| quantity | auto, multiplier 53 | pinned, multiplier 15 |
|---|---|---|
| baseline A | 0.4833 | 0.4838 |
| work subsidy | +0.3004 | +0.2997 |
| empowerment | -0.0029 | +0.0061 |
| participation credit | +0.0267 | +0.0273 |
| UI replacement +0.10 | -0.1365 | -0.1416 |
| UI replacement at floor | +0.1381 | +0.1461 |
| participation, baseline | 0.3518 | 0.3507 |
| participation, under empowerment | 0.6236 | 0.5393 |
| participation, under the subsidy | 0.1448 | 0.1588 |

Every agency number is stable to the third decimal across a three-and-a-half
fold change in the multiplier. Every participation number is not: empowerment
moves participation by 0.27 in one calibration and 0.19 in the other. The
reason is that the hardship statistics are driven by the direct effect of each
policy on earnings and buffers, and the participation feedback is second order
for them, while for participation itself the feedback IS the result.

So the split is clean. **The participation results inherit the
non-identification; the agency results do not.** The one exception is
empowerment, whose agency effect changes sign between the two, and it is
smaller than 0.01 either way: raising low-education agency raises participation
enough that the time and saving cost almost exactly cancels the mechanical
gain, and which side of zero that lands on is not something this model
identifies. It should be reported as indistinguishable from zero, which is
itself the interesting statement, since at stage 5b it was the third largest
positive effect on the dashboard.

**P10 holds in both runs.** The two hardship concepts still disagree in sign
on the replacement rate: minus 0.137 and minus 0.142 on the OECD union against
plus 0.016 and plus 0.017 on the source's income test. The stage-6 finding is
now confirmed on a corrected wealth distribution and at two calibrations with
very different multipliers.

**Predictions scored.** P1 to P3 in the probe entry above. P4 holds, sigma_m
0.380 against stage 6's 0.395. P5 FAILS: the slope is 0.9811 against a
predicted band of 0.947 plus or minus 0.03, and more to the point the slope is
not a single number at all, which the prediction did not anticipate. P6 holds,
asset poverty 0.4013 and hand-to-mouth 0.2944. P7 holds, A 0.4833 inside the
predicted [0.48, 0.58] and at the very bottom of it. P8 holds. P9 FAILS on
magnitude: the replacement-rate effect is minus 0.137, larger than stage 6's
minus 0.094 rather than at least a third smaller, because restoring the
hand-to-mouth tail gave the policy more households whose buffers can move, not
fewer. P10 holds. P11 is not tested, the money credit having gone with the
money cost.


### 2026-09-12, verification

| check | result |
|---|---|
| stationarity identity, four states, five discount types, union event | holds to 7e-13; stored indicators to 1e-16 |
| theta halved at the calibrated point | participation moves 0.0085, hardship 0.0051 |
| omega 0.15, 0.30 and 0.50, recalibrated at each | see below |
| independent path, no response family | agency reproduces to 0.0001; every category within 0.001 |
| asset grid, na 200 against 400 | reported differences move at most 0.0078; baseline agency 0.0089 |

The theta row improves on stage 6, which moved 0.0141 and 0.0204, and the
hardship figure is the one that matters for the agency column: 0.005. The
asset-grid row puts baseline agency at two decimals rather than three, 0.48,
which is how it should be quoted.

The independent path caught a real error before it reached a number anyone
would read. Its first run returned agency 0.6404, asset poverty 0.2134 and
hand-to-mouth 0.1166, which are the STAGE-6 figures to three decimals. The
script had been derived from its stage-6 counterpart, which solves one
parameter set per taste node, and at stage 7 that silently drops the discount
heterogeneity and reproduces the previous economy. Once each (discount type,
taste node) pair is solved and mixed, it agrees with the family reduction to
0.0001 on every quantity. The episode is worth recording because the failure
mode was not a crash: it was a check that ran clean and disagreed, and the
disagreement was the check working.

**The omega sweep is the strongest robustness evidence in this project so
far**, because recalibrating at each omega happens to span almost the whole
multiplier range the non-identification implies, 2.7 at omega 0.50 against 53
at 0.30 and 49 at 0.15.

| omega | kappa | sigma_m | multiplier | A | subsidy | empowerment | credit | UI + | UI floor |
|---|---|---|---|---|---|---|---|---|---|
| 0.15 | 12.08 | 0.595 | 49.0 | 0.4837 | +0.3002 | +0.0078 | +0.0268 | -0.1296 | +0.1436 |
| 0.30 | 9.92 | 0.380 | 52.8 | 0.4833 | -0.0029 | +0.0267 | -0.1365 | +0.1381 | |
| 0.50 | 8.05 | 0.330 | 2.7 | 0.4825 | +0.3002 | +0.0237 | +0.0302 | -0.1479 | +0.1526 |

Across a twentyfold range in the policy multiplier and the whole span of the
one parameter with no point estimate:

| quantity | range |
|---|---|
| baseline agency | 0.4825 to 0.4837 |
| asset poverty | 0.4013 to 0.4026 |
| income poverty | 0.0215 to 0.0217 |
| hand-to-mouth | 0.2939 to 0.2971 |
| work subsidy on agency | +0.3002 to +0.3004 |
| participation credit on agency | +0.0267 to +0.0302 |
| replacement rate on agency, union test | -0.1479 to -0.1296 |
| replacement rate on agency, income test | +0.0164 to +0.0166 |
| empowerment on agency | -0.0029 to +0.0237, SIGN CHANGES |

The work subsidy's effect on agency is identical to three decimals at
multipliers of 2.7 and 53. The two hardship concepts keep opposite signs on
the replacement rate at every omega. Only empowerment changes sign, and it is
the one effect small enough to be indistinguishable from zero throughout.

That is the stage's central methodological result. The agency column is a
distributional statistic and inherits almost nothing from the fixed point; the
participation column is the fixed point and inherits all of it. A dashboard
that reports both should say so, because a reader will otherwise assume the
two are equally well identified, and they are not.

### 2026-09-14, the committed-time mechanism is closed by the data

The retest at the corrected footing (`scripts/probe_defect.txt`) left one
candidate standing. Committed time when out of work moved the unemployed only
in combination with a devalued belonging payoff, and the two traded off
against each other, so the participation ratio pinned a curve through the pair
rather than a point. Calibrating both to the one moment would have swapped a
known defect for an unidentified parameter, which is the same disease as the
multiplier. The way out was to pin the time parameter externally and leave the
second to the moment.

Committed time when out of work is measurable, and it has been measured on the
same survey the effort calibration already rests on.

**What the time-use evidence says.** Three sources, two of them independent of
each other in data and country coverage, agree on the magnitude.

Brousse (2015), Economie et Statistique 478-479-480, Table 12, drawn from the
INSEE Enquete Emploi du temps 2010, persons aged 18 to 64 in metropolitan
France, average day:

| ages 30 to 54 | professional and studies | domestic |
|---|---|---|
| in employment | 5h27 | 3h06 |
| unemployed | 0h41 | 5h17 |

| ages 18 to 29 | professional and studies | domestic |
|---|---|---|
| in employment | 5h43 | 2h05 |
| unemployed | 0h34 | 3h26 |

The unemployed take on 131 extra minutes of domestic activity a day at 30 to
54, and 81 at 18 to 29, against foregone professional time of 286 and 309
minutes. That is 0.458 and 0.262 of the work time given up. The article's own
regression (Annexe, Table B), which conditions on sex, household, education
and disability, puts the unemployed at +130 minutes of domestic activity for
women and +127 for men relative to full-time employment, which matches the raw
prime-age figure closely enough to treat the composition story as settled.

Krueger and Mueller (2012), Journal of the European Economic Association,
Table 3, Western Europe pooled, ages 20 to 54, all days: the unemployed do 100
more minutes of non-market committed activity a day than the employed (home
production and care +73, shopping and services +15, job search +12) against
295 minutes of foregone work, a share of 0.339. Aguiar, Hurst and Karabarbounis
(2013), American Economic Review 103(5), reach the same place from the American
Time Use Survey: home production absorbs roughly 30 percent of foregone market
work hours and job search between 2 and 6 percent.

Job search itself is small everywhere and small in France in particular.
Krueger and Mueller's Table 4 puts the French unemployed at 20.9 minutes a day
unconditionally, with 19.4 percent searching on a given day and 107.8 minutes
conditional on searching. Search is 7 percent of foregone work time. The
committed time of an unemployed person is domestic work, not job search, which
is worth stating because the parameter was named for search and the naming was
misleading.

**Converting to model units.** The engine's time endowment is committed time,
paid plus unpaid, and phi is set so that the employed paid share is 0.53. The
floor belongs to the same scale, so it is the data ratio times the model's own
paid time:

| source | share of foregone work | model time floor |
|---|---|---|
| Brousse, ages 30 to 54 | 0.458 | 0.243 |
| Krueger and Mueller, Western Europe | 0.339 | 0.180 |
| Brousse, ages 18 to 29 | 0.262 | 0.139 |

The admissible range is 0.14 to 0.24, centred near 0.19.

**The verdict.** At every value in that range the mechanism does nothing at
all. `probe_defect.txt` reports the employed rate, the unemployed rate, the
ratio and the hand-to-mouth share as bit-identical at floors of 0.10, 0.20,
0.30 and 0.40, all equal to the no-mechanism row: 0.2629, 1.0000, 3.804,
0.2901. The first movement is at 0.50, which is more than double the top of
the data range and is itself close to the calibrated work share, and even
there the unemployed rate only falls to 0.9337 against a target of 0.486.

This is not a near miss to be split with a combination. The externally
identified value of the parameter leaves the model exactly where it started,
which means there is no free parameter left to hit the moment with. The
committed-time mechanism is closed, the money cost was closed on 2026-09-12
and again at the corrected footing, and scaling the belonging payoff was
closed at both footings. All three candidates are spent.

**Why the transition is sharp, and why it is not a bug.** The flip from 0.9999
to 0.0000 between floors of 0.30 and 0.40 at a belonging scale of 0.50 looks
like a knife edge and partly is one: at a fixed belonging scale the unemployed
are homogeneous in every dimension the participation decision depends on, they
all choose zero effort, they all face the same time cost, and with a logit
scale of 0.005 they cross together. Population taste heterogeneity would smooth
this into a gradient. The mechanism is wired correctly, which the flip itself
demonstrates, and the identical rows below 0.50 are a saturated logit rather
than a dead parameter. The unemployed's consumption and saving are untouched
because the floor changes the time constraint and the disutility, not the
budget, which is why the hand-to-mouth share does not move either.

**What the defect costs.** The model's unemployed share at this footing is
implied by the aggregate: 0.3160 = (1 - u) x 0.2629 + u x 1.0000 gives u =
0.072. At the target ratio the unemployed would participate at 0.486 x 0.2629
= 0.128, and the aggregate would be 0.253. The model reports 0.316. The
aggregate participation rate, which is the object the social multiplier acts
on, is overstated by 25 percent. That is material for policy work and it has
to be said plainly rather than filed as a footnote.

**Where this leaves the margin.** The structural reading is that the model
predicts the sign correctly for the wrong reason and the data disagree with
the mechanism, not the parameter. Participation here is a choice whose cost is
time and whose payoff is unchanged by employment status. The unemployed have
the lowest opportunity cost of time in the economy, so they participate most.
The empirical literature on why unemployment reduces social contact is not
about the price of time: Jahoda's latent deprivation account and the Paul and
Moser (2009) meta-analysis in the Journal of Vocational Behavior treat the loss
of collective purpose and structure as a direct consequence of job loss rather
than as a budget or time constraint. That is a different object from anything
the current margin contains, and it cannot be reached by making participation
more expensive.

Two honest options follow, and neither is the one that was being attempted.
Document the defect, quarantine it, and check whether the reported results
depend on the unemployed's counterfactual behaviour; or rebuild the
participation payoff so that part of belonging is attached to employment
itself rather than bought with time. The first is cheap and should come first,
because if the reported results are insensitive to the unemployed block the
defect is a stated limitation rather than a blocker. The second is a redesign
of the S margin and should not be started until the first is answered.

**One item found in passing, not acted on.** The phi calibration cites the
Enquete Emploi du temps 2010 at 3h24 paid against 3h01 unpaid, a paid share of
0.530. Brousse's Table 12 puts employed persons aged 30 to 54 at 5h27 against
3h06, a paid share of 0.637, and those aged 18 to 29 at 5h43 against 2h05, a
share of 0.733. The 3h24 figure looks like a population-wide average across all
activity statuses rather than an employed-only one, which would make the
model's employed work less, relative to their committed time, than employed
French adults do. The source of the 3h24 and 3h01 pair has not been traced, so
this is recorded and not corrected. It does not affect the verdict above,
which uses the data only as a ratio and takes the level from the model.

### 2026-09-14, the quarantine: the defect is a blocker, not a limitation

Scripts `scripts/quarantine.jl` (stopped, log `quarantine.txt`) and
`scripts/quarantine2.jl` (log `quarantine2.txt`). Footing: G+S+A, unemployment,
discount spread 0.037, kappa 9.90, sigma 0.385, eleven productivity states.

**The first design failed on its own evidence.** It bracketed the truth between
the economy as it stands and one where a time floor of 0.40 and belonging at
0.50 drive the unemployed out. The second baseline was enough: aggregate
0.3574 to 0.0413, employed 0.3075 to 0.0438. Removing a seven percent group
from participation collapsed the employed as well. Interpolating between a
high and a collapsed equilibrium bounds nothing, and at sixteen minutes an
economy the design needed about eight hours, so it was stopped.

**The second design imposes the data on one set of families.** At zero
participation credit and zero money cost, an unemployed household's
participation has no budget effect (its effort is zero) and its logit option
value does not depend on assets. So what the unemployed do on this margin moves
no savings or effort policy at a given belonging scale; it moves only the
aggregate. The counterfactual can therefore be computed by rewriting the
unemployed's participating mass at each node, with no household problem solved
again. The rule imposed is unemployed rate = ratio x employed rate at the same
node. Three checks passed before anything was read: node rates equal summed
participating mass (worst gap 1e-15); the untouched families reproduce the
suite (0.357355, 0.494664, 0.299820); and imposing an unemployed level of
0.0091 reproduces the independent full re-solve exactly (0.0413 and 0.0438).
The shortcut is exact here, not an approximation.

**At the calibrated technology, the high equilibrium does not survive.**

| unemployed participation | rate | employed | unemployed | agency | hardship | htm | multiplier |
|---|---|---|---|---|---|---|---|
| as it stands | 0.3574 | 0.3075 | 1.0000 | 0.4947 | 0.3949 | 0.2998 | 34.0 |
| ratio 1.000 | 0.0448 | 0.0454 | 0.0365 | 0.5319 | 0.3520 | 0.2670 | 1.9 |
| ratio 0.486, INSEE | 0.0423 | 0.0442 | 0.0173 | 0.5320 | 0.3518 | 0.2669 | 1.8 |
| ratio 0.000 | 0.0401 | 0.0432 | 0.0000 | 0.5322 | 0.3517 | 0.2667 | 1.8 |

Every row has a single crossing of the participation map, so this is not a
switch between coexisting equilibria. The defect shifts the map itself: the
calibrated economy has one equilibrium at 0.357 only because the unemployed
participate far above the employed rate, and with them even at parity (ratio
1.0) it has one equilibrium at 0.045. The current footing is calibrated on the
defect.

**Recalibrated under the INSEE ratio, the model fits better than before.** The
technology scan on the imposed families (sigma step 0.02, quadrature 500, group
targets 0.25 and 0.45) finds its best point at kappa 10.80, sigma 0.48, root
loss 0.0044. The same scan at the current footing had a best loss of 0.0233,
though on a finer quadrature, so the comparison is indicative rather than
exact. As a full economy:

| | as it stands | INSEE ratio, recalibrated |
|---|---|---|
| kappa, sigma | 9.90, 0.385 | 10.80, 0.48 |
| participation | 0.3574 | 0.3475 |
| employed, unemployed | 0.3075, 1.0000 | 0.3620, 0.1604 |
| agency | 0.4947 | 0.4871 |
| hardship (union) | 0.3949 | 0.4042 |
| hand-to-mouth | 0.2998 | 0.3070 |
| slope, multiplier | 0.9706, 34.0 | 0.9032, 10.3 |

Once both economies are fitted to the same targets, the levels are close:
agency moves 0.0076, just above the 0.005 tolerance, and hand-to-mouth stays on
its 0.30 target without touching the discount spread. The +0.037 agency gap in
the first table compares a calibrated economy with a collapsed one and is not a
statement about calibrated levels.

The multiplier is still not identified. The "acceptable-fit region" printed a
single point only because the best loss is small and the criterion is relative
(1.5 times the best). On the absolute standard used at stage 7 (losses up to
about 0.035), sigma 0.44 to 0.62 qualifies and the multiplier ranges from 3.5
to 29.4. The correction narrows the range from 8.8 to 43.1 but does not close
it.

**What the imposed ratio is and is not.** It is a reduced-form rule with one
data number and no free parameter, not a mechanism: the unemployed do not
choose their participation, it is tied to the employed rate. It stays exact
for any policy that leaves unemployed participation without a budget effect,
which covers the work subsidy, empowerment and the replacement rate. It does
not hold under the participation credit, which pays participants and so gives
the unemployed a budget reason to join; that policy cannot be run this way.

**Corrections to earlier statements in this document.** The 21 percent
overstatement of aggregate participation was an arithmetic count at fixed
behaviour and is superseded: the defect does not inflate the equilibrium, it
sustains it. `probe_defect.jl` omits `S = true`; its numbers stand because a
response family imposes the belonging scale directly and bypasses the switch,
but its header label is wrong and a reader should know that a config can say S
is off while the families read are social.

**One problem found in passing, not acted on.** In the first run's work-subsidy
tax loop the equilibrium went from 0.7797 at a tax of zero to 0.1685 at 0.076,
so at the old footing a small fiscal change moved the economy a long way and the
closure may not converge. Whether this persists at the recalibrated footing,
where the multiplier is 10 rather than 34, is untested.

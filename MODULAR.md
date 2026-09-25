# The modular SAGE economy

Written 2026-09-13. What the stack is, what it guarantees, and what is not yet
settled. This is the state document for the model itself, as distinct from
`STAGE6.md` and `STAGE7.md`, which record two particular extensions, and from
`AGENCY.md`, which records what the agency column is.

## What it is

One configuration type, one solver, one result. `SAGEConfig` describes an
economy completely; `solve_economy` returns every column of the dashboard;
`test_modular.jl` checks that the switches behave.

| file | what it holds |
|---|---|
| `src/SAGEBewley.jl` | the engine: parameters, the income process, the baseline solver, wellbeing accounting |
| `scripts/proto_participation_core.jl` | the household problem with the discrete participation choice, hard-threshold and logit forms |
| `scripts/agency_core.jl` | the hardship threshold and the cumulative distributions everything is read off |
| `scripts/unemployment_core.jl` | the employment process, discount-factor types, the per-cell summary, the hardship categories |
| `scripts/sage_modular.jl` | `SAGEConfig`, `solve_economy`, `describe`, `report` |
| `scripts/modular_stack.jl` | the load order, as one file, for workers |
| `scripts/modular_workers.jl` | process parallelism |
| `scripts/test_modular.jl` | the suite |

## The dimensions

In SAGE terms, with the framework's own letters.

**G, material gain.** Always present: consumption, effort, saving. On its own
this is a Bewley-Aiyagari economy with an effort margin.

**S, social cohesion**, as the participation margin: a discrete choice to
commit a lump of time whose payoff rises in how many others do the same,
following Brock and Durlauf (2001). Off means the interaction strength is
zero, at which the household problem collapses to G.

**A, agency**, following Snower and Lima de Miranda (2020) section 3.3. Two
halves: alpha, the ability to turn effort into income, which differs across
education cells when A is on; and freedom from hardship, which is an
accounting column computed in every configuration.

**E, environment.** Not implemented.

Two extensions are switches of their own, independent of the dimensions:
unemployment risk with earnings-related insurance, and permanent
discount-factor heterogeneity.

## What the suite guarantees

Thirteen reductions, each checked rather than asserted, all passing at
**exactly zero difference** on ten reported quantities at production numerics.

| reduction | |
|---|---|
| G+A with agency equalised | gives back G |
| G+S with the interaction strength at zero | gives back G |
| G+S+A with the interaction strength at zero | gives back G+A |
| G+S+A with agency equalised | gives back G+S |
| G+S+A with both switched off | gives back G |
| G+S+A with unemployment at zero separation | gives back G+S+A |
| G+S+A with the discount spread at zero | gives back G+S+A |
| G+S+A with both extensions off | gives back G+S+A |
| G+S+A with the monetary participation cost at zero | gives back G+S+A |
| G+S+A with every policy instrument at zero | gives back G+S+A |
| the same configuration solved twice | identical |
| the baseline solved twice | identical |
| the two cells listed in the other order | identical |

Two of these are worth singling out.

The unemployment reduction is not a tautology. Switching unemployment off
builds a genuinely different state space, nz states rather than 2nz with half
of them unreachable, and the two still agree exactly. An earlier version of
the code kept the unreachable states and the test was vacuous.

The foundation is checked separately, in `probe_reduction.jl`: the
participation solver at zero social strength reproduces the engine's own
baseline solver to 9e-9 on effort, income, wealth, the mass at the borrowing
constraint and the wealth median. So this is one economy with switches, not
two code paths that happen to agree.

## What the suite found

The suite was not a formality. It caught a defect in the baseline that had
been present through every stage of this project.

**Two productivity states are not enough for a threshold statistic.** With
nz = 2 the income distribution is two clusters of near-equal mass with a gap
between them, and the median falls in the gap: the baseline 48th percentile is
0.378 and the 50th is 0.530. That gives a median-to-mean ratio of 1.17, which
no income distribution has. The poverty line is half the median and the asset
threshold a quarter of that, so every hardship statistic, and therefore the
whole agency column, inherited a forty percent jump from a number that was not
identified.

| productivity states | median | median over mean | asset poverty | agency |
|---|---|---|---|---|
| 2 | 0.530 | 1.17 | 0.433 | 0.475 |
| 3 | 0.444 | 0.979 | 0.571 | 0.360 |
| 5 | 0.444 | 0.979 | 0.547 | 0.380 |
| 7 | 0.444 | 0.980 | 0.550 | 0.377 |
| 9 | 0.444 | 0.978 | 0.550 | 0.377 |

Three states fix the median; seven settle the agency column without the social
dimension. The existing income-process sweep in this project
(`audit_nz_l5.txt`) passed at two states because the participation results are
not threshold statistics. A threshold statistic is a different question and
nobody had asked it.

**Consequence.** Stages 6 and 7 were run at two states, so their agency LEVELS
are not converged, and the discount spread was calibrated against a
hand-to-mouth share computed at two states, so the calibration moves too. The
reductions, the identities, the independent-path check and the omega
robustness are unaffected, since none of them depends on the income process
being fine enough. What has to be recomputed is the calibration and the
levels. At seven states with unemployment a solve costs 3.1 seconds against
0.7, so that is hours rather than days.

The modular default is therefore seven productivity states, not the engine's
two. The engine's own default is left alone so the S paper is unaffected.

## The poverty line, and why it is not the model's own median

The OECD line is half the median equivalised disposable income, and taking the
median from the model is the obvious reading. It does not work, for a reason
that took three probes to pin down.

Income in this model is a set of clusters, one per productivity state, so the
median is a discrete statistic that hops between them. At two states that is a
jump from 0.378 to 0.530. Adding states shrinks the jumps but does not remove
them: the median drifts monotonically upward, 0.4160 at five and seven states,
then 0.4220, 0.4280, 0.4338 at nine, eleven and thirteen, carrying agency down
from 0.384 to 0.369 with it.

The line is therefore anchored on MEAN income instead, which has no atoms and
is stable to 0.001 across every state space tried, times the empirical
median-to-mean ratio. France, Eurostat ilc_di03 at the latest reference year:
mean equivalised net income EUR 30 438 against a median of EUR 26 459, a ratio
of 0.8693. That holds the line at 0.1967 to 0.1970 across five to thirteen
states, against 0.2080 to 0.2169 when it came from the model's own median.

It also corrects a second thing. The model's own median-to-mean ratio runs
from 0.92 to 0.96, against 0.87 in the data: its income distribution is far too
compressed, so its own median produces a poverty line about a tenth too high.
Anchoring fixes the discreteness and the compression at once, and it is the
more defensible reading of the OECD definition, which is a line computed from a
population, not from a model.

## How many productivity states

Eleven, not the engine's two, and not the seven the median fix first suggested.

Rouwenhorst matches the mean, variance and autocorrelation of the process
exactly at every state count, but its stationary distribution is binomial and
approaches a normal only as the count grows. A threshold on wealth depends on
the SHAPE of the income distribution, not only on its variance, so it converges
at the rate the binomial approaches the normal rather than at the rate the
moments are matched. That is why the participation results were fine at two
states and the hardship statistics are not.

With the line anchored, agency moves 0.008 from seven states to nine and 0.005
from nine to eleven, then oscillates inside 0.004 out to twenty-three. With
unemployment on, the configuration stage 7 uses, it is inside 0.002 from nine.
Eleven is where it settles, and the residual 0.002 is why agency is quoted to
two decimals and not three.

Cost: 5.3 seconds a solve at eleven states with unemployment, against 0.7 at
two. Affordable.

## What is not settled

| discretisation | move in agency |
|---|---|
| productivity states, 9 against 7 | 0.0076, NOT SETTLED |
| productivity states, 5 against 7 | 0.0007 |
| asset grid, 400 against 200 | 0.0019 |
| effort grid, 160 against 80 | 0.0013 |
| choice smoothing, theta halved | 0.0007 |
| taste quadrature, 8000 against 2000 | 0.0000 |
| asset grid top, 8 against 4 | 0.0001 |

Six of seven settle inside 0.005. The productivity row does not, and only when
the social dimension is on: without it, nine against seven moves 0.0001. The
sequence is also not monotone, 0.3706 at five, 0.3713 at seven, 0.3637 at
nine, which is the signature of amplification rather than of a trend.

The likely cause is that the configuration being tested is not a calibrated
economy. Its interaction strength and taste dispersion are inherited from the
stage-7 calibration, which was done at two productivity states, so the
participation rate is 0.64 against a French target of 0.35 and the economy may
be sitting somewhere steep. `probe_nz2.jl` tells the two apart by reporting
the map slope alongside, and repeats the sweep at a social technology that
puts the rate near the target. Until that comes back, the modular stack is
sound on every reduction and the agency column is quotable to two decimals,
not three.


**2026-09-14.** The calibrated footing used above (kappa 9.90, sigma 0.385) is
sustained by the unemployed-participation defect: with the unemployed at the
INSEE ratio the same technology has a single equilibrium at 0.042. Recalibrated
under the ratio it lands at kappa 10.80, sigma 0.48, participation 0.3475,
agency 0.4871. See STAGE7.md, the quarantine section, before quoting any number
from the four-economy table.

## 2026-09-24, countries: the United States is not calibrated (decision)

The US G+S+A cohesion-off fit reached a hand-to-mouth share of 0.019 at the
largest discount spread tried, 0.115, against an aim of 0.281 (target 0.31). The
cause is the benefit: the OECD Tax-Benefit net replacement rate averages 0.13
over the first twelve months of unemployment, because US benefits run out after
about five, and with that little insurance even the most impatient type builds a
buffer. A one-asset model cannot deliver a large hand-to-mouth share without
either insurance or implausible impatience.

Decision (the author, 2026-09-24): the United States is reported as not
calibrated, in all four configurations. It is not tuned. Two routes remain open
and neither is taken: defining the US benefit over a typical spell (33 to 38
percent for about five months) or including food stamps and social assistance,
which would change the benefit concept for one country only; and a wider
discount spread, which the literature would not support. The first is the
natural sensitivity if the US is ever needed. The data row stays in
`data/country_labour_participation.csv`; the markers
`SAGE_Bewley/scripts/calibration_country_US*.not_calibrated.txt` keep the runner
from retrying, and deleting them re-enables it.

`calibrate_country.jl` now stops any configuration whose cohesion-off fit ends on
the spread grid's edge more than 0.05 from its hand-to-mouth aim, so a case like
this costs a minute rather than an hour.

## 2026-09-25, three countries calibrated in every configuration; the suite passes at France's new footing

**Basis.** One data basis for every country: EU-SILC 2015 formal volunteering by
education (the targets for participation), OECD 2023 unemployment by education,
long-term unemployment share and twelve-month net replacement rate (the labour
market and the benefit), HETUS 2010 paid share of committed time (effort), and
the hand-to-mouth targets carried over from the country table. The unemployed
participate at the national ratio of the employed rate. Sources:
`data/country_labour_participation_sources.md`. France moved onto this basis
from its INSEE targets. The United States is not calibrated (section above).

**Each configuration calibrated to its own targets.** Effort to the country's
target, hand-to-mouth within 0.01 of its target, and for G+S and G+S+A
participation in both education cells within the root-loss standard.

| | phi | spread | kappa | sigma | participation | hand-to-mouth | agency | multiplier |
|---|---|---|---|---|---|---|---|---|
| France G | 14.34 | 0.032 | | | 0 | 0.3045 | 0.5014 | |
| France G+A | 14.38 | 0.031 | | | 0 | 0.2997 | 0.4948 | |
| France G+S | 14.34 | 0.027 | 10.60 | 0.58 | 0.2472 | 0.3018 | 0.5031 | 4.3 |
| France G+S+A | 14.38 | 0.026 | 10.95 | 0.92 | 0.2461 | 0.3011 | 0.5012 | 2.0 |
| Germany G | 18.98 | 0.009 | | | 0 | 0.3238 | 0.5195 | |
| Germany G+A | 19.03 | 0.009 | | | 0 | 0.3223 | 0.5149 | |
| Germany G+S | 18.91 | 0.005 | 11.70 | 0.50 | 0.2946 | 0.3117 | 0.5293 | 10.6 |
| Germany G+S+A | 19.00 | 0.005 | 12.20 | 0.78 | 0.3009 | 0.3109 | 0.5252 | 2.5 |
| Italy G | 9.23 | 0.040 | | | 0 | 0.4106 | 0.4192 | |
| Italy G+A | 9.26 | 0.041 | | | 0 | 0.4083 | 0.4002 | |
| Italy G+S | 9.19 | 0.038 | 7.85 | 0.52 | 0.1404 | 0.4057 | 0.4204 | 3.7 |
| Italy G+S+A | 9.22 | 0.040 | 6.80 | 1.10 | 0.1413 | 0.4139 | 0.3974 | 1.5 |

Targets: participation France 0.203/0.291, Germany 0.252/0.349, Italy
0.116/0.165; hand-to-mouth 0.30, 0.32, 0.41. Germany's two cohesion
configurations sit at the edge of the tolerance (0.311 and 0.312 against 0.32),
and Germany's G+S fits its tertiary cell 0.009 short.

**The same four economies at each country's G+S+A parameters** (the fixed-parameter view: what switching a mechanism does, holding everything else):

| agency (hand-to-mouth) | France | Germany | Italy |
|---|---|---|---|
| G | 0.5375 (0.2635) | 0.5491 (0.2907) | 0.4196 (0.4111) |
| G+A | 0.5283 (0.2685) | 0.5454 (0.2871) | 0.4072 (0.4007) |
| G+S | 0.5083 (0.2984) | 0.5285 (0.3151) | 0.4083 (0.4241) |
| G+S+A | 0.5012 (0.3011) | 0.5252 (0.3109) | 0.3974 (0.4139) |

**What the two views say.**

1. At fixed parameters, cohesion lowers agency by 0.030 in France, 0.021 in
   Germany and 0.011 in Italy, in proportion to how much each country
   participates. The channel is time: participation comes out of paid work,
   saving falls, hand-to-mouth rises and more households fall under the asset
   threshold. Agency heterogeneity lowers agency by 0.009, 0.004 and 0.012,
   in proportion to the gap between the education cells. The two effects add up
   to within 0.003.
2. Recalibrated, the cohesion effect on agency disappears: with every economy
   fitted to the same hand-to-mouth target, the G+S and G+S+A agency figures sit
   within about 0.003 of their no-cohesion counterparts once the residual
   hand-to-mouth differences are allowed for. The agency effect survives:
   0.007 in France, 0.005 in Germany, 0.019 in Italy.
3. Agency moves almost one for one with hand-to-mouth (France's correction took
   hand-to-mouth up 0.021 and agency down 0.019; Italy's, 0.021 and 0.017). It
   is largely an asset-poverty measure, so cross-country agency comparisons are
   mostly hand-to-mouth comparisons and have to be presented as such.
4. Agency heterogeneity roughly halves the social multiplier or more: 4.3
   against 2.0 in France, 10.6 against 2.5 in Germany, 3.7 against 1.5 in
   Italy. Without A, the social mechanism has to produce the whole education
   gradient in participation on its own, which puts it nearer its fold. Any
   policy experiment on participation therefore has to report results with A on
   and off.
5. The multiplier rises with the level of participation across countries (G+S+A:
   Italy 1.5, France 2.0, Germany 2.5), with the relative education gradient
   almost the same in all three (about 0.7).
6. The source of the participation targets moves the multiplier by an order of
   magnitude: France's G+S+A multiplier is 2.0 on EU-SILC volunteering and 21 on
   the INSEE membership targets. The education gradient is what does it.
7. The unemployed participation ratio barely moves any calibration: across the
   four national ratios, sigma moves by at most 0.08 and the multiplier by 0.1.

**The suite at France's new footing: 24 of 24 checks pass.** The 16 reductions
are exact, the replication from the disk cache matches to zero, and seven
convergence rows settle, the largest move in agency 0.0019 (nine productivity
states). A memory stop at five workers restarted the suite on three without loss.

| convergence row | move in agency |
|---|---|
| taste quadrature, 8000 against 2000 | +0.00006 |
| productivity states, 9 against 11 | -0.00186 |
| productivity states, 13 against 11 | -0.00096 |
| choice smoothing halved | -0.00028 |
| asset grid top, 8 against 4 | -0.00020 |
| belonging grid, 0.1 against 0.2 | -0.00001 |
| effort grid, 160 against 80 | -0.00139 |

**Open.** The doubled asset grid row has not run at any footing since the INSEE
one; it needs four to five GB a worker and a machine that can spare three
workers for several hours. The United States is not calibrated. The agency and
belonging gradients and the hand-to-mouth targets are carried over from the old
country table and have not been re-derived; the German unemployed ratio is not
checked in its source document. The G+S hand-to-mouth aim still uses France's
INSEE-footing gap and relied on its one correction for Italy. The acceptable-fit
multiplier ranges without A are wide (Italy 1.4 to 15.6).

# The agency column

Written 2026-09-10. Records what the A dimension of the SAGE dashboard now is,
where each piece of it comes from, what it does under the three policies the
S+A paper already reports, and what is not closed.

Code, all under `SAGE_Bewley/scripts/`:

| file | what it does |
|---|---|
| `agency_core.jl` | the object: the hardship threshold and the cumulative distributions everything is read off |
| `sa_agency.jl` | the driver. With no arguments it runs the stage-5b calibration; with three it runs another point on the omega sweep |
| `agency_gate.jl` | the stationarity identity the aggregate rests on |
| `agency_second_path.jl` | an independent path with no response family and no interpolation |
| `agency_na_check.jl`, `agency_na_pooled.jl`, `agency_na_policies.jl` | the asset grid, per cell, pooled, and on all four policy states |
| `agency_omega_table.jl` | collates the omega sweep |

Logs sit beside each script as `.txt`; the numbers the text below quotes are
in `sa_agency_results.txt`.

## What was missing

Snower and Lima de Miranda (2020, IZA DP 12998, section 3.3) write agency
utility as

    U^a = C * alpha * (1 - p)

with two components they call complementary: alpha, "the ability to influence
one's economic fortunes through one's own efforts", and (1 - p), "freedom from
economic hardship", p being the probability that income falls below a critical
level. The S+A model implemented alpha, as a coefficient on the return to
effort inside the budget constraint, and dropped (1 - p). With only alpha, the
A column is a parameter that policy does not move, so it reports nothing.
Conway (2020), concluding section, proposed the same closure and did not
implement it.

## The hardship event

Their p is static: one period, uniform luck, no wealth. The reason to put it
in a Bewley economy is that wealth is a buffer, so hardship becomes the
failure of the buffer rather than a draw, which is the "ability to regain
financial prosperity" reading of the dimension.

The threshold is the OECD's own, unmodified. Balestra and Tonkin (2018), OECD
Statistics Working Paper 2018/01, paragraph 68: an individual is asset-poor if
they belong to a household with "liquid financial wealth insufficient to
support them at the level of the income poverty line for at least three
months", the income poverty line being 50 percent of the national median
equivalised disposable income. OECD (2025), *Household financial fragility and
asset poverty in OECD regions*, states the same test as financial assets below
25 percent of the national income poverty line.

With the model period a year, the wealth threshold is therefore

    abar = (3 / 12) * 0.5 * median(disposable income) = 0.0515

against a baseline median disposable income of 0.4120. Nothing here is tuned.
The horizon, the fraction, and the poverty line are all the OECD's.

The household object is forward-looking: h(a) = 1{a < abar} is the hardship
indicator and p(a, z) = E[h(a') | a, z] under the household's own next-asset
policy, so a household's agency depends on where its saving decision is taking
it, not only on where it is.

## Why the aggregate is the OECD statistic

For any stationary distribution lambda, sum_lambda p = E[h(a')] = E[h], since
lambda is its own successor. Agency alpha is constant within an education
cell. So

    A_g = alpha_g * (1 - h_g)          exactly,

with h_g the cell's asset-poverty rate. The aggregate of the forward-looking
object is the contemporaneous OECD statistic, computed inside the model. That
is worth having: the A column is directly comparable to a number somebody else
measured, rather than being an index only this model can produce.

It also means the one-year horizon buys nothing at the aggregate. A horizon
that takes the union over several years, which is what the economic-insecurity
literature measures (Osberg and Sharpe 2009; Hacker et al. 2010; Rohde, Tang
and Rao 2014), is a different object and is not implemented.

## What it does

At the stage-5b calibration, kappa 10.00, sigma_m 0.510, omega 0.30, theta
0.005, na 200, ne 80. Every participation rate below reproduces
`sa_level4_results.txt` to four decimals, which the driver checks, because
this layer is accounting and changes no behaviour.

| policy | r (S) | alpha-bar | asset poverty | A | change in A |
|---|---|---|---|---|---|
| baseline | 0.3526 | 0.8380 | 0.4281 | 0.4795 | |
| financed work subsidy | 0.1132 | 0.8380 | 0.3889 | 0.5121 | +0.033 |
| empowerment | 0.4647 | 0.8745 | 0.4263 | 0.5016 | +0.022 |
| participation credit | 0.8491 | 0.8380 | 0.4193 | 0.4872 | +0.008 |

The test the column had to pass was whether it moves under policies that leave
alpha untouched, since otherwise it is decorative. It does. Decomposing the
change exactly into an alpha channel, a hardship channel and their
interaction:

| policy | change in A | alpha | hardship | interaction |
|---|---|---|---|---|
| work subsidy | +0.0326 | 0.0000 | +0.0326 | 0.0000 |
| empowerment | +0.0221 | +0.0208 | +0.0011 | +0.0002 |
| participation credit | +0.0077 | 0.0000 | +0.0077 | 0.0000 |

Three things in that table are worth stating plainly.

**The work subsidy raises agency while collapsing participation.** This was
predicted to go the other way. It does not, and the reason is clear: the
subsidy raises the return to effort and the fall in participation returns the
time lump to work, so earnings rise about seven percent, buffers rise with
them, and asset poverty falls four points. The dashboard therefore shows a
trade-off between two dimensions rather than a policy that loses on all of
them, which is the first thing in this project that a second dimension has
actually bought.

**Empowerment is almost entirely mechanical.** Raising the low cell's alpha
from 0.765 to 0.838 raises A by 0.022, of which 0.021 is the definitional
alpha channel and 0.001 is any reduction in hardship. Low-cell income rises
about six percent and low-cell asset poverty falls 0.6 points, because the
higher return to effort also pulls the cell further into participation, which
costs time. Presenting empowerment as an agency policy would be close to
circular, and the decomposition is the thing that says so.

**The participation credit's agency gain is disequalising, like its take-up.**
Asset poverty falls 1.3 points in the high cell and 0.4 in the low, so the
gap in A widens from 0.089 to 0.098. That is the same incidence the S+A paper
already reports on the participation side, appearing independently on the
agency side.

## External comparison, untargeted

The model's asset-poverty rate on the French cells is 0.428. OECD (2025) puts
France below 40 percent on the same test, with Austria and Denmark below 30,
Canada and Germany at 42 to 44, and Slovenia at 61. Balestra and Tonkin (2018)
Figure 6.1 gives an OECD average of 14 percent income-poor plus a further 36
percent asset-poor but not income-poor. The model is a few points above
France's band and inside the OECD range. Nothing about the wealth distribution
was calibrated to this; the asset grid was scaled to the wealth distribution
and the hand-to-mouth share was matched at 0.32 against 0.30, and the
asset-poverty rate follows from that.

## Robustness

| check | result |
|---|---|
| Participation rates reproduce `sa_level4_results.txt` | all four policies, to four decimals |
| Reading the wealth distribution as a step function rather than interpolating | A moves 0.0007 to 0.0014 |
| Anchored versus floating poverty line | A moves at most 0.002 |
| Threshold horizon 1, 3, 6, 12 months | ordering of the four policies unchanged at every horizon |
| Threshold moved plus and minus ten percent | A moves at most 0.007 |
| Asset grid, na 200 against 400, per cell at seven belonging scales | up to 0.012 in the cell hardship rate |
| Asset grid, na 200 against 400, taste-weighted pool | pooled A moves 0.0020 |
| Asset grid, na 200 against 400, all four policy states | reported differences move at most 0.0019 |
| Independent code path, no family and no interpolation | agency reproduces to 0.0002 |
| Stationarity identity, forward hardship against contemporaneous | holds to machine precision at ten points |
| Private share omega across 0.15 to 0.50, recalibrated at each | all three effects hold their sign |

The anchored line, fixed at the baseline median, is the headline. That is the
standard choice for policy comparison, matching Eurostat's at-risk-of-poverty
rate anchored in time, and it separates a policy's effect on buffers from its
effect on the line. The floating line is reported beside it and moves nothing.

The grid row is the one to watch, because grid scaling has been the recurring
fault in this model. Doubling na moves the cell hardship rate by less than
0.002 at most belonging scales but by 0.012 at one scale sitting in the
participation transition, which is the same near-fold amplification the rest
of the model shows. That per-node figure is larger than the smallest effect
the dashboard reports, the participation credit's 0.008, so it has to be
resolved at the level the dashboard actually quotes, which is the
taste-weighted pool over the whole family rather than any single node.
`agency_na_pooled.jl` rebuilds both baseline families at na = 400 and pools
them at the na = 200 equilibrium rate, isolating the distributional statistic
from any movement in the equilibrium itself. The pooled A moves 0.0020, so the
per-node figure washes out in the taste weighting: the scales where it is
large carry only part of the mass. Against that band the subsidy's 0.033 is a
factor of sixteen, empowerment's 0.022 a factor of eleven, and the
participation credit's 0.008 a factor of four. The first two are safe. The
credit's is real but should be quoted as a small positive rather than to three
decimals. `agency_na_policies.jl` repeats the exercise on all four policy
states, which is the sharper test, since a difference usually survives a grid
better than a level does. It does here, but unevenly:

| policy | change in A at na 200 | at na 400 | movement |
|---|---|---|---|
| work subsidy | +0.0326 | +0.0319 | -0.0007 |
| empowerment | +0.0221 | +0.0222 | +0.0002 |
| participation credit | +0.0077 | +0.0058 | -0.0019 |

The subsidy and empowerment results are converged: they move by a fortieth and
a hundredth of their own size. The participation credit's is not. It moves by
a quarter of its size, so what the model supports is that the credit raises
agency by a small positive amount of order 0.006 to 0.008, and not a figure to
three decimals. That is how it should be quoted.

The identity row is the one the whole construction rests on, so it is checked
rather than assumed. `agency_gate.jl` builds p(a, z) explicitly, household by
household, from the participation mixture and the Young lottery, and compares
its mean with the contemporaneous asset-poverty rate at five belonging scales
in each cell. The two agree to machine precision at all ten points. The second
code path in `agency_second_path.jl` shares nothing with the driver but the
household solver: it draws taste nodes, solves every one of them directly at
its own belonging scale, and pools without any family or interpolation. It
returns agency of 0.4794 against the driver's 0.4795.

The omega row needs care and got it wrong once. Omega, the private share of
the participation payoff, has no point estimate. It does not enter the agency
object at all, but it moves the equilibrium participation rate and so moves
the wealth distribution agency is read off. Sweeping it with kappa and sigma_m
held at their stage-5b values drives the model into a near-zero-participation
equilibrium and produces a spurious sign change in the credit's effect; that
is the same fault as holding a calibration across a solver change, which
Part 1 of `MODEL_READINESS.md` records as one of the three that caused the
stage-4 detour. Recalibrating at each omega, using the pairs in
`sa_omega_l4.txt`, the picture is stable:

| omega | kappa | sigma_m | rate | asset poverty | A | subsidy | empowerment | credit |
|---|---|---|---|---|---|---|---|---|
| 0.15 | 13.00 | 0.760 | 0.3502 | 0.4266 | 0.4808 | +0.0339 | +0.0229 | +0.0071 |
| 0.30 | 10.00 | 0.510 | 0.3526 | 0.4281 | 0.4795 | +0.0326 | +0.0221 | +0.0077 |
| 0.50 | 8.00 | 0.430 | 0.3499 | 0.4287 | 0.4789 | +0.0295 | +0.0238 | +0.0077 |

Baseline agency varies by 0.002 across the range and every effect keeps its
sign and roughly its size. The credit's weakness is the asset grid, not omega:
across omega it sits in a band of 0.0006, and under a doubling of na it moves
0.0019.

The threshold band matters for a second reason. The model's income
distribution is compressed: its median-to-mean ratio is 0.939 against 0.87 in
French data, Eurostat ilc_di03 giving a mean equivalised net income of EUR
30 438 against a median of EUR 26 459 at the latest reference year. So the
poverty line the model generates, and with it the wealth threshold, is on the
high side. A threshold ten percent lower puts
baseline asset poverty at 0.423 rather than 0.428, which is part of why the
model sits a little above the OECD's French band.

## The gate

`MODEL_READINESS.md` Part 7 makes a number quotable when five things hold:
every discretisation it touches is shown converged, it satisfies an identity
an independent formula predicts, a second code path reproduces it, it survives
the parameters that have no point estimate, and it is not a sign against a
threshold that depends on an unidentified parameter.

| | subsidy raises A | empowerment is mechanical | credit raises A |
|---|---|---|---|
| discretisations converged | yes, moves 0.0007 | yes, moves 0.0002 | no, moves 0.0019 on 0.0077 |
| identity | yes | yes | yes |
| second code path | yes | yes | yes |
| survives omega | yes, 0.0295 to 0.0339 | yes, 0.0221 to 0.0238 | yes, 0.0071 to 0.0077 |
| not a sign against a threshold | yes | yes | yes |

So the first two are quotable as stated. The third is quotable as a sign and
as an order of magnitude, that the participation credit raises agency by
something around 0.006 to 0.008, and not as a figure to three decimals.

## What is not closed

**The model has no unemployment state.** Snower and Lima de Miranda's hardship
is triggered by losing your job, and the OECD criterion is stated "in the
absence of income". The productivity process here is a symmetric AR(1) with
rho 0.9 and eta 0.1, so income never falls anywhere near the poverty line and
hardship in this model is a wealth phenomenon rather than an income
phenomenon. Everything above is correct as an asset-poverty calculation and
none of it exercises the income-loss channel the source has in mind. Adding an
absorbing-risk unemployment state is the first extension, and it is the one
that would let the paper use the phrase "if you lose your job".

**No policy in the current set lowers A.** All three raise it. A column that
only moves one way is a weak test of itself, even though the decomposition
shows the movement is real and not mechanical.

**Agency does not enter decision utility.** Snower and Lima de Miranda put
U^a in both the decision objective and experienced wellbeing. Here it is in
experienced wellbeing only, which is why no recalibration is implied. Moving
it into decision utility is a separate step and would force one.

**The column is not yet priced.** The World Happiness Report life-satisfaction
coefficient on "freedom to make life choices", 0.947 against 0.588 on log
income, is the natural price and the WELLBY bridge already has the slot open
for it. U^a is on a zero to one scale, and so is the WHR variable, so the
mapping is available. It has not been wired in.

**Within-cell alpha is constant.** That is what makes the aggregate collapse
exactly. With alpha varying inside a cell, the covariance between alpha and
hardship would matter and the forward-looking object would do work at the
aggregate too.

## Sources

Balestra, C. and R. Tonkin (2018), "Inequalities in household wealth across
OECD countries: Evidence from the OECD Wealth Distribution Database", OECD
Statistics Working Papers 2018/01, OECD Publishing, Paris.

Conway, A. (2020), master's thesis, Sciences Po.

Hacker, J. S. et al. (2010), "Economic Security at Risk", Rockefeller
Foundation.

Lima de Miranda, K. and D. J. Snower (2020), "Recoupling Economic and Social
Prosperity", IZA Discussion Paper 12998; also *Global Perspectives* 1(1).

Eurostat, "Mean and median income by age and sex", table ilc_di03, EU
statistics on income and living conditions.

OECD (2025), "Household financial fragility and asset poverty in OECD
regions", OECD Regional Development Papers, OECD Publishing, Paris.

Osberg, L. and A. Sharpe (2009), "New Estimates of the Index of Economic
Well-being for Selected OECD Countries", CSLS Research Report.

Rohde, N., K. K. Tang and D. S. P. Rao (2014), "Distributional Characteristics
of Income Insecurity in the US, Germany and Britain", *Review of Income and
Wealth* 60(S1).

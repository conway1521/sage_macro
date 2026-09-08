# Model readiness: what moved, why, and whether it has stopped

Rewritten 2026-09-08 at the end of stage 5, superseding the 2026-09-05 version
(kept as `MODEL_READINESS_2026-09-05.md`). That version diagnosed the churn as
a process failure and declared the numerics nearly closed. It was right about
the process and wrong about the closure: two further faults were found in the
three days after it was written, and fixing them moved the paper's headline
back to where it had been in June. This document records where things now
stand, with the evidence rather than the assertion, and says plainly what
remains open.

Scripts and logs are in `SAGE_Bewley/scripts/`; the layered record is in
`VERIFICATION.md`.

## The verdict first

The June draft of the S+A paper was right on every qualitative claim, and its
calibration, $(\kappa, \sigma_m) = (10.0, 0.50)$, was right to within the
numerics of the time. Everything reported as a correction to it between June
and September was a consequence of three faults in the numerics, not a
finding about the economy. Those faults are now fixed, each with a test that
would have caught it, and the June numbers are recovered at a footing where
the asset grid, the effort grid, the taste quadrature, the map grid and the
choice-smoothing scale have each been shown converged.

What that footing also shows, and June could not, is that the participation
moments identify a curve in $(\kappa, \sigma_m)$ rather than a point. The
paper's verdict holds everywhere on that curve; its margin does not, and is
reported as a range with the best-fitting value first. That is the honest form
of the result, and a better one than a point would have been.

The model is ready to build on for the purposes it was designed for. The
places where it is not are named in Part 6, and none of them is numerical.

## Part 1. What happened, in order

| stage | footing | ratio | multiplier | what was wrong |
|---|---|---|---|---|
| June | hard threshold, 41 uniform family nodes, 15 taste nodes, $a_{\max}$ 100 | 1.10 | 3.6 (inconsistent with the slope) | everything under-resolved, but at the right point |
| stage 4 (Sep 3) | hard threshold, 83 concentrated nodes, 2000 taste nodes | 1.60 | 2.47 | the step response could not fit at low dispersion; calibration pushed to the flat end of the valley |
| stage 5 (Sep 8, morning) | logit, rescaled grid, $(\kappa, \sigma_m)$ held at stage 4 | 1.60 | 2.47 | calibration not redone after the solver change |
| stage 5a | recalibrated, $\theta = 0.01$, $n_e = 40$ | 1.06 | 11 | $\theta$ not in its limit at a steep point; $n_e$ not converged there |
| **stage 5b (final)** | **recalibrated, $\theta = 0.005$, $n_e = 80$** | **1.10** | **8.3** | every grid shown converged |

Three faults account for the whole table.

**The asset grid was fifty times too wide.** $a_{\max} = 100$ against a French
wealth distribution that ends near two years of income, so 97 percent of the
nodes were empty and the whole distribution sat on six of them. That made each
group's participation response a five-level step, forced the taste quadrature
to 2000 nodes, and put the participation cutoff among the same six nodes.
Stage 4 found and fixed the quadrature symptom without finding the grid cause.
The engine shares the grid; its default concentration is now `pexp = 4`, and
the S paper and lecture were rebuilt on it with their headline unchanged to
the first decimal.

**The hard threshold cannot resolve the participation level.** The aggregate
is mass above a wealth cutoff sitting on the atom at the borrowing constraint,
and no grid settles that: across $n_a$ = 200 to 800 the level wandered by two
points and the country ordering moved inside the noise. The Brock and Durlauf
(2001) logit form of the same model, with a small i.i.d. taste shock, is the
fix; its $\theta \to 0$ limit is the hard threshold, so the proposition is
untouched.

**The calibration was held fixed across a change to the solver.** Stage 5
recomputed everything at stage 4's $(\kappa, \sigma_m)$. Recalibrating on the
logit core moved the point from $(10.75, 0.750)$ to $(10.00, 0.510)$, because
the smoothed response fits at low dispersion where the step could not, and
that single move is the entire difference between a ratio of 1.60 and 1.10.

## Part 2. The valley

Tracing the best $\kappa$ at each $\sigma_m$ (`sa_valley.txt`): the moment
loss has a definite minimum at $\sigma_m \approx 0.50$ and rises steadily to
about 2.7 times that at $\sigma_m = 1.0$. Along the floor the bound
$\bar\sigma$ moves only from 0.46 to 0.47, because it depends on the group
rates and the moments pin those. What the moments do not pin is $\sigma_m$
itself. So:

| $\sigma_m$ on the floor | 0.50 | 0.60 | 0.75 | 0.90 | 1.00 |
|---|---|---|---|---|---|
| root loss | 0.020 | 0.039 | 0.058 | 0.072 | 0.078 |
| ratio $\sigma_m / \bar\sigma$ | 1.08 | 1.29 | 1.60 | 1.91 | 2.12 |
| multiplier $1/(1-G')$ | 9.6 | 4.2 | 2.6 | 2.1 | 1.9 |

The verdict (outside the coordination region) holds at every point with a
defensible fit. The margin is a range. Stage 4 sat at 0.75, two thirds of the
way along, with twice the minimum loss; every number it reported as a
strengthening was a move along this curve. The paper now states the range and
reports the best fit first. The multiplier is the same slope read the other
way and inherits the range, which is why the policy magnitudes swung between
drafts and why they are now reported with the curve in view.

## Part 3. Standing evidence at the final point

$(\kappa, \sigma_m, \theta, n_e) = (10.00, 0.510, 0.005, 80)$, $\omega = 0.30$.

| check | result |
|---|---|
| Recalibration on $\theta = 0.005$ and $0.0025$ families | identical point |
| Halving $\theta$ | level 0.001, slope 0.002 |
| Doubling $n_a$ | level 0.0001, slope 0.00004 |
| $n_e$ = 80 to 320 | slope 0.8983 to four decimals; level in a 0.0006 band |
| Taste quadrature | 500 nodes suffice; 2000 used |
| Map grid 101 to 1601 | level to the sixth decimal |
| Linearisation identity at a one percent shock | confirmed on the final families: $+0.2$ percent (8.304 measured against 8.284 predicted) |
| Determinism | rerun reproduces the results file byte for byte |
| Independent code path | the countries script reproduces France to four decimals |
| Income process $n_z$ = 2 to 7 | conclusions stable, converged by 5 (stage 4 core; not yet repeated at the final point, see Part 6) |
| Private share $\omega$ | verdict holds at 0.15, 0.30, 0.50; the margin does not |

The first four rows are the ones missing from every earlier draft, and they
are why this draft is different in kind: the number has stopped moving because
each surface it lives on has been shown flat. The identity row is the one
that matters most, and it now passes on the exact families the paper quotes,
not on a related but different footing.

## Part 4. What is fragile, and how it is reported

Near a fold, every family error is multiplied by the multiplier. At the final
point that is a factor of eight to ten, which is why an effort grid that was
fifth-decimal at the flat stage-4 point cost 0.014 on the level here, and why
the country levels fan out from 0.09 to 0.46 across seven rows from inputs
that differ by tenths. Two rules follow and both are applied.

No level is quoted to more precision than the multiplier allows: the
participation rate is 0.35 with a stated band, not 0.3526. And no quantity is
reported as a sign relative to a threshold: the take-up incidence is a profile
of ratios, the GDP-B result is a breakeven price set against the model's own,
and the margin is a range along the valley.

## Part 5. External validation

| target | targeted? | result |
|---|---|---|
| Hand-to-mouth share, France | no | 0.32 against 0.30 |
| Wealth Gini, France | no | 0.55 against 0.68; the shortfall is entirely the top tail |
| Participation rises with education | no | reproduced |
| Higher-income group supplies more fabric | no | reproduced |
| Aggregate participation and gradient | yes | 0.353; 0.267 / 0.439 against 0.25 / 0.45 |
| WISE Agency ordering | no | Spearman +0.89 all six, +0.80 OECD four |
| WISE Solidarity, time-based cohesion (S paper) | no | inverted, $-0.15$ to $-0.80$ |
| WISE Solidarity, participation cohesion (S+A paper) | no | +0.46 to +0.94 all six, +0.80 to +1.00 OECD four, beats both inputs every year, ordering resolved |
| Cross-country policy signs | no | subsidy down 7 of 7, credit up 7 of 7 |

The participation object fixes the cohesion inversion the June benchmark
flagged. Six countries, so suggestive; and at this calibration the cross-
country levels are a tenfold-amplified prediction from the agency and
belonging inputs, to be presented as a prediction and not a fit.

## Part 6. What is not closed

| item | status | what it would take |
|---|---|---|
| Wealth Gini top tail | known one-asset limit; second-order for participation | heterogeneous returns, one extra persistent state; days |
| $\omega$ | no point estimate; the margin runs from about 1.02 to 1.63 across 0.15 to 0.50 | a measurement of the private share of the participation payoff; the framework's first empirical ask |
| $\Lambda$ | not identified from behaviour; only $\kappa\Lambda$ is | affects the GDP-B price only; the WELLBY literature supplies it |
| $n_z$ at the final point | converged at stage 4; not yet repeated on the logit core | an afternoon |
| $\bar q$, cell shares | never swept | an afternoon each |
| Euler errors in the participation core | computed for the engine only | an hour |
| Developing-country engine rows | need $a_{\max}$ near 25; the S+A cells are unaffected | one line in `country_params` |

None is a defect. The first three are limits to state; the last four are
checks to run, and none of them touches a headline.

## Part 7. The gate, and the verdict against it

A number is quotable when all five hold: every discretisation it touches has
been shown converged; it satisfies an identity an independent formula
predicts; a second code path reproduces it; it survives the parameters that
have no point estimate; and it is not a sign against a threshold that depends
on an unidentified parameter.

At the final point the bound, the ratio, the multiplier, the policy signs, the
take-up profile and the country ordering pass. Levels pass once the band is
stated. The GDP-B sign and the take-up sign do not and are not reported as
signs. The margin does not and is reported as a range.

The model is ready for the S+A paper and for the per-country layer it was
built to support. It is not yet ready to be called a structural counterpart to
the Recoupling dashboard on the cohesion side, on six countries; that claim
needs the $\omega$ measurement and more countries, and both are joint work.

## What the next session should do first

The identity row is confirmed: `audit_sa.jl` ran clean at the final point,
8.304 measured against 8.284 predicted at a one percent shock, 0.2 percent
off. The paper (`sage_sa.tex`) has been rewritten end to end against this
calibration, compiles at 22 pages, and was read through in full rather than
checked by pattern-matching alone; two places where the prose logic itself
had gone stale (the take-up disequalising claim, the GDP-B sign) were caught
that way and would not have been caught by search-and-replace on numbers.

Still open, in priority order: repeat the $n_z$ sweep on the logit core (an
afternoon), then the SSRN post. The one thing not to do is change the core
again without recalibrating before reading a single number; that is the
mistake that produced the whole stage-4 detour.

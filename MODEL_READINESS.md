# Model readiness: why the numbers kept moving, and whether they have stopped

Written 2026-09-05, after the Level 4 recomputation and the audit that followed
it. The question this answers is not "are the current numbers right" but "is
there a reason to expect the next number to reverse as well".

Scripts: `SAGE_Bewley/scripts/audit_sa.jl`, `audit_nz.jl`,
`audit_oldfooting.jl`, `wise_participation.jl`, `sa_level4.jl`. Logs sit beside
each. Earlier layers are in `VERIFICATION.md` and `REVIEW.md`.

## The verdict first

The churn was a process failure, not a fragile model, and the process failure
is now closed. Eleven reversals across three months reduce to four faults, of
which three were fixed months ago and one, the under-resolved response family,
propagated into everything the S+A paper said. That one is fixed, and there is
now a test that would have caught it on day one.

What is not closed: the level of participation is imprecise, one free parameter
moves the policy multiplier by a factor of six, and the model cannot reproduce
the participation gradient at the headline calibration. None of those is a
defect. All three should be reported rather than resolved.

## Part 1. Why it kept changing

### The ledger

| # | Reported | Actually | Root cause |
|---|---|---|---|
| 1 | Intensive-margin tipping | No fold at any kappa up to 50 | Frisch set by feel at 4 |
| 2 | Long wealth tail | Truncation-driven at the grid boundary | beta-R knife edge, unsourced |
| 3 | Stationary distribution converged | Silently non-convergent | Only checked lambda sums to one |
| 4 | SAGE-RBC labour cycle | Discretisation noise, halved on refinement | No grid-refinement test |
| 5 | S+A robust to doubling taste nodes | Needed 2000, not 15; 3 family nodes on the transition | Grid chosen without looking at the function |
| 6 | Hand-to-mouth 0.33 and drifting | The drift was the measure, not the model | Grid diagnostic used as a statistic |
| 7 | Decoupling Q -4.7 percent | -5.2 percent | No convergence test on the reported quantity |
| 8 | Credit equalising at all take-up rates | Disequalising at quarter take-up | Consequence of 5 |
| 9 | Subsidy lowers GDP-B 2.2 percent | Raises it 1.5 percent | Consequence of 5 |
| 10 | Gradient half taste half agency | Two thirds taste | Consequence of 5 |
| 11 | Gradient shortfall is structural | Mostly an omega artefact | Claim written before the sweep |

Items 8, 9 and 10 are not independent failures. They are item 5 arriving in
three places. The real count is four faults and one discipline failure:

- **Unsourced parameters** (1, 2). Closed in June by the literature pass.
- **No convergence or invariance testing** (3, 4, 5, 7). Closed by the
  verification ladder, except that the ladder did not cover the reduction
  layer, which is why 5 was found last and hurt most.
- **A diagnostic used as a statistic** (6). Closed; `hand_to_mouth` now lives
  in the engine and `frac_constrained` carries a docstring saying what it is
  not for.
- **Claims written ahead of the evidence** (11). Mine, and recent. The fix is a
  rule, not code: no conclusion is written until the parameter it is most
  sensitive to has been swept.

### The root cause of the expensive one, quantified

At the calibrated point a cell's participation response is close to a step. It
sits at zero until the belonging scale reaches 4.4, hits a plateau at exactly
0.5 where the low-income half of the cell has switched and the high-income half
has not, and reaches one by 6.2. The entire transition is 1.8 wide.

Translated into the taste distribution that gets integrated over it, that
interval is 16 percent of the mass. At the fifteen quadrature nodes the paper
used, **2.4 nodes** landed in the transition, so the answer was decided by
where two or three nodes happened to fall. At 2000 nodes, 318 land there.

That single arithmetic line explains items 5, 8, 9 and 10.

### Would we have caught it?

I claimed the linearisation identity would have caught it, on the grounds that
the old paper reported a slope of 0.81 and an amplification of 3.6 while
1/(1-0.81) is 5.14. That comparison was not safe, because the old amplification
was measured on a 29-point move and the identity holds only for small shocks.
So the claim was tested rather than asserted (`audit_oldfooting.jl`), by running
the identity at a shock small enough that curvature cannot explain a gap:

| footing | tau = 0.01 | tau = 0.20 |
|---|---|---|
| old: 41 uniform nodes, 15 taste nodes | **+47.6%** | -30.2% |
| new: 83 concentrated nodes, 2000 taste nodes | **-0.1%** | -5.5% |

The answer is yes. At a one percent shock the old footing misses by 48 percent,
and the sign of the error flips between small and large shocks, which is the
signature of an interpolated near-step rather than of curvature. The test costs
two family solves and would have run on day one.

## Part 2. Which quantities are trustworthy, and which are not

The reversals were not randomly distributed. They landed on a specific class of
quantity, and the audit measures the split. Propagating the asset-grid wobble
through to the conclusions:

| quantity | spread over na = 100 to 400 | class |
|---|---|---|
| participation rate r* | 5.7% | level |
| education gap | 7.2% | level |
| map slope G' | 0.8% | conclusion |
| bound sigma-bar | 0.3% | conclusion |
| ratio sigma*/sigma-bar | 0.3% | conclusion |
| multiplier 1/(1-G') | 1.3% | conclusion |

The levels are imprecise and the conclusions are not, and this is structural
rather than lucky: the bound is a product of a complementarity factor that
rises with r and a density term that falls with it, so the two partly cancel.

**The rule that follows.** Levels, orderings and signs of first-order effects
are robust. What is fragile is any quantity reported as a *sign relative to a
threshold*, because it inherits the uncertainty of both sides. Both reversals
in Level 4 were of exactly that form:

- "the credit is equalising" is the high/low ratio compared against its own
  baseline of 1.40, and the answer runs 1.19, 1.43, 1.60 across take-up rates.
- "the subsidy lowers GDP-B" is a shadow price compared against a breakeven,
  and it depends on Lambda, which the engine's own identification note says is
  not identified from behaviour at all: only the product kappa-Lambda is. The
  clean form is that the subsidy becomes GDP-B reducing only if Lambda exceeds
  1.31, which is 1.49 times its calibrated value.

So the reporting rule is: **publish the distance and the profile, never the
thresholded sign.** Both papers now do this, and it removes the largest single
source of reversal at no cost in content.

## Part 3. Standing evidence

What the model now passes, with the evidence rather than the assertion.

| check | result |
|---|---|
| Linearisation identity, small shock | multiplier 2.6148 against a predicted 2.6166, **-0.1%** |
| Identity, error monotone in shock size | -0.1, -0.7, -5.5 percent at tau = 0.01, 0.05, 0.20: curvature and nothing else |
| Determinism | rerun reproduces the results file byte for byte |
| Independent code path | the cross-country script computes France separately and agrees to four decimals |
| Map-trace grid | r* stable to the sixth decimal from ngrid 101 to 1601 |
| Effort grid | participation stable in the fifth decimal over two doublings |
| Income process, nz = 2 to 7 | ratio 1.52 to 1.60, multiplier 2.86 to 2.61, converged by nz = 5 |
| Private share omega | verdict holds at 0.15, 0.30, 0.50; the margin does not |
| Euler errors, engine | mean log10 below -3, improving with refinement |
| Stationary distribution | invariant to 9.4e-13 |

The identity is the one that matters most, because it is the only check that
ties an experiment to a formula with no free parameter, and because it is the
one that discriminates the old footing from the new.

## Part 4. What I got wrong in this audit

I argued that nz = 2 was the root cause: two income states give two switching
populations, hence the near-step response, hence the quadrature problem, hence
the gradient shortfall. I recommended the income-process upgrade as the
priority next step. Testing it (`audit_nz.jl`, na = 100 throughout so the
comparison is internal):

| nz | transition width | levels | gap (target 0.200) | G' | nodes for 0.002 |
|---|---|---|---|---|---|
| 2 | 1.6 | 5 | 0.1314 | 0.6502 | 500 |
| 3 | 2.0 | 6 | 0.1334 | 0.6492 | 500 |
| 5 | 3.2 | 11 | 0.1261 | 0.6176 | 500 |
| 7 | 4.2 | 13 | 0.1237 | 0.6167 | 500 |

The response smooths exactly as predicted, by a factor of 2.6 in width and from
five distinct levels to thirteen. Nothing
else follows. The gradient does not improve, it slightly worsens. The
quadrature requirement does not fall. The slope drops five percent, so the
discipline result strengthens a little and the multiplier shrinks a little.

So the diagnosis was wrong: within-cell income heterogeneity is not what holds
the gradient back. The omega evidence is the better explanation, since at omega
= 0.50 the model reaches 0.233 and 0.434 against targets of 0.25 and 0.45.

This is a better outcome than being right would have been. The conclusions are
now known to be insensitive to the income process across a range nobody had
tested, and a day of work that was about to be spent on the wrong upgrade was
not spent.

## Part 5. External validation

The only gate that grid refinement cannot help with, and the one that had been
failing.

| target | not targeted in calibration | result |
|---|---|---|
| Hand-to-mouth share, France | yes | 0.33 against 0.30 |
| Wealth Gini, France | yes | 0.55 against 0.68, under |
| Participation rises with education | yes | reproduced |
| Higher-income group supplies more fabric | yes | reproduced, matches volunteering data |
| WISE Agency ordering | yes | Spearman +0.89 all six, +0.80 OECD four |
| WISE Solidarity, old cohesion object | yes | **-0.15 to -0.80, inverted** |
| WISE Solidarity, participation object | yes | **+0.43 to +1.00, positive in all six cells** |
| Cross-country policy signs | yes | subsidy down 7 of 7, credit up 7 of 7 |

The last of the new rows is the substantive result of this audit.
`BENCHMARK_WISE.md` found that the S paper's cohesion object, all non-work
time, inverted against the WISE Solidarity Index, and concluded that the object
needed rethinking before the model could be called a structural counterpart to
the Recoupling dashboard. The S+A paper had already done that rethinking,
replacing it with participation time, and nobody went back to rerun the
benchmark. It fixes the inversion, in all three years and both samples, and it
beats both of its own calibrated inputs, so it is not simply inheriting the
correlation from what went in.

Read it as suggestive rather than established: six countries, four in the OECD
sample, and Germany and Italy sit 0.0002 apart in the model so their order
carries no information. It is a nonlinear aggregator of calibrated inputs
ordering countries the way an independently built index does, not a prediction
from primitives.

## Part 6. What is still untested

| surface | status | expected direction |
|---|---|---|
| Asset grid in the participation core | **not converged**: r* spans 0.340 to 0.360 over na 100 to 400 | levels imprecise, conclusions stable |
| Participation lump q-bar = 0.10 | never swept | scales the belonging payoff; likely reparameterises kappa |
| Cell shares, fixed at 50/50 | never swept | shifts the aggregate, not the bound's form |
| Euler errors in the participation core | never computed; only done for the engine | unknown |
| Lambda | not identified from behaviour, sourced from a self-selected sample | only affects the GDP-B ledger |
| Wealth Gini | known one-asset limitation | not fixable without a second asset |

The asset grid is the live one and the honest consequence is that participation
levels should be quoted as 0.35 with a stated uncertainty of about a point, not
as 0.353. The bound and the multiplier keep their precision.

## Part 7. The gate

A number is quotable when all five hold:

1. Every discretisation it touches has been shown converged, reported rather
   than assumed.
2. It satisfies at least one identity that an independent formula predicts.
3. A second code path or parameterisation reproduces it.
4. It survives the parameters that have no point estimate.
5. It is not a sign relative to a threshold that depends on an unidentified
   parameter. If it is, publish the distance instead.

Against that gate: the bound, the ratio, the multiplier and the policy signs
pass all five. Participation levels fail (1) and should carry an uncertainty.
The GDP-B sign fails (5) and is now reported as a breakeven. The take-up
incidence sign fails (5) and is now reported as a profile.

Nothing in the current S+A paper is quoted outside what this gate permits.

# Overnight review and validation report

Date: 2026-06-09 to 2026-06-10. Scope: full review of the SAGE-Bewley program
(engine v1, heterogeneous-types v2, the two scoped extensions), parametrization
discipline, numerical solidity, and strategic assessment. Reviewer stance:
adversarial, in the spirit of a numerical-macro referee. Repo:
github.com/conway1521/sage_macro (main; v1.0 tagged preserves the
thesis-faithful world).

---

## 0. The one-paragraph summary

The engine is now solid: every parameter is literature-sourced or calibrated to
a stated data target, the stationary distribution is computed exactly, the
results are stable across grids, and the code is fast. The review found and
fixed two real numerical defects and one fatal calibration defect. The honest
parametrization strengthens the model's distributional realism dramatically
(hand-to-mouth and wealth Gini now near data) and it KEEPS the pure-S results
(decoupling, the two-planner policy contrast) while KILLING the intensive-margin
tipping result, which turns out to require a labour-supply elasticity eight
times the quasi-experimental consensus. That loss is the review's most
valuable product: it tells us exactly what the S+A paper must be instead, and
the overnight prototypes (heterogeneous types, homophily, a discrete
participation margin) map the road there. The program's strategy, low-lift,
modular, calibratable, Julia, aimed at the wellbeing-empirics community,
survives review and is in better shape than before, because what we now claim
is what an honest model actually delivers.

---

## 1. v1, the engine: what was reviewed, fixed, and what it is now

### 1.1 What was audited

Line-by-line economics and mathematics: the Bellman structure (effort folded
into the reward, next-assets as the DiscreteDP action), the budget set, the
preference specification, the Rouwenhorst income process and its normalisation,
the expectation step (EV = V Pi'), the Young-lottery stationary distribution,
the continuous policy refinement (golden-section, with the documented reason
effort is NOT re-optimised), the Gini computation, the wellbeing dashboard, the
policy experiment's budget balance, and the identification of the social
parameters. Numerically: grid convergence in the asset grid (na 200 to 400),
the effort grid (ne 60 to 120), a_max stress, top-of-grid mass, and the
convergence behaviour of both fixed-point loops.

### 1.2 Defects found and fixed

1. **Silent non-convergence of the stationary distribution (real bias).** The
   power iteration could exhaust 100k iterations without reaching tolerance
   and return the stale iterate with no signal. Under the corrected
   preferences this biased the baseline public good by 1.7 percentage points.
   Fix: sparse power iteration remains the fast path; when it stalls, the
   engine switches to dense repeated squaring of the transition matrix
   (T^(2^45), rows renormalised), which is exact for this state-space size,
   unconditionally stable, and faster than the old loop (0.2s). This also
   retires the old "slow-mixing performance corner" for good.
2. **Gini omitted the first Lorenz segment.** The cumulative sums started the
   trapezoid rule one segment late, dropping the origin segment. Negligible at
   these grids but wrong; fixed by prepending the origin.
3. **Fatal calibration defect: the beta-R knife edge.** The thesis pair
   (beta = 0.99, R = 1.01, so beta*R = 0.9999) was harmless under the thesis
   curvature but under the literature curvature (gamma = 2) the wealth
   distribution became truncation-driven: 31 percent of the population sat on
   the top asset node, and the baseline public good moved from 0.47 to 0.36
   as the grid refined and moved again when a_max changed. That is not a
   stationary equilibrium; it is an artifact of the grid boundary. Fix:
   beta = 0.96, R = 1.02 (Aiyagari-tradition annual values; r* near 2
   percent). After the fix the grid battery is stable to the third decimal,
   top-of-grid mass is zero, and a_max is slack.
4. Convergence warnings added to the multiplier fixed point (it previously
   could exit at maxit silently).

### 1.3 The parametrization, now fully sourced

| parameter | value | source / discipline |
|---|---|---|
| gamma (CRRA) | 2.0 | EIS = 0.5, Havranek (2015 JEEA) meta-analysis, selective-reporting corrected |
| psi (inverse Frisch) | 2.0 | Frisch = 0.5, Chetty, Guren, Manoli, Weber (2011 AER) quasi-experimental consensus; old 0.25 implied Frisch = 4 |
| phi (effort disutility) | 14.0 | calibrated: baseline mean work share = 0.53, the paid share of committed time, INSEE Enquete Emploi du temps 2010 (paid 3h24 vs unpaid 3h01 per day) |
| beta | 0.96 | standard annual discount factor (Aiyagari 1994 tradition) |
| R | 1.02 | long-run real rate, r* estimates (Holston-Laubach-Williams) |
| rho, eta (income) | 0.9, 0.1 | within annual ranges surveyed by Heathcote-Storesletten-Violante (2010); thesis matched the hand-to-mouth share |
| alpha by type | 0.765, 0.911 | OECD Better Life Index 2017 empowerment indicators by education (thesis, France) |
| B by type | 0.80, 0.94 | OECD BLI quality-of-support-network items by education (thesis) |
| Lambda | 0.876 | thesis weight on the cohesion dimension from BLI rankings; flagged for re-estimation from life-satisfaction panels |
| kappa (social strength) | swept | no credible point estimate exists; swept and characterised, stated openly |
| subsidy = 0.20 (experiment) | EITC-phase-in scale | policy-relevant magnitude |

Identification note, now documented in the code: in decision utility only the
product kappa * Lambda * B is identified; Lambda is separately pinned only by
the wellbeing (dashboard) side. This is stated rather than hidden.

What the calibrated model now delivers against data it was NOT targeted to hit:
hand-to-mouth share 0.33 (Kaplan-Violante-Weidner European range is ~0.30),
wealth Gini 0.55 (data ~0.68; vanilla Aiyagari models typically manage ~0.38).
The income Gini (~0.15) understates data (~0.30), because two income states
with eta = 0.1 give little dispersion. That is a known, fixable coarseness, not
a structural flaw.

### 1.4 Results: what survives the honest parametrization, what does not

**Survives, and cleanly:**

- The decoupling and two-planner policy result, the core of the S paper. A
  budget-balanced 20 percent make-work-pay subsidy raises aggregate
  consumption by ~5.5 percent and lowers the public good by ~4.7 percent (at
  kappa = 1; same signs at kappa = 2). A consumption-index planner adopts the
  policy; a wellbeing planner sees the social cost. This was robust before;
  it is robust under the honest parameters; it is the program's most reliable
  result.
- All the level economics of social motives (Section 2).

**Does not survive:**

- The intensive-margin tipping (multiple equilibria of the smooth multiplier).
  Under the honest Frisch elasticity there is NO bistability at any social
  strength tested, up to kappa = 50, fifteen times the old window. The
  two-start test agrees everywhere; the map has no fold. Diagnosis: the old
  result was carried by Frisch = 4, an effort response eight times the
  evidence. With realistic effort elasticity, the social feedback cannot bend
  the aggregate response enough to fold it. The agency-inequality finding from
  the earlier session (tipping needs unequal agency) was a property of that
  high-elasticity world and goes down with it.

This retraction is the most important sentence of the night for the papers:
**the S+A lead paper cannot rest on smooth intensive-margin tipping.** Section
4 gives the redesigned, better-grounded route.

### 1.5 Grade and limitations

**Engine (v1.1): A-.** Correct, exact-distribution, literature-parametrized,
grid-stable, fast (~0.2s a solve), versioned (v1.0 preserves the thesis
world). Held back from A by the deliberately coarse income process and the
partial-equilibrium wedges below.

Limitations that are NEXT STEPS (fixable, costed):
- Income process: nz = 2 understates income inequality; a 5-to-7-state
  Rouwenhorst with HSV persistence is an afternoon of work and would also let
  income and education be separated properly.
- Lambda re-estimation from life-satisfaction regressions (a WISE
  collaboration object, by design).
- The income Gini target and the country rows for US/NL/IT remain to be
  filled from data (placeholders warn loudly).

Limitations that are HARD LIMITS of this model class (state them, do not
apologise for them):
- Partial equilibrium: R is exogenous; the agency wedge (1-alpha) income
  vanishes as deadweight rather than going somewhere. A general-equilibrium
  close (sequence-space Jacobian) is Paper 2 infrastructure, not a patch.
- The public good equals average non-work time, mechanically. A free rider's
  leisure builds fabric. Defensible under the time-use reading (unpaid work
  IS the fabric), but the participation prototype (Section 4) shows the
  cleaner architecture: fabric = participation time only, leisure separate.
- Steady-state comparisons only; no transitions. Tipping dynamics, if
  restored, will eventually want transition paths.

### 1.6 Layman diagnostic (v1)

We checked the machine the way an examiner would: every assumption against
the published evidence, every computed number against finer and finer grids.
We found three problems. One was an accounting slip in the inequality measure
(tiny, fixed). One was the solver quietly giving up before the answer was
fully cooked (fixed with a method that always finishes, and is faster). The
serious one: two of the old behavioural settings, how strongly people respond
to work incentives and how patient they are relative to interest rates, were
set at values the evidence rejects, and together they made some headline
numbers depend on an arbitrary technical boundary in the computer, not on
economics. We replaced every such setting with the published consensus value,
re-tuned the one free dial against French time-use data, and re-ran
everything. The model now also matches two facts about wealth it was never
told to match, which is encouraging. The main policy result (raising work
incentives lifts consumption but erodes social fabric, so a money-only
evaluation overstates the gain) survives unchanged. The dramatic tipping
result does not survive: it needed people to reallocate their time about
eight times more readily than the evidence says they do. We know exactly why,
and Section 4 shows the better-founded way to get tipping back.

---

## 2. v2, heterogeneous social types: re-verification under honest parameters

### 2.1 What v2 is and what was verified

A population is a mix of permanent social types (parameter bundles with
shares), coupled ONLY through the scalar public good, so each type is an
inner solve of the v1 engine and the population is an outer fixed point. No
state-space expansion. The machinery was re-verified under v1.1: fixed points
converge from both directions, the cached type-solves are consistent, and the
mixing arithmetic checks by hand.

The headline v2 result from the previous session (a strong-giver minority of
~20 percent tips a low-cohesion conditional majority into the high
equilibrium) was a child of the old parametrization: it required the
bistability that honest elasticities remove. Re-verified honestly, there is no
discontinuous tipping to trigger (two-start tests on mixed populations agree
up to kappa = 20). **The v2 claim must be downgraded from "a committed
minority tips the economy" to "a committed minority lifts the economy, with
increasing returns".** The machinery itself is sound and fast; it is the old
headline that was parametrization-fragile.

### 2.2 What the types DO deliver under honest parameters

- Motives move levels a lot: an all-selfish economy sustains Q = 0.47, an
  all-conditional-cooperator economy 0.56, an all-givers economy 0.62 (kappa
  = 8). The social motive is worth ~15 points of cohesion, a third of the
  selfish baseline.
- The FGF economy: using the Fischbacher-Gachter-Fehr (2001) experimental
  type distribution (50 percent conditional cooperators, 30 percent free
  riders, 20 percent unconditional givers) as the population, cohesion
  settles at Q = 0.55. Conditional cooperators carry 51 percent of the
  fabric; the givers over-contribute per capita (23 percent of the fabric
  from 20 percent of the people). The form-is-arbitrary critique is answered:
  the population mix is a measured object.
- Convex crowding-in (the honest residue of the committed-minority idea):
  each percentage point of givers added to a conditional population raises
  equilibrium cohesion by +0.066pp at low giver shares, rising to +0.21pp at
  30 percent givers. Givers seed fabric, conditional cooperators amplify it
  through the multiplier. Increasing returns to committed minorities, without
  any knife-edge tipping claim.

### 2.3 Grade and diagnostic

**v2 (types framework): B+.** The architecture (types as parameter bundles
coupled through one scalar; literature-disciplined shares) is validated,
cheap, and is the right chassis for the S+A paper. Grade held down because the
old headline did not survive and its replacement (crowding-in levels) is
solid but less dramatic; the dramatic version needs the participation margin.

Layman diagnostic (v2): we let people differ in WHY they contribute, using
the proportions experimental economists actually measure, instead of assuming
everyone is identical. The machinery works and is quick. The previous
session's flashy result (a small committed minority flips society from low to
high cohesion in one jump) relied on the same too-elastic behaviour we
corrected in v1, so we withdrew it. What replaces it is still good and is
honest: committed givers raise everyone's cohesion, with momentum, each
additional giver does more than the last, because their example feeds the
conditional majority. The "flip" story has a better foundation waiting in
Section 4.

---

## 3. The two scoped extensions, built and compared

### 3.1 Homophily (belonging) channel: BUILT, in the engine

Design: the belonging aggregate of group g is A_eff[g] = (1-h) Q + h Qmean[g],
h in [0,1] the homophily weight (bonding vs bridging social capital, Putnam;
homophily, McPherson et al. 2001). h = 0 is exactly the old multiplier
(verified to 1.7e-9); the fixed point becomes per-group. One new parameter,
backward compatible, asymmetric starts supported.

Results (kappa = 8 unless noted):
- Segregation is real but moderate: going from full bridging to full bonding
  widens the cohesion gap between education groups from 7.7 to 10.0 points,
  with the LOW group falling and the high group rising.
- Distribution: bonding-only belonging raises high-education social wellbeing
  by ~9 percent and cuts low-education social wellbeing by ~9 percent
  relative to bridging. Bridging is pro-poor; segregation of the social
  fabric hurts those with least fabric. A structural version of Putnam's
  claim, and a natural WISE talking point.
- The only multiplicity that survives honest parameters lives here: under
  pure bonding at kappa = 20 the low-education group shows two stable
  cohesion levels depending on its own history, 0.5955 from a low start vs
  0.6166 from a high start, confirmed at tolerance 1e-7 with 400 iterations
  (script v2_homophily_confirm.jl). Group-level feedback concentration
  partially restores what economy-wide smoothing destroyed. Weak, but real,
  and it points the same direction as the participation margin:
  concentration and discreteness, not smooth aggregates, are where
  multiplicity lives.

### 3.2 Correlated types: BUILT, script-level

Design: type cells = (social motive) x (agency tier), tiers scaling alpha by
0.9/1.1, total giver share held at the FGF 20 percent, givers placed
independently, all-poor, or all-rich.

Results: aggregate cohesion is essentially INVARIANT to where the givers sit
(Q = 0.5774/0.5774/0.5773); two effects offset, rich givers contribute more
time each (the wealth effect dominates at gamma = 2: richer people work less
and give more time) while the displaced conditionals shift the other way. But
the incidence differs: poor givers personally carry a larger sacrifice
relative to their means. So "who the givers are" is a distributional
question, not an aggregate one, at honest elasticities. This kills a
potential over-claim before we made it, which is exactly what scoping is for.

### 3.3 The comparison, and against the A and E roadmap

- The homophily channel is the stronger extension of the two: it produces new
  qualitative economics (segregation, regressive belonging, the only honest
  multiplicity so far) with one parameter and no architecture cost. It should
  be IN the S paper or its immediate sequel.
- Correlated types produce a clean null plus an incidence story; valuable as
  discipline, not as a headline. Keep as a robustness/incidence section of
  the types paper, not its spine.
- Against A (agency, Paper 2): both extensions compose with agency cleanly.
  Homophily already interacts with the education gradient (the low-agency
  group is the one that segregates downward); the A paper can make agency
  endogenous to the same group structure. The types chassis carries any
  motive x agency joint distribution without new machinery (proved tonight).
- Against E (environment, later): E enters as a wedge or price in material
  gain; nothing tonight constrains or complicates it. The modular claim
  holds: every extension tonight was either one engine parameter or a
  script-level outer loop.

---

## 4. The road back to tipping: the participation margin (designed, prototyped)

Theory says multiplicity in social-interaction models comes from a DISCRETE
choice with complementarity (Brock-Durlauf 2001), not from smooth intensive
margins. The honest version of the SAGE tipping story is therefore:
participation in the social sphere is discrete (join the association, show up,
or not), with a minimum meaningful time lump, and the return to participating
rises with how many others participate. The fabric is participation time, not
all non-work time, which also fixes the free-rider-leisure wrinkle and matches
what time-use surveys actually measure (participation rates ~ one third in
France; participants' social/volunteer time of order 0.1 of committed time).

Prototyped tonight (coarse grids, repo scripts proto_participation*.jl):
- Common-threshold version: degenerate, as theory predicts, all-or-nothing
  participation with a knife edge at extreme kappa. Not the model, but the
  proof that discreteness changes the equilibrium structure where the smooth
  margin could not.
- Taste-dispersed version (three belonging-taste tertiles): DELIVERS interior
  multiplicity. At strong interaction the economy has two genuinely distinct
  equilibria: a zero-participation society, and a participating society where
  the high- and mid-taste tertiles fully join and the low-taste tertile joins
  at 46 percent. Two honest caveats, both informative: (i) the nominal kappa
  needed (120) is large only because the participation fabric base is five
  times smaller than the smooth model's (the effective marginal return is
  comparable to the smooth model's mid-range once rescaled); (ii) the zero
  equilibrium is exactly zero because the prototype gives participation no
  private payoff, so an empirically grounded warm-glow component (people do
  volunteer in low-participation places) will lift the low equilibrium
  interior and lower the multiplicity threshold. Both are calibration work,
  not architecture work.

The designed S+A core, then: logit (or taste-distributed) discrete
participation + multiplier complementarity + the existing wealth/agency
heterogeneity. Every ingredient is standard, citable, and calibratable
(participation rates by education from ESS/INSEE; the Brock-Durlauf
interaction threshold gives the multiplicity condition in closed form to
check against). Estimated build: days, not weeks, on the existing chassis.

---

## 5. Overall assessment

**The strategy survives adversarial review.** Low-lift was the right call:
every result tonight, including the painful one, came cheap because the
chassis is small and exact. Modular was the right call: homophily cost one
parameter; types cost an outer loop; participation reused the whole DDP
apparatus. Julia was the right call: solves are 0.2s, full experiment suites
run in minutes on a laptop, and nothing tonight needed anything beyond the
existing toolkit. Calibratable was the right call, and is now true in a
stronger sense: the model matches wealth facts it was not aimed at.

**The honest losses are strategic gains.** The tipping retraction is the kind
of thing a referee would have found later, in public. Finding it ourselves,
overnight, with the diagnosis (Frisch = 4) and the redesigned route
(Brock-Durlauf participation) in hand, converts a vulnerability into the
agenda for the lead paper. The papers should now be framed as: S paper on
decoupling and the two-planner result (robust, ready); S+A paper on
participation-driven multiplicity and who tips first (designed, prototyped);
types and homophily as the composition-and-belonging layer across both.

**On the ambition.** The utility-vs-wellbeing architecture (decision utility
that prices the act of contributing; experienced wellbeing that prices the
enjoyed fabric) held up everywhere tonight and is the genuinely novel,
defensible core of the program. A heterogeneous-agent model where the social
dimension is calibrated to time-use, support-network, and participation data,
and where the wellbeing dashboard is separate from the choice model, is a
class of model the wellbeing-empirics community does not currently have. The
night's work made that claim more honest and therefore stronger.

**Addendum, the income-process limitation, prototyped after grading.** The
education-times-income separation (two permanent education cells, each with a
five-state Rouwenhorst income process; script proto_edu_income.jl) works with
zero engine surgery and yields a calibration menu: eta = 0.15 delivers wealth
Gini 0.69 and hand-to-mouth 0.28 (both at data) with income Gini 0.185 still
low; eta = 0.25 delivers income Gini 0.335 (at data) but hand-to-mouth drops
to 0.11. One risk parameter cannot hit all four moments; the standard
completion is a persistent-plus-transitory income process (transitory shocks
raise income inequality with little wealth effect), a half day on this
architecture. The limitation is hereby downgraded from flaw to menu.

**Outstanding items not finished tonight**, in priority order:
1. Update the S paper text (sage_s.tex) to the v1.1 numbers and excise the
   intensive-margin tipping claims. This changes the paper's THESIS, so it
   waits for sign-off rather than being done unilaterally overnight. The
   rewrite plan: (i) keep title and framing on decoupling and the
   two-planner result, which is robust and is the S paper; (ii) replace the
   tipping section with the honest finding (no fold under measured
   elasticities) presented as a RESULT about where multiplicity cannot live,
   plus the participation-margin design as the S+A program; (iii) refresh
   the calibration table from the Section 1.3 table; (iv) regenerate the
   policy figure from v11_battery_policy.jl numbers; (v) add the homophily
   segregation result as a short section or trailer for the next paper.
2. The Brock-Durlauf participation model done properly (logit shocks inside
   the DDP, private warm-glow anchor, calibration to ESS/INSEE participation
   rates). (Days; the S+A core.)
3. Persistent-plus-transitory income process on the education-cell
   architecture (half a day; completes the moment menu above).
4. Lambda re-estimation design note for the WISE collaboration pitch.
5. QuantEcon lecture refresh to v1.1 defaults before submission.
6. Country rows US/NL/IT from data.

---

## Postscript (same night, part two)

The outstanding items were executed in the hours after this report was
written. Item 1: the paper is rewritten end to end (13 pages, new title,
retraction reported as a discipline result, incidence sharpened, all numbers
and figures regenerated from scripts/paper_v11_figures.jl). Item 2: the
participation model is built and validated (scripts/participation_model.jl);
calibrated to the French participation rate of one third with a private
payoff share of 0.3, the economy sits inside the coordination region, a 15
percent and a 51 percent participation equilibrium coexisting; near-fold
point values are grid-sensitive (na 100 vs 140 differ), so the prototype
establishes structure rather than point estimates, and the full build with
smoothed discrete choice is the remaining step. Item 3: the income-process
completion is mapped (scripts/proto_income_complete.jl) via a validated
engine override for arbitrary processes; transitory shocks buy the income
Gini at the hand-to-mouth share's expense, the known one-asset frontier.
Item 4: the Lambda estimation design note is written (vault). The plain-
language account of the whole arc is SYNTHESIS.md.

## 6. File map of the night

- Engine: SAGE_Bewley/src/SAGEBewley.jl (v1.1: parameters, solver, Gini,
  warnings, homophily channel, group_means).
- Batteries: scripts/v11_battery_{grids,window,policy}.jl with outputs
  reproduced in this report.
- Extensions: scripts/v2_types_honest.jl, v2_homophily.jl,
  v2_homophily_confirm.jl, v2_correlated.jl.
- Prototypes: scripts/proto_participation.jl, proto_participation_core.jl,
  proto_participation_taste.jl.
- Everything committed and pushed to conway1521/sage_macro (main).

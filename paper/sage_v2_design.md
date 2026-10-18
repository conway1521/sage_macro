---
title: "SAGE, version 2: design note"
subtitle: "A quarterly model with flows consistent with unemployment duration, then two assets. Draft for methods review before building (revision 2)"
author: "Alessandro Conway"
date: "October 2026"
geometry: margin=2.5cm
fontsize: 11pt
linestretch: 1.15
---

**Purpose.** This note sets out the design of version 2 of SAGE before any of it is built, so that problems in the design can be found while they are cheap to fix. Version 1, documented in a separate model note, is a one-asset, annual, partial-equilibrium Bewley economy for France, Germany and Italy, with social participation (S), agency and security (A) and place (E) as switches above a standard base (G). Version 2 keeps the dimensions and changes the base in two steps: a quarterly model whose labour-market flows are consistent with the duration of unemployment, then a second, illiquid asset. Two further changes go with them: dread of job loss with a reference lottery that moves with the household's own search, and a decomposition of the response of job finding to benefits.

This is the second revision. A first review found that the first draft did not identify the two exit rates it relied on, that its decomposition of the benefit response counted liquidity twice, and that its conversion of the income process to a quarter was not a normalisation. A second review found that partner earnings were treated inconsistently across states, that the state space could not carry the entitlement rules, that the quarterly income process was still underidentified, that the duration bands were not mapped to a quarterly model with endogenous search, and that the housing budget counted avoided rent twice and mixed net equity with gross returns. Each is addressed below. Section 8 lists the questions that remain open.

# 1. What version 1 leaves open

Version 1 hits all of its targets in twelve configurations, and its switches return the model without them exactly. Five results are stated as limits.

1. **The fall in consumption on job loss** over a first year out of work is 0.28 to 0.29, about three times the 0.091 that Kolsrud, Landais, Nilsson and Spinnewijn (2018) measure in Swedish registers for those still out of work after 20 weeks. Most of the model's fall is the anticipation of the long-term state.
2. **The long-term state is too persistent.** It is built from household joblessness, which includes inactive adults, and the job-finding rate of the Labour Force Survey, measured among all the unemployed, is assigned to the first year alone. Its share of the out of work is 63%, 83% and 69%, against 25%, 31% and 55% of the unemployed out of work for a year or more (Eurostat `une_ltu_a`, 2023).
3. **The response of job finding to benefits** has no moral hazard within the spell, because with an annual period the first year's benefit is paid whatever the household does. The model's elasticity, $-0.11$ to $-0.31$, nets a liquidity effect against an effect of future entitlement of opposite sign.
4. **The MPC** is in the survey's range but misordered: 0.40, 0.35 and 0.33 in France, Germany and Italy against 0.33, 0.46 and 0.49 in the HFCS.
5. **Median liquid wealth** in France is twice the survey value.

Items 1 and 2 are probably linked: if the long-term state is too persistent, households fear it too much and their consumption falls too far on entering unemployment. A shorter period on its own would leave that untouched, which is why the flows are rebuilt in the same step as the period.

# 2. The observation unit and the employment states

**The unit.** The model's unit is a household with one main earner, whose labour-market state is the household's. Individual flow rates from the Labour Force Survey apply to the main earner. A partner, where present, keeps working in every state of the main earner, and the household's income is the main earner's earnings or benefits plus the partner's earnings. This is implemented through one source for every state out of work: the household-weighted net replacement rates of OECD TaxBEN 2023, month by month up to month 60, for three childless household types (single, a couple whose partner works, a couple whose partner does not) weighted by Eurostat household shares and the measured share of non-working adults whose partner works. Social assistance and housing benefit are included, so the profile covers the months after insurance ends. Version 1 used this profile for the first year and the income of jobless households for the years after, which dropped the partner at the end of the first year. The consistent profile, the mean of months 13 to 60, is 0.49, 0.42 and 0.32 in France, Germany and Italy, against 0.48, 0.51 and 0.44 for version 1's jobless-household income, so the correction lowers income beyond a year in Germany and Italy rather than raising it.

The share of adults in jobless households, a target in version 1, becomes an untargeted test computed with the same mapping: the main earner's non-employment times the share of non-working adults whose partner does not work.

**The states** at a quarterly frequency are:

- E, employed,
- $U^e_1$ to $U^e_8$, unemployed and entitled to insurance, for one to eight quarters,
- $U^n_1$ to $U^n_8$, unemployed and not entitled, for one to eight quarters,
- L, unemployed for nine quarters or more,
- N, inactive.

Entitlement is fixed at entry: households entering unemployment from work are entitled, those entering from inactivity are not, a stated simplification of contribution rules. The eight quarters are tracked one by one (tunnel states), so benefit expiry at the statutory maximum, the pro-rata last quarter, and progression into L are functions of the state. Eight quarters cover the longest statutory insurance duration in the three countries under the rules in force. Beyond them every household receives the post-insurance part of the TaxBEN profile.

**Cost.** The labour states rise from three in version 1 to nineteen. With the 33 income states of version 1 that is 627 states per household type, six times version 1. I pay for it by reducing the persistent income component from 11 to 7 Rouwenhorst states, and I report how the main moments move when it is reduced, on version 1's model, before the change is made.

# 3. Step 1: a quarterly model with flows consistent with duration

Step 1 runs in four stages, each checked and reported before the next, so that the effect of the period and the effect of the flows can be told apart.

## 3.1 Stage 1a: the period, with version 1's flows

Every rate is converted to a quarter. Patience becomes $\beta^{1/4}$ and the return $R^{1/4}$. The income process is **refitted, not converted**. The published annual process, an AR(1) with a transitory shock, implies the variance of annual income and its autocovariances at every lag, $\gamma_0 = \sigma^2_\eta/(1-\rho^2) + \sigma^2_\varepsilon$ and $\gamma_k = \rho^k \sigma^2_\eta/(1-\rho^2)$. The three quarterly parameters (persistence and the two innovation variances) are chosen so that the sums of quarterly income over a year reproduce $\gamma_0$, $\gamma_1$ and $\gamma_2$, with job loss included, using the procedure that already purges the published process of job loss in version 1. Three moments for three parameters close the identification, and $\gamma_3$ is a check. The rule $\rho^{1/4}$ with the unconditional variance kept does not preserve the moments of annual sums, so it is not used.

The check separates two kinds of outcome. Exogenous aggregates must be preserved to the calibration's tolerance: the annual moments of income, the annual equivalents of the flows, and the government's budget. Endogenous household outcomes, such as wealth, the MPC and the fall on job loss, are allowed to move, since households re-optimise four times as often, and they are reported.

## 3.2 Stage 1b: flows fitted to the duration of unemployment

**Why the first draft did not identify the exits.** In an annual model in which everyone in the first-year state leaves it after one period, stationarity of the long-term stock implies $\bar f = (1-h)(1-\iota^U) - h\,\iota^L$, where $\bar f$ is the average job-finding rate, $h$ the long-term share and $\iota$ the exits to inactivity. The two job-finding rates drop out. The average flow and the long-term share are one restriction, not two.

**What identifies them instead.** The stock of the unemployed by duration (Eurostat `lfsa_ugad`). Its bands of less than one month and 1 to 2 months lie inside a first quarter of unemployment, which a quarterly model cannot split, so I merge them. Under the model's timing, in which spells start at the beginning of a quarter and the survey records completed months, every other band begins and ends on a quarter: 3 to 5 months is the second quarter, 6 to 11 the third and fourth, 12 to 17 the fifth and sixth, 18 to 23 the seventh and eighth, 24 to 47 the ninth to sixteenth, and 48 or more the seventeenth onwards. That gives seven bands.

**Job finding with duration and search.** The chance that an unemployed household finds work in a quarter is $\lambda_d\, x$, where $x \in [0,1]$ is its search effort, chosen at cost $k_g x^{1+\gamma_s}/(1+\gamma_s)$ as in version 1, and $\lambda_d$ is the rate at which offers arrive at duration $d$. The arrival rates follow five duration groups (quarter 1, quarter 2, quarters 3 and 4, quarters 5 to 8, and L), the same for both cells, and the cost level $k_g$ is set by cell. The duration profile of exits then has two sources: the arrival rates, and the effort households choose as their entitlement runs down and their savings fall. The exit to inactivity at each duration is a share of the total exit, taken from the quarterly flows (`lfsi_long_q`) and assumed constant across durations, with a sensitivity in which long-term exits lean towards inactivity.

**Fitting in two passes.** First, the hazards are fitted to the bands in a homogeneous duration model, which gives starting values. Second, $\lambda_d$ and $k_g$ are fitted in the solved household model, so that its stationary distribution reproduces the seven band shares and the mean flow from unemployment to work by cell. Selection among survivors is then part of the fit: households who search hard leave early, and the survivors at long durations are those who search less. Band shares up to eight quarters come directly from the stationary distribution over the tunnel states. The split of L between the ninth to sixteenth quarters and the seventeenth onwards needs durations beyond the state space, so I compute it from a simulated panel of households drawn from the solved model. With seven band shares and two mean flows for seven parameters, the fit is exactly identified in this pass, and the jobless-household share, the flows by duration where national surveys publish them, and the bands year by year are its tests.

**The other flows, and which adjust.** Fixing every flow and every stock would over-determine the system, so the rule is explicit. The flows from employment to inactivity, from inactivity to work and from inactivity to unemployment are taken from `lfsi_long_q`. Job loss $\delta_g$ is set so that each cell's unemployment rate (OECD Education at a Glance) holds given the exits, and the entry from inactivity to unemployment is scaled so that the inactivity rate (Eurostat) holds. Where Eurostat publishes durations by education the arrival rates may differ by cell, otherwise the national shape is used.

**Caveats.** The steady-state reading of a duration distribution is biased by cohort effects after large shocks. I therefore average the bands over several years outside recessions and report the fit year by year. Identification is shown, as in version 1, by the Jacobian of the band shares and flows in the parameters.

Search effort (A) applies in every unemployed state, with its cost levels fitted so that the mean chances of moving to work equal the fitted hazards to work. The places of E take their local hazards from the regional LFS where published.

## 3.3 Stage 1c: benefits, entitlement and timing

**Benefits by duration.** Entitled households in $U^e_1$ to $U^e_8$ receive the household-weighted TaxBEN replacement rate of their quarter, the mean of its three months, up to the statutory maximum, with the last quarter paid pro rata where the maximum is not a whole number of quarters. After it, and throughout $U^n_1$ to $U^n_8$ and L, they receive the post-insurance part of the same profile, which carries social assistance, housing benefit and a working partner. The means-tested floor of version 1 applies in every state.

**Timing within a quarter.** Search effort is chosen at the start of the quarter. A household that finds work starts at the beginning of the next quarter and receives the current quarter's benefit in full. Benefits are paid by quarter of unemployment, and search shortens the spell by whole quarters. Spells start at the beginning of a quarter, which is the convention the duration bands are read under.

## 3.4 Stage 1d: recalibration, and the tests

Every configuration is recalibrated on the quarterly model. **A country whose refitted quarterly economy cannot meet the annual base's targets stays annual, and that is stated.**

The tests are built to match their benchmarks' estimands.

- **The fall on job loss**: the model's fall for households still unemployed at 20 weeks, measured over the same horizon as Kolsrud and co-authors' 0.044 and 0.091, and over the spell against their 0.08.
- **The MPC**: the HFCS question asks how much of a windfall of one month's income would be spent within twelve months, so the model's MPC sums the responses of four quarters to the same windfall.
- **The response of job finding to benefits**: Chetty's (2008) hazard elasticity of $-0.53$ for a weekly hazard, converted to a quarterly chance, and the median duration elasticity of 0.53 in Schmieder and von Wachter (2016).
- **The long-term share** of the unemployed, now matched through the duration fit, and the jobless-household share, computed with the partner mapping of Section 2, as an untargeted test.

The fall and its decomposition are reported after each stage, so that the part due to the period (1a), to the flows (1b) and to the benefit profile (1c) can be read separately.

# 4. Step 2: two assets

## 4.1 The asset and its cash flows

The illiquid asset $k$ is **housing equity of the main residence**, and version 2 abstracts from mortgages: a household with equity $k$ is treated as owning outright a dwelling of value $k$. Returns, housing services and the ownership threshold all apply to $k$, so the accounting is internally consistent. The cost of this convention is stated. Leveraged owners earn the unlevered gain on their equity rather than the levered gain on their house, and owners whose equity is below the threshold are classified as tenants, a share I report from the HFCS aggregate tables. Borrowing against housing is left for later. Voluntary pensions are left out, so that the tenure tests are defined.

**Ownership** means $k \ge k_{min}$, with $k_{min}$ fitted to the home-ownership rate given the HFCS distribution of net equity among owners.

**Cash flows.** An owner does not pay rent and receives no cash from the dwelling. Its housing services are consumed in kind, and the benefit of owning is that rent is not paid. A tenant pays rent from income at the measured share of rent in tenants' disposable income. The capital gain $g_k$, by country from the housing returns of Jordà, Knoll, Kuvshinov, Schularick and Taylor (2019), accrues inside the asset. A household that does not adjust has
$$c + b' = (1+r_b)\, b + y - \tau(y) - \text{rent} \cdot \mathbf{1}[k < k_{min}] + \text{transfers}, \qquad k' = (1 + g_k)\, k,$$
and one that adjusts pays the fixed cost $\chi_0$, in units of mean quarterly income, and chooses $k'$ freely:
$$c + b' + k' + \chi_0 = (1+r_b)\, b + (1+g_k)\, k + y - \tau(y) - \text{rent} \cdot \mathbf{1}[k < k_{min}] + \text{transfers}.$$
Tenure in a quarter is set by the asset held at its start, so a household that buys pays rent in the quarter it buys and not after. Households die at rate $1/45$ a year and are replaced by newborn tenants with no housing equity, so that the distribution is stationary (as in Kaplan, Moll and Violante 2018).

## 4.2 Parameters and tests

| parameter | how it is set | source |
|---|---|---|
| capital gain $g_k$ | set from data | Jordà et al. (2019), housing, by country |
| rent of tenants | set from data | Eurostat, rent as a share of tenants' disposable income |
| ownership threshold $k_{min}$ | fitted | home-ownership rate (HFCS 2021) |
| fixed cost $\chi_0$ | fitted | share of wealthy hand-to-mouth (HFCS 2021, the rule of Kaplan, Violante and Weidner 2014) |
| patience $\bar\beta$ and gap $\Delta\beta$ | fitted, as now | hand-to-mouth share and its gap by education |
| | becomes a test | median liquid wealth over income, the MPC, the tenure gap in hand-to-mouth by income |

The solver exists from earlier work: a nested endogenous grid method (Druedahl 2021), with keeping and adjusting combined by a small logit smoothing. Its cash-flow equations are rewritten to the budget above before it is used, and its top-of-grid treatment, repaired in the one-asset solver in version 1, is carried over.

Two assets are the standard route to MPCs of the size the survey reports in Germany and Italy, and they give E housing tenure by place. They may not shrink the fall on job loss, since owners with little cash have little buffer, so the fall is reported whatever it does.

# 5. Dread with a reference lottery that moves with search

**The lottery.** With four kinds of outcome next quarter, dread takes the general form of the expected gain-loss utility of Kőszegi and Rabin (2007) over a lottery:
$$D(s, a', x) = \eta(\lambda-1) \sum_{i<j} p_i(x)\, p_j(x)\, \big|\,\bar u_i(a') - \bar u_j(a')\,\big|,$$
where $i, j$ range over next quarter's employment outcomes (work, continued unemployment at the next duration, inactivity), $p_i(x)$ their probabilities, which depend on search $x$ in unemployed states, and $\bar u_i(a')$ the expected utility of next quarter's consumption in outcome $i$, with income shocks averaged within each outcome. Dread is over employment outcomes, not over income shocks, a stated reduction. With two outcomes the formula is version 1's.

**The reference** is the household's own plan, the choice-acclimating personal equilibrium of Kőszegi and Rabin (2007), with the weight at Pagel's (2017) 1.5. Consumption in each outcome comes from the consumption policy of the previous iteration of the solver, and the solution is accepted only when the policy used inside dread equals the policy it produces, to the solver's tolerance.

**Search** is chosen to maximise the full objective, $\beta\,EV(x) - k x^{1+\gamma_s}/(1+\gamma_s) - D(x)$, which dread can make non-concave. The first-order condition is therefore not solved by bisection. At each node I evaluate the objective on a grid of 101 values of $x$, refine around the best point by golden section, and compare with both boundaries, taking the lowest $x$ in a tie. The brute-force benchmark is extended to this choice.

**Saving.** Dread depends on next period's assets through the consumption policies, so its derivative in $a'$ enters the Euler equation, as dread already does in version 1, using the slope of the previous iteration's policies.

I report results under both specifications, version 1's and this one, for every configuration with A.

# 6. Decomposing the response of job finding to benefits

1. **The permanent change** (the benefit raised in every spell) is split into a **current-spell** change (the benefit raised for the remaining quarters of the spell under way) and a **future-entitlement** change (the benefit raised for spells that start later). At first order the two add up to the permanent change, and for the finite change used the interaction residual is reported so that the accounting is exact.
2. **The comparison with Chetty (2008)** is made the way his estimate is made, not by labelling a residual. Chetty compares the response of durations to severance pay, a lump sum at job loss, with their response to benefits. I compute the same two responses in the model: to a lump sum paid at the start of a spell, and to the current-spell benefit change, both as elasticities at the baseline. Their ratio is the model's counterpart of his liquidity share, and that ratio is the test. I do not call the difference moral hazard, since in this model it also contains the timing of payments, their contingency on remaining unemployed, and their effect on dread.
3. **Dread's part** is shown separately, by repeating both responses with dread off and every other parameter held.

# 7. What carries over, the order, and what stays out

**Carries over unchanged.** S, with the unemployed's own belonging scale fitted to the measured ratio of their participation to the employed's, which version 1 introduced after its review. A's job search with the curvature of DellaVigna, Lindner, Reizer and Schmieder (2017), and hours for those who control them. E's channels and the national financing of places. The floor's tax at the outlay of the economy with S. The wellbeing account with the Green Book bridge.

**Order and checks.** Step 1 (stages 1a to 1d), then Step 2, with the new dread and the decomposition run at the end of Step 1 and again after Step 2. Every step runs the same battery as version 1: exact switches, Euler errors, the brute-force benchmark at the kinks (extended to search with dread, and to the adjustment margin in Step 2), the asset grid's ceiling and density, and a comparison of the modules at fixed parameters beside the refitted configurations. Each step ends with a recalibration and a tag.

**Stays out of version 2.** Prices and wages remain fixed: a labour market in equilibrium (Landais, Michaillat and Saez 2018) is the step after, and transition paths with A follow it (Auclert, Bardóczy, Rognlie and Straub 2021). Housing markets and house prices, migration between places, choosing whether to be in the labour force, contribution histories, and voluntary pensions are not planned.

# 8. Questions for review

1. Is a constant split of exits between work and inactivity across durations acceptable, or should the long-term hazards be split using flows by duration where national surveys publish them?
2. Are arrival rates by duration group, common to both education cells, with effort chosen by households, a defensible way to let selection and duration dependence share the decline of exits with duration?
3. Is abstracting from mortgages, with the stated misclassification of leveraged owners, acceptable for a model whose housing block serves the MPC and the tenure gap, or is collateralised borrowing needed already in version 2?
4. Does the choice-acclimating personal equilibrium suit dread of job loss, where the lottery is partly the household's own search, or would a preferred personal equilibrium, or a reference fixed at the start of the quarter, be more defensible?
5. Should two assets come before the quarterly model, given that the MPC is the gap they address and the quarterly model changes how the MPC is measured?

# References

Auclert, A., Bardóczy, B., Rognlie, M. and Straub, L. (2021). Using the sequence-space Jacobian to solve and estimate heterogeneous-agent models. *Econometrica* 89(5), 2375-2408.

Chetty, R. (2008). Moral hazard versus liquidity and optimal unemployment insurance. *Journal of Political Economy* 116(2), 173-234.

DellaVigna, S., Lindner, A., Reizer, B. and Schmieder, J. (2017). Reference-dependent job search: evidence from Hungary. *Quarterly Journal of Economics* 132(4), 1969-2018.

Druedahl, J. (2021). A guide on solving non-convex consumption-saving models. *Computational Economics* 58(3), 747-775.

Jordà, Ò., Knoll, K., Kuvshinov, D., Schularick, M. and Taylor, A. (2019). The rate of return on everything, 1870-2015. *Quarterly Journal of Economics* 134(3), 1225-1298.

Kaplan, G., Moll, B. and Violante, G. (2018). Monetary policy according to HANK. *American Economic Review* 108(3), 697-743.

Kaplan, G. and Violante, G. (2014). A model of the consumption response to fiscal stimulus payments. *Econometrica* 82(4), 1199-1239.

Kaplan, G., Violante, G. and Weidner, J. (2014). The wealthy hand-to-mouth. *Brookings Papers on Economic Activity*, Spring, 77-138.

Kolsrud, J., Landais, C., Nilsson, P. and Spinnewijn, J. (2018). The optimal timing of unemployment benefits: theory and evidence from Sweden. *American Economic Review* 108(4-5), 985-1033.

Kőszegi, B. and Rabin, M. (2007). Reference-dependent risk attitudes. *American Economic Review* 97(4), 1047-1073.

Landais, C., Michaillat, P. and Saez, E. (2018). A macroeconomic approach to optimal unemployment insurance: theory. *American Economic Journal: Economic Policy* 10(2), 152-181.

McKay, A. and Reis, R. (2016). The role of automatic stabilizers in the U.S. business cycle. *Econometrica* 84(1), 141-194.

Pagel, M. (2017). Expectations-based reference-dependent life-cycle consumption. *Review of Economic Studies* 84(2), 885-934.

Schmieder, J. and von Wachter, T. (2016). The effects of unemployment insurance benefits: new evidence and interpretation. *Annual Review of Economics* 8, 547-581.

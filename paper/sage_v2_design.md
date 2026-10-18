---
title: "SAGE, version 2: design note"
subtitle: "A quarterly model with flows consistent with unemployment duration, then two assets. Draft for methods review before building (revision 1)"
author: "Alessandro Conway"
date: "October 2026"
geometry: margin=2.5cm
fontsize: 11pt
linestretch: 1.15
---

**Purpose.** This note sets out the design of version 2 of SAGE before any of it is built, so that problems in the design can be found while they are cheap to fix. Version 1, documented in a separate model note, is a one-asset, annual, partial-equilibrium Bewley economy for France, Germany and Italy, with social participation (S), agency and security (A) and place (E) as switches above a standard base (G). Version 2 keeps the dimensions and changes the base in two steps: a quarterly model whose labour-market flows are consistent with the duration of unemployment, then a second, illiquid asset. Two further changes go with them: dread of job loss with a reference lottery that moves with the household's own search, and a decomposition of the response of job finding to benefits.

This revision answers a first review of the design. That review found that the first draft did not identify the two exit rates it relied on, that its decomposition of the benefit response counted liquidity twice, and that its conversion of the income process to a quarter was not the normalisation it claimed to be. It also asked for the observation unit, the entitlement rules, the timing within a quarter, the cash flows of the illiquid asset, the link from that asset to housing tenure, and the treatment of a search problem that dread makes non-concave. Each is addressed below. Section 8 lists the questions that remain open.

# 1. What version 1 leaves open

Version 1 hits all of its targets in twelve configurations, and its switches return the model without them exactly. Five results are stated as limits.

1. **The fall in consumption on job loss** over a first year out of work is 0.28 to 0.29, about three times the 0.091 that Kolsrud, Landais, Nilsson and Spinnewijn (2018) measure in Swedish registers for those still out of work after 20 weeks. Most of the model's fall is the anticipation of the long-term state.
2. **The long-term state is too persistent.** It is built from household joblessness, which includes inactive adults, and the job-finding rate of the Labour Force Survey, measured among all the unemployed, is assigned to the first year alone. Its share of the out of work is 63%, 83% and 69%, against 25%, 31% and 55% of the unemployed out of work for a year or more (Eurostat `une_ltu_a`, 2023).
3. **The response of job finding to benefits** has no moral hazard within the spell, because with an annual period the first year's benefit is paid whatever the household does. The model's elasticity, $-0.11$ to $-0.31$, nets a liquidity effect against an effect of future entitlement of opposite sign.
4. **The MPC** is in the survey's range but misordered: 0.40, 0.35 and 0.33 in France, Germany and Italy against 0.33, 0.46 and 0.49 in the HFCS.
5. **Median liquid wealth** in France is twice the survey value.

Items 1 and 2 are probably linked: if the long-term state is too persistent, households fear it too much and their consumption falls too far on entering unemployment. A shorter period on its own would leave that untouched, which is why the flows are rebuilt in the same step as the period.

# 2. The observation unit and the employment states

**The unit.** The model's unit is a household with one main earner, whose labour-market state is the household's. Individual flow rates from the Labour Force Survey apply to the main earner. A partner's earnings enter, as in version 1, through the household-weighted replacement rates of OECD TaxBEN, which include a working partner where one is present. Household income in each state is therefore the main earner's earnings or benefits plus the partner's contribution embedded in those rates, and the share of adults in jobless households, a target in version 1, becomes an untargeted test of this mapping.

**The states** at a quarterly frequency are:

- E, employed,
- $U_1$ to $U_4$, unemployed for one to four quarters,
- $L_1$, unemployed for five to eight quarters, and $L_2$, unemployed for nine or more,
- N, inactive.

Two long-term states serve two purposes. They let the exit from long unemployment fall with duration, which the duration data show, and they carry insurance entitlements that last beyond a year where the statute provides them.

# 3. Step 1: a quarterly model with flows consistent with duration

Step 1 runs in four stages, each checked and reported before the next, so that the effect of the period and the effect of the flows can be told apart.

## 3.1 Stage 1a: the period, with version 1's flows

Every rate is converted to a quarter. Patience becomes $\beta^{1/4}$ and the return $R^{1/4}$. The income process is **refitted, not converted**: the quarterly persistence and the variances of the persistent and transitory innovations are chosen so that the sums of quarterly income over a year have the published variance and first autocovariance of annual income, with job loss included, using the procedure that already purges the published process of job loss in version 1. The rule $\rho^{1/4}$ with the unconditional variance kept does not preserve the moments of annual sums, so it is not used.

The check separates two kinds of outcome. Exogenous aggregates must be preserved to the calibration's tolerance: the annual moments of income, the annual equivalents of the flows, and the government's budget. Endogenous household outcomes, such as wealth, the MPC and the fall on job loss, are allowed to move, since households re-optimise four times as often, and they are reported.

## 3.2 Stage 1b: flows fitted to the duration of unemployment

**Why the first draft did not identify the exits.** In an annual model in which everyone in the first-year state leaves it after one period, stationarity of the long-term stock implies $\bar f = (1-h)(1-\iota^U) - h\,\iota^L$, where $\bar f$ is the average job-finding rate, $h$ the long-term share and $\iota$ the exits to inactivity. The two job-finding rates drop out. The average flow and the long-term share are one restriction, not two.

**What identifies them instead.** The stock of the unemployed by duration (Eurostat `lfsa_ugad`, in bands of less than one month, 1 to 2, 3 to 5, 6 to 11, 12 to 17, 18 to 23, 24 to 47, and 48 months or more). In a steady state, the stock in each band is the inflow times the probability of surviving to that duration, so the shape of the distribution identifies the hazard of leaving unemployment at each duration. I estimate five quarterly exit hazards, constant within their bands: quarter 1 (bands below three months), quarter 2 (3 to 5 months), quarters 3 and 4 (6 to 11 months), $L_1$ (12 to 23 months) and $L_2$ (24 months or more). Eight bands for five hazards leave the fit over-identified, and I report its residuals. The total hazard at each duration is split between work and inactivity by the shares of the quarterly flows (`lfsi_long_q`). The split is assumed constant across durations, a stated assumption with a sensitivity in which long-term exits lean towards inactivity.

**The other flows.** Job loss $\delta_g$, the flows from employment to inactivity, and the flows out of inactivity to work and to unemployment come from `lfsi_long_q`. Stocks of unemployment by education (OECD Education at a Glance) and of inactivity (Eurostat) are matched. Where Eurostat publishes durations by education the hazards are fitted by cell, otherwise the national shape is used, with the cells differing in level so as to match their unemployment rates.

**Caveats.** The steady-state reading of a duration distribution is biased by cohort effects after large shocks. I therefore average the bands over several years outside recessions and report the fit year by year. I will show identification as in version 1, by the Jacobian of the band shares in the hazards.

Search effort (A) applies in every unemployed state, with its cost levels fitted so that the mean chances of moving to work equal the fitted hazards to work. The places of E take their local hazards from the regional LFS where published.

## 3.3 Stage 1c: benefits, entitlement and timing

**Benefits by duration.** $U_1$ to $U_4$ and, where the statute provides it, $L_1$ receive the household-weighted replacement rate of their quarter from the monthly profile of OECD TaxBEN 2023. Entitlement ends at the statutory maximum. A household whose entitlement ends within $L_1$ moves to the long-term income of version 1 (the measured ratio of jobless-household income to other households' income) and to the floor, and $L_2$ receives that income throughout. Where a statutory duration is not a whole number of quarters, the last quarter is paid pro rata.

**Entitlement.** Households entering unemployment from work are entitled. Households entering from inactivity are not, and receive the long-term income and the floor. Both are stated simplifications of contribution rules, which I do not model.

**Timing within a quarter.** Search effort is chosen at the start of the quarter. A household that finds work starts at the beginning of the next quarter and receives the current quarter's benefit in full, so benefits are paid by quarter of unemployment and search shortens the spell by whole quarters.

## 3.4 Stage 1d: recalibration, and the tests

Every configuration is recalibrated on the quarterly model. **A country whose refitted quarterly economy cannot meet the annual base's targets stays annual, and that is stated.**

The tests are built to match their benchmarks' estimands.

- **The fall on job loss**: the model's fall for households still unemployed at 20 weeks, measured over the same horizon as Kolsrud and co-authors' 0.044 and 0.091, and over the spell against their 0.08.
- **The MPC**: the HFCS question asks how much of a windfall of one month's income would be spent within twelve months, so the model's MPC sums the responses of four quarters to the same windfall.
- **The response of job finding to benefits**: Chetty's (2008) hazard elasticity of $-0.53$ for a weekly hazard, converted to a quarterly chance, and the median duration elasticity of 0.53 in Schmieder and von Wachter (2016).
- **The long-term share** of the unemployed, now matched through the duration fit, and the jobless-household share as an untargeted test.

The fall and its decomposition are reported after each stage, so that the part due to the period (1a), to the flows (1b) and to the benefit profile (1c) can be read separately.

# 4. Step 2: two assets

## 4.1 The asset and its cash flows

The illiquid asset $k$ is **housing equity of the main residence**, net of mortgage debt. Voluntary pensions are left out, so that $k > 0$ identifies an owner and the tenure tests are defined. A household owns if its housing equity is at least $k_{min}$, the value of the smallest owned dwelling relative to income, set from the HFCS distribution of main-residence values among owners.

The return on housing has two parts, and the model treats them differently. The **capital gain** $g_k$ accrues inside the asset. The **rental yield** $y_k$ is the rent an owner does not pay, so it frees cash relative to a tenant: owners receive $y_k k$ as a liquid flow and tenants pay rent from income at the measured share of rent in tenants' disposable income. Both rates come by country from the housing returns of Jordà, Knoll, Kuvshinov, Schularick and Taylor (2019), which separate the yield from the gain. The budget of a household that does not adjust is
$$c + b' = (1+r_b) b + y_k k + y - \tau(y) - \text{rent}\cdot\mathbf{1}[k < k_{min}] + \text{transfers}, \qquad k' = (1 + g_k) k,$$
and one that adjusts pays the fixed cost $\chi_0$ and chooses $k'$ freely. Owners cannot borrow against their equity except by adjusting, which stands for refinancing. Households die at rate $1/45$ a year and are replaced by newborn tenants with no housing equity, so that the distribution is stationary (as in Kaplan, Moll and Violante 2018).

## 4.2 Parameters and tests

| parameter | how it is set | source |
|---|---|---|
| capital gain $g_k$, rental yield $y_k$ | set from data | Jordà et al. (2019), housing, by country |
| rent of tenants | set from data | Eurostat, rent as a share of tenants' disposable income |
| minimum owned dwelling $k_{min}$ | fitted | home-ownership rate (HFCS 2021) |
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

The decomposition follows the structure the review proposed.

1. **The permanent change** (the benefit raised in every spell) is split into a **current-spell** change (the benefit raised for the remaining quarters of the spell under way) and a **future-entitlement** change (the benefit raised for spells that start later). At first order the two add up to the permanent change. For the finite change used, the interaction residual is reported so that the accounting is exact.
2. The current-spell change is then split, as in Chetty (2008), into **liquidity** and **moral hazard**. The liquidity part is the response to a lump-sum transfer paid at the start of the quarter equal to the expected discounted value of the current-spell benefit change, using the household's baseline chances of remaining unemployed. The moral-hazard part is the residual.

Chetty's estimate that about 60% of the current-spell response is liquidity is a test of step 2. The future-entitlement effect has no published counterpart and is reported as the model's.

# 7. What carries over, the order, and what stays out

**Carries over unchanged.** S, with the unemployed's own belonging scale fitted to the measured ratio of their participation to the employed's, which version 1 introduced after its review. A's job search with the curvature of DellaVigna, Lindner, Reizer and Schmieder (2017), and hours for those who control them. E's channels and the national financing of places. The floor's tax at the outlay of the economy with S. The wellbeing account with the Green Book bridge.

**Order and checks.** Step 1 (stages 1a to 1d), then Step 2, with the new dread and the decomposition run at the end of Step 1 and again after Step 2. Every step runs the same battery as version 1: exact switches, Euler errors, the brute-force benchmark at the kinks (extended to search with dread, and to the adjustment margin in Step 2), the asset grid's ceiling and density, and a comparison of the modules at fixed parameters beside the refitted configurations. Each step ends with a recalibration and a tag.

**Stays out of version 2.** Prices and wages remain fixed: a labour market in equilibrium (Landais, Michaillat and Saez 2018) is the step after, and transition paths with A follow it (Auclert, Bardóczy, Rognlie and Straub 2021). Housing markets and house prices, migration between places, choosing whether to be in the labour force, contribution histories, and voluntary pensions are not planned.

# 8. Questions for review

1. Is a constant split of exits between work and inactivity across durations acceptable, or should the long-term hazards be split using flows by duration where the national surveys publish them?
2. Is the steady-state reading of the duration bands, averaged over years outside recessions, adequate, or does it need a cohort correction?
3. Is treating the rental yield as a liquid flow to owners (with rent paid by tenants) and the capital gain as accruing inside the asset the right split for the MPC of owners with little cash?
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

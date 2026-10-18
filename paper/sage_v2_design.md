---
title: "SAGE, version 2: design note"
subtitle: "Flows consistent with unemployment duration, a quarterly period and two assets. Draft for methods review before building"
author: "Alessandro Conway"
date: "October 2026"
geometry: margin=2.5cm
fontsize: 11pt
linestretch: 1.15
---

**Purpose.** This note sets out the design of version 2 of SAGE before any of it is built, so that problems in the design can be found while they are cheap to fix. Version 1, documented in a separate model note, is a one-asset, annual, partial-equilibrium Bewley economy for France, Germany and Italy, with social participation (S), agency and security (A) and place (E) as switches above a standard base (G). Version 2 keeps the dimensions and changes the base in three steps, in this order: the flows of the labour market made consistent with the duration of unemployment, a quarterly period, and a second, illiquid asset. Two smaller changes go with them: dread of job loss with a reference lottery that moves with the household's own search, and a decomposition of the response of job finding to benefits. Section 8 lists the questions on which I would most value a reviewer's view.

# 1. What version 1 leaves open

Version 1 hits all of its targets in twelve configurations, and its switches return the model without them exactly. Five results are stated as limits, and the methods review of the version 1 note added two causes I had not stated.

1. **The fall in consumption on job loss** over a first year out of work is 0.28 to 0.29, about three times the 0.091 that Kolsrud, Landais, Nilsson and Spinnewijn (2018) measure in Swedish registers for those still out of work after 20 weeks. Most of the model's fall is the anticipation of the long-term state.
2. **The long-term state is too persistent.** It is built from household joblessness, which includes inactive adults, and the job-finding rate of the Labour Force Survey, measured among all the unemployed, is assigned to the first year alone. Its share of the out of work is 63%, 83% and 69%, against 25%, 31% and 55% of the unemployed out of work for a year or more (Eurostat `une_ltu_a`, 2023). The implied mean stay is 11 to 14 years in Germany.
3. **The response of job finding to benefits** has no moral hazard within the spell, because with an annual period the first year's benefit is paid whatever the household does. The model's elasticity of the first year's chance of finding work, $-0.11$ to $-0.31$, nets a liquidity effect against an insurance effect of opposite sign, against $-0.31$ to $-0.39$ for Chetty's (2008) full response converted to a yearly chance.
4. **The MPC** is in the survey's range but misordered: 0.40, 0.35 and 0.33 in France, Germany and Italy against 0.33, 0.46 and 0.49 in the HFCS.
5. **Median liquid wealth** in France is twice the survey value.

Items 1 and 2 are probably linked, and that is the main reason for the order of the steps below. If the long-term state is too persistent, households fear it too much and their consumption falls too far on entering unemployment. A quarterly period on its own would leave that untouched.

# 2. Step 1: flows consistent with unemployment duration

## 2.1 States

The employment states become four: employed (E), unemployed with a duration below a year (U), unemployed for a year or more (L), and jobless and inactive (N). Version 1 merged L and N. Separating them lets each be fitted to its own data and lets the security motive rest on the risk of long unemployment rather than on the stock of jobless households.

With the quarterly period of Step 2, U is split into four quarters of duration, $U_1$ to $U_4$, so that benefits can follow their statutory profile and search can respond to the remaining duration of insurance. In Step 1, which stays annual, U is one state.

## 2.2 Transitions

The transition matrix between employment states, by education cell $g$, is
$$\Pi_g = \begin{pmatrix} 1-\delta_g-\iota^E_g & \delta_g & 0 & \iota^E_g \\ f^U & 0 & 1-f^U-\iota^U & \iota^U \\ f^L_g & 0 & 1-f^L_g-\iota^L & \iota^L \\ \nu^E_g & \nu^U_g & 0 & 1-\nu^E_g-\nu^U_g \end{pmatrix},$$
with rows and columns ordered (E, U, L, N). The rates are fitted to three sets of official statistics:

- **gross flows** between employment, unemployment and inactivity from the longitudinal Labour Force Survey (Eurostat `lfsi_long_q`, quarterly, and `lfsi_long_a`, annual), converted between frequencies with the correction for time aggregation of Shimer (2012),
- **the duration of unemployment**: the share of the unemployed out of work for a year or more (`une_ltu_a`), by education where Eurostat publishes it and otherwise nationally, with the cells differing by their unemployment rates,
- **stocks**: unemployment rates by education (OECD Education at a Glance) and inactivity rates of the working-age population (Eurostat).

The key identification is between $f^U$ and $f^L$. The LFS flow from unemployment to employment is an average over all durations, $\bar f = (u f^U + l f^L)/(u + l)$, and the long-term share pins down how fast the exit falls with duration. Two moments determine the two rates in each cell. The jobless-household share used in version 1 becomes an untargeted test.

The structure follows the three-state models of gross worker flows (Krusell, Mukoyama, Rogerson and Şahin 2017), with duration added in the manner of McKay and Reis (2016). Inactivity is exogenous in version 2: N households do not search, receive the minimum income or the long-term income share of version 1, and leave N at measured rates. Making participation in the labour market a choice is outside version 2.

## 2.3 What changes elsewhere

Search effort (A) applies in U and L, with its cost levels fitted to $f^U$ and $f^L$ as now. Dread uses the new transition rates. The places of E take their local access to work and long-term share from the regional LFS where published. The base is recalibrated in G, G+S, G+A and G+S+A before Step 2 begins, so that the effect of the flows on the fall in consumption and on the security motive is shown at an annual period first.

## 2.4 Test and stop rule

The test is the fall on job loss and its decomposition at an annual period, before and after the change. If the fall moves little, the persistence of the long-term state was not the cause, and that is reported. The step stops if the four-state flows cannot match the LFS flows, the long-term share and the stocks at the same time in a country. In that case the long-term share takes priority, since it governs the security motive, and the miss on the flows is stated.

# 3. Step 2: a quarterly period

The period becomes a quarter in three stages, each checked before the next. Version 1 contains a probe of the first stage, which shows that the period alone moves the fall over a first quarter to 0.07 to 0.09 and the quarterly MPC to 0.11 to 0.17.

1. **Conversion.** Every rate is converted to a quarter as a stated normalisation, not a calibration. Flows come from the quarterly LFS directly. Persistence of income becomes $\rho^{1/4}$ with the unconditional variance kept, patience $\beta^{1/4}$, the return $R^{1/4}$, and the transitory shock carries four times the per-quarter variance so that a year's average carries the year's. The quarterly economy must keep the annual one's long-run facts within the tolerances of the calibration.
2. **Benefits by quarter of duration.** $U_1$ to $U_4$ receive the household-weighted replacement rate of their quarter, from the monthly profile of OECD TaxBEN 2023, which the first stage averages over a year. Insurance that runs beyond a year moves into L's income where the statute provides it. This is where moral hazard enters: a household searching in $U_2$ weighs the benefit it would receive in $U_3$ if it failed.
3. **Recalibration** of every configuration on the quarterly period.

**Tests.** The fall over a first quarter against Kolsrud's 0.044 for the first 20 weeks, the response of job finding to benefits against Chetty's full $-0.53$ for a weekly hazard converted to a quarterly chance, and the duration elasticity against the median of 0.53 in Schmieder and von Wachter (2016). The quarterly MPC is compared with the survey and with the quarterly estimates the literature reports.

**Stop rule.** A country whose refitted quarterly economy cannot meet the annual base's targets stays annual, and that is stated.

# 4. Step 3: two assets

## 4.1 The household

The household holds liquid wealth $b \ge 0$ with return $r_b$ and illiquid wealth $k \ge 0$, housing and voluntary pensions, with return $r_k > r_b$, adjusted only at a fixed cost:
$$c + b' + k' + \chi_0 \mathbf{1}[k' \neq k] = (1+r_b) b + (1+r_k) k + y - \tau(y) + \text{transfers},$$
following Kaplan and Violante (2014). The fixed cost makes households adjust rarely, which produces the wealthy hand-to-mouth: households with housing and little cash, who spend a large share of a windfall. Households die at rate $1/45$ a year and are replaced by newborns with no illiquid wealth, so that the illiquid distribution is stationary (as in Kaplan, Moll and Violante 2018).

The solver exists from earlier work: a nested endogenous grid method (Druedahl 2021), in which the household chooses each period between keeping $k$ and adjusting it, the keeper's problem is the one-asset problem with $k$ as a state, and the adjuster's is a one-dimensional choice over $k'$ with the keeper's value as continuation. The two branches are combined with a small logit smoothing. Its top-of-grid treatment, repaired in the one-asset solver in version 1, has to be carried over before it is used.

## 4.2 Parameters

| parameter | how it is set | source |
|---|---|---|
| illiquid premium $r_k - r_b$ | set from data | housing returns net of costs in Jordà, Knoll, Kuvshinov, Schularick and Taylor (2019), by country |
| fixed cost $\chi_0$ | fitted | share of wealthy hand-to-mouth (HFCS 2021, the rule of Kaplan, Violante and Weidner 2014) |
| patience $\bar\beta$ and gap $\Delta\beta$ | fitted, as now | hand-to-mouth share and its gap by education |
| | becomes a test | median liquid wealth over income, the MPC, home ownership by income |

## 4.3 What it should change, and what it may not

Two assets are the standard route to MPCs of the size the survey reports in Germany and Italy, and they give E housing tenure by place, which the HFCS shows separates the hand-to-mouth across places in France. They may not shrink the fall on job loss: households rich in housing and poor in cash have little buffer, so the fall could rise for them. The test of the step is therefore the MPC and the tenure gap in hand-to-mouth, with the fall reported whatever it does.

# 5. Dread with a reference lottery that moves with search

In version 1 the lottery a household dreads is set by the measured transition rates, and dread is evaluated at next period's resources. In version 2 the reference lottery is the household's own plan, the choice-acclimating personal equilibrium of Kőszegi and Rabin (2007), and dread is evaluated at next period's consumption, as in Pagel (2017):
$$D(s, a', x) = \eta(\lambda-1)\, q_s(x)\,[1-q_s(x)]\,\big[u(c(a', s^{hi})) - u(c(a', s^{lo}))\big],$$
where $q_s(x) = x$ in searching states and the measured rate elsewhere, and $c(\cdot)$ is next period's consumption policy. The search condition then gains the derivative of dread in $x$:
$$k x^{\gamma_s} = \beta\,[EV_f(a') - EV_s(a')] - \eta(\lambda-1)(1-2x)\big[u(c^{hi}) - u(c^{lo})\big].$$
Dread pushes search towards the extremes. Near $x = 1/2$ its effect is small, and below one half it lowers the marginal value of search, since a higher chance raises the variance of the lottery. In the endogenous grid method the consumption policy of the previous iteration provides $c(\cdot)$, and the search condition is solved at each node by bisection on $x$, since it is no longer in closed form. The weight stays at Pagel's 1.5. I will report the results under both specifications, the version 1 form and this one, for the configurations with A.

# 6. Decomposing the response of job finding to benefits

With the quarterly period, three experiments separate the channels the version 1 review identified, in the spirit of Chetty's (2008) decomposition:

1. **liquidity**: a one-off transfer at the start of a spell equal to the benefit change over the insured duration, with the benefit schedule unchanged,
2. **moral hazard**: the benefit raised in the remaining quarters of the current spell only, with future spells unchanged,
3. **insurance value**: the benefit raised for future spells only, which changes the value of a job relative to remaining out of work.

The permanent change is approximately the sum of the three. Chetty's estimate that about 60% of the response is liquidity becomes a test of the first two.

# 7. What carries over, the order, and what stays out

**Carries over unchanged.** S with the unemployed's own belonging scale fitted to the measured ratio of their participation, which version 1 introduced after its review. A's job search with the curvature of DellaVigna, Lindner, Reizer and Schmieder (2017), and hours for those who control them. E's channels and the national financing of places. The floor's tax at the outlay of the economy with S. The wellbeing account with the Green Book bridge.

**Order and checks.** Steps 1, 2 and 3 in that order, each with the same battery as version 1: exact switches, Euler errors, the brute-force benchmark at the kinks (extended to search, and to the adjustment margin in Step 3), the asset grid's ceiling and density, and a comparison of the modules at fixed parameters beside the refitted configurations. Each step ends with a recalibration and a tag.

**Stays out of version 2.** Prices and wages remain fixed: a labour market in equilibrium, with vacancies, matching and bargaining at a fixed interest rate (Landais, Michaillat and Saez 2018), is the step after. Transition paths with A come after that, by the sequence-space method (Auclert, Bardóczy, Rognlie and Straub 2021). Housing markets, house prices, migration between places, and choosing whether to be in the labour force are not planned.

# 8. Questions for review

1. Is a four-state structure (E, U, L, N) with exogenous inactivity enough to make the security motive credible, or does the persistence problem need a choice of labour-force participation?
2. Is fitting the first-year and long-term exits to the LFS flow and the long-term share the right identification, given that the LFS flow is measured among all the unemployed and the share is a stock?
3. Does the choice-acclimating personal equilibrium suit dread of job loss, where the lottery is partly the household's own search, or would a preferred personal equilibrium, or a reference fixed at the start of the period, be more defensible?
4. Are the three experiments of Section 6 a clean decomposition at a quarterly period, and do they map onto Chetty's?
5. Should two assets come before the quarterly period, given that the MPC is the gap they address and the quarterly period changes how the MPC is measured?

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

Krusell, P., Mukoyama, T., Rogerson, R. and Şahin, A. (2017). Gross worker flows over the business cycle. *American Economic Review* 107(11), 3447-3476.

Landais, C., Michaillat, P. and Saez, E. (2018). A macroeconomic approach to optimal unemployment insurance: theory. *American Economic Journal: Economic Policy* 10(2), 152-181.

McKay, A. and Reis, R. (2016). The role of automatic stabilizers in the U.S. business cycle. *Econometrica* 84(1), 141-194.

Pagel, M. (2017). Expectations-based reference-dependent life-cycle consumption. *Review of Economic Studies* 84(2), 885-934.

Schmieder, J. and von Wachter, T. (2016). The effects of unemployment insurance benefits: new evidence and interpretation. *Annual Review of Economics* 8, 547-581.

Shimer, R. (2012). Reassessing the ins and outs of unemployment. *Review of Economic Dynamics* 15(2), 127-148.

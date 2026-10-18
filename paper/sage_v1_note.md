---
title: "SAGE, version 1: a modular heterogeneous-agent model of material, social, security and place wellbeing for France, Germany and Italy"
subtitle: "Model note, draft for methods review"
author: "Alessandro Conway"
date: "October 2026"
geometry: margin=2.5cm
fontsize: 11pt
linestretch: 1.15
---

**Abstract.** I describe version 1 of SAGE, a one-asset Bewley economy in partial equilibrium, calibrated to France, Germany and Italy, in which three dimensions of wellbeing can be switched on and off above a standard base. The base (G) has incomplete markets, uninsured income risk, job loss with a first insured year and a state of longer joblessness, a means-tested minimum income and hours set by the job. Social participation (S) is a logit choice with a social multiplier. Agency and security (A) adds anticipatory dread of job loss in the sense of Kőszegi and Rabin, costly job search with the curvature estimated by DellaVigna and co-authors, and chosen hours for those who control their working time. Place and environment (E) distributes households across regions or types of place, which differ in access to work, joblessness, commuting and community life, and values air quality in a wellbeing account. Every parameter is either a published estimate read at its source, an official statistic, or fitted to a named moment. Switched off, each dimension returns the model without it exactly. All twelve configurations hit their targets. The model reproduces the liquidity part of the response of job finding to benefits, finds that participation lowers search effort among the unemployed, and shows that the search cost it needs stays below the measured life-satisfaction cost of unemployment. Three gaps are stated rather than forced: the fall in consumption on job loss is two to three times the Swedish register estimate, the response of job finding to benefits is about half the literature's, and the marginal propensity to consume is in range but misordered across countries. Version 2 moves to a quarterly period and two assets.

# 1. Introduction

Most heterogeneous-agent models treat wellbeing as consumption and leisure. The literature on wellbeing beyond income, from the life-satisfaction evidence on unemployment to the measurement frameworks of statistical offices, points to other things that matter: taking part in the life of one's community, security against falls in living standards, and the place one lives in. In my master's thesis I built a Bewley model with these dimensions in a stylised form (Conway 2020). This note documents its first version fit for scrutiny: calibrated to three euro-area economies, with each dimension resting on a declared theory and a published estimate, and with the base reproducing standard macroeconomic facts.

The model is modular by design. G is a standard incomplete-markets economy. S, A and E are switches, and two rules govern them. First, a dimension brings its own theory and parameters and nothing else, and switched off it returns G exactly. Second, each dimension acts through behaviour, through wellbeing, or both, and its strength in each comes from data, never from tuning. Following Lima de Miranda and Snower (2020), each dimension is its own term in household wellbeing, which changes choices where its argument depends on them and changes wellbeing only where it does not.

Version 1 is deliberately limited to one asset and partial equilibrium, in the spirit of the partial-equilibrium analysis in Kaplan and Violante (2014). I would argue that this is the right first step. It lets the household side be checked against micro evidence before prices are endogenised, and it keeps every mechanism legible. Section 8 sets out what version 2 adds and which gaps it is expected to close.

# 2. The base economy (G)

## 2.1 Households

Households live forever and maximise expected discounted utility over consumption $c$ and time use $T$:
$$u(c, T) = \frac{c^{1-\gamma}}{1-\gamma} - \phi \frac{T^{1+\psi}}{1+\psi},$$
with $\gamma = 2$ and $\psi = 1/0.143$, the Frisch elasticity estimated from Swedish lottery winners by Cesarini, Lindqvist, Notowidigdo and Östling (2017, Table 5), which I transfer to the three countries. The weight $\phi$ is fitted (Section 5). Time is $T = (1+\kappa_p)e + \bar q d$, where $e$ is hours of paid work, $\kappa_p$ is commuting time per unit of work in place $p$ (zero nationally), and $\bar q d$ is the time taken by social participation $d \in \{0,1\}$ when S is on, set to measured time use (HETUS 2010).

Households hold one liquid asset $a \ge 0$ with gross real return $R$, the mean real return on overnight household deposits from 2003 to 2021 (ECB MFI interest rate statistics): 0.986, 0.991 and 0.989 in France, Germany and Italy. There are two education cells (below tertiary and tertiary), five permanent income types and, within each cell, one discount factor: $\bar\beta$ for the tertiary cell and $\bar\beta - \Delta\beta$ for the other.

## 2.2 Income and employment

Each household is employed (E), in a first year out of work (U) or beyond a year out of work (L), the three-state structure of McKay and Reis (2016). The employment transition matrix is
$$\Pi_{emp} = \begin{pmatrix} 0 & f & 1-f \\ \delta_g & 1-\delta_g & 0 \\ 0 & f^L_g & 1-f^L_g \end{pmatrix},$$
with rows and columns ordered (U, E, L). The job-finding rate $f$ is the annual flow from unemployment to employment in the Labour Force Survey (Eurostat `lfsi_long_a`, 2023): 0.549, 0.639 and 0.443. Job loss $\delta_g$ is set so that each cell's unemployment rate (OECD Education at a Glance 2023) holds. The exit from the long-term state $f^L_g$ follows in closed form from the share of adults in very-low-work-intensity households by education (Eurostat `ilc_lvhl14n`).

Earnings are $w = \alpha_g z \, \zeta \, e$, where $\alpha_g$ is relative pay by education (Structure of Earnings Survey 2022), $\zeta$ the permanent type and $z$ a persistent AR(1) component with a transitory shock, both by education, from the estimates for each country of Ampudia, Cooper, Le Blanc and Zhu (2024, Table 16 of the working-paper version). Those estimates measure household income including spells out of work, which the model adds separately. I therefore purge them: the standard deviations of the persistent and transitory innovations are re-solved so that model household income, job loss included, has the published variance and first autocovariance, with the persistence kept. The persistent component is discretised on 11 Rouwenhorst states and the transitory one on three.

## 2.3 Government

In the first year out of work a household receives the household-weighted net replacement rate for months 1 to 12 from OECD TaxBEN 2023 (0.72, 0.70, 0.70), of which the state pays the part net of a partner's earnings (0.50, 0.48, 0.47). In the long-term state household income is a share of what the household would earn, the measured ratio of median equivalised income in jobless households to that in other households (Eurostat `ilc_di07`: 0.48, 0.51, 0.44). A means-tested floor tops every household's resources up to the official minimum income, a share of median disposable income (OECD TaxBEN: 0.36, 0.37, 0.40), applied to the model's own median. The state's outlays (the insured part of benefits, the floor) are financed by a proportional tax on labour income that balances the budget.

## 2.4 Hours

In G hours are set by the job, not by the household. Each income state has one level of hours, found in a reference economy without the floor or the transitory shock, at which the household's first-order condition for hours holds on average in that state. The level does not respond to the household's wealth or to policy, which is the point: in most jobs hours are not chosen. Section 3.2 relaxes this for those who control their working time.

# 3. The three dimensions

## 3.1 S: social participation

With S on, each household chooses each year whether to take part in community life. Taking part costs time $\bar q$ and yields a belonging payoff
$$\Lambda\, \kappa\, m\, B_g\, [\omega + (1-\omega) r],$$
where $r$ is the aggregate participation rate, $m$ an idiosyncratic taste drawn from a lognormal with dispersion $\sigma_m$, $B_g$ the measured share of the cell with someone to ask for help (EU-SILC 2015, `ilc_scp15`, normalised to mean one), $\kappa$ the strength of the social technology and $\omega = 0.3$ the part of the payoff that does not depend on others. $\Lambda = 1$ is a normalisation. The choice is logit with a small scale (0.005), in the tradition of Brock and Durlauf (2001). Because the payoff rises with $r$, participation has a social multiplier. The equilibrium is the highest stable crossing of the aggregate participation map with the 45-degree line, found on a grid of 401 values of $r$. Participation among the unemployed is set as a measured multiple of the employed rate (0.56, 0.55, 0.94), since their reported participation reflects more than their choice in the model.

## 3.2 A: agency and security

A has three parts.

**Dread of job loss, in choices.** Following Kőszegi and Rabin (2009) as applied to consumption by Pagel (2017), a household anticipates the coming year's employment lottery. The anticipatory loss is
$$D(s, a') = \eta(\lambda-1)\, q_s(1-q_s)\, [u(Ra' + y^{hi}_s) - u(Ra' + y^{lo}_s)],$$
where $q_s$ is the chance of a change of employment status next year and $y^{hi}, y^{lo}$ are next year's incomes in the two outcomes. The weight $\eta(\lambda-1) = 1.5$ is Pagel's calibration ($\eta = 1$, $\lambda = 2.5$, p. 899), with her structural estimates ($\eta = 1.16$, $\lambda = 3.11$, Table 1) giving 2.45 as the top of a band. Dread falls as savings rise, so it enters the Euler equation and households save partly for peace of mind.

**Job search.** Out of work, a household chooses $x \in [0,1]$, its chance of finding work next year, at utility cost $k_{g,j} x^{1+\gamma_s}/(1+\gamma_s)$, $j \in \{U, L\}$. The curvature $\gamma_s = 0.35$ is the estimate of DellaVigna, Lindner, Reizer and Schmieder (2017, Table I, column 1) in the standard model with savings. Each searching state's row of the transition matrix is split into its part towards work and the rest, which the chosen $x$ reweights:
$$x^* = \min\left\{\left(\frac{\beta\,[EV_f(a') - EV_s(a')]}{k}\right)^{1/\gamma_s}, 1\right\}.$$
The four cost levels per country (two cells, two states) are fitted so that the mean chances equal the measured $f$ and $f^L_g$. The response of job finding to benefits is then an untargeted test (Section 7.2).

**Hours for those who control them.** A share of each cell chooses its hours freely: the measured share of employed people who can fully decide when their working day starts and ends (Eurostat `lfso_19fxwt01`, 2019: 0.15 and 0.25 in France, 0.16 and 0.31 in Germany, 0.15 and 0.19 in Italy). On the floor such a household works zero hours unless working lifts it above the floor and is worth more.

## 3.3 E: place and environment

With E on, the economy is a set of places, either the OECD TL2 regions (14 in France, 16 in Germany, 21 in Italy) or the three types of place of the degree of urbanisation. Places share national parameters and differ only through measured channels: the education composition, access to work (the flow into employment and the unemployment rate), the share of jobless households (which sets the exit from the long-term state locally), commuting time (types of place only) and community infrastructure, which scales the independent part of the belonging payoff with an elasticity of 0.4. Taxes and the floor are financed nationally. Households do not move between places in version 1. With every place identical, the place economy reproduces the national one to about $10^{-11}$.

## 3.4 What is not in the base, and why

Two channels were built and left out by rules set before the results. A conversion channel (a place's income per head entering resources) broke the order of regional poverty in France and stays an option. Housing tenure, which separates the hand-to-mouth by place in the HFCS, needs two assets and waits for version 2. The cost of being out of work beyond the income lost (Section 4) was built as a term in choices and tested. At its life-satisfaction size it lowered the response of job finding to benefits to a third or a half of even the liquidity part of the evidence. I count it in wellbeing only.

# 4. The wellbeing account

The account reports, per head and per year, what each dimension's own term is worth, in life-satisfaction points on the 0 to 10 scale and as a share of consumption. One bridge serves every term: the HM Treasury (2021) supplementary Green Book guidance, under which a share $x$ of income lost is worth $\beta_Y \ln(1-x)$ points with $\beta_Y = 1.961$. Terms that come from the model are turned into points, and terms that come from the evidence are turned into shares.

| term | dimension | value | source |
|---|---|---|---|
| dread of job loss | A | model consumption equivalent, those in work | model |
| out of work beyond income | A | the ESS gap at the same income decile, 1.05 to 1.06 points; 0.8 as a low end | ESS rounds 6, 7, 10, 11; Clark, Knabe and Rätzel (2010) |
| of which: job search | A | model consumption equivalent, those out of work | model |
| taking part | S | 0.055 to 0.081 points per participant | Meier and Stutzer (2008), fixed effects |
| air quality | E | 0.3% to 0.8% of income per µg/m³ of PM2.5 above 5 µg/m³ | Menz and Welsch (2010); OECD regional PM2.5; WHO (2021) |
| commuting | E | check only: already a time cost in the model | Stutzer and Frey (2008) |

The life-satisfaction gap of the unemployed is measured among those looking for work, so it includes the strain of searching. The account therefore shows the gap as the whole cost of being out of work beyond income, with the model's search cost as a part of it. The terms are not summed: weights across dimensions are a later step, for which I plan to use the Better Life Index users' own rankings by country.

# 5. Calibration

Table 1 lists what is set directly from official statistics or published estimates. Table 2 lists what is fitted, and to which moment. The household moments come from the Eurosystem Household Finance and Consumption Survey, wave 2021, for households not in retirement, used only as aggregate tables.

**Table 1. Set from data (France, Germany, Italy).**

| | FR | DE | IT | source |
|---|---|---|---|---|
| job finding $f$ | 0.549 | 0.639 | 0.443 | Eurostat `lfsi_long_a`, 2023 |
| exit from long-term state $f^L$, by cell | 0.216, 0.685 | 0.071, 0.093 | 0.250, 0.247 | closed form from `ilc_lvhl14n` |
| replacement rate, first year (household; state) | 0.72; 0.50 | 0.70; 0.48 | 0.70; 0.47 | OECD TaxBEN 2023 |
| long-term income over others' | 0.48 | 0.51 | 0.44 | Eurostat `ilc_di07` |
| minimum income, share of median | 0.36 | 0.37 | 0.40 | OECD TaxBEN 2023 |
| gross real return | 0.986 | 0.991 | 0.989 | ECB MIR, 2003 to 2021 |
| control over working time, by cell | 0.15, 0.25 | 0.16, 0.31 | 0.15, 0.19 | Eurostat `lfso_19fxwt01` |
| Frisch elasticity | 0.143 | 0.143 | 0.143 | Cesarini et al. (2017), transfer |
| dread weight $\eta(\lambda-1)$ | 1.5 | 1.5 | 1.5 | Pagel (2017) |
| search curvature $\gamma_s$ | 0.35 | 0.35 | 0.35 | DellaVigna et al. (2017) |
| income process | by education | | | Ampudia et al. (2024), purged |

**Table 2. Fitted, and to what.**

| parameter | moment | configurations |
|---|---|---|
| hours weight $\phi$ | mean paid-work share of the employed (HETUS 2010) | all |
| patience $\bar\beta$ | hand-to-mouth share (liquid wealth below a week of income; HFCS) | all |
| patience gap $\Delta\beta$ | hand-to-mouth gap between education cells (HFCS) | all |
| permanent types $\zeta$, weights | official income deciles and top share (Eurostat `ilc_di01`) | G, read by the others |
| social technology $\kappa$, dispersion $\sigma_m$ | formal volunteering by education (EU-SILC 2015, `ilc_scp19`) | G+S, G+S+A |
| search costs $k_{g,U}, k_{g,L}$ | mean job finding, first year and beyond, by cell | G+A, G+S+A |

The hand-to-mouth share follows Kaplan, Violante and Weidner (2014) in counting liquid wealth (sight accounts and directly held securities) below a week of annual income. Median liquid wealth over income and the survey MPC are not targeted, and serve as tests. Each configuration is fitted to its own targets, so G+A and G+S+A refit $\phi$, $\bar\beta$ and $\Delta\beta$ with dread and search on, and G+S+A refits $\kappa$ and $\sigma_m$ as well. Search costs are fitted by a secant in logs at the configuration's calibration, and the calibration is then repeated with them. The cycle stops when the mean chances are within 0.005 of the measured rates at the final calibration. In G+S+A the participation equilibrium is held while the costs are fitted, and the chances are averaged over the belonging scales the equilibrium assigns.

Identification is shown by the Jacobian of the targets in the fitted parameters. In G the condition numbers are 5.0, 3.1 and 4.1, and each parameter moves its own moment most. The social technology is the weakest part: in France the condition number of the S block is 23, which is why I report the social multiplier as a band (1.2 to 1.4) rather than a point.

**Table 3. Fitted values, G+S+A with dread and search.**

| | $\phi$ | $\bar\beta$ | $\Delta\beta$ | $\kappa$ | $\sigma_m$ | $k_U$ by cell | $k_L$ by cell |
|---|---|---|---|---|---|---|---|
| FR | 62.5 | 0.935 | 0.077 | 7.75 | 1.72 | 8.76, 4.23 | 10.56, 3.34 |
| DE | 98.7 | 0.965 | 0.053 | 11.60 | 1.60 | 11.68, 11.10 | 18.19, 16.50 |
| IT | 22.0 | 0.960 | 0.086 | 3.65 | 1.80 | 8.77, 10.98 | 9.99, 12.29 |

*Italy's G+S+A is from the round before its last refit of search costs, with chances within 0.006 of the measured rates. The final round is running.*

# 6. Numerical method and verification

The household problem is solved by the endogenous grid method (Carroll 2006), with the labour margin handled as in Barillas and Fernández-Villaverde (2007) and the non-concavities from the participation choice, the floor and chosen hours handled by an upper envelope in the manner of Iskhakov, Jørgensen, Rust and Schjerning (2017). Points on the floor have zero marginal value of assets. The asset grid has 200 exponentially spaced points up to four years of mean income. Past the last endogenous point, next period's assets stay at the top of the grid and consumption and hours come from the budget there. Value iteration stops on the MacQueen (1966) and Porteus (1971) bounds at $10^{-9}$. Where the floor makes the iteration cycle, the step is relaxed and a residual below $10^{-2}$ is accepted and logged. The stationary distribution uses the lottery method of Young (2010). With S on, each household problem is solved on 83 belonging scales and the equilibrium mixes them.

Verification has five parts.

1. **Exact switches.** With S off, participation is below $10^{-4}$ and no belonging enters welfare. With every place identical, E reproduces the nation to about $10^{-11}$. The budget balances to $10^{-12}$ or better without S and to 0.05% of mean income with S. These checks pass in every configuration and country but one. The tax that pays for the floor is set in the economy without S, so with S on a small gap is allowed, and in Germany's G+S+A it is 0.06% of mean income, just over that allowance, because job search changes who reaches the floor.
2. **Euler errors.** Over 40 problems, the mean error lies between $10^{-4.9}$ and $10^{-6.4}$ and the worst point between $10^{-2.2}$ and $10^{-2.6}$.
3. **Brute force at the kinks.** For households who choose hours under the floor, plain value iteration on 1,500 asset points, with full search over next assets, hours refined by golden section and the floor as an explicit option, is compared with the fast solver against pass rules set before the runs. On-floor status agrees for all of the mass in every problem, and hours agree within 0.3%. One problem in Italy failed on consumption and value at the top of the asset grid, and passes 4 of 4 after the repair described above. The benchmark is still to be extended to search.
4. **Grid.** Doubling the asset grid moves the national moments within tolerance where it has been run. With S on in France and Italy it did not finish within the runner's six-hour limit.
5. **One stable equilibrium.** The participation map has one stable crossing in every country where it was checked. Italy's G+S+A check did not finish.

# 7. Results

## 7.1 Fit and untargeted moments

**Table 4. G+S+A with dread and search, against data.**

| | FR model | FR data | DE model | DE data | IT model | IT data |
|---|---|---|---|---|---|---|
| hand-to-mouth (target) | 0.269 | 0.268 | 0.252 | 0.252 | 0.203 | 0.203 |
| participation, below tertiary (target) | 0.203 | 0.203 | 0.252 | 0.252 | 0.116 | 0.116 |
| participation, tertiary (target) | 0.291 | 0.291 | 0.349 | 0.349 | 0.165 | 0.165 |
| median liquid wealth over income | 0.095 | 0.047 | 0.115 | 0.117 | 0.214 | 0.229 |
| MPC, one month's income | 0.397 | 0.331 | 0.345 | 0.464 | 0.326 | 0.486 |
| fall in consumption, first year out of work | 0.291 | about 0.10 | 0.277 | about 0.10 | 0.291 | about 0.10 |

*Data: HFCS 2021 (households not in retirement), EU-SILC 2015, Kolsrud, Landais, Nilsson and Spinnewijn (2018) for Sweden.*

Median liquid wealth, which is not targeted, is close in Germany and Italy and twice the survey value in France. The survey MPC asks how much of a windfall of one month's income would be spent within a year. The model is in the range of the survey in all three countries but misorders them, too high in France and too low in Germany and Italy.

The fall in consumption over a first year out of work is the clearest miss. The European benchmark is Kolsrud and co-authors (2018), who measure total consumption in Swedish registers at a replacement rate of 72%: 0.044 in the first 20 weeks, 0.091 after 20 weeks and about 0.10 in a second year. The model's fall is two to three times larger. A decomposition shows where it comes from. With the first year fully insured, 0.21 to 0.22 remains with dread, against 0.12 to 0.13 without it, so most of the fall is the anticipation of the long-term state, which dread makes households fear more. A probe that converts every rate to a quarter, with nothing refitted, lowers the fall over a first quarter to 0.07 to 0.09. That is still about twice Kolsrud's 0.044, so the annual period explains part of the gap but not the factor of two.

## 7.2 Job search

With costs fitted to the measured rates, I raise the first year's benefit by 10%, hold the tax, and measure the response of the first year's chance of finding work. The elasticity is $-0.23$ and $-0.30$ in France (by cell), $-0.17$ and $-0.11$ in Germany, and $-0.14$ and $-0.17$ in Italy. The literature's median duration elasticity is 0.53 (Schmieder and von Wachter 2016), and Chetty (2008) estimates a hazard elasticity of $-0.53$, of which about 60% is a liquidity effect (p. 217). Converted from a weekly hazard to the chance of finding work within a year at the measured rates, the full response is $-0.35$, $-0.31$ and $-0.39$, and its liquidity part $-0.21$, $-0.18$ and $-0.23$.

The model holds the liquidity part only, and the reason is structural. With an annual period, the first year's benefit is paid in the year whose search it would change, so the household receives it whatever it does. Raising it leaves the reward to searching unchanged and acts only through the buffer carried into the next year. Against the liquidity part, France is at or above it and Germany and Italy are at 60 to 90% of it. The moral hazard part needs the insured spell split into periods, which is the first change of version 2. Search itself moves the economy little, as it should when the mean rates are held: the fall on job loss changes by at most 0.003, and hand-to-mouth falls by about 0.01 in Germany and Italy.

## 7.3 Interactions

Two interactions follow from the design without new parameters. First, with S on, households out of work search less. In Germany the mean chance chosen by the lowest permanent type below tertiary falls from 0.042 with S off to 0.022 at any positive belonging scale, and for the same type with tertiary education from 0.92 to 0.84. Taking part, for which the unemployed have more time, makes being out of work less bad, so the reward to finding work is smaller. To give the measured rates, Germany's search costs in G+S+A are 7 to 17% lower than in G+A. In France and Italy the effect is small and the costs differ by under 2%. Second, dread differs by place because job loss and the long-term state do, so security is unequal across regions even where incomes are not.

## 7.4 The wellbeing account

**Table 5. Wellbeing account, G+S+A (points per head per year; share of consumption in brackets).**

| term | France | Germany |
|---|---|---|
| A: dread of job loss | $-0.027$ (0.014) | $-0.015$ (0.008) |
| A: out of work beyond income (ESS gap 1.06) | $-0.101$ (0.040) | $-0.106$ (0.042) |
| of which: job search | $-0.071$ (0.030) | $-0.043$ (0.020) |
| of which: the rest | $-0.030$ (0.014) | $-0.062$ (0.027) |
| S: taking part (0.055 to 0.081 a participant) | $+0.016$ | $+0.019$ |
| E: air quality, central (band 0.3 to 0.8%) | $-0.049$ (0.025) | $-0.058$ (0.029) |

*Italy follows at the release.*

The job search cost the model needs to give measured job finding is worth 0.74 points a person out of work in France and 0.44 in Germany. Both lie below the measured gap of about 1.06, a test the model could have failed. The air-quality term is sizeable relative to the others, because exposure to PM2.5 lies above the WHO guideline for everyone, but at a band of a factor of 2.7 it is also the least precise.

# 8. Limits and version 2

**Stated limits of version 1.**

1. The fall in consumption on job loss is two to three times the Swedish register estimate.
2. The response of job finding to benefits contains the liquidity part only.
3. The MPC is in range but misordered across countries.
4. Median liquid wealth in France is twice the survey value.
5. Wages, job finding and the interest rate are fixed (partial equilibrium). Policies with A are comparisons of steady states, not paths.
6. Households do not move between places, and housing tenure is absent.
7. Germany's community channel has no regional infrastructure source and stays national. The community elasticity is estimated on Italy.
8. The social multiplier is a band, the Frisch elasticity a transfer from Sweden, and the cost of being out of work is valued at mean income.
9. The brute-force benchmark does not yet cover search.
10. G+S+A solves take one and a half to three and a half hours, and Germany's household problems sometimes end on the relaxation rule at the floor.

**Version 2.** The first change is a quarterly period, in three steps, each checked before the next:
1. Every rate converted to a quarter, and the quarterly economy shown to keep the annual one's facts.
2. A first year out of work lasting four quarters.
3. A recalibration.

A country that cannot be refitted quarterly stays annual, and that is stated. This should bring in the moral hazard part of the response of job finding, put the MPC on the horizon of the quarterly literature, and shrink the fall on job loss.

The second change is two assets, liquid wealth and housing, in the manner of Kaplan and Violante (2014). Owners and tenants appear, along with households who own a house but hold little cash. This is the standard route to MPCs of the size the survey reports in Germany and Italy, and it gives E housing tenure by place. It may not shrink the fall on job loss, since households rich in housing and poor in cash have little buffer, so that gap may remain the one version 2 does not close.

After version 2 come a labour market in equilibrium, with job finding from vacancies and matching and wages from bargaining at a fixed interest rate (Landais, Michaillat and Saez 2018), transition paths through every dimension by the sequence-space method (Auclert, Bardóczy, Rognlie and Straub 2021), and weights across dimensions from the Better Life Index.

# Data

This paper uses data from the Eurosystem Household Finance and Consumption Survey. Results are aggregates, and cells with fewer than 30 unweighted households are suppressed. Other data are official statistics from Eurostat, the OECD and the ECB, and the European Social Survey (rounds 6, 7, 10 and 11, aggregates only). Code: github.com/conway1521/sage_macro.

# References

Ampudia, M., Cooper, R., Le Blanc, J. and Zhu, G. (2024). MPC heterogeneity and the dynamic response of consumption to monetary policy. *American Economic Journal: Macroeconomics* 16(3). Table 16 read in the working-paper version, BIS Working Paper 1102.

Auclert, A., Bardóczy, B., Rognlie, M. and Straub, L. (2021). Using the sequence-space Jacobian to solve and estimate heterogeneous-agent models. *Econometrica* 89(5), 2375-2408.

Barillas, F. and Fernández-Villaverde, J. (2007). A generalization of the endogenous grid method. *Journal of Economic Dynamics and Control* 31(8), 2698-2712.

Brock, W. and Durlauf, S. (2001). Discrete choice with social interactions. *Review of Economic Studies* 68(2), 235-260.

Carroll, C. (2006). The method of endogenous gridpoints for solving dynamic stochastic optimization problems. *Economics Letters* 91(3), 312-320.

Cesarini, D., Lindqvist, E., Notowidigdo, M. and Östling, R. (2017). The effect of wealth on individual and household labor supply: evidence from Swedish lotteries. *American Economic Review* 107(12), 3917-3946.

Chetty, R. (2008). Moral hazard versus liquidity and optimal unemployment insurance. *Journal of Political Economy* 116(2), 173-234.

Clark, A., Knabe, A. and Rätzel, S. (2010). Boon or bane? Others' unemployment, well-being and job insecurity. *Labour Economics* 17(1), 52-61.

Conway, A. (2020). Master's thesis, Sciences Po.

DellaVigna, S., Lindner, A., Reizer, B. and Schmieder, J. (2017). Reference-dependent job search: evidence from Hungary. *Quarterly Journal of Economics* 132(4), 1969-2018.

HM Treasury (2021). Wellbeing guidance for appraisal: supplementary Green Book guidance. London.

Iskhakov, F., Jørgensen, T., Rust, J. and Schjerning, B. (2017). The endogenous grid method for discrete-continuous dynamic choice models with (or without) taste shocks. *Quantitative Economics* 8(2), 317-365.

Kaplan, G. and Violante, G. (2014). A model of the consumption response to fiscal stimulus payments. *Econometrica* 82(4), 1199-1239.

Kaplan, G., Violante, G. and Weidner, J. (2014). The wealthy hand-to-mouth. *Brookings Papers on Economic Activity*, Spring, 77-138.

Kolsrud, J., Landais, C., Nilsson, P. and Spinnewijn, J. (2018). The optimal timing of unemployment benefits: theory and evidence from Sweden. *American Economic Review* 108(4-5), 985-1033.

Kőszegi, B. and Rabin, M. (2009). Reference-dependent consumption plans. *American Economic Review* 99(3), 909-936.

Landais, C., Michaillat, P. and Saez, E. (2018). A macroeconomic approach to optimal unemployment insurance: theory. *American Economic Journal: Economic Policy* 10(2), 152-181.

Lima de Miranda, K. and Snower, D. (2020). Recoupling economic and social prosperity. IZA Discussion Paper 12998 (working paper).

MacQueen, J. (1966). A modified dynamic programming method for Markovian decision problems. *Journal of Mathematical Analysis and Applications* 14(1), 38-43.

McKay, A. and Reis, R. (2016). The role of automatic stabilizers in the U.S. business cycle. *Econometrica* 84(1), 141-194.

Meier, S. and Stutzer, A. (2008). Is volunteering rewarding in itself? *Economica* 75(297), 39-59.

Menz, T. and Welsch, H. (2010). Population aging and environmental preferences in OECD countries: the case of air pollution. *Ecological Economics* 69(12), 2582-2589.

Pagel, M. (2017). Expectations-based reference-dependent life-cycle consumption. *Review of Economic Studies* 84(2), 885-934.

Porteus, E. (1971). Some bounds for discounted sequential decision processes. *Management Science* 18(1), 7-11.

Schmieder, J. and von Wachter, T. (2016). The effects of unemployment insurance benefits: new evidence and interpretation. *Annual Review of Economics* 8, 547-581.

Stutzer, A. and Frey, B. (2008). Stress that doesn't pay: the commuting paradox. *Scandinavian Journal of Economics* 110(2), 339-366.

World Health Organization (2021). WHO global air quality guidelines. Geneva.

Young, E. (2010). Solving the incomplete markets model with aggregate uncertainty using the Krusell-Smith algorithm and non-stochastic simulations. *Journal of Economic Dynamics and Control* 34(1), 36-41.

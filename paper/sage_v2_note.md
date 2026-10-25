---
title: "SAGE, version 2: a quarterly economy with unemployment durations, benefit profiles and job search"
subtitle: "Model note, draft for methods review"
author: "Alessandro Conway"
date: "October 2026"
geometry: margin=2.5cm
fontsize: 11pt
linestretch: 1.15
---

**Abstract.** Version 2 of SAGE keeps version 1's structure, a one-asset Bewley economy in partial equilibrium for France, Germany and Italy with three switchable dimensions of wellbeing, and changes how time and unemployment are represented. The period is a quarter. Exits from unemployment follow the duration bands of the Labour Force Survey, an inactive state holds jobless households outside unemployment, and benefits follow the household-weighted net replacement rates of OECD TaxBEN quarter by quarter, with entitlement running out at the statutory maximum. Dread of job loss is the coming year's lottery at Pagel's annual weight, and job search is refitted so that chosen exits match the duration-based hazards, with the arrival rate normalised as in DellaVigna and co-authors. Every configuration is recalibrated. Three results stand out. The marginal propensity to consume, measured over twelve months as the survey asks, is no longer too low: it is twice the survey value in France, above it in Germany and close to it in Italy. The fall in consumption on job loss, measured as Kolsrud and co-authors measure it, is 0.16 to 0.17 without dread and 0.21 to 0.23 with it, about four to five times their estimate, a gap that version 1's two-asset reference attributes largely to the absence of illiquid wealth. The response of job finding to benefits now carries moral hazard within the spell and comes out at about twice Chetty's estimate. France cannot carry dread in choices on the quarterly economy, and dread enters its wellbeing only.

# 1. What version 2 changes, and why

Version 1 (Conway 2026, model note) left three gaps stated rather than forced. The fall in consumption on job loss was about three times the Swedish register estimate, the response of job finding to benefits held no moral hazard within the spell, and the marginal propensity to consume was in range but misordered across countries. Each gap had a candidate cause in the annual period. With a year as the period, the first year's benefit is paid whatever the household does, so search effort cannot respond to it within the spell. The fall on job loss is measured over a whole year out of work, while the benchmark is the first 20 weeks. The survey asks about spending within twelve months, while an annual model reports the response within its period.

Version 2 therefore moves to a quarter and brings in what a quarter makes measurable: unemployment durations, benefit profiles by month, and the timing of entitlement. The design was reviewed twice before it was built (`paper/sage_v2_design.md`). The second asset, planned as step 2, was not adopted: one quarterly two-asset household problem took two to three hours on the existing solver (Section 6), and the annual two-asset reference of version 1 already shows what illiquid wealth does to the fall on job loss. Version 2 is the quarterly one-asset model, and the annual two-asset reference remains the model for wealth.

# 2. The quarterly economy

## 2.1 Period, patience and the income process

Patience and returns are converted by their fourth roots, and the asset grid's top is scaled to quarterly income. The published income process is annual (Ampudia, Cooper, Le Blanc and Zhu 2024): an AR(1) with persistence $\rho$ and innovation variance $\sigma_\eta^2$, plus a transitory part with variance $\sigma_\varepsilon^2$. I map it to a quarter by treating annual log income as the average of four quarters' log income, a stated convention. The quarterly persistence is set to $\rho^{1/4}$ and the two quarterly standard deviations are fitted so that annual averages reproduce the published variance and first autocovariance, with job loss in the chain. Fitting the persistence freely as well put France's low-education cell at a near-unit root, because unemployment spells of a year and more add covariance across years. That root mixed slowly and took a solve from 36 minutes to five hours. The fixed persistence misses the second autocovariance by 2 to 12 per cent, with Germany's low-education cell the largest miss, and that is stated.

I also tested a transitory part that lasts a year on average rather than a quarter. It failed for a reason worth recording. A transitory part kept across quarters also carries into the next year's average, with an annual autocorrelation of about 0.5, which the published decomposition rules out, so the fit pushed the persistent part to its bound. The transitory part is drawn afresh each quarter.

## 2.2 Unemployment durations and inactivity

Exits from unemployment come from the stock of the unemployed by duration (Eurostat `lfsa_ugad`, 2015 to 2019 and 2022 to 2024). Five quarterly hazards, constant within quarter 1, quarter 2, quarters 3 to 4, quarters 5 to 8 and beyond, are fitted to the seven duration bands in a steady state, constrained not to rise with duration. Spells are tracked quarter by quarter for eight quarters, after which households enter a long-term state. The quarterly flows (`lfsi_long_q`) imply faster exits than the durations allow, which I read, following Elsby, Hobijn and Şahin (2015), as churning between unemployment and inactivity that does not end a reported spell. The duration-based exit is therefore split between work and inactivity with work taking the flows' rate into employment.

The model's unit is the household's main earner, so person-level flows into and out of inactivity overstate inactivity at the household level. Applied directly, they made a fifth to a quarter of households inactive. The inactive state is instead sized at the household level: by education cell, the share of adults in jobless households (EU-SILC) less the unemployed. The person flows give only how fast it is left and where to. Job loss and the flow into inactivity are set together so that each cell's unemployment rate and inactive share are version 1's.

## 2.3 Benefits by quarter

Benefits follow the household-weighted TaxBEN profile of version 1's first-year rate, month by month to month 60, averaged by quarter. Months 1 to 12 reproduce version 1's first-year rates exactly (0.725, 0.699 and 0.702). The profile is 0.725 for eight quarters in France (24 months of insurance), 0.699 for four quarters in Germany, and declining from 0.725 to 0.489 over eight quarters in Italy, as NASpI does. Beyond eight quarters the mean of months 25 to 60 applies: 0.337, 0.332 and 0.236. These are below version 1's jobless-household income (0.480, 0.509 and 0.437), which an earlier stage had kept, so benefits there had been more generous than the rules.

The model's minimum income is its means-tested floor, as in version 1. I therefore use TaxBEN's profile without social assistance, so that assistance is not paid twice, once without the floor's test on assets. The two profiles differ only in France beyond two years. Germany's Bürgergeld is classed in TaxBEN as unemployment assistance and stays in the income either way, as it did in version 1.

The design gave those entering unemployment from inactivity a spell without entitlement. It doubled the state space and the solve time while moving the fall on job loss by 0.002 to 0.006, so it is left out, with entitlement for every entrant. Switched back on at the calibrated economy, it moves hand-to-mouth by at most 0.004 and the fall by at most 0.006 in Germany and Italy.

## 2.4 Dread over the coming year

Version 1's dread is the anticipatory loss of the coming year's employment lottery, at the weight $\eta(\lambda-1) = 1.5$ of Pagel (2017), in the form of Kőszegi and Rabin (2009). Pagel estimates that weight in a life-cycle model with an annual period. Applied to a quarter's lottery it would shrink dread to about a quarter of its size relative to consumption utility. In version 2 households dread the coming year's lottery each quarter, the chance of a change of status within four quarters from the four-step transition matrix, which keeps the term's size relative to consumption utility as in version 1.

# 3. Job search

The design fitted arrival rates by duration group and cost levels by cell to the duration bands. With the chance of work $\lambda_d x$ and effort chosen at cost $k x^{1+\gamma_s}/(1+\gamma_s)$, the chosen exit is proportional to $\lambda^{1+1/\gamma_s} k^{-1/\gamma_s}$ wherever effort is interior. Scaling $\lambda$ by $a$ and $k$ by $a^{1+\gamma_s}$ leaves every exit unchanged, so exits alone cannot separate the two. DellaVigna, Lindner, Reizer and Schmieder (2017), the source of $\gamma_s = 0.35$, define search intensity as the chance of finding work, an arrival rate of one, and I adopt their normalisation. Duration dependence then goes into the cost level, by quarter of the spell and education cell, fitted so that the chance chosen, averaged over the stationary distribution, equals the duration-based exit to work in every quarter. In France the costs vary by the data's duration groups rather than by quarter, because neighbouring quarters' costs alternated in the fit.

The fitted costs rise with duration: in Germany's low-education cell from 17 in the first quarter to 31 from the third and 36 in the long-term state, in Italy's from 23 to 48 by the eighth quarter and 71 beyond. Rising costs are what a falling hazard needs once selection on wealth is accounted for. G+S+A takes G+A's costs, since a fit with S on rebuilds the participation families at every step, and its chosen exits are reported.

# 4. Calibration

Each configuration is recalibrated on the quarterly economy to version 1's targets, with version 1's rule that the MPC is a test and not a target. Patience and its gap by education are fitted to the hand-to-mouth share and its gap by education (HFCS 2021, households not retired, the narrow liquid-wealth definition of Kaplan, Violante and Weidner 2014). Where S is on, its two parameters are fitted to the participation of the two education cells by version 1's method: the households' response to belonging solved over a grid of belonging scales, the measured ratio of the unemployed's participation imposed, and the parameters scanned for the equilibrium the economy selects, with a multiplier of at most five. The quarterly economy needs a coarser belonging grid (22 scales rather than 83) to fit on a runner. On Germany's G+S the coarse and version 1's 42-scale grids give the same moments to the fourth decimal.

The quarterly economy needs far less patience than the annual one for the same buffers: annual equivalents of 0.82, 0.91 and 0.92 against version 1's 0.96 to 0.98. France's low-education cell sits at 0.69. With dread in choices, Germany and Italy need lower patience again (0.81 and 0.88). France cannot be fitted with dread in choices: its hand-to-mouth share needs patience of about 0.70, and its education gap is then not reached. Under the rule agreed for version 1, dread there enters wellbeing only and France's G+A takes G's patience. The social parameters move little from version 1, and switching S on leaves hand-to-mouth, the MPC and the fall where G has them, as the modular design requires.

# 5. Measures matched to their benchmarks

**The MPC over twelve months.** The HFCS asks how much of an unexpected windfall of one month's income a household would spend within twelve months. The model's measure follows each household's own choices forward four quarters and sums the extra consumption over the windfall.

**The fall on job loss.** Kolsrud, Landais, Nilsson and Spinnewijn (2018) estimate a drop of 4.4 per cent as the survival-weighted mean of the weekly consumption drop over the first 20 weeks of a spell, against consumption in the last year in work. The model's measure follows the cohort that loses its job through its first two quarters out of work, against its consumption in its last quarter in work, weighting the second quarter by survival over seven of its thirteen weeks. Because consumption keeps falling as buffers run down, this estimand gives a slightly larger fall than version 1's instantaneous measure.

# 6. Numerical method and verification

The household problem is solved by the endogenous grid method with an upper envelope and logit smoothing of discrete choices, as in version 1. At a quarterly period the stationary distribution is found by a sparse direct solve where power iteration has not settled, which took one problem from about four hours to under a minute. Version 1 is reproduced to $3.5 \times 10^{-13}$ after every change, by a regression harness of 183 moments. The chain written in version 2's labelled states reproduces version 1's annual chain to $3 \times 10^{-11}$.

The two-asset solver (the nested endogenous grid method of Druedahl 2021) was sped up three to four times by running its inner and outer steps on threads with separate work arrays, leaving its answers unchanged to $10^{-14}$. One quarterly two-asset problem still takes about half an hour and 3,700 to 4,900 iterations, which a calibration of several problems a solve cannot afford on the runners used here. Midpoint extrapolation of the error bounds (MacQueen 1966; Porteus 1971) did not reduce the iteration count, since the stopping rule is the span of the bounds, which a common shift leaves unchanged. Policy-iteration steps would be the next step.

# 7. Results

## 7.1 Fit and untargeted moments

| | hand-to-mouth (target) | MPC 12 months (survey) | fall on job loss (Kolsrud 0.044) |
|---|---|---|---|
| France G | 0.273 (0.268) | 0.73 (0.33) | 0.165 |
| Germany G | 0.253 (0.252) | 0.54 (0.46) | 0.168 |
| Italy G | 0.194 (0.203) | 0.41 (0.49) | 0.170 |
| Germany G+A, search fitted | 0.252 | 0.62 | 0.228 |
| Italy G+A, search fitted | 0.194 | 0.52 | 0.226 |

The MPC, measured as the survey asks it, has moved from too low in version 1 to too high in France and Germany, and close to the survey in Italy once dread is in. Much of version 1's MPC gap was the horizon. France's MPC is more than twice its survey value at the patience its hand-to-mouth share requires, and lowering patience further would raise it more, so in the one-asset model France's two moments pull against each other.

The fall on job loss is about four times Kolsrud and co-authors' estimate without dread and five times with it, against five to seven times in version 1. Version 2's lower fall came in two steps that pulled in opposite directions: durations from the data lowered it, and benefits following the real profile raised it again, since earlier stages had been more generous than the rules. In version 1's annual two-asset reference the fall was 0.07 to 0.11 in the three countries against 0.15 to 0.25 on one asset, because households with illiquid wealth behind them absorb a job loss. I read most of the remaining gap as the absence of that wealth. The benchmark is Swedish, with replacement up to its cap above the three countries', so it is a lower bound for them.

## 7.2 The response of job finding to benefits

With benefits paid by quarter, search effort can respond to them within the spell. Raising the entitled benefit by 10 per cent in every quarter, with taxes held fixed, lowers the mean chance of finding work by 8.5 per cent in Germany and 10.5 per cent in Italy, elasticities of $-0.85$ and $-1.05$. Chetty (2008) estimates $-0.53$ for a weekly hazard, which converts to about $-0.45$ and $-0.48$ for the two countries' quarterly chances (my conversion). The model therefore responds about twice as strongly as the benchmark, where version 1 held only the liquidity part at about half of it. The overshoot is common to both countries, which points to the cost curvature: with $\gamma_s = 0.35$, effort responds to the gain from work with an elasticity of about 2.9. The curvature is a published estimate and I do not tune it to the elasticity.

## 7.3 The wellbeing account

Version 1's account is kept, with one correction. Version 1's long-term state held every jobless household and charged each the life-satisfaction gap of the unemployed (about 1.06 points at the same income decile, ESS). Version 2 separates the unemployed from the inactive. I estimated the inactive's gap from the same survey with the same controls. Those not looking for work and the sick or disabled lose about as much as the unemployed, those retired early or caring for a household lose nothing, and together the inactive lose 0.14, 0.24 and 0.23 points. The account charges the unemployed their gap and the inactive the pooled one.

| points per head and year | France | Germany | Italy |
|---|---|---|---|
| out of work beyond income, unemployed | -0.067 | -0.027 | -0.072 |
| inactive beyond income | -0.007 | -0.017 | -0.007 |
| dread of a change of status (G+A) | in wellbeing only, [to complete] | -0.053 | -0.033 |
| of which job search, within the unemployed's term | [to complete] | -0.007 | -0.046 |
| taking part (G+S, Meier and Stutzer 2008) | +0.016 | +0.019 | +0.009 |
| air quality | -0.049 | -0.058 | -0.103 |

The cost of being out of work falls by a third to a half against version 1, most in Germany, where most jobless households are inactive. Dread roughly doubles in Germany, since it now covers the year's lottery at its full size. In Italy job search accounts for two thirds of the unemployed's measured gap, because matching Italy's slow exits takes high search costs, against a quarter in Germany. The model's own value of belonging is 0.11, 0.55 and 0.20 points a participant against the evidence's 0.055 to 0.081, close in France and Italy and about seven times it in Germany, as in version 1. With all three dimensions on, the terms barely move: in G+S+A every A term in Germany and Italy lies within 2 per cent of its G+A value, taking part stays at +0.019 and +0.008, and G+A's search costs give exits within about 2 per cent of the targets.

# 8. Limits and open decisions

I state five limits. First, the MPC over twelve months is too high in France and Germany, and in France by more than double. Second, the fall on job loss remains four to five times the benchmark, a gap I attribute largely to the absence of illiquid wealth, on version 1's annual two-asset evidence rather than a quarterly two-asset model. Third, the response of job finding to benefits is about twice the benchmark, most plausibly through the search cost curvature. Fourth, the fixed quarterly persistence misses the second autocovariance of income by up to 12 per cent in France and about a quarter in Germany's low-education cell with the benefit profile. Fifth, Italy's patience gap with dread sits at the search's bound, and the budget gap of G+S+A is of order $10^{-4}$ because the floor's tax is set with S off, as in version 1.

Two decisions are open. The design's rule is that a country whose quarterly economy cannot meet the annual base's targets stays annual. France meets its targets with dread in wellbeing only, and its MPC test fails by the widest margin, so whether France is reported on the quarterly or the annual economy is a choice I put to review. The inactive's gap is pooled because the model's inactive state cannot be split by main activity, and the alternatives, no gap or the unemployed's, would understate or overstate the cost.

# Data

Eurostat: `lfsa_ugad` (unemployment by duration), `lfsi_long_q` (labour market flows, seasonally adjusted), `ilc_lvhl14n` and `ilc_di07` (jobless households and their income). OECD TaxBEN 2023 net replacement rates by month (`DSD_TAXBEN_NRR`). HFCS 2021 (Eurosystem Household Finance and Consumption Survey): this paper uses data from the Eurosystem Household Finance and Consumption Survey. European Social Survey rounds 6, 7, 10 and 11, life satisfaction by main activity, aggregates only. Scripts: `data/labour/duration_flows.py`, `data/benefits/build_floor_and_replacement.py` (part h), `data/ess/ess_inactive_gaps.py`.

# References

Ampudia, M., Cooper, R., Le Blanc, J. and Zhu, G. (2024). MPC heterogeneity and the dynamic response of consumption to monetary policy. *American Economic Journal: Macroeconomics* 16(3). Table 16 read in the working-paper version, BIS Working Paper 1102.

Chetty, R. (2008). Moral hazard versus liquidity and optimal unemployment insurance. *Journal of Political Economy* 116(2), 173-234.

Conway, A. (2020). Master's thesis, Sciences Po.

DellaVigna, S., Lindner, A., Reizer, B. and Schmieder, J. (2017). Reference-dependent job search: evidence from Hungary. *Quarterly Journal of Economics* 132(4), 1969-2018.

Druedahl, J. (2021). A guide on solving non-convex consumption-saving models. *Computational Economics* 58, 747-775.

Elsby, M., Hobijn, B. and Şahin, A. (2015). On the importance of the participation margin for labor market fluctuations. *Journal of Monetary Economics* 72, 64-82.

Hubbard, R. G., Skinner, J. and Zeldes, S. (1995). Precautionary saving and social insurance. *Journal of Political Economy* 103(2), 360-399.

Kaplan, G., Violante, G. and Weidner, J. (2014). The wealthy hand-to-mouth. *Brookings Papers on Economic Activity*, Spring, 77-138.

Kolsrud, J., Landais, C., Nilsson, P. and Spinnewijn, J. (2018). The optimal timing of unemployment benefits: theory and evidence from Sweden. *American Economic Review* 108(4-5), 985-1033.

Kőszegi, B. and Rabin, M. (2009). Reference-dependent consumption plans. *American Economic Review* 99(3), 909-936.

MacQueen, J. (1966). A modified dynamic programming method for Markovian decision problems. *Journal of Mathematical Analysis and Applications* 14(1), 38-43.

Meier, S. and Stutzer, A. (2008). Is volunteering rewarding in itself? *Economica* 75(297), 39-59.

Pagel, M. (2017). Expectations-based reference-dependent life-cycle consumption. *Review of Economic Studies* 84(2), 885-934.

Porteus, E. (1971). Some bounds for discounted sequential decision processes. *Management Science* 18(1), 7-11.

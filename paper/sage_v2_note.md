---
title: "SAGE, version 2: a quarterly economy with unemployment durations, benefit profiles and job search"
subtitle: "Model note, draft for methods review"
author: "Alessandro Conway"
date: "October 2026"
geometry: margin=2.5cm
fontsize: 11pt
linestretch: 1.15
---

**Abstract.** Version 2 of SAGE keeps version 1's structure, a one-asset Bewley economy in partial equilibrium for France, Germany and Italy with three switchable dimensions of wellbeing, and changes how time and unemployment are represented. The period is a quarter. Exits from unemployment follow the duration bands of the Labour Force Survey, an inactive state holds jobless households outside unemployment, and benefits follow the household-weighted net replacement rates of OECD TaxBEN quarter by quarter, with entitlement running out at the statutory maximum. Dread of job loss is the coming year's lottery at Pagel's annual weight, and job search is refitted so that chosen exits match the duration-based hazards, with the arrival rate normalised as in DellaVigna and co-authors. Every configuration is recalibrated. Three results stand out. The marginal propensity to consume, measured over twelve months as the survey asks, is no longer too low: it is twice the survey value in France, above it in Germany and close to it in Italy, while its profile over five years lies close to the Norwegian lottery evidence. The fall in consumption on job loss, measured as Kolsrud and co-authors measure it, is 0.16 to 0.17 without dread and 0.21 to 0.23 with it, about four to five times their estimate, a gap that version 1's annual two-asset reference narrows but does not close. The response of job finding to benefits now carries moral hazard within the spell. With the curvature of the search cost set on German evidence on the potential duration of benefits, the elasticity of time out of work to the benefit level is 0.30, 0.36 and 0.19 in France, Germany and Italy, within or near the measured ones, while the response to entitlement is small and about the same in the three countries, matching Germany and lying below the French and Italian estimates at every margin tested. France cannot carry dread in choices on the quarterly economy, and dread enters its wellbeing only. Places by degree of urbanisation are carried to the quarterly economy, with G, G+S and G+S+A, at the national calibrations, which they leave within 0.006 of their targets.

# 1. What version 2 changes, and why

Version 1 (Conway 2026, model note) left three gaps stated rather than forced. The fall in consumption on job loss, 0.28 to 0.29 over a first year out of work, was about three times the Swedish register estimate for those still out of work after 20 weeks (0.091), the benchmark that matches an annual period, and about six and a half times the estimate for the first 20 weeks (0.044) that version 2 uses. The response of job finding to benefits held no moral hazard within the spell, and the marginal propensity to consume was in range but misordered across countries. Each gap had a candidate cause in the annual period. With a year as the period, the first year's benefit is paid whatever the household does, so search effort cannot respond to it within the spell. The fall on job loss is measured over a whole year out of work, while the benchmark is the first 20 weeks. The survey asks about spending within twelve months, while an annual model reports the response within its period.

Version 2 therefore moves to a quarter and brings in what a quarter makes measurable: unemployment durations, benefit profiles by month, and the timing of entitlement. The design was reviewed twice before it was built (`paper/sage_v2_design.md`). The second asset was planned as step 2. I built and tested three quarterly two-asset designs after version 2 was settled, and none reproduced who holds illiquid wealth with little cash, so the second asset is set aside (Section 8). Version 2 is the quarterly one-asset model, and the annual two-asset reference of version 1 remains the model's only evidence on what illiquid wealth does to the fall on job loss.

# 2. The quarterly economy

## 2.1 Period, patience and the income process

Patience and returns are converted by their fourth roots, and the asset grid's top is scaled to quarterly income. The published income process is annual (Ampudia, Cooper, Le Blanc and Zhu 2024): an AR(1) with persistence $\rho$ and innovation variance $\sigma_\eta^2$, plus a transitory part with variance $\sigma_\varepsilon^2$. I map it to a quarter by treating annual log income as the average of four quarters' log income, a stated convention. The quarterly persistence is set to $\rho^{1/4}$ and the two quarterly standard deviations are fitted so that annual averages reproduce the published variance and first autocovariance, with job loss in the chain. Fitting the persistence freely as well put France's low-education cell at a near-unit root, because unemployment spells of a year and more add covariance across years. That root mixed slowly and took a solve from 36 minutes to five hours. The fixed persistence misses the second autocovariance in every cell, by up to about a quarter in the final economy with the benefit profile (Germany's low-education cell: 0.049 against 0.064), and that is stated.

I also tested a transitory part that lasts a year on average rather than a quarter. It failed for a reason worth recording. A transitory part kept across quarters also carries into the next year's average, with an annual autocorrelation of about 0.5, which the published decomposition rules out, so the fit pushed the persistent part to its bound. The transitory part is drawn afresh each quarter.

## 2.2 Unemployment durations and inactivity

Exits from unemployment come from the stock of the unemployed by duration (Eurostat `lfsa_ugad`, 2015 to 2019 and 2022 to 2024). Five quarterly hazards, constant within quarter 1, quarter 2, quarters 3 to 4, quarters 5 to 8 and beyond, are fitted to the seven duration bands in a steady state, constrained not to rise with duration. Spells are tracked quarter by quarter for eight quarters, after which households enter a long-term state. The quarterly flows (`lfsi_long_q`) imply faster exits than the durations allow, which I read, following Elsby, Hobijn and Şahin (2015), as churning between unemployment and inactivity that does not end a reported spell. The duration-based exit is therefore split between work and inactivity with work taking the flows' rate into employment.

The model's unit is the household's main earner, so person-level flows into and out of inactivity overstate inactivity at the household level. Applied directly, they made a fifth to a quarter of households inactive. The inactive state is instead sized at the household level: by education cell, the share of adults in jobless households (EU-SILC) less the unemployed. The subtraction assumes that the model's unemployed main earners live in jobless households and that adults stand for main earners. Neither holds exactly, since an unemployed adult can live with someone in work, so the inactive share is an approximation on that stated assumption. The person flows give only how fast it is left and where to. Job loss and the flow into inactivity are set together so that each cell's unemployment rate and inactive share are version 1's.

## 2.3 Benefits by quarter

Benefits follow the household-weighted TaxBEN profile of version 1's first-year rate, month by month to month 60, averaged by quarter. Months 1 to 12 reproduce version 1's first-year rates exactly (0.725, 0.699 and 0.702). The profile is 0.725 for eight quarters in France (24 months of insurance), 0.699 for four quarters in Germany, and declining from 0.725 to 0.489 over eight quarters in Italy, as NASpI does. Beyond eight quarters the mean of months 25 to 60 applies: 0.337, 0.332 and 0.236. These are below version 1's jobless-household income (0.480, 0.509 and 0.437), which an earlier stage had kept, so benefits there had been more generous than the rules.

The model's minimum income is its means-tested floor, as in version 1. I therefore use TaxBEN's profile without social assistance, so that assistance is not paid twice, once without the floor's test on assets. The two profiles differ only in France beyond two years. Germany's Bürgergeld is classed in TaxBEN as unemployment assistance and stays in the income either way, as it did in version 1.

The design gave those entering unemployment from inactivity a spell without entitlement. It doubled the state space and the solve time while moving the fall on job loss by 0.002 to 0.006, so it is left out, with entitlement for every entrant. Switched back on at the calibrated economy, it moves hand-to-mouth by at most 0.004 and the fall by at most 0.006 in Germany and Italy.

## 2.4 Dread over the coming year

Version 1's dread is the anticipatory loss of the coming year's employment lottery, at the weight $\eta(\lambda-1) = 1.5$ of Pagel (2017), in the form of Kőszegi and Rabin (2009). Pagel estimates that weight in a life-cycle model with an annual period. Applied to a quarter's lottery it would shrink dread to about a quarter of its size relative to consumption utility. In version 2 households dread the coming year's lottery each quarter. In state $s$ the term is $\eta(\lambda-1)\, q_s (1-q_s)\, [u(y^{hi}_s) - u(y^{lo}_s)]$, where $q_s$ is the chance of a change of status within four quarters from the four-step transition matrix of the labour chain, and $y^{hi}_s$ and $y^{lo}_s$ are a period's resources in work and in the bad outcome at the same latent productivity. With dread in choices it is subtracted from each period's utility in the Bellman equation, and otherwise it enters the account only. Two features follow. The lottery is the chain's, at the calibrated hazards, so it does not move with the household's own search effort or wealth, and it is the status four quarters ahead, not the path within the year. And the term is of the same degree as consumption utility in a period's resources, so its consumption equivalent per period does not depend on the period's length. Charging it each quarter therefore keeps its size relative to consumption utility, as each year did in version 1. The horizon is a convention, and Section 7.3 reports the term with the coming quarter's lottery instead.

# 3. Job search

The design fitted arrival rates by duration group and cost levels by cell to the duration bands. With the chance of work $\lambda_d x$ and effort chosen at cost $k x^{1+\gamma_s}/(1+\gamma_s)$, the chosen exit is proportional to $\lambda^{1+1/\gamma_s} k^{-1/\gamma_s}$ wherever effort is interior. Scaling $\lambda$ by $a$ and $k$ by $a^{1+\gamma_s}$ leaves every exit unchanged, so exits alone cannot separate the two. DellaVigna, Lindner, Reizer and Schmieder (2017) define search intensity as the chance of finding work, an arrival rate of one, and I adopt their normalisation. Duration dependence then goes into the cost level, by quarter of the spell and education cell, fitted so that the chance chosen, averaged over the stationary distribution, equals the duration-based exit to work in every quarter. In France the costs vary by the data's duration groups rather than by quarter, because neighbouring quarters' costs alternated in the fit, and they are fitted with dread in wellbeing only, as France's calibration requires (Section 4).

The curvature $\gamma_s$ was first taken from DellaVigna and co-authors, at 0.35. With it the response of job finding to the benefit level was two to three times Chetty's (2008) US estimate in all three countries and well above the European ones. I therefore set the curvature on the best-measured European estimand, the effect of the potential duration of benefits on time out of work in Germany, where two designs agree: Schmieder, von Wachter and Bender (2012) find 0.10 to 0.13 extra months out of work per month of entitlement for extensions from 12 to 18 months, and Lichter and Schiprowski (2021) about 0.12 for 12 to 15 months. For 12 to 15 months the model gives 0.50, 0.25, 0.16 and 0.12 at curvatures of 0.35, 1, 2 and 3, falling about as $\gamma_s^{-0.65}$, and at $\gamma_s = 3$ on the fitted costs it gives 0.115 and, for 12 to 18 months, 0.109. The same curvature applies in France and Italy, whose entitlement and level estimates, with Germany's level response, are tests (Section 7.2).

The fitted costs rise with duration in every country and cell, which is what a falling hazard needs once selection on wealth is accounted for. At this curvature the levels move steeply, since the chosen chance moves with the cost only to the power $-1/3$: in Germany's low-education cell the level in the eighth quarter is about 29 times the first quarter's. G+S+A takes G+A's costs, since a fit with S on rebuilds the participation families at every step, and its chosen exits are reported.

# 4. Calibration

Each configuration is recalibrated on the quarterly economy to version 1's targets, with version 1's rule that the MPC is a test and not a target. Patience and its gap by education are fitted to the hand-to-mouth share and its gap by education (HFCS 2021, households not retired, the narrow liquid-wealth definition of Kaplan, Violante and Weidner 2014). A household is hand-to-mouth when its liquid wealth is at most one week of its own income, the same threshold in both versions (a period's income times 4/52 here). Where S is on, its two parameters are fitted to the participation of the two education cells by version 1's method: the households' response to belonging solved over a grid of belonging scales, the measured ratio of the unemployed's participation imposed, and the parameters scanned for the equilibrium the economy selects, with a multiplier of at most five. The quarterly economy needs a coarser belonging grid (22 scales rather than 83) to fit on a runner. On Germany's G+S the coarse and version 1's 42-scale grids give the same moments to the fourth decimal.

The quarterly economy needs far less patience than the annual one for the same buffers: annual equivalents of 0.82, 0.91 and 0.92 against version 1's 0.96 to 0.98. France's low-education cell sits at 0.69. With dread in choices, Germany and Italy need lower patience again (0.81 and 0.88). France cannot be fitted with dread in choices: its hand-to-mouth share needs patience of about 0.70, and its education gap is then not reached. Under the rule agreed for version 1, dread there enters wellbeing only and France's G+A takes G's patience. The social parameters move little from version 1, and switching S on leaves hand-to-mouth, the MPC and the fall where G has them, as the modular design requires.

The low patience is the cost of a one-asset model fitted to liquid wealth. In such a model the only wealth is liquid, so households must hold as little in total as the data's liquid holdings, and only low patience keeps them there. Kaplan and Violante (2022) describe this as the main trade-off of one-asset models: calibrated to liquid wealth, they produce MPCs of the right size at the price of too little wealth overall and patience below what models of total wealth use. I take the trade, since the questions here concern buffers against job loss, and I do not read the patience as an estimate of time preference.

# 5. Measures matched to their benchmarks

**The MPC over twelve months.** The HFCS asks how much of an unexpected windfall of one month's income a household would spend within twelve months. The model's measure follows each household's own choices forward four quarters and sums the extra consumption over the windfall.

**The fall on job loss.** Kolsrud, Landais, Nilsson and Spinnewijn (2018) estimate a drop of 4.4 per cent as the survival-weighted mean of the weekly consumption drop over the first 20 weeks of a spell, against consumption in the last year in work. The model's measure follows the cohort that loses its job through its first two quarters out of work, against its consumption in its last quarter in work, weighting the second quarter by survival over seven of its thirteen weeks. Because consumption keeps falling as buffers run down, this estimand gives a slightly larger fall than version 1's instantaneous measure.

# 6. Numerical method and verification

The household problem is solved by the endogenous grid method with an upper envelope and logit smoothing of discrete choices, as in version 1. At a quarterly period the stationary distribution is found by a sparse direct solve where power iteration has not settled, which took one problem from about four hours to under a minute. Version 1 is reproduced to $3.5 \times 10^{-13}$ after every change, by a regression harness of 183 moments. The chain written in version 2's labelled states reproduces version 1's annual chain to $3 \times 10^{-11}$.

The two-asset solver (the nested endogenous grid method of Druedahl 2021) was sped up three to four times by running its inner and outer steps on threads with separate work arrays, leaving its answers unchanged to $10^{-14}$. One quarterly two-asset problem then still took about half an hour and 3,700 to 4,900 iterations, which a calibration of several problems a solve could not afford on the runners used here. Midpoint extrapolation of the error bounds (MacQueen 1966; Porteus 1971) did not reduce the iteration count, since the stopping rule is the span of the bounds, which a common shift leaves unchanged. Since then the solver takes ten policy-evaluation steps between full steps (modified policy iteration, Puterman 1994, section 6.5), and a quarterly problem converges in 10 to 30 minutes once the illiquid grid covers only states that households can hold. The two-asset model is set aside for now (Section 8).

# 7. Results

## 7.1 Fit and untargeted moments

| | hand-to-mouth (target) | MPC 12 months (survey) | fall on job loss (Kolsrud 0.044) |
|---|---|---|---|
| France G | 0.273 (0.268) | 0.73 (0.33) | 0.165 |
| Germany G | 0.253 (0.252) | 0.54 (0.46) | 0.168 |
| Italy G | 0.194 (0.203) | 0.41 (0.49) | 0.170 |
| France G+A, search fitted (dread in wellbeing only) | 0.270 | 0.71 | 0.164 |
| Germany G+A, search fitted | 0.253 | 0.62 | 0.228 |
| Italy G+A, search fitted | 0.199 | 0.53 | 0.220 |

The MPC, measured as the survey asks it, has moved from too low in version 1 to too high in France and Germany, and close to the survey in Italy once dread is in. Much of version 1's MPC gap was the horizon. Within a quarter the MPC of G+A with search is 0.31, 0.24 and 0.21 in France, Germany and Italy, against 0.71, 0.62 and 0.53 over twelve months, so most of the twelve-month response comes after the first quarter. France's MPC is more than twice its survey value at the patience its hand-to-mouth share requires, and lowering patience further would raise it more, so in the one-asset model France's two moments pull against each other.

Version 2 is a one-asset model calibrated to liquid wealth, the route Kaplan and Violante (2022) find gets MPCs about right in one-asset models, and its hand-to-mouth households are the poor hand-to-mouth of Kaplan, Violante and Weidner (2014). Two further tests follow the windfall over time and across liquid wealth, both on G+A with search fitted and both untargeted.

| | year 1 | year 2 | year 3 | five years | MPC 12 months by liquid wealth quintile, model | the same, HFCS 2021 |
|---|---|---|---|---|---|---|
| France | 0.71 | 0.15 | 0.04 | 0.92 | 0.73, 0.82, 0.75, 0.69, 0.56 | 0.35, 0.36, 0.38, 0.41, 0.48 |
| Germany | 0.62 | 0.18 | 0.06 | 0.89 | 0.63, 0.71, 0.66, 0.60, 0.51 | 0.50, 0.47, 0.45, 0.47, 0.44 |
| Italy | 0.53 | 0.18 | 0.07 | 0.83 | 0.44, 0.66, 0.60, 0.52, 0.42 | 0.53, 0.50, 0.46, 0.45, 0.40 |

The windfall is one month of the household's own income, as in the survey. Spending peaks in the year of receipt and has almost stopped by the fourth year. Fagereng, Holm and Natvik (2021) find the same shape in Norwegian registers: lottery winners spend 0.52 of a prize within the year of winning, about 0.18 in the following year and about 0.90 over five years, with the within-year share falling from 0.62 to 0.46 across quartiles of liquid assets (figures as read in their 2019 working paper version). The model's second year (0.15 to 0.18) and five-year totals (0.83 to 0.92) lie close to these values in all three countries, and its first year matches in Italy and lies above in Germany and France. Their prizes are mostly larger than a month's income and spending falls with the size of the prize, so for the survey's windfall the Norwegian first-year figure is if anything a lower bound. From the second quintile of liquid wealth to the fifth, the model's MPC falls by 28 to 36 per cent. Over the same quintiles the survey's MPC is flat in Germany, falls by a fifth in Italy and rises in France, so the model's gradient is steeper than the survey's everywhere and closest to it in Italy. I read this gradient with care, since survey answers about gains show weak links to liquidity (Fuster, Kaplan and Zafar 2021), while the lottery evidence shows strong ones. The lowest quintile spends less than the second in all three countries because of the means-tested floor. The floor tops up 22, 27 and 49 per cent of the lowest quintile in France, Germany and Italy, and a windfall reduces the top-up, so these households spend only 0.31, 0.23 and 0.12 of it within the year. The rest of the lowest quintile spends 0.85, 0.79 and 0.74, and without the floor's households the MPC falls steadily with liquid wealth. Households with no income, who receive no windfall in the survey's sense, are 1 to 5 per cent of the quintile and do not account for the dip. The level remains the open issue: above the survey in France and Germany, close to it in Italy.

The fall on job loss is about four times Kolsrud and co-authors' estimate without dread and five times with it, against about six and a half times in version 1 on the same benchmark. Version 2's lower fall came in two steps that pulled in opposite directions: durations from the data lowered it, and benefits following the real profile raised it again, since earlier stages had been more generous than the rules. In version 1's annual two-asset reference the fall was 0.07 to 0.11 in the three countries against 0.15 to 0.25 on one asset, because households with illiquid wealth behind them absorb a job loss. That reference still left 1.6 to 2.5 times the benchmark, and a second asset with wealthy hand-to-mouth households can raise the MPC, so how much of the gap illiquid wealth closes remains open. The benchmark is Swedish. Whether these countries' falls should be larger or smaller depends on replacement at the cap, wealth and who stays out of work, so I use it as a benchmark and claim no ordering.

I tested two explanations of the remaining gap on the calibrated G+A, fitting nothing. Low buffers are the first, and they do not explain it. Job losers who were hand to mouth in their last quarter in work make up 19 to 25 per cent of those losing a job, and their fall is smaller than the rest's: 0.130 against 0.173 in France, 0.198 against 0.235 in Germany and 0.127 against 0.232 in Italy. In my view the means-tested floor accounts for this, since it tops up the incomes of the poorest job losers. Low patience is the second. With version 1's annual patience in both cells (0.962, 0.984 and 0.983), the hand-to-mouth share falls by a third to two thirds, yet the fall moves only from 0.164 to 0.149 in France and from 0.220 to 0.207 in Italy. In Germany it falls further, from 0.228 to 0.144, which still leaves three times the benchmark. The replacement rates are already those of the household, a partner's earnings included, so a missing second earner does not explain it either. What remains is the depth of the drop in household income on job loss against what Swedish households keep through channels the model leaves out, illiquid wealth among them, and I leave that gap stated rather than closed.

## 7.2 The response of job finding to benefits

With benefits paid by quarter, search effort can respond to them within the spell. Three measured responses serve as tests, all at the curvature set in Section 3 and on the fitted costs. The chance of work is averaged over the entitled quarters, weighted by the mass unemployed in each. The level response raises the entitled benefit by 10 per cent in every quarter with taxes held fixed. The entitlement response extends entitlement by the measured study's months, rounded to quarters, and counts months out of work after job loss, capped at 36 as Schmieder and co-authors cap them.

| | France | Germany | Italy |
|---|---|---|---|
| benefit level, elasticity of the chance of work | -0.29 | -0.23 | -0.21 |
| benefit level, elasticity of time out of work | 0.30 | 0.36 | 0.19 |
| measured, duration elasticity | 0.14 to 0.5 | none credible (Europe, corrected: 0.21) | about 0.23 |
| entitlement, months out of work per month | 0.100 (6 to 15 months) | 0.115 (12 to 15), 0.109 (12 to 18) | 0.113 (9 to 12) |
| measured | about 0.19 | 0.10 to 0.13 (target) | 0.30 to 0.36 |
| liquidity share | 0.19 | 0.26 | 0.30 |

The evidence reports elasticities of the time out of work, so I measure the same thing: the months from job loss to the next job through every state out of work, capped at 36. On that estimand the model gives 0.30 in France, 0.36 in Germany and 0.19 in Italy. France's lies within the range of the official evaluation of the 2019 to 2021 reform (Dares 2025), and Italy's a little below the one credible design (D'Ambrosio and Scrutinio 2022). Germany has no credible level estimate, and its value lies above the mean corrected for publication bias in Cohen and Ganong (2026). The elasticities of the chance of work are smaller, because hazards fall with duration and the rise in time out of work comes from the later quarters too. At a curvature of 0.35 the responses were -1.43, -0.85 and -1.05. The curvature scales the level and entitlement responses together, so the test is of their ratio: given the German entitlement effect, the model's level responses fall in each country's range, which the curvature alone does not ensure.

The response to entitlement is a different matter. The model's effect is nearly the same in the three countries, about 0.10 to 0.12 extra months out of work per month of entitlement, while the measured effects differ by a factor of three, so it matches Germany, where it is the target, and lies at about half the French estimate and a third of the Italian. Two features of the evidence temper the comparison. Le Barbanchon (2016) estimates the French effect for claimants with short work histories, whose response need not be the average claimant's. The two Italian designs at age 50 (Scrutinio 2019; D'Ambrosio and Scrutinio 2022, both working papers of the Italian social security institute) sit at a cutoff where Citino, Russ and Scrutinio (2026) document that the timing of layoffs is moved, which would bias them upward, and the peer-reviewed estimate (Sovera 2026, about 0.33) comes from a reform that changed eligibility and the benefit profile together. The test's margin is not the reason. At the margin each economy is calibrated on, cutting France's and Italy's eight quarters to six or seven, the effect is lower still, 0.054 to 0.059 a month in France and 0.057 to 0.068 in Italy, as an extension late in a spell should matter less. Nor is the restart of a spell through inactivity the reason: with no entitlement for those entering unemployment from inactivity, Italy's effect at the calibrated margin is 0.063 a month against 0.068 (the same test for France and Germany, whose state space it doubles, did not finish within the runners' six hours). The model's response to entitlement is small in all three countries, and the comparison with France and Italy is not like for like in its regime either, since the studies measure extensions under earlier rules and the model holds the 2023 ones. A curvature by country would fit Italy at about 1, but it would then rest on the weakest of the three bodies of evidence, so I keep one curvature and report the gap.

Chetty's comparison is computed as he computes it: the response of job finding among those who lose their job to a lump sum paid at the start of the spell, against the response to a benefit rise of the same expected cash value, both on the job losers' own spells. The ratio, the model's counterpart of his liquidity share, is 0.19 in France, 0.26 in Germany and 0.30 in Italy against his estimate of about 0.6, and it hardly moves with the curvature (0.25 in Germany at 0.35). Nor does it vary much with the buffer at job loss: among job losers with less than a quarter of a quarter's income in liquid wealth it is 0.18, 0.23 and 0.29, and among the rest 0.20, 0.27 and 0.30. The means-tested floor therefore does not absorb the lump sum, and the small share is not a matter of the poorest. The curvature therefore changes the size of the response and leaves its split between cash on hand and the rest about where it was. Taking dread out of choices leaves Germany's ratio unchanged.

Two of these misses bear on any welfare statement about benefits, and they push in opposite directions. The fall on job loss is four to five times the evidence, so the model overstates what benefits are worth as insurance. Chetty's liquidity share is about half the evidence, so the model attributes too much of the response of job finding to the change in incentives and overstates its cost. The two partly offset, but neither is measured well enough to know by how much, so I treat the model's welfare effects of benefit reforms as illustrations of mechanisms and not as estimates.

## 7.3 The wellbeing account

Version 1's account is kept, with one correction. Version 1's long-term state held every jobless household and charged each the life-satisfaction gap of the unemployed (about 1.06 points at the same income decile, ESS). Version 2 separates the unemployed from the inactive. I estimated the inactive's gap from the same survey with the same controls. Those not looking for work and the sick or disabled lose about as much as the unemployed, those retired early or caring for a household lose nothing, and together the inactive lose 0.14, 0.24 and 0.23 points. The account charges the unemployed their gap and the inactive the pooled one.

| points per head and year | France | Germany | Italy |
|---|---|---|---|
| out of work beyond income, unemployed | -0.068 | -0.029 | -0.074 |
| inactive beyond income | -0.007 | -0.017 | -0.007 |
| dread of a change of status (G+A) | -0.046 (in wellbeing only) | -0.054 | -0.037 |
| of which job search, within the unemployed's term | -0.010 | -0.003 | -0.016 |
| taking part (G+S, Meier and Stutzer 2008) | +0.016 | +0.019 | +0.009 |
| air quality | -0.049 | -0.058 | -0.103 |

The cost of being out of work falls by a third to a half against version 1, most in Germany, where most jobless households are inactive. Dread roughly doubles in Germany, since it now covers the year's lottery at its full size. With the coming quarter's lottery instead, every parameter held, it is -0.026 in Germany and -0.018 in Italy, about half, and Germany's returns to version 1's -0.028. The horizon is therefore what doubles dread. Pagel's weight is estimated at an annual period, which supports the year's lottery, but the quarter's is a defensible alternative and I report both. Among those out of work, dread may overlap with the life-satisfaction gap of the unemployed, which is measured on people who already feel it. Among those in work there is no such overlap, and there dread is 0.012, 0.014 and 0.007 of consumption in France, Germany and Italy. Job search accounts for about a fifth of the unemployed's measured gap in Italy, a seventh in France and a tenth in Germany. At a curvature of 0.35 these shares were two thirds, two fifths and a quarter, since a steeper cost reaches the same exits at a smaller cost in wellbeing, and the unemployed's whole term moved by at most 0.002. The model's own value of belonging is 0.10, 0.54 and 0.17 points a participant against the evidence's 0.055 to 0.081, close in France and Italy and about seven times it in Germany, as in version 1. With all three dimensions on, the terms barely move: in G+S+A every A term lies within 1 per cent of its G+A value, taking part stays at +0.016, +0.019 and +0.009, and G+A's search costs give exits within about 3 per cent of the targets.

## 7.4 Exact switches

Each switch was tested at the calibrated parameters in the three countries. A configuration with a dimension switched off was solved beside the same configuration with that dimension's own parameters taken from the smaller configuration's file, everything else held. In all fifteen pairs every reported result is identical, with search, dread and the participation families on. In two first runs one pair differed slightly, by up to 0.6 per cent in Italy, and agreed exactly in eight reruns. I record it as a numerical caveat whose cause I have not found.

## 7.5 Places on the quarterly economy

E is carried to the quarterly economy as in version 1: each type of place by the degree of urbanisation (cities, towns and suburbs, rural areas) is its own economy under one national tax, at the calibrated G's parameters, with the channels of composition, access to work and commuting. Access to work now acts on the quarterly chain. Each place's chances of leaving unemployment, quarter by quarter, are scaled by its flow from unemployment into work (Eurostat `lfsi_long_e03`, ages 25 to 54, 2015 to 2018) relative to the national flow weighted by the unemployed, and job loss and the flow into inactivity are refitted so that each place has its own unemployment rate and share of jobless households. Eurostat does not publish these flows by degree of urbanisation for Germany, so German places differ through job loss and inactivity only. In rural France and Italy the fitted flow from work into inactivity reaches zero, so their jobless share is the lowest the chain allows rather than the data's. In each of the three countries, three identical places reproduce the national economy exactly, with a largest difference of zero.

| | France | Germany | Italy |
|---|---|---|---|
| hand-to-mouth, nation without E | 0.273 | 0.253 | 0.194 |
| hand-to-mouth, nation with E | 0.276 | 0.253 | 0.194 |
| unemployment, without E and with E | 0.109, 0.117 | 0.098, 0.098 | 0.099, 0.100 |
| hand-to-mouth, cities, towns and suburbs, rural | 0.268, 0.285, 0.275 | 0.236, 0.259, 0.273 | 0.197, 0.193, 0.190 |
| unemployment, cities, towns and suburbs, rural | 0.123, 0.136, 0.092 | 0.130, 0.089, 0.055 | 0.113, 0.094, 0.088 |

With places on, the national targets hold within 0.003, inside the HFCS standard errors, so I do not recalibrate G+E. In France the places' unemployment rates, set from the data, average above the national rate by 0.8 points. The HFCS releases the degree of urbanisation for France only. Among French households not retired, the model's hand-to-mouth share is 0.268 in cities and 0.285 in towns and suburbs against 0.287 and 0.290 in the data, untargeted, but 0.275 in rural areas against 0.187. In my view the rural miss likely belongs with the first limit in Section 8, as wealth the one-asset model cannot show, but I have not tested that. In Germany the hand-to-mouth share and the MPC rise from cities to rural areas while unemployment falls, so composition, through lower incomes, outweighs access there.

With social participation on, each place also has its own community channel, and a solve of G+S+E needs six builds of the households' response to belonging, of 90 to 190 minutes each. I therefore solve it in stages handed from one job to the next (the place configurations, then the first and second pass of every place in parallel, then the aggregates). The stages call the same code as one long solve, and for France G they reproduce it to every reported digit.

| G+S+E | France | Germany | Italy |
|---|---|---|---|
| participation, nation without E and with E | 0.233, 0.230 | 0.279, 0.278 | 0.125, 0.125 |
| participation, cities, towns and suburbs, rural | 0.215, 0.226, 0.250 | 0.275, 0.279, 0.283 | 0.127, 0.124, 0.122 |
| multiplier of participation, with E | 1.36 | 1.43 | 1.20 |

Participation stays within 0.003 of G+S, and hand-to-mouth within 0.001 of G+E, so I do not recalibrate G+S+E either. Participation is highest in rural areas in France and Germany and in cities in Italy, untargeted, and the spread between places is widest in France, at 3.5 points.

G+S+A+E adds dread and job search, at G+S+A's calibration, with France's dread in wellbeing only as before. A single pass for one place can then take more than the six hours a job allows, so each pass saves every education cell it finishes and the next run resumes from them.

| G+S+A+E | France | Germany | Italy |
|---|---|---|---|
| hand-to-mouth, nation without E and with E | 0.271, 0.274 | 0.252, 0.258 | 0.199, 0.199 |
| hand-to-mouth, cities, towns and suburbs, rural | 0.263, 0.282, 0.279 | 0.193, 0.272, 0.358 | 0.193, 0.201, 0.203 |
| participation, nation without E and with E | 0.232, 0.230 | 0.279, 0.278 | 0.125, 0.125 |
| participation, cities, towns and suburbs, rural | 0.216, 0.226, 0.247 | 0.276, 0.278, 0.282 | 0.127, 0.124, 0.122 |
| multiplier of participation, with E | 1.35 | 1.38 | 1.22 |

Places move Germany's hand-to-mouth share by 0.006 here, twice as much as under G+E, which is still inside the HFCS standard error of 0.014, so I do not recalibrate G+S+A+E. The gradient across German places steepens with dread and search, from 0.236 to 0.273 under G+E to 0.193 to 0.358 here. German places differ only in job loss and inactivity, so in my view the steeper gradient reflects precaution: with dread in choices, rural households, who face the lowest risk of job loss, keep the smallest buffers, but I have not decomposed it. Participation by place is within 0.003 of G+S+E in every country and place, and France's hand-to-mouth shares in cities and towns stay within 0.03 of the HFCS, with the rural miss unchanged (0.279 against 0.187).

# 8. Limits and open decisions

I state seven limits. First, the model has one asset. Its hand-to-mouth households are all poor hand-to-mouth, so it cannot show households with housing or pension wealth and little cash, who make up from about a half of the hand-to-mouth among households not retired in Italy to four fifths in France (HFCS 2021) and are concentrated below tertiary education. I tried three two-asset designs on the quarterly economy, and none placed these households by education as the data do. In my view the missing piece is housing with ownership over the life cycle (Kaplan, Mitman and Violante 2020), which is a project of its own, so the two-asset model is set aside. Second, the MPC over twelve months is above the survey in France and Germany, in France by more than double, while the spending profile over five years lies close to the Norwegian lottery evidence. I keep the MPC as a test rather than fit a spread of patience to the survey, because fitting it would move the model away from the evidence on actual spending. Third, the fall on job loss remains four to five times the benchmark. Neither the buffers of those who lose their job nor low patience accounts for it (Section 7.1), and version 1's annual two-asset reference narrows it to 1.6 to 2.5 times, so part of the gap is likely the missing illiquid wealth. Fourth, the response of job finding to entitlement is small and about the same in the three countries, matching Germany, where the curvature was set, and lying below the French and Italian estimates by factors of about two and three, whether tested at the studies' margins or at the calibrated one. Germany's elasticity of time out of work to the benefit level, 0.36, also lies above the European corrected mean. Fifth, the fixed quarterly persistence misses the second autocovariance of income by up to 12 per cent in France and about a quarter in Germany's low-education cell with the benefit profile. Sixth, Italy's patience gap with dread sits at the search's bound, and the budget gap of G+S+A is of order $10^{-4}$ because the floor's tax is set with S off, as in version 1. Seventh, places enter the quarterly economy at the national calibrations, which they leave within 0.006 of their targets, and they miss France's lower hand-to-mouth share in rural areas (Section 7.5).

One decision is settled and one is open. The design's rule is that a country whose quarterly economy cannot meet the annual base's targets stays annual. France meets its targets with dread in wellbeing only, and its MPC test fails by the widest margin, but returning it to the annual economy would lose moral hazard within the spell and the comparison across countries, so France stays quarterly and its dread is reported as a difference of configuration. The inactive's gap is pooled because the model's inactive state cannot be split by main activity, and the alternatives, no gap or the unemployed's, would understate or overstate the cost. As bounds, no gap removes the inactive's term, and the unemployed's gap makes it -0.051, -0.075 and -0.032 points in France, Germany and Italy against the pooled -0.007, -0.017 and -0.007.

# Data

Eurostat: `lfsa_ugad` (unemployment by duration), `lfsi_long_q` (labour market flows, seasonally adjusted), `ilc_lvhl14n` and `ilc_di07` (jobless households and their income). OECD TaxBEN 2023 net replacement rates by month (`DSD_TAXBEN_NRR`). HFCS 2021 (Eurosystem Household Finance and Consumption Survey): this paper uses data from the Eurosystem Household Finance and Consumption Survey. European Social Survey rounds 6, 7, 10 and 11, life satisfaction by main activity, aggregates only. Scripts: `data/labour/duration_flows.py`, `data/benefits/build_floor_and_replacement.py` (part h), `data/ess/ess_inactive_gaps.py`.

# References

Ampudia, M., Cooper, R., Le Blanc, J. and Zhu, G. (2024). MPC heterogeneity and the dynamic response of consumption to monetary policy. *American Economic Journal: Macroeconomics* 16(3). Table 16 read in the working-paper version, BIS Working Paper 1102.

Chetty, R. (2008). Moral hazard versus liquidity and optimal unemployment insurance. *Journal of Political Economy* 116(2), 173-234.

Citino, L., Russ, K. and Scrutinio, V. (2026). Manipulation and selection in unemployment insurance. *Economic Journal*, 136(678), 2092-2130.

Cohen, J. P. and Ganong, P. (2026). Disemployment effects of unemployment insurance: a meta-analysis. *American Economic Review: Insights*, 8(1), 1-18.

Comité d'évaluation de la réforme de l'assurance chômage 2019-2021 (2025). *Rapport final*. Dares, Ministère du Travail, April 2025. Cited as Dares (2025).

Conway, A. (2020). Master's thesis, Sciences Po.

D'Ambrosio, A. and Scrutinio, V. (2022). A few Euro more: benefit generosity and the optimal path of unemployment benefits. CEP Discussion Paper 1835, London School of Economics, also WorkINPS Paper 46 (working paper).

DellaVigna, S., Lindner, A., Reizer, B. and Schmieder, J. (2017). Reference-dependent job search: evidence from Hungary. *Quarterly Journal of Economics* 132(4), 1969-2018.

Druedahl, J. (2021). A guide on solving non-convex consumption-saving models. *Computational Economics* 58, 747-775.

Elsby, M., Hobijn, B. and Şahin, A. (2015). On the importance of the participation margin for labor market fluctuations. *Journal of Monetary Economics* 72, 64-82.

Hubbard, R. G., Skinner, J. and Zeldes, S. (1995). Precautionary saving and social insurance. *Journal of Political Economy* 103(2), 360-399.

Fagereng, A., Holm, M. B. and Natvik, G. J. (2021). MPC heterogeneity and household balance sheets. *American Economic Journal: Macroeconomics*, 13(4), 1-54.

Fuster, A., Kaplan, G. and Zafar, B. (2021). What would you do with \$500? Spending responses to gains, losses, news, and loans. *Review of Economic Studies*, 88(4), 1760-1795.

Kaplan, G., Mitman, K. and Violante, G. L. (2020). The housing boom and bust: model meets evidence. *Journal of Political Economy*, 128(9), 3285-3345.

Kaplan, G. and Violante, G. L. (2022). The marginal propensity to consume in heterogeneous agent models. *Annual Review of Economics*, 14, 747-775.

Kaplan, G., Violante, G. and Weidner, J. (2014). The wealthy hand-to-mouth. *Brookings Papers on Economic Activity*, Spring, 77-138.

Kolsrud, J., Landais, C., Nilsson, P. and Spinnewijn, J. (2018). The optimal timing of unemployment benefits: theory and evidence from Sweden. *American Economic Review* 108(4-5), 985-1033.

Kőszegi, B. and Rabin, M. (2009). Reference-dependent consumption plans. *American Economic Review* 99(3), 909-936.

Le Barbanchon, T. (2016). The effect of the potential duration of unemployment benefits on unemployment exits to work and match quality in France. *Labour Economics*, 42, 16-29.

Lichter, A. and Schiprowski, A. (2021). Benefit duration, job search behavior and re-employment. *Journal of Public Economics*, 193, 104326.

MacQueen, J. (1966). A modified dynamic programming method for Markovian decision problems. *Journal of Mathematical Analysis and Applications* 14(1), 38-43.

Meier, S. and Stutzer, A. (2008). Is volunteering rewarding in itself? *Economica* 75(297), 39-59.

Pagel, M. (2017). Expectations-based reference-dependent life-cycle consumption. *Review of Economic Studies* 84(2), 885-934.

Porteus, E. (1971). Some bounds for discounted sequential decision processes. *Management Science* 18(1), 7-11.

Puterman, M. (1994). *Markov Decision Processes: Discrete Stochastic Dynamic Programming*. Wiley.

Schmieder, J., von Wachter, T. and Bender, S. (2012). The effects of extended unemployment insurance over the business cycle: evidence from regression discontinuity estimates over 20 years. *Quarterly Journal of Economics* 127(2), 701-752.

Scrutinio, V. (2019). The medium-term effects of unemployment benefits. WorkINPS Paper 18 (working paper).

Sovera, A. (2026). Evaluating the impact of unemployment benefit reforms on career stability in Italy: evidence from a regression discontinuity analysis. *International Tax and Public Finance*, online first [volume and pages not yet assigned].

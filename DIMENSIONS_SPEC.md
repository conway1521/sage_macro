# S, A and E: what each dimension is in the model

Written 2026-10-08. One page per dimension: the concept and its source, what the switch changes in the model, what is taken from data, what is fitted, what it reports, what tests it, and what is still open with the options. It states the designs agreed on 27 and 29 September (`AGENCY.md`, `PLAN_AGENCY_V2.md`, `E_PLACE_CONCEPT.md`, `WISE_MAPPING.md`) as they stand in the code today, and adds what the work since has shown. Choices for the author are marked **Decision**, each with a recommendation.

## Rules common to the three

1. **G is the economy.** For each country G reproduces the income distribution, the labour market, the hand-to-mouth share in total and by education, median liquid wealth, hours, and (as tests) the MPC and the fall in consumption on job loss. The wealth distribution is on the two-asset reference.
2. **A switch leaves G intact.** Switching S, A or E on leaves the list above unchanged within tolerance. Each dimension adds its own targets and nothing else.
3. **Off is exactly off.** With a switch off the model is the model without that dimension, to rounding.
4. **Every parameter has a source** (`V3_START.md`, section 34): a published or official figure, a fit to a named moment, a stated normalisation, or a numerical setting.
5. **Each dimension reports recognised indicators** with an official counterpart, so that the Beyond-GDP reader can check it.

## S: social cohesion

**Concept.** Belonging as a local public good: a household gains from taking part, and gains more the more others take part (Snower and Lima de Miranda 2020 for the dimension; Brock and Durlauf 2001 for the interaction).

**What the switch changes.** Each year a household chooses whether to take part in organised voluntary activity.
- Taking part costs time, the measured share of the year it takes.
- It pays a belonging payoff: (level) x (taste of the education group) x (the household's own taste) x (the community fabric). The fabric is a private share plus the rest times the participation rate around the household.
- Participation is therefore a fixed point: the rate people choose has to be the rate they face.
- The unemployed take part at a measured fraction of the rate of the employed.

| | what | source |
|---|---|---|
| from data | time cost of taking part (0.012, 0.047, 0.022 of time in France, Germany, Italy) | time-use surveys (HETUS 2010) |
| from data | participation by education (the targets) | EU-SILC 2015, formal volunteering |
| from data | the unemployed relative to the employed | INSEE, Freiwilligensurvey, ISTAT |
| from data | taste for belonging by education | the share with someone to ask for help, EU-SILC 2015, by education, mean one (re-derived 27 September) |
| fitted | the level of the payoff and the spread of own taste | participation of the two education groups (in G+S+A; G+S fits the level to the national rate) |
| normalised | the weight of belonging in welfare | one |
| not identified | the private share of the fabric (0.30) | none: the multiplier is reported as a band |

**Reports.** Participation by education and by employment status; the social multiplier (how far participation feeds on itself) with its band; the belonging part of welfare.

**Tests passed (version 4; to rerun on version 5).** One stable equilibrium in the three countries. Participation of both education groups on target with A on. In a recession participation falls and recovers.

**Open.**
- **S1, the private share.** It sets the multiplier and no national moment pins it down. Regional differences in participation give a lower bound through E. Proposed: keep the band, and narrow it with the regional evidence once E is rerun.
- **S2, exactly off.** With the measured time cost, 0.2% of households in France (0.03% in Italy) still take part when S is off. Proposed: no participation choice when there is no payoff. One line in the household problem.

## A: agency

**Concept.** Snower and Lima de Miranda (2020, section 3.3) give agency two parts: the ability to influence one's economic fortunes through one's own effort, and freedom from economic hardship. The decisions of 27 September made the first the return to one's own effort and the headline measure protection if the shock hits.

**What the switch changes today.**
- **The return to effort differs by education.** Pay per unit of effort relative to the national mean is 0.86 and 1.27 in France, 0.83 and 1.44 in Germany, 0.90 and 1.46 in Italy (below tertiary, tertiary). With A off both groups earn the mean.
- **Dread of job loss is measured.** The employed bear a cost from their exposure to losing their job (Koszegi and Rabin 2009; Pagel 2017, at the literature's weight). It is counted in wellbeing and does **not** enter choices: when it did, households saved so much that Germany's and Italy's hand-to-mouth shares could not be reached (28 September, on the old inputs).

| | what | source |
|---|---|---|
| from data | return to effort by education | hourly pay by education, Eurostat Structure of Earnings Survey, mean one |
| from data | weight of dread | Pagel (2017) |
| fitted | nothing of its own | |
| in G, not in A | benefits, job-loss and job-finding rates, the means-tested floor, liquid buffers | |

**Reports.**
- **Protection if hit** (headline): return to effort x (1 less the fall in consumption on job loss).
- **Expected loss to unemployment**, the counterpart of the OECD's labour-market insecurity (Cazes, Hijzen and Saint-Martin 2015).
- **The fall in consumption on job loss** itself.
- **Room to manoeuvre**: the share whose liquid wealth covers three months of income, close to How's Life financial insecurity (Balestra and Tonkin 2018).
- **The cost of insecurity** to the employed, in consumption.

**Tests passed.** A widens the gap in participation between the education groups. The policies tried so far (higher benefits among them) all raise protection, so the measure has not yet been seen to fall.

**The open question, A1: what should the switch be?** What A reports is protection, and what determines protection (benefits, risk, buffers) is all in G. The switch itself changes the pay premium, which is a fact about earnings, and a dread term that changes no choice. So switching A on does not add protection to the economy.

| option | the switch | for | against |
|---|---|---|---|
| **1, as today** | pay premium by education, dread measured | A's tested prediction on participation stays A's. Nothing to rebuild | G has no education premium (the permanent income types stand in for it). The switch and the indicators are about different things |
| **2** | premium always in G. A = dread measured in wellbeing | G is a complete economy. A is plainly the security dimension | A changes no behaviour, so the switch is a reporting layer |
| **3** | premium always in G. A = dread in choices | A is the security dimension and acts: households save for peace of mind, and benefits lower dread among the employed as well as the fall for the unemployed | failed once at the literature's weight. Untested on the corrected inputs. Patience would be recalibrated |

**Decision A1.** Recommended: test option 3 on the corrected inputs with one cheap run per country (G+A with dread in choices at the published weight: can the hand-to-mouth share and liquid wealth still be met?). If they can, option 3. If not, option 1 stays, because option 2 leaves a switch that does nothing.

**Also open.**
- **A2, the year of the pay data.** The ratios in use (0.68, 0.58, 0.62) are not those of the 2022 survey recorded beside them in the country table (0.63, 0.59, 0.64). Proposed: the 2022 survey, with the derivation written out.
- **A3, the benchmark.** Protection and expected loss to be set beside the OECD's labour-market insecurity by country as a standing test (`data/validation/agency_benchmarks.csv`).

## E: place and environment

**Concept (agreed 27 and 29 September).** The environment people live in, in two senses. What a place gives (access to work and services, community) against what it costs (commuting, pollution). And the cost side for later and elsewhere: the household's greenhouse-gas footprint.

**What the switch changes.** The country is solved as a set of places of an official geography, each its own economy with its own social fixed point, under one national tax rate. The standard geography is the OECD's large regions (14 in France, 16 in Germany, 21 in Italy). The degree of urbanisation (cities, towns, rural) is the alternative. Places differ through five channels, each set from official data by the same rule in every country:

| channel | what differs by place | data |
|---|---|---|
| composition | share with tertiary education | Eurostat |
| access to work | job-loss and job-finding rates | regional unemployment and its long-term share |
| conversion | what effort yields: income per head over what education and employment predict | Eurostat regional household income |
| commuting | time per unit of work | by degree of urbanisation only. Zero by region: nothing is published |
| community | the private share of the social fabric rises with predetermined community infrastructure, with one elasticity | France: sports facilities built before 1990. Italy: non-profit organisations in 2011. **Germany: no source yet** |

| | what | source |
|---|---|---|
| fitted | the community elasticity (0.4, range 0.3 to 0.5) | volunteering across Italy's regions, **in sample** |
| refitted with places | patience and the other national parameters | the national targets |
| indicators only | footprint per head (consumption times the national intensity). Exposure to pollution by type of place | Eurostat |

**Reports by place.** Participation, protection, the hand-to-mouth share, hours, unemployment. Beside them the footprint and the official exposure to pollution, which enter no decision and no welfare figure.

**Tests.**
- Identical places give back the national economy exactly, and the national moments hold with places on: **passed**.
- Volunteering across Italy's 21 regions, untargeted: correlation 0.67 from the economic channels alone, 0.81 to 0.83 with community. The model's spread is 0.19 to 0.26 against 0.31 in the data: **passed in order, short in size**.
- The hand-to-mouth share across Italy's regions: right order (correlation 0.83), a fifth of the data's spread: **partly**.
- The hand-to-mouth share by type of place in France: the data have most in cities, the model in rural places: **failed**.

**Open.**
- **E1, the natural environment.** Today it is two indicators. (a) Keep them as indicators. (b) Let exposure to pollution enter wellbeing, which needs a published valuation. (c) Split consumption into energy-intensive and other goods, so that a carbon price changes what people buy and not only how much. **Decision E1.** Recommended: (a) for now and (b) once a valuation is chosen from the literature. (c) is a larger build and belongs after the base is closed.
- **E2, what a place costs.** The failed test and the short regional spread point the same way: nothing in the model makes city households hold less liquid wealth. Housing cost is the large cost of place the concept names and the model lacks. Proposed: a sixth channel, housing cost by place from official data (the share of income spent on housing by degree of urbanisation and by region), tested against the HFCS by place. **Decision E2.**
- **E3, the community elasticity** is estimated on the data it explains. Proposed: estimate on Italy with a standard error, test on Germany's Lander against the Freiwilligensurvey once Germany has a source for infrastructure, and on France at a finer geography.
- **E4, order.** E is rerun only when G is closed on version 5, since each place configuration costs hours.

## Decisions taken (8 October 2026)

| | decision | what was decided |
|---|---|---|
| A1 | what the A switch is | **the pay premium by education is in G** (decided the same evening, whatever the test of dread gives). A is the security dimension: dread of job loss and the protection indicators. Dread acting on choices is tested on the corrected inputs and adopted if the hand-to-mouth share and liquid wealth still hold. Later, to restore the other half of the concept (influencing one's fortunes through one's own effort): whether a household can choose its hours, from official data on who decides working time, to be scoped |
| E1 | the natural environment | consequences for wellbeing, not decisions (below) |
| E2 | housing cost as a channel of place | yes, from official data, tested on the HFCS by place. Built when G is closed |
| S1 | the private share of the social fabric | the multiplier stays a band, narrowed with regional evidence once E is rerun |
| S2 | S exactly off | yes |

**E1, as decided.** Neither part of the natural environment is a choice the household makes in this model: there is no moving between places and one consumption good. Both are consequences, the way dread is in A. They differ in who bears them.
- **Exposure to pollution is borne by the household.** It can enter the household's own wellbeing as a measured cost, exactly as dread does, once a published valuation is chosen.
- **The footprint is borne by others, later and elsewhere.** It is counted beside the household's wellbeing, in tonnes first and at official carbon values second, and never added to it (the rule of 29 September, already built).

## What follows from the premium in G

- **Each dimension depends on G alone.** G+S reaches the participation of both education groups without A, since the groups now differ in pay in G. S, A and E are each scoped, calibrated and tested on their own (G+S, G+A, G+E), and the combinations are a check of consistency.
- **A has no calibration of its own while dread is only measured.** A configuration with A reads the file of the same configuration without it and adds the indicators. Four calibrations a country, not eight: G, G+S, G+E, G+S+E.
- **A rule for what a switch may bring** (agreed 8 October): a dimension, or a named combination, may bring the theory it needs. That theory is part of the switch, declared here beforehand with its reason and source, the same in every country, and off still gives the base exactly. The base itself does not change with what is combined.

## A1, tested and adopted (9 October 2026)

Dread acting on choices was tested on version 5 and the wealth moments still hold (exactly in France and Italy, within a standard error in Germany), so it is adopted by the rule agreed: in version 5 A is the dread of job loss in the household's problem at the published weight. A configuration with A is calibrated on its own again (patience and the floor refitted), so a country has eight calibrations, each dimension still sitting on G alone. The cost found by the test: patience falls by 0.02 to 0.03 and the fall in consumption on job loss rises to 0.19, 0.27 and 0.28, further from the literature's 0.07 to 0.16. Reversible by one setting.

## A, settled by the user (10 October 2026)

Job insecurity affects welfare and does not change behaviour: dread of job loss is measured at its published weight and counted in wellbeing, and it does not enter the household's choices. A therefore adds no parameter. A configuration with A reads the calibration of the same one without it and adds the protection indicators and the cost of insecurity. The version with dread in choices (tested 9 October) stays as a variant behind one setting. The other half of the concept, influencing one's fortunes through one's own effort, is to be restored later by choice over hours.

## A, reopened and scoped (11 October 2026)

**Why reopened.** After the decisions of 8 and 10 October the switch changed nothing in the economy: the pay premium had moved to G and dread was counted in wellbeing only. The user, 11 October: "I was wrong to turn it off"; what matters is to "explore properly the existence of A as a dimension and try to get the switch on / off correct". Nothing below is built. It is the scope, for agreement.

**The frame (the user's, after Snower and Lima de Miranda 2020).** Agency is a household's command over its ability to weather shocks such as losing a job. It has two sides.
- **Wellbeing.** Insecurity is a cost in itself: the dread of losing a job, and the cost of being out of work and of staying out of work.
- **Behaviour.** Being vulnerable to job loss changes how much a household works.

**The switch, proposed.** A off is G exactly, as now. A on adds two parts, each with its own source.

| part | what it adds | acts on | parameters and their source |
|---|---|---|---|
| A1, insecurity in wellbeing | (a) dread of job loss among those in work; (b) a cost of being out of work, in the first year and beyond, over and above the income lost | the wellbeing count only | (a) the published weight (Koszegi and Rabin 2009; Pagel 2017), built; (b) a published life-satisfaction estimate of the non-income cost of unemployment, converted at a published income coefficient: to be chosen and checked at the source (the repository's `data/wellby_coefficients.csv` has a candidate marked to confirm) |
| A2, hours as a choice | households with control over their working time choose their hours each year, given their wealth, their pay and their risk; the others work the hours the job sets | the household's problem | the share with control, by education, from Eurostat (below); the elasticity of hours already in the base (psi = 2, a Frisch elasticity of 0.5, the micro consensus of Chetty, Guren, Manoli and Weber 2011) |

**The official figures for A2** (Eurostat `lfso_19fxwt01`, Labour Force Survey module of 2019, employed persons aged 15 to 74; `data/validation/agency_working_time.csv`).

| who decides the start and end of working time | France | Germany | Italy |
|---|---|---|---|
| the person, fully: below tertiary, tertiary | 0.15, 0.25 | 0.16, 0.31 | 0.15, 0.19 |
| the person, with restrictions: below tertiary, tertiary | 0.20, 0.36 | 0.23, 0.41 | 0.10, 0.19 |
| the employer: below tertiary, tertiary | 0.66, 0.39 | 0.61, 0.28 | 0.75, 0.62 |

Control over working time rises with education in the three countries and is lowest in Italy. This gives A back a measured gradient by education, in place of the pay premium that moved to G. One caution: the question is about when one works, not how much. It is the nearest official measure of control over hours by education; a measure of hours wanted against hours worked (`lfso_17cspwt`, involuntary part-time) is the alternative to check.

**What A2 does in the model.** A household that chooses its hours works more when it is poor and when it is exposed, and less when it is comfortable. So it has a second way to absorb a shock beside its savings. Expected, to be tested and not assumed: hours fall with wealth; hours rise with the risk of job loss (precautionary labour supply: Low 2005; Pijoan-Mas 2006; Flodén 2006; Jessen, Rostam-Afschar and Schmitz 2018 estimate its size for Germany); those households respond less in spending to a change in income; protection rises with education because control does. A policy that raises benefits lowers both dread and precautionary hours.

**What it cannot do, to be plain about.** A household out of work cannot work in this model, so hours do not help inside a spell. The channel works before it (buffers built by working more) and after it (rebuilding). The fall in consumption on job loss may ease a little or not at all.

**What has to be built.**
1. The engine solves chosen hours only without the means-tested floor, and the base now has one (the minimum income). Chosen hours with the floor is a change to a solver file: near the floor an extra euro earned is taken back, so a household there stops working, which is the benefit trap and has to be solved and not avoided.
2. Two kinds of household in each education group, those who choose and those who do not, with the official shares.
3. Dread with the state out of work: the prospect of job loss now includes the chance of a long spell.
4. The cost of being out of work in the wellbeing count.
5. A calibration of its own for a configuration with A (patience and its gap refitted, since those who choose hours hold different buffers), as the rule on configurations asks. Eight calibrations a country again.
6. The tests: off gives G exactly; the accuracy check with the hours condition; transitions.

**Risks.**
- **The MPC.** With hours chosen a constrained household meets a windfall partly by working less, which caps its MPC near psi / (psi + gamma) = 0.5. The model's MPC is already below the survey's in Germany and Italy and above it in France. This is why hours were set by the job on 2 October. A share of choosers moves the MPC part of the way.
- **The benefit trap** may bite harder than in the data if every euro earned is withdrawn; official withdrawal rates are below one (the OECD's participation tax rates), which would be one more measured input.
- **Compute** doubles for a configuration with A.

**Choices for the user.**
1. **Who chooses hours.** Those who decide fully (0.15 to 0.31), or those who decide fully or with restrictions (0.34 to 0.72). Proposed: fully as the base, the wider group as a band.
2. **The cost of being out of work in wellbeing.** Include it now as a measured cost, once a published estimate is checked at its source; or leave A1 as dread alone. Proposed: include it.
3. **Dread in choices.** The frame puts behaviour in hours and dread in wellbeing. Proposed: dread stays out of choices; the variant remains behind its setting.
4. **Order.** A feasibility probe first (does a household that chooses its hours solve on the new base, and how large is the response of hours to wealth and to risk at the literature's elasticity), then the engine work, then the calibrations. The probe is `probe_agency_hours.jl`, started on 11 October; it changes nothing in the model.

**The feasibility probe** (`probe_agency_hours.jl`, run 38153101306, 11 October; G of each country as calibrated, the floor off in every solve, so the three columns compare with each other and not with the calibrated economy).

| | France | Germany | Italy |
|---|---|---|---|
| hours of those in work: set by the job, chosen | 0.643, 0.642 | 0.609, 0.610 | 0.726, 0.721 |
| chosen hours, lowest and highest quarter of assets | 0.707, 0.550 | 0.678, 0.521 | 0.829, 0.601 |
| the same with hours set by the job | 0.678, 0.591 | 0.644, 0.562 | 0.771, 0.664 |
| hours when job loss is 1.5 times as likely | +0.4% | +0.4% | +0.6% |
| households with no buffer: job, chosen | 0.359, 0.394 | 0.332, 0.339 | 0.220, 0.233 |
| spending in the first year out of work over spending in work: job, chosen | 0.640, 0.651 | 0.599, 0.614 | 0.652, 0.670 |
| mean spending: job, chosen | 0.565, 0.551 | 0.533, 0.522 | 0.625, 0.614 |

What it says.
1. **It solves.** A household that chooses its hours has a solution on the new base in the three countries, the floor apart.
2. **Hours move with wealth, strongly**: with hours chosen the poorest quarter works 28 to 38% more than the richest. This is the second way of absorbing a shock, and it is large at the base's preferences (the wealth effect on hours is gamma over psi, which is one). The data's relation between hours and wealth is weak, so this is the moment that will discipline A2 and it may ask for fewer choosers or a smaller wealth effect than the literature's elasticity alone implies. To be measured before building: hours by income or wealth in an official source.
3. **Hours rise with risk, a little**: half as much job-loss risk again raises hours by about half a percent, more among the poorest quarter (1 to 2%). Precautionary labour supply is there and small.
4. **Those who can adjust hours hold less buffer**: the share with none rises by 1 to 4 points. Hours stand in for savings, as the literature on labour supply as self-insurance finds.
5. **The fall in spending on job loss eases by 1 to 2 points**, as cautioned: hours do not help inside a spell.
6. **Mean spending is 2% lower with hours chosen at the same mean hours**: hours move from well-paid to poorly paid states, since it is the poor who work more. An output cost of the wealth effect on hours, to keep in view.

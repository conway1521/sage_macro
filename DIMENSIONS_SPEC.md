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

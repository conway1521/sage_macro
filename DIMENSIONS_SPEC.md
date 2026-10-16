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

**Transitions with A (decided by the user, 13 October 2026).** "State the limit for v1, build transitions with A after." In version 1 a policy with A on is a comparison of steady states; the path solver covers A off, with S on or off. Paths with households who choose their hours are the first build after version 1.

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

## E on the base with the state out of work (declared 13 October 2026, before any result)

The place layer is carried to the base as it stands (`v3 = :v5m`), with one addition that the base itself brings and one decision of order on housing.

**The state out of work by place.** The base has a state out of work, sized nationally to the official share of people in jobless households. Places now have it too, by the same rule and closed form: the place's share is the nation's, by education, times the place's official share (Eurostat `ilc_lvhl23n` by degree of urbanisation, `ilc_lvhl21n` by region, 2023) over the population-weighted mean of the places, at the place's own education mix. The national share is unchanged by construction. Job loss and job finding come from the access channel. Where they alone give more than the place's share, the yearly exit is 0.95 and job loss falls to hold the share. Nothing is fitted.

| people under 65 in jobless households, percent, 2023 | cities | towns and suburbs | rural areas |
|---|---|---|---|
| France | 10.4 | 11.5 | 5.8 |
| Germany | 13.1 | 8.9 | 5.5 |
| Italy | 10.2 | 8.5 | 7.6 |

The income process net of job loss stays national: places differ in the risk of losing work, not in the wage risk of those who keep it. The floor is national, as is the tax rate.

**Housing cost (E2), data in and order decided by the theory.** The median share of housing costs in disposable household income by degree of urbanisation is published (Eurostat `ilc_lvho08b`, 2023): France 15.3, 11.2, 9.7 percent (cities, towns, rural), Germany 20.6, 19.4, 17.6, Italy 10.9, 9.6, 9.1. By region France publishes nothing (`ilc_lvho07_r` has Germany and Italy only), so the channel exists by degree of urbanisation alone, as commuting does.

Two versions of the channel are not equal, and this is settled before building:
- **A cost of living proportional to income** (incomes deflated by local prices, Moretti 2013) leaves the hand-to-mouth share where it is. With these preferences saving scales with income, and the floor and the place's incomes are deflated alike. It would shift the weight of consumption against time (the hours of those who choose them, participation), nothing else.
- **A committed amount** (housing as a necessity, a larger share of low incomes; Chetty and Szeidl 2007 on commitments) does change who holds a buffer, but its sign is not given: a commitment raises the buffer a household wants relative to what is left after housing and lowers it relative to gross income, and the floor works the other way again.

So the order is: first the five channels and the state out of work by place, read against the test that failed (hand-to-mouth by type of place in France); then housing as a committed amount, with the before and after. Jobless households are twice as frequent in French cities and towns as in rural places, which is the base's own reason for more households without buffers in cities and was absent when the test failed.

**Tests, restated for the base.** Identical places give back the nation. The national moments with places on, against the tolerances of the calibration, at the national parameters (a refit only if they move by more). Untargeted: hand-to-mouth by type of place against the HFCS (France), volunteering by place, and the regional tests as before.

**Results on the base, France (13 October; `V3_START.md` section 92).**
- Identical places give back the nation: **passed** after a repair (the job's hours of a place were set after the national financing; now before it, as the nation's are).
- National moments with places on, at the national parameters: participation 0.2316 against 0.2331, hand-to-mouth 0.272 against 0.270 by type of place: **inside the tolerances, no refit**.
- Participation by type of place against volunteering, untargeted and out of sample: 1.00, 1.05, 1.21 against 1.00, 1.07, 1.24: **passed**.
- Poverty by region against the official rate, untargeted: correlation 0.97 (0.89 in metropolitan France), spread two thirds of the data's: **passed in order, short in size**. With the conversion channel 0.47: **the conversion channel is not carried to France as it stands** (a uniform scale makes Île-de-France rich, where the official poverty rate is above average).
- Hand-to-mouth by type of place: **failed again**, model 1.00, 1.07, 1.13 against 1.00, 1.01, 0.65 in the HFCS (not retired).

**E2 restated by the data.** In the HFCS (France 2021, not retired) owners are hand-to-mouth alike in every type of place (0.163, 0.170, 0.169). Tenants are not (0.373, 0.458, 0.238), and they are 59%, 42% and 26% of households. The gap holds within education and among those of 40 and over. The missing cost of place is tenure. **Decided by the user (13 October 2026): tenure is not built into E.** Checked for worth first, on the data alone (HFCS 2021, not retired, rows `tenure_nr`, `tenure_inc_nr`, `degurba_inc_nr`, `region_nr`, `region_tenure_nr` of `data/hfcs_targets.csv`):
- tenants are about twice as often hand-to-mouth as owners in the three countries (France 0.370 against 0.167, Germany 0.321 against 0.152, Italy 0.345 against 0.138), and the gap holds within each third of income, so tenure is not a marker of income;
- it is a national fact, so building it would change the base and not only E;
- it explains about two thirds of France's gap by type of place, about a third of France's regional spread, and does not order Germany's or Italy's regions;
- a cross-section cannot separate a committed rent from who becomes an owner.

**The limit, as stated:** the model does not place households without buffers correctly where a place is mostly a large city, because tenants are twice as often hand-to-mouth and the model has no tenure. Joblessness, poverty and participation by place are not affected. **The tenure tables are a validation target for the two-asset reference**, where households with and without an illiquid asset exist. **E2 (housing cost as a sixth channel) is closed without a build.**

**Still open in E:** the conversion channel has to take one form in every country and passes Italy's test while failing France's regional poverty; Germany has no source for community infrastructure; the regional hand-to-mouth tests (the survey has 9 regions for France on the 2013 map, 4 groups of Länder for Germany, 20 regions for Italy).

**The conversion channel, restated and put to a test fixed in advance (agreed with the user, 13 October 2026).** The channel says that the same work yields more or less income in one place than in another: official household income per head over what the place's people would predict, applied to everyone's pay there. As written it left low employment inside the residual, because the model had no jobless households. It has them now, place by place, so the residual is redefined as official income per head over what the model's own place already gives, jobless households included (`:conversion_net`; the floor's top-up left out of the prediction). The same rule in every country.

*The rule, set before the runs:* keep the channel if Germany's overshoot in the regional spread of poverty goes and Italy keeps its gain; drop it from the base's default if the order of regional poverty still falls in any country. Whatever the outcome, Île-de-France (rich on average, unequal inside) belongs to the large-city limit. Official hourly earnings by region (Structure of Earnings Survey 2022, NUTS 1) are a cross-check of direction, not an input: Italy has five macro-areas only.

*Seen before any solve:* the redefinition moves the premiums little (their spread across regions 0.089 to 0.083 in France, 0.057 to 0.054 in Germany, 0.136 to 0.139 in Italy). Counting joblessness twice was a small part of the overshoot. The larger part is that the premium is an average: regional differences in pay are wider at the top of the distribution than at the bottom, where poverty is decided, and a uniform scale gives the bottom the top's difference.

*The outcome (13 October, late):* with the restated channel the order of France's regional poverty still falls (correlation with the official rate 0.44 in metropolitan France, 0.89 without the channel; run 38469136825). **By the rule the channel leaves the base's default.** It stays an option (`:conversion_net`), documented with its tests. The base's places differ by composition, access to work, the state out of work, commuting (by type of place) and community. The cost, stated: Italy's regional gap in poverty is right in order and about a third of the data's size without it.

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

**The data against the probe: hours by wealth in the HFCS** (`hfcs_protocol/hfcs_hours.py`, run locally, aggregates only, `data/validation/hfcs_hours_by_wealth.csv`; persons aged 25 to 59 in work, 2021 wave).

| weekly hours in the main job | France | Germany | Italy |
|---|---|---|---|
| lowest quarter of household deposits | 33.1 | 36.6 | 35.6 |
| highest quarter | 34.1 | 38.5 | 38.7 |
| lowest and highest quarter of net wealth | 33.3, 33.9 | 36.2, 38.7 | 36.5, 38.2 |
| below tertiary, tertiary | 33.5, 34.2 | 37.0, 39.3 | 37.2, 36.8 |
| the model, hours chosen: poorest quarter over richest | +28% | +30% | +38% |
| the model, hours set by the job (the base): the same | +15% | +15% | +16% |
| the model, the base: below tertiary over tertiary | +11% | +14% | +12% |

**What this changes in the scope.**
1. **In the data hours do not fall with wealth.** They are flat or rise a little (3 to 9% from the lowest to the highest quarter). With hours chosen at the base's preferences the model has them fall by a quarter to a third. Built as proposed, A2 would put into the model a behaviour the data do not show.
2. **The reason is the strength of the wealth effect on hours**, gamma over psi, which is one in the base. It is not a parameter anyone chose for this purpose: hours have been set by the job since 2 October, and it only mattered through the job's average.
3. **The base itself has hours by education the wrong way round**: its lower education group works 11 to 14% more than its higher, where the survey has it work the same or up to 6% less. This is a miss of G that no test had looked at. It comes from the same wealth effect, through the hours the job sets. It does not touch the fitted moments (mean effort is fitted, incomes are fitted to the deciles), but it is a property a labour economist would notice.
4. **So A2 needs one more measured input before it is built: the size of the wealth effect on hours.** The clean published evidence is the response of earnings to a windfall (lottery studies: Imbens, Rubin and Sacerdote 2001; Cesarini, Lindqvist, Notowidigdo and Östling 2017, both to be read at the source for the number), which is modest. A cross-section by wealth, as above, mixes that effect with pay (the better paid are wealthier and work no less), so it is a test and not the estimate.
5. **What follows for the size of A2.** With a wealth effect as small as that evidence suggests, hours respond little to vulnerability, and the behaviour side of A through hours will be small. That would be a finding to report as it is. The larger response of a household to vulnerability in this model is its saving, which G already has.

**Choices added for the user.**
5. **The wealth effect on hours.** Fit it to the published earnings response to a windfall, in A2 and in the hours the job sets (which would also be tested against hours by education). This is a change to preferences and so to the base; or leave the base's hours as they are and state the miss. Proposed: read the two sources first and bring the numbers, then decide.
6. **If hours turn out to be a small channel**, whether the behaviour side of A should also carry something else that the data support, to be looked for (the second earner going to work when the first loses a job is the classic one, and the survey could measure it), or whether a small A2 reported as such is the answer.

**The published evidence on how hours respond to wealth, read at the source on 11 October** (`data/validation/labour_supply_evidence.csv`, with what was read and what was not).

| | Sweden: Cesarini, Lindqvist, Notowidigdo and Östling (2017, AER 107(12)), the published article | United States: Golosov, Graber, Mogstad and Novgorodsky (2024, QJE), the authors' draft of January 2023 |
|---|---|---|
| yearly labour earnings per 100 of wealth won | -1.1 for the winner (s.e. 0.15), -1.3 for a married household; at once, and lasting over ten years | -2.3 for the household; -1.3 in the bottom quarter of income, -3.1 in the top |
| earnings response per unit of unearned income | lifetime: -0.17 at age 20, -0.12 at 40, -0.04 at 60 | in the period: -0.50 (consumption +0.60) |
| on the extensive margin | 40% of the five-year response, 24% after ten years | 40% per adult; 58% for low incomes |
| hours | 1.3 a week fewer per million kronor (about 140,000 dollars), 4% of a working week | not reported |
| elasticities | Frisch 0.14, compensated 0.10, uncompensated 0.01 | |
| by education, age, sex | "quite similar"; none by college | larger for higher incomes |
| spouse | responds less than the winner | responds a third as much |

Not read beyond the abstract: Imbens, Rubin and Sacerdote (2001), about 0.11 of unearned income taken as leisure; Jessen, Rostam-Afschar and Schmitz (2018), 2.8% of married men's hours in Germany worked as precaution against wage risk. The American study says of the European ones that they are "consistently and noticeably smaller" than its own and cautions against carrying a wealth effect from one country to another.

**What the base's preferences imply, against these.** With consumption curvature gamma = 2 and hours curvature psi = 2:

| | the base | Sweden | United States |
|---|---|---|---|
| Frisch elasticity, 1 / psi | 0.50 | 0.14 | |
| earnings response per unit of income, a household that spends what it earns, gamma / (gamma + psi) | -0.50 | -0.04 to -0.17 | -0.50 |
| uncompensated elasticity of hours to pay, (1 - gamma) / (gamma + psi) | -0.25 | 0.01 | |

- The base's response to income equals the American estimate and is three to twelve times the Swedish.
- The uncompensated elasticity of -0.25 is what puts hours by education the wrong way round: at France's pay ratio of 1.59 it gives the lower group 12% more hours, and the base has 11%. The Swedish estimate and the HFCS (the same or up to 6% fewer) both say about zero.
- At the Swedish Frisch elasticity (psi = 7) and the same gamma the three become 0.14, -0.22 and -0.11: each closer to the European evidence, the response to income still above its range. The probe is being rerun at that value to read the two cross-sections (run on 11 October).

**The choice this puts to the user (choice 5, restated).** Which evidence disciplines hours in a model of France, Germany and Italy.
- **The micro consensus used so far** (a Frisch elasticity of 0.5): hours fall with wealth and with pay far more than the survey shows, in the base and more so with hours chosen.
- **The European lottery evidence** (a Frisch elasticity of 0.14, one published number in place of another): flatter hours in the base, a smaller and more believable response where hours are chosen, and so a small behaviour side of A through hours. A change to the base's preferences, to be recalibrated and retested.
- Neither removes the wrong sign by education entirely: that needs an uncompensated elasticity of zero, which these preferences give only with gamma at one.

**The probe at the Swedish elasticity** (run 38156361534; psi = 7, the scale of the cost of hours moved so that mean hours stay on target, the floor off as before).

| | France | Germany | Italy | the HFCS |
|---|---|---|---|---|
| the base, hours set by the job: below tertiary over tertiary, at 0.5 and at 0.14 | +11%, +5% | +14%, +6% | +12%, +5% | -2%, -6%, +1% |
| the base: poorest quarter of assets over richest, at 0.5 and at 0.14 | +15%, +7% | +15%, +7% | +16%, +8% | -3%, -5%, -8% |
| hours chosen: the same, at 0.5 and at 0.14 | +28%, +12% | +30%, +12% | +38%, +15% | |
| hours chosen: response to job loss 1.5 times as likely, at 0.5 and at 0.14 | +0.4%, +0.2% | +0.4%, +0.2% | +0.6%, +0.3% | |
| households with no buffer, job-set and chosen, at 0.14 | 0.358, 0.369 | 0.314, 0.319 | 0.217, 0.226 | |
| spending in the first year out of work over spending in work, job-set and chosen, at 0.14 | 0.640, 0.644 | 0.603, 0.609 | 0.653, 0.659 | |

- The European elasticity halves both misses of the base's hours (by education and by wealth) and does not remove them: the sign is still the model's and not the survey's.
- With hours chosen at that elasticity the response to vulnerability is a fifth to a third of a percent of hours, the buffer falls by about a point and spending out of work rises by half a point. **Hours are then a minor way of weathering a shock.** This is what the European evidence says, and it is the honest size of A's behaviour side through hours.

**Decided by the user, 11 October**: the base's hours elasticity moves to the European value (Frisch 0.14; `frisch_elasticity` in `data/manual_inputs.csv`, flagged as a transfer from Sweden). Recalibration started the same day.

**The second earner, scoped (11 October).** Two things, to be kept apart.
- **A partner's existing earnings are already in G.** The household replacement rate in the first year out of work is 0.72, 0.70 and 0.70 (France, Germany, Italy) where the state pays 0.50, 0.48 and 0.47: a partner who keeps working covers about 0.23 of the household's previous income. The weights are Eurostat's (a partner works for 44 to 58% of non-working adults in couples without children and 72 to 77% with children).
- **A partner who starts work, or works more, because the other lost the job** (the added worker effect) is what A could add. The European evidence is that it is small: in Austrian administrative data on husbands displaced by mass layoffs and plant closures, wives' labour supply rises moderately, by entering work, and their added earnings recover only a small share of the household's loss, public transfers and taxes insuring more (Halla, Schmieder and Weber 2020, American Economic Journal: Applied Economics 12(4); the published abstract, the article's tables not read). Across 28 European countries it exists and varies with the welfare regime and the cycle (Bredtmann, Otten and Rulff 2018, ILR Review 71(5); abstract only).

**Conclusion of the scoping of A's behaviour side.** Neither hours nor a second earner is a large way of weathering a job loss in European data. What protects a household is mostly what it already has when the shock comes: public insurance, a partner's existing earnings, savings. All of that is in G. So the behaviour A adds is small in truth, and the model should have it at its measured size and say so.

**Proposed definition of A, to close the scope.**
1. **Insecurity in wellbeing**: dread of job loss, with the chance of a long spell in it, and the cost of being out of work beyond the income lost. The larger part of A.
2. **Hours as a choice for those with control over their working time** (Eurostat's shares by education), at the European elasticity. Small, measured, and it makes the switch change behaviour.
3. **The protection indicators**, as now.
4. **Not built**: the second earner's response (small, and it needs two adults in a household, which the model does not have); dread in choices (the variant stays).

## A, the definition (decided by the user, 11 October 2026)

"yes go ahead with that definition of A". G is not redefined: it is the standard economy, with job-loss risk, public insurance and saving, and the economics of security are in it. A is the security dimension, in four parts.

1. **A wellbeing account.** Insecurity counts: the dread of losing a job, with the fall to assistance after a first year out of work in it, and (to add, once a published estimate is read at its source) the cost of being out of work beyond the income lost. Counted in wellbeing; not in choices.
2. **One margin of choice.** Households with control over their working time choose their hours each year; the others work the hours the job sets. The shares by education are Eurostat's (the person decides fully: 0.146 and 0.250 in France, 0.163 and 0.313 in Germany, 0.154 and 0.191 in Italy; `control_hours_low`, `control_hours_high`), the elasticity the base's (0.14).
3. **A reading of G.** The protection indicators: what the economy delivers by way of security.
4. **Levers that sit in G.** The benefit rate, the minimum income, the risk of job loss, control over working time. With A on, their value for security shows in the welfare count.

S and E change the economy; A changes what counts, and one choice. A off is G exactly.

**What A adds to the list of parameters**: nothing fitted. Two official shares a country and a published weight. So a configuration with A reads the calibration of the same one without it, as before, and the test is that it still meets its targets (the probe at the European elasticity moved the share without a buffer by a point with every household choosing; with a fifth of them choosing it should move by a fraction of that).

**As built** (11 October; `SAGEConfig.control_share`, `control_groups`, `params_of` in `sage_modular.jl`; `apply_floor!` in `egm_core.jl`).
- Households of each education cell come in up to three groups with weights common to the two cells: those who choose in neither cell, those who choose in the cell with the larger share only, those who choose in both. Three times the household problems of G.
- **With the minimum income**: a household that chooses its hours and would be on the floor does not work, since every euro earned is taken back; one that could be on it is on it only if that is worth more than working its way above. The engine refused chosen hours with a floor until now.
- The hours a job asks, and the base of the proportional tax, are those of the economy without choosers.
- Dread for those in their first year out of work now looks to the assistance of the year after, not to their own benefit going on.
- Not covered yet: transitions with households that choose their hours (the path solver refuses them and says so).

**A's first run** (`probe_agency_build.jl`, runs 38170810347, 38170812262, 38170814000, 11 October; G against G+A, each reading G's calibration at the European elasticity). It solved at the first attempt in the three countries.

| | France | Germany | Italy |
|---|---|---|---|
| hand-to-mouth, G and G+A | 0.270, 0.273 | 0.252, 0.255 | 0.206, 0.206 |
| median liquid wealth over income | 0.113, 0.113 | 0.134, 0.136 | 0.249, 0.249 |
| MPC | 0.412, 0.402 | 0.363, 0.355 | 0.351, 0.343 |
| hours of those in work | 0.643, 0.642 | 0.609, 0.608 | 0.725, 0.720 |
| **earnings response to a windfall, per unit** | 0, -0.014 | 0, -0.013 | 0, -0.011 |
| fall in consumption on job loss | 0.300, 0.300 | 0.334, 0.334 | 0.288, 0.287 |
| in-work poverty | 0.091, 0.090 | 0.085, 0.083 | 0.150, 0.150 |
| the budget's gap | 0 | 0 | 0 |
| households who choose their hours | 18% | 20% | 16% |
| of those in work among them, working no hours on the minimum income | 0.3% | 0.3% | 3.7% |

1. **The switch changes behaviour, by a little, and off is G.** The MPC falls by a point; the hours of those who choose respond to a windfall.
2. **G+A still meets G's targets** on G's calibration: the hand-to-mouth share moves by 0.004 at most against a tolerance of 0.02, the median not at all. So A has no calibration of its own, as intended.
3. **An untargeted number lands on the evidence.** The economy's earnings fall by 1.1 to 1.4 per 100 of a windfall in the year. The Swedish estimate, over all winners, is 1.07 (s.e. 0.15). Nothing in A was fitted to it: the shares are Eurostat's and the elasticity the lottery study's own.
4. **The benefit trap is there and small**, except in Italy, where 3.7% of those who choose their hours and have a job work none and live on the minimum income (0.6% of all households). Italy's minimum income is the highest against its median and its low pay the lowest.
5. **The fall in consumption on job loss does not move**, as the scoping said it would not.

**A and S together (12 October).** With A on, social participation rises: in Germany from 0.279 to 0.295 (below tertiary 0.252 to 0.265, tertiary 0.349 to 0.373), in Italy from 0.125 to 0.132. Taking part costs time, and a household that chooses its hours makes that time by working a little less, where one whose job sets its hours has to find it on top. Since control over working time rises with education, **A widens the gap in participation between the education groups** (Germany: 0.097 to 0.108): the prediction the old A made through pay, now made through time.
- This is a prediction, to be tested: participation by control over working time, which the European Social Survey can give (it asks both).
- It means G+S+A read from G+S's calibration overshoots the participation targets by 0.7 to 1.6 points, beyond the tolerance of 0.5. So **a configuration with S and A has a calibration of its own**: G's part and S's two parameters refitted with the choosers in. G+A still reads G. Five calibrations a country without places: G, G+S, G+S+A, and G+A reading G.
- **Households with a job who work no hours** (the benefit trap) are now counted as out of work: the mean hours of those in work are taken over the others, and their share is reported (`idle`). This was Italy's miss of its hours target by 0.0001 beyond tolerance.

## Phase 1 scope: A and E as their own utilities (proposed 14 October 2026, for the user's agreement)

`ROADMAP.md`, phase 1. Version 1 stays one asset and partial equilibrium. Nothing here is built until the user agrees.

### The household's wellbeing, with every term named

Each year a household gets

\[ W = u(c) - v(\text{time}) + \underbrace{\Lambda B Q\, d}_{S} \;-\; \underbrace{D(a') \;-\; k(s) \;-\; \chi\, \mathbb{1}[\text{out of work}]}_{A} \;-\; \underbrace{\textstyle\sum_j \omega_j\, x_{j,p}}_{E}, \]

with time the job's hours (or chosen ones), commuting and participation. Each term either changes choices (its argument depends on what the household does) or changes wellbeing only (it does not).

| term | dimension | argument | changes choices? | strength from |
|---|---|---|---|---|
| belonging \(\Lambda B Q d\) | S | taking part, and how many others do | yes | built; participation by education fitted |
| dread \(D(a')\) | A | next year's chance of losing work and how far income falls, given the buffer carried | yes: saving | Pagel (2017), \(\eta(\lambda-1) = 1.5\), already in `manual_inputs.csv` |
| cost of search \(k(s)\) | A | search effort while out of work | yes: job finding | fitted to the response of unemployment duration to benefits |
| cost of being out of work \(\chi\) | A | being out of work | yes, through search | life-satisfaction evidence (Winkelmann and Winkelmann 1998) |
| place environment \(\omega_j x_{j,p}\) | E | air pollution, access to services, by place | no (no moving in version 1) | life-satisfaction evidence (for air, Luechinger 2009 or Ferreira and co-authors 2013) |
| commuting time | E | time per unit of work, by place | yes: hours where chosen | built |

### A: three pieces

1. **Dread in choices** (option 3 of decision A1, never decided; built and run on 9 October as the variant `SAGE_DREAD_CHOICE=1`). The term is the anticipatory loss of the coming year's employment lottery, in the form of Kőszegi and Rabin (2009) as Pagel (2017) uses it for consumption: weight times q(1 - q) times the utility gap between keeping and losing work at the buffer carried. Households then save for peace of mind, and a benefit lowers dread among those in work as well as the fall for those who lose it. On 9 October Germany and Italy calibrated with it (falls on job loss 0.25 and 0.30, on the old inputs); France failed because its search started from an old file, a fault of the start not of the model. **G+A gets its own calibration** (patience refitted, nothing new fitted).
2. **Search effort**, agency over job loss. Out of work, a household chooses effort s, which raises its chance of finding work (the first year's rate and the exit from the state out of work, by the same rule) at a cost k(s) with one curvature. A off: effort fixed where job finding is the measured rate, so the base is exact. A on: two parameters a country, the cost's level (mean job finding stays the measured rate) and its curvature, fitted to **the response of unemployment duration to the benefit level** (Chetty 2008 for the model; Schmieder and von Wachter 2016 for the estimates, by country where one exists, a flagged transfer where not). Out of work also costs \(\chi\) beyond income, from the life-satisfaction evidence, which raises search: so \(\chi\) is set first, from wellbeing data, and the curvature second, from behaviour.
3. **Hours for those with control over their time**: built (11 October).

**A in wellbeing then has three parts** (dread, the search cost, the cost of being out of work), all valued in consumption and in WELLBYs through the bridge of `data/EVIDENCE_WELLBY.md`.

### E: what changes

- **Behaviour**: as now (composition, access to work, the state out of work, commuting, community). E's behavioural bite grows in version 2 (tenure) and with the labour market in equilibrium (local job finding), not here.
- **Wellbeing**: the place's environment as its own term, for the variables with a published valuation read at the source: air pollution (PM2.5 exposure by region, OECD Regional Well-Being; by type of place, the EU-SILC question on pollution already in the place table) and access to services (unmet medical need for distance, already in the table) if a valuation is found; otherwise it stays an indicator. Commuting stays a time cost; the commuting paradox (Stutzer and Frey 2008) is not added on top, to avoid counting the time twice.
- **Germany's community source**: to be found (community infrastructure per head by Land), or Germany's community channel stays national and is stated.

### The interactions this gives, with no new parameter

- **A with E**: dread differs by place because job loss and the state out of work differ by place; search effort differs because job finding does.
- **A with S**: built (control over time raises participation).
- **S with E**: built (community).

### Tests set before the runs (untargeted)

| | test | data |
|---|---|---|
| A, behaviour | the share of the unemployed out of work for a year or more | Eurostat `une_ltu_a` |
| A, behaviour | the fall in consumption on job loss and the MPC properties still hold | as now |
| A, wellbeing | the life-satisfaction gap between those in and out of work, against the model's in WELLBYs | EU-SILC `ilc_pw01` by activity status |
| A with S | participation by control over working time | ESS |
| E, wellbeing | life satisfaction by type of place and by region, against the model's wellbeing by place | EU-SILC `ilc_pw02` (in the place table); regional where published |
| all | on and off exact; the brute-force benchmark extended to search effort | the test battery |

### Build order inside the phase

1. Dread in choices: repair the calibration's start, recalibrate G+A and G+S+A in the three countries.
2. Search effort and \(\chi\): a change to the household problem of the unemployed in `egm_core.jl` (the transition to work depends on the choice). **The repair of the top of the asset grid (section 100 of `V3_START.md`) goes into the same change**, so one recalibration covers both.
3. E's wellbeing terms: data and valuations, a reporting layer with no recalibration.
4. The tests, the model note, the release of version 1.

### Stop rules

- **Dread**: if a country cannot meet its hand-to-mouth and median targets with dread in choices after patience is refitted, dread stays in wellbeing only there, and that is stated.
- **Search**: where no published duration response exists for a country, the central estimate is transferred and flagged; if the curvature needed lies outside the range the literature reports, the miss is stated, not forced.
- **E**: only variables with a valuation read at the source enter wellbeing; the rest stay indicators.
- **The phase as a whole**: six weeks. What passes by then is released as version 1; the rest moves to the list.

### To read at the source before building (the user's agreement asked)

Pagel (2017) and Kőszegi and Rabin (2009) for dread (Pagel's weight is already in use, read on 8 October); Chetty (2008) and Schmieder and von Wachter (2016) for search, and the country studies they cite; Winkelmann and Winkelmann (1998) for the cost of being out of work; Luechinger (2009) and Ferreira and co-authors (2013) for air quality. Official data through the Eurostat and OECD interfaces: `une_ltu_a`, `ilc_pw01`, regional PM2.5 exposure.

### Phase 1: the evidence read at the source (14 October 2026)

PDFs in the session's reading folders; journal versions where open, else working papers (WP), labelled. The figures I use below were checked in the PDFs.

**Search effort.**
- No quasi-experimental estimate of the response of unemployment duration to the benefit *level* exists for France, Germany or Italy: France's only evaluation (Unédic 2025, official) moves the level and the duration together; Germany's (Hunt 1995) has the wrong sign and is imprecise; Italy's (Rosolia and Sestito 2012, Bank of Italy WP) is a null from a small change. Every country target is a transfer.
- The review: duration elasticity with respect to the benefit level from 0.1 to 2, **median 0.53** over 18 studies (Schmieder and von Wachter 2016, Table 2; WP p. 16, checked). Chetty (2008): hazard elasticity -0.527 (s.e. 0.267), so 0.53 (checked). A meta-analysis corrected for publication bias gives about 0.2 (Cohen and Ganong 2024, WP, publication not verified).
- The curvature of the search cost estimated directly: \(c(s) = k s^{1+\gamma}/(1+\gamma)\), **\(\gamma = 0.40\) (s.e. 0.046)** in the standard model with savings (DellaVigna, Lindner, Reizer and Schmieder 2017, QJE, Hungary; WP Table 3, checked); 0.13 in their hand-to-mouth version.
- Cautions: about 60% of the response is liquidity, not moral hazard (Chetty 2008), so the curvature is only right if the model's buffers among the unemployed are; European estimates mostly measure non-employment, not insured spells; in Italy many unemployed draw no benefit.

**The cost of being out of work and of insecure work.**
- Unemployment, holding income: Winkelmann and Winkelmann (1998, Economica; fixed-effects logit, GSOEP 1984 to 1989, men): -0.958 (0.204), about seven times the log-income effect. On the 0 to 10 scale with fixed effects and income in the same regression: men -1.17 (0.09), women -0.43 (0.09) (Clark, Knabe and Rätzel 2010, Labour Economics; IZA WP, Table 3). France, pooled and official: -0.62 (INSEE Analyses 71, 2022). No peer-reviewed estimate for Italy.
- Insecure work, among the employed: "concerned about job security" men -0.35 (0.03), women -0.20 (0.04), same regression (Clark, Knabe and Rätzel); perceived chance of losing the job, -0.23 per unit of probability (Green 2011, JHE, Australia). The evidence is for **perceived risk, not contract type**: fixed-term contracts are insignificant within person (Dawson, Veliziotis and Hopkins 2017, BHPS). So precarious work is modelled through the chance of losing the job, which is how dread works.
- Our own data test agrees in size (`data/validation/ess_life_satisfaction.csv`, cross-section): unemployed -1.06, -1.06, -1.05; limited contracts -0.21, -0.20, -0.27 (France, Germany, Italy).
- **Dread's weight, checked in the published version (15 October 2026).** Pagel (2017), *Review of Economic Studies* 84(2), 885 to 934: the calibration is \(\eta = 1, \lambda = 2.5\) (caption of Figure 1, p. 899, chosen in line with the micro and experimental evidence of her section 2.3.2), so \(\eta(\lambda-1) = 1.5\), the value in use; the structural estimates are \(\eta = 1.16\) (s.e. 0.111) and \(\lambda = 3.11\) (0.682) (Table 1, p. 910), so 2.45. The author's copy read on 14 October was an earlier draft with other numbers. The weight stays 1.5, with 2.45 as the top of a band.

**Air quality.**
- No peer-reviewed European valuation of PM2.5 with an income coefficient was found. Luechinger (2009, EJ; WP) values SO2 in Germany (IV -0.008 per µg/m³, log income 0.548: €313 per µg/m³ per household a year). Ferreira and co-authors (2013, Ecological Economics; WP) value SO2 across 23 countries in the ESS (-0.021 per µg/m³, log income 0.372). Ferreira and Moro (2010) value PM10 in Ireland, weakly (p < 0.10, one cross-section).
- Official data: population-weighted PM2.5 by TL2 region for France, Germany and Italy, 1990 to 2020 (OECD `OECD.ENV.EPI,DSD_AIR_POL@DF_AIR_POLL`); Eurostat publishes none by region. Nothing values access to services in life-satisfaction terms.

**Air quality estimated (14 October 2026; decided by the user: "yes ferreira 2013").** `data/environment/ess_pm25_life_satisfaction.py`, the method of Ferreira and co-authors (2013) on ESS rounds 6, 7, 10, 11 for the three countries, matched to OECD regional PM2.5 (24,568 respondents, 52 regions; results in `data/environment/pm25_valuation.csv`).
- With country-by-round dummies (their specification, without their climate controls): **-0.036 (s.e. 0.014) per µg/m³**, log income +1.03 (0.05), so one µg/m³ is worth about 3.5% of income. Same sign as theirs for SO2 and of the same order (0.021/0.372, about 5.7% per µg/m³ of SO2); larger than Luechinger's quasi-experimental 1.5% for SO2.
- With region dummies as well (the effect read from changes within regions over time): +0.029 (0.059), nothing. The estimate rests on differences between regions within a country, which may carry other regional differences; the within-region changes, 2012 to 2020, are too small and too common to identify it.
- ~~Decided by the user (14 October): a band from zero to the cross-regional value (3.5% of income per µg/m³).~~ **Replaced by the user (16 October): E's air-quality term enters as the band of Menz and Welsch (2010, Ecological Economics 69(12)), 0.3% to 0.8% of income per µg/m³ of particulates**, their preferred specifications, 25 OECD countries including France, Germany and Italy; every result involving air quality is shown at both ends. Our cross-regional ESS estimate (3.5%) is kept as an upper check: it sits on the specification they reject. Their pollutant is PM10 and the regional exposure series is PM2.5; the band is applied per µg/m³ of PM2.5, a stated transfer.
- The social cost of carbon stays beside wellbeing, never in it (decision E1 of 29 September): emissions priced as a separate line, damage-based values as a band (official German value, Rennert and co-authors 2022) and the French target-based value as an alternative, to be read at the source; a secondary line in version 1, since with one good emissions move only with total consumption.

**The published versions checked (16 October 2026; the PDFs in the user's `sage_sources` folder).**
- **Search curvature corrected: 0.35, not 0.40.** DellaVigna, Lindner, Reizer and Schmieder (2017, QJE 132(4)), Table I column (1), p. 2000: \(\gamma = 0.35\) (s.e. 0.04) in the standard model with savings (three cost types, 15-day discount factor 0.93); the 0.40 was the working paper's. The elasticity of search effort to the value of work is \(1/\gamma\), about 2.9. The hand-to-mouth 0.13 is not in the published paper. The model's default is now 0.35; the first runs at 0.40 serve as a sensitivity.
- Confirmed as used: Chetty (2008) -0.527 (0.267) and the 60% liquidity share; Schmieder and von Wachter (2016) the median 0.53 over 18 studies (the European median for potential duration is 0.40, not 0.37); Pagel (2017) as recorded; Luechinger (2009) and Ferreira and co-authors (2013) as recorded (Luechinger's income coefficient is instrumented, about 0.15 by OLS, which halves or thirds any valuation that uses it); Clark, Knabe and Rätzel, working paper, as recorded (effects at zero regional unemployment).
- **Menz and Welsch (2012) value SO2 and NO2, not particulates**, from national means, 1990 to 1997, without Italy: no use for E's PM2.5 term.
- **Dolan and Laffan (2016, UK, PM2.5)**: -0.017 (0.005) per µg/m³ on the 0 to 10 scale, about half our cross-regional -0.036; their money values rest on a linear income term for employees and they expect instrumented values under half as large. A check on the size of ours, consistent with the band from zero.
- Rennert and co-authors (2022): USD 185 per tonne of CO2 (2020 dollars, near-term rate 2%), 5 to 95% range 44 to 413.

**ThreeME (OFCE and ADEME), looked into at the user's request (16 October 2026).** A multi-sector neo-Keynesian model with bottom-up building and vehicle stocks, built for France (versions for Mexico, Indonesia, Tunisia and the Netherlands; none published for Germany or Italy); open code (GPL-3, EViews) at github.com/ThreeME-org/ThreeME_V3-open; documentation Reynès, Callonnec, Saussay and co-authors (2021, *ThreeME Version 3: a full description*); a peer-reviewed use, Malliet, Reynès, Landa, Hamdi-Cherif and Saussay (2020, *Environmental and Resource Economics*).
- **No local air pollutants and no health or wellbeing valuation**: greenhouse gases only (CO2, CH4, N2O, F-gases, IPCC factors scaled to Eurostat). Nothing for E's particulate term.
- **One representative household** in the open code. The French distributional work is a separate CIRED and ADEME project: Engel curves by decile and household type from the Budget des Familles surveys (Nadaud 2020, CIRED working paper 2020-81), used in Ravigné, Ghersi and Nadaud (2022, *Ecological Economics* 196).
- **What E could take later (option E1(c), the split of consumption into energy-intensive and other goods)**: ThreeME's top nest (housing, transport, other goods) as a template; its pass-through of a carbon price to each good's price as an outside input; Nadaud's French elasticities by decile; emission intensities recomputed from Eurostat and IEA by ThreeME's method. The incidence by income and place has to come from household budget surveys, not from ThreeME, and its consumption block does not save, which a Bewley model must keep its own.

**More published sources read (16 October 2026).**

*The fall in consumption on job loss: the benchmark replaced.* The range "0.07 to 0.16" was never in a source (it looks assembled from Gruber's 6.8% and Browning and Crossley's 14%). The sourced benchmark:
- **Kolsrud, Landais, Nilsson and Spinnewijn (2018, AER 108(4-5)), Sweden, registers, total consumption, replacement rate 72%**: 0.054 (s.e. 0.001) in the year unemployment starts (Fig. 5, p. 1026); 0.044 in the first 20 weeks and **0.091 (0.005) after 20 weeks** (Fig. 6A, p. 1027); 0.08 (0.01) over the spell (Table 3, p. 1031); **about 0.10 in a second year out of work** (p. 1010). The European anchor.
- Browning and Crossley (2001, JPubE 80), Canada: 14% of total spending (about 12% of the level before) at about 26 weeks out of work (pp. 9 to 10); median 3.1%.
- Gruber (1997, AER 87(1)), US food: 6.8% (p. 195); 0.22 to 0.26 at zero replacement (Table 1, p. 196); 0.35 for those still out of work a year later (Table 3, p. 200).
- Ganong and Noel (2019, AER 109(7)), US nondurables: 6% at onset, 12% more at benefit exhaustion (p. 2396).
- **Reading for the model**: its fall over a first full year out of work (0.21 in the base, 0.29 with dread) is about twice Kolsrud's 0.09 to 0.10 for spells of that length at a similar replacement rate; its quarterly fall in the probe (0.07 to 0.09) is about twice Kolsrud's 0.044 for the first 20 weeks. So the model's households smooth job loss about half as well as Swedish data show, at both horizons: the period explains part of the gap to the old range, not the factor of two.

*Air quality: a published value.* **Menz and Welsch (2010, Ecological Economics 69(12))**: PM10, 25 OECD countries including France, Germany and Italy, 1990 to 2004, country fixed effects: -0.005 to -0.006 per µg/m³ on a 1 to 4 scale (Table 3, p. 2587), about -0.017 to -0.020 on 0 to 10 once rescaled, close to Dolan and Laffan's -0.017 for PM2.5; willingness to pay **0.3% to 0.8% of income per µg/m³** in their preferred specifications (p. 2586; Table 4). Their specification without lagged income gives 3.2%, which they reject as implausible; our cross-regional 3.5% sits on it. So the top of E's air-quality band at 3.5% is not supported. PM10 against PM2.5 (the fine part of PM10) is not settled by these sources.

*Wellbeing of S and E.* Meier and Stutzer (2008, Economica 75): volunteering weekly or monthly raises life satisfaction by 0.055 to 0.081 points (0 to 10) with fixed effects, 0.24 in the natural experiment of East Germany's reunification (Table 2, p. 51); no money value printed. Stutzer and Frey (2008, SJE 110(2)): one hour of commuting each way lowers life satisfaction by 0.20 points with fixed effects (Table 1, p. 350); their money value (35% of labour income for 22 minutes) rests on an unpublished income regression and they warn against reading it literally.

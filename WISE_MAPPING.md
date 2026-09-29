# Model outputs mapped to Beyond-GDP indicators (draft, 2026-09-28)

For users from the wellbeing-measurement community (OECD How's Life / WISE, the Snower and Lima de Miranda dashboard). Each row names the model output (the field of `solve_economy`) and its closest indicator counterpart.

- **Every output is also available by group:** education cell (`pooled[g]`), employment status (`rate_E`, `rate_U` and the employed masks), and wealth, through the stationary distribution. Inclusion and equality therefore come with every row.
- **The indicator names follow the OECD How's Life framework.** They must be checked against the current edition before publication.

## Material conditions (G)

| model output | what it is | indicator counterpart |
|---|---|---|
| `mean_income`, `median_income` | labour and benefit income, model units | household disposable income (level relative to the country's mean, not euros) |
| `mean_labour_income`, `mean_effort_employed` | earnings, and the paid share of committed time | earnings; time in paid work (HETUS) |
| `unemployment`, `1 - unemployment` | the unemployment rate | employment and unemployment rates |
| `hand_to_mouth_kvw` | wealth at most one week of own income (Kaplan, Violante and Weidner 2014) | financial fragility; the HFCS liquidity indicators |
| `wealth_p50`, `wealth_p90` | wealth distribution | household wealth, wealth inequality |
| `mpc`, `mpc_htm` | spending out of a one-month windfall | untargeted check against Jappelli and Pistaferri (2014) and the HFCS spending question |

## Agency (A)

| model output | what it is | counterpart |
|---|---|---|
| `alpha` by cell (input) | the return to one's own effort, relative to the national mean | the education earnings gradient (SES) |
| `A_cond` (headline) | alpha × (1 - consumption drop on job loss) | SAGE agency, protection if hit: no single How's Life indicator |
| `shock_loss_income` | expected share of income lost to unemployment, institutions only | **labour-market insecurity** (OECD; Cazes, Hijzen and Saint-Martin 2015): the direct counterpart |
| `shock_loss`, `A` | the same for consumption, including own savings, and alpha × (1 - that) | SAGE agency, expected-loss reading |
| `consumption_drop` | drop in consumption at job loss | the consumption-smoothing literature (Gruber 1997; Ganong and Noel 2019; INSEE 2024 for France) |
| `room` | share whose liquid wealth covers 3 months of own income | close to How's Life **financial insecurity** (lacking liquid assets to cover three months at the poverty line): `1 - room` is the counterpart |
| `dread_cost_E` | the consumption-equivalent cost of insecurity for the employed | life-satisfaction studies of job insecurity (Carr and Chung 2014): about 1 to 2 percent |

## Social connection (S)

| model output | what it is | indicator counterpart |
|---|---|---|
| `rate`, `rate_E`, `rate_U`, by cell | formal volunteering | volunteering (EU-SILC ad hoc modules 2015 and 2022; How's Life social connections) |
| B by cell (input) | taste for belonging | having someone to count on (EU-SILC ilc_scp15; How's Life social support) |
| the social multiplier | how far participation feeds on others' participation | no indicator: a structural quantity, reported as a range |

## Place and environment (E): why these variables (2026-09-29)

E does not choose its own variables. Three official frameworks choose them:
- **The place typology:** the Degree of Urbanisation (cities, towns and suburbs, rural areas). It was endorsed by the UN Statistical Commission in 2020 as the international standard, and Eurostat publishes it for every indicator below.
- **What varies by place:** the eleven topics of the OECD Regional Well-Being framework, with the OECD's own headline indicators (OECD Regional Well-Being: a user's guide, version October 2025, Table 2).
- **Where sustainability sits:** the Conference of European Statisticians' Recommendations on Measuring Sustainable Development (UNECE, Eurostat and OECD, 2014). Wellbeing is split into here and now, later, and elsewhere. E version 1 is the here and now of place. Later and elsewhere are the sustainability cost side.

**The rule.** Every place-varying topic is one of four things:
- an **input** to a channel, taken from data;
- a **test**, an outcome the model predicts by place and the data check;
- **reported** beside the model;
- **out of scope,** with the reason.

Inputs are not tests: a variable used to set a channel cannot also validate it.

| OECD topic (headline indicator) | E version 1 | model object | by degree of urbanisation (Eurostat) |
|---|---|---|---|
| Income (household disposable income) | input: the conversion premium c_p, net of education mix | alpha by place | median equivalised income, ilc_di17 |
| Jobs (employment and unemployment rates) | input: access channel | job finding and separation by place | unemployment rate, lfst_r_urgau; quarterly flows, lfsi_long_e03 and lfsi_long_e04 |
| Education (share with at least upper secondary) | input: composition | education cells by place | tertiary share, edat_lfs_9913 |
| Access to services (broadband; download speed) | reported beside c_p as its candidate mechanism | inside the conversion premium | households with broadband, isoc_ci_it_h |
| Community (someone to rely on in case of need) | test | local participation and the community fabric | someone to ask for help, ilc_scp16; formal volunteering, ilc_scp20 (also a test) |
| Life satisfaction (0 to 10) | test, through the WELLBY overlay | wellbeing by place | overall life satisfaction, ilc_pw02 |
| Environment (PM2.5 exposure) | reported (amenity) | none in choices | pollution and grime, ilc_mddw05. PM2.5 by degree of urbanisation from the EEA/JRC grids is to be sourced. |
| Health (life expectancy; mortality) | access part reported; health as a state out of scope | none | unmet medical need because too far, hlth_silc_21. Life expectancy by urbanisation is not published. |
| Housing (rooms per person; affordability) | out of scope in version 1: no housing market. Planned as housing by place, the illiquid asset | later | housing cost overburden by degree of urbanisation (to collect) |
| Safety (homicide rate) | out of scope: nothing in the model responds to it | none | crime, violence or vandalism in the area (EU-SILC; to collect and verify the table code, reported only) |
| Civic engagement (voter turnout) | out of scope: S models social participation, not voting | none | none by urbanisation |

Not an OECD topic, but part of the access channel: commuting time, an input (lfso_19plwk28, by place and education).

| CES dimension | E |
|---|---|
| here and now | E version 1: access, conversion, community, amenities |
| later (capital stocks, including natural capital) | out of scope in version 1. The cost side, emissions from consumption and commuting, comes next and needs a household footprint source. |
| elsewhere (transboundary effects) | out of scope. Consumption footprints would carry it later. |

**What counts as enough.**
- Every OECD topic sits in one of the four categories.
- Three topics are tests: community, volunteering and life satisfaction.
- Four are out of scope, each for a stated reason.
- None is chosen because it helped the fit.

## Not in the model

- **Subjective wellbeing.** Life satisfaction is not modelled. The overlay route (WELLBY weights) is in the plan.
- **Health, housing, safety, knowledge and skills.** These enter only through inputs (alpha, the income process) if at all.

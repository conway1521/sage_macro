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

## Place and environment (E, planned)

| planned output | counterpart |
|---|---|
| participation, unemployment and savings by place type | the same indicators by degree of urbanisation (Eurostat) |
| omega by place (community infrastructure) | facilities and associations per head (INSEE BPE, the associations register, ISTAT) |
| pollution exposure by place (amenity) | exposure to air pollution (EEA; EU-SILC ilc_mddw05) |
| commuting time | time use: commuting (LFS 2019 module) |
| emissions from commuting and consumption (the sustainability side) | household greenhouse-gas footprint (to source) |

## Not in the model

- **Subjective wellbeing.** Life satisfaction is not modelled. The overlay route (WELLBY weights) is in the plan.
- **Health, housing, safety, knowledge and skills.** These enter only through inputs (alpha, the income process) if at all.

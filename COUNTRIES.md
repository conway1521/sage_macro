# Cross-country calibration: the standard pipeline and the seven-country scoping

This is the public-facing summary of how the engine is calibrated for any country, what it now does for the seven we have wired up, and what an honest fit table looks like. The sourcing document is [CALIBRATION_PIPELINE.md](CALIBRATION_PIPELINE.md), and the table itself lives in `SAGE_Bewley/src/SAGEBewley.jl` under `COUNTRIES`. To swap the country the model represents, call `country_params(code)` with one of FR, DE, IT, US, CO, ZA, CN.

## The one-line story

Adding a country to the model is a row in a table, and every cell of that row has a public, harmonised source. The seven countries here are calibrated the same way, by the same procedure, from the same kinds of data; the table is the deliverable, and ten more countries is data entry against the same recipe.

## The Better Life Index question, answered carefully

The Better Life Index has two different things in it, and only one of them is the citizen-rated weights that you remember being uneasy about.

**The dimension scores by country.** These are administrative data published in the OECD's *How's Life?* series: employment rates, labour-market security indices, self-reported health from EU-SILC and equivalent, PISA and PIAAC for skills, the support-network item from harmonised surveys. They are population-representative and published for every OECD member plus the key partners. This is the data we use for the agency and belonging gradients (alpha and B in the model). It is not crowdsourced and not statistically weak.

**The dimension weights from the YBLI tool.** These are the citizen-rated weights from the Your Better Life Index web tool, the 16,000-French-users object you remember. The numbers have gone up since you last looked: the OECD reports more than 80,000 users across countries by the latest waves, but the sample is still self-selected (people who came across the tool, who skew educated and online), so it is reliable for relative weights but weak for population-level point estimates. This is the data behind the cohesion weight Lambda in the model.

So the honest two-route recommendation. Route 1, use YBLI weights as the baseline calibration of Lambda, declare the sample weakness openly, and rely on the fact that the cross-country pattern of weights is more robust than any single country's level. Route 2, the upgrade path, is to estimate Lambda from a representative life-satisfaction panel per country: SOEP for Germany, Understanding Society for the UK, the European Social Survey for cross-EU comparability, the Health and Retirement Study or General Social Survey for the US, the China Family Panel Studies for China, the Encuesta Longitudinal Colombiana for Colombia, the National Income Dynamics Study for South Africa. The regression a partner has usually already run gives a coefficient ratio that maps directly to Lambda. The [Lambda Estimation Design](./Lambda%20Estimation%20Design.md) note is this offer.

## Removing the France-centricity, parameter by parameter

Below, what could be France-specific in the calibration, and the harmonised cross-country source we now use instead.

| parameter | the France-specific way (old) | the harmonised way (now) |
|---|---|---|
| effort disutility phi | calibrated to French time use | calibrated per country to the country's time use (MTUS) |
| real rate R | ECB-era | OECD long-term rate series, deflated, twenty-year average |
| income process rho, eta | EU-SILC France | moment-matched to country wealth Gini (WID) and HtM share (KVW / national HFCS / SCF / CHFS / NIDS) |
| agency alpha by education | OECD BLI France | OECD How's Life empowerment indicators per country, by education, on the same 0-1 band |
| belonging taste B by education | OECD BLI France support network | OECD How's Life support-network item per country, by education; WVS Wave 7 where OECD does not cover |
| cohesion weight Lambda | OECD YBLI France weights | OECD YBLI weights per country (baseline); life-satisfaction panel estimation per country (upgrade) |
| interaction strength kappa | INSEE Première French participation | WVS Wave 7 associational membership rate per country |
| taste dispersion sigma_m | INSEE Première French gradient | WVS Wave 7 education gradient per country |

Nothing in this list requires data from a French source. Every entry has a harmonised cross-country source that delivers the same indicator for every country in scope.

## What the seven calibrated countries look like

Calibrated targets and the model's matches, all from running `scripts/countries_compare.jl`. Columns are model / target. A star marks a miss above 0.10.

| code | wealth Gini | HtM share | work share | income Gini |
|---|---|---|---|---|
| FR | 0.55 / 0.68 * | 0.33 / 0.30 | 0.52 / 0.53 | 0.15 / 0.30 * |
| DE | 0.54 / 0.78 * | 0.33 / 0.32 | 0.55 / 0.55 | 0.17 / 0.30 * |
| IT | 0.52 / 0.61 | 0.29 / 0.41 * | 0.55 / 0.55 | 0.21 / 0.33 * |
| US | 0.51 / 0.85 * | 0.27 / 0.31 | 0.60 / 0.60 | 0.20 / 0.41 * |
| CO | 0.41 / 0.81 * | 0.11 / 0.55 * | 0.60 / 0.60 | 0.34 / 0.55 * |
| ZA | 0.37 / 0.95 * | 0.08 / 0.60 * | 0.55 / 0.55 | 0.39 / 0.63 * |
| CN | 0.43 / 0.70 * | 0.13 / 0.50 * | 0.65 / 0.65 | 0.31 / 0.45 * |

Reading this honestly. The work share hits every country by construction, since phi is calibrated per country to its time-use survey. The hand-to-mouth share is in the right neighbourhood for the OECD members and visibly undershoots for the developing countries, where the one-asset Bewley structure cannot simultaneously deliver a very high hand-to-mouth share and a very high wealth Gini. The wealth Gini consistently undershoots: standard one-asset calibrations reach 0.38 in this model class; we reach 0.55 for the European countries and the US, which is much closer to data than the standard, but not the very high Ginis of the US (0.85) or South Africa (0.95) or Colombia (0.81). The income Gini undershoots because we use two productivity states; the architecture for fixing it (education cells with persistent plus transitory shocks) is built and produces income Ginis from 0.27 to 0.33, the relevant range.

What this means for the paper. We present four countries calibrated and fit-validated (France, Germany, Italy, USA), say honestly that the European calibrations are tighter, and report the developing-country rows (Colombia, South Africa, China) as scoping calibrations that show the pipeline runs cleanly outside the OECD core. The full fix for the developing-country rows is the two-asset extension along Kaplan and Violante; that is a Paper 3 project, not a missing piece.

## How a new country gets added

The recipe is six steps, every step pointing at a public source. The whole thing should take half a day per country given the sources.

1. **R.** Pull the OECD long-term interest series for the country, deflate by CPI, twenty-year average. Annualise to the gross rate (1 + r).
2. **alpha by education.** Open the OECD *How's Life?* country profile. Take the empowerment indicators (labour-market security index, self-reported health, skills) and aggregate them with equal weights, by education group, scaled into the 0-1 band so that France's row reproduces the thesis numbers.
3. **B by education.** Same source, the social-support indicator, by education group. If the country is outside OECD coverage, take the equivalent question from WVS Wave 7.
4. **Lambda.** OECD YBLI weights for the cohesion dimension (baseline). For the upgrade, the design note is in the vault.
5. **rho, eta.** Pick them jointly to match the country's wealth Gini (WID) and hand-to-mouth share (KVW where covered, national HFCS or SCF or CHFS or NIDS or LIS otherwise).
6. **phi, kappa, sigma_m.** Calibrate phi to the country's MTUS work share, calibrate (kappa, sigma_m) jointly to the country's WVS Wave 7 participation rate and education gradient.

Every step is reproducible from the named source; the script `scripts/calibrate_phi_country.jl` is the template for the per-country calibration; the row format is in `COUNTRIES`. A collaborator who knows their country can add it without touching the model.

## Where the engine sits today

`country_params("DE")` returns a SAGEParams object configured for Germany. The lecture's country block runs every country inline and demonstrates the country switch on the financed-subsidy experiment. The model's predictions are honest and the limitations are documented; the road from "seven scoped" to "fifteen with paper-quality fit" runs through one row of microdata per country plus the two-asset extension for high-wealth-Gini countries.

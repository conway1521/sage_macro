# A standard cross-country calibration pipeline

This document fixes one question once. For any country, where does each parameter come from? The answer is the same sources for every country, so a row in the country table is filled the same way wherever it is filled. The pipeline is the deliverable. Calibrating ten more countries after this is data entry, not modelling.

The audience is a careful reader who wants to know that nothing is France-specific by accident, and a future collaborator who wants to add their country in an afternoon.

## The structure: what is universal and what is country-specific

The model has three layers, and they parametrise differently.

**Universal layer.** Preference parameters that the meta-analytic literature treats as human, not national. Risk aversion gamma = 2 (Havránek 2015 across 41 countries, no significant cross-country heterogeneity in the corrected mean). Labour-supply responsiveness psi = 2 (Chetty et al. 2011 across the OECD, the intensive-margin Frisch consensus). Patience beta = 0.96 (the annual heterogeneous-agent standard). The participation lump qbar = 0.10 (time-use order of magnitude across countries with comparable surveys). Sweep parameters omega and h (no country pins them yet, swept openly).

**Country-specific layer.** Six numbers that genuinely differ across countries: the real interest rate R, the income process (rho, eta), agency by education group (alpha_low, alpha_high), the belonging taste by education group (B_low, B_high), the cohesion weight Lambda, and the participation calibration (kappa, sigma_m). All of these come from harmonised cross-country sources, so the same table can be filled the same way for every country.

**Country-specific by calibration target.** The effort disutility phi is universal in form but calibrated per country to that country's paid-work share of committed time from its time-use survey.

## Each parameter's source, the same for every country

The default source is the cross-country one. The national alternative is named when it gives a better number. A row is filled by following the table.

### R, the long-run real interest rate

Primary source: the OECD long-term interest rate series, deflated by CPI inflation expectations, averaged over the most recent twenty years. Alternative: the Holston-Laubach-Williams natural-rate estimates for the countries they cover, IMF World Economic Outlook real rate annexes for the rest. The choice is documented per country but always uses the same procedure.

### Income process, rho and eta

Primary procedure: pick rho and eta jointly to match two country moments, the wealth Gini and the hand-to-mouth share, both with universal sources below. This is moment-matching, not direct estimation, and it is the standard heterogeneous-agent practice when individual earnings panels are not available. Where they are available (PSID for the US, SOEP for Germany, EU-SILC for the European Union members, CHFS for China), the direct estimates are reported as a cross-check.

### Wealth Gini target

Primary source: the World Inequality Database at wid.world. Universal, harmonised, free, publicly hosted, updated annually. This is the right source precisely because it is the same source everywhere. Alternative: Credit Suisse Global Wealth Report (cited in the literature, similar numbers, less open).

### Hand-to-mouth share target

Primary source: Kaplan, Violante, and Weidner 2014 for the eight countries they cover (US, Canada, Australia, UK, Germany, France, Italy, Spain), using their standard liquid-assets definition. Alternative: the Eurosystem Household Finance and Consumption Survey (HFCS) for European countries not in KVW; the Survey of Consumer Finances (SCF) replication for the US; the China Household Finance Survey (CHFS) for China; the Encuesta de Calidad de Vida (ECV) or Encuesta Longitudinal Colombiana (ELCA) for Colombia; the National Income Dynamics Study (NIDS) for South Africa. The KVW algorithm applied to whichever national survey is the standard route.

### phi, calibrated to the paid-work share

Primary source: the Multinational Time Use Study at the Oxford Centre for Time Use Research (MTUS), which harmonises the major national time-use surveys onto a common diary classification. For each country, compute the paid-work share of committed time, paid divided by paid plus unpaid domestic and associative time, for employed adults. Then choose phi so the model's mean work share equals that number. For France this is 0.53 from the 2010 Enquête Emploi du temps. For the US, ATUS gives roughly 0.60. For Germany and Italy, HETUS gives 0.55 and 0.55. For South Africa, TUS 2010 gives roughly 0.55. For Colombia, ENUT 2016 gives 0.60. For China, CTUS 2018 gives roughly 0.65. The procedure is universal; the number per country is data.

### alpha by education (the agency gradient)

Primary source: the OECD "How's Life?" indicators, the underlying administrative data that the Better Life Index displays. The relevant items are labour-market security (insecurity-adjusted earnings), self-reported health, and skills (PISA, PIAAC where available). These are aggregated to a single empowerment index per education group, then scaled into the model's 0-1 agency band. The OECD publishes these by education for its 41 members and key partners (Colombia is a member since 2020; Brazil, China, India, Indonesia, Russia, South Africa are key partners with selected indicators). For countries not in OECD coverage (the China case is the awkward one), the same items are constructed from national admin sources, named per country.

The crucial honest point: this is administrative data, not crowdsourced ratings. The BLI you remember interacting with, where users weight the dimensions, is a separate object covered below.

### B by education (the belonging taste gradient)

Primary source: the OECD "How's Life?" item on the quality of the social support network ("If you were in trouble, do you have relatives or friends you can count on to help you whenever you need them?"), stratified by education group. Where the OECD does not publish this stratification, the World Values Survey carries the same question in Wave 7 (2017-2022) for 64 countries with at least 1,000 respondents each. Education stratification is straightforward from WVS microdata. This is the standard cross-country source for the belonging taste.

### Lambda, the cohesion weight

This is the parameter the BLI question really concerns. Two primary routes, and a note on which is statistically stronger.

*Route 1, dimension weights from the YBLI tool.* The OECD's online Better Life Index lets users weight the eleven dimensions. The aggregate across users in a country gives a relative weight on the social-support dimension that can be mapped to Lambda. France had about 16,000 users by 2017; six years later the count is higher and more countries are covered. The advantage is cross-country comparability: the same instrument, the same dimensions, the same scale. The disadvantage is what you correctly remember being uneasy about: the sample is self-selected (people who came across the BLI website), so it is not representative. For sixteen thousand French users you have a large sample, but it is not a random sample of the French population, and the implicit weighting of who shows up varies by country. It is reliable for revealed-preference rankings; it is weak for population-level point estimates.

*Route 2, estimation from a life-satisfaction panel.* The robust route. A regression of life satisfaction on log consumption, the social-support indicator, and controls, in a representative panel, gives a ratio of coefficients that maps to Lambda in model units. Standard panel: SOEP for Germany, Understanding Society for the UK, EU-SILC ad hoc satisfaction modules for EU countries, the Health and Retirement Study (HRS) and the General Social Survey (GSS) for the US, the China Family Panel Studies (CFPS) for China, the Encuesta Longitudinal Colombiana (ELCA) for Colombia, the National Income Dynamics Study (NIDS) for South Africa, the European Social Survey for cross-EU comparability. The advantage is statistical strength on a representative sample. The disadvantage is comparability across countries: the regression specification varies, and the social-support measure is not identical across panels.

*The honest recommendation.* Use Route 1 as the baseline calibration (its sample weakness affects level but not relative magnitudes across dimensions), declare it openly, and treat Route 2 as the upgrade path that makes Lambda a country-estimated parameter rather than a country-imputed one. The Lambda Estimation Design note in the vault sets out Route 2 as the natural WISE collaboration object: the partner brings the regression they already run, and the model returns counterfactuals in WELLBYs.

### kappa and sigma_m, calibrated jointly to participation

Primary source: the World Values Survey Wave 7 (2017-2022) associational-membership questions: "Now I am going to read off a list of voluntary organisations. For each one, could you tell me whether you are an active member, an inactive member, or not a member?" Counting "active" gives a participation rate per country, and the same question stratified by education gives the gradient. The WVS is the universal cross-country source; the European Social Survey gives finer detail for Europe; INSEE Première gives the long historical series for France (used in the lead paper as a robustness check). The calibration target is the pair (overall rate, education gradient). Two moments fit two parameters cleanly.

### qbar, the participation lump

Primary source: MTUS again, this time the distribution of participants' social and associative time (not the average across the population). For participants in the OECD time-use countries this sits between 0.08 and 0.12 of committed time, so 0.10 is the harmonised order-of-magnitude value used as the default. Where a country's TUS allows a tighter number, the country row records it.

### omega and h, openly swept

No country sources. Reported with sensitivity in every output.

## What follows from this pipeline

A country row needs nine numbers from data: R, the wealth Gini target, the HtM target, the paid-work share, two alphas, two Bs, Lambda, and the participation gradient (two numbers). Plus the calibrated phi, kappa, sigma_m that come out of solving the model to match the targets. That is twelve parameters, every one of them from a named source. The other seven preference and process parameters are universal.

For an audience: "ten countries calibrated" means ten rows of this table, every row filled the same way, every row reproducible from the cited public sources.

## Validation

Every country's calibrated model is then judged on its untargeted moments. The standard scoreboard:

- Income Gini (target: WID income Gini per country)
- Composition of the public good (model prediction vs national volunteering rate)
- Distributional match (top-decile wealth share, bottom-quartile consumption share)

A country is calibrated when the targeted moments are hit and the untargeted moments are within standard tolerance. The repository's country comparison script reports both sets.

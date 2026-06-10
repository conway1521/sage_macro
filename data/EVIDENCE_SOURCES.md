# Evidence sources index (the three data streams)

Located 2026-06-10. The WELLBY stream is pulled and verified (see EVIDENCE_WELLBY.md). The YBLI and WISE streams have their authoritative sources located and are ready for extraction.

## 1. WELLBY (DONE, see EVIDENCE_WELLBY.md)

- HM Treasury Green Book supplementary guidance (2021): WELLBY = 13,000 GBP, the ES monetisation formula, beta_Y = 1.96. Read directly.
- World Happiness Report 2025 Ch2 Statistical Appendix Table 10: the cross-country coefficients (G 0.588, S 2.510, A 0.947). Read directly.
- WVS wave 7 individual participation coefficients (secondary).

## 2. YBLI citizen weights (source located, ready to extract)

The authoritative source is Balestra, Boarini and Tosetto (2018), "What matters the most to people? Evidence from the OECD Better Life Index users' responses", OECD Statistics Working Papers No. 2018/03, document SDD/DOC(2018)3. It analyses about 130,000 Better Life Index user responses since 2011, with the importance weights users place on the eleven wellbeing dimensions, by country and by population group. Ratings are expressed as a share of total, so equal weighting would give each dimension 9.09 percent.

Next step: extract the per-country dimension weight tables from SDD/DOC(2018)3 (one.oecd.org/document/SDD/DOC(2018)3/en/pdf), apply the eleven-to-SAGE mapping (social connections to S; civic engagement, education, health, jobs security to A; income, housing, jobs earnings to G; environment to E; life satisfaction is the outcome, excluded), and produce per-country (Lambda_S, weight_A, weight_G, weight_E). The user's note that the user base has grown several-fold since 2017 means a newer extract, if available from the OECD WISE Centre, would be even stronger; this working paper is the public baseline.

The eleven dimensions: housing, disposable income, jobs, work-life balance, education and skills, social connections, environmental quality, civic engagement and governance, health status, subjective wellbeing, safety.

## 3. WISE / Recoupling indices (source located, ready to extract)

The Recoupling Dashboard (Lima de Miranda and Snower 2020) publishes Solidarity (S), Agency (A), Material Gain (G) and Environmental Sustainability (E) indices for more than 30 countries over 2007 to 2018. It splits inward solidarity (within-group cohesion) from outward solidarity (cooperation with strangers), which maps onto our bonding-versus-bridging homophily channel. The WISE Database is at beyond-gdp.world/wise-database (over a million data points, 244 metrics, 218 countries, organised by Wellbeing, Inclusion, Sustainability).

Primary documents with the country index values: Lima de Miranda and Snower (2020), "Recoupling Economic and Social Prosperity", Global Solutions Journal 5 (Kiel Institute PDF); and the UC Press Global Perspectives version. The Global Solutions Initiative dashboard page hosts the interactive tool.

Next step: pull the per-country S and A index values for our seven countries, and benchmark our model orderings (the B gradient, the alpha gradient, and the equilibrium participation Q) against their solidarity and agency orderings, reporting rank correlations. The inward-versus-outward solidarity split is the natural external check on the homophily channel. Filing a data request at beyond-gdp.world doubles as the first contact with the programme.

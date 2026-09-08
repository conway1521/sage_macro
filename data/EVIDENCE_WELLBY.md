# WELLBY evidence: the coefficient library and the money bridge

First pull, 2026-06-10. This file records what was pulled, from where, the bridge machinery it feeds, and what is verified versus still to confirm. The data live in `wellby_coefficients.csv` (the raw coefficients) and `sage_weights_wellby.csv` (the SAGE relative weights derived from them).

## What the bridge needs, and what we now have

The model's experienced wellbeing is W = u(c) + Lambda B Q. To express a policy's effect in WELLBYs and in money, three objects are needed: the income gradient of life satisfaction (b), the social gradient (d), and the money value of a life-satisfaction point. All three are now pulled and verified.

## The money anchor (verified, primary)

HM Treasury Green Book supplementary guidance (July 2021, last updated November 2022, still current as of September 2026): one WELLBY, defined as a one-point change in life satisfaction on the 0-10 scale per person per year, is valued at 13,000 GBP (2019 prices), with a recommended range of 10,000 (low) to 16,000 (high). The central value is the midpoint of the two, and the two ends come from different methods, which an earlier version of this note had the wrong way round. Verified against the guidance text directly:

- LOW, 10,000: based on a QALY value updated to 2019 prices, broadly following the approach of Frijters and Krekel (2021), adapted to reflect academic comment on the low-point conversion.
- HIGH, 16,000: based on an ln(income) coefficient of 1.96105 from Fujiwara (2021).
- CENTRAL, 13,000: the midpoint of low and high.

The Green Book's monetisation formula, which is exactly the bridge structure we want, is

  ES = M [ exp( beta_Q dQ / beta_Y ) - 1 ],

where M is average net personal income, beta_Y = 1.96 is the coefficient on log income (Fujiwara 2021; the guidance carries it as 1.96105, footnote 106, and the formulae themselves are taken from Fujiwara 2013), beta_Q is the coefficient on the outcome being valued, and dQ is its change. One scale detail that matters: the 1.96 is stated on the 0-10 life-satisfaction scale, rescaled from the original study's 1-7 scale where the coefficient is 1.25 (guidance footnote 105). Our life-satisfaction coefficients are on the 0-10 Cantril scale, so the two are consistent and no rescaling is needed. In our application beta_Q dQ is just the life-satisfaction effect size of the policy, so the money value follows directly once the model's fabric change is mapped to a life-satisfaction change.

## The coefficient anchor (verified, primary)

World Happiness Report 2025, Chapter 2 Statistical Appendix, Table 10, column (1), verified against the appendix PDF directly: pooled OLS explaining average happiness across countries, dependent variable the Cantril ladder (0-10), with BOTH year and country fixed effects, 2234 observations across 155 countries, standard errors cluster-adjusted at the country level, adjusted R-squared 0.897. (An earlier version of this note said about 140 countries; it is 155.) The coefficients on a common scale:

| variable | coefficient | std error | units | SAGE |
|---|---|---|---|---|
| log GDP per capita | 0.588 | 0.125 | log income | G |
| social support | 2.510 | 0.319 | national share 0-1 (someone to count on) | S |
| freedom to make life choices | 0.947 | 0.239 | national share 0-1 | A |
| generosity | 0.585 | 0.202 | residual donation | S (prosocial) |
| perceptions of corruption | -0.842 | 0.21 | national share 0-1 | institutions |
| healthy life expectancy | -0.012 | 0.01 | years | (n.s.) |

This single regression gives coefficients for three of the four SAGE dimensions at once, on the same life-satisfaction scale, which is why it is the spine of the bridge. The social-support variable is a 0-1 population share, the same object as the model's aggregate participation rate, so it matches mapping (a) of the plan directly.

## The micro participation anchor (verified, secondary)

For the individual-level participation margin (the S+A model's own object), World Values Survey wave 7 individual regressions give a per-membership life-satisfaction coefficient of about 0.10 (group/associational membership), with context-specific participation-index coefficients in the 0.05 to 0.07 range. These are the micro analogue of the macro social-support coefficient and bound the individual effect of joining.

## The implied SAGE weights and the Lambda cross-check

Normalising the gain coefficient to 1, the WELLBY-revealed relative weights are:

  gain G = 1.00, agency A = 1.61, social cohesion S = 4.27, prosocial S2 = 0.99.

So at the macro level, citizens reveal (through the life-satisfaction regression) that social cohesion carries roughly four times the weight of material gain, and agency about one and a half times. This is the empirical face of Lambda. It sits well above the thesis Lambda of 0.876 (which was a normalised OECD Better Life Index dimension weight, a different basis), and it is consistent with the plan's expectation that the WELLBY-implied social weight is several times the citizen-rating one. The clean number to carry through the papers: the social-to-gain coefficient ratio d/b = 2.510 / 0.588 = 4.27.

Three Lambda values to report side by side once the YBLI pull lands: thesis (0.876, OECD BLI 2017), YBLI citizen ratings (to pull, phase 1), and WELLBY/WHR regression (this pull, ratio 4.27). The spread is itself the finding.

## Environment (E): the gap

The WHR regression has no environment term, so the E weight cannot come from this source. It must come from the YBLI citizen ratings (phase 1) or a dedicated subjective-wellbeing and environment study. Flagged for the E model, not the S or S+A papers.

## Verified versus to confirm

Re-verified 2026-09-08 against the primary documents, not against secondary summaries. Confirmed exactly: the Green Book 13,000 with its 10,000 to 16,000 range and 2019 price base; the ES formula and beta_Y = 1.96105 with its Fujiwara (2021) attribution and 0-10 scale basis; every coefficient and standard error in WHR 2025 Table 10 column (1). Three things in the earlier version of this note were wrong and are corrected above: the low and high Green Book methods were swapped and mislabelled, the country count was understated as about 140 rather than 155, and the scale basis of the 1.96 was not recorded.

One methodological point in favour of this bridge, noted while checking. The WHR regression carries country fixed effects, so its coefficients are identified from within-country variation over time, which is the same kind of variation a policy change produces. Applying them to a within-country counterfactual is therefore better founded than a pure cross-section would be. It remains value transfer in the Green Book's sense, and the construct mismatch below is the real caveat, not the identification.

Still at lower confidence: Verified from secondary sources: the WVS participation coefficients. To confirm against the original book tables: the Origins of Happiness adult life-satisfaction coefficients (log income about 0.09, partnered about +0.30, unemployed about -0.65, mental-health problem about -0.70). The PDF table columns did not align under text extraction, so these are recorded at lower confidence and flagged in the CSV; they are not load-bearing for the bridge, which rests on the Green Book and WHR anchors.

## Sources

- HM Treasury, Wellbeing Guidance for Appraisal: Supplementary Green Book Guidance, July 2021.
- Fujiwara (2021), the income coefficient behind the Green Book DCE valuation.
- World Happiness Report 2025, Chapter 2 Statistical Appendix, Table 10.
- World Values Survey wave 7, individual life-satisfaction regressions (secondary compilations).
- Clark, Fleche, Layard, Powdthavee, Ward, The Origins of Happiness (Princeton, 2018), online materials.

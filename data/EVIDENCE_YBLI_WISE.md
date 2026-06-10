# YBLI and WISE evidence (pulled 2026-06-10, deep-research verified)

Both streams researched with a fan-out, fetch, and adversarial-verification harness (101 agents, 19 sources, 24 of 25 claims confirmed 3-0). Headline: the WISE per-country indices are in hand for six of seven countries; the YBLI per-country weights do not exist in public form, and the reason is strategically useful.

## WISE Recoupling: Solidarity and Agency indices (data in hand)

Source: Lima de Miranda and Snower (2020), "Recoupling Economic and Social Prosperity", BSG Working Paper SM-WP-2020-001 (Tables 1 and 2, years 2007 and 2017) and the Global Solutions Initiative dashboard (2018). Values are in `wise_recoupling.csv`. Six of our seven countries are covered; Colombia is genuinely absent from the 35-country sample and would need a WISE Database data request (beyond-gdp.world) or the G20 2010-2023 extension.

Index construction: the Agency (Empowerment) Index has five components (labour-market insecurity, vulnerable employment, life expectancy, years in education, confidence in empowering institutions). The Solidarity Index has giving behaviour, trust in others, and social support, with some versions adding minority rights under an inward-versus-outward split. That inward-versus-outward split is the external counterpart of our bonding-versus-bridging homophily channel.

The paths (2007 to 2017/2018), Solidarity Index:

| country | 2007 | 2017/18 | direction |
|---|---|---|---|
| United States | 0.73 | 0.65 / 0.67 | down |
| Italy | 0.54 | 0.47 / 0.49 | down |
| France | 0.46 | 0.45 | flat |
| Germany | 0.63 | 0.66 / 0.67 | up |
| China | 0.33 | 0.48 / 0.52 | up (caveat) |
| South Africa | 0.27 | 0.56 | up (caveat) |

The rich-economy pattern (US and Italy solidarity falling, France flat) against the catch-up countries (China, South Africa rising) is exactly the variation a calibrated-history exercise would try to explain. The US is the cleanest test case for the rising-inequality-erodes-cohesion hypothesis: solidarity fell from 0.73 to about 0.66 while agency stayed flat near 0.78.

Data-quality flags carried from the authors: China and South Africa agency use only three of the five components, and China's solidarity omits social support. Cite the year and source because the working paper (2017) and dashboard (2018) differ by 0.00 to 0.02 on most indices; the 2007 values are identical across sources.

## YBLI: the per-country weights do not exist publicly (important)

The canonical analysis (Balestra, Boarini and Tosetto 2018, OECD SDD/DOC(2018)3, about 130,000 users May 2011 to December 2017) does NOT publish per-country dimension weights. It disaggregates only by sex, age, and four world regions (Asia-Pacific, Europe, North America, South America). Country enters the regressions only through objective Better Life Index performance, never as a weight. So the per-country YBLI weight vector the project hoped to wire into the country rows is not available from the public source.

Two corrections to our prior assumptions: the importance scale is 0 to 5, not 0 to 10 (the 0 to 10 applies only to the optional life-satisfaction question); and the weights are relative (each dimension as a share of a user's total, equal weighting equals 9.09 percent).

What we CAN use from YBLI:
- The overall importance ranking (t-test): health, life satisfaction, education, work-life balance, then at a distance safety, environment, housing, jobs, income, community ties, and civic engagement (lowest).
- Regional gradients: South America rates education, jobs, and civic engagement highest; Asia-Pacific rates safety and work-life balance; Europe rates health; North America rates life satisfaction.
- Demographic gradients: men weight material conditions (income, jobs, housing) more, women weight quality of life, community, and work-life balance more; older users weight housing, safety, health, civic engagement, younger users weight life satisfaction, work-life balance, jobs, income, community.

Access route for genuine per-country figures: the OECD WISE Centre Well-being Data Monitor (launched November 2025, which now hosts an updated Better Life Index) via a direct data request. The live "responses" view that the user recalls from 2020 showed per-country shared-index aggregates on the website, but those were never published as a static per-country weight table. This is the request to file alongside the WISE Database one.

## The strategic finding: stated weights and revealed weights disagree on social cohesion

Put the two evidence pulls side by side and a genuine tension appears, and it is the project's own thesis in the data.

- Stated importance (YBLI, what people SAY matters): community ties and civic engagement rank LAST of the eleven dimensions.
- Revealed importance (WHR/WELLBY, what their life satisfaction actually MOVES with): social support has the LARGEST coefficient (2.51), well above income (0.59) and freedom (0.95).

People say social connection matters least, yet their measured wellbeing responds to it most. This is the classic gap between decision weights (what people choose and report) and experienced-wellbeing weights (what actually moves their wellbeing), the distinction at the heart of this project. It means the three Lambda values will span a very wide range, low under YBLI stated weights, high under WELLBY revealed weights, and the spread is not noise to be averaged away but the finding itself. It is the empirical case for why a wellbeing model must use experienced weights, not stated preferences, when valuing the social fabric.

## Implication for the dynamic / calibrated-history idea

The WISE Solidarity and Agency paths are exactly the external validation series the calibrated-history idea needs. We can now feed each country's observed wealth-inequality path through the model and check the predicted cohesion path against the WISE Solidarity path for the US, Italy, France, Germany (and, with caveats, China and South Africa). The US is the natural proof of concept.

# Literature and data brief: grounding S, A and E

Prepared 2026-10-02. Scope: the social (S), agency (A) and place (E) dimensions of the SAGE Bewley model, the Beyond GDP frameworks they should map to, and official data that could corroborate each one for France, Germany and Italy.

## How to read the verification labels

Every entry carries one label. Numbers are quoted only where the label is [S] or [A], and the location in the source is given.

| label | meaning |
|---|---|
| [S] | read in the source itself today: full text of the paper or report, or the official database queried directly (Eurostat and OECD APIs) |
| [A] | abstract read today at the publisher, NBER or RePEc page. Nothing beyond the abstract is claimed |
| [M] | bibliographic record confirmed today (Crossref or publisher listing). Any description of content is from general knowledge of the paper and must be checked before it is cited for a specific claim |
| UNVERIFIED | could not be opened, or known only through a secondary description. Listed again at the end |

One warning from the verification itself. An automated summary of the OECD working paper by Hijzen and Menyhért returned a "Table 2" with country values for France, Germany and Italy. I read the PDF text and no such table exists: the country values appear only in figures. Those numbers are excluded, and the official values below come from the OECD database instead. Numbers from PDFs should therefore be trusted only where this brief marks them [S].

---

## 1. S: social interactions in participation

### 1a. Canonical theory

| source | what it gives the model | label |
|---|---|---|
| Brock and Durlauf (2001), "Discrete choice with social interactions", Review of Economic Studies 68(2), 235-260 | Binary logit choice with a payoff that rises in the expected mean choice. Equilibrium solves m = tanh(beta h + beta J m). Proposition 2: three equilibria exist when beta J > 1 and the private incentive h is small enough, otherwise one. Proposition 4: with three roots the two extreme ones are locally stable and the middle one is unstable. Proposition 5: when h > 0 the equilibrium with the same sign as h gives every agent higher expected utility | [S] propositions read in the article, journal pages 241-244 |
| Manski (1993), "Identification of endogenous social effects: the reflection problem", Review of Economic Studies 60(3), 531-542 | Endogenous, contextual and correlated effects cannot be separated in a linear-in-means model without prior information on reference groups | [A] |
| Glaeser, Sacerdote and Scheinkman (2003), "The social multiplier", Journal of the European Economic Association 1(2-3), 345-353 | Defines the multiplier as the ratio of the aggregate to the individual coefficient, about 1/(1 - x) in large groups when own outcome rises by x per unit of the neighbours' mean | [S] numbers read in the NBER working paper version (w9153, pdf pages 4, 5 and 15), not in the journal version |
| Blume, Brock, Durlauf and Ioannides (2011), "Identification of social interactions", Handbook of Social Economics vol. 1B, 853-964 | The reference treatment of identification in linear, discrete-choice and network models | [A] |
| Brock and Durlauf (2007), "Identification of binary choice models with social interactions", Journal of Econometrics 140(1), 52-75 | Partial identification when groups are selected | [M] |

### 1b. Empirical magnitudes to benchmark a multiplier of 1.3 to 1.8

No study was found that estimates a social multiplier for volunteering itself in France, Germany or Italy. The benchmarks are neighbouring behaviours.

| study | setting | magnitude | implied multiplier | label |
|---|---|---|---|---|
| Glaeser, Sacerdote and Scheinkman (2003) | Fraternity and sorority membership, Dartmouth roommates. The closest case to associational membership | below one at room level, 1.4 at floor level (groups of eight), 2.23 at dormitory level (groups of 57) | 1.4 to 2.2, reported by the authors | [S] working paper, pdf page 15 |
| Nickerson (2008), "Is voting contagious?", American Political Science Review 102(1), 49-57 | Two placebo-controlled canvassing experiments, two-voter households | "60% of the propensity to vote is passed onto the other member of the household" | 1.6 within a two-person household (my arithmetic) | [A] |
| Smith, Windmeijer and Wright (2015), "Peer effects in charitable giving", Economic Journal 125(585), 1053-1071 | Online fundraising pages | a 10 pound rise in the mean of past donations raises giving by 2.50 pounds in the published abstract, and by 3.50 pounds in the working paper abstract | 1.33 to 1.54 if read as a linear-in-means slope (my arithmetic, not the authors') | [A], the two versions differ |
| Shang and Croson (2009), Economic Journal 119(540), 1422-1439 | Field experiment, public radio donors | social information raises contributions by about 12 percent in the best condition | not a multiplier | [A] |
| Frey and Meier (2004), American Economic Review 94(5), 1717-1722 | Field experiment, student charitable funds | contributions rise when people learn that many others contribute | qualitative | [A] |
| Freeman (1997), "Working for nothing", Journal of Labor Economics 15(1), S140-S166 | US volunteer labour supply | "many volunteer only when requested to do so" | supports a social channel, no multiplier | [A] |
| Meer (2011), Journal of Public Economics 95(7-8), 926-941 | Alumni giving, roommate assignment | social ties have "a strong causal role" in the decision to donate | qualitative | [A] |
| Mohan and Bennett (2019), Environment and Planning A 51(4), 950-979 | England, Citizenship Survey linked to the charity register | a positive relation between the number of locally operating charities and the likelihood of formal volunteering | not a multiplier, relevant to E | [A] |

Reading: a multiplier of 1.3 to 1.8 lies inside the range the literature reports for group membership, voting and giving (about 1.3 to 2.2). In my view the defensible statement is that the model's range is consistent with estimates for neighbouring behaviours, and that no direct estimate for volunteering exists. Andreoni and Scholz (1998, Economic Inquiry 36(3), 410-428) estimate interdependent giving, but I confirmed only the record [M] and quote no number. Cantoni, Yang, Yuchtman and Zhang (2019, Quarterly Journal of Economics 134(2), 1021-1077) is a counterexample in which participation decisions are strategic substitutes [M], which a referee could cite against assuming complementarity everywhere.

### 1c. Social capital, time, unemployment and education

- **Economic approach.** Glaeser, Laibson and Sacerdote (2002), "An economic approach to social capital", Economic Journal 112(483), F437-F458 [A]. Social capital is an individual investment. It rises then falls with age, falls with expected mobility and with distance, and rises with human capital investment.
- **Unemployment lowers participation.** Kunze and Suppa (2017), Journal of Economic Behavior and Organization 133, 213-235 [A]: German panel data with plant closures as exogenous entry, "negative and lasting effects for public social activities" and a retreat into private life. Pohlan (2019), same journal, 164, 273-299 [A]: job loss damages perceived social integration, and the effects grow with duration and persist after re-employment.
- **A caution from time-use data.** Eurostat HETUS, table tus_00selfstat, activity "organisational work", daily participation rate in 2010 for the unemployed against full-time employed: Germany 3.8 against 3.6 percent, France 1.3 against 1.5, Italy 1.6 against 0.7 [S, Eurostat API]. On the diary measure the unemployed do not participate less, and in Italy they participate more. The model imposes the gap from the twelve-month survey measure, so the two measures should be reconciled in the text.
- **Education gradient, official.** Eurostat ilc_scp19, formal volunteering, age 16 and over, 2015, by ISCED 0-2 / 3-4 / 5-8: France 14.9 / 23.8 / 29.8, Germany 19.5 / 28.6 / 36.4, Italy 8.4 / 14.6 / 16.8 percent [S, Eurostat API]. The tertiary to low ratio is about 2.0 in France and Italy and 1.9 in Germany.
- **Education gradient, causal.** Dee (2004), Journal of Public Economics 88(9-10), 1697-1720 [A]: schooling raises voter participation and support for free speech, using college availability and child labour laws. Milligan, Moretti and Oreopoulos (2004), same issue, 1667-1695 [M]. Huang, Maassen van den Brink and Groot (2009), Economics of Education Review 28(4), 454-464 [A]: a meta-analysis of 154 estimates on trust and 286 on participation. Helliwell and Putnam (2007), Eastern Economic Journal 33(1), 1-19 [M]. Against a causal reading, Gibson (2001), Economics of Education Review 20(3), 225-233: within twin pairs more education lowers volunteering (UNVERIFIED: secondary, publisher abstract seen only through a search summary).
- **Time against money.** Bauer, Bredtmann and Schmidt (2013), European Journal of Political Economy 32, 80-94 [A]: across Europe time and money gifts are positively correlated, and people substitute money for time as market work rises.
- **Participation and well-being.** Meier and Stutzer (2008), "Is volunteering rewarding in itself?", Economica 75(297), 39-59 [A]: volunteers are more satisfied, and causality is studied through "the collapse of East Germany and its infrastructure of volunteering". This paper serves S and E at once.

### 1d. Equilibrium selection

Brock and Durlauf (2001) give the model two usable results [S]: the extreme equilibria are the stable ones under myopic expectations (Proposition 4), and with a positive private incentive the high equilibrium is the one with higher expected utility for every agent (Proposition 5). Selecting the highest stable equilibrium therefore selects the welfare-dominant one, but the paper offers no argument that agents coordinate on it. The wider literature offers three positions, all [M]: Cooper and John (1988, Quarterly Journal of Economics 103(3), from page 441) on Pareto-ranked equilibria under strategic complementarity, Milgrom and Roberts (1990, Econometrica 58(6), from page 1255) on the largest and smallest equilibria of supermodular games as the natural bounds, and Kandori, Mailath and Rob (1993, Econometrica 61(1), from page 29) with Morris and Shin (2003, Advances in Economics and Econometrics, Cambridge University Press, 56-114), where noise or learning can select the risk-dominant equilibrium, which need not be the highest. Blume and Durlauf (2003, International Game Theory Review 5(3), 193-209) discuss equilibrium concepts for these models [M].

---

## 2. A: agency and insurance

### 2a. From capability to a measurable statistic

- **Concept.** Sen, Commodities and Capabilities (1985, North-Holland) and Development as Freedom (1999, Oxford University Press): UNVERIFIED at the publisher today, standard references. Robeyns (2005), "The capability approach: a theoretical survey", Journal of Human Development 6(1), 93-117 [M]. Alkire (2002), Valuing Freedoms, Oxford University Press [M]. Alkire and Foster (2011), "Counting and multidimensional poverty measurement", Journal of Public Economics 95(7-8), 476-487 [A]: dual cut-off identification, the operational form most used by statistical offices.
- **Insurance coefficients.** Blundell, Pistaferri and Preston (2008), American Economic Review 98(5), 1887-1921 [A]: partial insurance of permanent shocks, full insurance of transitory shocks except among poor households, with taxes, transfers and family labour supply doing much of the insuring. Kaplan and Violante (2010), American Economic Journal: Macroeconomics 2(4), 53-87 [A]: BPP estimate that 36 percent of permanent shocks are insurable, against 7 to 22 percent in a calibrated incomplete-markets model depending on the debt limit.
- **Official counterparts.** OECD How's Life database definitions [S]: indicator 2.5, labour market insecurity, is the "average expected monetary loss associated with becoming and staying unemployed, as a percentage of previous earnings", and indicator 1.6, financial insecurity, is the share with liquid financial assets below three months of the poverty line. Hijzen and Menyhért (2016), OECD Social, Employment and Migration Working Paper 175 [S]: the indicator "is then defined as unemployment risk times one minus unemployment insurance, and measures the expected proportional loss in earnings due to unemployment" (paper page 10).

### 2b. The statistic closest to "one minus the expected consumption loss on job loss"

Two statistics are close, and they answer different questions.

| statistic | what it is | FR | DE | IT | label |
|---|---|---|---|---|---|
| OECD labour market insecurity, 2016 (latest year in the database) | expected earnings loss from unemployment, percent of previous earnings. Unconditional, income, institutions only | 3.07 | 1.42 | 8.63 | [S] OECD SDMX API, dataflow DSD_HSL@DF_HSL_CWB, measure 2_5 |
| one minus that | counterpart of the model's expected-loss reading | 0.969 | 0.986 | 0.914 | my arithmetic |
| consumption drop at job loss | conditional on the event, includes own savings | 15 percent at six months | none found | none found | see below |

Consumption drop at unemployment, the conditional statistic:

| study | country, data | drop | label |
|---|---|---|---|
| Bonnet, Olivia, Le Grand, Ragot and Wilner (2025), INSEE Analyses 104 | France, La Banque Postale accounts, 2,409 households with six months or more of insured unemployment | income falls 31 percent. Consumption is 2 percent lower after one month and 15 percent lower after six. Over six months consumption falls by 35 percent of the income loss: 58 percent in the lowest liquidity quartile, 17 percent in the highest (figure 2a) | [S] INSEE page. INSEE warns the sample is not representative |
| Gruber (1997), American Economic Review 87(1), 192-205 | US, PSID food | average fall 7 percent. Ten points more replacement makes it 2.7 percent smaller. Without insurance it "would have been over three times as large" | [A] NBER w4750 |
| Browning and Crossley (2001), Journal of Public Economics 80(1), 1-23 | Canada | "about 16% of total expenditure" for those still unemployed after six months. Benefit effects only for those without assets | [A] |
| Landais and Spinnewijn (2021), Review of Economic Studies 88(6), 3041-3085 | Sweden, registry | about 13 percent | [A] |
| Kolsrud, Landais, Nilsson and Spinnewijn (2018), American Economic Review 108(4-5), 985-1033 | Sweden | drop "large from the start of the spell" and rising, no number in the abstract | [A] |
| Ganong and Noel (2019), American Economic Review 109(7), 2383-2424 | US bank accounts | sharp drop at benefit exhaustion, no number in the abstract | [A] |
| Bentolila and Ichino (2008), Journal of Population Economics 21(2), 255-280 | Spain, Italy, Germany, Britain, US | longer spells bring smaller consumption losses in Spain and Italy, read as family insurance | [A] discussion paper version, no magnitudes |

The model's conditional indicator for France therefore has a direct official benchmark of about 0.85 at six months, with a strong liquidity gradient that the Bewley structure should reproduce untargeted. For Germany and Italy I found no verified estimate of the consumption drop. Bentolila and Ichino is the only comparative source and I could not read its magnitudes. The by-education split of labour market insecurity is published in the same OECD database (the definition lists education level as a breakdown [S]), which gives the A dimension an official gradient to match.

---

## 3. E: place and the local public good

### 3a. Theory

Samuelson (1954), Review of Economics and Statistics 36(4), from page 387, and Tiebout (1956), Journal of Political Economy 64(5), 416-424, are anchors only [M]. Buchanan (1965), "An economic theory of clubs", Economica 32(125), from page 1, and Cornes and Sandler (1996), The Theory of Externalities, Public Goods, and Club Goods, 2nd edition, Cambridge University Press, are the better fit [M]: community infrastructure is congestible and excludable by distance, a local club good. For "social infrastructure" as a term, the academic references are Latham and Layton (2019), Geography Compass 13(7), e12444, and Finlay, Esposito, Kim, Gomez-Lopez and Clarke (2019), "Closure of 'third places'?", Health and Place 60, 102225 [M]. Klinenberg's Palaces for the People is a trade book and is excluded under the source rules.

### 3b. Does infrastructure or association density raise participation?

| study | evidence | bearing on epsilon | label |
|---|---|---|---|
| Putnam, Leonardi and Nanetti (1993), Making Democracy Work, Princeton University Press | Twenty Italian regions. The civic community index combines association density, newspaper readership, referendum turnout and preference voting, and predicts institutional performance | the origin of using Italian association density | [M], index composition from secondary descriptions |
| Guiso, Sapienza and Zingales (2016), "Long-term persistence", JEEA 14(6), 1401-1436 | Italian cities that were free city-states have "a higher level of civic capital today", increasing in the length and intensity of independence | civic capital is a slow stock, consistent with omega as a stock | [A]. That they measure civic capital partly by non-profit organisations per head is from memory of the paper and UNVERIFIED in the source |
| Guiso, Sapienza and Zingales (2004), American Economic Review 94(3), 526-556 | Italian provinces. Movers carry the trust of the province where they grew up | part of the regional pattern is in people, not in facilities | [A] |
| Satyanath, Voigtländer and Voth (2017), Journal of Political Economy 125(2), 478-526 | 229 German towns. One standard deviation more association density, "at least 15% faster Nazi Party entry" | density raises mobilisation, whatever its direction. A reminder that the belonging payoff is not welfare by construction | [A] NBER w19201 |
| Mohan and Bennett (2019) | England: more locally operating charities, higher likelihood of formal volunteering. Regional and national charities, and charity size, have no effect | supports a local supply channel. Cross-sectional | [A] |
| Roskruge, Grimes, McCann and Poot (2012), International Regional Science Review 35(1), 3-25 | New Zealand: local social infrastructure spending linked to trust and participation. Effects are "affected by both selection effects and free rider processes" | the most direct test, and a cautious result | [A] |
| Meier and Stutzer (2008) | Collapse of East Germany's volunteering infrastructure removed opportunities and lowered life satisfaction | a quasi-experiment on infrastructure, on the well-being side | [A] |
| Gilpin, Karger and Nencka (2024), American Economic Journal: Economic Policy 16(2), 78-109 | US public libraries: capital investment raises visits, children's event attendance and circulation "by an average of 5-15 percent" | the only causal facility-to-use magnitude found | [A] |
| Wicker, Hallmann and Breuer (2013), Sport Management Review 16(1), 54-67 | Munich, 11,175 respondents, geo-coded facilities: swimming pools matter for sport participation, sport fields for club participation | supports a facility channel for clubs. Multi-level correlations | [A] |
| Pawlowski, Steckenleiter, Wallrafen and Lechner (2021), Labour Economics 70, 101996 | German municipal sports spending and SOEP outcomes | positive income effects for men, selection on observables | [A] |
| Bolet (2021), Comparative Political Studies 54(9), 1653-1692 | One more community pub closure in a district raises UKIP support by 4.3 points | loss of a meeting place has measurable social effects | [A] repository record |
| Geraci, Nardotto, Reggiani and Sabatini (2022), Journal of Public Economics 206, 104578 | UK: fast internet "caused a significant decline in civic and political engagement" | infrastructure can also crowd participation out. Broadband enters the model as a positive conversion factor | [A] |
| Alesina and La Ferrara (2000), Quarterly Journal of Economics 115(3), 847-904 | US localities: participation is lower where inequality and fragmentation are higher | composition, the competing explanation | [A] |
| Durante, Mastrorocco, Minale and Snyder (2025), Economic Journal 135(667), 773-807 | Italy, over 600,000 respondents, 2000-2015: social participation, political participation, general trust and institutional trust are distinct components | which Italian measure is used matters | [A] |

**On epsilon of 0.3 to 0.5.** I found no published elasticity of volunteering or associational participation with respect to facilities or organisations per head. The nearest causal magnitude is the 5 to 15 percent rise in library use after capital investment, which is not expressed per unit of infrastructure. The elasticity therefore rests on the model's own Italian estimate, and the literature supports the sign and the local nature of the effect more than its size.

### 3c. Place effects and spatial macro

- Chetty and Hendren (2018), Quarterly Journal of Economics 133(3), 1107-1162 and 1163-1228 [M]: childhood exposure effects of neighbourhoods and county-level causal estimates.
- Chetty, Jackson, Kuchler, Stroebel et al. (2022), Nature 608, 108-121 [A, NBER w30313]: economic connectedness is among the strongest predictors of mobility, "whereas other social capital measures are not strongly associated with economic mobility". Civic engagement, the model's S, is in the second group.
- Moretti (2011), "Local labor markets", Handbook of Labor Economics vol. 4B, 1237-1313 [M]. Bilal (2023), "The geography of unemployment", Quarterly Journal of Economics 138(3), 1507-1576 [M].
- Rodríguez-Pose (2018), Cambridge Journal of Regions, Economy and Society 11(1), 189-209 [A]. Dijkstra, Poelman and Rodríguez-Pose (2020), Regional Studies 54(6), 737-753 [M].
- Bilal and Rossi-Hansberg (2021), "Location as an asset", Econometrica 89(5), 2459-2495 [A]: location choice as an investment, validated on French tax data. This is the closest published heterogeneous-agent model with places, and it has mobility, which the SAGE place layer assumes away.
- Giannone, Li, Paixão and Pang, "Unpacking moving", Bank of Canada Staff Working Paper 2023-34: a working paper from an official institution, not peer reviewed, listed for completeness.

### 3d. Urban and rural

Eurostat ilc_scp20, formal volunteering by degree of urbanisation, cities / towns and suburbs / rural [S, Eurostat API]:

| | 2015 | 2022 |
|---|---|---|
| France | 20.3 / 21.4 / 27.7 | 14.2 / 15.2 / 17.6 |
| Germany | 23.5 / 29.6 / 34.5 | flagged unreliable, not published |
| Italy | 11.4 / 12.3 / 12.2 | 5.5 / 5.1 / 5.5 |

The rural premium is large in France and Germany and absent in Italy. Sørensen (2016), Regional Studies 50(3), 391-410 [A]: in Denmark bonding social capital is higher in rural areas and bridging marginally higher in urban areas. Paarlberg, Nesbit, Choi and Moss (2022), Voluntas 33(1), 107-120 [A]: US rural residents volunteer more, with a narrowing gap. Brueckner and Largey (2008), Journal of Urban Economics 64(1), 18-34 [A for the design]: the finding that interaction is lower in dense tracts is from a secondary description, UNVERIFIED.

---

## 4. Beyond GDP anchors

| framework | participation and belonging | agency and economic security | place and environment | label |
|---|---|---|---|---|
| Stiglitz, Sen and Fitoussi (2009), Report of the Commission, paragraph 28 | vi. "Social connections and relationships", and v. "Political voice and governance" | viii. "Insecurity, of an economic as well as a physical nature". Recommendation 6 refers to "objective conditions and capabilities" | vii. "Environment (present and future conditions)" | [S] pages 14-15 of the Eurostat-hosted PDF |
| OECD How's Life (2024 edition), database definitions | 7.1 Social support. Time spent in social interactions. 14.7 "Volunteering through organisations", placed under social capital, a resource for future well-being | 2.5 Labour market insecurity. 1.6 Financial insecurity | Environmental quality dimension. Natural capital | [S] definitions document. The list of eleven dimensions is from the OECD's own page summary |
| OECD Regional Well-Being, user's guide, October 2025, Table 2 | Community: share with friends or relatives to rely on. Civic engagement: voter turnout | Jobs: employment and unemployment rates. Income: household disposable income per head | Environment: PM2.5 exposure. Access to services: broadband share and download speed | [S] page 13. No volunteering indicator and no economic security indicator exist at TL2 |
| CES Recommendations on Measuring Sustainable Development (UNECE, Eurostat, OECD, 2014) | trust and institutions, under "here and now" | consumption and income, labour | "later" as capital stocks, "elsewhere" as footprints | UNVERIFIED: secondary. The UNECE PDF returned an access error, and the theme list comes from a search summary of it |
| Hoekstra (2019), Replacing GDP by 2030, Cambridge University Press | | | | [M], content not read |
| Jansen, Wang, Behrens and Hoekstra (2024), Lancet Planetary Health 8(9), e695-e705 | Reviews 65 Beyond GDP metrics and proposes a dashboard for sustainable and inclusive well-being | | | [A] via the project page. Sub-dimensions not read |
| Liu, Wang, Behrens, Schrijver, Jansen, Rum and Hoekstra (2024), Scientific Data 11 | The WISE database: 244 metrics for 218 countries, per the project page | | | [M] |
| Fearon, Gallant, Druckman, Mair and Liu, Ecological Economics 251, 109221 | Time-use modelling of 2050 lifestyles in Finland, France and the UK: the WISE output closest to a model with a time budget | | | [M] |
| Jansen, Hoekstra, Kaufmann and Gerer (2023), WISE Horizons deliverable 1.1. Wiebe, Hoekstra and Rocha Aponte (2026), WISE Accounts, Zenodo | Official project deliverables | | | project pages only |

WISE Horizons itself: Horizon Europe grant 101095219, coordinated by Leiden University, 2023 to April 2027 [S, CORDIS].

Two mapping points follow. Volunteering sits in the OECD framework as social capital for future well-being and social support sits in current well-being, so the model's participation rate and its belonging payoff map to two different places. The regional framework has no volunteering indicator, so a regional participation prediction cannot be checked against OECD regional data and needs national sources.

---

## 5. Data for corroboration

| # | provider and dataset | indicator | coverage | access | label |
|---|---|---|---|---|---|
| 1 | Eurostat ilc_scp19 | formal and informal volunteering, active citizenship, by sex, age and education | FR, IT 2015 and 2022. DE 2015 only | API, bulk | [S] |
| 2 | Eurostat ilc_scp20 | the same by income quintile, household type and degree of urbanisation | as above | API, bulk | [S] |
| 3 | Eurostat ilc_scp21, ilc_scp22 (2015), ilc_scp23 to ilc_scp26 (2022) | reasons for not participating, type of organisation | national | API | [S] codes |
| 4 | EU-SILC microdata, 2015 and 2022 modules | the same items by region | region variable at NUTS1 or NUTS2 depending on country. No regional table is published | research proposal to Eurostat | regional detail not checked |
| 5 | Eurostat ilc_scp16, ilc_pw02, ilc_pw04 | someone to ask for help, life satisfaction, trust, by degree of urbanisation | national by place type | API | [S] codes |
| 6 | Eurostat HETUS tus_00selfstat, tus_00educ | time and participation rate in organisational work, informal help, travel to work, by labour status and education | FR, DE, IT, 2000 and 2010 waves. 2020 wave under tus_20* | API | [S] |
| 7 | Eurostat lfso_19plwk28, lfst_r_lfe2ecomm | commuting time by education and degree of urbanisation (2019). Commuters by NUTS2 | national by place type. NUTS2 | API | [S] codes |
| 8 | OECD Regional Well-Being | voter turnout, social support, life satisfaction, broadband, PM2.5 | TL2, 468 regions | spreadsheet on the site, OECD Data Explorer | [S] |
| 9 | OECD How's Life database | labour market insecurity, financial insecurity, social support, volunteering through organisations, by education | national | SDMX API | [S] |
| 10 | European Social Survey | participation and trust items, with multilevel NUTS files | FR, DE, IT in most rounds | ESS Data Portal, free registration | portal confirmed, variable names not checked |
| 11 | Eurofound EQLS, UK Data Service SN 7348 | volunteering ever and at least monthly, self-assessed urban or rural | 2003 to 2016 | UK Data Service registration | documentation seen, NUTS detail not confirmed |
| 12 | INSEE Base permanente des équipements | counts of facilities, including sport, leisure and culture | commune and IRIS, annual. 2025 edition published July 2026 | free CSV | [S] INSEE page |
| 13 | Ministry of Sports, Data ES | about 330,000 sports facilities, about 90 variables including year of commissioning | France, facility level | data.gouv.fr, API, open licence | secondary: search summary of official pages |
| 14 | German Freiwilligensurvey | engagement rates, with a Länder report for 2019 | 1999, 2004, 2009, 2014, 2019. 2024 wave collected | scientific use files now at GESIS | [S] DZA page. Regional identifiers not confirmed |
| 15 | ISTAT Aspetti della vita quotidiana | unpaid activity in voluntary associations | annual since 1993, about 25,000 households, regional | IstatData, public-use microdata | official pages via search |
| 16 | ISTAT non-profit census and register | institutions, employees, volunteers | 2011, 2015, 2021, annual register 2016-2023, regional | dati-censimentipermanenti.istat.it | [S] ISTAT page |
| 17 | INSEE Analyses 104, data file | consumption, saving and income around job loss, by liquidity quartile | France 2020-2024 | spreadsheet on the page | [S] |
| 18 | ECB HFCS | liquid wealth, hand-to-mouth shares, by place from the 2021 wave | 2010, 2014, 2017, 2021 | application to the ECB | wave list from ECB pages |
| 19 | Eurostat ilc_mdes04, ilc_mdes04_r | inability to face unexpected expenses | national from 2003, NUTS2 from 2021 | API | [S] codes |
| 20 | Eurostat env_ac_ghgfp | consumption-based greenhouse gas footprints (FIGARO) | national, 2010-2023 | API | [S] code |
| 21 | JRC EDGAR NUTS2 | territorial emissions by sector | NUTS2, 1990-2023 | spreadsheet | official page via search. Production-based, not consumption-based |

No official regional consumption-based footprint was found. The peer-reviewed substitutes are Ivanova et al. (2017), Environmental Research Letters 12(5), 054013, for 177 EU regions, and Ottelin, Heinonen, Nässén and Junnila (2019), same journal, 14(11), 114016, by degree of urbanisation [M both].

**A comparability warning.** Formal volunteering falls between the two EU-SILC modules by far more than behaviour plausibly changed: France 23.0 to 15.6 percent and Italy 12.0 to 5.3 [S]. Eurostat's Statistics Explained attributes part of the fall to the pandemic years (official page, read through a summary). The two modules should not be pooled, and levels should be taken from one module only.

**Which dataset is an untargeted test of which prediction.**

| prediction | test | status |
|---|---|---|
| S: participation by education within country | rows 1 and 14, 15 | untargeted only if the gradient is generated by A and not imposed |
| S: gap between employed and unemployed | row 6 | already imposed from the survey measure, so the diary measure is a consistency check, and it disagrees |
| S+E: participation by degree of urbanisation | row 2, 2015 | untargeted for France and Germany if place enters only through measured channels |
| E: regional participation, Germany | row 14, Länder | untargeted, and the natural second country after Italy |
| E: regional participation, France | row 4 or ESS, against rows 12 and 13 | untargeted, needs microdata |
| E: infrastructure to participation, Italy | rows 15 and 16 | not independent if non-profit density sets omega: use it as input or as test, not both |
| A: consumption drop by liquidity | row 17 | untargeted for France |
| A: expected income loss, by country and education | row 9 | untargeted |
| E: social support by region | row 8 | untargeted but coarse (Gallup samples) |

---

## 6. Synthesis (my assessment, separate from the evidence above)

### S

1. **Well grounded.** The functional form is Brock and Durlauf's, the stability of the extreme equilibria and the welfare ranking are in the paper, and the multiplier range of 1.3 to 1.8 sits inside the 1.3 to 2.2 reported for membership, voting and giving. The education gradient and the effect of unemployment on public social activity both have causal support.
2. **Thin.** There is no direct multiplier estimate for volunteering, so the range is borrowed. A referee would raise Manski's reflection problem against any multiplier read off regional correlations, would ask why the highest equilibrium is selected when learning and global-games arguments can select another, and could point to the time-use data in which the unemployed do not participate less.
3. **Corroborations, by value for effort.** First, reconcile the imposed employment gap with HETUS (one API call, done here, needs one paragraph). Second, report whether beta J exceeds one at the calibration, since below one the selection question disappears. Third, the Freiwilligensurvey by Land as an untargeted regional test for Germany.

### A

1. **Well grounded.** The indicator has two official counterparts with published definitions, and France has an official conditional benchmark of a 15 percent consumption drop at six months with a liquidity gradient from 58 to 17 percent of the income loss.
2. **Thin.** The link from Sen's capability to a single insurance statistic is the author's construction, and the capability literature would call it one functioning among many. Germany and Italy have no verified consumption-drop estimate. A referee would also note that the BPP coefficient concerns permanent shocks, while job loss in the model is transitory.
3. **Corroborations.** First, compare the model's drop by liquidity quartile with INSEE figure 2a, which is cheap and untargeted. Second, compare the model's expected income loss with OECD labour market insecurity for the three countries (3.1, 1.4, 8.6 percent) and by education. Third, obtain the published tables of Bentolila and Ichino for Germany and Italy.

### E

1. **Well grounded.** Civic capital as a persistent local stock (Putnam; Guiso, Sapienza and Zingales), a local supply channel from organisations to volunteering (Mohan and Bennett), a quasi-experiment on lost infrastructure (Meier and Stutzer), and a rural premium in official data for France and Germany.
2. **Thin.** No published elasticity benchmarks epsilon, so 0.3 to 0.5 stands on one country. The Italian measure is the weak point: non-profit institutions per head is close to the outcome it explains, and the persistence literature treats that kind of variable as a measure of civic capital, so a referee will call the 0.89 correlation partly mechanical and partly reverse causality. Roskruge et al. find selection and free riding, Guiso, Sapienza and Zingales (2004) show that movers carry their province's trust, and Geraci et al. show infrastructure that lowers participation. The assumption of no migration also runs against Bilal and Rossi-Hansberg.
3. **Corroborations.** First, re-estimate epsilon on France with pre-1990 sports facilities from Data ES, which is predetermined and physically distinct from participation, and report it beside the Italian value. Second, in Italy replace institutions per head in 2011 with a lagged or historical measure and show the fit survives. Third, test the regional prediction on German Länder, where infrastructure did not enter the calibration at all.

---

## Sources verified

URLs are those opened or queried on 2026-10-02.

**Read in the source [S]**
- Brock, W. A. and Durlauf, S. N. (2001). Discrete choice with social interactions. Review of Economic Studies 68(2), 235-260. https://hceconomics.uchicago.edu/sites/default/files/pdf/events/Brock_Durlauf_2001_REStud_v68-N2.pdf
- Glaeser, E. L., Sacerdote, B. I. and Scheinkman, J. A. (2002). The social multiplier. NBER Working Paper 9153. https://www.nber.org/papers/w9153. Published in Journal of the European Economic Association 1(2-3), 345-353 (2003).
- Bonnet, O., Olivia, T., Le Grand, F., Ragot, X. and Wilner, L. (2025). Lorsqu'ils perdent leur emploi, les ménages diminuent-ils leur épargne ou réduisent-ils leurs dépenses ? INSEE Analyses 104. https://www.insee.fr/fr/statistiques/8356347
- Hijzen, A. and Menyhért, B. (2016). Measuring labour market security and assessing its implications for individual well-being. OECD Social, Employment and Migration Working Papers 175. https://www.oecd.org/en/publications/measuring-labour-market-security-and-assessing-its-implications-for-individual-well-being_5jm58qvzd6s4-en.html
- OECD. How's Life? Well-being database, definitions and metadata. https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/measuring-well-being-and-progress/oecd-well-being-database-definitions.pdf. Data: https://sdmx.oecd.org/public/rest/data/OECD.WISE.WDP,DSD_HSL@DF_HSL_CWB
- OECD (2025). OECD Regional Well-Being: a user's guide. https://www.oecdregionalwellbeing.org/assets/downloads/Regional-Well-Being-User-Guide.pdf
- Stiglitz, J. E., Sen, A. and Fitoussi, J.-P. (2009). Report by the Commission on the Measurement of Economic Performance and Social Progress. https://ec.europa.eu/eurostat/documents/8131721/8131772/Stiglitz-Sen-Fitoussi-Commission-report.pdf
- Eurostat tables ilc_scp19, ilc_scp20, tus_00selfstat, and the table of contents for all other codes. https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ and https://ec.europa.eu/eurostat/api/dissemination/catalogue/toc/txt?lang=en
- CORDIS, WISE Horizons, grant 101095219. https://cordis.europa.eu/project/id/101095219
- INSEE, Base permanente des équipements 2025. https://www.insee.fr/fr/statistiques/8217527?sommaire=8217537
- DZA, German Survey on Volunteering. https://www.dza.de/en/research/fdz/german-survey-on-volunteering
- ISTAT, non-profit census results. https://www.istat.it/statistiche-per-temi/censimenti/istituzioni-non-profit/risultati/

**Abstract read [A]**
- Alesina, A. and La Ferrara, E. (2000). Quarterly Journal of Economics 115(3), 847-904. https://ideas.repec.org/a/oup/qjecon/v115y2000i3p847-904..html
- Algan, Y. and Cahuc, P. (2010). Inherited trust and growth. American Economic Review 100(5), 2060-2092. https://www.aeaweb.org/articles?id=10.1257/aer.100.5.2060
- Alkire, S. and Foster, J. (2011). Journal of Public Economics 95(7-8), 476-487. https://ideas.repec.org/a/eee/pubeco/v95y2011i7-8p476-487.html
- Bauer, T. K., Bredtmann, J. and Schmidt, C. M. (2013). European Journal of Political Economy 32, 80-94. https://ideas.repec.org/a/eee/poleco/v32y2013icp80-94.html
- Bentolila, S. and Ichino, A. (2008). Journal of Population Economics 21(2), 255-280. https://doi.org/10.1007/s00148-006-0081-z. Abstract of CEPR DP 2539: https://econpapers.repec.org/RePEc:cpr:ceprdp:2539
- Bilal, A. and Rossi-Hansberg, E. (2021). Econometrica 89(5), 2459-2495. https://www.econometricsociety.org/publications/econometrica/2021/09/01/location-asset
- Blume, L. E., Brock, W. A., Durlauf, S. N. and Ioannides, Y. M. (2011). Handbook of Social Economics 1B, 853-964. https://www.sciencedirect.com/science/article/abs/pii/B9780444537072000013
- Blundell, R., Pistaferri, L. and Preston, I. (2008). American Economic Review 98(5), 1887-1921. https://www.aeaweb.org/articles?id=10.1257/aer.98.5.1887
- Bolet, D. (2021). Comparative Political Studies 54(9), 1653-1692. https://doi.org/10.1177/0010414021997158
- Browning, M. and Crossley, T. F. (2001). Journal of Public Economics 80(1), 1-23. https://ideas.repec.org/a/eee/pubeco/v80y2001i1p1-23.html
- Brueckner, J. K. and Largey, A. G. (2008). Journal of Urban Economics 64(1), 18-34. https://ideas.repec.org/a/eee/juecon/v64y2008i1p18-34.html
- Chetty, R., Jackson, M. O., Kuchler, T., Stroebel, J. et al. (2022). Social capital I. Nature 608, 108-121. https://doi.org/10.1038/s41586-022-04996-4. Abstract of NBER w30313: https://ideas.repec.org/p/nbr/nberwo/30313.html
- Dee, T. S. (2004). Journal of Public Economics 88(9-10), 1697-1720. https://ideas.repec.org/a/eee/pubeco/v88y2004i9-10p1697-1720.html
- Durante, R., Mastrorocco, N., Minale, L. and Snyder, J. M. (2025). Unpacking social capital. Economic Journal 135(667), 773-807. https://ideas.repec.org/a/oup/econjl/v135y2025i667p773-807..html
- Freeman, R. B. (1997). Journal of Labor Economics 15(1), S140-S166. https://econpapers.repec.org/RePEc:ucp:jlabec:v:15:y:1997:i:1:p:s140-66
- Frey, B. S. and Meier, S. (2004). American Economic Review 94(5), 1717-1722. https://www.aeaweb.org/articles?id=10.1257/0002828043052187
- Ganong, P. and Noel, P. (2019). American Economic Review 109(7), 2383-2424. https://ideas.repec.org/a/aea/aecrev/v109y2019i7p2383-2424.html
- Geraci, A., Nardotto, M., Reggiani, T. and Sabatini, F. (2022). Journal of Public Economics 206, 104578. https://ideas.repec.org/a/eee/pubeco/v206y2022ics0047272721002140.html
- Gilpin, G., Karger, E. and Nencka, P. (2024). American Economic Journal: Economic Policy 16(2), 78-109. https://www.aeaweb.org/articles?id=10.1257/pol.20210300
- Glaeser, E. L., Laibson, D. and Sacerdote, B. (2002). Economic Journal 112(483), F437-F458. https://onlinelibrary.wiley.com/doi/abs/10.1111/1468-0297.00078
- Gruber, J. (1997). American Economic Review 87(1), 192-205. Abstract of NBER w4750: https://www.nber.org/papers/w4750
- Guiso, L., Sapienza, P. and Zingales, L. (2004). American Economic Review 94(3), 526-556. https://www.aeaweb.org/articles?id=10.1257/0002828041464498
- Guiso, L., Sapienza, P. and Zingales, L. (2016). Journal of the European Economic Association 14(6), 1401-1436. https://econpapers.repec.org/RePEc:oup:jeurec:v:14:y:2016:i:6:p:1401-1436.
- Huang, J., Maassen van den Brink, H. and Groot, W. (2009). Economics of Education Review 28(4), 454-464. https://ideas.repec.org/a/eee/ecoedu/v28y2009i4p454-464.html
- Jansen, A., Wang, R., Behrens, P. and Hoekstra, R. (2024). Lancet Planetary Health 8(9), e695-e705. https://doi.org/10.1016/S2542-5196(24)00147-5
- Kaplan, G. and Violante, G. L. (2010). American Economic Journal: Macroeconomics 2(4), 53-87. https://www.aeaweb.org/articles?id=10.1257/mac.2.4.53
- Kolsrud, J., Landais, C., Nilsson, P. and Spinnewijn, J. (2018). American Economic Review 108(4-5), 985-1033. https://www.aeaweb.org/articles?id=10.1257/aer.20160816
- Kunze, L. and Suppa, N. (2017). Journal of Economic Behavior and Organization 133, 213-235. https://ideas.repec.org/a/eee/jeborg/v133y2017icp213-235.html
- Landais, C. and Spinnewijn, J. (2021). Review of Economic Studies 88(6), 3041-3085. https://researchonline.lse.ac.uk/id/eprint/105861/
- Manski, C. F. (1993). Review of Economic Studies 60(3), 531-542. https://ideas.repec.org/a/oup/restud/v60y1993i3p531-542..html
- Meer, J. (2011). Journal of Public Economics 95(7-8), 926-941. https://ideas.repec.org/a/eee/pubeco/v95y2011i7p926-941.html
- Meier, S. and Stutzer, A. (2008). Economica 75(297), 39-59. https://ideas.repec.org/a/bla/econom/v75y2008i297p39-59.html
- Mohan, J. and Bennett, M. R. (2019). Environment and Planning A 51(4), 950-979. https://doi.org/10.1177/0308518X19831703
- Nickerson, D. W. (2008). American Political Science Review 102(1), 49-57. https://ideas.repec.org/a/cup/apsrev/v102y2008i01p49-57_08.html
- Paarlberg, L. E., Nesbit, R., Choi, S. Y. and Moss, R. (2022). Voluntas 33(1), 107-120. https://doi.org/10.1007/s11266-021-00401-2
- Pawlowski, T., Steckenleiter, C., Wallrafen, T. and Lechner, M. (2021). Labour Economics 70, 101996. https://ideas.repec.org/a/eee/labeco/v70y2021ics0927537121000312.html
- Pohlan, L. (2019). Journal of Economic Behavior and Organization 164, 273-299. https://ideas.repec.org/a/eee/jeborg/v164y2019icp273-299.html
- Rodríguez-Pose, A. (2018). Cambridge Journal of Regions, Economy and Society 11(1), 189-209. https://eprints.lse.ac.uk/85888/
- Roskruge, M., Grimes, A., McCann, P. and Poot, J. (2012). International Regional Science Review 35(1), 3-25. https://doi.org/10.1177/0160017611400068
- Satyanath, S., Voigtländer, N. and Voth, H.-J. (2017). Journal of Political Economy 125(2), 478-526. https://doi.org/10.1086/690949. Abstract of NBER w19201: https://www.nber.org/papers/w19201
- Shang, J. and Croson, R. (2009). Economic Journal 119(540), 1422-1439. https://ideas.repec.org/a/ecj/econjl/v119y2009i540p1422-1439.html
- Smith, S., Windmeijer, F. and Wright, E. (2015). Economic Journal 125(585), 1053-1071. https://doi.org/10.1111/ecoj.12114. Working paper abstract: https://ideas.repec.org/a/wly/econjl/v125y2015i585p1053-1071.html
- Sørensen, J. F. L. (2016). Regional Studies 50(3), 391-410. https://ideas.repec.org/a/taf/regstd/v50y2016i3p391-410.html
- Wicker, P., Hallmann, K. and Breuer, C. (2013). Sport Management Review 16(1), 54-67. https://ideas.repec.org/a/eee/spomar/v16y2013i1p54-67.html

**Record confirmed only [M]** (Crossref, https://api.crossref.org/works/ plus the DOI)
- Algan and Cahuc (2014), Handbook of Economic Growth 2, 49-120, 10.1016/B978-0-444-53538-2.00002-2. Alkire (2002), Valuing Freedoms, Oxford University Press, https://global.oup.com/academic/product/valuing-freedoms-9780199245796. Andreoni and Scholz (1998), 10.1111/j.1465-7295.1998.tb01723.x. Bilal (2023), 10.1093/qje/qjad010. Blume and Durlauf (2003), 10.1142/S021919890300101X. Brock and Durlauf (2007), 10.1016/j.jeconom.2006.09.002. Buchanan (1965), 10.2307/2552442. Cantoni et al. (2019), 10.1093/qje/qjz002. Chetty and Hendren (2018), 10.1093/qje/qjy007 and 10.1093/qje/qjy006. Cooper and John (1988), 10.2307/1885539. Cornes and Sandler (1996), 10.1017/CBO9781139174312. Dijkstra, Poelman and Rodríguez-Pose (2020), https://econpapers.repec.org/RePEc:taf:regstd:v:54:y:2020:i:6:p:737-753. Fearon et al., 10.1016/j.ecolecon.2026.109221 (Crossref dates the volume 2027 and gives the title without "postgrowth"). Finlay et al. (2019), 10.1016/j.healthplace.2019.102225. Helliwell and Putnam (2007), 10.1057/eej.2007.1. Hoekstra (2019), 10.1017/9781108608558. Ivanova et al. (2017), 10.1088/1748-9326/aa6da9. Kandori, Mailath and Rob (1993), 10.2307/2951777. Latham and Layton (2019), 10.1111/gec3.12444. Liu et al. (2024), 10.1038/s41597-024-04006-4. Milgrom and Roberts (1990), 10.2307/2938316. Milligan, Moretti and Oreopoulos (2004), 10.1016/j.jpubeco.2003.10.005. Moretti (2011), 10.1016/S0169-7218(11)02412-9. Morris and Shin (2003), 10.1017/CBO9780511610240.004. Ottelin et al. (2019), 10.1088/1748-9326/ab443d. Putnam, Leonardi and Nanetti (1993), Princeton University Press, https://www.jstor.org/stable/j.ctt7s8r7. Robeyns (2005), 10.1080/146498805200034266. Samuelson (1954), 10.2307/1925895. Tiebout (1956), 10.1086/257839.
- For the JSTOR-era articles Crossref returns the first page only, so end pages are not given above.

## Could not verify

- **Hijzen and Menyhért (2016), country values.** The paper shows them in figures only. Use the OECD database values quoted in section 2b.
- **Guiso, Sapienza and Zingales (2016), measures and effect sizes.** Abstract only. The claim that non-profit organisations per head is one of their civic capital measures is from memory and must be checked in the article before the synthesis point on E is used in writing.
- **Putnam (1993), index components and correlations.** Secondary descriptions only.
- **Gibson (2001), twin result.** Secondary: seen through a search summary of the publisher abstract.
- **Brueckner and Largey (2008), sign of the density effect.** The abstract gives the design, the result is from a secondary description.
- **Wicker et al. (2013), the 2.9 percent odds figure** reported by a search summary: not in the abstract, not used.
- **Smith, Windmeijer and Wright (2015).** The published and working paper abstracts give 2.50 and 3.50 pounds. The article itself was not opened.
- **Bentolila and Ichino (2008), magnitudes by country.** Springer page behind a login.
- **Ganong and Noel (2019) and Kolsrud et al. (2018), size of the drop.** Not in the abstracts.
- **Andreoni and Scholz (1998), elasticity.** Not opened.
- **Sen (1985, 1999).** Not checked at the publisher.
- **CES Recommendations (2014).** UNECE PDF returned an access error. Theme allocation is secondary. URL attempted: https://unece.org/fileadmin/DAM/stats/publications/2013/CES_SD_web.pdf
- **Hoekstra (2019) and Jansen et al. (2024), dimension lists.** Records confirmed, content not read, so the corresponding cells in the section 4 table are left empty.
- **WISE Horizons deliverable 1.1 and WISE Accounts.** Seen on the project site (https://wisehorizons.eu/publications/), not opened.
- **Eurostat Statistics Explained on the 2015 to 2022 fall** (EU formal volunteering 18.9 to 12.3 percent, pandemic explanation): read through an automated summary of https://ec.europa.eu/eurostat/statistics-explained/index.php?title=Quality_of_life_indicators_-_governance_and_basic_rights. The country figures in section 5 are from the API and are solid.
- **Data access details not confirmed:** EU-SILC regional identifiers in the 2015 and 2022 modules, ESS volunteering variable names and rounds, EQLS regional coding, Freiwilligensurvey regional identifiers in the scientific use file, Data ES variable list, country coverage of the HETUS 2020 wave, and the French associations register.
- **No source found:** a published elasticity of volunteering with respect to facilities or organisations per head, a consumption-drop estimate at unemployment for Germany or Italy, an official regional consumption-based emissions series, and a social multiplier estimated for volunteering.

# E as the environment people live in: concept (agreed 2026-09-27)

Status: concept agreed with the user. Feasibility study in progress (data, literature, modelling). It is to be built after A version 2 and one clean recalibration of S+G+A, and designed while the HFCS application is pending.

## Framing

In Snower and Lima de Miranda, E is environmental sustainability. Here E is **the environment people live in**, with two sides. That keeps the label legitimate and matches how the OECD wellbeing framework treats environmental quality, as something individuals experience where they live.

- **What a place gives you:** closeness to jobs and services, broadband, health care, clean air and green space.
- **What it costs:** commuting time, pollution, and later the sustainability cost of consumption (emissions). Sustainability is not dropped. It is the cost side, added later.

## The simple version

Households live in one of **three place types**, Eurostat's degree of urbanisation: cities, towns and suburbs, rural areas. Place is **fixed**, with no migration and no housing market, like education. Cells become education × place, 2 × 3 = 6.

Places differ through **three channels**, each connected to a dimension already in the model:

| channel | what differs by place | connects to |
|---|---|---|
| Access to work | job-finding and job-loss rates; commuting time taken from the day | G (earnings, time) and A (security) |
| Conversion | how effort and time turn into results: broadband and services raise the return to effort (Sen's conversion factors) | A (capability) |
| Community | the time cost of taking part; how connected people are across groups (homophily by place, the European stand-in for Chetty et al. 2022's economic connectedness) | S (participation, social feedback) |

Environmental quality (air, green space) enters wellbeing as an amenity of the place.

**Reduction.** With the three place types identical, the model gives back today's economy exactly.

## What the HFCS adds by place

If the HFCS records where households live, liquid buffers by place give security and room to manoeuvre (Sen's capability set) by place, and hand-to-mouth targets by place. This is to be checked in the feasibility study.

## Guardrails

- No migration and no housing market in the first version.
- Three channels only, each with a data target.
- Built only on a clean, audited S+G+A.

## Feasibility study (2026-09-27)

Results below as they come in.

### Data side (collected with `data/place/collect_place_data.py`, output `data/place/place_by_degurba.csv`)

Eurostat publishes almost every ingredient by degree of urbanisation, harmonised for the EU. France, Germany and Italy; cities / towns and suburbs / rural areas:

| indicator (year, table) | FR | DE | IT |
|---|---|---|---|
| population share (2023, ilc_lvho01) | 37 / 30 / 34 | 40 / 41 / 20 | 35 / 47 / 18 |
| tertiary share, 25-64 (2015, edat_lfs_9913) | 42 / 31 / 26 | 34 / 25 / 23 | 24 / 15 / 12 |
| unemployment, 20-64 (2023, lfst_r_urgau) | 7.9 / 7.5 / 5.5 | 3.9 / 2.7 / 1.8 | 8.7 / 7.0 / 6.9 |
| quarterly U to E, 25-54 (2015-18, lfsi_long_e03) | 20.5 / 21.5 / 25.2 | not published | 13.8 / 14.5 / 16.0 |
| one-way commute, minutes (2019, lfso_19plwk28) | 28 / 25 / 24 | 28 / 25 / 25 | 24 / 20 / 20 |
| household broadband (2021, isoc_ci_it_h) | 93 / 87 / 82 | 90 / 88 / 88 | 90 / 89 / 85 |
| median income, EUR (2023, ilc_di17) | 25,987 / 24,793 / 25,701 | 27,199 / 28,445 / 28,789 | 21,397 / 20,426 / 20,101 |
| unmet medical need, access (2023, hlth_silc_21) | 3.4 / 4.1 / 3.7 | 0.3 / 0.2 / 0.1 | 1.8 / 1.6 / 2.6 |
| formal volunteering (2015, ilc_scp20) | 20 / 21 / 28 | 24 / 30 / 35 | 11 / 12 / 12 |
| someone to ask for help (2015, ilc_scp16) | 93 / 93 / 93 | 95 / 97 / 97 | 86 / 86 / 89 |
| pollution, grime (2023, ilc_mddw05) | 24 / 15 / 9 | 22 / 15 / 9 | 14 / 9 / 5 |
| life satisfaction (2022, ilc_pw02) | 7.0 / 6.9 / 7.0 | 6.6 / 6.4 / 6.4 | 7.2 / 7.1 / 7.2 |

**What the data say about the three channels, on this axis:**

- **Access to work runs the "wrong" way, or not at all.** Rural areas have lower unemployment, better job finding and shorter commutes than cities in France and Germany. The degree of urbanisation separates composition (the tertiary-educated concentrate in cities), amenities (pollution), broadband and community (rural volunteering is a third higher in France and Germany), but not opportunity. Part of this is sorting: who lives where.
- **Opportunity gaps in Europe are regional.** Grouping NUTS2 regions by the EU cohesion-policy rule (GDP per head in PPS relative to the EU, 2015-17 mean, my replication of the Commission's categories) gives unemployment in 2023 of:
  - Italy: 14.5 percent in less-developed regions (27 percent of its labour force), 6.4 in transition regions, 4.9 in more-developed regions;
  - France: 6.6 and 6.9, with no less-developed mainland region;
  - Germany: 3.2 and 3.0.

  Only Italy has a large opportunity gap by place, and it is regional.
- **Consequence for the design.** Place should be a generic layer with an interchangeable typology: degree of urbanisation (amenities, community, broadband, commuting) or regional development category (opportunity). This links directly to the regional ecosystem papers and to cohesion policy as the place-based policy. The model code need not know which typology is used.
- **Coverage gaps:**
  - The flows by place stop in 2018, are published as whole percentages, and are missing for Germany.
  - Volunteering by place is missing for Germany in 2022.
  - Economic connectedness has no European source.

### Modelling side

- **The household solver is cell-agnostic.** The two-cell assumption sits in the wrapper (about 60 places, mostly sage_modular.jl).
- **Place can be a layer over the existing engine.** Each place type is its own economy with its own flows, alpha, community and amenities. The places are tied by national financing (one benefit tax and levy), and the social feedback is local within a place. That needs no rewrite of the core, and identical places reduce to today's model by construction.
- **Compute grows linearly** in the number of places, and they run in parallel.
- **New code needed:**
  - commuting as a time cost per unit of work, a new solver parameter;
  - the national-financing wrapper;
  - amenities in the wellbeing overlay.

### HFCS by place (from the public ECB documentation; whether the variables are filled in for FR, DE and IT needs the data)

| wave | degree of urbanisation (DHDEGURBA) | region (DHREGION) |
|---|---|---|
| 2010, 2014 | not in the catalogue | not in the catalogue |
| 2017 | not in the catalogue | FR NUTS1 (8 ZEAT), DE 4 groups of Länder (not NUTS1), IT 20 regioni |
| 2021, 2023 | yes, 3 classes (cities, towns and suburbs, rural) | as in 2017 |

Sources: HFCS UDB documentation, 2017 wave (June 2021) pp. 162-163; 2021 wave (July 2023) pp. 165, 170-172; 2023 derived variables (June 2026) pp. 24, 28-30.

- **KVW liquid and illiquid wealth can be built from components:**
  - liquid assets: deposits DA2101, funds DA2102, bonds DA2103, listed shares DA2105;
  - liquid debt: DL1210, DL1220;
  - illiquid wealth: DA1110, other property, DA2109;
  - income: gross annual income DI2000.
  - Cash is not collected.
- **Hand-to-mouth and buffers by degree of urbanisation are feasible from 2021 and 2023,** and by region from 2017.
- **The ECB's own tables publish nothing by place, and no published paper was found with HFCS hand-to-mouth by urban/rural or region.** That looks like an open niche and a possible contribution in its own right.
- **Cells will be thin** for Italy's regions × urbanisation, and Germany's four Länder groups are coarse. For Italy, north / centre / south from the regioni is the natural regional split.

### Literature (review 2026-09-27; [A] means the abstract only was read, to be checked before citing)

- **Access to work.**
  - Bilal (2023, QJE) [A]: in French administrative data, spatial unemployment gaps come mainly from separation rates driven by local employers. This is the template for place-specific flows.
  - Stutzer and Frey (2008, SJE): in the SOEP, one hour of one-way commuting lowers life satisfaction by 0.20 on a 0-10 scale, and full compensation for the mean commute is about 35 percent of labour income.
  - Dickerson, Hole and Munford (2014, RSUE) [A] find no life-satisfaction effect in the UK, a counterweight.
  - Gutierrez-i-Puigarnau and van Ommeren (2010, JUE) [A]: commuting barely changes hours.
  - Aslund, Osth and Zenou (2010, JEG) [A]: Swedish quasi-experiment, doubling nearby jobs raises employment by 2.9 points.
- **Conversion.**
  - Urban wage premium net of sorting: France density elasticity about 0.03 (Combes, Duranton and Gobillon 2008, JUE); Spain 0.022 static, 0.051 with learning (De la Roca and Puga 2017, ReStud); Italy 0.022 (Mion and Naticchioni 2009, as reported by De la Roca and Puga).
  - Broadband raises skilled wages and lowers low-skilled wages (Akerman, Gaarder and Mogstad 2015, QJE), so conversion depends on education type.
  - German DSL coverage raises re-employment by 1.3 to 2.3 points (Gurtzgen et al. 2021, EER; working-paper numbers).
- **Community.**
  - Chetty et al. (2022, Nature I and II) [A]: economic connectedness predicts mobility, while volunteering does not.
  - There is no European analogue of economic connectedness. The Facebook European index (Bailey et al. 2020) measures links between regions, not across social status.
  - Italian civic capital is regional (Guiso, Sapienza and Zingales 2016, JEEA) [A].
- **Amenities.**
  - Raw life satisfaction is flat by place type in all three countries.
  - With controls, rural EU residents are more satisfied (Sorensen 2014, Regional Studies) [A].
  - German air-quality valuation: Luechinger (2009, EJ).
  - Green space: White et al. (2013, Psychological Science) [A].
  - Nothing comparable exists for FR or IT.
- **Method and policy.** Gaubert, Kline, Vergara and Yagan (2025, AER) [A] on place-based redistribution. Austin, Glaeser and Summers (2018, BPEA) [A] on targeting employment policy where non-employment is high. No published Bewley model with fixed place types and no migration was found: either a contribution or a warning sign.

**Evidence strength by channel:**

| channel | strength | note |
|---|---|---|
| access | strong in levels, medium in flows | flows are thin |
| conversion | medium for FR and DE, weak for IT | |
| community | medium for participation | weak for connectedness |
| amenities | weak as a target | validation only |

Italy is the weakest country throughout on the degree-of-urbanisation axis. Its place story is regional.

### Modelling test: the access channel alone (France, `SAGE_Bewley/scripts/probe_place_fr.jl`)

France's calibrated G+S+A economy was solved once per place type, changing only the job-finding rate (scaled by the place's quarterly U to E probability) and the separation rate (from the place's unemployment rate). The inputs are pre-audit, so this tests the mechanism, not the numbers.

| | job finding | unemployment | participation (model) | formal volunteering (data, 2015) | poor htm | A_cond |
|---|---|---|---|---|---|---|
| cities | 0.719 | 6.9% | 24.2% | 20.3% | 0.023 | 0.750 |
| towns | 0.755 | 6.5% | 24.4% | 21.4% | 0.023 | 0.750 |
| rural | 0.884 | 4.8% | 25.6% | 27.7% | 0.040 | 0.746 |

1. **Access alone gives a rural premium of 1.4 points against 7.4 in the data,** about a fifth. It works mainly through composition: fewer unemployed, who participate at half the employed rate.
2. **The rest must come from the community channel** (local feedback, belonging, the time cost of joining). Education composition works the other way, since rural areas have fewer tertiary-educated people.
3. **Better job security lowers precautionary saving,** so rural poor hand-to-mouth rises from 0.023 to 0.040. Agency in the if-hit sense barely moves, because a lower chance of job loss leaves the loss if it happens unchanged.
4. **The layer works mechanically,** and the responses are small and well behaved.

**Feasibility verdict (2026-09-27):**

- **Data:** good on the degree-of-urbanisation axis for all three countries (Eurostat, harmonised). The HFCS supports place from 2017 (region) and 2021 (urbanisation). Economic connectedness has no European source.
- **Economics:** in France and Germany, place acts mainly through community and amenities. In Italy it acts through opportunity, which is regional. So the typology must be interchangeable.
- **Modelling:** a wrapper over the existing engine, with local social feedback and national financing. Two new pieces are needed, commuting as a time cost and an amenity term in wellbeing.

The place layer stays scheduled after A version 2 and the clean recalibration.

## Community as the local public good: the omega-by-place test (2026-09-27)

In the model the payoff to participation scales with the community fabric, omega + (1 - omega) × participation. The second term is the public good that S produces. omega is the fabric that exists regardless of this year's participation, the stock of community infrastructure. With place, both become local, and omega by place can be measured. The test is whether measured infrastructure lines up with participation by place, which it was not fitted to.

**France, by degree of urbanisation.**

- Scripts: `data/place/community_infrastructure_fr.py` (INSEE Base permanente des equipements 2025) and `data/place/associations_fr.py` (Repertoire national des associations, September 2026).
- Classes come from the INSEE grille communale de densite 2025, with population from 2022.

| per 1,000 inhabitants | cities | towns | rural | rural / cities |
|---|---|---|---|---|
| sport, leisure and culture facilities | 1.68 | 3.14 | 6.08 | 3.63 |
| libraries | 0.06 | 0.15 | 0.51 | 8.9 |
| health and social action facilities | 11.8 | 11.6 | 7.4 | 0.62 |
| France services centres | 0.015 | 0.036 | 0.075 | 5.1 |
| registered associations, active | 45.3 | 34.8 | 39.3 | 0.87 |
| active, declared or updated since 2015 | 20.4 | 19.4 | 23.8 | 1.17 |
| sports associations | 5.1 | 6.6 | 7.8 | 1.53 |
| **formal volunteering, % (EU-SILC 2015)** | **20.3** | **21.4** | **27.7** | **1.36** |

- Every community measure is higher in rural France, and the volunteering premium sits within the range of the association measures.
- Facility counts per person overstate rural capacity, since every commune has its own pitch and hall.
- The raw association count is inflated in cities by national federations registered in Paris. The liveness proxy removes most of that.
- Health and social services run the other way, and so does the public employment service. That is the access side of E, and France services is the place-based policy that targets it.
- About 3 percent of active associations could not be placed (cedex postcodes).

**Italy, by macro-area.**

- Non-profit institutions per 10,000 inhabitants in 2021: ISTAT BES at local level, indicator 05REL008, population-weighted over regions.
- Organised volunteering in the last four weeks: ISTAT, Il volontariato in Italia, 2023. ISTAT publishes neither indicator by urbanisation.

| | non-profits per 10,000 | organised volunteering 2023 (2013), % |
|---|---|---|
| north-west | 63.3 | 7.6 (9.4) |
| north-east | 70.1 | 9.1 (10.2) |
| centre | 67.8 | 5.8 (7.9) |
| south | 48.3 | 3.3 (5.3) |
| islands | 53.0 | 4.3 (5.9) |

The ranking matches except for the centre, where Rome's national organisations inflate the count (the Paris effect). Participation varies more than infrastructure: from the north-east to the south, non-profits fall by 31 percent and volunteering by 64 percent. That is the signature of local social feedback amplifying a difference in the fabric.

**What this shows.**

1. **Measured community infrastructure lines up with participation by place, in both countries and on both typologies.** omega by place is measurable, and it carries the effect that access to work could not.
2. **The mapping from infrastructure to omega needs one elasticity.** The implied elasticity of participation to infrastructure is above one in Italy, from about 2.7 on non-profits, and around 1 to 2 in France depending on the measure. A multiplier above one explains that naturally. This is the identification route for the social multiplier that national levels could not give.
3. **Caveats:**
   - there are few observations;
   - the Italian gradient also reflects income, unemployment and centuries of civic history (Guiso, Sapienza and Zingales 2016), which the model partly captures through the access channel and composition;
   - infrastructure is partly an outcome of past participation, so omega is best read as the slow-moving stock and participation as the fast variable;
   - Germany has no comparable official register by place (Vereine by Land only).

**Design consequence.**

- omega by place = omega × (infrastructure_p / infrastructure_national)^epsilon.
- epsilon is set on one country and tested on the other.
- This turns the community channel from a residual into a measured input with one parameter and an out-of-sample test.
- Public investment in community infrastructure becomes a policy lever acting through omega, which the local social feedback amplifies.

## Plan items added 2026-09-27 (shoring up the limits)

1. **Predetermined infrastructure, against two-way causality.** Measure omega by place with facilities that predate today's participation. The French Ministry of Sport's census of sports facilities (Recensement des equipements sportifs, open data) records each facility's year of entry into service. Use facilities opened before a cut-off (for instance 1990) as the predetermined stock, and report the elasticity with and without the cut-off. Look for the Italian analogue, such as ISTAT or CONI facility censuses with a construction date, or use the long-run civic capital of Guiso, Sapienza and Zingales (2016) as the predetermined stock by region.
2. **More observations.** Italy: organised volunteering for 21 regions (IstatData, VOLUNTEERING) against non-profits for 21 regions and 107 provinces (BES at local level). France: stay with the three density classes, plus the 13 metropolitan regions if volunteering by region can be found in an official source.
3. **Out-of-sample test.** Fit epsilon on one country and predict the other. If it fails, fall back to place-specific belonging calibrated directly (weaker E, same structure).
4. **The policy lever reported as a range** over epsilon (and over the predetermined against current measures), never as a point estimate.
5. **Germany** borrows epsilon and is checked against its own volunteering by place (ilc_scp20, 2015).

## Predetermined infrastructure and the Italian regions (2026-09-28)

Scripts: `data/place/sports_facilities_fr.py` (Recensement des equipements sportifs, Ministere des Sports, 333,695 facilities, Licence Ouverte) and `data/place/italy_regions.py` (ISTAT SDMX volunteering 2013, 2023 and 2010-2025; BES 05REL008 non-profits 2011 and 2021; Eurostat regional unemployment and tertiary share).

**France:** sports facilities per 1,000 inhabitants, by year of entry into service.

| | cities | towns | rural | rural / cities |
|---|---|---|---|---|
| all | 2.55 | 4.64 | 7.78 | 3.05 |
| before 1990 | 1.26 | 1.99 | 3.13 | 2.49 (bounds 2.34 to 2.63) |
| before 1975 | 0.59 | 0.76 | 1.15 | 1.93 |
| formal volunteering (EU-SILC 2015) | 20.3% | 21.4% | 27.7% | 1.36 |

The rural gradient of predetermined infrastructure is steeper than that of volunteering. The implied elasticity of participation to the stock is below one: about 0.3 to 0.5 on the log ratios. Two caveats apply:
- facility counts per head overstate rural capacity;
- "before 1990" means built then and still standing.

**Italy:** 21 regions, log-log slope of volunteering on non-profit density (standard error in brackets).

| pair | r | slope | slope with unemployment and tertiary share |
|---|---|---|---|
| organised volunteering 2023 on non-profits 2011 | 0.77 | 1.10 (0.18) | 0.35 (0.25) |
| annual survey 2023-25 on non-profits 2021 | 0.82 | 1.00 (0.16) | 0.39 (0.18) |
| same, without Bolzano and Trento | 0.65 | 0.78 (0.19) | 0.05 (0.11) |

The raw association is strong, and non-profit density in 2011 already predicts volunteering in 2023. With unemployment and education controlled for, most of it goes. There is no Rome headquarters effect in the counts: Lazio is at the national average.

**What this means for the design.**
1. **omega by place is a secondary channel.** In Italy, access to work and composition, which the model carries structurally, absorb most of the regional gradient. This supports building place with all three channels together, not community alone.
2. **The elasticity of participation to predetermined infrastructure is well below one:** about 0.3 to 0.5 in France, and about 0.3 to 0.4 with controls in Italy. It is identified from two countries that roughly agree. That is the out-of-sample check, passed tentatively.
3. **Evidence strength:** France's measure is the cleanest (predetermined and administrative). Italy's is cross-sectional with n = 21 and two influential alpine provinces.

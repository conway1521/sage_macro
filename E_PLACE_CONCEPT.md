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

## Economics specification, version 1 (2026-09-29)

**Why these variables:** see `WISE_MAPPING.md`, section E. The OECD Regional Well-Being topics and the CES here, later and elsewhere frame decide what is an input, a test, reported, or out of scope.

**Principle:** the place parameters come from data, and the national calibration is left as it is. E adds one free parameter, the community elasticity epsilon, which is reported as a range. Everything E predicts by place is untargeted: unemployment, volunteering and, later, the hand-to-mouth from the HFCS by place. That makes E a test of the model, not a fit.

**Structure.**
- **Cells:** education × place (2 × 3), with population and tertiary shares by place from `place_by_degurba.csv` (ilc_lvho01, edat_lfs_9913).
- **Social feedback is local:** each place has its own participation fixed point, and the community fabric omega_p + (1 - omega_p) × participation_p is local.
- **Financing is national:** one unemployment-insurance tax and one lump-sum tax across places.
- **Reduction:** three identical places give back the national economy exactly.

**Channel 1, access to work** (links to G and A):
- **Job finding f_p and separation delta_p by place,** from the quarterly unemployment-to-employment flows and unemployment rates by degree of urbanisation, converted to annual rates as the national ones are (`build_country_table.py`).
- **Commuting as time:** each unit of work costs (1 + tau_p) units of time, with tau_p = commuting minutes a day over working minutes a day, by place and education (Eurostat commuting by degree of urbanisation).
- **What it does:** it enters the time budget and the disutility of effort. The model already has a time floor; commuting scales with work rather than being fixed.
- **New solver parameter:** tau per state.

**Channel 2, conversion** (links to A, Sen's conversion factors):
- **alpha_{g,p} = alpha_g × c_p,** where c_p is the place premium in earnings that education composition does not explain. It is median income by place (ilc_di17) over the median predicted from the place's education mix at national education pay ratios.
- **Normalisation:** c_p averages to one nationally, so national calibration and reductions are unchanged.
- **Broadband and services are not a separate parameter in version 1.** Their effect sits inside c_p. They are reported beside it as the candidate mechanism.
- **Data gap:** no official source has earnings by degree of urbanisation and education together, so c_p is a residual, and I will label it as such.

**Channel 3, community** (links to S):
- **omega_p = omega × (infra_p / infra_national)^epsilon,** with predetermined infrastructure (French sports facilities from before 1990, Italian non-profit density in 2011).
- **epsilon is between 0.3 and 0.5,** from France and Italy. Results are reported at both ends.
- **Validation:** formal volunteering by place (EU-SILC 2015, ilc_scp20) is untargeted.

**Amenities** (wellbeing only, no choice in version 1):
- **Measures:** pollution and grime, unmet medical need for reasons of distance, and life satisfaction by place.
- **Role:** reported beside the model's wellbeing outputs by place, not fed into choices. Choices come later, and only with a source for the valuation.

**Outputs by place** (for the WISE audience): participation, agency and protection if hit, hardship, hand-to-mouth, effort, commuting time. Each is by education within place.

**Build order:**
- **E1: the place layer.** Six cells, local fixed points, national financing, and the reduction test in the suite.
- **E2: channel parameters by place** from the data (a script, with sources).
- **E3: France** with validation against unemployment and volunteering by place, then Germany and Italy.
- **E4: the HFCS-by-place layer,** when the data arrive: liquid buffers and hand-to-mouth by place as targets.
- **Later: housing by place** as E's illiquid asset, joining the two-asset parallel.

**Decisions made here, open to the user:**
- **E is built on the one-asset core first.** It is calibrated for all three countries and fast. It moves to two assets when that parallel is complete for the three countries.
- **Conversion is a composition-adjusted residual** in version 1, not a broadband elasticity.

## Build log

**2026-09-29, E1 and E2.**

- **The place layer** (`place_layer.jl`): each place is its own economy with local social feedback, financed nationally, with hardship against the national line. Three places identical to the nation reduce to it to 6e-16 (G+A and G+S+A), and the reduction is in the suite.
- **Channels from data:** composition, access to work, conversion (a labelled residual), commuting (a new EGM parameter, relative to the national mean, exact when zero), and community (France: sports facilities in service before 1990, epsilon 0.4 with ends 0.3 and 0.5).
- **First test, France G+S+A** (`test_places.txt`), rural over cities participation, against formal volunteering at 1.365:

| channels | ratio |
|---|---|
| composition only | 0.905 |
| access only | 1.022 |
| both | 0.925 |

- **Reading:**
  - Composition works against the data: rural areas have fewer tertiary-educated people, who take part more.
  - Access adds a little.
  - The rural premium must come from the community channel.
  - Composition also gives cities higher agency (1.02 against 0.96 rural) and better protection if hit (0.89 against 0.84), through the capability gradient.

**2026-09-29, all channels** (`run_places_{FR,DE,IT}.txt`). Rural over cities participation, against formal volunteering (EU-SILC 2015):

| | data | composition | access | conversion | commuting | community | all channels |
|---|---|---|---|---|---|---|---|
| France | 1.37 | 0.91 | 1.02 | | | 1.56 (epsilon 0.4) | 1.34 (epsilon 0.3) to 1.68 (epsilon 0.5) |
| Germany | 1.47 | 0.94 | 1.02 | 1.04 | 1.01 | no data | 1.07 (no community) |
| Italy | 1.07 | 0.94 | 1.00 | 0.94 | 1.01 | no data | 0.94 (no community) |

1. **The economic channels cannot produce the rural participation premium.** Composition works against it, and access, conversion and commuting each add 0 to 4%. In France and Germany, where the premium is large, it has to come from community.
2. **France with the community channel lands on the data at the low end of the elasticity range:** 1.34 at 0.3 against 1.37, with towns over cities at 1.12 against 1.05.
3. **How independent is the test?** The range 0.3 to 0.5 came partly from France's own raw ratio (volunteering 1.37 against predetermined infrastructure 2.49 gives about 0.34), so France is not fully out of sample. The independent evidence is Italy's regional estimate with controls, 0.35 to 0.39. At those values the French model gives about 1.44 to 1.53: a rural premium of the right sign and size, overshooting by 0.1 to 0.2.
   - What the model adds is structure. Local feedback makes the multiplier higher in cities (2.0) than in rural areas (1.7), because a thinner fabric leans more on participation itself.
4. **National participation drifts** from 0.233 to 0.228 with local feedback and heterogeneous fabric. A recalibration of kappa with places would restore it. Small, but noted.
5. **Italy:** the urban-rural premium is small in the data (1.07), and the model has composition dominating. Italian place differences are regional, so the regional typology is the right one for Italy. It is prepared in `italy_regions.py`.
6. **Germany:** there is no community infrastructure by place, so the channel that carries the premium cannot be measured. It could borrow the French or Italian elasticity with a proxy, or be reported as untested.
7. **Safer jobs, thinner buffers:**
   - In Germany, lower rural unemployment leads to less precautionary saving, far more asset poverty (hardship 0.47 against 0.18 in cities) and lower protection if hit.
   - The same sign appears in France, smaller.
   - This is a testable prediction for the HFCS by place. The size comes from the one-asset model and will shrink with two assets.

## The standard (agreed 2026-09-29): E as one schema over official geographies

**A place is a cell of an official statistical geography.** The place layer does not care which geography: it takes any partition of the population with a population share and the channel data. What makes E standard is a fixed data schema and one rule per channel, applied the same way under every typology.

| layer | standard | coverage | status |
|---|---|---|---|
| national | the calibrated model | FR, DE, IT; the US next | done (one asset); two assets in progress |
| **sub-layer, standard** | **OECD TL2 regions** | all 38 OECD countries | building (2026-09-29) |
| sub-layer, alternative | Degree of Urbanisation (UN standard 2020) | EU now; global where survey data exist | done (E1-E2) |
| sub-sub layer, later | the urban-rural classes of TL3 regions within a TL2 region | where data exist | later |

**Why TL2 is the standard sub-layer:**
- It is the level of the OECD Regional Well-Being indicators, the same eleven topics that ground E.
- It exists for every OECD country: US states, Canadian provinces, and so on.
- It gives many observations (France 18, Germany 16, Italy 21) for estimating and testing the community elasticity.

TL2 is NUTS 1 in France and Germany (régions, Länder) and NUTS 2 in Italy (regioni, with Bolzano and Trento separate), per the OECD Regional Well-Being user's guide (October 2025), Table 1.

**Caveats:**
- A TL2 region, like a place type, is a statistical unit, not the scale of social interaction. Local feedback is a representative-place approximation.
- Small regions have noisy survey indicators. Results are population-weighted, and small regions are flagged.

**The schema:** one file per typology, `data/place/place_<typology>.csv`, with columns indicator, country, place, year, value, source. Same indicators, same names, whatever the geography. `place_by_degurba.csv` is the first instance.

**The rule per channel**, identical across typologies:

| channel | rule | TL2 source (to verify in the build) |
|---|---|---|
| population | population share | Eurostat regional population (NUTS 1 or 2) |
| composition | tertiary share, scaled to the national share | Eurostat edat_lfse_04 |
| access | unemployment rate and long-term share. Job finding = 1 - long-term share, as the national table does; separation from steady state | Eurostat lfst_r_lfu3rt, lfst_r_lfu2ltu |
| conversion | disposable income per head over the education- and employment-predicted value | Eurostat nama_10r_2hhinc |
| commuting | national (0) where no regional data exist | none published by region |
| community | predetermined infrastructure, one elasticity | France: sports facilities before 1990 aggregated to régions; Italy: non-profits 2011 by region; Germany: clubs by Land (source to find) |
| validation (untargeted) | social support and life satisfaction; volunteering where official | OECD Regional Well-Being (TL2); ISTAT volunteering by region; the Freiwilligensurvey by Land |

**Beyond Europe:** the same schema with national official sources. For the US, state unemployment (BLS), education and commuting (Census, ACS), personal income (BEA), and volunteering (the Census/AmeriCorps volunteering supplement). The national US model is calibrated first.

## Sustainability: the cost side of E (agreed 2026-09-29)

E version 1 is the here and now of environment. Sustainability is added as the cost side, in the CES terms of later and elsewhere.

- **Consumption-based greenhouse-gas footprint:** emissions = intensity_p x consumption, with the intensity per euro of consumption varying by place (heating, car dependence, commuting). Consumption-based accounting includes emissions embodied in imports, so one measure covers both later (climate) and elsewhere (other countries).
- **Data (to source and verify):** national consumption-based footprints (Eurostat); regional footprints for EU regions from the peer-reviewed literature (Ivanova and co-authors, 2017, Environmental Research Letters, to check); OECD regional territorial emissions as a fallback elsewhere.
- **Outputs:** emissions per person by group and place in every scenario, beside the wellbeing indicators. A carbon tax with revenue recycling is a policy instrument.
- **Guardrail:** emissions are an output with a fixed intensity by place. There is no climate-damage feedback into wellbeing, which is a different and much larger model.
- **Valuation (optional, never the headline):**
  - The social cost of carbon turns emissions into the units of the welfare measure (consumption equivalents), so a scenario can show a net of wellbeing gained here and now against damage later and elsewhere.
  - A range of official values: the German Environment Agency's methodological convention, the European Investment Bank's shadow cost of carbon, France's valeur de l'action pour le climat, and the US EPA's 2023 estimate. Each is to be verified in its source before entering `data/manual_inputs.csv`.
  - The same values set the carbon tax in scenarios.
  - Physical emissions are always reported first, since much of the Beyond-GDP audience prefers them to a monetised figure.

**2026-09-29, E at TL2** (`run_places_tl2_{FR,DE,IT}.txt`; 14, 16 and 21 regions). Composition, access and conversion from Eurostat regional data. For Italy, community from non-profit density in 2011.

**Italy, the untargeted test,** against organised volunteering across 21 regions (ISTAT, 2023-25):

| channels | correlation | log-log slope | spread of log participation (model / data) |
|---|---|---|---|
| composition, access, conversion | 0.67 | 0.26 | 0.117 / 0.309 |
| plus community, epsilon 0.3 | 0.81 | 0.51 | 0.193 / 0.309 |
| plus community, epsilon 0.5 | 0.83 | 0.68 | 0.255 / 0.309 |

1. **Participation passes with real statistical weight.**
   - The economic channels alone reproduce two thirds of the regional pattern: the north-south gradient runs through unemployment, education and pay.
   - Predetermined community infrastructure lifts the correlation to above 0.8.
   - Even at epsilon 0.5 the model's spread is below the data's (0.26 against 0.31), which points to an elasticity at or above the top of the range, or a channel still missing.
2. **Agency by region is large and plausible:** 1.0 to 1.3 in the north against 0.73 to 0.86 in the south, carried by the pay premium net of education.
3. **Hardship by region is wrong-signed. This is a failure, reported as such.**
   - The model puts hardship highest in the low-unemployment north (Bolzano 0.66, Lombardy 0.56) and lowest in the south (about 0.19). Official poverty statistics show the reverse.
   - The cause is the precautionary channel, "safer jobs, thinner buffers", which dominates liquid wealth by place in the one-asset model. OECD asset poverty is on liquid wealth, so low job risk shows up as asset poverty.
   - Real differences in wealth across regions also reflect pay levels, housing and inheritance, which the model does not carry by place.
   - The places-together national hardship (0.32 against 0.20 for the national economy) is the same problem in aggregate.
   - **Consequences:**
     - hardship by place is not reported until this is fixed;
     - the two-asset model by place is the first candidate fix;
     - the HFCS by region is the test.
4. **France and Germany at TL2** run cleanly: national participation is preserved, with regional agency from 0.88 to 1.10 in Germany. There is no regional participation validation yet. The next data step is the OECD Regional Well-Being indicators (social support, life satisfaction) and the Freiwilligensurvey by Land.

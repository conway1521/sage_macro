# Execution plan: the preferences phase (YBLI, WELLBY, WISE, GDP-B, participation credit)

Written to be executed by a fresh session. Every task names its data, the file to create, and an acceptance test. The state of the world before this plan: engine v1.1 (literature parameters, exact distribution, homophily channel, seven country rows with Atlas-cited targets), S paper (13pp, compiles), S+A paper (12pp, compiles, three-policy section including the participation tax credit), QuantEcon lecture (builds, country switch), all on github.com/conway1521/sage_macro. The reviews behind these are REVIEW.md, SYNTHESIS.md, WEIGHTS_LANDSCAPE.md, CALIBRATION_PIPELINE.md, COUNTRIES.md, NARRATIVE.md.

The goal of this phase, in one sentence: replace the last thesis-era preference object (the single Lambda) with a data architecture in which the weights people place on the SAGE dimensions come from real human ratings (YBLI), real wellbeing regressions (WELLBY), the WISE programme's own indicators, and eventually direct elicitation (GDP-B style), with the participation credit as the policy showcase priced in those units.

---

## Phase 1: YBLI subjective weights, mapped to S, A, G, E (the thesis's own idea, done properly)

The point. The YBLI tool records how people themselves value the eleven BLI dimensions, by country, over years of tool usage. The thesis mapped the eleven dimensions into the SAGE letters once, by hand, for France 2017. The upgrade: obtain the user-ratings data, apply the same mapping for every country and every available wave, average over time, and give every country row its OWN citizen-derived weight vector (Lambda for S, and in principle relative weights for A and G too).

### Tasks

1.1 Obtain the YBLI user-ratings data. Sources in order of preference: (a) the OECD Data Explorer archive dataset DF_BLI (the index values) and the YBLI ratings exports the OECD has published in its methodology papers (the Boarini and colleagues working papers on user preferences report aggregated weights by country); (b) the OECD WISE Centre (oecd.org/wise) data request channel for the full ratings microdata, which the OECD has shared with researchers before; (c) fallback: digitise the published per-country weight tables in the OECD's "How's Life?" methodology annexes. Record which route worked in the doc.

1.2 Fix the dimension mapping, once, in a table in the repo. Proposed starting point (adjust against the thesis chapter before freezing): Community and social connections to S. Civic engagement, education, health, jobs security to A. Income, housing, jobs earnings to G. Environment to E. Life satisfaction is the OUTCOME, not a weight, and stays out of the mapping. Write the mapping as `data/ybli_sage_mapping.csv` with a justification line per dimension.

1.3 Script `scripts/ybli_weights.jl`: read the ratings, apply the mapping, produce per-country (Lambda_S, weight_A, weight_G, weight_E) normalised so G's weight is 1 (the model's Gamma normalisation). Produce both the latest-wave value and the historical average; report both.

1.4 Wire into the engine: extend the COUNTRIES rows with `Λ_ybli` (and optionally the A and G relative weights), keeping the current values as defaults until the data lands.

1.5 Test it. Re-run the policy table (S paper) and the three-policy comparison (S+A paper) under each country's own citizen-derived Lambda. The acceptance test: the decoupling SIGN survives everywhere (it should, it is preference-independent on the behavioural side); the magnitude of the wellbeing loss now varies across countries with their own valuations, which becomes a reportable cross-country result in itself ("the same policy hurts more where people care more about community, by their own stated weights").

### Honest caveat to carry

The YBLI sample is self-selected. The defence: we use the weights as RELATIVE magnitudes, we average over the full usage history per country (which the user is right to note has grown several-fold since 2017), and we triangulate against WELLBY (Phase 2). State this in one paragraph wherever the weights are used.

---

## Phase 2: WELLBY, done with real depth (the central phase)

The point. The WELLBY framework prices a unit of life satisfaction. If we can map the model's two dimensions into life-satisfaction units, every policy result in both papers can be expressed in WELLBYs and in money, which is the unit the policy audience (UK Treasury Green Book, the Layard-De Neve programme) already uses. This is also the statistically strong way to discipline Lambda.

### The architecture (decide first, then build)

The model's experienced wellbeing is U = Uc + Us with Us = Lambda B Q. The WELLBY bridge is a life-satisfaction equation

LS = a + b log(c) + d S_measure + controls,

where S_measure is a social-support or participation measure on a known scale. The bridge has three free objects: b (income gradient), d (social gradient), and the mapping from the model's Q (or participation rate) to the S_measure scale. The literature pins b and d; the mapping is ours and must be stated. Two candidate mappings, build both: (a) Q maps to the share who report having support (the binary OECD item), so d applies to a 0-1 variable; (b) participation rate maps to the WVS active-membership rate. Run everything under both and report the spread as honest uncertainty.

### Tasks

2.1 Collect the coefficient library. Build `data/wellby_coefficients.csv` with one row per published estimate: source, dataset, country, b (log income), d (social measure), the social measure's definition and scale, sample, year. Primary sources to harvest: Clark, Fleche, Layard, Powdthavee, Ward "The Origins of Happiness" (Princeton 2018, the coefficient tables are the canonical source); Layard and De Neve "Wellbeing: Science and Policy" (2023) chapter tables; Frijters and Krekel "A Handbook for Wellbeing Policy-Making" (OUP 2021) and their 2024 HSSC WELLBY paper; the UK Treasury Green Book wellbeing supplementary guidance (2021) for the WELLBY monetary value (central 13,000 pounds, range roughly 10,000 to 16,000, 2019 prices); De Neve and co-authors' World Happiness Report chapters for cross-country gradients. Aim for 15 to 30 rows.

2.2 Script `scripts/wellby_bridge.jl`: implement both mappings; functions `wellbys_per_capita(sol_baseline, sol_policy; b, d, mapping)` returning the per-person LS change and the population WELLBY change; a money conversion using the Green Book value. Include the coefficient library loader so every run states which row of the library it used.

2.3 Re-express the headline results. The S paper's policy table gains two columns: change in WELLBYs per person per year, and the monetised equivalent; report under the central coefficients and the min and max of the library. The S+A three-policy comparison gains the same columns, which will produce the headline number of the phase: the participation credit's WELLBY return per unit of fiscal cost versus the work subsidy's WELLBY cost per unit of consumption gain.

2.4 The Lambda cross-check. The library's d over b ratio, mapped through the model's marginal utilities at the calibrated baseline, gives an implied Lambda. Compute it; compare with YBLI (Phase 1) and the thesis value. Expectation from the literature scan: the WELLBY-implied Lambda is two to three times the YBLI one. Whatever it is, report the three values side by side; the spread IS the finding, and the honest treatment is to carry all three through the policy tables as scenario columns.

2.5 Tests. (a) Replication sanity: feeding the bridge the baseline economy must return zero WELLBY change. (b) Coefficient sweep: results monotone and sign-stable across the library's range. (c) The known external anchor: the literature's unemployment LS penalty (about 0.7 LS points) versus the model's implied LS loss from the policy-induced material drop for the low group, as an order-of-magnitude check that the bridge is not absurd.

### Deliverable

A `wellby.jl` module plus the coefficient library, WELLBY columns in both papers' tables, and a short methods subsection in each paper. This is also the heart of the WISE collaboration offer: their regression coefficients drop straight into the library.

---

## Phase 3: WISE, pulled and used

The point. WISE Horizons (Snower and Lima de Miranda's programme) publishes the WISE Database (beyond-gdp.world/wise-database): the claim is over a million data points, 244 metrics, 218 countries, organised by Wellbeing, Inclusion, Sustainability. Their Recoupling Dashboard publishes per-country solidarity and agency indices, the same letters as our model. We should be benchmarked against their numbers BEFORE we ever present to that audience.

### Tasks

3.1 Pull what is public. The database portal has data-availability and data-request channels; the Recoupling Dashboard (Global Solidarity Index, agency index, published with the Lima de Miranda and Snower papers and the Tagesspiegel visualisation) has per-country values for 2007 to 2017 and updates. Download whatever exports exist; where the portal is request-gated, file the request (this is also a soft first contact with the programme, which is strategically useful). Store under `data/wise/`.

3.2 Script `scripts/wise_benchmark.jl`: for the seven country rows, compare (a) our B gradient and alpha gradient orderings against their solidarity and agency index orderings; (b) our model's equilibrium Q ordering against their solidarity ordering; (c) our decoupling result's cross-country magnitudes (run the financed subsidy for all seven countries, which the engine already supports) against the decoupling patterns their dashboard documents. Report rank correlations. Acceptance: report whatever comes out; agreement is validation, disagreement is a finding to investigate, both are content.

3.3 Write the bridge paragraph for both papers: the model as the structural counterpart of the WISE dashboard, with the benchmark table as evidence, and the WISE Database cited as a harmonised source alongside OECD How's Life and WVS in the calibration pipeline.

---

## Phase 4: GDP-B, included two ways

The point. GDP-B (Brynjolfsson, Diewert, Eggers, Fox; Stanford Digital Economy Lab; NBER w25695) does two things for us: a methodology for eliciting shadow prices of non-marketed goods through incentive-compatible online choice experiments, and an accounting framework for adding non-market value to GDP.

### Tasks

4.1 The model's own GDP-B exercise (cheap, striking, do first). Define the model's GDP-B as consumption plus the shadow value of the social fabric, priced at the WELLBY-derived value of Q from Phase 2. Script `scripts/model_gdpb.jl`: compute GDP (consumption) and GDP-B for the baseline and for each of the three policies. The expected headline: under the work subsidy, GDP rises 5.5 percent while GDP-B falls or is roughly flat; under the participation credit, GDP is roughly flat while GDP-B rises strongly. One table, both papers can cite it, and it speaks the language of the beyond-GDP audience natively.

4.2 The elicitation design note (the primary-data future). Vault note plus a short repo appendix: an incentive-compatible online choice experiment for the shadow price of associative time, modelled on the Brynjolfsson-Collis valuations of free digital goods (what compensation would you need to give up your associative participation for a month; discrete-choice BDM-style elicitation; representative panel). This replaces both YBLI self-selection and WELLBY's regression identification with direct elicitation. Spec the sample size from the GDP-B papers' power discussions, the survey instrument outline, and what parameter it pins (Lambda directly, and omega via the warm-glow versus social-return split of stated motives). This is a fundable, collaborator-attracting design, and citing the 2026 GDP-B workshop signals timeliness.

---

## Phase 5: the participation credit, from showcase to centrepiece

Already in the S+A paper at matched fiscal cost. The deepening tasks, in priority order:

5.1 Real-rate mapping. Replace the abstract "boost" with the actual policy parameter: France's 66 percent deduction and Gift Aid's 25 percent basic-rate top-up map to a rebate on the opportunity cost of the time lump (alpha times z times qbar). Implement the rebate in the budget constraint directly (the engine's subsidy machinery is the template), rather than as a payoff multiplier; rerun. Acceptance: the qualitative asymmetry survives the cleaner implementation (expected: yes, slightly smaller magnitudes).

5.2 Take-up incidence. Credits like Gift Aid are claimed disproportionately by higher-income households (itemisation, salience). Add a take-up gradient (low group claims at half the rate, an assumption to sweep) and report how much of the participation boom survives and who gets it. This pre-empts the obvious referee objection and produces a distributional table that matches the paper's incidence theme.

5.3 WELLBY pricing (depends on Phase 2). The credit's WELLBY return per euro of fiscal cost against the work subsidy's WELLBY cost per euro of consumption gain: the single most quotable number this programme can produce for the WISE audience.

5.4 Country sweep. Run the credit for all seven countries (the engine supports it); report where the social-feedback amplification is strongest (prediction: where calibrated kappa is highest relative to taste dispersion). A one-figure cross-country result.

---

## Order of execution and dependencies

Phase 4.1 and Phase 5.1 are independent and cheap: start there for early wins. Phase 1 and Phase 2 are the data-heavy core and can run in parallel; Phase 2 matters more if time is short. Phase 3 should start with the data request early (latency is external). Phase 5.3 and the paper rewrites land last, after Phase 2's bridge exists. Suggested order: 4.1, 5.1, 2.1, 1.1, 3.1 (request), 2.2 to 2.5, 1.2 to 1.5, 5.2, 3.2 to 3.3, 5.3, 5.4, 4.2, then the paper updates and a REVIEW-style validation pass over everything new.

## Acceptance criteria for the whole phase

Every new number traceable to a named row of a data file in `data/`. Both papers compile with the new tables and no orphaned claims. The three Lambda values (YBLI, WELLBY, thesis) reported side by side wherever Lambda matters. The credit results stated with the take-up caveat. A validation script per phase, run and committed. Vault status.md updated; memory updated; everything pushed.

# Audit 4: the data and the place layer (E)

## Summary

1. The national country table is sound: every Eurostat and OECD value I re-queried matches, the JSON-stat decoding is correct, and the Kaplan-Violante-Weidner and HFCS figures match the published tables exactly.
2. One confirmed data error: the household footprint (`env_ac_ghgfp`, `nace_r2=TOTAL`) leaves out households' direct emissions (heating, car fuel). France 2021 is 296 Mt in the file against 410 Mt with them, so emissions per head and the carbon-tax rate are about 28% too low.
3. Three concept mismatches change results: the TL2 conversion factor loads regional non-employment into the wage of the employed (largest in Italy); the net-wealth target divides by gross income while model income is net; the place job-finding rates are normalised with population weights where unemployed weights are needed (Italy: 0.394 against the national 0.440).
4. `build_tl2.py` silently mixes years and has no missing-data check: Valle d'Aosta's lower-education unemployment rate is a 2021 figure (8.1%) beside a 2025 overall rate (3.8%). Affected regions are small.
5. National financing balances by construction, identical places reproduce the nation, and the population weights sum to one (14, 16, 21 regions). `arop_rate` is never an input. `formal_volunteering` is never read by `places_from_data`, but `estimate_epsilon.jl` fits epsilon on it.

Julia was not run. Statements about the Julia code are derived by reading it; numbers for the place mappings were recomputed in Python from the committed csv files.

## 1. Data association table

Values are FR / DE / IT. "OK" means the data concept matches the model object closely enough; "MISMATCH" items have a finding below.

| name in code | value | source, code | year | population | unit | model object | association |
|---|---|---|---|---|---|---|---|
| `share_high` | 0.341 / 0.276 / 0.176 | Eurostat `lfsa_pgaed`, ED5-8 over ED0-8 | 2015 | 25-64, both sexes | fraction | share of the tertiary cell | OK. Re-queried, matches. 2015 beside a 2023 labour market |
| `part_low`, `part_high` | 0.203/0.291, 0.252/0.349, 0.116/0.165 | `ilc_scp19`, AC41A | 2015 | 25-64, all activity statuses | percent to fraction | participation by education cell, employed and unemployed pooled | OK. Re-queried, matches. Data include the inactive; the model has none |
| `B_low`, `B_high` | 0.979/1.041, 0.994/1.015, 0.986/1.064 | `ilc_scp15` | 2015 | 25-64 | ratio, mean one | belonging taste by cell | OK (ratio only) |
| `alpha_low`, `alpha_high` | 0.860/1.271, 0.831/1.443, 0.902/1.459 | `earn_ses14_16`, `earn_ses14_04` | 2014 | employees, firms 10+, NACE B-S (no public administration), all ages | gross hourly earnings, ratio, population mean one | wage per unit of effort by cell | Acceptable. Gross hourly ratio used for a net-income model; normalised with 25-64 population shares, not employment |
| `u_low`, `u_high` | 0.077/0.045, 0.032/0.021, 0.079/0.036 | OECD EAG `DF_LSO_NEAC_UNEMP`, weights `DISTR_EA` × `LF` | 2023 | 25-64 | percent of labour force to fraction | stationary unemployment by cell | OK. Weights are labour force, correct |
| `ltu_share`, `f_find` | 0.245, 0.311, 0.560; f = 1 - ltu | OECD `DF_DUR_I`, `Y_GE1`, PT_POP_SUB | 2023 | 15+, both sexes | share of the unemployed | annual U to E probability | OK. Re-queried: 24.545 / 31.093 / 56.024, one row per country. f = 1 - ltu is the stationary share of the stock with duration of a year or more in an annual chain with P(U to E) = f (`unemployment_core.jl:34`) |
| `delta_low`, `delta_high` | 0.063/0.035, 0.022/0.015, 0.038/0.016 | u f / (1 - u) | derived | | annual probability | P(E to U) | OK. Matches u = delta/(delta + f) in `unemployment_core.jl:41` |
| `rr` | 0.653 / 0.456 / 0.374 | OECD TaxBEN NRR, single, no children, AW100, social assistance in, housing out | 2023 | one household type | net income out of work over net income in work | benefit = rr × alpha × z × e_ref, both cells | Formula OK (stock-weighted, recomputed exactly). One household type at 100% of the average wage serves both cells; Italy's zero after month 24 UNVERIFIED |
| `ratio` | 0.561 / 0.546 / 0.937 | INSEE Première 1327 (SRCV 2008); Freiwilligensurvey 2014; ISTAT 2023 | 2008 / 2014 / 2023 | 16+ / 14+ / 15+ | unemployed over employed volunteering rate | rule for unemployed participation | Arithmetic reproduced. Definitions differ by country: Italy is a four-week reference period. ESS (`ess_volunteering_ratio.csv`, not read by any model code) gives 0.80-0.85 / 0.60-0.92 / 0.65, each with a standard error of 0.12 to 0.19 |
| `work_share` = `effort_target` = `e_ref` | 0.643 / 0.609 / 0.725 | HETUS `tus_00selfstat` AC1A/(AC1A+AC3+AC41+AC42), FT and PT combined with `lfsa_eppga` | wave 2010 (DE fieldwork 2012-13, IT 2008-09) | employed, all diary days | share of committed time | mean effort of the employed; reference effort in the benefit | OK. FR full-time components re-queried (5:03, 2:24, 0:01, 0:02) |
| `htm_target` | 0.032 / 0.074 / 0.083 | Kaplan, Violante and Weidner (2014), Table 5, baseline, P-HtM | HFCS 2008-10 | households, head 22-79, biweekly pay period | fraction | `hand_to_mouth_kvw` | Number VERIFIED in the paper. 2008-10 beside 2021-23 targets; the pay-period definition against an annual model is for the model auditor |
| `whtm_target` | 0.173 / 0.248 / 0.155 | same table, W-HtM | 2008-10 | same | fraction | `wealthy_htm` (two assets) | Number VERIFIED |
| `nw_income_target` | 4.02 / 2.38 / 5.51 | HFCS 2021 tables, A1 median net wealth over I1 median gross household income | 2021 | households | ratio of medians | median net wealth over `median_income` | Numbers VERIFIED. MISMATCH: gross income in the data, net in the model (finding 3) |
| `illiquid_premium` | 0.0354 / 0.0216 / 0.0215 | JST R6, real housing total return less real bill rate, arithmetic mean | 1980-2015 | national | annual rate | Rk - R | Script logic correct. Values UNVERIFIED (dataset not in the repo) |
| `median_to_mean` | 0.857 / 0.880 / 0.886 | `ilc_di03` MED_EI / MEAN_EI | 2015 | all persons, equivalised net income | ratio | poverty line = 0.5 × ratio × model mean income | OK. Re-queried, matches |
| `rho`, `eta` | 0.92, 0.10 | Bayer and Juessen (2012) | | household hourly wages, West Germany | | income process, all countries | Declared assumption. Not checked against the paper |
| `dread` | 1.5 | Pagel (2017); Brown et al. (2024) | | | | news-utility weight | Not checked |
| `weekly_hours` (hard-coded, `place_layer.jl:143`) | 37.6 / 35.4 / 37.2 | `lfsa_ewhun2` | 2019 | employed 20-64 | hours | commuting share of work time | VERIFIED by query. Typed in code, not in a data file |
| TL2 `pop_share` | 14 / 16 / 21 regions | `demo_r_pjanaggr3` | 2025 | all ages | percent | place weights | OK. Sums 100.0003 / 100.0000 / 100.0004. All ages against a 25-64 model |
| TL2 `tertiary_share_25_64` | | `edat_lfse_04` | 2025 | 25-64 | percent | cell share by place, rescaled to `share_high` | OK (scale 0.765 / 0.785 / 0.789) |
| TL2 `unemployment_rate_20_64` (and low, high) | | `lfst_r_lfu3rt`; weights `lfst_r_lfp2acedu` | 2025, some 2021-24 | 20-64; weights 25-64 | percent | separation by place and cell, as odds relative to the national mean | Mixed years (finding 7). The age mismatch cannot be removed: I checked that `lfst_r_lfu3rt` has no 25-64 and `lfst_r_lfp2acedu` has no 20-64 |
| TL2 `ltu_share` | | `lfst_r_lfu2ltu`, PC_UNE | mean of the last two available years | 20-64 | percent of the unemployed | job finding by place, relative | MISMATCH in the weights of the national mean (finding 4) |
| TL2 `hh_income_per_head` | | `nama_10r_2hhinc`, B6N, EUR_HAB | 2023 (IT 2024) | all inhabitants, all income sources, after taxes and transfers | EUR | multiplier on alpha | MISMATCH (finding 2) |
| degurba `q_unemp_to_emp_25_54` | FR, IT only | `lfsi_long_e03` | 2015-18 | 25-54 | quarterly percent, integers | job finding by place, relative | MISMATCH: quarterly ratio applied to an annual probability (finding 5) |
| degurba `median_income_eur` | | `ilc_di17` | 2023 | 18-64, equivalised net | EUR | multiplier on alpha | Better than the TL2 measure; still net and includes the non-employed |
| degurba `commute_mean_minutes_*` | | `lfso_19plwk28`, MN_GE1 | 2019 | employed 20-64 who commute | minutes one way | time cost per unit of work | OK. 10 trips a week over weekly minutes |
| community, FR degurba | 1.259 / 1.991 / 3.133 per 1,000 | Data ES census, in service before 1990; INSEE density grid | stock today, population 2022 | | facilities per 1,000 | omega by place | OK. Normalisation in finding 9 |
| community, IT TL2 | 24.8 to 103.7 per 10,000 | ISTAT BES 05REL008 | 2011 | | | omega by place | OK. Column 9 of `italy_regions.csv` is `np_per10k_2011` |
| `footprint_intensity`, `t_co2e_per_head` | 0.233 / 0.282 / 0.282 kg per EUR; 4.36 / 5.79 / 4.94 t (2021) | `env_ac_ghgfp` P31_S14, `nace_r2=TOTAL`; `nama_10_co3_p3`; `demo_gind` | 2021 | resident households | | emissions = intensity × consumption; carbon-tax rate | MISMATCH: direct emissions excluded (finding 1) |
| `carbon_values.csv` | 350 EUR (UBA), 250 EUR (Quinet) and others | agency reports | price years 2016-2025 | | per tonne | valuation of an emissions change | Not verified online. Price-year mismatch (finding 11) |
| `arop_rate`, `formal_volunteering` | | `ilc_li41`; `ilc_scp20`; Freiwilligensurvey 2019; ISTAT AVQ | | | | validation | See finding 10 |

## Findings

### 1. The household footprint leaves out direct household emissions

- Location: `data/sustainability/footprint_intensity.py:32`; read at `SAGE_Bewley/scripts/sage_modular.jl:954`, `:966`, `:1044`.
- Severity: WRONG RESULTS. Confidence: CONFIRMED for France by API query; LIKELY the same for Germany and Italy (same query, not re-queried).
- The query uses `nace_r2=TOTAL`. In `env_ac_ghgfp` that code is the sum over products only. Households' direct emissions are a separate code, `HH`, and the full total is `TOTAL_HH`. France 2021, `P31_S14`, `c_orig=WORLD`: TOTAL 296,393 kt (the file's value), HH 113,132 kt, TOTAL_HH 409,525 kt.
- Size: France's footprint per head is 6.03 t, not 4.36 t, and the intensity is 0.322 kg per euro, not 0.233. The carbon-tax rate `eur_per_tonne × intensity / 1000` and every `emissions` figure are 28% too low. The docstring and `E_PLACE_CONCEPT.md` describe the object as the household footprint including heating and car use.
- Fix: `nace_r2=TOTAL_HH` and regenerate the csv.

### 2. The TL2 conversion factor loads non-employment into the wage of the employed

- Location: `SAGE_Bewley/scripts/place_layer.jl:182-188`; data `data/place/build_tl2.py:92`.
- Severity: WRONG RESULTS by place. Confidence: LIKELY (the arithmetic is confirmed; whether it is intended is a design call, since the notes label it a residual).
- `pred = ((1-t) alpha_l + t alpha_h) × (1 - u)` and `conv = income per inhabitant / pred`, which then multiplies `alpha` and so the wage of every employed household in the place. Income per inhabitant falls with inactivity; `1 - u` nets out only unemployment.
- Scenario: Campania against Bolzano. Income per head ratio 16,200 / 30,300 = 0.53. The `1 - u` ratio is 0.875, so the conv ratio is about 0.61 (file values: ITF3 near the bottom, ITH1 1.33). The employment rates 20-64 (Eurostat `lfst_r_lfe2emprt`, 2024, queried) are 49.4% and 79.9%, a ratio of 0.62. Netting employment out would leave a conv ratio near 0.86. About two thirds of the measured "conversion" gap is non-employment, not a lower return to work.
- The measure is also after national taxes, pensions and transfers, which the model then applies again, and per inhabitant of any age.
- Normalisation: the code sets the population-weighted mean of `conv × pred` equal to that of `pred` (verified: ratio 1.0000). The mean of `conv` itself is 0.998 / 0.999 / 0.994, not one as `E_PLACE_CONCEPT.md` states. Small.
- Fix: replace `(1 - u[i]/100)` by the regional employment rate 20-64, or use a per-worker measure (compensation of employees per employee, `nama_10r_2coe` over `nama_10r_3empers`).

### 3. Net wealth to income: gross income in the target, net income in the model

- Location: `data/manual_inputs.csv:34-36`; matched at `SAGE_Bewley/scripts/calibrate_two_asset.jl:82` (also `_s.jl:73`, `_e.jl:63`).
- Severity: WRONG RESULTS. Confidence: LIKELY.
- The target is median net wealth over median annual gross household income (HFCS Table I1, verified). The model moment divides by `r.median_income`, disposable income in a model with a net replacement rate and a poverty line on net income.
- Size: the target is too low by the gross-to-net factor at the median. I did not verify that factor from an official source; any plausible value (10% to 30%) exceeds the 5% tolerance `TOL.nw`. The HFCS gross-income concept also differs by country, which the ratio inherits.
- Fix: divide by a net median (EU-SILC median household disposable income, or HFCS net income where the country collects it) or state that the model's income is gross and change the benefit and poverty-line inputs to match.

### 4. Place job finding is normalised with population weights

- Location: `SAGE_Bewley/scripts/place_layer.jl:162` (and `:163`, `:170` for the unemployment means).
- Severity: WRONG RESULTS in the national aggregate with E on. Confidence: CONFIRMED (arithmetic from `place_tl2.csv`).
- `qn` is the population-weighted mean of `100 - ltu_p`. The national long-term share is the unemployed-weighted mean, and regions with high unemployment have high long-term shares. Population weights make the population mean of `f_p` equal the national `f`, while the mean over the unemployed, the one that reproduces the national long-term share, is lower.
- Size (TL2): mean job finding over the unemployed is 0.739 against 0.755 in France, 0.682 against 0.689 in Germany, 0.394 against 0.440 in Italy. Italy's economy with E on has an implied long-term share near 60.5% against the 56.0% target, and separations are scaled down with it.
- Fix: weights `w[i] * u[i]` in `qn`.
- Related, small: the national cell rates `ul_n`, `uh_n` use population weights where cell labour force weights (`w × share`) apply. The implied aggregate rates are within 0.2 points of the targets (Italy: lower cell 8.01% against 7.92%, higher cell 3.42% against 3.59%).

### 5. Degree of urbanisation: a quarterly ratio scales an annual probability

- Location: `SAGE_Bewley/scripts/place_layer.jl:159`, `:174`.
- Severity: WRONG RESULTS (degurba access channel, France and Italy). Confidence: CONFIRMED.
- `f_p = f × q_p / q_n` with `q` the quarterly U to E probability. `E_PLACE_CONCEPT.md` says the flows are "converted to annual rates as the national ones are"; the code does not convert.
- France: quarterly means 20.5 / 21.5 / 25.25 give `f` of 0.691 / 0.725 / 0.851. Annualised, `1 - (1 - q)^4` is 0.601 / 0.620 / 0.688 and gives 0.713 / 0.736 / 0.816. The rural minus cities gap is 0.160 in the code against 0.104, about 55% too large.
- Fix: annualise `q` before taking the ratio. Germany has no flow data by urbanisation and keeps national job finding, as the code intends.

### 6. The replacement rate does not follow place job finding

- Location: `place_base`, `SAGE_Bewley/scripts/place_layer.jl:27-38` (no `rr` field).
- Severity: WRONG RESULTS by place. Confidence: LIKELY (a consistency gap, not a coding slip).
- National `rr` is the benefit averaged over the stock of unemployed at the national long-term share. With access on, each place has its own long-term share but the national `rr`.
- Size, same formula and TaxBEN file: Italy 0.374 nationally, 0.47 to 0.50 at a long-term share of 35 to 40% (the North), 0.33 at 62% (the South). France 0.67 to 0.56 from the lowest region to the overseas regions. Germany 0.50 to 0.40.
- Fix: compute `rr_p` from the place's long-term share and pass it through `place_base`; national financing already handles it.

### 7. `build_tl2.py` mixes years and takes stale values without a flag

- Location: `data/place/build_tl2.py:69-77` (`emit`), `:99-114` (`latest_by`), `:132` (dead check).
- Severity: FRAGILE (wrong for the regions concerned, small weights). Confidence: CONFIRMED by API query.
- `latest_by` takes the latest year separately for each education level and stamps the row with the ED3_4 year. `emit(years=2)` takes the last two available years, not the last two calendar years.
- Cases: Valle d'Aosta (ITC2) lower-cell rate 8.13% is from 2021 (10.3 and 6.5), beside an overall rate of 3.8% in 2025 (7.2% in 2021); its lower-cell separation is about double what a 2025 figure would give. Molise (ITF2) higher-cell 6.9% is 2023, when the overall rate was 9.6% against 6.3% in 2025. Trento (ITH2) higher-cell is 2023, so the higher cell shows more unemployment than the lower. Bolzano (ITH1): ED0-2 from 2024 with ED3_4 from 2025; its long-term share is the single year 2021. Mecklenburg-Vorpommern (DE8): long-term share is 2022-23.
- Missing and filled silently by the national value or the overall odds ratio: long-term share for FRM, DE5, DEC, ITC2; lower-cell rate for FRM, DE5, DE8, DEC, DEE, DEG; higher-cell rate for those plus DE4, DEF, ITC2, ITH1. In Germany 7 of 16 regions have no higher-cell rate.
- `missing = [... if False]` is always empty, so the script never reports any of this. `by_geo_year` overwrites silently if a query returns more than one value per region and year (no case found today: all dimensions are filtered).
- Fix: require the same year across education levels and a maximum age (for instance two years), write the year actually used, and replace the dead line with a list of (indicator, region) pairs absent or stale.

### 8. With E on, `median_income` is the mean of place medians

- Location: `SAGE_Bewley/scripts/place_layer.jl:233-235`, `:269`; used at `SAGE_Bewley/scripts/calibrate_two_asset_e.jl:63` and `place_layer.jl:262` (`:model` poverty line only).
- Severity: FRAGILE. Confidence: LIKELY.
- The net-wealth numerator is the median of the pooled national distribution (`Ntot` summed over places); the denominator is the population-weighted mean of place medians. With conversion spreading alpha by 0.78 to 1.33 across Italian regions the two differ. I could not size it without running the model.
- Fix: carry the income distribution by place and take the pooled median, as is done for wealth.

### 9. The community normalisation does not preserve the national average

- Location: `SAGE_Bewley/scripts/place_layer.jl:203-204`.
- Severity: COSMETIC to FRAGILE. Confidence: CONFIRMED.
- `infra_nat` is the population-weighted arithmetic mean, so the weighted mean of `(infra_p / infra_nat)^epsilon` is below one for epsilon below one. Italy: 0.991 / 0.990 / 0.990 at epsilon 0.3 / 0.4 / 0.5. France by urbanisation at 0.4: 0.983. National omega falls by 1 to 2% when the channel is switched on, which lowers participation slightly for a reason unrelated to place.
- France also mixes population bases: weights from EU-SILC (36.6 / 29.8 / 33.6) and facilities per head on the INSEE grid (37.1 / 30.7 / 32.2).
- Fix: divide by the weighted mean of `infra_p^epsilon` (taken to the power 1/epsilon).

### 10. A validation indicator is used to fit epsilon

- Location: `SAGE_Bewley/scripts/estimate_epsilon.jl:24`.
- Severity: FRAGILE (a claim, not a number). Confidence: CONFIRMED.
- `places_from_data` never reads `formal_volunteering` or `arop_rate`. `arop_rate` appears only in `probe_hardship_by_place.jl:19` and `test_place_report.jl:29`, as comparisons. `formal_volunteering` is the fitting target of `estimate_epsilon.jl` on Italy's regions. If that estimate sets `epsilon`, Italian participation by region is in sample, and the statement that E fits nothing holds only for France and Germany.

### 11. Carbon values: price year and currency

- Location: `SAGE_Bewley/scripts/sage_modular.jl:983-995`.
- Severity: FRAGILE. Confidence: CONFIRMED by reading.
- The default `uba_central` is in 2025 euros for a tonne emitted in 2026, applied to 2021 consumption in 2021 euros, so `share` mixes price years. `epa_central` is in US dollars and is returned in the field `eur`.
- Fix: deflate to the footprint year and convert, or refuse keys whose currency is not EUR.

### 12. Inputs outside the manifest and swallowed failures

- Location: `data/make_manifest.py:17-42`; `data/place/collect_place_data.py:37-40`.
- Severity: FRAGILE. Confidence: CONFIRMED.
- `res_data_es_20260927.csv` (the sports census behind France's omega by place), the two ISTAT csv files and the two Eurostat Italy extracts read by `italy_regions.py` are not in `FILES`, so `fetch_data.sh` cannot restore them. `add()` catches every exception, prints a line and continues, so a failed query drops an indicator and the model falls back to national values.

## Checked and found correct

- JSON-stat decoding in all four `get` functions: row-major flat index over `id` and `size`, last dimension fastest; category index inverted correctly. Re-queried values land on the right labels. `footprint_intensity.get` relies on time being last and one country per call, which holds.
- `one()` raises unless exactly one value matches, so an unfiltered dimension cannot mislabel a national value. `eag()` has the same guard. `dur` has none but the flow returns one row per country (checked).
- Country table values re-queried and matching: `ilc_di03` 2015, `ilc_scp19` 2015, `lfsa_pgaed` 2015, HETUS components, OECD duration 2023. `rr` recomputed from the TaxBEN file: 0.653 / 0.456 / 0.374; one row per country and month, months 1 to 60 complete.
- `manual_inputs.csv`: KVW Table 5 baseline rows (P-HtM 0.138 US, 0.074 DE, 0.032 FR, 0.083 IT; W-HtM 0.202, 0.248, 0.173, 0.155) read in the Brookings PDF. HFCS 2021 tables, June 2026 edition: net wealth medians 106.7 / 125.7 / 151.0 (PDF p. 4) and gross income medians 44.8 / 31.3 / 27.4 (PDF p. 52) read in the ECB PDF. The four `ratio` derivations reproduce from the figures quoted in the csv.
- Separation by place: `delta_p / f_p = (delta / f) × odds(u_p) / odds(u_n)`, the stationary odds of the two-state chain.
- National financing: `lumptax_p = T_nat - ui_tax(p)` and `T_nat = lumptax + Σ w ui_tax(p)`, so every place pays `T_nat` in total and revenue equals the national lump sum plus national benefit spending. Benefits follow the place's alpha and cell shares in both the tax and the transfers.
- Identical places: with no channels every spec is empty, `place_base` returns the national config, the `1e-13` snap restores the national tax, and every aggregate is a weighted mean of identical numbers; the slope aggregate `1 - 1/Σ w/(1-s)` returns `s`.
- Population weights: 14 / 16 / 21 regions, sums 100.0003 / 100.0000 / 100.0004, renormalised in code. Composition: the weighted tertiary share equals `share_high` after scaling; the 0.95 cap does not bind.
- Csv readers that split on commas: `place_tl2.csv` (quoted source is field 6, after the value), `carbon_values.csv` (fields 1 to 6 precede the quoted ones), `manual_inputs.csv` (fields 1 to 3), `sports_facilities_fr.csv` (the matched label has no comma), `italy_regions.csv` and `footprint_intensity.csv` (no quoted fields), the country table (none). No misalignment today; a region name or label with a comma in an early column would shift fields.
- Italy's ISTAT codes map correctly to NUTS 2021 (ITD1-5 to ITH1-5, ITE1-4 to ITI1-4). French NUTS 2016 codes FRB to FRM and FRY are used throughout. No EL/GR or UK code is involved.
- Commuting: 10 one-way trips over weekly minutes; weekly hours match `lfsa_ewhun2` 2019. Carbon-tax units: EUR per tonne × kg per EUR / 1000 is dimensionless.
- `alpha_ratio_ses2022`, the ESS ratios, `community_infrastructure_fr.csv` and `associations_fr.csv` are read by no model code.

## Could not verify

- Illiquid premium (0.0354 / 0.0216 / 0.0215): the JST dataset is not in the repo. Script logic is correct.
- TaxBEN Italy: zero from month 25 with social assistance claimed, in a year when the Reddito di cittadinanza existed. The OECD API refused the query (403). If the true figure were 25%, Italy's `rr` would rise from 0.374 to about 0.45.
- INSEE Première 1327 (17%, 35%, 67%, 58%), Freiwilligensurvey 2014 (26.1, 46.7, 51.1), ISTAT 2023 (5.9, 6.3), the Freiwilligensurvey 2019 rates by Land, Bayer and Juessen (2012), Pagel (2017), and the carbon values: not checked against the sources.
- The gross-to-net factor at the median behind finding 3, and the size of finding 8: need an official net median and a model run.
- Germany's and Italy's direct household emissions (finding 1): same query as France, not re-queried.
- Anything that needs a solve: that identical places reproduce the nation numerically, and the grids are common across places (assumed by `rs[1].agrid`).

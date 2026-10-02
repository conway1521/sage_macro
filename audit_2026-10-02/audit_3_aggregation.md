# Audit 3: aggregation, indicators, welfare, propensities, transitions

## Summary

1. The pooling arithmetic is sound: every indicator in `_solve` is a ratio of sums, the discount-type weights, node weights and cell shares each enter once and sum to one, and no further sibling of the effort-per-employed bug exists among the headline fields. Two mild siblings remain (`A_cond` across cells, `time_propensities`).
2. Welfare has two confirmed errors. With the unemployed participation rule on (every country configuration), the value function still has the unemployed participating by choice, so V, Vb, Ve and every consumption equivalent are inconsistent with the reported participation. With S off, the belonging part Vb is computed at the default `social_strength = 1.0` instead of zero (visible in `test_reporting2_FR.txt`: belonging 0.0702 and a negative remainder in a G+A economy).
3. The carbon tax leaves income, wealth and both poverty thresholds nominal, so hardship under `ctax` is measured against an undeflated line. `transition` double-counts `levy_employed` in the tax path. `transition_s` returns unconverged paths without warning (the logged recession run stopped at 40 iterations, gap 5.8e-5 against a tolerance of 1e-7).
4. `country_config` falls back silently to engine defaults when a calibration file is missing, and the file is chosen from the `config` string alone, independently of the `S`, `A`, `E` keywords. Twelve (country, config, illiquid) combinations currently have no file.
5. The reduction suite is weaker than it reads: rows 6 to 10 compare a configuration with itself (identical parameters or identical `SAGEConfig`, served from cache), `reduce_to` lets NaN pass, and welfare, propensities, consumption, `ctax`, `psi`, `time_bonus`, `commute`, `impatient_share` and E with the illiquid asset are not covered.

Nothing was run. Everything below is from reading the code, the data headers and three logged outputs (`test_reporting2_FR.txt`, `test_carbon2_FR.txt`, `test_transition_s_FR.txt`). Magnitudes are back-of-envelope unless a log is cited.

## 1. Indicator table

Notation: `share_g` cell share, `mass`, `part` etc. the per-state sums in `pooled[g]` (each cell has total mass one), `emp` the employed mask (`transfer .<= 0`), lambda the stationary mass. "All" means all households. Location: `SAGE_Bewley/scripts/sage_modular.jl:580-709` unless stated.

| field | definition in words | numerator | denominator | correct? |
|---|---|---|---|---|
| `rate` | participation, all households | S on: the fixed point r of the map; S off: sum_g share_g x pooled rate | 1 (all) | Yes. S on: `rate` is the interpolated crossing, so it differs from sum_g share_g x pooled[g].rate by about 3e-7 (log: 0.23308318 against 0.23308350) |
| `rate_E` | participation of the employed | sum_g share_g sum part[emp] | sum_g share_g sum mass[emp] | Yes |
| `rate_U` | participation of the unemployed | sum_g share_g sum part[!emp] | sum_g share_g sum mass[!emp], guarded | Yes |
| `unemployment` | unemployed share | sum_g share_g sum mass[!emp] | 1 | Yes (wrong if rr = 0 or levy_employed < 0, finding 9) |
| `A`, `A_cell` | alpha x (1 - expected consumption loss to unemployment next year) | cell: alpha_g x (1 - sum pmass / sum mass); nation: share-weighted | all, per cell | Yes |
| `shock_loss`, `shock_loss_income`, `A_institutions` | the expected loss itself (consumption, income) | sum pmass (pinc) | sum mass, per cell, then shares | Yes |
| `A_cond`, `A_cond_cell` | alpha x (1 - consumption drop on job loss), among the employed | cell: sum dmass[emp] / sum mass[emp] | cell: employed of the cell. Nation: weighted by share_g | Cell: yes. Nation: NO, cells should be weighted by their employed mass (finding 8). About 0.002 for France |
| `consumption_drop` | mean drop on job loss, the employed | sum_g share_g sum dmass[emp] | mE = sum_g share_g sum mass[emp] | Yes |
| `hardship`, `income_poor`, `asset_poor`, `both`, `vulnerable` | OECD categories | sum_g share_g x (jinc, asset cdf at abar, jboth) | all | Yes, with one inconsistency: `asset` is the interpolated cdf, `both` and `ypoor` use the step test `a < abar` (finding 12) |
| `asset_poor_by_quintile` | asset poverty within income quintile | cumulative `ypoor` on YGRID | cumulative `Y` on YGRID | Yes, conditional on all incomes lying in [0, 1.5] (finding 14) |
| `hand_to_mouth` (old) | share with wealth below 4 weeks of mean labour income | cdf of pooled wealth at (4/52) x minc | all | Yes. `minc` is labour income per head of ALL households, unemployed counted at zero; by definition, not a slip |
| `hand_to_mouth_kvw` | wealth at most one week of own labour and benefit income; poor hand-to-mouth with two assets | sum hmass | sum mass (all) | Yes |
| `wealthy_htm` | same test, with illiquid wealth | sum whmass | all | Yes |
| `mpc` | spending share of a one-month windfall | sum lambda x pc x (c(a + D/R) - c(a)) / D | all (households with D = 0 add zero to the numerator but stay in the denominator; none in practice) | Yes |
| `mpc_htm` | MPC of the (poor) hand-to-mouth | sum mpchmass | sum hmass | Yes |
| `mpc_wealthy` | MPC of the wealthy hand-to-mouth | sum mpcwmass | sum whmass | Yes |
| `mps`, `mpe` | saving and earnings response per unit of windfall | sum lambda x (da', dlab) / D | all | Yes |
| `mpp` | change in participation probability after the one-month windfall | sum lambda x dP1 | all | Yes as coded, but NOT per unit of income: it is per one month of own income, unlike `mpc`, `mps`, `mpe`. Under the participation rule it uses the unemployed's chosen P1 |
| `room` | share with liquid wealth at least 3 months of own income | sum rmass | all | Yes |
| `dread_cost_E` | consumption-equivalent dread cost, employed | sum xmass[emp] | mE | Yes |
| `mean_income` | mean disposable income (labour, liquid capital income, transfers, net of lump-sum taxes) | sum_g share_g ymean | all | Yes. Nominal under `ctax` (finding 3); excludes the return on the illiquid asset |
| `median_income` | anchored: `median_to_mean` x mean; or the model median | as stated | all | Yes |
| `mean_labour_income` | alpha z e per head | sum lambda alpha z e | ALL households | By definition per head; excludes the subsidy and Z |
| `mean_effort_employed` | effort of the employed | sum_g share_g eff_E (employed states only) | sum_g share_g sum mass[emp] | Yes (the repaired field) |
| `consumption` | mean real consumption | sum cmass | all | Yes |
| `consumption_cell` | by education cell | sum cmass of cell g | sum mass of cell g | Yes |
| `consumption_status` | by employment status | sum_g share_g sum cmass[mask] | sum_g share_g sum mass[mask] | Yes; NaN for the unemployed when unemployment is off |
| `wealth_p50`, `wealth_p90` | quantiles of liquid wealth | cdf_quantile of sum_g share_g x pooled W | all | Yes |
| `welfare.V`, `Vc`, `Ve`, `Vb` | mean value and its parts | sum_g share_g sum vmass etc. | all (= 1) | Pooling yes. Content: NO under the participation rule (finding 1); `Vb` NO with S off (finding 2) |
| `welfare.cell[g]` | by education cell | sum of the cell | sum mass of the cell | Pooling yes; same content caveats |
| `welfare.status[k]` | by employment status today (V, Vc only) | masked sums | masked mass | Pooling yes; NaN for the unemployed without unemployment |
| `slope`, multiplier | slope of the aggregate participation map at the selected crossing | finite difference on the 401-point grid | n/a | Yes |
| E on: `rate_E`, `A_cond`, `consumption_drop`, `mean_effort_employed`, `dread_cost_E` | national, employed | sum_i wE_i x place value | wE_i = w_i (1 - u_i), normalised | Yes |
| E on: `rate_U`, status values | national, unemployed | sum_i wU_i x place value | wU_i = w_i u_i, normalised | Yes |
| E on: population fields (`E_POP`) | national | sum_i w_i x place value | population weights | Yes, except `hand_to_mouth` (each place uses its own threshold, finding 13) and `median_income` under `poverty_line = :model` (mean of medians) |
| E on: cell fields | national by cell | sum_i w_i share_ig x place cell value | sum_i w_i share_ig | Yes |

Fields absent from an E result (accessing them errors): `mpc_htm`, `mpc_wealthy`, `A_cell`, `A_cond_cell`, `both`, `vulnerable`, `hardship_cell`, `asset_poor_by_quintile`, `wealth_p90`, `employed`, `lumptax`, `welfare.cell[g].Ve/Vb`.

## 2. Findings

### 1. Welfare ignores the unemployed participation rule

- Location: `sage_modular.jl:366-372` (`impose_unemployed_ratio`), `reporting_core.jl:49-62, 82`, `transition_core.jl:211, 278-283`.
- Severity: WRONG RESULTS. Confidence: CONFIRMED BY DERIVATION (code path), magnitude estimated.
- What the code does: the rule rewrites `part` and `rate` only. `vmass`, `vcmass`, `vemass`, `vbmass`, `mppmass` come from `sol.V` and `sol.P1`, in which the unemployed choose participation freely. The exactness argument in the config comment covers savings and effort policies, and it is right for those, but the level of V is not covered: an unemployed household's flow utility contains `bel x d` and the time cost of QBAR at its chosen probability, in the current state and in every future unemployed spell of an employed household.
- Should do: evaluate the unemployed states' belonging and time terms at the rule's rate (`ratio x employed rate` at that node).
- Size: the unemployed join when u Lambda QBAR exceeds phi QBAR^3 / 3, about 0.002 at France's phi, that is at almost every taste node, so the value function has them near one while the rule reports about 0.56 x 0.24 = 0.13. With 6.5 percent unemployed and mean scale kappa B arg of about 2.6, the over-counted flow is roughly 0.065 x 0.0876 x 2.6 = 0.015 utils a year against u(c) of about -2.2: around 0.6 percent of consumption in the level of V. In comparisons, any policy that raises unemployment gains a spurious 0.1 percent of consumption per point of unemployment, the belonging part responds too strongly to the fabric (the unemployed carry roughly a tenth of Vb where the rule would give them about 2 percent), and `welfare_ce(...).unemployed` is dominated by belonging the rule says they do not receive. `transition_s` welfare has the same content.
- Smallest fix: the terms are linear, so add two policy evaluations to `welfare_parts`: the value of one unit of participation in the unemployed states for belonging and for the time cost (`F \ (bel x 1{s in U} x 1)` and the matching effort difference), plus the same with the chosen P1. At pooling replace the chosen contribution by `ratio x rE(node)` times the unit value, and subtract the unemployed states' option value from V. Until then, state in the paper that welfare is evaluated with free participation of the unemployed.

### 2. With S off the belonging part of welfare is not zero

- Location: `sage_modular.jl:565-569`.
- Severity: WRONG RESULTS (decomposition; total unaffected). Confidence: CONFIRMED (code and log).
- What the code does: `solve0` solves `update(job[2]; social_strength = 0.0)` but passes the unmodified `job[2]` to `cell_summary` and `agency_summary`. `SAGEParams.social_strength` defaults to 1.0 (`src/SAGEBewley.jl:125`), so `welfare_parts` computes `bel = 1.0 x Lambda x B x QBAR` and values the participation that logit noise produces.
- Evidence: `test_reporting2_FR.txt`, France G+A: "belonging 0.0702 + remainder -0.0146". The remainder is the logit option value, which cannot be negative; the true split is belonging 0 and remainder +0.0556.
- Consequences: `welfare.Vb` and `welfare_ce(...).parts.belonging` are spurious in G and G+A, and `choice_and_rest` is off by the opposite amount. The exact-reduction requirement fails on this field: G+S at kappa = 0 gives Vb = 0 (all node weight at u = 0) and G gives 0.07.
- Smallest fix: `p = update(job[2]; social_strength = 0.0)` and use `p` in all three calls.

### 3. Hardship under the consumption tax is nominal

- Location: `unemployment_core.jl:190-203` (income), `agency_shock.jl:73-76`, `sage_modular.jl:1043-1053`.
- Severity: WRONG RESULTS for hardship, income poverty and asset poverty in carbon-tax experiments. Confidence: LIKELY (depends on the intended concept; a real line is the only reading consistent with an anchored poverty line).
- What the code does: with `pc = 1 + ctax`, consumption and the MPC are deflated correctly, but disposable income `y`, wealth `a` and the inherited thresholds `(ypov, abar)` stay nominal. The rebate enters `y` through the negative lump-sum tax.
- Size: at EUR 100 a tonne France's rate is 2.33 percent. The rebate is about 0.023 x mean consumption, roughly 5 to 6 percent of the poverty line, while the line should rise by 2.33 percent in nominal terms, so the fall in income poverty attributed to the rebate is overstated by something like 40 percent, and asset poverty is understated because balances buy 2.33 percent less. `test_carbon2_FR.txt` reports hardship +0.0025 on this basis.
- Smallest fix: compare `y / p.pc` and `a / p.pc` with the thresholds in `cell_summary` and `two_asset_cell_summary` (or scale the thresholds by `pc` inside `carbon_tax_economy`), and report `mean_income` in real terms.

### 4. `transition` and `transition_s` net the levy on the employed into the insurance tax

- Location: `transition_core.jl:133-134` and `:240`.
- Severity: WRONG RESULTS when `levy_employed != 0`. Confidence: CONFIRMED BY DERIVATION.
- What the code does: `uicost(t)` sums `mu x transfer_at` over all states. With a levy, employed states carry `transfer = -levy` (`sage_modular.jl:298`), so the path tax is `lumptax + benefits - levy x employment`, whereas the steady state the path starts from and ends in uses `lumptax + ui_tax_of(c)`, benefits only. A zero shock therefore does not return the steady state: every household receives the levy revenue back along the path and loses it at T + 1.
- Size: the whole levy revenue, each period.
- Smallest fix: sum over the unemployed states only (`max(transfer, 0)` or the `z == 0` mask). The policy scripts use the levy (`policy_tests.jl:107`), not yet with transitions.

### 5. `country_config`: silent defaults when the calibration file is missing, and the file is chosen independently of the switches

- Location: `sage_modular.jl:829-864`.
- Severity: FRAGILE (wrong-association risk). Confidence: CONFIRMED.
- Behaviour, precisely:
  - File chosen: `calibration_country_<code>.txt` for `config == "GSA"` without the illiquid asset; `..._<code>_<config>.txt` for any other string; `..._<code>_<config>_I.txt` when the keyword `illiquid = true` is passed (for "GSA" too).
  - If the file does not exist: no error, no warning, nothing recorded in the result. The config keeps the country's labour-market table and the engine defaults phi = 14, beta_bar = 0.96, beta_spread = 0, kappa = 10, sigma_m = 0.4, chi0 = 0.05, illiquid_premium = 0. It never falls back to another configuration's file.
  - Missing today: `_GSA_I`, `_GS_I`, `_GSAE_I`, `_GSE_I` for FR, DE and IT, and `IT_GAE_I`. A typo in `config` ("GAS") behaves the same way. The United States fails loudly (alpha is "NA"), so it is safe.
  - `config` sets E (`occursin('E', config)`) but never S or A. `country_config("FR"; S = true)` loads the G+S+A calibration into a G+S economy, and `country_config("FR"; config = "GA")` returns a G economy with G+A's parameters unless `A = true` is also passed. `france_footing` and the suite rely on this (all four economies at the G+S+A calibration), which is fine for reductions but is not "each configuration fitted to its own targets".
  - An unknown key in a file errors (good). A trailing comment on a value line errors (good).
- Smallest fix: `isfile(cal) || error(...)` unless `allow_uncalibrated = true`, and derive S, A, E from `config` (or assert that the keywords agree with it).

### 6. `transition_s` returns unconverged paths without a warning

- Location: `transition_core.jl:248-267, 274`.
- Severity: FRAGILE. Confidence: CONFIRMED (log).
- `test_transition_s_FR.txt`: the recession run used all 40 iterations and stopped at gap 5.8e-5 against `tol = 1e-7`. The result carries `iterations` and `gap` but nothing flags it. When the loop exits on `maxit`, `rel` has been updated after `outs` was computed, so `participation` and `fabric` (from `rel`) and every other path and the welfare number (from `outs`) belong to different iterates. At this gap the mismatch is about 4e-5 in participation, small against the 1.5-point response, but the contraction factor is (1 - damp) + damp x slope, so an economy near its fold will not converge in 40 steps at all.
- Also: the zero-shock run needs 7 iterations because `r0.rate` is the interpolated crossing and the node sum gives 3e-7 more. The terminal value (rel = 1) is inconsistent with the path at that order. Harmless in size, but "exactly" in the header comment is not true.
- Smallest fix: compute `outs` once more at the final `rel`, and `@warn` (or error) when `gap >= tol`.

### 7. `time_propensities` mixes populations and ignores commuting

- Location: `sage_modular.jl:1065-1074`.
- Severity: WRONG RESULTS, small. Confidence: CONFIRMED BY DERIVATION.
- `work` is per employed household, `part` uses the change in `rate` over ALL households, and `leisure_employed = 1 - work - part` is labelled as the employed's. The employed's time identity is `d(time) = kappa de + QBAR dP1_E + d(leisure)`, so the participation term must use `rate_E`, and work must be multiplied by `1 + commute` (the unused `kappa = 1.0` on line 1069 looks like the start of that). Under the rule the unemployed rate is `ratio x rate_E`, so the error in `part` is a factor of about 1 - u(1 - ratio), 3 percent for France; with commuting on, leisure is overstated by `commute x work`.
- Smallest fix: `part = QBAR * (rP.rate_E - rB.rate_E) / h`, and scale `work` by the employed-weighted `1 + commute`.

### 8. National `A_cond` weights cells by population share, not by their employed

- Location: `sage_modular.jl:600-601, 622`.
- Severity: COSMETIC to minor. Confidence: CONFIRMED BY DERIVATION.
- `A_cond_cell[g]` is among the employed of cell g, and `consumption_drop` pools with employed weights, but `A_cond = sum_g share_g A_cond_cell[g]`. The employed weights are `share_g x mE_g / mE`. France: unemployment 7.7 and 4.5 percent by cell, so the low cell's weight should be 0.651, not 0.659, and with a 0.24 gap between the cells' values `A_cond` is understated by about 0.002. The place layer then aggregates this number with employed weights, so the two levels are inconsistent with each other.
- Smallest fix: weight by `cs[g].share * sum(pooled[g].mass[emp]) / mE`.

### 9. The employed mask is inferred from the sign of the transfer

- Location: `sage_modular.jl:355, 587`.
- Severity: FRAGILE. Confidence: CONFIRMED BY DERIVATION.
- `emp = transfer .<= 0`. With `rr = 0` every state counts as employed (unemployment 0, `rate_E`, `mean_effort_employed`, `A_cond` pooled over everyone: the old bug by another route). With `levy_employed < 0` (a payment to the employed) the employed states have a positive transfer and count as unemployed. `cell_summary` and `agency_summary` use `z > 0`, so numerators and denominators would then disagree. Neither value is refused.
- Smallest fix: build the mask from the process (`z_vals_override .> 0`).

### 10. `carbon_value(...).share` divides money of one year and currency by another

- Location: `sage_modular.jl:983-995`.
- Severity: FRAGILE. Confidence: CONFIRMED.
- `eur` and `share` use `v.value` as it stands: EUR 2025 for `uba_central` (the default key, a German value applied to any country), EUR 2018 for Quinet, USD 2020 for `epa_central`. `cB` is euros of the footprint year (2021). The currency and price year are returned but not applied, so `share` is off by cumulative inflation (around 15 to 20 percent for the default key) and is meaningless for the USD key.
- Smallest fix: refuse a key whose currency is not EUR, and either deflate to the footprint year or drop `share`.

### 11. `scan_technology` can fit an equilibrium that `solve_economy` does not select

- Location: `sage_modular.jl:762-779`; callers `calibrate_country.jl:331`, `calibrate_two_asset_s.jl:126`.
- Severity: FRAGILE. Confidence: SUSPECTED (needs a case with two stable crossings).
- With the default `selected_only = false` the loss is minimised over every stable crossing, while `_solve` keeps the highest. The calibration scripts call it with the default. If the best fit at some (kappa, sigma) is a lower crossing, the calibrated economy solves to a different rate. `max_mult` does not rule this out. `scan_technology_places` always takes the highest, so the E and non-E calibrations differ in this respect.
- Smallest fix: `selected_only = true` in the calibration calls.

### 12. `asset_poor` and `both` read the wealth distribution differently

- Location: `sage_modular.jl:689-691`; `unemployment_core.jl:198, 203`.
- Severity: COSMETIC. Confidence: CONFIRMED.
- `asset` is the linearly interpolated cdf at `abar`; `jboth` and `ypoor` count nodes with `a < abar`. So `union = inc + asset - both` and `vulnerable = asset - both` mix the two readings, and the quintile profile does not integrate to `asset_poor`. The gap is a fraction of the mass on one grid node near `abar`, below 0.1 point at na = 200.

### 13. E on: `hand_to_mouth` is a mean of place-specific thresholds

- Location: `place_layer.jl:233-235, 269`.
- Severity: COSMETIC. Confidence: CONFIRMED.
- Each place uses 4 weeks of its own mean labour income, and the national figure is the population mean of those shares, which is not the share of the national wealth distribution (`Wtot`, already built) below the national threshold. Exact only when places are identical. `median_income` under `poverty_line = :model` has the same form.

### 14. Smaller items

- `YGRID` ends at 1.5 (`agency_core.jl:67`; `unemployment_core.jl:195-199`). Income above it enters `ymean` but not `Y`, so `median_model` and the quintile profile are computed on the households below 1.5. Not binding for one asset at France's parameters by my estimate (top state about 0.9 plus 0.08 capital income); assumed, not checked, for `conv`-scaled places or `a_max = 8`.
- Node weights clamp tastes beyond `ugrid[end] = 30` (`sage_modular.jl:465-480`). At sigma_m near 1 and above (France 1.02 to 1.10, Italy G+S 1.46) about 0.2 percent of households sit above the cap and carry 3 to 7 percent of taste-weighted mass, so `Vb` and its response are truncated by roughly 1 to 4 percent. Participation is unaffected if the rate is saturated at u = 30. The grid was sized when sigma_m was 0.4. SUSPECTED size.
- `transition` and `transition_s` do not refuse `illiquid = true`; `egm_step` is one-asset. Dread vectors (`dread_q`, `dread_hi`, `dread_lo`) are not updated with the path's Pi and tax, which matters only for `dread_mode = :behaviour`.
- `welfare_ce` hard-codes `gamma = 2.0` as a keyword; `transition` reads `p.gamma`. Equal today.
- `scan_technology_places` defaults to `nq = 500` taste nodes, the solver to `c.nq = 2000`.

## 3. Answers to the specific questions

**Pooling (item 2).** `betas_of` weights sum to one in all three branches. `node_weights` adds exactly 1 per taste node and divides by `nq`. Types are mixed inside `build_family_ag` (S on) or `collapse_all(out[...], bw)` (S off), nodes by `collapse_all(fams[g], node_weights)`, cells by `share` in `_solve`: once each. `collapse_agency` carries all 18 fields `agency_summary` returns. All conditional means are ratios of pooled sums. `impatient_share > 0` silently overrides `beta_spread`.

**Thresholds and units (item 3).** The model period is a year throughout: poverty line 0.5 x median; asset threshold (months / 12) x 0.5 x median; KVW test `a <= y / 52` (half a fortnight's pay); room `a >= y / 4`; windfall `y / 12`; old hand-to-mouth 4 / 52 of mean labour income. No unit slip. Income concept for the line: labour income with subsidy, liquid capital income (R - 1)a, participation credit, benefits, less lump-sum taxes including the insurance tax and the employed levy, mixed over the participation choice. The anchor ratio is Eurostat mean and median equivalised net income, the same broad concept. Two caveats: nominal under `ctax` (finding 3), and with two assets the return on the illiquid asset is not in income, which is right if it is housing (imputed rent is not in the Eurostat concept) and wrong if it is financial. The own-income tests (KVW, room, MPC) use labour plus benefit income without capital income and gross of the lump-sum tax, as KVW do.

**welfare_ce (item 4).** V_B(omega) = (1 + omega)^(1 - gamma) Vc_B + Ve_B + Vb_B + rest_B = V_P gives omega = (1 + (V_P - V_B) / Vc_B)^(1 / (1 - gamma)) - 1, as coded. With gamma = 2, Vc < 0: a gain makes x < 1 and omega > 0; x <= 0 (a gain no scaling of consumption can deliver, utility being bounded above) returns NaN, which is right. It holds across discount types because every type's Vc scales by the same factor. The parts are each component's change alone and do not add to the total (exactly additive only to first order; with gamma = 2, 1 / (1 + x) - 1). By cell and by status each group uses its own Vc (in the E aggregation too). Meaning: a utilitarian comparison of two stationary cross-sections, the expected value of being dropped at random into one or the other. It includes the change in the wealth distribution as if it were free, so a policy that raises steady-state wealth looks better than living through its transition would; "by status" compares the employed of one economy with the employed of the other, who are different people with different wealth. It is not the welfare of any household alive at the reform.

**Propensities (item 5).** Budget pc c = R a + lab - T + tr + credit d - a'. A windfall D of cash on hand is assets higher by D / R: correct. pc dc + da' - dlab = D, so MPC + MPS - MPE = 1 holds exactly without a credit or money cost, and under linear interpolation and extrapolation because the identity is linear in the policies; the logs give 1.000000 with and without the tax. `interp_ext` is correct.

**Emissions and csv parsing (item 6).** `footprint_intensity.csv` has 7 unquoted numeric columns; column 5 is kg per euro, column 7 tonnes per head, as used. `carbon_values.csv`: columns 1 to 6 are read and contain no quoted commas (the quoted fields are columns 8 to 10), so `split(ln, ",")` is safe for what is used. Units: tax rate = EUR/t x kg/EUR / 1000, dimensionless; `cB` = t x 1000 / (kg/EUR) = EUR per head; revenue t x real consumption equals (pc - 1) c. The four revenue iterations converge at rate t (error about t^4).

**Transitions (item 7).** delta_scale[t] changes Pi from t to t + 1; unemployment at date 1 is the steady state's; the tax at t balances benefits paid at t (subject to finding 4); backward steps run T to 1 from the steady-state V and Va with each period's own Pi and tax; the distribution moves forward with the same Pi, so the mass by state matches the exogenous path. The terminal condition is exact for `transition` once the shock is over (no endogenous price), approximate for `transition_s` (the fabric depends on wealth). Welfare is sum lambda_ss x V_1 against sum lambda_ss x V_ss over the pre-shock distribution, each type discounting at its own beta, converted with the steady-state Vc: the permanent consumption change equivalent to living through the path. Correct, with finding 1's caveat. In `transition_s` the rule is imposed per (cell, type, node), which equals the steady state's pooled imposition because employment mass does not depend on the type, unless the cap at one binds.

## 4. Checked and found correct

- `mean_effort_employed`: numerator restricted to z > 0 states, denominator employed mass (`sage_modular.jl:613-614`; `unemployment_core.jl:194`).
- `ui_tax` ignores rho and eta but is exact: z is normalised to mean one and the Rouwenhorst stationary law is binomial for any rho.
- `agency_summary`: p uses Pi[s, u] and the same-latent-productivity pairing (u, u + nh); the drop on job loss is at the same assets; the dread equivalent solves Gamma u(c(1 - x)) = Gamma u(c) - D.
- Two-asset split: poor hand-to-mouth on k index 1, wealthy otherwise; `mpc_htm` and `mpc_wealthy` divide by their own masses.
- E aggregation: employed, unemployed, population and cell weights match each field's population; national financing gives every place the national total tax.
- `hardship_threshold`, `cdf_quantile`, `share_below_interp`, `asset_poverty_by_quantile` (boundary bin split).
- Crossing search: stable crossings only, highest selected, no double counting that matters.
- Family cache key hashes the full `repr` of the parameters, so thresholds, tax, `ctax`, `psi`, commute, time bonus and dread all enter.

## 5. Coverage gaps in the test suite (`test_modular.jl`)

Tested for real: A equalised (trivial by construction), S at kappa = 0 against the direct solve, cell order, the rule with S off, the refusals, the quarantine pin, dread off and overlay, inert illiquid asset for G and G+A, E with no channels for four configurations, three identical places.

- **Rows 7, 9 and 10 compare a config with itself.** `beta_spread = 0.0, nbeta = 5`, `pcost = 0.0` and the zero policy instruments are the defaults, so the `SAGEConfig` is identical to GSA's and `ECON_CACHE` returns the same object.
- **Rows 6 and 8 are vacuous too.** `cells_of` sets delta to 0.0 when unemployment is off, so "unemployment off" already runs the 2nz-state process with unreachable states; `unemployment = true, delta = (0, 0)` yields identical parameters and loads the same families from disk. The `delta === nothing` branch of `cell_params_u`, the different state space the comment there describes, is never reached from `sage_modular.jl`.
- **`reduce_to` passes NaN.** `abs(NaN - x) > worst` is false, so a field that is NaN on either side is skipped.
- **Fields never compared in the core rows:** welfare (V, Vc, Ve, Vb), `mpc`, `mps`, `mpe`, `mpp`, `consumption`, `rate_E`, `rate_U`, `unemployment`, `mean_income`, `hand_to_mouth_kvw`, `A_cond` (only in the illiquid and E rows). A check of Vb = 0 with S off would have caught finding 2; G+S at kappa = 0 against G on welfare fails today.
- **Row 13 excludes the one place the rule is not applied.** Welfare is identical with and without the rule, which is finding 1.
- **No reduction for:** `ctax = 0` through `carbon_tax_economy` in the suite (only in `test_carbon.jl`), homogeneity under `ctax` (real quantities unchanged when the tax is rebated in proportion), `psi` set explicitly, `time_bonus = 0`, `commute = (0, 0)` or commute against the equivalent rescaling of phi, `impatient_share -> 0` and `beta_low = beta_bar` against one type, `levy_employed = 0`, `search_time = 0`, `belong_u = 1`, `e_ref`/`phi` at France's values, E with the illiquid asset, the illiquid asset inert with S on, the transitions at zero shock (separate scripts, not in the suite, and none with a levy), `welfare_ce(r, r) = 0` and the adding-up identity (separate scripts, G+A only).
- **All default-footing rows run without unemployment,** where A, `shock_loss` and `consumption_drop` are trivially alpha and zero.

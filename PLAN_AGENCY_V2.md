# Plan: audited inputs, then agency in preferences (version 2, with version 1 as the fallback)

Written 2026-09-27. This plan replaces ad hoc checking with a fixed sequence of phases, each ending in a gate that must pass before the next phase uses compute. The state before it is in MODULAR.md (last two sections), and the reasons for it are the two limits found in the policy tests: the social multiplier is identified only through the carried-over education gradients, and agency barely responds to institutions and has no place in preferences.

## Decisions taken (2026-09-27)

1. **alpha is the return to one's own effort.** Its gradient comes from hourly pay by education (Eurostat SES), normalised so that its population mean is 1 in each country. The 0 to 1 band is dropped. Levels of pay across countries belong to productivity, not to agency.
2. **The headline agency measure is protection if the shock hits**, A_cond = alpha (1 - drop on job loss). The expected loss (A, the OECD labour-market insecurity concept) and the risk of job loss are reported beside it.
3. **Agency enters preferences (version 2).** Employed households bear a disutility from their exposure to job loss, so agency acts on choices. If version 2 fails a gate, the fallback is version 1: agency enters measured wellbeing only, with the same weight, and choices are unchanged.
4. **The German unemployed participation ratio becomes 0.546** (Freiwilligensurvey 2014), at the next recalibration.

## The design of the agency term (version 2)

**The object.** An employed household in latent productivity state z that chooses assets a' for next year faces a separation probability delta_g. If it loses its job, its resources fall from R a' + y_ref(z) to R a' + b(z), where y_ref(z) = alpha_g e_ref z Z is labour income at the reference effort and b(z) the benefit. Its exposure is

\[ X(a', z) = \delta_g \, \max\left(0,\; 1 - \frac{R a' + b(z)}{R a' + y_{ref}(z)}\right). \]

Savings reduce exposure, and so does a more generous benefit. Exposure depends only on the state and the chosen a', not on the household's own future policy, so the household problem stays a standard discrete dynamic programme with no inner fixed point.

**The preference.** The employed household values consumption as if it were c (1 - theta X(a', z)):

\[ u = \Gamma\left(\frac{[c(1-\theta X)]^{1-\gamma}}{1-\gamma} - \phi\frac{e^{1+\psi}}{1+\psi}\right) + \text{belonging} \cdot d. \]

theta X is then the share of consumption the household would give up to be rid of the insecurity, which is how the wellbeing literature reports it, so theta can be calibrated directly. theta = 0 gives back today's model exactly. The unemployed have no exposure term: their loss has already happened.

**Grounding.** Anticipatory utility, where people derive utility now from what they expect (Caplin and Leahy 2001). Job insecurity lowers life satisfaction among people who stay employed (Knabe and Ratzel 2011; Green 2011; the meta-analysis of Sverke, Hellgren and Naswall 2002). Institutions moderate that cost (Carr and Chung 2014). The exposure measure is close to the financial-resilience notion, being able to cope with a loss of income, which the OECD How's Life framework tracks. That link is to be checked in Phase 2.

**What it changes.** Households save partly for peace of mind, so the patience calibration moves. Insurance now reduces anxiety among the employed as well as the drop for the unemployed. Agency gets a utility component beside consumption, effort and belonging, which gives a four-part wellbeing decomposition.

**The A switch.** A on means education-specific alpha plus theta > 0. A off means common alpha (mean 1) and theta = 0. The four configurations (G, G+A, G+S, G+S+A) stay as they are.

## Phase 1: input audit (no compute beyond downloads)

**Tasks.**

1.1 **Inventory** every number that enters a solve: the country table (21 columns × 4 countries), SAGEParams defaults (gamma, psi, beta, R, Gamma, Lambda, the income process, grids, E_REF, phi's default, omega, QBAR, nz, na, ne), SAGEConfig defaults, calibration targets and tolerances, and constants hard-coded in scripts. For each: the value, every file and line that reads it, and the source.

1.2 **Classify** each as verified (checked against the primary source, table or page recorded), derived (formula checked), assumption (declared, with the reference that justifies it) or unverified.

1.3 **Rebuild the country table with a script**, `data/build_country_table.py`. It downloads each series from the Eurostat, OECD and TaxBEN APIs, applies the documented computations and writes `data/country_labour_participation.csv`. No hand-typed numbers. Where a value cannot be downloaded (Freiwilligensurvey, INSEE, ISTAT, BLS, KVW 2014 Table 5), it is entered once in `data/manual_inputs.csv` with its citation and page, and the script reads it from there.

1.4 **Adopt the decisions** in the table: alpha from SES 2022 hourly earnings (mean 1), B from EU-SILC 2015 ilc_scp15, and the German ratio 0.546. B also needs a mean decision. I propose keeping the current population mean, since B's level is absorbed by kappa.

1.5 **Single source of truth.** Check that no script reads an old value: calibration_ratio.txt (the INSEE footing), the archive folder, the old engine's COUNTRIES and COUNTRY_TARGETS tables, and constants duplicated across files. Anything obsolete is moved to the archive or deleted from the load path.

1.6 **Widen the sigma scan to 3.0**, since the multiplier range's lower end currently sits at the grid edge.

**Gate 1.** No input classed unverified. The table is regenerated from the script and differs from the committed CSV only where a decision or a correction says so, and every difference is listed. The inputs are tagged `inputs-v2`.

## Phase 2: the literature for theta (reading, no compute)

**Tasks.**

2.1 Collect peer-reviewed estimates of the life-satisfaction effect of perceived job insecurity or unemployment risk among the employed, and the income coefficient from the same studies. Candidates: Knabe and Ratzel 2011 (SOEP, Germany), Green 2011 (HILDA), Carr and Chung 2014 (European Social Survey, across countries), Sverke et al. 2002 (meta-analysis). Country-specific estimates are preferred where they exist.

2.2 Convert each to a consumption-equivalent share, with the ratio-of-coefficients method standard in the happiness literature (Clark, Frijters and Shields 2008). Record the mean share among the employed and, if available, the gradient by education.

2.3 Write the target in `data/manual_inputs.csv`: the mean consumption-equivalent cost of insecurity among the employed, per country if the evidence allows it, otherwise one value, with a range.

**Gate 2.** A documented target with a range from at least two independent peer-reviewed sources. If the estimates disagree by more than a factor of three, the range goes into the calibration as a sensitivity rather than a single number.

## Phase 3: implementation and tests (small compute)

**Tasks.**

3.1 Add `theta_A` to SAGEParams (default 0) and the exposure term to the reward of employed states in proto_participation_core.jl (the four reward constructions), unemployment_core.jl and the budget helpers in agency_shock.jl. This changes the solver digest, so every cache rebuilds, as expected.

3.2 Add `theta_A` to SAGEConfig and the calibration files. Report per economy:
- exposure (mean X among the employed);
- the agency utility component;
- the four-part wellbeing decomposition (consumption, effort, belonging, agency);
- A, A_cond and the job-loss risk.

3.3 **Tests.**
- theta = 0 reproduces today's economies to machine precision, for all four configurations, in the suite.
- theta > 0 raises saving among the employed and lowers exposure.
- Convergence rows at theta > 0 move agency and hand-to-mouth by less than the suite tolerance.
- The unemployed participation rule stays exact, because the term does not touch the unemployed budget.

3.4 **Prototype on France** at the audited inputs. Report how far theta at the Phase 2 target moves hand-to-mouth, effort and participation before recalibration.

**Gate 3.** Exact reduction, convergence, and no pathology: no mass at the top of the asset grid, and no loss of a stable participation equilibrium.

## Phase 4: recalibration (the main compute, laptop sessions with the user's say-so each time)

**Tasks.**

4.1 Extend calibrate_country.jl with theta: G targets (effort, poor hand-to-mouth), S targets (participation by education), and the A target (the consumption-equivalent cost of insecurity), in the fixed order phi, patience, theta, then the social technology. The order is repeated until all targets hold within tolerance.

4.2 Calibrate FR, DE and IT in all four configurations on `inputs-v2`. The United States stays uncalibrated (decision of 2026-09-24).

4.3 Report the multiplier ranges on the widened sigma scan.

**Gate 4.** Every configuration hits its own targets within tolerance, and the suite passes.

## Phase 5: results

5.1 Policy tests as in MODULAR.md 2026-09-27, plus the wellbeing decomposition by dimension, A_cond as the headline, and the insurance experiment reading both the drop and the anxiety channel.

5.2 Write-up in MODULAR.md, one section, and update the vault status.

## The fallback to version 1

Version 1 is taken if:
- **Gate 2 fails:** no credible target for theta.
- **Gate 3 fails:** the reduction is inexact, the term does not converge, or it produces pathological savings.
- **Gate 4 fails for the preference itself:** a country cannot hit its G targets with theta at its target.

Version 1 keeps theta = 0 in behaviour. It reports measured wellbeing as consumption, effort, belonging and lambda_A × A_cond, with lambda_A taken from the Phase 2 evidence. Phases 1, 4 (without theta) and 5 go ahead unchanged, so a fallback costs no extra compute.

## Parallel track, needing the user

The social multiplier needs a moment beyond national levels. The candidate is regional excess variance (Glaeser, Sacerdote and Scheinkman 1996), with the European Social Survey rounds 1 to 9 (item wrkorg, NUTS regions), ISTAT's regional series and the Freiwilligensurvey Länder. The ESS needs a free account, which the user has to create. It enters after Phase 4 as an added calibration moment.

## Estimated effort

| phase | work | compute |
|---|---|---|
| 1 audit | one to two sessions | downloads only |
| 2 literature | one session | none |
| 3 implementation | one to two sessions | under an hour |
| 4 recalibration | monitoring | about a day in laptop sessions |
| 5 results | one session | about an hour |

Deferred until after this plan: informal insurance (S feeding A), the E dimension, the HFCS targets (when access is granted), general equilibrium for the best fit.

## Progress (paused 2026-09-27, Phase 1 in progress)

Found so far in the audit, all to be fixed in Phase 1:

- **Education shares are 50/50 for every country.** SAGEConfig's default `share = (0.5, 0.5)` is never overridden by `country_config`. The actual tertiary shares (ages 25 to 64, 2015) are about 36 percent in France, 27 in Germany and 17 in Italy. This affects aggregate participation, the social feedback, the insurance tax and mean earnings. `alpha_off` is also a simple mean rather than a share-weighted one.
- **`median_to_mean = 0.8693` is France's** (ilc_di03) and applies to every country. It is to be made per country (ilc_di03, 2015).
- **The effort target mixes definitions.** The level is anchored to France's INSEE 0.53, which appears to cover all adults, while the ratios come from HETUS 2010 figures for the employed (FR 0.644, DE 0.610, IT 0.727). The target should be the HETUS share for the employed directly, with e_ref equal to it. The HETUS computation is replicated from raw `tus_00selfstat` (France: 0.673 full-time, 0.502 part-time, 17.6 percent part-time, giving 0.643).
- **alpha and B** as in MODULAR.md 2026-09-27 (gradients). alpha is to come from SES 2014 (`earn_ses14_16`, `earn_ses14_04`, matching the 2015 participation module), with SES 2022 as a check.
- **The German ratio** is 0.546.

Not yet inventoried: SAGEParams defaults in full (being checked: rho, eta, R, QBAR, omega, Lambda), test_modular preflight constants, policy_tests constants.

Helper for the build script: `data/eurostat_api.py` (Eurostat JSON API reader). The OECD EAG flows `DF_LSO_NEAC_UNEMP`, `DF_LSO_NEAC_DISTR_EA` and `DF_LSO_NEAC_LF` download with the key `FRA+DEU+ITA+USA................` (17 dimensions). There is no build script yet: `data/build_country_table.py` is the next task.

Background research, reports to be filed on return:

1. Literature for theta: the life-satisfaction cost of job insecurity among the employed.
2. Verification of the hand-entered inputs: the KVW Table 5 values, the participation ratios, BLS 2015 and ATUS.
3. Published annual earnings-process estimates for FR, DE and IT.

**Report 2 filed (hand-entered inputs):**

- **KVW poor hand-to-mouth, Table 5 baseline (p. 119):** 0.032, 0.074, 0.083 and 0.138, all verified. The US figure comes from SCF 2010 alone. Europe comes from HFCS 2008 to 2010, with income years 2009 (France, Germany) and 2010 (Italy).
- **France's ratio of 17/35 is association membership, not volunteering** (INSEE Première 1327, SRCV 2008). Within members, 67 percent of the unemployed volunteer against 58 percent of the employed, which implies a volunteering ratio of about 0.56. That is derived, not an INSEE figure. There is no newer official ratio by activity status.
- **Italy's 5.9/6.3 is verified**, but its reference window is 4 weeks (ISTAT 2023, time-use survey) against 12 months elsewhere.
- **The US 23.3/27.2 is verified** (BLS 2015, Table 1).
- **Germany's 26.1, 46.7, 51.1 and weights 37.1, 12.3 are verified** (Freiwilligensurvey 2014, BMFSFJ long version, Abb. 16-3 p. 441, Tab. 16-3 p. 436), giving a ratio of 0.546.
- **US volunteering by education, 25 and over (BLS 2015 Table 1):** 8.1, 15.6, 26.5 and 38.8.
- **ATUS 2025 Table 8B has no all-employed column.** It splits employed people by whether a child lives in the household, so the US work share needs re-deriving with population weights. The US is not calibrated, so this is low priority.
- **Decision for Phase 1:** France's ratio should use the volunteering-based 0.56, the same concept as the targets, with 0.486 kept as a sensitivity. Italy's window mismatch is to be documented.

**Report 1 filed (literature for theta).** The agent read working papers and accepted manuscripts. The published tables are still to be checked.

- **The fixed-effects SOEP and HILDA studies give implausible money values.** Knabe and Ratzel 2011, Clark, Knabe and Ratzel 2010, Geishecker 2012 and Green 2011 imply compensating incomes of 100 percent or more of income for any job worry. The literature attributes this to attenuated income coefficients (Clark, Frijters and Shields 2008).
- **Carr and Chung (2014, JESP, ESS 2010, 22 countries) is the only European estimate with a plausible share.** The 8 percent of employees who are severely insecure would pay about 15 to 19 percent of income, which averages about 1.4 percent over all employees. This conversion rests on the agent's assumption that the income variable is in deciles.
- **Recommended target:** theta × mean X of about 3 percent of consumption for the average employed adult, with a range of 1.5 to 6 percent. Country scaling as a sensitivity: Germany about 0.8, France 1, Italy 1.5 to 2.
- **Design implications:**
  - The cost is concave in the probability of job loss, and about 70 percent of the gradient is fear unrelated to the expected loss (Green 2011, Geishecker 2012), so a linear theta X overstates the cost at high exposure.
  - Long-term replacement rates moderate the cost: 10 points more removes about 44 percent of it (Carr and Chung 2014). This supports exposure net of benefits.
- **Gate 2 status: marginal.** Only one source gives a usable level, below the two the gate requires. **Decision on return:** either accept the 3 percent (1.5 to 6) as an order of magnitude, with the full range as a sensitivity, or fall back to version 1. A concave exposure, for example X to the power one half, or a fixed fear component should also be considered before implementation.

**Report 3 filed (earnings process).** Some sources were read in working-paper form, as flagged in the report.

- **The one harmonised estimate in the model's form** (AR(1) plus transitory plus fixed effect) is Bayer and Juessen (2012, Economics Letters). It gives rho about 0.92 in Germany, the US and the UK, with an innovation variance of about 0.010 in Germany against 0.025 in the US.
- **Other European estimates agree:** Floden and Linde (2001, RED) for Sweden net of unemployment (0.855, 0.023), and Cappellari (2004, JHR) for Italy (0.69 to 0.89, small permanent variance).
- **There is no published parametric AR(1) for France.** Bonhomme and Robin (2009) and the French administrative studies report moments only.
- **The evidence cannot separate FR, DE and IT reliably.**
- **Recommendation:**
  - one common European process, rho = 0.92 and eta = 0.10 (Bayer and Juessen 2012, cross-checked against Floden and Linde 2001 and Cappellari 2004);
  - France borrows the pooled value, which is to be stated;
  - the transitory component is treated as measurement error and dropped, as Floden and Linde do, with one robustness run at eta squared = 0.02;
  - sensitivity at rho 0.85 and 0.95, eta 0.08 and 0.14;
  - US reference: HSV (2010) rho = 0.973, eta squared about 0.014.
- **Decision for Phase 1:** rho moves from 0.90 to 0.92 and eta stays at 0.10. This is a small change, but the income process is now anchored to a named estimate rather than a range. Rouwenhorst is right for rho of 0.9 or more (Kopecky and Suen 2010).

# Assessment of the calibrated model (2026-09-29)

Step 3 of `PLAN_MASTER.md`: what each parameter is fitted to, where each configuration stands, what the model gets wrong on moments it was not fitted to, and what follows for the build order. Every number below comes from a committed log or probe output, on the EGM solver.

## 1. What each parameter is fitted to

| parameter | fitted to | configurations | source of the target |
|---|---|---|---|
| phi, effort disutility | effort of the employed | all | HETUS work share |
| discount spread (mean patience when the spread is zero) | poor hand-to-mouth | all | Kaplan, Violante and Weidner (2014), Table 5 |
| kappa, interaction strength | participation by education (G+S+A); overall participation (G+S) | S on | EU-SILC 2022 |
| sigma, dispersion of belonging taste | the participation gap between education cells | G+S+A; held at the G+S+A value in G+S | same |
| alpha, capability | not fitted: pay ratios by education | A on | SES 2018 |
| unemployed participation ratio | not fitted: imposed as a rule | S on | national surveys; ESS as a cross-check |
| rho, eta, rr, f, delta | not fitted: external | all | Bayer and Juessen (2012); OECD TaxBEN 2023; OECD 2023 |
| dread weight 1.5 | not fitted: overlay only | A on | Pagel (2017); Brown et al. (2024) |

**Target ownership (2026-09-28).** A configuration is fitted only to the targets its switches own. The education gap in participation belongs to S and A together, so G+S reports it as an untargeted moment. G+S cannot identify sigma without it, so sigma is held at the G+S+A value, and in the policy tests G+S inherits the G+S+A band for sigma. The unemployed ratio could not replace the gap. It is imposed rather than produced. With the rule off (`probe_gs_identification.jl`, France G+S), the unemployed participate 4.6 to 25 times as much as the employed across sigma from 0.3 to 1.7, against 0.561 in the data, because they have more free time. So the model's own ratio points the wrong way and cannot identify sigma.

**Stability gate.** No configuration counts as calibrated with a social multiplier above 5, that is, a map slope above 0.8. It binds nowhere in the committed calibrations.

## 2. Where each configuration stands

All twelve configurations are calibrated to their own targets, within 0.005 on effort and hand-to-mouth, and within the participation standard.

| | G | G+A | G+S | G+S+A |
|---|---|---|---|---|
| FR | yes | yes | yes, multiplier 1.8 | yes, multiplier 1.8 |
| DE | yes | yes | yes, multiplier 1.8 | yes, multiplier 1.8 |
| IT | yes | yes | yes, multiplier 1.3 | yes, multiplier 1.3 |

**Untargeted education gap in G+S** (model against data):

| | model | data | share owed to A |
|---|---|---|---|
| FR | 0.024 | 0.088 | about 73% |
| DE | 0.008 | 0.097 | about 92% |
| IT | 0.011 | 0.049 | about 78% |

Social feedback alone produces a quarter of the gradient at most. The capability gradient produces the rest.

## 3. Untargeted moments, G+S+A (`assessment_moments.jl`)

| moment | FR model | FR data | DE model | DE data | IT model | IT data |
|---|---|---|---|---|---|---|
| annual MPC, one-month windfall | 0.115 | 0.42 | 0.141 | 0.50 | 0.185 | 0.48 |
| MPC of the hand-to-mouth | 0.330 | | 0.285 | | 0.420 | |
| consumption drop on job loss | 0.134 | 0.09 (0.05 to 0.13) | 0.323 | 0.06 (0.04 to 0.09) | 0.422 | 0.08 (0.05 to 0.13) |
| top 10% wealth share | 0.227 | 0.499 | 0.248 | 0.555 | 0.235 | 0.495 |
| wealth Gini | 0.398 | 0.676 | 0.440 | 0.727 | 0.413 | 0.640 |
| median liquid assets / mean income | 2.22 | 0.25 | 2.01 | 0.30 | 1.86 | 0.24 |

Benchmark sources are in the validation table of `PLAN_MASTER.md`. The Italian wealth benchmarks were corrected on 2026-09-29 from the June 2026 edition of the HFCS tables. The wealth rows compare the model's single liquid asset with HFCS net wealth.

## 4. Reading

**Liquidity, MPC and wealth concentration: the one-asset limit.** The single asset holds all saving as if it were cash. The median household therefore holds about two years of income in liquid form, against a quarter of a year in the HFCS. Only the poor hand-to-mouth (3 to 8%) have high MPCs, so the mean MPC is a third of the data's. This is the failure Kaplan and Violante (2014) document for one-asset models. The missing group is the wealthy hand-to-mouth, who hold illiquid wealth and little cash. Wealth concentration is too low for the same reason, since housing and business wealth are absent. **Consequence:** the illiquid-asset switch, already next in the plan, is confirmed as the priority. Its targets are HFCS liquid and illiquid holdings, and the poor and wealthy hand-to-mouth separately.

**The consumption drop on job loss: missing insurance.** The drop is a buffer-stock effect (`probe_drop_profile.jl`). At a year of earnings in assets it is 3% in France, 9 to 11% in Germany and 24 to 27% in Italy. At zero assets it is 37%, 55% and 62 to 65%. There are two sources of the excess:

- **Germany:** the discount spread that produces 7% poor hand-to-mouth leaves the impatient types with almost no buffer. Four fifths of them hold under 0.31 years of earnings, and their mean drop is 0.38.
- **Italy:** unemployment is persistent (56% of spells last a year or more) and benefits fall to zero at long durations. In a single-earner household a job loss is therefore close to a permanent income loss, even for patient households.

Paying the higher first-year replacement rate instead of the spell average lowers the drop only a little (`probe_drop.jl`: DE 0.32 to 0.29, IT 0.42 to 0.37). The model lacks the insurance real households use: a second earner (Blundell, Pistaferri and Saporta-Eksten 2016), family transfers, unsecured credit, and a period shorter than a year. The data measure the first year after displacement, including quick re-employment, while an annual model unemploys for the whole year.

**Why it matters for A.** Protection if hit, the headline part of agency, is alpha times one minus this drop. It is credible for France. For Germany and Italy it currently overstates exposure, and a cross-country comparison of protection would partly reflect missing household insurance rather than welfare states.

**Participation: sound.** The calibrated economies sit at multipliers 1.3 to 1.8 with unique equilibria (France G+S+A: every policy and technology). A carries most of the education gradient.

## 5. What follows

1. **Illiquid asset (next build step, unchanged).** It fixes liquidity, the MPC and concentration, and brings the wealthy hand-to-mouth.
2. **Household insurance for the drop (a decision).** The options, in order of cost:
   - **Report protection only for France** until the drop is fixed. This is free.
   - **A borrowing limit** from unsecured credit data. This is cheap.
   - **A second earner.** This is larger: it changes the household problem, and it overlaps with the illiquid asset in the state space.
3. **Period length.** An annual period exaggerates the drop. A quarterly period is the standard fix but multiplies the solve time by about four. Keep it in view, not now.
4. **Policy and equilibrium counts** on the new calibrations (running).

## 6. Anatomy of the unemployed participation gap (2026-09-29, `probe_unemployed_gap.txt`)

The unemployed take part at about 0.56 of the employed rate (INSEE; ESS 0.80 to 0.85). With the imposed rule switched off, France's calibrated G+S+A gives 3.5: nearly every unemployed person takes part. Each measurable mechanism was then switched on alone, and then combined, with everything else held at the calibration.

| mechanism | unemployed / employed |
|---|---|
| none (rule off) | 3.48 |
| money cost of taking part, 1.6% to 12.5% of mean income | 3.77 to 2.88 |
| time committed out of work (home production, search), 0.05 to 0.30 of the time endowment | 3.48 to 2.91 |
| belonging out of work at 80% to 40% of its value | 3.48 to 3.44 |
| money cost 3.1% and committed time 0.19 together (the measured anchors) | 3.17 |

- **The anchors:**
  - money: recreational and sporting services are about 1% of household consumption, or 0.5% in Italy (Eurostat hbs_str_t211, 2020), so at most about 3% of a participant's income;
  - time: about 30% of lost market hours go to home production (Aguiar, Hurst and Karabarbounis 2013).
- **Result: no measurable economic cost comes close.** Money costs cut everyone's participation almost in proportion. Committed time leaves the unemployed with more free time than the employed at any plausible value. Even a belonging value cut to 40% barely moves them, because with time disutility convex in hours, a tenth of the day costs someone not working almost nothing.
- **Reading:** in a standard model, the gap cannot be rationalised by time or money. It points to what the wellbeing literature calls the non-pecuniary costs of unemployment: lost networks, identity and routine, stigma and mental health (Clark and Oswald 1994; Winkelmann and Winkelmann 1998). The model does not represent these.
- **Consequence:** the imposed ratio stays. It is reported as an empirical regularity the economics cannot generate, not as a patch that hides a mechanism. This is a finding in its own right.

# Sources for country_labour_participation.csv

Assembled 2026-09-15. Every number in the CSV comes from the source named here,
by the computation stated. Values marked CARRIED OVER were not re-verified in
this pass and are listed at the end as open items.

## Labour market (one source and one year for all four countries: 2023)

| column | source | computation |
|---|---|---|
| u_low, u_high | OECD Education at a Glance, Data Explorer `OECD.EDU.IMEP, DSD_EAG_LSO_EA@DF_LSO_NEAC_UNEMP`, 2023, ages 25-64, both sexes | u_high = tertiary (ISCED 5-8). u_low = below upper secondary (ISCED 0-2) and upper secondary or post-secondary non-tertiary (ISCED 3-4), weighted by population share (`DF_LSO_NEAC_DISTR_EA`) times labour-force participation rate (`DF_LSO_NEAC_LF`). The United States has no 2024 row, hence 2023 for all. Cross-check: the Eurostat 2024 equivalents (`lfsa_urgaed` weighted by `lfsa_agaed`) are within 0.15 points for FR, DE and IT |
| ltu_share | OECD Data Explorer `OECD.ELS.SAE, DSD_DUR@DF_DUR_I`, 2023, share of the unemployed out of work for 1 year or over, all ages, both sexes | as published |
| f_find | derived | 1 - ltu_share, the convention used for France at stage 6 |
| delta_low, delta_high | derived | u f / (1 - u), the stationary separation rate |
| rr | OECD Tax-Benefit Data Portal, `OECD.ELS.JAI, DSD_TAXBEN_NRR@DF_NRR`, 2023 | net replacement rate, single person without children, previously earning 100 percent of the average wage, no social assistance, no housing benefit; mean of months 1 to 12, because the model's benefit does not expire. France 68 in every month (the stage-6 value); Germany 59 flat; Italy declining from 63; the United States 34 for about five months then zero |

## Participation

| column | source | computation |
|---|---|---|
| part_low, part_high (FR, DE, IT) | Eurostat EU-SILC 2015 ad hoc module, `ilc_scp19`, formal voluntary activities (AC41A), ages 25-64, both sexes | high = tertiary (ED5-8); low = ED0-2 and ED3_4 weighted by 2015 population (`lfsa_pgaed`, ages 25-64) |
| part_low, part_high (US) | BLS, Volunteering in the United States 2015, Table 1 (volunteering for an organisation, September 2014 to September 2015), ages 25 and over | tertiary = bachelor's and higher plus associate degree; the published 'some college or associate degree' group is split by CPS 2015 population (cpsaat07: some college no degree 35,326 of 56,263 thousand) assuming an equal volunteering rate within the group. Age band 25+ against 25-64 in Europe |
| ratio | national official figures, NOT one concept (Eurostat publishes no volunteering by activity status in 2015 or 2022) | FR 17/35, INSEE Premiere 1327 (association membership, SRCV-SILC 2008). DE 26.1/45.5, Deutscher Freiwilligensurvey 2019 (freiwilliges Engagement, arbeitslos gemeldet against erwerbstaetig), figure taken from the BMFSFJ report as quoted, NOT yet checked in the document. IT 5.9/6.3, ISTAT, Volunteering in Italy 2023 (organised volunteering, jobseekers against employed), checked on the ISTAT press release page. US 23.3/27.2, BLS 2015 Table 1 (unemployed against employed), checked |

## Effort and benefit reference

| column | source | computation |
|---|---|---|
| work_share (FR, DE, IT) | Eurostat HETUS 2010 wave, `tus_00selfstat`, time spent, all days; France and Italy 2009-10, Germany 2012-13 | paid = main and second job and related travel (AC1A); unpaid = household and family care (AC3) plus organisational work (AC41) and informal help to other households (AC42); employed full-time and part-time combined with the part-time share of employment (`lfsa_eppga`, ages 15-64: FR 2010 17.6, DE 2013 26.7, IT 2010 14.8) |
| work_share (US) | BLS American Time Use Survey 2025, Table 8B, all employed persons 18+ | working and work-related / (that plus household activities, purchasing goods and services, caring for and helping household and nonhousehold members, organisational civic and religious activities). The BLS chart 'activity by employment status' gives lower caring time for full-time workers (0.46 against 1.22 hours); the table is used |
| effort_target | derived | 0.518873 (France's G+A employed effort at the calibrated footing, test_modular.txt) times work_share / work_share(FR). France is the fixed point of the procedure |
| e_ref | derived | 0.53 (France's benefit reference) times the same ratio |

## CARRIED OVER, not re-verified in this pass

- alpha_low, alpha_high, B_low, B_high: the old engine's `COUNTRIES` table (OECD How's Life by education, as documented in CALIBRATION_PIPELINE.md). Not re-derived.
- htm_target: the old engine's `COUNTRY_TARGETS` (Kaplan, Violante and Weidner 2014). Not re-checked against the paper's table.
- The German ratio needs checking in the Freiwilligensurvey 2019 report itself.
- The old table's work shares (DE 0.55, IT 0.55, US 0.60 against FR 0.53) are NOT used; HETUS puts Germany below France and Italy well above it.

## Status of each country (2026-09-24)

France and Germany are calibrated. The United States is NOT calibrated, by
decision: with a twelve-month replacement rate of 0.13 the model cannot reach the
US hand-to-mouth target (0.019 against 0.31). Its row is kept for a possible
sensitivity with the benefit defined over a typical spell. See MODULAR.md. Italy
is in progress.

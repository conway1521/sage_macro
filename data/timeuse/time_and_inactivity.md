# Time and inactivity: two measured inputs for France, Germany and Italy

Built 2 October 2026 from the Eurostat dissemination API, the ISTAT SDMX service and four documents read in full text. Every number below is in a csv in this folder with its source and a status. Status key: VERIFIED means the value was returned by the official API on the build date, or transcribed from the cited page of a document I read. DERIVED means arithmetic on verified values. UNVERIFIED means I could not confirm it. Nothing is typed from memory.

## Files

| File | Content |
|---|---|
| `estat.py` | shared helper for the Eurostat API (standard library) |
| `pull_time_use.py` | Task 1: writes `hetus_time_by_status.csv`, `silc_volunteering_prevalence.csv`, `qbar_from_data.csv` |
| `qbar_crosschecks.py` | Task 1: stylised-question checks, writes `qbar_crosschecks.csv` |
| `pull_inactivity.py` | Task 2: writes `inactive_share_tl2.csv`, `inactive_share_degurba.csv`, `inactive_composition.csv` |
| `pull_volunteering_by_status.py` | Task 2: writes `volunteering_by_status.csv` (and keeps `raw/istat_avq_131.csv` as a fallback, the ISTAT service is slow) |
| `build_accounting.py` | Task 2: the accounting identity filled two ways, writes `accounting_layer.csv` |

All csv files have the columns indicator, country, place, group, year, value, unit, source, status. Run order: `pull_time_use.py`, `qbar_crosschecks.py`, `pull_inactivity.py`, `pull_volunteering_by_status.py`, `build_accounting.py`.

---

# PART A. EVIDENCE

## 1. The time participation takes

### 1.1 The model's unit

`data/build_country_table.py` (lines 147 to 157) takes HETUS wave 2010 from `tus_00selfstat`, unit `TIME_SP` (mean time per day over all persons and all diary days, weekdays and weekends), sex total, for the full-time and the part-time employed. Committed time is AC1A (main and second job and related travel) + AC3 (household and family care) + AC41 (organisational work) + AC42 (informal help to other households). The work share is AC1A over that sum, computed for full-time and part-time separately and combined with the part-time share of employment (`lfsa_eppga`, ages 15 to 64, FR 2010, DE 2013, IT 2010). My script reproduces the repository's values exactly (FR 0.64323, DE 0.60867, IT 0.72522), so the denominator below is the model's.

| Wave 2010 | Committed time, full-time (min/day) | Committed time, part-time | Part-time share | Weighted committed time |
|---|---|---|---|---|
| FR | 303 + 144 + 1 + 2 = 450 | 218 + 211 + 1 + 4 = 434 | 0.176 | 447.2 |
| DE | 285 + 128 + 5 + 5 = 423 | 175 + 220 + 6 + 6 = 407 | 0.267 | 418.7 |
| IT | 373 + 111 + 1 + 3 = 488 | 234 + 226 + 2 + 6 = 468 | 0.148 | 485.0 |

QBAR = 0.10 therefore means 45, 42 and 49 minutes a day, every day of the year, or 5.2, 4.9 and 5.7 hours a week (272, 255 and 295 hours a year).

Two facts about the table that matter later. The Eurostat tables by labour status cover persons aged 20 to 74 (Eurostat metadata `tus_00_esms`, section 3.6). The "2010" wave was collected in 2009 to 2010 in France, 2012 to 2013 in Germany and 2008 to 2009 in Italy, and the "2000" wave in 1998 to 1999, 2001 to 2002 and 2002 to 2003 (same metadata, section 3.7).

### 1.2 What the diaries record (wave 2010)

Mean minutes per day are computed as participation rate times participation time, which is finer than the published whole minutes (the published value for a French full-time worker is "0:01"). Each cell reads: share doing the activity on a diary day, minutes on such a day, implied mean minutes per day over everyone.

| | AC41 organisational work | AC42 informal help | AC43 participatory activities |
|---|---|---|---|
| FR full-time | 1.5%, 85 min, 1.28 | 2.4%, 86 min, 2.06 | 3.5%, 99 min, 3.47 |
| FR part-time | 1.2%, 97 min, 1.16 | 3.5%, 106 min, 3.71 | 4.6%, 91 min, 4.19 |
| FR unemployed | 1.3%, 130 min, 1.69 | 5.4%, 120 min, 6.48 | 7.0%, 83 min, 5.81 |
| FR retired | 3.4%, 125 min, 4.25 | 6.9%, 115 min, 7.94 | 10.1%, 123 min, 12.42 |
| FR homemakers | 1.6%, 130 min, 2.08 | 5.8%, 71 min, 4.12 | 8.7%, 88 min, 7.66 |
| FR students | 1.1%, 33 min, 0.36 | 2.3%, 71 min, 1.63 | 2.4%, 131 min, 3.14 |
| FR all 20 to 74 | 1.8%, 105 min, 1.89 | 3.8%, 108 min, 4.10 | 5.5%, 107 min, 5.89 |
| DE full-time | 3.6%, 149 min, 5.36 | 6.0%, 85 min, 5.10 | 2.3%, 91 min, 2.09 |
| DE part-time | 3.9%, 143 min, 5.58 | 7.7%, 84 min, 6.47 | 5.6%, 71 min, 3.98 |
| DE unemployed | 3.8%, 212 min, 8.06 | 13.1%, 106 min, 13.89 | 2.9%, 60 min, 1.74 |
| DE retired | 7.1%, 170 min, 12.07 | 11.9%, 111 min, 13.21 | 6.8%, 71 min, 4.83 |
| DE homemakers | 7.2%, 148 min, 10.66 | 11.8%, 93 min, 10.97 | 6.1%, 73 min, 4.45 |
| DE students | 3.0%, 143 min, 4.29 | 5.2%, 106 min, 5.51 | 2.5%, 71 min, 1.78 |
| DE all 20 to 74 | 4.5%, 156 min, 7.02 | 8.2%, 95 min, 7.79 | 4.1%, 77 min, 3.16 |
| IT full-time | 0.7%, 161 min, 1.13 | 3.5%, 80 min, 2.80 | 4.9%, 64 min, 3.14 |
| IT part-time | 1.2%, 200 min, 2.40 | 6.7%, 84 min, 5.63 | 7.1%, 59 min, 4.19 |
| IT unemployed | 1.6%, 173 min, 2.77 | 5.4%, 119 min, 6.43 | 4.7%, 65 min, 3.06 |
| IT retired | 2.6%, 174 min, 4.52 | 14.1%, 125 min, 17.63 | 14.1%, 69 min, 9.73 |
| IT homemakers | 1.6%, 136 min, 2.18 | 10.6%, 121 min, 12.83 | 12.8%, 62 min, 7.94 |
| IT students | 1.2%, 223 min, 2.68 | 2.1%, 75 min, 1.58 | 3.8%, 61 min, 2.32 |
| IT all 20 to 74 | 1.3%, 162 min, 2.11 | 7.0%, 109 min, 7.63 | 8.1%, 65 min, 5.27 |

Wave 2000 is in `hetus_time_by_status.csv` with the same layout. Several of its cells are suppressed by Eurostat (under 25 observations), mostly for the unemployed, students and Italian part-time workers.

Two patterns stand out. Someone doing organisational work on a given day spends between about one and a half and nearly four hours on it in every country and status (French students, at 33 minutes, are the one exception). The differences across groups are therefore almost entirely in how often it happens. Retired people do it on two to four times as many days as full-time workers, and homemakers on about twice as many in Germany and Italy.

### 1.3 The twelve-month prevalence

EU-SILC 2015 ad hoc module, `ilc_scp19`, all education levels, both sexes, percent.

| | Formal volunteering AC41A | | | Informal volunteering AC42A | Active citizenship AC43A |
|---|---|---|---|---|---|
| | 16+ | 25 to 64 | 20 to 74 (derived) | 25 to 64 | 25 to 64 |
| FR | 23.0 | 23.6 | 24.3 | 24.1 | 27.9 |
| DE | 28.6 | 27.8 | 28.6 | 10.6 | 15.1 |
| IT | 12.0 | 12.6 | 12.8 | 12.1 | 7.2 |

The 25 to 64 rate is the one the model's participation targets are built from (same table, by education). The 20 to 74 rate matches the HETUS population and is my weighting of the 20 to 64 and 65 to 74 rates by population (`demo_pjangroup`, 2015).

### 1.4 Conversion: time per day per annual participant

Everyone who does organisational work on a diary day is, by definition, someone who did it within twelve months. Mean time per day over all persons therefore equals the twelve-month prevalence times the mean time per day of an annual participant, so the latter is the ratio of the two. I compute it for full-time and part-time workers separately, divide by their own committed time, and weight with the part-time share, exactly as `work_share` is built.

**France.** Full-time: 0.015 x 85 = 1.275 min/day. Divided by 0.236: 5.40 min/day per annual participant. Divided by 450: 0.0120. Part-time: 0.012 x 97 = 1.164, / 0.236 = 4.93, / 434 = 0.0114. Weighted: 0.824 x 0.0120 + 0.176 x 0.0114 = **0.0119**. That is 5.3 minutes a day, or 32 hours a year, on 23 days a year for a full-time worker.

**Germany.** Full-time: 0.036 x 149 = 5.364, / 0.278 = 19.29, / 423 = 0.0456. Part-time: 0.039 x 143 = 5.577, / 0.278 = 20.06, / 407 = 0.0493. Weighted: 0.733 x 0.0456 + 0.267 x 0.0493 = **0.0466**. That is 19.5 minutes a day, or 119 hours a year, on 47 days a year for a full-time worker.

**Italy.** Full-time: 0.007 x 161 = 1.127, / 0.126 = 8.94, / 488 = 0.0183. Part-time: 0.012 x 200 = 2.400, / 0.126 = 19.05, / 468 = 0.0407. Weighted: 0.852 x 0.0183 + 0.148 x 0.0407 = **0.0216**. That is 10.4 minutes a day, or 64 hours a year, on 20 days a year for a full-time worker.

### 1.5 The range, by what counts as participation

Share of the employed's committed time, per twelve-month formal volunteer (prevalence AC41A, ages 25 to 64, 2015). Definitions B and C keep the same participants and add their time on other activities, which makes them upper bounds: they attribute all participatory activity and all informal help in the population to the formal volunteers. To my knowledge AC43 in the HETUS activity list is meetings and religious practice, which I did not re-verify at source for this brief (UNVERIFIED).

| | A: AC41 only | B: AC41 + AC43 | C: AC41 + AC42 + AC43 | C over formal or informal volunteers |
|---|---|---|---|---|
| FR, wave 2010 | 0.012 | 0.046 | 0.068 | 0.034 |
| DE, wave 2010 | 0.047 | 0.069 | 0.116 | 0.084 |
| IT, wave 2010 | 0.022 | 0.076 | 0.129 | 0.065 |
| FR, wave 2000 | 0.008 | 0.048 | 0.103 | 0.051 |
| DE, wave 2000 | 0.058 | 0.086 | 0.147 | 0.106 |
| IT, wave 2000 | 0.017 | 0.076 | 0.154 | 0.078 |

The last column divides the widest numerator by the sum of the formal and informal prevalences (AC41A + AC42A), as if the two groups did not overlap. It is a lower bound for definition C, and it implies a participation rate about twice the one the model targets.

The same calculation with all persons aged 20 to 74 in the numerator and the 20 to 74 prevalence, still over the employed's committed time, gives for wave 2010: A 0.017 (FR), 0.059 (DE), 0.034 (IT), B 0.072, 0.085, 0.119, C 0.110, 0.150, 0.242. These are higher because the retired and homemakers give more days. They describe the population, and the model's households are the labour force.

By labour status (definition A, wave 2010, national prevalence because none exists by status): the unemployed give 7.2 (FR), 29.0 (DE) and 22.0 (IT) minutes a day per annual participant against 5.4, 19.3 and 8.9 for full-time workers. If the unemployed in fact volunteer less often than the employed over twelve months (section 2.4), their time per participant is higher still.

### 1.6 Checks from stylised survey questions

These are independent of the diaries and of EU-SILC. All are in `qbar_crosschecks.csv`.

| Source | What it says | In the model's unit |
|---|---|---|
| FR: Prouteau and Wolff (2004), Économie et Statistique 372, Tableau 1 (INSEE enquête Vie associative, October 2002, ages 15+) | 27.6% volunteered in twelve months. Mean 99.9 hours a year per volunteer (standard deviation 204.9). Regular volunteers (12.1% of the population) 175.9 hours, occasional (18.6%) 33.0 hours. Two thirds give at most one hour a week, 11% give six hours or more | 0.037 for all volunteers, 0.065 for regular, 0.012 for occasional |
| IT: ISTAT (2014), Attività gratuite a beneficio di altri, Anno 2013, Prospetti 2 and 3 (ages 14+, four weeks before the interview) | 9.1% of the employed did organised volunteering in four weeks, 15.1 hours each over the four weeks (all statuses: 7.9%, 18.6 hours) | 0.067 per volunteer active in the four weeks. About 0.048 per twelve-month participant (scaled by 9.1 / 12.6, two different surveys, indicative) |
| DE: Freiwilligensurvey 2019, Kurzbericht (BMFSFJ 2021), p. 31 | 60.0% of volunteers give up to two hours a week, 17.1% give six hours or more | Two hours a week is 0.041, so six volunteers in ten are at or below that. QBAR = 0.10 is 4.9 hours a week. A mean is not published in the pages I read. With assumed band means of 1, 4 and 8 hours it would be 0.059 (UNVERIFIED, an assumption) |

Stylised questions give more time than diaries (France 100 hours a year against 32 from the diary and the 2015 prevalence, Italy roughly double). This direction of difference is expected, since recall questions overstate regular activities and the diary's AC41 excludes travel and any volunteering the respondent described as sport, culture or a meeting. The truth for formal volunteering lies between the two columns.

### 1.7 Assumptions and flags

1. Years do not match. Diaries are 2008 to 2013 and the prevalence is 2015. No twelve-month prevalence comparable to EU-SILC 2015 exists for the diary years.
2. The employed are divided by the prevalence of everyone aged 25 to 64. If the employed volunteer more than the inactive of the same age (section 2.4 suggests about 10% more), QBAR for definition A falls by about that proportion.
3. Organisational work in the diary (AC41) and "formal voluntary activities" in EU-SILC are close but separately defined. The French AC41 time is very low next to a prevalence of 23.6%, which points to coding differences. I would not read the French 0.012 as a firm lower bound.
4. Main activity only. Travel to the activity sits in AC9 and is excluded, in the same way that commuting has its own code (AC913) outside AC1A.
5. Participation rates are published to one decimal, so a rate of 0.7% (Italian full-time workers) carries a rounding error of about 7%. Sampling error is not published. Cells under 25 observations are suppressed.
6. The denominator is the committed time of the average employed person. A participant's own committed time is larger by their extra AC41 time, which lowers the share by a few percent of itself.
7. AC43 is outside the model's committed-time denominator. Adding it would raise the denominator by under 1%.
8. Italy's part-time weight uses 2010 as in the repository, although the Italian diary was collected in 2008 to 2009 (the 2009 share is 14.1% against 14.8%).

## 2. People outside the labour force, by place

### 2.1 TL2 regions

Source: `lfst_r_lfsd2pwc` (EU Labour Force Survey, population in private households by labour status), persons outside the labour force over population, country of birth total. Latest year 2025, all 51 regions present, none missing. The ratios agree with the published participation rates (`lfst_r_lfp2actrt` for 15 to 74 and 15+, `lfst_r_lfp2actrc` for 20 to 64) to within 0.09 points in 432 comparisons. The csv also holds 2015, 2019 and 2024, ages 15 to 64, the population and inactive counts, and the employed and unemployed shares.

The three right-hand columns before the last give the composition of the inactive aged 15+ in the 2021 census (`cens_21a_r2`: students, retired persons and capital income recipients, other). The last column is the age-proxy participation rate of the inactive defined in section 2.6.

| Place | 20 to 64, 2025 | 15 to 74, 2025 | 15+, 2025 | 15+, 2015 | Students % | Retired % | Other % | p_I (A) |
|---|---|---|---|---|---|---|---|---|
| FR | 18.8 | 35.2 | 43.0 | 44.0 | 19 | 64 | 17 | 22.6 |
| FR1 | 16.4 | 30.8 | 37.0 | 38.7 | 26 | 54 | 20 | 22.5 |
| FRB | 17.4 | 34.9 | 43.9 | 46.4 | 16 | 71 | 14 | 22.4 |
| FRC | 19.7 | 37.5 | 46.2 | 45.7 | 15 | 71 | 14 | 22.5 |
| FRD | 18.5 | 36.4 | 44.7 | 44.8 | 16 | 69 | 15 | 22.6 |
| FRE | 21.3 | 36.6 | 43.6 | 45.9 | 19 | 60 | 21 | 22.8 |
| FRF | 20.2 | 36.7 | 44.5 | 44.1 | 18 | 65 | 18 | 22.7 |
| FRG | 17.3 | 34.5 | 42.4 | 42.0 | 18 | 70 | 12 | 22.8 |
| FRH | 17.5 | 37.0 | 44.6 | 44.1 | 17 | 70 | 12 | 22.9 |
| FRI | 17.1 | 35.5 | 44.7 | 45.3 | 15 | 71 | 14 | 22.6 |
| FRJ | 19.4 | 36.8 | 45.2 | 47.2 | 17 | 66 | 17 | 22.6 |
| FRK | 17.4 | 32.9 | 40.9 | 42.8 | 19 | 66 | 15 | 22.6 |
| FRL | 20.3 | 37.5 | 46.5 | 47.4 | 16 | 64 | 20 | 22.4 |
| FRM (low reliability) | 22.3 | 40.7 | 49.1 | 59.5 | 13 | 61 | 26 | 22.4 |
| FRY | 31.8 | 45.8 | 50.6 | 47.4 | 22 | 45 | 34 | 22.9 |
| DE | 15.7 | 29.7 | 38.3 | 39.8 | 12 | 66 | 21 | 29.9 |
| DE1 | 13.6 | 27.0 | 35.6 | 36.8 | 14 | 62 | 24 | 29.9 |
| DE2 | 13.1 | 26.5 | 35.3 | 36.9 | 14 | 70 | 16 | 30.0 |
| DE3 | 18.0 | 29.6 | 37.4 | 39.2 | 14 | 61 | 25 | 29.5 |
| DE4 | 15.3 | 33.2 | 42.4 | 40.1 | 10 | 75 | 15 | 30.2 |
| DE5 | 21.3 | 32.7 | 40.8 | 44.1 | 13 | 59 | 28 | 29.6 |
| DE6 | 17.0 | 27.9 | 35.2 | 37.5 | 16 | 62 | 22 | 29.5 |
| DE7 | 16.8 | 30.1 | 38.4 | 39.5 | 13 | 63 | 24 | 29.8 |
| DE8 | 16.8 | 35.4 | 44.5 | 42.2 | 9 | 76 | 14 | 30.3 |
| DE9 | 15.9 | 29.8 | 38.6 | 40.6 | 12 | 66 | 21 | 29.9 |
| DEA | 17.8 | 31.1 | 39.2 | 42.2 | 12 | 62 | 25 | 29.8 |
| DEB | 14.7 | 29.3 | 37.6 | 40.2 | 11 | 66 | 23 | 30.1 |
| DEC | 18.2 | 33.6 | 42.4 | 43.6 | 11 | 66 | 23 | 30.0 |
| DED | 13.6 | 31.0 | 41.6 | 41.3 | 11 | 75 | 14 | 30.1 |
| DEE | 16.9 | 35.1 | 44.9 | 41.7 | 9 | 75 | 16 | 30.2 |
| DEF | 16.0 | 29.6 | 38.8 | 41.4 | 12 | 71 | 17 | 29.9 |
| DEG | 15.5 | 33.3 | 43.2 | 41.5 | 10 | 75 | 15 | 30.2 |
| IT | 28.0 | 41.9 | 50.1 | 51.0 | 16 | 47 | 37 | 11.3 |
| ITC1 | 21.0 | 37.0 | 46.9 | 47.5 | 15 | 57 | 28 | 10.9 |
| ITC2 | 19.1 | 35.4 | 44.9 | 45.0 | 16 | 57 | 27 | 11.0 |
| ITC3 | 22.7 | 38.1 | 49.0 | 51.5 | 14 | 54 | 32 | 10.7 |
| ITC4 | 22.7 | 37.4 | 46.0 | 45.8 | 17 | 54 | 30 | 11.2 |
| ITH1 | 18.6 | 33.0 | 41.2 | 40.9 | 19 | 56 | 24 | 11.4 |
| ITH2 | 20.6 | 36.1 | 44.6 | 44.7 | 18 | 55 | 26 | 11.3 |
| ITH3 | 22.6 | 37.4 | 46.2 | 47.4 | 16 | 52 | 32 | 11.2 |
| ITH4 | 21.7 | 37.3 | 47.5 | 49.3 | 15 | 57 | 28 | 10.9 |
| ITH5 | 19.8 | 34.9 | 44.5 | 45.6 | 16 | 57 | 27 | 11.0 |
| ITI1 | 20.6 | 35.8 | 46.0 | 47.2 | 16 | 54 | 31 | 10.9 |
| ITI2 | 21.9 | 37.1 | 47.3 | 48.1 | 16 | 53 | 31 | 10.9 |
| ITI3 | 23.1 | 37.9 | 47.4 | 48.1 | 17 | 55 | 28 | 11.0 |
| ITI4 | 26.6 | 40.2 | 48.3 | 48.0 | 17 | 42 | 40 | 11.4 |
| ITF1 | 28.1 | 42.5 | 50.9 | 52.6 | 16 | 47 | 37 | 11.2 |
| ITF2 | 33.5 | 47.3 | 55.3 | 56.6 | 16 | 47 | 38 | 11.3 |
| ITF3 | 41.0 | 51.9 | 57.4 | 60.3 | 17 | 32 | 52 | 11.9 |
| ITF4 | 38.7 | 50.7 | 57.6 | 58.4 | 15 | 39 | 46 | 11.5 |
| ITF5 | 34.7 | 47.8 | 55.2 | 56.3 | 17 | 42 | 42 | 11.4 |
| ITF6 | 44.0 | 55.0 | 61.0 | 60.6 | 16 | 38 | 47 | 11.7 |
| ITG1 | 41.4 | 53.0 | 59.1 | 60.3 | 15 | 34 | 51 | 11.7 |
| ITG2 | 31.3 | 45.0 | 53.1 | 53.1 | 15 | 44 | 41 | 11.2 |

Flags. All French 2025 values carry the Eurostat flag d (definition differs) and 2024 carries a break in series. Corsica (FRM) is flagged low reliability in every year, and its 2015 value of 59.5 should not be used. The census classification is by current activity status in the census, which differs from the LFS: I use the census only for the mix of the inactive, never for the share.

### 2.2 Degree of urbanisation

Source: `lfsa_pgauws`, persons outside the labour force over population, percent.

| | | 20 to 64 | 15 to 74 | 15+ | Formal volunteering, EU-SILC (`ilc_scp20`, 16+) |
|---|---|---|---|---|---|
| FR 2025 | Cities | 18.5 | 33.6 | 40.9 | 14.2 (2022) |
| | Towns and suburbs | 20.8 | 37.7 | 45.9 | 15.2 (2022) |
| | Rural areas | 17.8 | 35.7 | 43.9 | 17.6 (2022) |
| FR 2015 | Cities | 23.3 | 37.0 | 43.0 | 20.3 |
| | Towns and suburbs | 24.9 | 40.0 | 46.6 | 21.4 |
| | Rural areas | 20.4 | 36.5 | 43.3 | 27.7 |
| DE 2025 | Cities | 17.6 | 29.6 | 37.6 | not published for 2022 |
| | Towns and suburbs | 15.1 | 30.0 | 39.2 | |
| | Rural areas | 13.0 | 29.1 | 37.8 | |
| DE 2015 | Cities | 20.2 | 32.6 | 40.1 | 23.5 |
| | Towns and suburbs | 17.7 | 32.0 | 40.4 | 29.6 |
| | Rural areas | 16.0 | 29.8 | 38.4 | 34.5 |
| IT 2025 | Cities | 27.3 | 40.8 | 49.3 | 5.5 (2022) |
| | Towns and suburbs | 28.6 | 42.5 | 50.3 | 5.1 (2022) |
| | Rural areas | 28.1 | 42.5 | 51.0 | 5.5 (2022) |
| IT 2015 | Cities | 30.3 | 43.3 | 50.5 | 11.4 |
| | Towns and suburbs | 31.8 | 44.6 | 51.1 | 12.3 |
| | Rural areas | 32.4 | 44.5 | 51.6 | 12.2 |

The inactive share differs by at most five points across place types within a country. The volunteering rate differs by up to eleven points (Germany). Inactivity cannot be what separates cities from rural areas.

### 2.3 Who the inactive are, nationally

EU-SILC 2015, most frequent activity status, ages 18+ (`ilc_lvhl02`), the same survey as the volunteering module. Percent of the population.

| | Employed | Unemployed | Retired | Other inactive |
|---|---|---|---|---|
| FR | 52.7 | 5.9 | 28.3 | 12.6 |
| DE | 55.2 | 4.5 | 26.4 | 13.8 |
| IT | 44.7 | 9.0 | 20.8 | 25.3 |

Italy's inactive are a different population from the French and German ones: fewer pensioners and twice as many others (homemakers above all). In Campania, Sicily and Calabria "other" is about half of the inactive aged 15+ (table in 2.1).

### 2.4 The volunteering of the inactive against the employed and the unemployed

**EU-SILC 2015: no table by activity status exists.** The published module tables (`ilc_scp19` to `ilc_scp22`) break down by sex, age, education, income quintile, household type and degree of urbanisation only. The microdata would be needed. The closest evidence is the following.

(a) EU-SILC 2015 by age, the same survey as the model's targets (`ilc_scp19`, formal volunteering, percent).

| | 16 to 24 | 25 to 64 | 65 to 74 | 65+ | 75+ |
|---|---|---|---|---|---|
| FR | 21.8 | 23.6 | 27.7 | 22.5 | 17.1 |
| DE | 28.0 | 27.8 | 33.6 | 31.2 | 28.9 |
| IT | 16.4 | 12.6 | 12.1 | 8.9 | 6.1 |

(b) Italy, ISTAT Aspetti della vita quotidiana (SDMX dataflow `83_63_DF_DCCV_AVQ_PERSONE_131`), unpaid work in voluntary associations in the last twelve months, ages 15+, percent. This is the same survey and concept as the regional series already in `data/place/volunteering_by_region.csv`.

| | Employed | Unemployed, worked before | Seeking first job | Homemakers | Students | Retired | Other | Total |
|---|---|---|---|---|---|---|---|---|
| 2015 | 11.9 | 10.3 | 8.7 | 7.2 | 15.4 | 9.6 | 7.1 | 10.7 |
| 2025 | 10.5 | 7.8 | 4.7 | 5.4 | 11.0 | 9.5 | 5.9 | 9.3 |

Aggregated with the survey's own counts: labour force 11.5%, inactive 9.7% in 2015, a ratio of 0.85. In 2025 the ratio is again 0.85 (10.0% and 8.4%). The 2015 total of 10.7% sits close to the EU-SILC 2015 value of 12.0%.

(c) Germany, Freiwilligensurvey 2019 (Simonson, Kelle, Kausmann and Tesch-Römer, eds, 2021, Abbildung 4-5, p. 75), ages 14+, volunteering in the last twelve months, percent: total 39.7, full-time employed 43.5, part-time or marginal 50.8, unemployed 19.0, retired 31.7, in education 46.3, not employed for other reasons 34.3. The level is far above EU-SILC (28.6) because the survey's concept of engagement is wider. Only the ratios are usable: retired 0.73, other reasons 0.79, in education 1.06, unemployed 0.44, all relative to full-time employed.

(d) Italy, ISTAT 2013 module (Prospetto 2), organised volunteering in the four weeks before the interview, ages 14+, percent: employed 9.1, seeking work 6.2, homemakers 5.4, students 9.5, retired 7.9, other 5.0, total 7.9.

(e) France: no official table of volunteering by activity status found (UNVERIFIED, NOT FOUND). The nearest is association membership in SRCV 2008 (Luczak and Nabli 2010, Insee Première 1327, ages 16+): employed 35%, retired 34%, unemployed 17%, homemakers 23%. Among members, 58% of the employed and 67% of the unemployed volunteer, which gives volunteering rates of about 20% and 11%. The publication gives no such share for the retired, students or homemakers, only that it is lower.

(f) Diaries (section 1.2): the retired do organisational work on 2.3 (FR), 2.0 (DE) and 3.7 (IT) times as many days as full-time workers. This mixes how many take part with how often. Set against (a) to (d), it says the retired are somewhat fewer among participants and much more frequent once they are in.

Comparability. The two EU-SILC modules differ in level: formal volunteering fell from 23.0% (2015) to 15.6% (2022) in France and from 12.0% to 5.3% in Italy, and Germany has no 2022 value in the published table. Over the same years the Italian annual survey moved from 10.7% to 8.3%, a far smaller fall, so most of the gap between the modules is not behaviour. I did not verify the cause (questionnaire wording and the pandemic period are the obvious candidates, UNVERIFIED). Use one module or the other, never a mix. National surveys differ from EU-SILC in level (Germany 39.7% against 28.6%), in age range (14+ or 15+ against 16+) and in reference period (the ISTAT 2013 module is four weeks).

### 2.5 Which numbers exist at which level

| Quantity | National | Degree of urbanisation | TL2 region |
|---|---|---|---|
| Inactive share, ages 20 to 64, 15 to 74, 15+ (LFS, annual to 2025) | yes | yes | yes, all 51 |
| Age mix of the inactive (LFS) | yes | yes | yes |
| Type mix of the inactive: students, retired, other (Census 2021) | yes | no | yes |
| Status mix, EU-SILC 2015 (employed, unemployed, retired, other) | yes | no | no |
| Participation of everyone, EU-SILC 2015 and 2022 | yes (DE 2015 only) | yes (DE 2015 only) | no |
| Participation of everyone, national surveys | yes | IT by type of municipality (not pulled) | DE (Freiwilligensurvey 2019), IT (ISTAT annual), none for FR |
| Participation by age, EU-SILC | yes | no | no |
| Participation by activity status | IT (ISTAT annual, 2013 to 2025), DE (2019), FR membership only (2008) | no | no |

### 2.6 The accounting identity, filled two ways

For a place r: P_r = (1 - s_r) p_LF,r + s_r p_I,r, with P the participation of everyone, s the inactive share of the survey population (ages 15+), p_LF the labour force's participation and p_I the inactive's.

Method A (age proxy, all three countries): the inactive of each age band in the place take part at the national EU-SILC 2015 rate of that band. Method B (status ratio, Italy and Germany): p_I = rho x p_LF, where rho weights the national rates of students, retired and other inactive relative to the labour force by the place's census mix. Relative rates used: Italy students 1.34, retired 0.84, other 0.63 (ISTAT annual, 2015). Germany students 1.04, retired 0.71, other 0.77 (Freiwilligensurvey 2019, with the labour-force rate built from full-time, part-time and unemployed rates and LFS weights, giving 44.6%).

| 2015, EU-SILC scale | s (15+) | P everyone | p_I (A) | p_LF (A) | rho (B) | p_LF (B) |
|---|---|---|---|---|---|---|
| FR national | 44.0 | 23.0 | 22.7 | 23.2 | none | none |
| FR cities | 43.0 | 20.3 | 22.7 | 18.5 | | |
| FR towns and suburbs | 46.6 | 21.4 | 22.7 | 20.2 | | |
| FR rural | 43.3 | 27.7 | 22.8 | 31.4 | | |
| DE national | 39.8 | 28.6 | 29.8 | 27.8 | 0.76 | 31.6 |
| DE cities | 40.1 | 23.5 | 29.6 | 19.4 | 0.76 | 26.0 |
| DE towns and suburbs | 40.4 | 29.6 | 29.8 | 29.5 | 0.76 | 32.7 |
| DE rural | 38.4 | 34.5 | 29.8 | 37.4 | 0.76 | 37.9 |
| IT national | 51.0 | 12.0 | 11.5 | 12.5 | 0.84 | 13.1 |
| IT cities | 50.5 | 11.4 | 11.5 | 11.3 | 0.84 | 12.4 |
| IT towns and suburbs | 51.1 | 12.3 | 11.6 | 13.0 | 0.84 | 13.4 |
| IT rural | 51.6 | 12.2 | 11.5 | 13.0 | 0.84 | 13.3 |

For TL2 regions the csv gives method B for the 16 German Länder (P from the Freiwilligensurvey 2019, s for 2019) and the 21 Italian regions (P from the ISTAT annual survey 2023 to 2025, s for 2024). The regional rho runs from 0.75 to 0.77 in Germany and from 0.81 (Campania, Sicily) to 0.88 (Bolzano, Trento) in Italy.

What the two methods show.

1. The two methods disagree on the level. EU-SILC by age says older people volunteer about as much as those of working age, so the inactive take part about as much as everyone and p_LF is within one point of P. The national surveys by status say the inactive take part at about 0.76 to 0.85 of the labour-force rate, so p_LF is 9 to 10% above P.
2. Method A applies one national rate per age band everywhere, which forces all differences between place types into the labour force (French cities 18.5 against rural 31.4). It is an upper bound on how much of the spread belongs to the labour force.
3. Under method B the correction factor is 1 - s (1 - rho). With s between 0.35 and 0.61 and rho between 0.75 and 0.88 it lies between 0.89 and 0.95 across all German and Italian regions (0.89 to 0.92 in Germany, 0.89 to 0.95 in Italy). Italian regional participation runs from 4.9% to 20.1%. Inactivity therefore moves the level by 5 to 11% and explains almost none of the regional spread.

---

# PART B. RECOMMENDATIONS

## QBAR

Set QBAR to **0.04**, with 0.02 and 0.07 as the sensitivity bounds, and treat 0.10 as outside the data for the model's definition of participation.

The reasoning is as follows. The model's participation targets are formal volunteering (EU-SILC AC41A), so the time cost should be the time formal volunteers give. The diary measure of exactly that is 0.012 (FR), 0.047 (DE) and 0.022 (IT). Stylised questions, which run high, give 0.037 (FR), 0.048 (IT, 0.067 for those active in a given month) and roughly 0.04 to 0.06 (DE). Adding all participatory activity gives 0.046, 0.069 and 0.076. The value 0.04 is inside every country's interval and close to the German diary and the French and Italian survey figures. The value 0.10 is reached only by also loading all informal help onto formal volunteers. It corresponds to about five hours a week, whereas two thirds of French volunteers give one hour or less and 60% of German volunteers give two hours or less, with only 11% and 17% giving six hours or more.

A single value across countries is the defensible choice in my view. The diary differences (France a quarter of Germany) are larger than the survey differences and partly reflect coding. If country values are wanted, about 0.025 (FR), 0.05 (DE) and 0.035 (IT) are the midpoints of the diary and survey figures, and I would label them weakly identified.

If the model is later meant to cover informal help as well, the participation target has to widen with it (formal or informal, roughly double the rate), and then the matching cost is 0.03 to 0.08, not 0.10.

One consistency point to check in the code: AC41 and AC42 are already inside the committed-time denominator, so a participant's QBAR is drawn from the same total that effort is measured against. That is the right structure, provided the non-participant's time on these activities is treated as zero.

## The accounting layer

1. Use the inactive share of the population aged 15+ for s, not 20 to 64. The regional surveys cover everyone from 14, 15 or 16, and at 15+ the inactive are 35 to 61% of the population against 13 to 44% at 20 to 64. The 15+ series exists for every TL2 region and every place type, annually, from `lfst_r_lfsd2pwc` and `lfsa_pgauws`.
2. Set p_I = rho x p_LF with rho = 0.85 for Italy (ISTAT annual survey, identical in 2015 and 2025) and rho = 0.76 for Germany (Freiwilligensurvey 2019). France has no source: use 0.80, the midpoint, and report the result for rho = 1 (the EU-SILC age proxy) as the alternative. Then P_r = p_LF,r x [1 - s_r (1 - rho)].
3. A regional rho from the census mix (csv `accounting_layer.csv`) is available for Germany and Italy and moves rho by at most 0.07. It is optional. I would use the national rho and keep the regional one as a check.
4. Expect the layer to rescale, not to explain. It lowers model participation by 5 to 11% to make it comparable with regional data, and leaves the regional and urban-rural spread to the model.
5. Apply the same logic to the national targets. `part_low` and `part_high` come from everyone aged 25 to 64, of whom 18% (DE) to 31% (IT) were inactive in 2015 (ages 20 to 64). With rho below one the labour force's true rate is a few percent above the target. For Italy, where the working-age inactive are mostly homemakers (relative rate about 0.6), a rough calculation puts the gap near 10%. This is a level correction of about the same size as point 4. If neither is applied the two errors largely cancel, because the model is calibrated to a mixed population and compared with a mixed population. If only the regional layer is applied, the model sits too low by the size of this target gap, so the two corrections should be made together or not at all.
6. Keep to the 2015 module throughout. The 2022 module is 32% (FR) and 56% (IT) lower and has no German value.

## Not confirmed

- France: twelve-month volunteering rate of the retired, students and homemakers. Not found in an official table. The SRCV 2008 figures in 2.4 (e) were read through an automated page reader, with the sentences quoted, and deserve a look at the original before citing.
- Germany: mean weekly hours per volunteer. Only the bands were read.
- EU-SILC 2015 volunteering by activity status: not published, microdata needed.
- The reason the 2015 and 2022 EU-SILC modules differ in level.
- Regional participation values taken from the repository's `volunteering_by_region.csv` were used as given and not re-verified here.

## Sources

Eurostat dissemination API, base `https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/<dataset>?format=JSON`, pulled 2 October 2026:

- `tus_00selfstat` (HETUS waves 2000 and 2010 by self-declared labour status), `...&geo=FR&geo=DE&geo=IT&sex=T&acl00=AC1A&acl00=AC3&acl00=AC41&acl00=AC42&acl00=AC43`. Metadata: https://ec.europa.eu/eurostat/cache/metadata/en/tus_00_esms.htm
- `ilc_scp19`, `ilc_scp20` (EU-SILC ad hoc modules 2015 and 2022, volunteering and active citizenship)
- `ilc_lvhl02` (EU-SILC, population by most frequent activity status)
- `lfsa_eppga` (part-time share), `demo_pjangroup` (population by age)
- `lfst_r_lfsd2pwc`, `lfst_r_lfp2actrt`, `lfst_r_lfp2actrc` (regional LFS), `lfsa_pgauws` (LFS by degree of urbanisation)
- `cens_21a_r2` (Census 2021, current activity status by region)

ISTAT SDMX: https://esploradati.istat.it/SDMXWS/rest/data/83_63_DF_DCCV_AVQ_PERSONE_131/?startPeriod=2013 (Aspetti della vita quotidiana, Associazionismo by occupational status).

Documents read in full text:

- ISTAT (2014). Attività gratuite a beneficio di altri. Anno 2013. Statistica report, 23 July 2014. https://www.istat.it/it/files/2014/07/Statistica_report_attivita_gratuite.pdf
- Simonson, J., Kelle, N., Kausmann, C. and Tesch-Römer, C. (eds) (2021). Freiwilliges Engagement in Deutschland: Der Deutsche Freiwilligensurvey 2019. Berlin: Deutsches Zentrum für Altersfragen. Read at https://www.ehrenamt.bayern.de/imperia/md/content/stmas/lbe_2023/system/freiwilliges_engagement_in_deutschland.pdf
- BMFSFJ (2021). Freiwilliges Engagement in Deutschland: Zentrale Ergebnisse des Fünften Deutschen Freiwilligensurveys (FWS 2019). https://www.bmbfsfj.bund.de/resource/blob/176836/7dffa0b4816c6c652fec8b9eff5450b6/freiwilliges-engagement-in-deutschland-fuenfter-freiwilligensurvey-data.pdf
- Prouteau, L. and Wolff, F.-C. (2004). Donner son temps : les bénévoles dans la vie associative. Économie et Statistique 372, from p. 3. https://www.insee.fr/fr/statistiques/fichier/1376604/es372a.pdf
- Luczak, F. and Nabli, F. (2010). Vie associative : 16 millions d'adhérents en 2008. Insee Première 1327. https://www.insee.fr/fr/statistiques/1280946

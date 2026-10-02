# HFCS readiness pack

Prepared 2026-10-02, before the microdata arrived, from the public ECB documentation and the published literature only. The companion script is `hfcs_moments.py` in this folder. Its self-test passes on synthetic data (section 8). Every name or definition that I could not read in an official document is marked **TO CONFIRM ON ARRIVAL** here and in the script.

## Documents used

| code | document | URL |
|---|---|---|
| HP | HFCS home page (list of all documents) | https://www.ecb.europa.eu/stats/ecb_surveys/hfcs/html/index.en.html |
| C10 | Core variables catalogue, wave 1 (UDB doc 2) | https://www.ecb.europa.eu/home/pdf/research/hfcn/HFCS_2010_Wave_Core_and_Derived_Variables.pdf |
| C14 | UDB documentation, core and derived variables, wave 2 (March 2020) | https://www.ecb.europa.eu/home/pdf/research/hfcn/HFCS_2014_Wave_Core_and_Derived_Variables.pdf |
| C17 | UDB documentation, core and derived variables, 2017 wave (June 2021) | https://www.ecb.europa.eu/home/pdf/research/hfcn/HFCS_2017_Wave_Core_and_Derived_Variables.pdf |
| C21 | UDB documentation, core and derived variables, 2021 wave (July 2023) | https://www.ecb.europa.eu/home/pdf/research/hfcn/HFCS_Core_and_Derived_Variables_2021_Wave.pdf |
| C23 | UDB documentation, core variables, 2023 wave (June 2026) | https://www.ecb.europa.eu/home/pdf/research/hfcn/HFCS_Core_output_derivables_2023_Wave.pdf |
| D23 | UDB documentation, derived variables, 2023 wave (June 2026). The file name says 2013, the content is the 2023 wave | https://www.ecb.europa.eu/home/pdf/research/hfcn/HFCS_2013_Wave_Derived_Variables.pdf |
| N21, N23 | Non-core variables, 2021 and 2023 waves | https://www.ecb.europa.eu/home/pdf/research/hfcn/HFCS_NonCore_Variables_2021_Wave.pdf and https://www.ecb.europa.eu/home/pdf/research/hfcn/NoncoreVariables_2023.pdf |
| M10 | Methodological report, first wave, Statistics Paper Series 1 (2013) | https://www.ecb.europa.eu/pub/pdf/other/ecbsp1en.pdf |
| M14 | Methodological report, second wave, Statistics Paper Series 17 (2016) | https://www.ecb.europa.eu/pub/pdf/scpsps/ecbsp17.en.pdf |
| M17 | Methodological report, 2017 wave, Statistics Paper Series 35 (2020) | https://www.ecb.europa.eu/pub/pdf/scpsps/ecb.sps35~b9b07dc66d.en.pdf |
| M21 | Methodological report, 2021 wave, Statistics Paper Series 45 (2023) | https://www.ecb.europa.eu/pub/pdf/scpsps/ecb.sps45~4bbcfb02eb.en.pdf |
| M23 | Methodological report, 2023 wave, Statistics Paper Series 52 (2026) | https://www.ecb.europa.eu/pub/pdf/scpsps/ecb.sps52.en.pdf |
| AF | Research dataset request form, with the confidentiality commitment | https://www.ecb.europa.eu/home/pdf/research/hfcn/access_form_leadresearchersurname_researchersurname.pdf |
| KVW | Kaplan, Violante and Weidner (2014), "The Wealthy Hand-to-Mouth", Brookings Papers on Economic Activity, Spring, 77-138 | https://www.brookings.edu/wp-content/uploads/2016/07/2014a_Kaplan.pdf |
| BT | Balestra and Tonkin (2018), "Inequalities in household wealth across OECD countries", OECD Statistics Working Papers 2018/01, SDD/DOC(2018)1 | https://www.oecd.org/en/publications/inequalities-in-household-wealth-across-oecd-countries_7e1bf673-en.html |
| DFL | Drescher, Fessler and Lindner (2020), "Helicopter money in Europe", Economics Letters 195, 109416 | https://doi.org/10.1016/j.econlet.2020.109416 (full text read at Europe PMC, PMC7382353) |

Two reading notes. The OECD's own PDF link returned errors on the day, so I read the text of SDD/DOC(2018)1 from a copy of the same document at old.iariw.org/copenhagen/balestra.pdf, and the page numbers below are those of the working paper. Page numbers for the ECB catalogues are the printed page numbers, which equal the PDF pages.

## 1. What the HFCS is

The Eurosystem Household Finance and Consumption Survey is a harmonised household survey of assets, liabilities, income and selected consumption, run by the national central banks and some statistical institutes under the Household Finance and Consumption Network. It is harmonised on output: each country delivers the same list of core variables, and may collect them through its own survey (Italy through the Banca d'Italia SHIW, France through Insee's Enquête Patrimoine: M21 pp. 20-21). Samples are designed to be representative at the euro area and national levels (M23 p. 8), which matters for section 4.

**Waves, reference periods and net sample sizes for FR, DE, IT.**

| wave | country | fieldwork | assets and liabilities | income | net sample (households) | source |
|---|---|---|---|---|---|---|
| 2010 | DE | 09/2010 to 07/2011 | time of interview | 2009 | 3,565 | M10 Table 9.1 p. 74, response table p. 41 |
| 2010 | FR | 10/2009 to 02/2010 | time of interview | 2009 | 15,006 | same |
| 2010 | IT | 01/2011 to 08/2011 | 31/12/2010 | 2010 | 7,951 | same |
| 2014 | DE | 04/2014 to 11/2014 | time of interview | 2013 | 4,461 | M14 Table 9.1, Table 5.1 |
| 2014 | FR | 10/2014 to 02/2015 | time of interview | 2014 | 12,035 | same |
| 2014 | IT | 01/2015 to 06/2015 | 31/12/2014 | 2014 | 8,156 | same |
| 2017 | DE | 03/2017 to 10/2017 | time of interview | 2016 | 4,942 | M17 Table 1 p. 6, sample table p. 37 |
| 2017 | FR | 09/2017 to 01/2018 | time of interview | 2016 | 13,685 | same |
| 2017 | IT | 01/2017 to 09/2017 | 31/12/2016 (dwellings at interview) | 2016 | 7,420 | same |
| 2021 | DE | 04/2021 to 01/2022 | time of interview | last calendar year | 4,119 | M21 Table 1 p. 3, Table 14 p. 38 |
| 2021 | FR | 09/2020 to 03/2021 | time of interview | 2020, built from 2019 fiscal data | 10,253 | same |
| 2021 | IT | 03/2021 to 12/2021 | 31/12/2020 (dwellings at interview) | 2020 | 6,239 | same |
| 2023 | DE | 05/2023 to 02/2024 | time of interview | last calendar year | 3,985 | M23 Table 2 p. 8, sample table p. 42 |
| 2023 | FR | 06/2023 to 01/2024 | time of interview | 2023, built from 2022 fiscal data | 11,941 | same |
| 2023 | IT | 01/2023 to 12/2023 | 31/12/2022 (dwellings at interview) | 2022 | 9,641 | same |

All three countries are in all five waves (M23 Table 1 p. 7). The page numbers in the last column are printed page numbers as I read them from the PDF text, and the sample-size tables should be glanced at once more when writing the paper.

**Income concept.** Core income variables are gross of taxes and social contributions. France is the exception: its income comes from fiscal registers and is gross of taxes but net of social contributions, and two components (private business other than self-employment, other sources) are not collected (M21 Table 5 p. 22, M23 p. 24). Italy collects net income and the Banca d'Italia estimates gross income with a tax model (same table). There is no core net income variable. Net income components and "income taxes and social contributions" (HNG0710) exist as non-core variables for Italy only among our three countries (M21 Appendix A2 p. 80, M23 Appendix A2 p. 81).

**Structure of the user database.**

- Units: household-level variables (prefix H for core, D for derived) and person-level variables (prefixes R and P). Core variable names are a letter block plus four digits, with section letters A demographics, B real assets, C liabilities and credit constraints, D businesses and financial assets, E employment, F pensions, G income, H gifts, I consumption (C21 contents).
- Derived variables (prefix D) are computed by the ECB from the core variables: DA assets, DL liabilities, DN net positions, DI income, DH household descriptors, DO other indicators (C21 pp. 153-201, D23).
- Multiple imputation: five implicates, identified by IM0100 (C21 p. 150, M21 p. 45). Every household appears five times.
- Weights: HW0010 is the household estimation weight. Italy also has HW0010a for comparisons across waves, because its sample design changed in 2021. HW0010 is for cross-sectional use (C21 p. 151, C23 p. 138).
- Replicate weights: WR0001 to WR1000, Rao-Wu rescaled bootstrap (C21 p. 152, M21 pp. 52-54).
- Flags: every variable xxxxxxx has a flag Fxxxxxxx giving its origin (collected, edited, imputed, set missing for anonymisation: C21 p. 151).
- Identifiers: SA0100 country, SA0010 household, RA0010 person. The ECB's own Stata example imports the data with `mi import flong, m(im0100) id(sa0100 sa0010)` and `mi svyset [pw=hw0010], bsrweight(wr0001-wr1000)` (M10 Table 7.3 p. 67), which confirms the long layout and suggests lower-case names in Stata.
- **File names and formats: TO CONFIRM ON ARRIVAL.** No public document that I read lists the file names. M10 refers to the "household-level file", the "personal-level file" and the "H file" (pp. 76, 102). The script expects one folder per wave holding D (derived), H (household core), P (person core), HN and PN (non-core) and W (replicate weights) files, either one per implicate (D1 to D5) or stacked, in Stata or csv, and all of this is set in one block at the top of the script.

## 2. Variable map

Status "confirmed" means the name and definition were read in the catalogue cited. Whether the variable is filled for a given country and wave is what the script's coverage table reports on day one.

### A. Wealth and income

KVW's definitions for the euro area, from the paper (pp. 92-96):

- **Sample:** head aged 22 to 79, households dropped if income is negative or if all income is from self-employment. Final samples in the 2008-10 HFCS: DE 3,091, FR 12,688, IT 6,384 (Table 1).
- **Income:** "gross income from wages, salaries, and self-employment, unemployment benefits, regular private transfers such as child support and alimony, and regular public transfers". Capital income is excluded.
- **Liquid assets:** "cash, sight (also called current, draft, or checking) accounts, mutual fund holdings, shares in publicly traded companies, and corporate or government bond holdings".
- **Cash adjustment:** cash is not observed, so transaction-account balances are inflated by the ratio of average cash holdings (138 dollars, 2010 Survey of Consumer Payment Choice) to median transaction accounts in the 2010 SCF (2,500 dollars), about 5.5 percent, in all surveys (p. 95 and footnote 9).
- **Liquid debt:** "the balance on credit cards after the most recent payment that accrue interest, together with any balances on credit lines or bank overdrafts that also accrue interest". Net liquid wealth is liquid assets minus liquid debt.
- **Illiquid wealth:** "the value of the household's main residence and other properties net of mortgages and unsecured loans specifically taken out to purchase the home, plus occupational and voluntary pension plans, cash value of life insurance policies, certificates of deposit, and saving bonds". Businesses, vehicles and valuables are robustness rows only.

| concept | HFCS variable(s) | file | status and source |
|---|---|---|---|
| sight accounts | DA21011 (= HD1110) | D (H) | confirmed C21 pp. 84, 157 |
| saving accounts, time deposits, certificates of deposit | DA21012 (= HD1210) | D (H) | confirmed C21 pp. 85-86, 157 |
| mutual funds | DA2102 | D | confirmed C21 p. 158 |
| bonds | DA2103 (= HD1420) | D | confirmed C21 p. 158 |
| publicly traded shares | DA2105 (= HD1510) | D | confirmed C21 p. 159 |
| credit line or overdraft balance | DL1210 (= HC0220) | D | confirmed C21 pp. 66, 184. C10 p. 150 prints HC0210, which is the yes or no question and looks like a misprint |
| credit card balance charged interest | DL1220 (= HC0320) | D | confirmed C21 pp. 67, 184. Not asked in France in wave 1 (M10 p. 83) |
| cash | none | | not collected. KVW factor 1.055 applied to sight accounts |
| credit limit | none | | not collected. KVW assume one month of income |
| ECB net liquid assets | DNNLA = DA2101 + DA2102 + DA2103 + DA2104 + DA2105 + DA2106 - DL1210 - DL1220 - DL1230, and DNNLAratio | D | confirmed C21 p. 190, D23 pp. 48-49 |
| main residence | DA1110 | D | confirmed C21 p. 153 |
| all real estate (main residence + other) | DA1400 | D | confirmed C21 p. 156 |
| mortgage debt | DL1100 (= DL1110 + DL1120) | D | confirmed C21 p. 180 |
| voluntary pensions and whole life insurance | DA2109 | D | confirmed C21 p. 160 |
| occupational pension accounts | wave 1: PF0710. Later waves: PFA080$x where PFA020$x = 2 | P | names confirmed (C10 p. 114, C21 pp. 113, 118). **Not used by the script: TO CONFIRM ON ARRIVAL** whether to add them |
| unsecured loans taken to buy the home | HC050$x (purpose) with HC080$x (balance) | H | names confirmed C21 pp. 71, 73. **Not netted by the script: TO CONFIRM** |
| business wealth | DA1200 (= DA1121 + DA1140) | D | confirmed C21 p. 155 |
| net wealth | DN3001 = DA3001 - DL1000, excluding public and occupational pensions | D | confirmed C21 p. 189 |
| gross household income | DI2000 | D | confirmed C21 p. 178 |
| labour and transfer income (KVW) | DI1100 + DI1200 + DI1610 + DI1620 + DI1700, plus DI1510 by a switch | D | names confirmed C21 pp. 172-177. **Whether KVW count public pensions among "regular public transfers" is TO CONFIRM** against their replication files |
| net household income | DI2000 - HNG0710 | D, HN | HNG0710 confirmed N21 and N23, listed for Italy and Finland only. **TO CONFIRM** that it is delivered. France and Germany: not feasible from the HFCS |
| household size, consumption units | DH0001, DH0002 | D | confirmed C21 p. 162. C21 p. 178 prints "DI2000eq = DI2000 / DH0003", C14 p. 156 and D23 p. 36 print DH0002. The script does its own equivalisation |

**The treatment of saving accounts in KVW.** KVW's text names sight accounts only as liquid in the HFCS and lists certificates of deposit and saving bonds as illiquid. The HFCS does not separate these: HD1210 pools Livret-type saving accounts, Sparbuch, Tagesgeld, time deposits and certificates of deposit. Two numbers in their Table 2 (p. 99) indicate that the whole of HD1210 was treated as illiquid. The median of "cash, checking, saving, MM accounts" is 1,255 euros in France and 1,154 in Germany, which is the order of magnitude of sight accounts alone, and the share of households with positive net illiquid wealth is 0.922 in France although only 0.607 own housing, 0.039 hold retirement accounts and 0.378 life insurance. The script therefore puts saving accounts in illiquid wealth for the KVW replication (`KVW_SAVING_ACCOUNTS_ILLIQUID = True`). This is my inference from the published table, **TO CONFIRM** by reproducing Table 5 on the 2010 wave, which the script does in `hfcs_benchmarks.csv`. It matters a great deal for France, where regulated saving accounts are liquid in practice, and so the script also reports a broad liquid wealth with all deposits liquid.

### B. Hand-to-mouth

| concept | definition | source |
|---|---|---|
| KVW at the zero kink | 0 <= liquid <= y/2, with y the income of one pay period | KVW eq. 8-9 pp. 88-89 |
| KVW at the credit limit | liquid < 0 and liquid <= y/2 - limit | KVW eq. 10-11 pp. 89-90 |
| poor and wealthy | illiquid <= 0 is poor (including negative housing equity), illiquid > 0 is wealthy | KVW p. 89 |
| pay period | two weeks in the benchmark, from US Consumer Expenditure Survey pay frequencies, applied to every country. One week and one month are robustness rows | KVW p. 101, Table 5 pp. 119-120 |
| credit limit | one month of income, common to all surveys | KVW p. 101 |
| model rule | liquid <= annual labour-plus-benefit income / 52, wealthy if illiquid > 0, no credit-limit branch, no sample restriction | `egm2_core.jl` line 550 |

The two rules share the threshold, since half of a fortnight's income is one week of income. They differ in four ways: KVW's sample restriction, KVW's requirement that a borrower be at the credit limit (the model rule counts every household with negative liquid wealth), the cash factor, and the classification of saving accounts. The script reports `htm_kvw_*` (with weekly and monthly variants), `htm_model_narrow_*` (KVW wealth, model rule, all households) and `htm_model_broad_*` (all deposits liquid, illiquid as net wealth minus liquid), so each step is visible.

### C. Wealth to income, concentration

| concept | definition | source |
|---|---|---|
| net wealth to income target (FR 4.02, DE 2.38, IT 5.51) | median DN3001 over median DI2000, a ratio of two medians: HFCS 2021 statistical tables A1 (125.7, 106.7, 151.0 thousand euros) over I1 (31.3, 44.8, 27.4) | `data/manual_inputs.csv`, rows `nw_income_target` |
| liquid wealth to income | ratio of medians for both liquid concepts, and the median household ratio. `TWO_ASSET_DESIGN.md` cites "Table F1: 0.25 FR, 0.30 DE, 0.27 IT". The derived variable DNNLAratio is the candidate concept behind it, and the script reports its median as `dnnla_to_income_median_of_ratio`. **TO CONFIRM** which concept Table F1 uses |
| net wealth Gini, top 10% share | on DN3001, households, weight HW0010 | DN3001 confirmed C21 p. 189 |

### D. Poverty and hardship

BT section 6 and Box 6.1 (pp. 56-63): the unit is the individual, income and wealth are equivalised by the square root of household size, the income poverty line is 50 percent of the national median, and a person is asset poor if liquid financial wealth is below a quarter of the annual poverty line (three months). Liquid financial assets are "cash, quoted shares, mutual funds and bonds net of liabilities of own unincorporated enterprises". Where the wealth survey has no disposable income, gross income is used, "which implies an upward bias in estimates of asset-based poverty". That is the HFCS case. BT Table 6.1 (p. 63) gives, for 2015 or the latest year: asset poor (three months) FR 40.5, DE 42.4, IT 38.7 percent, income poor FR 11.0, DE 15.8, IT 14.2, and both FR 8.4, DE 11.4, IT 11.8.

| concept | HFCS construction | status |
|---|---|---|
| equivalised income | DI2000 / sqrt(DH0001), person weights HW0010 x DH0001 | confirmed names. Gross income, not disposable |
| income poverty | below 50 percent (and 60 percent) of the national median, per implicate | BT p. 56 |
| liquid financial wealth (OECD) | DA21011 + DA21012 + DA2102 + DA2103 + DA2105, gross, equivalised the same way | my mapping of BT's list. Deposits stand for "cash". **TO CONFIRM** against the OECD Wealth Distribution Database definitions if exact replication is wanted |
| asset poverty | equivalised liquid financial wealth < 0.25 x the 50 percent line | BT Box 6.1 |
| hardship | asset poor and income poor. "Vulnerable" is asset poor and not income poor | BT pp. 56-57 |

### E. Groups

| group | HFCS variable | coding | status |
|---|---|---|---|
| education of the reference person | DHEDUH1 (from PA0200) | 1 ISCED 0-1, 2 ISCED 2, 3 ISCED 3-4, 5 ISCED 5-8. Below tertiary = 1, 2, 3 | confirmed C21 pp. 30, 166. The ISCED 0-4 against 5-8 cut is exactly available. Finer cuts are not: categories are grouped for anonymisation (M21 p. 58) |
| labour status of the reference person | DHEMPH1 | 1 employee, 2 self-employed, 3 unemployed, 4 retired, 5 other | confirmed C21 p. 166 |
| reference person | DHIDH1, UN/Canberra definition | | confirmed C21 p. 168 |
| region | DHREGION (recoded from SA0300) | see section 4 | confirmed C17 p. 163, C21 pp. 170-172, D23 pp. 28-30 |
| degree of urbanisation | DHDEGURBA (from SC0310) | 1 cities, 2 towns and suburbs, 3 rural | confirmed C21 p. 165, D23 p. 24 |

### F. Self-reported MPC

| item | finding | source |
|---|---|---|
| variable | HIZ040a (percent spent), HIZ040b (its complement to 100), derived DOLOTTGOOD = HIZ040a | C17 pp. 144, 190. C21 pp. 149, 199. C23 p. 136. D23 p. 58 |
| wording | "Imagine you unexpectedly receive money from a lottery, equal to the amount of income your household receives in a month. What percent would you spend over the next 12 months on goods and services, as opposed to any amount you would save for later or use to repay loans?" Answer on a ruler from 0 to 100 | C21 p. 149 |
| waves | 2017 (added in the third wave: M17 p. 13), 2021, 2023. Not in the 2010 and 2014 catalogues | C10, C14 |
| countries | in 2017 it is "not collected in Estonia, Finland, Hungary or Poland" (M17 p. 77), so FR, DE and IT have it. For 2021 and 2023 no such list was found: **TO CONFIRM ON ARRIVAL** | |
| published means, HFCS 2017 | DE 51.3 (s.e. 0.8), FR 41.8 (0.5), IT 48.1 (0.7) percent, with no missing values in the three countries. Range across 17 countries: 33 (Netherlands, Portugal) to 57 (Greece, Lithuania) | DFL Table 2 |
| published pattern | answers cluster at 0, 50 and 100. The MPC falls with income and has "hardly any correlation" with net wealth. DFL do not cut by liquid wealth, which is the cut the model needs | DFL abstract and section 3 |
| name caveat | DFL print the variable as "hiz0400a". The catalogue says HIZ040a. The script tries DOLOTTGOOD, HIZ040A, HIZ0400A in turn | **TO CONFIRM ON ARRIVAL** |

### G. Consumption

| concept | HFCS variable | notes |
|---|---|---|
| food at home, typical month | HI0100 | all waves (C10 p. 84, C21 p. 143). COICOP 01 and 02.1 |
| food outside the home, typical month | HI0200 | all waves. In wave 1 it is merged into HI0100 for Italy (M10 p. 85) |
| utilities, typical month | HI0210 | from wave 2 (C14 p. 127) |
| all consumer goods and services, typical month | HI0220 | from wave 2 (C14 p. 128). Includes food and utilities, excludes durables, rent, loan repayments, insurance and renovation. Not total consumption |
| trips and holidays, last 12 months | HI0230 | from wave 3 (C17 p. 140) |
| annual derived versions | DOFOODC, DOFOODCH, DOCOGOOD, DOCOUTIL | C21 and D23 define them as 12 x the monthly amount, C14 and C17 print them without the factor 12. The script annualises the H-file amounts itself |
| expenses against income | HI0600 (1 above, 2 equal, 3 below income) | all waves except Italy in wave 1 (M10 p. 85). KVW use it as a check |

Consumption to income by group is feasible from 2014 with HI0220 over DI2000. It is non-durable spending over gross income, so its level is not comparable with the model's consumption share and only its gradient across groups is informative.

### H. Portfolio

| concept | HFCS construction | status |
|---|---|---|
| any illiquid wealth | DA1400 > 0 or DA2109 > 0 or DA1200 > 0 | confirmed names |
| home ownership | DA1110 > 0 (or DHHST in 1, 2) | confirmed C21 pp. 153, 167 |
| mortgage debt | DL1100, share of holders, median among holders, aggregate over income | confirmed |
| illiquid to liquid | ratio of medians and median household ratio | constructed |
| frequency of large adjustments | no direct question in FR, DE, IT. Proxies: HB0700 year the main residence was acquired (share acquired in the last five years), DREFINANi refinanced mortgage, HB130$x year a mortgage was taken. A non-core question on sold properties (HNB2800) exists for Malta only (M23 Appendix A2) | HB0700 confirmed C21 p. 35, bottom-coded at 1935. Reasons for and details of refinancing are not collected in Italy (M17 p. 76) |

### I. Credit constraints

| concept | HFCS variable | notes |
|---|---|---|
| applied for credit in the last three years | HC1300, DOCREDITAPPL | confirmed C21 pp. 75, 192 |
| refused or given less | HC1310a, HC1310b (1 turned down, 2 less than asked, 3 no). Wave 1: single HC1310. DOCREDITREFUSAL | confirmed C21 pp. 75-76, 193 |
| later successful | HC1320 | not asked in Italy in wave 2 (M14 p. 95) |
| discouraged | HC1400, DOCREDITNOTAPPL | confirmed C21 pp. 76, 192 |
| credit constrained | DOCREDITC = 1 if (refused and not later successful) or given less or discouraged | confirmed C21 p. 192 |
| has overdraft facility, has credit card | DLCL (HC0200), DLCC (HC0300) | confirmed C21 p. 188 |
| Italy, wave 1 | the whole block is "not provided for Italy due to the different approach and wordings used in the national questionnaire" | M10 p. 84 |
| reasons for refusal | HNC0200, non-core, France only | M21, M23 Appendix A2 |

## 3. Estimation protocol

1. **Weights.** Every statistic uses HW0010. Person-level statistics (section D) use HW0010 times household size.
2. **Implicates.** Each statistic is computed separately on each of the five implicates and the point estimate is the mean of the five (M21 section 7.3, pp. 54-55). Medians, shares, Gini coefficients and ratios of medians are all treated this way: the statistic is computed within the implicate and then averaged. The five implicates are never pooled into one sample, and no implicate is used alone.
3. **Standard errors.** For implicate m, the statistic is recomputed with each replicate weight and U_m is the variance across replicates. Then W is the mean of U_m, Q is the variance of the five point estimates, and the total variance is T = W + (1 + 1/M) Q, with M = 5 (M21 p. 54). The script uses the first 200 replicate weights by default, which the report allows (M21 p. 53: the first 200 or 500 give faster, slightly less stable estimates), and `--nrep 1000` uses all of them.
4. **Degrees of freedom.** The report gives the Rubin and the Barnard and Rubin (1999) formulas and leaves the choice to users (M21 p. 55). The script reports standard errors only. Tests on small regional cells should use the small-sample formula.
5. **Medians and quantiles.** The weighted quantile is the smallest value at which the cumulative weight share reaches q, without interpolation. The bootstrap is consistent for quantiles (M21 p. 52). The ECB tables may interpolate, so differences in the last digit against published medians are expected.
6. **Quantities that depend on a national threshold** (the poverty line, the liquid wealth quintile cut-offs) are computed per implicate with the main weight and held fixed across replicate weights. This understates their standard errors slightly and is a deliberate simplification.
7. **Equivalisation.** Square root of household size for section D, following BT. The HFCS's own DH0002 is the modified OECD scale (1, 0.5, 0.3: C21 p. 162) and can be swapped in with one line.
8. **Negative and zero incomes.** The ECB bottom-codes non-positive income at 1 euro in its own ratios (C21 pp. 194-195). The script uses all households for ratios of medians, restricts household-level ratios (liquid over income, consumption over income) to positive income, drops negative income from the KVW sample as KVW do, and reports the share with non-positive income so the restriction is visible.
9. **Missing amounts.** A missing amount for an item the household does not hold is treated as zero. Because a variable that a country did not collect would then silently become zero, the script writes `hfcs_coverage.csv` with the share of households with a non-missing value for every variable, country and wave. Read it first.
10. **Top-coding and rounding.** Monetary amounts are not top-coded in the general procedure. Age is top-coded at 85, and several year and duration variables are coded at bounds (M21 p. 58). Some countries apply random rounding to amounts, independently across implicates, with a negligible effect on means and medians (M21 pp. 58-59). Which of FR, DE and IT round is **TO CONFIRM ON ARRIVAL**. Age may be delivered in brackets only for some countries, in which case the script falls back on DHAGEH1B and the KVW age window becomes 20 to 79.
11. **Comparisons across waves.** For Italy, HW0010a replaces HW0010 in comparisons with earlier waves (C21 p. 151). Variances of changes should assume independence across waves, which is conservative given the panel components (M21 pp. 55-56).
12. **Disclosure.** Any cell based on fewer than 30 unweighted households is suppressed. See section 6 for the status of this rule.

## 4. By place: what the HFCS can and cannot provide

| | France | Germany | Italy |
|---|---|---|---|
| region variable | DHREGION | DHREGION | DHREGION |
| waves with region | 2017, 2021, 2023. Not in the 2010 and 2014 catalogues | same | same |
| level | NUTS 1 in the 2013 version, that is the eight former ZEAT of metropolitan France plus FR0 for the overseas departments: Île de France, Bassin Parisien, Nord-Pas-de-Calais, Est, Ouest, Sud-Ouest, Centre-Est, Méditerranée | "national coding" based on Länder, four groups, not NUTS 1: DENW (Lower Saxony, Schleswig-Holstein, Hamburg, Bremen), DEWW (North Rhine-Westphalia, Rhineland-Palatinate, Saarland), DEOS (the five eastern Länder and Berlin), DESW (Bavaria, Baden-Württemberg, Hesse) | NUTS 2 or adjusted NUTS 2: 20 regioni, IT1 to IT20, with Trentino-Alto Adige as one unit |
| number of cells | 9 | 4 | 20 |
| mean net sample per cell, 2021 | about 1,140 | about 1,030 | about 310 |
| match to the model's TL2 regions | no. The model uses the 13 current regions, the HFCS the 8 ZEAT. Regional statistics have to be aggregated to ZEAT, which needs a NUTS 2 to ZEAT key | no. 16 Länder against 4 groups. Länder statistics can be aggregated to the 4 groups by population | nearly. 21 TL2 units against 20, after merging Bolzano and Trento |
| degree of urbanisation | DHDEGURBA in the 2021 and 2023 catalogues, three classes. Not in the 2017 catalogue | same | same |
| source | C17 pp. 163-164, C21 pp. 165, 170-172, D23 pp. 24, 28-30 | same | same |

What this implies for the test of the model's regional prediction:

- **Italy is where the test can be run.** Twenty regions give a rank correlation with enough points, and Italy is the country where the model's hardship by region is wrong-signed (`E_PLACE_CONCEPT.md`, 2026-09-29 entry). With about 6,200 to 9,600 households in total, the smallest regions (Valle d'Aosta, Molise, Basilicata) will probably fall under 30 households and be suppressed, and many others will have wide intervals. The script also reports three macro-areas (North, Centre, South and Islands), which will be precise.
- **Germany cannot test a regional gradient.** Four groups of Länder allow an east against west contrast and nothing finer.
- **France allows a coarse test** on eight ZEAT, with large cells.
- **The catalogue states that DHREGION "is not available for all countries"** (C21 p. 172). FR, DE and IT codes are listed in it, which indicates the variable is delivered for them, but country-specific anonymisation can remove or coarsen variables (M21 p. 58). **TO CONFIRM ON ARRIVAL**, for both DHREGION and DHDEGURBA, per country and wave. The coverage table answers this in the first minute.
- **Region and urbanisation cannot be relied on jointly.** Italy's 20 regions times 3 classes gives 60 cells with about 100 households on average.
- **The weights are national.** The survey is designed for national representativeness and I found no statement that weights are calibrated to regional totals. Regional shares are therefore estimates for domains, with bootstrap standard errors that are valid but large, and without any guarantee that each region's sample reflects its population structure. This limitation should be stated in the paper.
- **The comparison series.** The official regional poverty rates the model is compared with are on disposable income. The HFCS gives gross income only, so HFCS income poverty by region is not the same concept. Liquid-asset poverty and hand-to-mouth shares by region have no official counterpart at all, which is the reason the HFCS is needed.

## 5. What each moment feeds, and what would confirm or reject the model

| moment (script name) | role in the model | a result that confirms | a result that rejects or forces a change |
|---|---|---|---|
| `htm_kvw_poor`, `htm_kvw_wealthy`, wave 2010 | replication of the current targets (FR 0.032 and 0.173, DE 0.074 and 0.248, IT 0.083 and 0.155) | `hfcs_benchmarks.csv` within about one point of KVW Table 5, baseline, weekly and monthly rows | a gap of several points, which would mean my reading of their wealth definitions (saving accounts, pensions in income) is wrong and must be fixed before anything else is used |
| the same, waves 2017 to 2023 | updated targets for chi0 and the impatient share | shares close to 2010 | large shifts, which would change the calibration targets |
| `htm_model_broad_*` against `htm_kvw_*` | whether the wealthy hand-to-mouth survive when saving accounts are liquid | wealthy share stays well above the poor share in Germany and Italy | the wealthy share collapses with broad liquid wealth. That would mean the German and Italian wealthy hand-to-mouth targets (0.248, 0.155), which the two-asset model cannot reach (0.13 and 0.06 in run 3), are partly an artefact of classification, and the calibration failure would be reassessed |
| `networth_to_income_ratio_of_medians`, 2021 | target for mean patience (4.02, 2.38, 5.51) | reproduces the published tables | a mismatch means a weight, implicate or variable error in the script |
| `liquid_*_to_income_*`, `dnnla_to_income_median_of_ratio` | first untargeted check (0.25, 0.30, 0.27 from Table F1) | one of the concepts reproduces Table F1, which settles what the model's liquid asset should be compared with | none reproduces it |
| `networth_gini`, `networth_top10_share` | validation (France model 0.650 and 0.46 in run 3) | data close to the model's values | model concentration far below the data in Germany and Italy |
| `asset_poor_oecd_*`, `hardship_oecd_*`, national | the model's hardship indicator | national hardship near the model's national economy value (0.20 for Italy) | far from it |
| the same, by `region` and `macro_region`, Italy | **the decisive test.** The model puts hardship highest in the North (Lombardy 0.56) and lowest in the South (about 0.19) | HFCS liquid-asset poverty also higher in the North than in the South. The model would then be right about liquid buffers, and the negative correlation with official poverty rates would reflect the difference between income poverty and asset poverty | HFCS asset poverty and hardship higher in the South, with intervals that exclude equality across macro-areas. The model's mechanism (low unemployment risk, hence low precautionary liquid saving) is then rejected as the driver of regional buffers, and regional wealth levels need pay, housing and inheritance by place |
| `htm_*`, `median_liquid_*` by `degurba` | the place layer's prediction that rural Germany has more asset poverty (0.47 against 0.18 in cities, one-asset model) | rural liquid buffers lower than urban ones in Germany | no gradient, or the reverse |
| `mpc_mean` by country | country-specific MPC targets. The model gives 0.11 against a survey value of 0.42 for France | none expected: the gap is known | the size of the gap by country is the input to the decision between a quarterly period and saving by rule |
| `mpc_mean` by `liquid_quintile` and `htm_status` | test of "MPC declining in liquid wealth" and of a higher MPC for the hand-to-mouth | MPC falls from the first to the fifth liquid quintile, and both hand-to-mouth groups are above the rest | a flat profile, as DFL find for net wealth. The model's central mechanism for the MPC would then lack support in this measure |
| `consumption_to_income_*` by group | gradient of the consumption share across education and labour status | a ratio that falls with education and is higher for the unemployed | the reverse |
| `share_any_illiquid`, `home_ownership_rate`, `share_with_mortgage`, `illiquid_to_liquid_*` | size of the illiquid asset. France at a fixed cost of 0.05 has "few households holding illiquid wealth" | the model's share with k > 0 near the data | the model far below the data |
| `hmr_acquired_last5y_share`, `share_refinanced_mortgage` | the adjustment frequency (the model's adjusting share is 9 percent a year at smoothing 0.01) | an annual rate of a few percent | the proxies cover housing only, so they bound the frequency from below and cannot reject on their own |
| `credit_constrained`, `credit_discouraged`, `has_overdraft_debt`, `share_liquid_kvw_negative` | the no-borrowing assumption (b_min = 0) and the constrained share | few households with negative net liquid wealth, and a constrained share of the same order as the poor hand-to-mouth share | a large share with overdraft or card debt, especially in Germany (22.5 percent hold revolving card debt in KVW Table 2), which would argue for the borrowing limit already raised in `TWO_ASSET_DESIGN.md` |

## 6. Day-one checklist and confidentiality rules

**Confidentiality rules** (AF, section 6 and the confidentiality commitment, section 9):

- The data are confidential and proprietary to the ECB. They may be used only for the project described in the application, never commercially.
- No duplication, transfer, disclosure or publication of the data to any third party without the ECB's express authorisation. Co-authors need their own approved application.
- No attempt to re-identify households, and no merging with other household-level databases for that purpose.
- Storage as declared in section 5 of the form: password-protected drive, restricted premises. In practice: an encrypted folder outside iCloud, Dropbox, the Obsidian vault and every git repository. Not on GitHub Actions, not on the second machine unless the application covers it, and never pasted into any online service or tool.
- Every publication cites "Eurosystem Household Finance and Consumption Survey" as the source and carries the sentence: "This paper uses data from the Eurosystem Household Finance and Consumption Survey. The results published and the related observations and analysis may not correspond to results or analysis of the data producers."
- A copy of each paper goes to hfcs.access@ecb.europa.eu.
- The data are destroyed when the project ends or after five years, whichever is earlier, unless access is renewed. A breach can cost up to 10,000 euros per case.
- **Minimum cell size.** The public form and commitment contain no numeric threshold for published cells. The 30-household rule in the script is a prudential default. **TO CONFIRM ON ARRIVAL** against the conditions sent with the data, and the constant `MIN_CELL` is one line.

**Checklist.**

1. Create `~/hfcs_secure` (or set `HFCS_DIR`) on an encrypted volume. Unzip each wave into its own sub-folder whose name contains the wave year (for instance `HFCS_UDB_2021`). Keep the ECB's file names.
2. Read the ECB's cover note and any README for file names, formats, the missing-value coding in csv and any output rule. Adjust `WAVE_DIR_TOKENS`, `FILE_PATTERNS`, `CSV_SEP` and `MIN_CELL` at the top of the script if needed.
3. Run `python3 hfcs_moments.py --selftest` to check the environment (pandas and numpy are the only dependencies. On this laptop `/usr/local/bin/python3` has them, the Homebrew `python3` does not).
4. Run `HFCS_DIR=~/hfcs_secure python3 hfcs_moments.py ~/hfcs_results --waves 2010 --nrep 50` first. It is quick and the 2010 wave has the KVW benchmarks.
5. Open `hfcs_coverage.csv`. Check that the required variables are present, which optional ones are absent (the log lists them), and whether `region` and `degurba` are filled for each country.
6. Open `hfcs_benchmarks.csv`. The KVW rows for 2010 should be within about a point. If not, flip `KVW_SAVING_ACCOUNTS_ILLIQUID` and `KVW_INCOME_INCLUDES_PUBLIC_PENSIONS` one at a time and rerun. KVW worked on the 2010 wave as released in 2013, and the files delivered now may have been revised since (I could not verify this from the public documents), so an exact match is not expected.
7. Run all waves with the default 200 replicate weights, then check the 2021 net wealth to income rows (4.02, 2.38, 5.51) and the 2017 MPC rows (0.418, 0.513, 0.481).
8. Only then read the by-place rows. Copy nothing but the three csv tables out of the secure environment.

The script writes three files and nothing else: `hfcs_moments.csv` (moment, country, wave, group_var, group, value, se, n_unweighted, n_implicates, n_replicates, suppressed, note), `hfcs_coverage.csv` and `hfcs_benchmarks.csv`. All writing goes through one function that refuses any other file name, any other set of columns, and any unsuppressed cell under the minimum size. There is no cache and no intermediate file.

## 7. Open questions that only the data can settle

1. File names, formats, case of variable names, and the missing-value coding in the csv files.
2. Whether HW0010 sits in the D file, the H file or both, and whether the W file is keyed by household only.
3. Whether DHREGION and DHDEGURBA are filled for FR, DE and IT in each of 2017, 2021 and 2023, and how many households each Italian region has.
4. Whether the KVW shares for 2010 are reproduced, which settles the treatment of saving accounts, public pensions in income, occupational pension accounts and home-purchase loans.
5. Whether the windfall question is filled for FR, DE and IT in 2021 and 2023, its column name (HIZ040A or HIZ0400A), and its non-response rate.
6. Whether HI0220 is filled for the three countries in each wave from 2014, and whether the derived consumption variables are monthly or annual in each wave.
7. Whether HNG0710 (taxes and social contributions) is delivered for Italy, which is the only route to net income.
8. Whether age is exact or bracketed per country, and which countries apply random rounding.
9. Which concept the ECB's Table F1 uses for liquid assets over income.
10. Whether credit card debt (DL1220) is filled for France after wave 1, and whether the credit-constraint block is filled for Italy after wave 1.
11. How much the French income concept (net of social contributions) moves the French hand-to-mouth threshold and the wealth to income ratio relative to Germany and Italy. This cannot be corrected inside the HFCS and should be stated as a limitation.
12. Whether the ECB sets a minimum cell size or other output rule in the access conditions.

## 8. Self-test

`python3 hfcs_moments.py --selftest` builds two synthetic waves with the HFCS column names (random numbers, four countries, 400 households each, five implicates, 25 replicate weights), writes 2017 as stacked csv files with upper-case names and 2021 as one Stata file per implicate with lower-case names, runs the whole pipeline on them in a temporary folder that is deleted afterwards, and checks the results against hand-computed and independently computed answers. Output of the run on 2026-10-02 (paths shortened):

```
SELF-TEST on synthetic data (no HFCS data is read)
  [PASS] weighted median, equal weights (2) and skewed weights (4)
  [PASS] Gini is 0 for equal holdings
  [PASS] Gini is 0.99 when one household of 100 holds everything
  [PASS] top 10% share is 0.19 for holdings 1..100 (91..100 over 5050 minus the p90 household)
  [PASS] Rubin: estimate 1.5, T = 0.01 + 1.5 * 0.5
  [PASS] KVW rule: zero kink, credit limit, poor and wealthy on six hand cases
  pipeline log (abridged):
    wave 2010: no folder found, skipped
    wave 2014: no folder found, skipped
    wave 2017: .../synthetic_hfcs/HFCS_UDB_2017_synthetic
    D: 1 file(s), 6000 rows, 38 columns used
    H: 1 file(s), 6000 rows, 8 columns used
    no HN file found (patterns: ^hn([1-5])?\.(csv|dta)$)
    W: 25 replicate weights for 1200 households
    FR 2017: variable 'taxes' (HNG0710) absent; variable 'age_rp_b' (DHAGEH1B) absent; variable 'degurba' (DHDEGURBA) absent
    FR 2017: 2040 cells, 376 suppressed
    DE 2017: 1615 cells, 249 suppressed
    IT 2017: 3230 cells, 1946 suppressed
    wave 2021: .../synthetic_hfcs/HFCS_UDB_2021_synthetic
    D: 5 file(s), 6000 rows, 39 columns used
    H: 5 file(s), 6000 rows, 8 columns used
    W: 25 replicate weights for 1200 households
    FR 2021: 2295 cells, 327 suppressed
    DE 2021: 1870 cells, 194 suppressed
    IT 2021: 3485 cells, 1887 suppressed
    wave 2023: no folder found, skipped
    written: .../out/hfcs_moments.csv (14535 rows)
    written: .../out/hfcs_coverage.csv (258 rows)
    written: .../out/hfcs_benchmarks.csv (36 rows)
  [PASS] three aggregate tables written and nothing else
  [PASS] both layouts load: 2017 stacked csv and 2021 per-implicate Stata, FR DE IT only
  [PASS] home ownership FR 2021: estimate and Rubin standard error match an independent computation
  [PASS] net wealth over income (ratio of medians) FR 2021 matches an independent computation
  [PASS] mean MPC FR 2021 (read from the H file under the alias HIZ040A) matches
  [PASS] region FR0 (12 households) is present and fully suppressed
  [PASS] no published cell has fewer than 30 households
  [PASS] degree of urbanisation: absent in 2017 (skipped), present in 2021
  [PASS] coverage table flags DHDEGURBA and taxes as absent in 2017
  [PASS] poor + wealthy = total hand-to-mouth in every published cell
  [PASS] MPC by liquid wealth quintile is computed (five quintiles) and declines by construction
  [PASS] standard errors are positive wherever a value is published
  [PASS] benchmark table is produced; synthetic waves have no 2010 or 2014, so those rows are empty
  [PASS] the writer refuses a household-level frame, an unknown file name and an unsuppressed small cell
  sample of the output (synthetic numbers, FR 2021, all households):
                                 moment  value     se  n_unweighted
                           htm_kvw_poor 0.0178 0.0124           290
                        htm_kvw_wealthy 0.1661 0.0406           290
                  htm_model_broad_total 0.0965 0.0331           400
                  hardship_oecd_persons 0.0647 0.0232           400
                               mpc_mean 0.4831 0.0301           388
                     credit_constrained 0.0741 0.0158           400
    networth_to_income_ratio_of_medians 6.9547 0.6305           400
                          networth_gini 0.4922 0.0166           400
  moments table: 14535 rows, 85 moments, 4979 suppressed cells
SELF-TEST PASSED: 20 of 20 checks
```

The numbers in the sample are synthetic and mean nothing. The run took seven seconds. The many suppressed Italian cells are the 20 synthetic regions with about 20 households each, which shows the rule working and is also a preview of the real constraint: a region needs at least 30 responding households to be published at all.

**What the self-test does not show.** It cannot detect a wrong variable name, a wrong file name or a misread definition, because the synthetic data are built from the same assumptions as the script. Those are covered by the coverage table and the benchmark table on day one.

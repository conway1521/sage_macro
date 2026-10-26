# Housing evidence for the two-asset model (FR, DE, IT)

Compiled 26 October 2026. Every number below was read from the source named in its row or computed by me from an official file, with the computation stated. One cross-check figure is second-hand and labelled as such. Status codes:

- **PDF/table read**: I read the number directly in the PDF, spreadsheet or official data file, at the location given.
- **Computed**: I computed it from an official dataset, procedure stated in the note.
- **Figure measured**: read from the vector geometry of a published chart (no numeric table exists), precision about 0.05 percentage points.
- **Not found**: no number given.
- **Second-hand**: quoted by another source, original not read (one row only, flagged).

Nothing is taken from an abstract only.

---

## 1. Housing returns (Jordà, Knoll, Kuvshinov, Schularick and Taylor 2019)

### 1a. Paper values (country tables)

The QJE typeset article (vol. 134(3), pp. 1225 to 1298) is behind the OUP paywall and I could not read it. The values below come from the working-paper version of the same paper, FRBSF Working Paper 2017-25 (December 2017), which I read in full. The QJE tables may differ slightly in the published version, so treat these as "working-paper Table 4 and Table 5" until checked against the journal PDF.

Arithmetic mean annual real returns, per cent. Real return defined as (1 + R)/(1 + π) minus 1 with CPI inflation (paper, eq. 2).

| Country | Period | Real housing total return | Real bills | Real bonds | Real equity | Source, location | Status |
|---|---|---|---|---|---|---|---|
| France | Full sample (1870 to 2015) | 6.54 | -0.47 | 1.54 | 3.25 | JKKST 2017 WP, Table 4 (bills, bonds) and Table 5 (equity, housing), "Full Sample" columns | PDF/table read |
| France | Post 1950 | 10.38 | 0.95 | 2.96 | 6.38 | same, "Post 1950" columns | PDF/table read |
| France | Post 1980 | 6.39 | 2.22 | 6.94 | 11.07 | same, "Post 1980" columns | PDF/table read |
| Germany | Full sample | 7.82 | 1.51 | 3.15 | 6.85 | same, "Full Sample" | PDF/table read |
| Germany | Post 1950 | 5.29 | 1.86 | 3.69 | 7.52 | same, "Post 1950" | PDF/table read |
| Germany | Post 1980 | 4.12 | 1.96 | 4.22 | 10.06 | same, "Post 1980" | PDF/table read |
| Italy | Full sample | 4.77 | 1.20 | 2.53 | 7.32 | same, "Full Sample" | PDF/table read |
| Italy | Post 1950 | 5.55 | 1.30 | 2.83 | 6.18 | same, "Post 1950" | PDF/table read |
| Italy | Post 1980 | 4.57 | 2.42 | 5.85 | 9.45 | same, "Post 1980" | PDF/table read |

The paper does not report a real rental yield and real capital gain split by country. Its only country split (working paper Table 7) is nominal and full sample, on the years where both equity and housing are observed:

| Country | Nominal housing capital gain | Nominal rental income | Nominal housing total return | Capital gain share | Obs. | Source, location | Status |
|---|---|---|---|---|---|---|---|
| France | 7.49 | 5.25 | 12.73 | 58.80% | 136 | JKKST 2017 WP, Table 7, "Housing" columns | PDF/table read |
| Germany | 3.50 | 6.03 | 9.52 | 36.73% | 111 | same | PDF/table read |
| Italy | 7.29 | 3.49 | 10.77 | 67.63% | 81 | same | PDF/table read |

### 1b. My computation from the public JST Macrohistory Database (Release 6)

File: `JSTdatasetR6.dta`, downloaded 26 October 2026 from https://www.macrohistory.net/app/download/9834512469/JSTdatasetR6.dta (SHA-256 b0ebb74a8d1b5b1bc9033fc46a6dcc578736afff8ce1e1086b7840f2649e79b3). R6 extends the RORE series to 2020 (Chen et al. 2022, JST R6 documentation).

Procedure (Python 3.11 with pandas, run with `-I` in a fresh scratch directory):
1. Keep FRA, DEU, ITA. Inflation π_t = cpi_t / cpi_{t-1} minus 1.
2. Real housing total return = (1 + `housing_tr`)/(1 + π) minus 1. Real capital gain = (1 + `housing_capgain`)/(1 + π) minus 1. Real bill = (1 + `bill_rate`)/(1 + π) minus 1.
3. Rental yield = `housing_rent_rtn` (rent over previous year's price, nominal ratio). I checked that `housing_tr` equals `housing_capgain` + `housing_rent_rtn` to within 3e-8 in every year. The deflated rent component is `housing_rent_rtn`/(1 + π), so real total = real capital gain + deflated rent component exactly.
4. Sample: years where `housing_tr`, `housing_capgain`, `housing_rent_rtn`, `bill_rate` and CPI inflation are all observed. Germany 1922 to 1923 dropped (hyperinflation, following the paper's exclusion rule). Premium = mean of (real housing minus real bill) over the same years.
5. Arithmetic means unless stated. Per cent per year.

| Country | Period (years used) | Real housing total return | Real capital gain | Rental yield (nominal ratio) | Rent component, deflated | Real bills | Housing minus bills | Status |
|---|---|---|---|---|---|---|---|---|
| France | 1871 to 2015 (138, gap 1915 to 1921) | 7.16 | 2.25 | 5.15 | 4.91 | -0.45 | 7.61 | Computed |
| France | 1950 to 2015 (66) | 9.71 | 4.86 | 5.09 | 4.86 | 0.99 | 8.72 | Computed |
| France | **1980 to 2015 (36)** | **5.84** | **1.92** | **4.05** | **3.92** | **2.30** | **3.54** | Computed |
| France | 1980 to 2020 (41) | 5.73 | 1.96 | 3.89 | 3.77 | 1.86 | 3.87 | Computed |
| Germany | 1871 to 2015 (111, gaps 1915 to 1924 and 1939 to 1962) | 7.81 | 1.85 | 6.03 | 5.96 | 2.64 | 5.17 | Computed |
| Germany | 1963 to 2015 (53, German housing series resumes only in 1963) | 5.28 | 1.17 | 4.21 | 4.11 | 1.69 | 3.59 | Computed |
| Germany | **1980 to 2015 (36)** | **4.11** | **-0.19** | **4.39** | **4.30** | **1.95** | **2.16** | Computed |
| Germany | 1980 to 2020 (41) | 4.76 | 0.51 | 4.33 | 4.25 | 1.53 | 3.23 | Computed |
| Italy | 1928 to 2015 (81, gap 1939 to 1945) | 4.77 | 1.45 | 3.49 | 3.31 | 1.37 | 3.39 | Computed |
| Italy | 1950 to 2015 (66) | 5.55 | 1.67 | 4.09 | 3.89 | 1.30 | 4.26 | Computed |
| Italy | **1980 to 2015 (36)** | **4.57** | **1.03** | **3.70** | **3.53** | **2.42** | **2.15** | Computed |
| Italy | 1980 to 2020 (41) | 4.45 | 0.85 | 3.76 | 3.60 | 2.03 | 2.42 | Computed |

Dispersion and geometric means, 1980 to 2015 (Computed, same sample):

| Country | SD real housing total | SD real capital gain | Geometric real housing total | Geometric real capital gain |
|---|---|---|---|---|
| France | 5.56 | 5.44 | 5.70 | 1.78 |
| Germany | 3.08 | 2.89 | 4.06 | -0.23 |
| Italy | 6.15 | 6.01 | 4.39 | 0.86 |

### Notes on item 1

- **Replication check.** For 1980 to 2015 my R6 numbers reproduce the paper's Post-1980 column for Germany (housing 4.11 vs 4.12, bills 1.95 vs 1.96, equity 10.04 vs 10.06) and Italy (housing, bills, bonds and equity identical to two decimals). For France they do not: R6 gives real housing 5.84 against 6.39 in the paper (post 1950: 9.71 against 10.38), and French equity also differs. French bills and bonds are close (2.30 vs 2.22). The French housing series has evidently been revised between the paper vintage and R6. I could not find the revision documented in the R6 RORE documentation, so I cannot say which vintage is better. Full-sample bill means for Germany and Italy also differ from the paper's Table 4, because Table 4 uses the years where bills and bonds are observed, whereas my rows restrict to years where housing is also observed (Italy housing starts in 1928, Germany has long housing gaps).
- **Net of what.** The JST rental yield is a *net* yield: benchmark rent-price ratios are net of maintenance, management costs, ground rent and other irrecoverable expenditure, and historical benchmarks are computed net of running costs and depreciation (WP Section 2.4 and footnote 5, Section 6.2 "Maintenance costs"). For Belgium one third of gross rent is assumed to go to running costs and depreciation, for Australia 2.2% of house value. The housing total return is therefore net of maintenance and depreciation, but **gross of taxes** (WP Section 6.3, "Taxes": the authors do not account for taxes) and **gross of transaction costs** (WP Section 6.3 estimates that round-trip costs of about 7.7% of value every ten years would lower annual housing returns by under one percentage point).
- **Capital gains** come from house price indices (Knoll, Schularick and Steger 2017). The rent-price approach assumes the indices track a representative portfolio, with no correction for changes in the housing stock (R6 documentation, footnote 7).
- **Mapping to the model.** In the model owners pay no rent and the asset's return is a capital gain accruing inside the asset. In JST terms the owner's return splits into the real capital gain (1980 to 2015: about -0.2% DE, 1.0% IT, 1.9% FR) plus an imputed net rent of about 3.5% to 4.3% of house value, which in the model is received in kind as housing services. Calibrating the in-asset return to the JST *total* return would double-count that service flow.
- **Bills.** `bill_rate` is a Treasury bill or money-market rate (R6 documentation, Table 1: France money market rate, Germany 3-month interbank, Italy government bill rate for 2016 to 2020).
- The 1980 to 2015 window spans the French 1998 to 2007 boom and the Italian post-2011 fall, so the country means are sensitive to the end year (compare the 1980 to 2020 rows).

---

## 2. Rent burden of tenants

Eurostat EU-SILC tables, retrieved through the Eurostat dissemination API on 26 October 2026 (tables last updated 20 October 2026). Values in per cent. Flag "b" = break in series.

**Important:** I found no Eurostat table that gives the *mean share of total housing costs in disposable income for tenants*. `ilc_mded01` exists but has no tenure breakdown (household type and poverty status only). I searched every table in the `ilc_mded` and `ilc_lvho` folders of the Eurostat catalogue. The closest official tenant measures are listed below.

### 2a. Share of rent in disposable household income (rent only, no utilities)

| Country | 2010 | 2015 | 2019 | 2022 | 2023 | 2024 | **2025** | Source, location | Status |
|---|---|---|---|---|---|---|---|---|---|
| France | 22.4 | 22.6 | 23.1 | 23.7 b | 22.7 | 22.5 | **22.5** | Eurostat `ilc_mded02`, hhcomp=TOTAL, rskpovth=TOTAL | PDF/table read (API) |
| Germany | 21.1 | 22.4 | 20.6 | 20.0 | 19.9 | 19.9 | **20.0** | same (2020 = 19.1 b) | PDF/table read (API) |
| Italy | 22.9 | 25.0 | 25.6 | 23.1 | 20.4 | 20.2 | **20.5** | same | PDF/table read (API) |
| EU27 | 23.1 e | 24.5 e | 23.7 | 23.2 | 22.5 | 22.3 | 22.5 | same | PDF/table read (API) |

### 2b. OECD median rent burden of tenants (rent only), market and subsidised tenants pooled

| Country | 2010 | 2015 | 2019 | 2022 | 2023 | **2024** | Source, location | Status |
|---|---|---|---|---|---|---|---|---|
| France | 21.1 | 22.2 | 22.3 | 22.8 | 22.1 | **21.8** | OECD Affordable Housing Database, HC1.2, sheet HC12_A1, row "Rent (private and subsidized)" | PDF/table read (xlsx) |
| Germany | 21.3 | 20.9 | 19.1 | 18.5 | 18.2 | **18.4** | same | PDF/table read (xlsx) |
| Italy | 19.1 | 21.7 | 21.7 | 20.9 | 19.0 | **18.4** | same | PDF/table read (xlsx) |

Same workbook, sheet HC12_2 Panel A, median rent burden by income quintile, 2024: France 29.2 (bottom) and 18.7 (third), Germany 27.8 and 15.5, Italy 28.4 and 16.7 (PDF/table read).

### 2c. Total housing costs (incl. utilities) of tenants: overburden rate and distribution

| Country | Tenure | Overburden rate (>40%), 2019 | 2023 | 2024 | **2025** | Share with housing costs >25% of income, 2025 | Source, location | Status |
|---|---|---|---|---|---|---|---|---|
| France | Market-price tenants | 17.7 | 19.3 | 20.2 | **18.7** | 57.8 | `ilc_lvho07c` (overburden), `ilc_lvho28` percent=PC_GT25 | PDF/table read (API) |
| France | Reduced-price or free | 10.4 | 11.7 | 12.2 | **10.7** | 41.5 | same | PDF/table read (API) |
| Germany | Market-price tenants | 18.3 | 14.9 | 13.8 | **13.2** | 41.3 | same (2020 = 12.3 b) | PDF/table read (API) |
| Germany | Reduced-price or free | 17.6 | 9.2 | 8.8 | **9.2** | 21.7 | same | PDF/table read (API) |
| Italy | Market-price tenants | 29.2 | 21.9 | 19.4 | **22.3** | 52.9 | same | PDF/table read (API) |
| Italy | Reduced-price or free | 9.6 | 5.5 | 4.8 | **6.0** | 16.1 | same | PDF/table read (API) |

All households, mean share of total housing costs in disposable income (`ilc_mded01`, not tenant-specific), 2025: France 18.5, Germany 24.1, Italy 14.1 (PDF/table read).

OECD rent-only overburden (rent > 40% of income), total population, 2024 or latest year, private-market tenants: France 10.4, Germany 5.1, Italy 6.9 (HC1.2, sheet HC12_3 Panel B, PDF/table read).

### Notes on item 2

- **Utilities.** EU-SILC "total housing cost" (variable HH070) includes utilities (water, electricity, gas, heating), structural insurance, mandatory services and charges, regular maintenance and repairs and taxes, plus rent for tenants or mortgage interest for owners (Eurostat Statistics Explained, glossary entry "Housing cost overburden rate" and the EU-SILC methodology page "economic strain linked to dwelling"). So `ilc_lvho07c`, `ilc_lvho28` and `ilc_mded01` are *not* pure rent. `ilc_mded02` and OECD HC1.2 (narrow definition) *are* rent only: Eurostat states that utilities paid with the rent are excluded from HH060, and OECD's narrow definition covers rent and mortgage payments only.
- **Housing allowances.** The overburden rate deducts housing allowances from both costs and income (glossary definition). The methodology page says HH070 itself is recorded gross of housing benefits. Whether `ilc_mded01` and `ilc_mded02` deduct allowances is not stated explicitly on the pages I read. OECD HC1.2 uses disposable income including housing allowances and rent before allowances. For France, where housing allowances (APL) are large, this matters for the level.
- **Population of `ilc_mded02`.** Eurostat defines it as the weighted mean of HH060 (current rent for the principal residence) over HY020 (disposable household income), and drops households with missing HH060. I infer, but the page does not say in so many words, that it is computed over rent-paying households, pooling market-price and reduced-price tenants. It is a mean, whereas OECD HC1.2 is a median, which explains part of the gap between 2a and 2b.
- **Market versus reduced rent.** I found no official mean or median rent share split by market-price versus reduced-price tenants. The split is available only for the overburden rate and the >25% distribution (2c). Those show that market tenants carry a markedly higher burden than reduced-rent tenants in all three countries.
- **Breaks.** Germany has a flagged break in 2020, so pre-2020 German values are not comparable with later ones. France has a break in 2020 and 2022 and no 2021 observation in several tables. OECD notes that German data before and after 2015 refer to different sources.

---

## 3. Home-ownership rate (cross-check)

Share of the population (persons, not households) living in owner-occupied dwellings.

| Country | 2015 | 2023 | 2024 | **2025** | Of which with mortgage (2025) | Of which outright (2025) | Source, location | Status |
|---|---|---|---|---|---|---|---|---|
| France | 64.1 | 63.1 | 61.2 | **61.4** | 30.8 | 30.5 | Eurostat `ilc_lvho02`, tenure=OWN, hhcomp=TOTAL, rskpovth=TOTAL | PDF/table read (API) |
| Germany | 51.9 | 47.6 | 47.2 | **47.2** | 24.0 | 23.3 | same | PDF/table read (API) |
| Italy | 72.9 | 75.2 | 75.9 | **77.1** | 17.3 | 59.9 | same | PDF/table read (API) |
| EU27 | 70.2 e | 69.1 | 68.4 | 68.5 | 24.8 | 43.7 | same | PDF/table read (API) |

Tenants, 2025: France 38.6 (market 16.4, reduced or free 22.2), Germany 52.8 (market 46.8, reduced or free 6.0), Italy 22.9 (market 13.6, reduced or free 9.3).

### Notes on item 3

- Eurostat shares are of *persons*. HFCS ownership is usually reported per *household*, and owner households are larger on average, so the person-based Eurostat rate should sit a little above a household-based rate.
- Germany's 2024 and 2025 values are identical on every tenure line, which may reflect a carried-forward estimate. I did not verify this.
- Italy's split between mortgage and outright owners jumps between 2024 and 2025 (12.7 to 17.3 with mortgage) without a break flag, so use the total.

---

## 4. Transaction costs of buying and selling a home

| Country | Buyer | Seller | Total round trip | Year | Source, location | Status |
|---|---|---|---|---|---|---|
| France | 10.65 | 3.49 | 14.14 | 2009 | Andrews, Caldera Sánchez and Johansson (2011), OECD ECO WP 836, Figure 27 Panel A, p. 61 | Figure measured |
| Germany | 6.70 | 1.12 | 7.82 | 2009 | same | Figure measured |
| Italy | 8.50 | 3.49 | 12.00 | 2009 | same | Figure measured |
| Cross-check, 13-country average round trip | n/a | n/a | about 7.7 | n/a | Cited by JKKST 2017 WP, Section 6.3, as OECD (2012). I did not read OECD (2012) itself | Second-hand |

Values in per cent of property value.

### Notes on item 4

- **How measured.** Figure 27 has no accompanying numeric table. The PDF figure is vector graphics, so I extracted each bar's rectangle coordinates and converted heights using the chart's gridlines (0 to 20 per cent, 8.87 points per percentage point). The read values land on round numbers (for instance seller costs of 3.49 and 1.12), which suggests the measurement error is about 0.05 points. Panel B of the same figure splits buyer costs by type (notary, agent, legal, registration fees, transfer taxes), but its hatched patterns cannot be measured reliably, so I give no split.
- **Construction.** The figure is based on the OECD Housing Market Questionnaire, 2009. Costs are averages as a share of property value and cover transfer taxes (for instance stamp duties), registration fees, notarial and other legal fees, and typical estate agency fees (Box 7, p. 62). Flat fees are converted to a percentage using an assumed average house price. Transfer taxes and registration fees make up about half of costs on average (footnote 41).
- **Caveats stated by the authors.** The figure ignores tax breaks for certain dwellings, so it may overstate costs in some countries, "in particular in Italy" (Figure 27, note 1). The authors also say incidence probably falls on buyers in practice, whatever the legal split (footnote 41).
- **Vintage.** These are 2009 values. Property transfer tax rates in France and Germany have been changed since 2009 (German Länder set their own rates). I did not find an official cross-country update with all three countries, so I give no current figure.
- **For a model.** The buyer plus seller total is the relevant one-off cost of a round trip. If agents in the model move rarely, the annualised cost is small (JKKST's illustration: 7.7% every ten years is about 0.77 points per year).

---

## References

Andrews, D., Caldera Sánchez, A. and Johansson, Å. (2011). Housing markets and structural policies in OECD countries. *OECD Economics Department Working Papers*, No. 836. OECD Publishing, Paris. https://doi.org/10.1787/5kgk8t2k9vf3-en

Chen, X., Elsherbiny, S., Duque Gabriel, R., Jordà, Ò., Kim, C. H., Schularick, M. and Taylor, A. M. (2022). Documentation on the JST Database Update 2016 to 2020 (Release 6). Macrofinance and Macrohistory Lab, University of Bonn. https://www.macrohistory.net/database/

Eurostat (2026a). Share of housing costs in disposable household income, by type of household and income group [ilc_mded01]. EU-SILC. https://doi.org/10.2908/ILC_MDED01 (accessed 26 October 2026, data updated 20 October 2026).

Eurostat (2026b). Share of rent related to occupied dwelling in disposable household income, by type of household and income group [ilc_mded02]. EU-SILC. https://doi.org/10.2908/ILC_MDED02 (accessed 26 October 2026).

Eurostat (2026c). Housing cost overburden rate by tenure status [ilc_lvho07c]. EU-SILC. https://doi.org/10.2908/ILC_LVHO07C (accessed 26 October 2026).

Eurostat (2026d). Distribution of population by housing cost burden and tenure status [ilc_lvho28]. EU-SILC. https://doi.org/10.2908/ILC_LVHO28 (accessed 26 October 2026).

Eurostat (2026e). Distribution of population by tenure status, type of household and income group [ilc_lvho02]. EU-SILC. https://doi.org/10.2908/ILC_LVHO02 (accessed 26 October 2026).

Eurostat (n.d.). Glossary: Housing cost overburden rate. Statistics Explained. https://ec.europa.eu/eurostat/statistics-explained/index.php?title=Glossary:Housing_cost_overburden_rate (accessed 26 October 2026).

Eurostat (n.d.). EU statistics on income and living conditions (EU-SILC) methodology: economic strain linked to dwelling. Statistics Explained. (accessed 26 October 2026).

Jordà, Ò., Knoll, K., Kuvshinov, D., Schularick, M. and Taylor, A. M. (2017). The rate of return on everything, 1870 to 2015. *Federal Reserve Bank of San Francisco Working Paper* 2017-25. https://doi.org/10.24148/wp2017-25

Jordà, Ò., Knoll, K., Kuvshinov, D., Schularick, M. and Taylor, A. M. (2019). The rate of return on everything, 1870 to 2015. *Quarterly Journal of Economics*, 134(3), 1225 to 1298. https://doi.org/10.1093/qje/qjz012

Jordà, Ò., Schularick, M. and Taylor, A. M. (2017). Macrofinancial history and the new business cycle facts. *NBER Macroeconomics Annual 2016*, 31, 213 to 263. (Citation for the JST Macrohistory Database, Release 6, file JSTdatasetR6.dta. Volume and pages from memory, not checked in this session.)

Knoll, K., Schularick, M. and Steger, T. (2017). No price like home: global house prices, 1870 to 2012. *American Economic Review*, 107(2), 331 to 353. (Cited inside JKKST 2017 for the price indices. Volume and pages from memory, not checked in this session.)

OECD (2025). OECD Affordable Housing Database, indicator HC1.2: Housing costs over income. OECD, Paris. https://oe.cd/ahd (workbook HC1-2-Housing-costs-over-income.xlsx, accessed 26 October 2026).

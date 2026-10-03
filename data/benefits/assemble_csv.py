"""Assemble floor_and_replacement.csv: recommended values first, then the statutory rules read at source
(typed here with the page and the date consulted), then every series computed by build_floor_and_replacement.py.

    python3 build_floor_and_replacement.py && python3 assemble_csv.py
"""
import csv, os

HERE = os.path.dirname(os.path.abspath(__file__))
COLS = ["indicator", "country", "value", "unit", "year", "family_type", "source", "url", "status"]
comp = list(csv.DictReader(open(os.path.join(HERE, "computed_series.csv"))))


def pick(indicator, country, year, family):
    got = [r for r in comp if r["indicator"] == indicator and r["country"] == country and r["year"] == str(year) and r["family_type"] == family]
    if len(got) != 1:
        raise ValueError(f"expected one row for {indicator} {country} {year} {family}, got {len(got)}")
    return got[0]


SP = "https://www.service-public.gouv.fr/particuliers/vosdroits/"
OECD_FR = "https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/income-support-redistribution-and-work-incentives/TaxBEN-France-latest.pdf"
OECD_DE = "https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/income-support-redistribution-and-work-incentives/TaxBEN-Germany-latest.pdf"
OECD_IT = "https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/income-support-redistribution-and-work-incentives/TaxBEN-Italy-latest.pdf"
MISSOC = "https://www.missoc.org/?p=86&countries_ids=9,10,14&topics_ids=69888,69889,69890,70001,69891,69892,69893,69894,69895,69896,69897,69898,69899,69900,69901,69902,69903,69904,69905,69906&format=HTML&year_id=1067&period=2026-01-01"
SGB12 = "https://www.gesetze-im-internet.de/sgb_2/__12.html"
BMAS = "https://www.bmas.de/DE/Arbeit/Grundsicherung-Buergergeld/Leistungen-und-Bedarfe-im-Buergergeld/einkommen-und-vermoegen.html"
BMAS23 = "https://www.bmas.de/DE/Service/Presse/Pressemitteilungen/2022/das-aendert-sich-2023.html"
BT1005 = "https://dserver.bundestag.de/btd/21/010/2101005.pdf"
BT1069 = "https://dserver.bundestag.de/btd/21/010/2101069.pdf"
LAV = "https://lavoro.gov.it/adi/comunicazione/news/adi-e-sfl-cosa-cambia-con-la-legge-di-bilancio"
CAM = "https://temi.camera.it/leg19/temi/il-reddito-di-cittadinanza.html"
V = "verified at source 2026-10-02"

S = [  # indicator, country, value, unit, year, family_type, source, url, status
    # ---- France
    ("rsa_montant_forfaitaire", "FR", 635.71, "EUR per month", 2025, "single, no children", "OECD TaxBEN policy description France 2025, section 3.1, RSA base amounts as of 1 January 2025", OECD_FR, V),
    ("rsa_montant_forfaitaire", "FR", 953.56, "EUR per month", 2025, "couple, no children", "OECD TaxBEN policy description France 2025, section 3.1, RSA base amounts as of 1 January 2025", OECD_FR, V),
    ("rsa_montant_forfaitaire", "FR", 646.52, "EUR per month", 2026, "single, no children", "MISSOC comparative tables, 1 January 2026, table XI, Minimum income level", MISSOC, V),
    ("rsa_montant_forfaitaire", "FR", 651.69, "EUR per month", 2026, "single, no children", "service-public.gouv.fr F19778 (page verified 1 April 2026), amount in force from April 2026", SP + "F19778", V),
    ("rsa_montant_forfaitaire", "FR", 977.54, "EUR per month", 2026, "couple, no children", "service-public.gouv.fr F19778 (page verified 1 April 2026)", SP + "F19778", V),
    ("rsa_forfait_logement", "FR", 78.20, "EUR per month deducted when housing benefit is received", 2026, "one person", "service-public.gouv.fr F19778 (page verified 1 April 2026)", SP + "F19778", V),
    ("rsa_forfait_logement", "FR", 156.41, "EUR per month deducted when housing benefit is received", 2026, "two persons", "service-public.gouv.fr F19778 (page verified 1 April 2026)", SP + "F19778", V),
    ("rsa_prime_de_noel", "FR", 152.45, "EUR per year", 2024, "single, no children", "OECD TaxBEN policy description France 2025, section 3.1.2 (December 2024 bonus)", OECD_FR, V),
    ("rsa_prime_de_noel", "FR", 228.68, "EUR per year", 2024, "couple, no children", "OECD TaxBEN policy description France 2025, section 3.1.2 (December 2024 bonus)", OECD_FR, V),
    ("min_income_asset_test", "FR", "none", "asset ceiling", 2026, "all", "RSA has no asset ceiling. Assets that yield no income are deemed to yield 3% a year; Livret A counts for its actual interest; current accounts are not counted (service-public.gouv.fr F24585, page verified 1 July 2026). OECD: 'There is no asset test carried out when assessing RSA applications'", SP + "F24585", V),
    ("min_income_asset_imputed_return", "FR", 0.03, "annual imputed income as a share of assets that yield no income", 2026, "all", "service-public.gouv.fr F24585 (page verified 1 July 2026)", SP + "F24585", V),
    ("min_income_age_condition", "FR", 25, "minimum age in years", 2026, "all", "service-public.gouv.fr F19778", SP + "F19778", V),
    ("ui_max_duration_statutory", "FR", 548, "calendar days (about 18 months), under age 53, contract ended after 1 February 2023", 2026, "all", "service-public.gouv.fr F14860 (page verified 23 July 2026). The TaxBEN profile pays the insurance benefit for 24 months (730 days)", SP + "F14860", V),
    ("taxben_rent_assumption", "FR", 764, "EUR per month (20% of the average wage)", 2025, "all", "OECD TaxBEN policy description France 2025, note to Figure 4", OECD_FR, V),
    # ---- Germany
    ("buergergeld_regelbedarf", "DE", 502, "EUR per month", 2023, "single, no children", "BMAS press release 'Das ändert sich im neuen Jahr' (2022); equals TaxBEN 6,024/12", BMAS23, V),
    ("buergergeld_regelbedarf", "DE", 451, "EUR per month per partner", 2023, "couple, no children", "BMAS press release 'Das ändert sich im neuen Jahr' (2022); equals TaxBEN 10,824/24", BMAS23, V),
    ("buergergeld_regelbedarf", "DE", 563, "EUR per month", 2024, "single, no children", "MISSOC comparative tables, 1 January 2026, table XI ('Since 01 January 2024'); OECD TaxBEN policy description Germany 2025, section 2.2; unchanged in 2025 and at 1 January 2026", MISSOC, V),
    ("buergergeld_regelbedarf", "DE", 506, "EUR per month per partner", 2024, "couple, no children", "MISSOC comparative tables, 1 January 2026, table XI; OECD TaxBEN policy description Germany 2025, section 2.2; unchanged in 2025 and at 1 January 2026", MISSOC, V),
    ("housing_cost_recognised_taxben", "DE", 495.50, "EUR per month (426 rent ceiling plus 69.50 heating, Berlin, January 2025)", 2025, "one-person household", "OECD TaxBEN policy description Germany 2025, section 3.2.3 ('These rates are applied in TaxBEN')", OECD_DE, V),
    ("housing_cost_recognised_taxben", "DE", 605.80, "EUR per month (515.45 rent ceiling plus 90.35 heating, Berlin, January 2025)", 2025, "two-person household", "OECD TaxBEN policy description Germany 2025, section 3.2.3", OECD_DE, V),
    ("housing_cost_recognised_national_average", "DE", 442.17, "EUR per month, running recognised cost of accommodation and heating", 2024, "one-person benefit unit, renting", "Bundestag Drucksache 21/1005 (31 July 2025), Tabelle 4, row Deutschland, column 13 (Statistik der Bundesagentur für Arbeit)", BT1005, V),
    ("housing_cost_actual_national_average", "DE", 453.76, "EUR per month, running actual cost of accommodation and heating", 2024, "one-person benefit unit, renting", "Bundestag Drucksache 21/1005 (31 July 2025), Tabelle 4, row Deutschland, column 9", BT1005, V),
    ("buergergeld_average_payment_entitlement", "DE", 1029, "EUR per month", 2024, "one-person benefit unit", "Bundestag Drucksache 21/1069 (28 July 2025), answer to question 3; composition of the amount not checked", BT1069, V),
    ("min_income_floor_national_housing", "DE", round(12 * (563 + 442.17), 2), "EUR per year (12 x (563 + 442.17))", 2024, "single, no children, jobless, with national average recognised housing cost", "standard rate (MISSOC) plus Bundestag Drucksache 21/1005 Tabelle 4", BT1005, "computed from verified figures"),
    ("min_income_asset_exemption", "DE", 40000, "EUR, first person, during the first year of receipt (Karenzzeit); 15,000 for each further person", "2023 to June 2026", "benefit unit", "BMAS, Einkommen und Vermögen; OECD TaxBEN policy description Germany 2025, section 2.2 (asset test); MISSOC table XI", BMAS, V),
    ("min_income_asset_exemption", "DE", 15000, "EUR per person after the first year of receipt", "2023 to June 2026", "benefit unit", "BMAS, Einkommen und Vermögen; OECD TaxBEN policy description Germany 2025; MISSOC table XI", BMAS, V),
    ("min_income_asset_exemption", "DE", 5000, "EUR per person up to age 30 (10,000 from 31, 12,500 from 41, 20,000 from 51); no grace period for assets", "from July 2026", "benefit unit", "§ 12 Abs. 2 SGB II, consolidated text consulted 2 October 2026; the code's header notes the act of 16 April 2026 with effect from 1 July 2026 (benefit renamed Grundsicherungsgeld)", SGB12, V + "; the commencement date of § 12 itself is taken from the header note of the code"),
    ("min_income_asset_exempt_items", "DE", "home, car, pensions", "owner-occupied house up to 140 m2 or flat up to 130 m2, one appropriate car per employable person, pension contracts", 2026, "benefit unit", "§ 12 Abs. 1 SGB II, consolidated text consulted 2 October 2026", SGB12, V),
    # ---- Italy
    ("adi_eligibility", "IT", "restricted", "household must include a minor, a person aged 60 or more, a disabled person or a disadvantaged member", 2025, "all", "OECD TaxBEN policy description Italy 2025, section 3.1.1; MISSOC table XI, Persons covered", OECD_IT, V),
    ("adi_income_supplement_max", "IT", 6500, "EUR per year times the equivalence scale (6,000 in 2024)", 2025, "household", "Ministero del Lavoro, 'ADI e SFL: cosa cambia con la Legge di Bilancio' (Legge 30 dicembre 2024, n. 207); OECD TaxBEN policy description Italy 2025, section 3.1.3", LAV, V),
    ("adi_rent_supplement_max", "IT", 3640, "EUR per year (3,360 in 2024)", 2025, "household renting", "Ministero del Lavoro, 'ADI e SFL: cosa cambia con la Legge di Bilancio'; OECD TaxBEN policy description Italy 2025", LAV, V),
    ("adi_isee_threshold", "IT", 10140, "EUR (9,360 in 2024)", 2025, "household", "Ministero del Lavoro, 'ADI e SFL: cosa cambia con la Legge di Bilancio'", LAV, V),
    ("adi_equivalence_scale", "IT", "1 + increments", "1 for the first member; +0.50 disabled; +0.40 aged 60 or more; +0.40 one adult with intense care duties; +0.30 disadvantaged; +0.15 each minor up to the second, +0.10 after; cap 2.2 (2.3)", 2025, "household", "OECD TaxBEN policy description Italy 2025, section 3.1.3", OECD_IT, V),
    ("min_income_asset_exemption", "IT", 6000, "EUR of financial assets for one member; +2,000 per further member up to 10,000; +1,000 per child after the second; +5,000 per disabled member (7,500 severe)", 2025, "household", "OECD TaxBEN policy description Italy 2025, section 3.1 (asset test); MISSOC table XI, Property and other assets", OECD_IT, V),
    ("min_income_asset_exemption_real_estate", "IT", 30000, "EUR of real estate other than the main home; the main home counts only above an IMU value of 150,000", 2025, "household", "OECD TaxBEN policy description Italy 2025, section 3.1 (asset test); MISSOC table XI", OECD_IT, V),
    ("adi_duration", "IT", 18, "months, renewable for 12 months at a time", 2026, "household", "MISSOC comparative tables, 1 January 2026, table XI, Duration and time limits", MISSOC, V),
    ("sfl_amount", "IT", 500, "EUR per month per participant (350 before 2025), paid only while attending a training or activation programme", 2025, "adult aged 18 to 59 able to work", "Ministero del Lavoro, 'ADI e SFL: cosa cambia con la Legge di Bilancio'; OECD TaxBEN policy description Italy 2025, section 3.2 (not included in TaxBEN)", LAV, V),
    ("sfl_duration", "IT", 12, "months, extendable by at most 12", 2025, "adult aged 18 to 59 able to work", "OECD TaxBEN policy description Italy 2025, section 3.2.3; MISSOC table XI", OECD_IT, V),
    ("rdc_max_duration_2023", "IT", 7, "monthly payments in 2023, except households with a minor, a disabled person or a person aged 60 or more", 2023, "household", "Camera dei deputati, 'La riforma del Reddito di cittadinanza' (Legge di Bilancio 2023, legge 197/2022)", CAM, V),
    ("taxben_asset_test_assumption", "IT", "passed", "OECD note: the standard TaxBEN calculations assume households always pass the asset test", 2025, "all", "OECD TaxBEN policy description Italy 2025, section 3.1 (asset test)", OECD_IT, V),
    # ---- other
    ("unemployed_men_living_in_couple_share", "FR", 0.56, "share of unemployed men who live in a couple", 2011, "men", "Biausque and Govillot (2012), Les couples sur le marché du travail, INSEE, France portrait social (enquête Emploi 2011)", "https://www.insee.fr/fr/statistiques/fichier/1374049/FPORSOC12k_D2_couple.pdf", V),
    ("unemployed_by_household_type_direct", "FR/DE/IT", "not found", "share of the unemployed by household type", "", "", "No Eurostat table crosses ILO unemployment with household composition (lfst_hhindws has employed and not employed only)", "https://ec.europa.eu/eurostat/api/dissemination/catalogue/toc/txt?lang=en", "UNVERIFIED: not published; proxy used"),
]

REC = []
FAM_F = "single, no children, jobless, {}"
for c in ("FR", "DE", "IT"):
    for y in (2023, 2025):
        for hb in ("with housing benefit", "without housing benefit"):
            for ind in ("min_income_share_gross_AW", "min_income_share_net_AW", "min_income_pct_median_disposable", "min_income_net_annual"):
                r = dict(pick(ind, c, y, FAM_F.format(hb)))
                r["status"] = "RECOMMENDED floor input (" + ("baseline" if hb.startswith("with ") else "variant without housing") + "); " + r["status"]
                REC.append(r)
    for y in (2023, 2025):
        fam = "three childless types; previous earnings 100% AW; social assistance yes; housing benefit no"
        r = dict(pick("nrr_household_weighted", c, y, fam)); r["status"] = "RECOMMENDED household-weighted replacement rate; " + r["status"]; REC.append(r)
        for fam in ("three childless types; previous earnings 67% AW; social assistance yes; housing benefit no",
                    "six household classes; previous earnings 100% AW; social assistance yes; housing benefit no"):
            r = dict(pick("nrr_household_weighted", c, y, fam)); r["status"] = "sensitivity to the recommended rate; " + r["status"]; REC.append(r)

with open(os.path.join(HERE, "floor_and_replacement.csv"), "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=COLS, lineterminator="\n")
    w.writeheader()
    w.writerows(REC)
    for row in S:
        w.writerow(dict(zip(COLS, row)))
    w.writerows(comp)
print("recommended", len(REC), "statutory", len(S), "computed", len(comp))

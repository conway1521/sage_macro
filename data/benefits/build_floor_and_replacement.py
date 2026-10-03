"""Consumption floor and replacement rates by family type for FR, DE, IT.

Python standard library only. Pulls the official series, caches them in raw/,
and writes computed_series.csv (every number derived here) next to this file.
floor_and_replacement.csv is assembled by assemble_csv.py from computed_series.csv
plus the hand-verified statutory rows in statutory_rows.csv.

    python3 build_floor_and_replacement.py           # use raw/ cache if present
    python3 build_floor_and_replacement.py --fresh   # download again

Queries (saved here so the pull can be repeated):
  OECD SDMX, https://sdmx.oecd.org/public/rest/data/<flow>/<key>?startPeriod=..&endPeriod=..
    NRR  OECD.ELS.JAI,DSD_TAXBEN_NRR@DF_NRR,1.0   key FRA+DEU+ITA..........   2022-2025
         dimensions: REF_AREA.MEASURE.UNIT_MEASURE.HOUSEHOLD_TYPE.AGE_CHILDREN.INCOME_PREV.
                     INCOME_PART.UNEMP_DURATION.SOC_ASS_BENEFIT.HOUSE_BENEFIT.FREQ
    IA   OECD.ELS.JAI,DSD_TAXBEN_IA@DF_IA,1.0     key FRA+DEU+ITA.......      2015-2025
         (adequacy of minimum income benefits: measure GMINISJF, units XDC and
          PT_INC_DISP_HH_MEDIAN)
    TW   OECD.CTP.TPS,DSD_TAX_WAGES_COMP@DF_TW_COMP,  key FRA+DEU+ITA.......   2022-2025
         (Taxing Wages: GEBT = gross earnings = the average wage; NIAT = net income)
  Eurostat, https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/<code>?geo=FR&geo=DE&geo=IT&time=..
    lfst_hhindws  persons by household composition and labour status
    lfst_hhwhnpt  persons by labour status within households and household composition
    lfsa_ugadra   unemployed by duration and registration/benefit receipt (percent)
    lfsa_ugad     unemployed by duration (thousand)

The spell average is the model's formula (data/build_country_table.py in the repo):
    s = ltu^(1/12);  rr = sum_{m=1..60} NRR_m s^(m-1) (1-s) + NRR_60 s^60
with ltu the 2023 share of the unemployed out of work a year or more
(OECD DF_DUR_I: FR 0.24545, DE 0.31093, IT 0.56024, the values in the repo's country table).
"""
import csv, io, json, os, sys, time, urllib.error, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
os.makedirs(RAW, exist_ok=True)
FRESH = "--fresh" in sys.argv
ISO = {"FRA": "FR", "DEU": "DE", "ITA": "IT"}
C3 = ["FRA", "DEU", "ITA"]
LTU = {"FR": 0.245450, "DE": 0.310930, "IT": 0.560240}   # OECD DF_DUR_I 2023, repo country table
UA = "Mozilla/5.0 (sage_macro build script)"

OECD_Q = {
    "nrr": ("OECD.ELS.JAI,DSD_TAXBEN_NRR@DF_NRR,1.0", "FRA+DEU+ITA..........", 2022, 2025),
    "ia": ("OECD.ELS.JAI,DSD_TAXBEN_IA@DF_IA,1.0", "FRA+DEU+ITA.......", 2015, 2025),
    "tw": ("OECD.CTP.TPS,DSD_TAX_WAGES_COMP@DF_TW_COMP,", "FRA+DEU+ITA.......", 2022, 2025),
}
EUROSTAT_Q = {
    "lfst_hhindws": "geo=FR&geo=DE&geo=IT&time=2023&time=2024&time=2025",
    "lfst_hhwhnpt": "geo=FR&geo=DE&geo=IT&time=2023&time=2024&time=2025",
    "lfsa_ugadra": "geo=FR&geo=DE&geo=IT&time=2023&time=2024&time=2025",
    "lfsa_ugad": "geo=FR&geo=DE&geo=IT&time=2023&time=2024&time=2025&sex=T",
}


def oecd_url(name):
    flow, key, a, b = OECD_Q[name]
    return f"https://sdmx.oecd.org/public/rest/data/{flow}/{key}?startPeriod={a}&endPeriod={b}"


def eurostat_url(ds):
    return f"https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/{ds}?{EUROSTAT_Q[ds]}"


def fetch(url, path, accept=None):
    if os.path.exists(path) and not FRESH:
        return open(path, encoding="utf-8-sig").read()
    hdr = {"User-Agent": UA}
    if accept:
        hdr["Accept"] = accept
    for attempt in range(6):
        try:
            raw = urllib.request.urlopen(urllib.request.Request(url, headers=hdr), timeout=300).read().decode("utf-8-sig")
            open(path, "w", encoding="utf-8").write(raw)
            time.sleep(3)
            return raw
        except urllib.error.HTTPError as e:
            print("retry", url[:80], e.code)
            time.sleep(15)
    raise RuntimeError("no data for " + url)


def oecd(name):
    raw = fetch(oecd_url(name), os.path.join(RAW, f"oecd_{name}.csv"), "application/vnd.sdmx.data+csv")
    return [{k.split(":")[0]: (v.split(":")[0] if k.split(":")[0] != "OBS_VALUE" else v) for k, v in r.items()}
            for r in csv.DictReader(io.StringIO(raw))]


def eurostat(ds):
    d = json.loads(fetch(eurostat_url(ds), os.path.join(RAW, f"{ds}.json")))
    dims, sz = d["id"], d["size"]
    lab = {k: {i: v for v, i in d["dimension"][k]["category"]["index"].items()} for k in dims}
    out = {}
    for flat, val in d["value"].items():
        f = int(flat); co = []
        for s in reversed(sz):
            co.append(f % s); f //= s
        out[tuple(lab[k][c] for k, c in zip(dims, co[::-1]))] = val
    return dims, out


OUT = []


def add(indicator, country, value, unit, year, family, source, url, status="computed from official series"):
    OUT.append(dict(indicator=indicator, country=country, value=value, unit=unit, year=year,
                    family_type=family, source=source, url=url, status=status))


# ---------------------------------------------------------------- average wage
tw = oecd("tw")
AW, NET = {}, {}
for r in tw:
    if (r["UNIT_MEASURE"], r["HOUSEHOLD_TYPE"], r["INCOME_PRINCIPAL"], r["INCOME_SPOUSE"]) != ("XDC", "S_C0", "AW100", "_Z"):
        continue
    c, y = ISO[r["REF_AREA"]], int(r["TIME_PERIOD"])
    if r["MEASURE"] == "GEBT":
        AW[(c, y)] = float(r["OBS_VALUE"])
    if r["MEASURE"] == "NIAT":
        NET[(c, y)] = float(r["OBS_VALUE"])
TW_SRC = "OECD Taxing Wages, DSD_TAX_WAGES_COMP@DF_TW_COMP, single no children at 100% AW, national currency"
for (c, y), v in sorted(AW.items()):
    add("average_wage_gross", c, round(v, 2), "EUR per year", y, "single, no children, 100% AW", TW_SRC + ", GEBT", oecd_url("tw"), "official series (OECD API)")
    add("average_wage_net", c, round(NET[(c, y)], 2), "EUR per year", y, "single, no children, 100% AW", TW_SRC + ", NIAT", oecd_url("tw"), "official series (OECD API)")

# ------------------------------------------------------- minimum income (floor)
ia = oecd("ia")
IA = {}
for r in ia:
    IA[(ISO[r["REF_AREA"]], r["UNIT_MEASURE"], r["HOUSEHOLD_TYPE"], r["HOUSE_BENEFIT"], int(r["TIME_PERIOD"]))] = float(r["OBS_VALUE"])
FAM = {"S_C0": "single, no children", "C_C0": "couple, no children", "S_C2": "single, 2 children", "C_C2": "couple, 2 children"}
IA_SRC = "OECD TaxBEN, Adequacy of minimum income benefits, DSD_TAXBEN_IA@DF_IA, measure GMINISJF"
for c in ("FR", "DE", "IT"):
    for y in (2023, 2024, 2025):
        for h in FAM:
            for hb, hbl in (("NO", "without housing benefit"), ("YES", "with housing benefit")):
                eur = IA[(c, "XDC", h, hb, y)]
                fam = f"{FAM[h]}, jobless, {hbl}"
                add("min_income_net_annual", c, eur, "EUR per year", y, fam, IA_SRC + ", XDC", oecd_url("ia"), "official series (OECD API)")
                add("min_income_pct_median_disposable", c, IA[(c, "PT_INC_DISP_HH_MEDIAN", h, hb, y)], "percent of median disposable household income",
                    y, fam, IA_SRC + ", PT_INC_DISP_HH_MEDIAN", oecd_url("ia"), "official series (OECD API)")
                if (c, y) in AW:
                    add("min_income_share_gross_AW", c, round(eur / AW[(c, y)], 4), "share of gross average wage", y, fam,
                        IA_SRC + " divided by Taxing Wages GEBT", oecd_url("ia"))
                    add("min_income_share_net_AW", c, round(eur / NET[(c, y)], 4), "share of net income of a single at 100% AW", y, fam,
                        IA_SRC + " divided by Taxing Wages NIAT", oecd_url("ia"))

# ------------------------------------------------------ net replacement rates
nrr = oecd("nrr")
N = {}
for r in nrr:
    N[(ISO[r["REF_AREA"]], int(r["TIME_PERIOD"]), r["HOUSEHOLD_TYPE"], r["INCOME_PREV"], r["INCOME_PART"],
       r["SOC_ASS_BENEFIT"], r["HOUSE_BENEFIT"], int(r["UNEMP_DURATION"][1:]))] = float(r["OBS_VALUE"]) / 100


def spell(c, y, h, prev, part, sa, hb, ltu=None):
    s = (LTU[c] if ltu is None else ltu) ** (1 / 12)
    g = lambda m: N[(c, y, h, prev, part, sa, hb, m)]
    return sum(g(m) * s ** (m - 1) * (1 - s) for m in range(1, 61)) + g(60) * s ** 60


TYPES = [  # label, household type, partner earnings
    ("single, no children", "S_C0", "_Z"),
    ("one-earner couple, no children (partner out of work, no benefit entitlement)", "C_C0", "NOEARN_UNEMP_WO_CONBEN"),
    ("two-earner couple, no children, partner at 67% AW", "C_C0", "AW67"),
    ("two-earner couple, no children, partner at 100% AW", "C_C0", "AW100"),
    ("single, 2 children", "S_C2", "_Z"),
    ("one-earner couple, 2 children (partner out of work, no benefit entitlement)", "C_C2", "NOEARN_UNEMP_WO_CONBEN"),
    ("two-earner couple, 2 children, partner at 67% AW", "C_C2", "AW67"),
    ("two-earner couple, 2 children, partner at 100% AW", "C_C2", "AW100"),
]
NRR_SRC = "OECD TaxBEN, Net replacement rates in unemployment, DSD_TAXBEN_NRR@DF_NRR, NHIDU"
RR = {}
for c in ("FR", "DE", "IT"):
    for y in (2023, 2025):
        for lab, h, part in TYPES:
            for prev in ("AW67", "AW100"):
                for sa in ("YES", "NO"):
                    for hb in ("NO", "YES"):
                        fam = f"{lab}; previous earnings {prev[2:]}% AW; social assistance {sa.lower()}; housing benefit {hb.lower()}"
                        for m in (2, 7, 13, 25, 60):
                            add(f"nrr_month_{m}", c, round(N[(c, y, h, prev, part, sa, hb, m)], 2), "share of net household income before job loss",
                                y, fam, NRR_SRC + f", month {m}", oecd_url("nrr"), "official series (OECD API)")
                        v = spell(c, y, h, prev, part, sa, hb)
                        RR[(c, y, h, part, prev, sa, hb)] = v
                        add("nrr_spell_average", c, round(v, 4), "share of net household income before job loss", y, fam,
                            NRR_SRC + f", months 1-60 weighted by the model's spell formula with ltu={LTU[c]}", oecd_url("nrr"))

# check against the repo's value (single, AW100, SA yes, HB no, 2023)
CHECK = {c: RR[(c, 2023, "S_C0", "_Z", "AW100", "YES", "NO")] for c in ("FR", "DE", "IT")}

# -------------------------------------------- household composition (weights)
dims, P = eurostat("lfst_hhindws")      # freq sex age phhcomp unit wstatus geo time
dims2, W = eurostat("lfst_hhwhnpt")     # freq hhwkstat phhcomp unit geo time
HH = ["A1_NCH", "A1_CH", "A_CPL_NCH", "A_CPL_CH", "A_OTH_NCH", "A_OTH_CH"]
HHL = {"A1_NCH": "one adult without children", "A1_CH": "one adult with children", "A_CPL_NCH": "adult in a couple without children",
       "A_CPL_CH": "adult in a couple with children", "A_OTH_NCH": "adult in another household type without children",
       "A_OTH_CH": "adult in another household type with children"}
SHARE = {}
for c in ("FR", "DE", "IT"):
    for y in ("2023", "2025"):
        for age in ("Y25-54", "Y18-64"):
            for w in ("POP", "NEMP"):
                tot = sum(P[("A", "T", age, h, "THS_PER", w, c, y)] for h in HH)
                for h in HH:
                    v = P[("A", "T", age, h, "THS_PER", w, c, y)]
                    SHARE[(c, y, age, w, h)] = v / tot
                    add("hh_share_" + ("not_employed" if w == "NEMP" else "population"), c, round(v / tot, 4),
                        "share of persons in the age group (" + ("not employed" if w == "NEMP" else "all") + ")", y,
                        f"{HHL[h]}, age {age[1:]}", "Eurostat lfst_hhindws (EU-LFS), thousand persons, share of the six household classes",
                        eurostat_url("lfst_hhindws"))
        # partner's status for the not employed living in a couple (all ages; the table has no age dimension)
        for h in ("A_CPL_NCH", "A_CPL_CH"):
            mixed = W[("A", "GE1_WRK_A1_NWRK", h, "THS_PER", c, y)] / 2     # one of the two adults is not working
            none = W[("A", "NWRK_X_EDUC_INAC_GE65", h, "THS_PER", c, y)]    # both not working, not both retired or students
            SHARE[(c, y, "partner_works", h)] = mixed / (mixed + none)
            add("partner_works_share", c, round(mixed / (mixed + none), 4), "share of not-working adults in a couple whose partner works", y,
                HHL[h] + ", all ages", "Eurostat lfst_hhwhnpt: 0.5*GE1_WRK_A1_NWRK / (0.5*GE1_WRK_A1_NWRK + NWRK_X_EDUC_INAC_GE65)",
                eurostat_url("lfst_hhwhnpt"), "computed proxy (not employed, not unemployed; no age split)")

# ----------------------------------------------------- benefit coverage (LFS)
dims3, U = eurostat("lfsa_ugadra")      # freq unit sex age regis_es duration geo time
dims4, D = eurostat("lfsa_ugad")        # freq unit sex age duration geo time
COV = {}
for c in ("FR", "DE", "IT"):
    for y in ("2023", "2024", "2025"):
        for age in ("Y15-74", "Y25-64"):
            dur = lambda ks: (lambda v: None if None in v else sum(v))([D.get(("A", "THS_PER", "T", age, k, c, y)) for k in ks])
            lt = dur(["M_LT1", "M1-2", "M3-5", "M6-11"]); ge = dur(["M12-17", "M18-23", "M24-47", "M_GE48"])
            nb_lt = U.get(("A", "PC", "T", age, "UNE_NBEN", "M_LT12", c, y)); nb_ge = U.get(("A", "PC", "T", age, "UNE_NBEN", "M_GE12", c, y))
            src = "Eurostat lfsa_ugadra (EU-LFS), UNE_NBEN, both sexes"
            if nb_lt is not None:
                add("unemployed_no_benefit_share", c, round(nb_lt / 100, 3), "share of the unemployed", y, f"age {age[1:]}, duration under 12 months", src, eurostat_url("lfsa_ugadra"), "official series (Eurostat API)")
            if nb_ge is not None:
                add("unemployed_no_benefit_share", c, round(nb_ge / 100, 3), "share of the unemployed", y, f"age {age[1:]}, duration 12 months or more", src, eurostat_url("lfsa_ugadra"), "official series (Eurostat API)")
            if None not in (lt, ge, nb_lt, nb_ge):
                v = (lt * nb_lt + ge * nb_ge) / (lt + ge) / 100
                COV[(c, y, age)] = (v, nb_lt / 100, nb_ge / 100, ge / (lt + ge))
                add("unemployed_no_benefit_share", c, round(v, 3), "share of the unemployed", y, f"age {age[1:]}, all durations",
                    src + ", the two duration classes weighted by lfsa_ugad (thousand persons)", eurostat_url("lfsa_ugadra"))

# ------------------------------------------------- household-weighted rates
# Mapping of the six Eurostat classes to TaxBEN cases (see the brief, section 4):
#   one adult without children          -> single, no children
#   one adult with children             -> single, 2 children
#   couple without / with children      -> partner works with probability p (lfst_hhwhnpt): two-earner case with the
#                                          partner at 67% AW; otherwise the one-earner case
#   other household types               -> treated as couples of the same child status (other adults present)
def weighted(c, y, prev, sa, hb, age="Y25-54", pop="NEMP", wy=None, children=True):
    wy = wy or ("2023" if y == 2023 else "2025")
    sh = lambda h: SHARE[(c, wy, age, pop, h)]
    p0, p2 = SHARE[(c, wy, "partner_works", "A_CPL_NCH")], SHARE[(c, wy, "partner_works", "A_CPL_CH")]
    r = lambda h, part: RR[(c, y, h, part, prev, sa, hb)]
    if children:
        cells = [(sh("A1_NCH"), r("S_C0", "_Z")), (sh("A1_CH"), r("S_C2", "_Z")),
                 ((sh("A_CPL_NCH") + sh("A_OTH_NCH")) * p0, r("C_C0", "AW67")),
                 ((sh("A_CPL_NCH") + sh("A_OTH_NCH")) * (1 - p0), r("C_C0", "NOEARN_UNEMP_WO_CONBEN")),
                 ((sh("A_CPL_CH") + sh("A_OTH_CH")) * p2, r("C_C2", "AW67")),
                 ((sh("A_CPL_CH") + sh("A_OTH_CH")) * (1 - p2), r("C_C2", "NOEARN_UNEMP_WO_CONBEN"))]
    else:   # three childless types only, as in the request
        s1 = sh("A1_NCH") + sh("A1_CH"); sc = 1 - s1
        pw = ((sh("A_CPL_NCH") + sh("A_OTH_NCH")) * p0 + (sh("A_CPL_CH") + sh("A_OTH_CH")) * p2) / sc
        cells = [(s1, r("S_C0", "_Z")), (sc * pw, r("C_C0", "AW67")), (sc * (1 - pw), r("C_C0", "NOEARN_UNEMP_WO_CONBEN"))]
    assert abs(sum(w for w, _ in cells) - 1) < 1e-9
    return sum(w * v for w, v in cells), cells


WRR = {}
for c in ("FR", "DE", "IT"):
    for y in (2023, 2025):
        for prev in ("AW67", "AW100"):
            for sa in ("YES", "NO"):
                for hb in ("NO", "YES"):
                    for ch in (True, False):
                        v, cells = weighted(c, y, prev, sa, hb, children=ch)
                        WRR[(c, y, prev, sa, hb, ch)] = (v, cells)
                        add("nrr_household_weighted", c, round(v, 4), "share of net household income before job loss", y,
                            ("six household classes" if ch else "three childless types") +
                            f"; previous earnings {prev[2:]}% AW; social assistance {sa.lower()}; housing benefit {hb.lower()}",
                            "TaxBEN spell averages weighted by Eurostat lfst_hhindws (not employed, age 25-54) and lfst_hhwhnpt",
                            oecd_url("nrr"), "computed; weights are a proxy (not employed, not unemployed)")

# ------------------------------------------------------------ sensitivities
SENS = {}
# (a) France: TaxBEN pays ARE for 24 months (730 days); the rule in force since 1 February 2023 is 548 days
#     (18 months) under age 53 while unemployment is below 9%. Variant: months 19-24 take the month-25 value.
def spell_path(c, path):
    s = LTU[c] ** (1 / 12)
    return sum(path[m] * s ** (m - 1) * (1 - s) for m in range(1, 61)) + path[60] * s ** 60


def fr18(y, h, prev, part, sa, hb):
    path = {m: N[("FR", y, h, prev, part, sa, hb, m)] for m in range(1, 61)}
    for m in range(19, 25):
        path[m] = path[25]
    return spell_path("FR", path)


for y in (2023, 2025):
    for prev in ("AW67", "AW100"):
        for sa in ("YES", "NO"):
            v = fr18(y, "S_C0", prev, "_Z", sa, "NO")
            SENS[("FR18_single", y, prev, sa)] = v
            add("nrr_spell_average_ARE_18_months", "FR", round(v, 4), "share of net household income before job loss", y,
                f"single, no children; previous earnings {prev[2:]}% AW; social assistance {sa.lower()}; housing benefit no",
                NRR_SRC + ", months 19-24 set to the month-25 value (ARE 548 days, service-public F14860)", oecd_url("nrr"),
                "computed sensitivity (author's adjustment of the OECD profile)")
# (b) Italy under 2022 rules (Reddito di cittadinanza without the seven-month cap), same ltu
for sa, hb in (("YES", "NO"), ("YES", "YES"), ("NO", "NO")):
    for prev in ("AW67", "AW100"):
        v = spell_path("IT", {m: N[("IT", 2022, "S_C0", prev, "_Z", sa, hb, m)] for m in range(1, 61)})
        SENS[("IT2022_single", prev, sa, hb)] = v
        add("nrr_spell_average", "IT", round(v, 4), "share of net household income before job loss", 2022,
            f"single, no children; previous earnings {prev[2:]}% AW; social assistance {sa.lower()}; housing benefit {hb.lower()}",
            NRR_SRC + f", TaxBEN 2022 rules, months 1-60 weighted with ltu={LTU['IT']}", oecd_url("nrr"))
        for m in (2, 13, 25, 60):
            add(f"nrr_month_{m}", "IT", N[("IT", 2022, "S_C0", prev, "_Z", sa, hb, m)], "share of net household income before job loss", 2022,
                f"single, no children; previous earnings {prev[2:]}% AW; social assistance {sa.lower()}; housing benefit {hb.lower()}",
                NRR_SRC + f", month {m}", oecd_url("nrr"), "official series (OECD API)")
# (c) weights: other household types dropped; population instead of not employed
def weighted_alt(c, y, prev, sa, hb, pop="NEMP", drop_other=False):
    wy = "2023" if y == 2023 else "2025"
    sh = lambda h: SHARE[(c, wy, "Y25-54", pop, h)]
    p0, p2 = SHARE[(c, wy, "partner_works", "A_CPL_NCH")], SHARE[(c, wy, "partner_works", "A_CPL_CH")]
    r = lambda h, part: RR[(c, y, h, part, prev, sa, hb)]
    c0 = sh("A_CPL_NCH") + (0 if drop_other else sh("A_OTH_NCH")); c2 = sh("A_CPL_CH") + (0 if drop_other else sh("A_OTH_CH"))
    cells = [(sh("A1_NCH"), r("S_C0", "_Z")), (sh("A1_CH"), r("S_C2", "_Z")), (c0 * p0, r("C_C0", "AW67")),
             (c0 * (1 - p0), r("C_C0", "NOEARN_UNEMP_WO_CONBEN")), (c2 * p2, r("C_C2", "AW67")), (c2 * (1 - p2), r("C_C2", "NOEARN_UNEMP_WO_CONBEN"))]
    tot = sum(w for w, _ in cells)
    return sum(w * v for w, v in cells) / tot


for c in ("FR", "DE", "IT"):
    for y in (2023, 2025):
        for prev in ("AW67", "AW100"):
            for lab, kw in (("other household types excluded", dict(drop_other=True)), ("population 25-54 weights", dict(pop="POP"))):
                v = weighted_alt(c, y, prev, "YES", "NO", **kw)
                SENS[("walt", c, y, prev, lab)] = v
                add("nrr_household_weighted", c, round(v, 4), "share of net household income before job loss", y,
                    f"six household classes, {lab}; previous earnings {prev[2:]}% AW; social assistance yes; housing benefit no",
                    "TaxBEN spell averages weighted by Eurostat lfst_hhindws and lfst_hhwhnpt", oecd_url("nrr"), "computed sensitivity; weights are a proxy")
# (d) insurance and partner earnings only: for singles and one-earner couples every month after the insurance
#     benefit ends is set to zero (FR 24 months in TaxBEN, DE 12, IT 24); two-earner couples keep the profile
#     without social assistance, whose long-run level is the partner's earnings. For use next to an explicit floor.
UI_END = {"FR": 24, "DE": 12, "IT": 24}
def ins_only(c, y, h, part, prev):
    path = {m: N[(c, y, h, prev, part, "NO", "NO", m)] for m in range(1, 61)}
    if part in ("_Z", "NOEARN_UNEMP_WO_CONBEN"):
        for m in range(UI_END[c] + 1, 61):
            path[m] = 0.0
    return spell_path(c, path)


for c in ("FR", "DE", "IT"):
    for y in (2023, 2025):
        wy = "2023" if y == 2023 else "2025"
        sh = lambda h: SHARE[(c, wy, "Y25-54", "NEMP", h)]
        p0, p2 = SHARE[(c, wy, "partner_works", "A_CPL_NCH")], SHARE[(c, wy, "partner_works", "A_CPL_CH")]
        for prev in ("AW67", "AW100"):
            r = lambda h, part: ins_only(c, y, h, part, prev)
            cells = [(sh("A1_NCH"), r("S_C0", "_Z")), (sh("A1_CH"), r("S_C2", "_Z")),
                     ((sh("A_CPL_NCH") + sh("A_OTH_NCH")) * p0, r("C_C0", "AW67")),
                     ((sh("A_CPL_NCH") + sh("A_OTH_NCH")) * (1 - p0), r("C_C0", "NOEARN_UNEMP_WO_CONBEN")),
                     ((sh("A_CPL_CH") + sh("A_OTH_CH")) * p2, r("C_C2", "AW67")),
                     ((sh("A_CPL_CH") + sh("A_OTH_CH")) * (1 - p2), r("C_C2", "NOEARN_UNEMP_WO_CONBEN"))]
            v = sum(w * x for w, x in cells)
            SENS[("ins", c, y, prev)] = (v, cells, ins_only(c, y, "S_C0", "_Z", prev))
            add("nrr_spell_average_insurance_only", c, round(ins_only(c, y, "S_C0", "_Z", prev), 4), "share of net household income before job loss", y,
                f"single, no children; previous earnings {prev[2:]}% AW; months after the insurance benefit ends set to zero",
                NRR_SRC + ", social assistance no, housing benefit no", oecd_url("nrr"), "computed (author's construction)")
            _, c3 = WRR[(c, y, prev, "YES", "NO", False)]     # weights of the three childless types: single, two-earner, one-earner
            v3 = c3[0][0] * r("S_C0", "_Z") + c3[1][0] * r("C_C0", "AW67") + c3[2][0] * r("C_C0", "NOEARN_UNEMP_WO_CONBEN")
            SENS[("ins3", c, y, prev)] = v3
            add("nrr_household_weighted_insurance_only", c, round(v3, 4), "share of net household income before job loss", y,
                f"three childless types; previous earnings {prev[2:]}% AW; singles and one-earner couples: zero after the insurance benefit ends",
                "TaxBEN spell averages weighted by Eurostat lfst_hhindws (not employed, age 25-54) and lfst_hhwhnpt", oecd_url("nrr"),
                "computed (author's construction); weights are a proxy")
            add("nrr_spell_average_insurance_only", c, round(r("C_C0", "NOEARN_UNEMP_WO_CONBEN"), 4), "share of net household income before job loss", y,
                f"one-earner couple, no children; previous earnings {prev[2:]}% AW; months after the insurance benefit ends set to zero",
                NRR_SRC + ", social assistance no, housing benefit no", oecd_url("nrr"), "computed (author's construction)")
            add("nrr_household_weighted_insurance_only", c, round(v, 4), "share of net household income before job loss", y,
                f"six household classes; previous earnings {prev[2:]}% AW; singles and one-earner couples: zero after the insurance benefit ends",
                "TaxBEN spell averages weighted by Eurostat lfst_hhindws (not employed, age 25-54) and lfst_hhwhnpt", oecd_url("nrr"),
                "computed (author's construction); weights are a proxy")

# (e) public part of the household-weighted rate: for two-earner couples the month-60 rate without social
#     assistance is (approximately) the partner's earnings and child benefits; subtracting it leaves the benefit.
for c in ("FR", "DE", "IT"):
    for y in (2023, 2025):
        for prev in ("AW67", "AW100"):
            v, cells = WRR[(c, y, prev, "YES", "NO", True)]
            priv = cells[2][0] * N[(c, y, "C_C0", prev, "AW67", "NO", "NO", 60)] + cells[4][0] * N[(c, y, "C_C2", prev, "AW67", "NO", "NO", 60)]
            SENS[("public", c, y, prev)] = v - priv
            v3, cells3 = WRR[(c, y, prev, "YES", "NO", False)]
            priv3 = cells3[1][0] * N[(c, y, "C_C0", prev, "AW67", "NO", "NO", 60)]
            SENS[("public3", c, y, prev)] = v3 - priv3
            add("nrr_household_weighted_public_part", c, round(v3 - priv3, 4), "share of net household income before job loss", y,
                f"three childless types; previous earnings {prev[2:]}% AW; social assistance yes; housing benefit no; partner's earnings removed",
                "household-weighted TaxBEN spell average less the weighted month-60 rate (no social assistance) of the two-earner couple",
                oecd_url("nrr"), "computed approximation; weights are a proxy")
            add("nrr_household_weighted_public_part", c, round(v - priv, 4), "share of net household income before job loss", y,
                f"six household classes; previous earnings {prev[2:]}% AW; social assistance yes; housing benefit no; partner's earnings removed",
                "household-weighted TaxBEN spell average less the weighted month-60 rate (no social assistance) of the two-earner couples",
                oecd_url("nrr"), "computed approximation; weights are a proxy")

with open(os.path.join(HERE, "computed_series.csv"), "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=["indicator", "country", "value", "unit", "year", "family_type", "source", "url", "status"], lineterminator="\n")
    w.writeheader(); w.writerows(OUT)

if __name__ == "__main__":
    pr = print
    pr("rows written:", len(OUT))
    pr("\ncheck against the repo (single, AW100, SA yes, HB no, 2023): ", {c: round(v, 4) for c, v in CHECK.items()}, " repo: FR 0.6529 DE 0.4563 IT 0.3742")
    pr("\naverage wage (gross, net):")
    for (c, y) in sorted(AW):
        pr(f"  {c} {y}  {AW[(c, y)]:10.0f} {NET[(c, y)]:10.0f}  net/gross {NET[(c, y)] / AW[(c, y)]:.3f}")
    pr("\nminimum income, EUR per year; share of gross AW; share of net AW; % median")
    for c in ("FR", "DE", "IT"):
        for y in (2023, 2024, 2025):
            for h in ("S_C0", "C_C0"):
                for hb in ("NO", "YES"):
                    e = IA[(c, "XDC", h, hb, y)]
                    pr(f"  {c} {y} {h} HB {hb:3s} {e:8.0f}  {e / AW[(c, y)]:.3f}  {e / NET[(c, y)]:.3f}  {IA[(c, 'PT_INC_DISP_HH_MEDIAN', h, hb, y)]:.0f}")
    for y in (2023, 2025):
        pr(f"\nNRR {y}: months 2, 13, 60 and spell average")
        for c in ("FR", "DE", "IT"):
            for lab, h, part in TYPES:
                for prev in ("AW67", "AW100"):
                    line = f"  {c} {h:5s} {part[:8]:8s} {prev:5s}"
                    for sa, hb in (("NO", "NO"), ("YES", "NO"), ("YES", "YES")):
                        g = lambda m: N[(c, y, h, prev, part, sa, hb, m)]
                        line += f" | SA {sa:3s} HB {hb:3s}: {g(2):.2f} {g(13):.2f} {g(60):.2f} avg {RR[(c, y, h, part, prev, sa, hb)]:.3f}"
                    pr(line)
    pr("\nhousehold shares, not employed 25-54 (and population 25-54), and partner-works probability")
    for c in ("FR", "DE", "IT"):
        for y in ("2023", "2025"):
            pr(f"  {c} {y} NEMP " + " ".join(f"{h}={SHARE[(c, y, 'Y25-54', 'NEMP', h)]:.3f}" for h in HH))
            pr(f"  {c} {y} POP  " + " ".join(f"{h}={SHARE[(c, y, 'Y25-54', 'POP', h)]:.3f}" for h in HH))
            pr(f"  {c} {y} partner works: no children {SHARE[(c, y, 'partner_works', 'A_CPL_NCH')]:.3f}, children {SHARE[(c, y, 'partner_works', 'A_CPL_CH')]:.3f}")
    pr("\nhousehold-weighted spell-average NRR")
    for key in sorted(WRR):
        v, cells = WRR[key]
        pr("  ", key, round(v, 4), " cells:", " + ".join(f"{w:.3f}*{x:.3f}" for w, x in cells))
    pr("\nshare of the unemployed receiving no benefit (all durations)")
    for k in sorted(COV):
        pr("  ", k, "all %.3f  under 12m %.3f  12m+ %.3f  (LFS long-term share %.3f)" % COV[k])
    pr("\nsensitivities")
    for k in sorted(SENS, key=str):
        v = SENS[k]
        if isinstance(v, tuple):
            pr("  ", k, round(v[0], 4), " single:", round(v[2], 4), " cells:", " + ".join(f"{w:.3f}*{x:.3f}" for w, x in v[1]))
        else:
            pr("  ", k, round(v, 4))

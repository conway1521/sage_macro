"""Build the country table from its sources. No number is typed by hand here:
series come from the Eurostat and OECD APIs and the TaxBEN file in data/, and
the few values that cannot be downloaded come from data/manual_inputs.csv,
each with its citation.

    python3 data/build_country_table.py            # writes data/country_labour_participation.csv
    python3 data/build_country_table.py --check    # compares with the committed table, writes nothing

Every column and its computation is documented in
data/country_labour_participation_sources.md and AUDIT_INPUTS.md.

Definitions (the two education cells are non-tertiary, ISCED 0-4, and
tertiary, ISCED 5-8; ages 25-64 unless stated):
  share_high       tertiary share of the population, 2015 (lfsa_pgaed). The
                   same weights split the low cell in every other column.
  part_low/high    formal volunteering, EU-SILC 2015 ad hoc module (ilc_scp19, AC41A)
  B_low/high       share with someone to ask for help, EU-SILC 2015 (ilc_scp15);
                   the ratio is the data's, the population mean is set to one
                   (the level is absorbed by the social technology kappa)
  alpha_low/high   mean hourly earnings, Structure of Earnings Survey 2014
                   (earn_ses14_16, B-S, 10+ employees), the two non-tertiary
                   levels weighted by employees (earn_ses14_04); population mean
                   one. SES 2022 is reported as a check (alpha_ratio_ses2022).
  work_share       paid share of committed time for the employed, HETUS 2010
                   (tus_00selfstat), full- and part-time combined with the
                   part-time share of employment in the survey year (lfsa_eppga)
  effort_target    = work_share: the model's effort is that share
  e_ref            = work_share: the reference effort in the benefit formula
  median_to_mean   median over mean equivalised net income, 2015 (ilc_di03)
  u_low/high       unemployment rate, OECD Education at a Glance 2023, the two
                   non-tertiary levels weighted by labour force (population
                   share times participation rate)
  ltu_share        share of the unemployed out of work a year or more, OECD 2023
  f_find           1 - ltu_share (annual model)
  delta_low/high   u f / (1 - u), the stationary separation rate
  rr               net replacement rate averaged over a spell (OECD TaxBEN 2023,
                   single, 100% of the average wage, social assistance in,
                   housing benefit out): monthly survival s = ltu^(1/12),
                   rr = sum_{m=1}^{60} NRR_m s^(m-1)(1-s) + NRR_60 s^60
  rho, eta         the income process (manual_inputs.csv)
  ratio, htm_target, and the US participation targets: manual_inputs.csv
"""
import csv, io, json, math, os, sys, time, urllib.error, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
EU = ["FR", "DE", "IT"]
ISO3 = {"FR": "FRA", "DE": "DEU", "IT": "ITA", "US": "USA"}
HETUS_YEAR = {"FR": "2010", "DE": "2013", "IT": "2010"}   # survey year for the part-time share


def eurostat(ds, **kw):
    q = "&".join(f"{k}={v}" for k, vs in kw.items() for v in (vs if isinstance(vs, list) else [vs]))
    d = json.load(urllib.request.urlopen(
        f"https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/{ds}?{q}", timeout=180))
    dims, sz = d["id"], d["size"]
    lab = {k: {i: v for v, i in d["dimension"][k]["category"]["index"].items()} for k in dims}
    out = []
    for flat, val in d["value"].items():
        f = int(flat); co = []
        for s in reversed(sz):
            co.append(f % s); f //= s
        out.append(({k: lab[k][c] for k, c in zip(dims, co[::-1])}, val))
    return out


def one(obs, **match):
    got = [v for k, v in obs if all(k.get(a) == b for a, b in match.items())]
    if len(got) != 1:
        raise ValueError(f"expected one value for {match}, got {len(got)}")
    return got[0]


def oecd(flow, key, start, end):
    url = f"https://sdmx.oecd.org/public/rest/data/{flow}/{key}?startPeriod={start}&endPeriod={end}"
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.sdmx.data+csv",
                                               "User-Agent": "Mozilla/5.0 (sage_macro build script)"})
    for attempt in range(6):
        try:
            raw = urllib.request.urlopen(req, timeout=180).read().decode("utf-8-sig")
            # some flows label their columns and codes ("REF_AREA: Reference area",
            # "FRA: France") even when not asked: keep the codes only
            rows = [{k.split(":")[0]: (v.split(":")[0] if k.split(":")[0] != "OBS_VALUE" else v)
                     for k, v in r.items()} for r in csv.DictReader(io.StringIO(raw))]
            if raw.startswith("DATAFLOW") and rows and "REF_AREA" in rows[0] and len(rows[0]) > 5:
                time.sleep(3)
                return rows
        except urllib.error.HTTPError:
            pass
        time.sleep(15)          # the OECD API rate-limits bursts of requests
    raise RuntimeError(f"OECD API gave no data for {flow}")


def hm(s):
    h, m = str(s).split(":")
    return int(h) + int(m) / 60


def manual():
    rows = {}
    with open(os.path.join(HERE, "manual_inputs.csv")) as fh:
        for r in csv.DictReader(line for line in fh if not line.startswith("#")):
            rows[(r["code"], r["field"])] = r["value"]
    return rows


M = manual()
T = {c: {"code": c} for c in EU + ["US"]}

# -- education shares, participation, belonging (2015) ----------------------
pop = eurostat("lfsa_pgaed", geo=EU, sex="T", age="Y25-64", unit="THS_PER", time="2015",
               isced11=["ED0-2", "ED3_4", "ED5-8"])
vol = eurostat("ilc_scp19", geo=EU, sex="T", age="Y25-64", unit="PC", time="2015", acl00="AC41A",
               isced11=["ED0-2", "ED3_4", "ED5-8"])
hlp = eurostat("ilc_scp15", geo=EU, sex="T", age="Y25-64", unit="PC", time="2015",
               isced11=["ED0-2", "ED3_4", "ED5-8"])
# SES 2014 publishes tertiary as ED5_6 and ED7_8: combined with employee weights
ses = eurostat("earn_ses14_16", geo=EU, sex="T", indic_se="ERN", currency="EUR", nace_r2="B-S",
               sizeclas="GE10", isced11=["ED0-2", "ED3_4", "ED5_6", "ED7_8"])
emp = eurostat("earn_ses14_04", geo=EU, sex="T", unit="NR", nace_r2="B-S", sizeclas="GE10",
               isced11=["ED0-2", "ED3_4", "ED5_6", "ED7_8"])
ses22 = eurostat("earn_ses22_16", geo=EU, sex="T", indic_se="ERN", unit="EUR", nace_r2="B-S",
                 sizeclas="GE10", isced11=["ED0-2", "ED3_4", "ED5-8"])
emp22 = eurostat("earn_ses22_04", geo=EU, sex="T", nace_r2="B-S", sizeclas="GE10",
                 isced11=["ED0-2", "ED3_4", "ED5-8"])
for c in EU:
    w0, w1, w2 = (one(pop, geo=c, isced11=e) for e in ("ED0-2", "ED3_4", "ED5-8"))
    sl, sh = (w0 + w1) / (w0 + w1 + w2), w2 / (w0 + w1 + w2)
    lowmean = lambda obs, wa=w0, wb=w1: (wa * one(obs, geo=c, isced11="ED0-2") +
                                         wb * one(obs, geo=c, isced11="ED3_4")) / (wa + wb)
    t = T[c]
    t["share_high"] = sh
    t["part_low"] = lowmean(vol) / 100
    t["part_high"] = one(vol, geo=c, isced11="ED5-8") / 100
    rB = lowmean(hlp) / one(hlp, geo=c, isced11="ED5-8")
    t["B_high"] = 1 / (sl * rB + sh); t["B_low"] = rB * t["B_high"]
    e = {k: one(emp, geo=c, isced11=k) for k in ("ED0-2", "ED3_4", "ED5_6", "ED7_8")}
    h = {k: one(ses, geo=c, isced11=k) for k in e}
    wmean = lambda ks: sum(e[k] * h[k] for k in ks) / sum(e[k] for k in ks)
    rA = wmean(("ED0-2", "ED3_4")) / wmean(("ED5_6", "ED7_8"))
    t["alpha_high"] = 1 / (sl * rA + sh); t["alpha_low"] = rA * t["alpha_high"]
    f0 = [v for k, v in emp22 if k["geo"] == c and k["isced11"] == "ED0-2"][0]
    f1 = [v for k, v in emp22 if k["geo"] == c and k["isced11"] == "ED3_4"][0]
    t["alpha_ratio_ses2022"] = ((f0 * one(ses22, geo=c, isced11="ED0-2") + f1 * one(ses22, geo=c, isced11="ED3_4"))
                                / (f0 + f1) / one(ses22, geo=c, isced11="ED5-8"))

# -- time use (HETUS 2010) ----------------------------------------------------
tus = eurostat("tus_00selfstat", geo=EU, sex="T", unit="TIME_SP", time="2010",
               wstatus=["EMP_FT", "EMP_PT"], acl00=["AC1A", "AC3", "AC41", "AC42"])
for c in EU:
    pt = one(eurostat("lfsa_eppga", geo=c, sex="T", age="Y15-64", unit="PC", time=HETUS_YEAR[c])) / 100
    share = {}
    for ws in ("EMP_FT", "EMP_PT"):
        g = lambda a: hm(one(tus, geo=c, wstatus=ws, acl00=a))
        share[ws] = g("AC1A") / (g("AC1A") + g("AC3") + g("AC41") + g("AC42"))
    T[c]["work_share"] = (1 - pt) * share["EMP_FT"] + pt * share["EMP_PT"]
    T[c]["effort_target"] = T[c]["work_share"]
    T[c]["e_ref"] = T[c]["work_share"]

# -- income distribution --------------------------------------------------------
inc = eurostat("ilc_di03", geo=EU, sex="T", age="TOTAL", unit="EUR", time="2015")
for c in EU:
    T[c]["median_to_mean"] = one(inc, geo=c, statinfo="MED_EI") / one(inc, geo=c, statinfo="MEAN_EI")

# -- labour market (OECD, 2023) -------------------------------------------------
KEY = "FRA+DEU+ITA+USA" + "." * 16


def eag(flow):
    """One value per country and attainment level: both sexes, ages 25-64,
    all fields and birthplaces, observed values (not standard errors)."""
    out = {}
    for r in oecd("OECD.EDU.IMEP,DSD_EAG_LSO_EA@" + flow + ",", KEY, 2023, 2023):
        if (r["SEX"], r["AGE"], r["STATISTICAL_OPERATION"], r["EDUCATION_FIELD"], r["BIRTH_PLACE"]) != \
                ("_T", "Y25T64", "OBS", "_T", "_T") or not r["OBS_VALUE"]:
            continue
        out.setdefault((r["REF_AREA"], r["ATTAINMENT_LEV"]), []).append(float(r["OBS_VALUE"]))
    for k, v in out.items():
        if len(v) != 1 and k[1] in ("ISCED11A_0T2", "ISCED11A_3_4", "ISCED11A_5T8"):
            raise ValueError(f"{flow}: {k} has {len(v)} values")
    return {k: v[0] for k, v in out.items()}


U, D, LF = eag("DF_LSO_NEAC_UNEMP"), eag("DF_LSO_NEAC_DISTR_EA"), eag("DF_LSO_NEAC_LF")
dur = {r["REF_AREA"]: float(r["OBS_VALUE"]) / 100
       for r in oecd("OECD.ELS.SAE,DSD_DUR@DF_DUR_I,", "FRA+DEU+ITA+USA......", 2023, 2023)
       if (r["SEX"], r["AGE"], r["DURATION"]) == ("_T", "_T", "Y_GE1")}
for c in EU + ["US"]:
    i = ISO3[c]
    w = {e: D[(i, e)] * LF[(i, e)] for e in ("ISCED11A_0T2", "ISCED11A_3_4")}
    t = T[c]
    t["u_low"] = sum(U[(i, e)] * w[e] for e in w) / sum(w.values()) / 100
    t["u_high"] = U[(i, "ISCED11A_5T8")] / 100
    t["ltu_share"] = dur[i]
    t["f_find"] = 1 - dur[i]
    for g in ("low", "high"):
        u = t["u_" + g]
        t["delta_" + g] = u * t["f_find"] / (1 - u)

# -- replacement rate over a spell (TaxBEN 2023 file in data/) ------------------
nrr = {}
with open(os.path.join(HERE, "taxben_nrr_2023_single_aw100.csv")) as fh:
    for r in csv.DictReader(fh):
        if (r["HOUSEHOLD_TYPE"], r["INCOME_PREV"], r["SOC_ASS_BENEFIT"], r["HOUSE_BENEFIT"]) != \
                ("S_C0", "AW100", "YES", "NO"):
            continue
        m = r["UNEMP_DURATION"]
        if m.startswith("M") and m[1:].isdigit():
            nrr[(r["REF_AREA"], int(m[1:]))] = float(r["OBS_VALUE"]) / 100
for c in EU + ["US"]:
    i = ISO3[c]; s = T[c]["ltu_share"] ** (1 / 12)
    T[c]["rr"] = sum(nrr[(i, m)] * s ** (m - 1) * (1 - s) for m in range(1, 61)) + nrr[(i, 60)] * s ** 60

# -- manual inputs ----------------------------------------------------------------
for c in EU + ["US"]:
    for f in ("ratio", "htm_target", "rho", "eta", "dread"):
        T[c][f] = float(M[(c, f)])
for f in ("part_low", "part_high"):
    T["US"][f] = float(M[("US", f)])
T["US"]["share_high"] = D[("USA", "ISCED11A_5T8")] / 100

COLS = ["code", "share_high", "alpha_low", "alpha_high", "B_low", "B_high", "u_low", "u_high", "ltu_share",
        "f_find", "delta_low", "delta_high", "rr", "part_low", "part_high", "ratio", "work_share", "e_ref",
        "effort_target", "htm_target", "median_to_mean", "rho", "eta", "dread", "alpha_ratio_ses2022"]
HEADER = ["# generated by data/build_country_table.py; do not edit by hand. Sources and computations:",
          "# data/country_labour_participation_sources.md and AUDIT_INPUTS.md. NA: not available for this",
          "# country (the United States is not calibrated)."]
out = io.StringIO()
out.write("\n".join(HEADER) + "\n")
w = csv.writer(out, lineterminator="\n")
w.writerow(COLS)
for c in EU + ["US"]:
    w.writerow([c] + [("%.6f" % T[c][k]) if isinstance(T[c].get(k), float) else "NA" for k in COLS[1:]])
path = os.path.join(HERE, "country_labour_participation.csv")
if "--check" in sys.argv:
    old = {}
    with open(path) as fh:
        for r in csv.DictReader(line for line in fh if not line.startswith("#")):
            old[r["code"]] = r
    print(f"{'column':22s}" + "".join(f"{c:>22s}" for c in EU))
    for k in COLS[1:]:
        cells = []
        for c in EU:
            new = T[c].get(k); o = old.get(c, {}).get(k)
            cells.append(f"{(o or '-')[:8]:>10s} -> {('%.6f' % new)[:8] if isinstance(new, float) else 'NA':>8s}")
        print(f"{k:22s}" + "".join(cells))
else:
    open(path, "w").write(out.getvalue())
    print("wrote", path)

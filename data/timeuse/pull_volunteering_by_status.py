"""TASK 2, third part. Volunteering of the inactive against the employed and the unemployed.

    python3 pull_volunteering_by_status.py

Eurostat publishes the EU-SILC 2015 module (ilc_scp19 to ilc_scp22) by sex, age, education,
income quintile, household type and degree of urbanisation. There is NO breakdown by activity
status. The closest tables, all written to volunteering_by_status.csv:
  (1) ilc_scp19 by age (16-24, 25-64, 65-74, 75+), 2015 and 2022: the same survey as the model's
      participation targets; age stands in for student and retired status.
  (2) ISTAT, Aspetti della vita quotidiana, SDMX dataflow 83_63_DF_DCCV_AVQ_PERSONE_131
      ("Associazionismo - condizione e posizione nella professione"): persons aged 15+ who did
      unpaid work in voluntary associations in the last 12 months, by status, 2013 to 2025.
  (3) Figures transcribed from official reports and one peer-reviewed article, each read in
      full text for this brief (DOCS below, with page or table).
  (4) tus_00selfstat: share doing organisational work (AC41) on a diary day, by status.
"""
import csv, io, os, urllib.request
from estat import get, hm, status, write_csv

HERE = os.path.dirname(os.path.abspath(__file__))
EU = ["FR", "DE", "IT"]
rows = []

# (1) EU-SILC by age ------------------------------------------------------------
AG = ["Y_GE16", "Y16-24", "Y25-64", "Y65-74", "Y_GE65", "Y_GE75"]
P = {}
for L, v, f in get("ilc_scp19", geo=EU, sex="T", isced11="TOTAL", acl00="AC41A", age=AG):
    P[(L["geo"], L["time"], L["age"])] = v
    rows.append(("formal_volunteering_12m", L["geo"], "national", L["age"], L["time"], v, "percent",
                 "Eurostat ilc_scp19 (EU-SILC ad hoc module), AC41A", status(f)))
for c in EU:
    for y in ("2015", "2022"):
        if (c, y, "Y25-64") in P:
            for a in ("Y16-24", "Y65-74", "Y_GE65", "Y_GE75"):
                rows.append(("formal_volunteering_ratio_to_25_64", c, "national", a, y, round(P[(c, y, a)] / P[(c, y, "Y25-64")], 3),
                             "ratio", "ilc_scp19", "DERIVED"))

# (2) ISTAT AVQ by status -------------------------------------------------------
URL = "https://esploradati.istat.it/SDMXWS/rest/data/83_63_DF_DCCV_AVQ_PERSONE_131/?startPeriod=2013"
LAB = {"1": "employed", "2": "unemployed, with work experience", "3": "seeking first job", "4": "homemaker",
       "5": "student", "6": "retired", "7": "other condition", "99": "total"}
SRC = "ISTAT Aspetti della vita quotidiana, SDMX 83_63_DF_DCCV_AVQ_PERSONE_131, DATA_TYPE 15_VOL_ASS (ages 15+, last 12 months)"
try:
    req = urllib.request.Request(URL, headers={"Accept": "application/vnd.sdmx.data+csv;version=1.0.0", "User-Agent": "Mozilla/5.0"})
    raw = urllib.request.urlopen(req, timeout=300).read().decode("utf-8-sig")
    with open(os.path.join(HERE, "raw", "istat_avq_131.csv"), "w") as fh:
        fh.write(raw)
except Exception as e:                       # the ISTAT service is slow: fall back to the saved pull
    print("ISTAT service not reached, using raw/istat_avq_131.csv:", e)
    raw = open(os.path.join(HERE, "raw", "istat_avq_131.csv"), encoding="utf-8-sig").read()
A = {}
for r in csv.DictReader(io.StringIO(raw)):
    if r["DATA_TYPE"] == "15_VOL_ASS" and r["SEX"] == "9" and r["LABOUR_PROFESS_STATUS_B"] in LAB:
        A[(r["LABOUR_PROFESS_STATUS_B"], r["TIME_PERIOD"], r["MEASURE"])] = float(r["OBS_VALUE"])
years = sorted({y for (_, y, _) in A})
for (s, y, m), v in sorted(A.items()):
    if m == "HSC":
        rows.append(("volunteering_in_associations_12m", "IT", "national", LAB[s], y, v, "percent", SRC, "VERIFIED"))
for y in years:
    # persons by status = volunteers (thousands) / rate; aggregate the labour force and the inactive
    n = {s: A[(s, y, "THV")] / (A[(s, y, "HSC")] / 100) for s in LAB if s != "99"}
    lf = sum(A[(s, y, "THV")] for s in "123") / sum(n[s] for s in "123")
    ina = sum(A[(s, y, "THV")] for s in "4567") / sum(n[s] for s in "4567")
    rows.append(("volunteering_in_associations_12m", "IT", "national", "labour force (employed and unemployed)", y, round(100 * lf, 2), "percent",
                 SRC + ": volunteers / persons, persons = THV / HSC", "DERIVED"))
    rows.append(("volunteering_in_associations_12m", "IT", "national", "outside the labour force", y, round(100 * ina, 2), "percent",
                 SRC + ": volunteers / persons, persons = THV / HSC", "DERIVED"))
    rows.append(("ratio_inactive_to_labour_force", "IT", "national", "outside the labour force / labour force", y, round(ina / lf, 3), "ratio", SRC, "DERIVED"))
    rows.append(("ratio_unemployed_to_employed", "IT", "national", "unemployed (both kinds) / employed", y,
                 round(sum(A[(s, y, "THV")] for s in "23") / sum(n[s] for s in "23") / (A[("1", y, "HSC")] / 100), 3), "ratio", SRC, "DERIVED"))
    rows.append(("volunteering_in_associations_12m", "IT", "national", "homemaker and other condition", y,
                 round(100 * sum(A[(s, y, "THV")] for s in "47") / sum(n[s] for s in "47"), 2), "percent",
                 SRC + ": volunteers / persons, persons = THV / HSC", "DERIVED"))
    for s in "4567":
        rows.append(("ratio_to_employed", "IT", "national", LAB[s], y, round(A[(s, y, "HSC")] / A[("1", y, "HSC")], 3), "ratio", SRC, "DERIVED"))

# (3) transcribed from documents read in full text ------------------------------
FWS = ("Simonson, Kelle, Kausmann and Tesch-Roemer (eds) 2021, Freiwilliges Engagement in Deutschland: Der Deutsche "
       "Freiwilligensurvey 2019, DZA Berlin, Abbildung 4-5, p. 75 (ages 14+, last 12 months, weighted, n = 27,705)")
ISTAT13 = ("ISTAT 2014, Attivita gratuite a beneficio di altri, Anno 2013 (Statistica report, 23 July 2014), Prospetto 2, p. 4 "
           "(ages 14+, FOUR weeks before the interview)")
ISTAT13H = ISTAT13.replace("Prospetto 2, p. 4", "Prospetto 3, p. 7")
INSEE = ("Luczak and Nabli 2010, Vie associative: 16 millions d'adherents en 2008, Insee Premiere 1327 (SRCV-SILC 2008, ages 16+), "
         "https://www.insee.fr/fr/statistiques/1280946")
DOC = "VERIFIED (document read, value transcribed)"
DOCS = [
    ("volunteering_12m_FWS", "DE", "total", 2019, 39.7, "percent", FWS),
    ("volunteering_12m_FWS", "DE", "employed full-time", 2019, 43.5, "percent", FWS),
    ("volunteering_12m_FWS", "DE", "employed part-time or marginal", 2019, 50.8, "percent", FWS),
    ("volunteering_12m_FWS", "DE", "unemployed", 2019, 19.0, "percent", FWS),
    ("volunteering_12m_FWS", "DE", "retired", 2019, 31.7, "percent", FWS),
    ("volunteering_12m_FWS", "DE", "in education", 2019, 46.3, "percent", FWS),
    ("volunteering_12m_FWS", "DE", "not employed, other reasons", 2019, 34.3, "percent", FWS),
    ("organised_volunteering_4w", "IT", "total", 2013, 7.9, "percent", ISTAT13),
    ("organised_volunteering_4w", "IT", "employed", 2013, 9.1, "percent", ISTAT13),
    ("organised_volunteering_4w", "IT", "seeking work", 2013, 6.2, "percent", ISTAT13),
    ("organised_volunteering_4w", "IT", "homemaker", 2013, 5.4, "percent", ISTAT13),
    ("organised_volunteering_4w", "IT", "student", 2013, 9.5, "percent", ISTAT13),
    ("organised_volunteering_4w", "IT", "retired", 2013, 7.9, "percent", ISTAT13),
    ("organised_volunteering_4w", "IT", "other condition", 2013, 5.0, "percent", ISTAT13),
    ("organised_volunteering_hours_4w_per_volunteer", "IT", "total", 2013, 18.6, "hours in four weeks", ISTAT13H),
    ("organised_volunteering_hours_4w_per_volunteer", "IT", "employed", 2013, 15.1, "hours in four weeks", ISTAT13H),
    ("organised_volunteering_hours_4w_per_volunteer", "IT", "seeking work", 2013, 18.3, "hours in four weeks", ISTAT13H),
    ("organised_volunteering_hours_4w_per_volunteer", "IT", "homemaker", 2013, 19.2, "hours in four weeks", ISTAT13H),
    ("organised_volunteering_hours_4w_per_volunteer", "IT", "student", 2013, 14.4, "hours in four weeks", ISTAT13H),
    ("organised_volunteering_hours_4w_per_volunteer", "IT", "retired", 2013, 28.1, "hours in four weeks", ISTAT13H),
    ("association_membership", "FR", "employed", 2008, 35, "percent", INSEE),
    ("association_membership", "FR", "retired", 2008, 34, "percent", INSEE),
    ("association_membership", "FR", "unemployed", 2008, 17, "percent", INSEE),
    ("association_membership", "FR", "homemaker", 2008, 23, "percent", INSEE),
    ("members_who_volunteer", "FR", "employed", 2008, 58, "percent of members", INSEE),
    ("members_who_volunteer", "FR", "unemployed", 2008, 67, "percent of members", INSEE),
]
for ind, c, g, y, v, u, src in DOCS:
    rows.append((ind, c, "national", g, y, v, u, src, DOC + (" via page reader" if src is INSEE else "")))
rows.append(("volunteering_rate_by_activity_status", "FR", "national", "retired, students, homemakers", "", "", "percent",
             "no official table found; EU-SILC module not published by activity status", "UNVERIFIED, NOT FOUND"))
fws = {g: v for ind, c, g, y, v, u, s in DOCS if ind == "volunteering_12m_FWS"}
for g in ("unemployed", "retired", "in education", "not employed, other reasons", "employed part-time or marginal"):
    rows.append(("ratio_to_employed_full_time", "DE", "national", g, 2019, round(fws[g] / fws["employed full-time"], 3), "ratio", FWS, "DERIVED"))

# (4) diary-day participation in organisational work, by status ------------------
T = {}
for L, v, f in get("tus_00selfstat", geo=EU, sex="T", acl00="AC41", unit="PTP_RT"):
    if not (isinstance(v, str) and v.startswith(":")):
        T[(L["geo"], L["time"], L["wstatus"])] = (v, f)
for (c, y, ws), (v, f) in sorted(T.items()):
    rows.append(("AC41_daily_participation_rate", c, "national", ws, y, v, "percent of persons on a diary day",
                 "Eurostat tus_00selfstat (HETUS, ages 20-74)", status(f)))
    e = T.get((c, y, "EMP_FT"))
    if e and e[0] and ws not in ("EMP_FT", "POP"):
        rows.append(("AC41_daily_rate_ratio_to_full_time", c, "national", ws, y, round(v / e[0], 2), "ratio",
                     "Eurostat tus_00selfstat: mixes how many take part with how often", "DERIVED"))
write_csv(os.path.join(HERE, "volunteering_by_status.csv"), rows)

print("IT (ISTAT AVQ, 12 months, 15+), percent:")
for y in ("2015", years[-1]):
    print(" ", y, {LAB[s]: A[(s, y, "HSC")] for s in LAB}, [r[5] for r in rows if r[0] == "ratio_inactive_to_labour_force" and r[4] == y])
print("DE (FWS 2019):", fws)
print("SILC 2015 by age:", {c: {a: P[(c, "2015", a)] for a in AG} for c in EU})

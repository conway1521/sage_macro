"""TASK 2. People outside the labour force, by place.

    python3 pull_inactivity.py

Pulls (Eurostat dissemination API, standard library only):
  lfst_r_lfsd2pwc   population in private households by labour status and NUTS 2 region (LFS):
                    POP, ACT, EMP, UNE, INAC, thousand persons; ages 20-64, 15-64, 15-74, 15+, 15-24
  lfst_r_lfp2actrt  labour force participation rates by region (cross-check, ages 15-74 and 15+)
  lfst_r_lfp2actrc  the same with ages 20-64 (cross-check)
  lfsa_pgauws       population by degree of urbanisation and labour status (LFS)
  ilc_lvhl02        EU-SILC, population 18+ by most frequent activity status (2015)
  cens_21a_r2       Census 2021, population by current activity status, age and region
Writes:
  inactive_share_tl2.csv          share outside the labour force, by TL2 region, 2015 and latest
  inactive_share_degurba.csv      the same by degree of urbanisation
  inactive_composition.csv        who the inactive are: by age (LFS, regional), by type (Census 2021,
                                  regional; EU-SILC 2015, national)
The TL2 list is the one in data/place/build_tl2.py.
"""
import os
from estat import get, status, write_csv

HERE = os.path.dirname(os.path.abspath(__file__))
REGIONS = {
    "FR": ["FR1", "FRB", "FRC", "FRD", "FRE", "FRF", "FRG", "FRH", "FRI", "FRJ", "FRK", "FRL", "FRM", "FRY"],
    "DE": ["DE1", "DE2", "DE3", "DE4", "DE5", "DE6", "DE7", "DE8", "DE9", "DEA", "DEB", "DEC", "DED", "DEE", "DEF", "DEG"],
    "IT": ["ITC1", "ITC2", "ITC3", "ITC4", "ITH1", "ITH2", "ITH3", "ITH4", "ITH5", "ITI1", "ITI2", "ITI3", "ITI4",
           "ITF1", "ITF2", "ITF3", "ITF4", "ITF5", "ITF6", "ITG1", "ITG2"],
}
CTRY = {g: c for c in REGIONS for g in REGIONS[c] + [c]}
GEO = [g for c in REGIONS for g in [c] + REGIONS[c]]
AGES = ["Y20-64", "Y15-64", "Y15-74", "Y_GE15", "Y15-24"]
YEARS = ["2015", "2019", "2024", "2025"]


def worst(*flags):
    f = "".join(sorted(set("".join(flags))))
    return ("VERIFIED" if not f else f"VERIFIED (Eurostat flags: {f})") + ", ratio DERIVED"


# ------------------------------------------------------------ TL2, LFS ---------
lfs = {}
for L, v, f in get("lfst_r_lfsd2pwc", geo=GEO, sex="T", c_birth="TOTAL", age=AGES,
                   wstatus=["POP", "ACT", "INAC", "EMP", "UNE"], time=YEARS):
    lfs[(L["geo"], L["time"], L["age"], L["wstatus"])] = (v, f)
latest = max(y for (_, y, _, _) in lfs)
rows, share = [], {}
SRC = "Eurostat lfst_r_lfsd2pwc (LFS, private households)"
for g in GEO:
    for y in YEARS:
        for a in AGES[:4]:
            p, i, e, u = (lfs.get((g, y, a, w)) for w in ("POP", "INAC", "EMP", "UNE"))
            if not (p and i):
                continue
            share[(g, y, a)] = 100 * i[0] / p[0]
            rows.append(("inactive_share", CTRY[g], g, a, y, round(100 * i[0] / p[0], 2), "percent of population", SRC + ": INAC / POP", worst(p[1], i[1])))
            rows.append(("population", CTRY[g], g, a, y, p[0], "thousand persons", SRC, status(p[1])))
            rows.append(("inactive", CTRY[g], g, a, y, i[0], "thousand persons", SRC, status(i[1])))
            if e and u:
                rows.append(("employed_share", CTRY[g], g, a, y, round(100 * e[0] / p[0], 2), "percent of population", SRC + ": EMP / POP", worst(p[1], e[1])))
                rows.append(("unemployed_share", CTRY[g], g, a, y, round(100 * u[0] / p[0], 2), "percent of population", SRC + ": UNE / POP", worst(p[1], u[1])))
# cross-check against the published participation rates
chk = []
for L, v, f in get("lfst_r_lfp2actrt", geo=GEO, sex="T", unit="PC", age=["Y15-74", "Y_GE15", "Y15-64"], time=[latest, "2015"]):
    k = (L["geo"], L["time"], L["age"])
    if k in share:
        chk.append(abs(100 - v - share[k]))
        rows.append(("inactive_share_from_published_rate", CTRY[L["geo"]], L["geo"], L["age"], L["time"], round(100 - v, 2),
                     "percent of population", "Eurostat lfst_r_lfp2actrt: 100 - participation rate", status(f)))
for L, v, f in get("lfst_r_lfp2actrc", geo=GEO, sex="T", unit="PC", age="Y20-64", c_birth="TOTAL", isced11="TOTAL", time=[latest, "2015"]):
    k = (L["geo"], L["time"], L["age"])
    if k in share:
        chk.append(abs(100 - v - share[k]))
        rows.append(("inactive_share_from_published_rate", CTRY[L["geo"]], L["geo"], L["age"], L["time"], round(100 - v, 2),
                     "percent of population", "Eurostat lfst_r_lfp2actrc: 100 - participation rate", status(f)))
write_csv(os.path.join(HERE, "inactive_share_tl2.csv"), sorted(rows, key=lambda r: (r[0], r[1], r[4], r[3], r[2])))
print(f"TL2: latest year {latest}; {len(chk)} cross-checks against published rates, largest gap {max(chk):.2f} points")
for c, regs in REGIONS.items():
    for a in ("Y20-64", "Y15-74", "Y_GE15"):
        miss = [g for g in regs if (g, latest, a) not in share]
        vals = [share[(g, latest, a)] for g in regs if (g, latest, a) in share]
        print(f"  {c} {a} {latest}: national {share[(c, latest, a)]:.1f}, regions {min(vals):.1f} to {max(vals):.1f}, missing {miss or 'none'}")

# ------------------------------------------------------------ degree of urbanisation
drow = []
SRC2 = "Eurostat lfsa_pgauws (LFS, private households)"
du = {}
for L, v, f in get("lfsa_pgauws", geo=list(REGIONS), sex="T", age=AGES, wstatus=["POP", "INAC", "EMP", "UNE"], time=YEARS):
    du[(L["geo"], L["time"], L["deg_urb"], L["age"], L["wstatus"])] = (v, f)
for c in REGIONS:
    for y in YEARS:
        for d in ("TOTAL", "DEG1", "DEG2", "DEG3"):
            for a in AGES[:4]:
                p, i, e, u = (du.get((c, y, d, a, w)) for w in ("POP", "INAC", "EMP", "UNE"))
                if not (p and i):
                    continue
                drow.append(("inactive_share", c, d, a, y, round(100 * i[0] / p[0], 2), "percent of population", SRC2 + ": INAC / POP", worst(p[1], i[1])))
                drow.append(("population", c, d, a, y, p[0], "thousand persons", SRC2, status(p[1])))
                if e and u:
                    drow.append(("employed_share", c, d, a, y, round(100 * e[0] / p[0], 2), "percent of population", SRC2 + ": EMP / POP", worst(p[1], e[1])))
                    drow.append(("unemployed_share", c, d, a, y, round(100 * u[0] / p[0], 2), "percent of population", SRC2 + ": UNE / POP", worst(p[1], u[1])))
write_csv(os.path.join(HERE, "inactive_share_degurba.csv"), sorted(drow, key=lambda r: (r[0], r[1], r[4], r[3], r[2])))
print("\ndegree of urbanisation, inactive share, ages 20-64 | 15-74 | 15+")
for c in REGIONS:
    for y in ("2015", latest):
        print(f"  {c} {y}: " + "  ".join(
            f"{d} " + " | ".join(f"{100 * du[(c, y, d, a, 'INAC')][0] / du[(c, y, d, a, 'POP')][0]:.1f}" for a in ("Y20-64", "Y15-74", "Y_GE15"))
            for d in ("TOTAL", "DEG1", "DEG2", "DEG3")))

# ------------------------------------------------------------ who the inactive are
crow = []
# (a) by age, LFS, regional: 15-24, 25-64, 65-74, 75+ as shares of the inactive aged 15+
for g in GEO:
    for y in ("2015", latest):
        i = {a: lfs.get((g, y, a, "INAC")) for a in ("Y15-24", "Y15-64", "Y15-74", "Y_GE15")}
        if not all(i.values()):
            continue
        tot = i["Y_GE15"][0]
        parts = {"Y15-24": i["Y15-24"][0], "Y25-64": i["Y15-64"][0] - i["Y15-24"][0],
                 "Y65-74": i["Y15-74"][0] - i["Y15-64"][0], "Y_GE75": tot - i["Y15-74"][0]}
        fl = "".join(v[1] for v in i.values())
        for a, v in parts.items():
            crow.append(("inactive_by_age_share", CTRY[g], g, a, y, round(100 * v / tot, 2), "percent of the inactive aged 15+",
                         SRC + ": INAC by age, differences of published age bands", worst(fl)))
# (b) by type, Census 2021, regional, ages 15+
cen = {}
for L, v, f in get("cens_21a_r2", geo=GEO, sex="T", age=["TOTAL", "Y_LT15", "Y15-29", "Y30-49", "Y50-64", "Y65-84", "Y_GE85"]):
    cen[(L["geo"], L["age"], L["wstatus"])] = (v, f)
SRC3 = "Eurostat cens_21a_r2 (Census 2021, current activity status)"
for g in GEO:
    ad = ["Y15-29", "Y30-49", "Y50-64", "Y65-84", "Y_GE85"]
    s = lambda w, ages=ad: sum(cen[(g, a, w)][0] for a in ages)
    tot, inac = s("TOTAL"), s("INAC")
    crow.append(("census_inactive_share", CTRY[g], g, "Y_GE15", "2021", round(100 * inac / tot, 2), "percent of population aged 15+", SRC3, "VERIFIED, ratio DERIVED"))
    wa = ["Y15-29", "Y30-49", "Y50-64"]
    crow.append(("census_inactive_share", CTRY[g], g, "Y15-64", "2021", round(100 * s("INAC", wa) / s("TOTAL", wa), 2), "percent of population aged 15-64", SRC3, "VERIFIED, ratio DERIVED"))
    for w, name in (("EDUC", "students"), ("INC", "retired and capital income recipients"), ("INAC_OTH", "other outside the labour force")):
        crow.append(("census_inactive_by_type_share", CTRY[g], g, name + ", 15+", "2021", round(100 * s(w) / inac, 2), "percent of the inactive aged 15+", SRC3, "VERIFIED, ratio DERIVED"))
        crow.append(("census_inactive_by_type_share", CTRY[g], g, name + ", 15-64", "2021", round(100 * s(w, wa) / s("INAC", wa), 2), "percent of the inactive aged 15-64", SRC3, "VERIFIED, ratio DERIVED"))
# (c) by most frequent activity status, EU-SILC 2015, national (same survey as the volunteering module)
for L, v, f in get("ilc_lvhl02", geo=list(REGIONS), sex="T", rskpovth="TOTAL", time=["2015", "2022"], wstatus=["EMP", "UNE", "RET", "INAC_OTH"]):
    crow.append(("silc_population_by_activity_status", L["geo"], "national", f"{L['wstatus']}, {L['age']}", L["time"], v, "percent of population in the age group",
                 "Eurostat ilc_lvhl02 (EU-SILC, most frequent activity status)", status(f)))
write_csv(os.path.join(HERE, "inactive_composition.csv"), sorted(crow, key=lambda r: (r[0], r[1], r[4], r[2], r[3])))
print("\ncomposition of the inactive aged 15+, Census 2021 (students | retired | other), national and range across regions")
for c, regs in REGIONS.items():
    get_ = lambda g, n: next(r[5] for r in crow if r[0] == "census_inactive_by_type_share" and r[2] == g and r[3] == n + ", 15+")
    for n in ("students", "retired and capital income recipients", "other outside the labour force"):
        vals = [get_(g, n) for g in regs]
        print(f"  {c} {n}: national {get_(c, n)}, regions {min(vals)} to {max(vals)}")

"""The life-satisfaction value of air quality (PM2.5) for E's wellbeing term (DIMENSIONS_SPEC.md, phase 1),
estimated the way Ferreira, Akay, Brereton, Cuñado, Martinsson, Moro and Ningal (2013, Ecological
Economics 88) estimate it for SO2: a hybrid life-satisfaction equation on the European Social Survey with
the pollutant measured in the respondent's region, the log of household income, individual controls,
the size of the settlement, and country-by-round dummies. A fitted moment under the parameter rule
(no published European PM2.5 valuation with an income coefficient was found, 14 October 2026).

Data. ESS rounds 6, 7, 10 (both editions) and 11 for France, Germany and Italy (raw files in
data/ess/raw, not redistributed). PM2.5: population-weighted mean exposure by OECD TL2 region and year
(OECD, dataflow OECD.ENV.EPI,DSD_AIR_POL@DF_AIR_POLL, measure MEAN_POP, PM2_5; data/environment/
oecd_pm25_tl2.csv), the interview year capped at 2020, the last year published. ESS regions are mapped
to TL2: Germany's Länder directly; France's NUTS 2 (2010 coding in rounds 6 and 7, 2016 in 10 and 11)
to its 2016 large regions; Italy's NUTS 2 in round 6 directly and its five NUTS 1 areas in rounds 10 and
11 by the population-weighted mean of their regions (data/place/place_tl2.csv). Household income: the
ESS income decile (hinctnta) at the midpoint of that decile of the national distribution of equivalised
disposable income in the interview year (Eurostat ilc_di01, fetched by fetch_income_deciles.py: P5 for the first decile, the mean of adjacent
cut-offs for the second to the ninth, P95 for the tenth), with household size as a control.

Deviations from Ferreira and co-authors, stated: no climate controls (they use ECA&D temperatures and
precipitation); equivalised decile midpoints in place of banded household income. Standard errors
clustered by region. A second specification adds region dummies, so the effect is read from changes
over time within regions.

    /usr/local/bin/python3 data/environment/ess_pm25_life_satisfaction.py
"""
import csv, os
import numpy as np, pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__)); DATA = os.path.join(HERE, "..")
FILES = [("ESS6e02_7", 6), ("ESS7e02_3", 7), ("ESS10e03_3", 10), ("ESS10SCe03_2", 10), ("ESS11e04_2", 11)]
YEAR = {(6, "DE"): 2012, (6, "FR"): 2013, (6, "IT"): 2013, (7, "DE"): 2014, (7, "FR"): 2014,
        (10, "DE"): 2021, (10, "FR"): 2021, (10, "IT"): 2021, (11, "DE"): 2023, (11, "FR"): 2023, (11, "IT"): 2023}
FR_OLD = {"FR10": "FR1", "FR21": "FRF", "FR22": "FRE", "FR23": "FRD", "FR24": "FRB", "FR25": "FRD", "FR26": "FRC",
          "FR30": "FRE", "FR41": "FRF", "FR42": "FRF", "FR43": "FRC", "FR51": "FRG", "FR52": "FRH", "FR53": "FRI",
          "FR61": "FRI", "FR62": "FRJ", "FR63": "FRI", "FR71": "FRK", "FR72": "FRK", "FR81": "FRJ", "FR82": "FRL", "FR83": "FRM"}

pm = pd.read_csv(os.path.join(HERE, "oecd_pm25_tl2.csv"))
PM = {(r.REF_AREA, int(r.YEAR)): r.PM25_MEAN_POP_UGM3 for r in pm.itertuples()}
pop = {}
for r in csv.reader(open(os.path.join(DATA, "place", "place_tl2.csv"))):
    if r[0] == "pop_share" and r[1] == "IT": pop[r[2]] = float(r[4])
def pm_of(country, region, year):
    y = min(year, 2020)
    if country == "DE": return PM.get((region, y))
    if country == "FR":
        code = FR_OLD.get(region, region[:3] if region.startswith("FR") and len(region) == 4 else None)
        return PM.get((code, y))
    if len(region) == 4: return PM.get((region, y))                      # Italy, NUTS 2
    regs = [k for k in pop if k.startswith(region)]                       # Italy, NUTS 1: population-weighted
    v = [(PM.get((k, y)), pop[k]) for k in regs if PM.get((k, y)) is not None]
    return sum(a * b for a, b in v) / sum(b for _, b in v) if v else None

_mid = pd.read_csv(os.path.join(HERE, "income_decile_midpoints.csv"))          # fetch_income_deciles.py
def deciles(country, year):
    m = _mid[(_mid.country == country) & (_mid.year == year)].sort_values("decile")
    return list(m.midpoint_eur)
MID = {}

rows = []
for d, rnd in FILES:
    use = ["cntry", "region", "stflife", "hinctnta", "agea", "gndr", "eduyrs", "mnactic", "maritalb", "hhmmb", "domicil", "pspwght"]
    df = pd.read_csv(os.path.join(DATA, "ess", "raw", d, d + ".csv"), usecols=lambda c: c in use, low_memory=False)
    df = df[df.cntry.isin(["FR", "DE", "IT"])]
    for r in df.itertuples():
        c = r.cntry; yr = YEAR.get((rnd, c))
        if yr is None or not (0 <= r.stflife <= 10 and 1 <= r.hinctnta <= 10 and 15 <= r.agea <= 100 and r.pspwght > 0): continue
        p = pm_of(c, str(r.region), yr)
        if p is None: continue
        if (c, yr) not in MID: MID[(c, yr)] = deciles(c, yr)
        rows.append(dict(c=c, rnd=rnd, region=str(r.region), ls=r.stflife, pm=p, lninc=np.log(MID[(c, yr)][int(r.hinctnta) - 1]),
                         age=r.agea, fem=int(r.gndr == 2), edu=min(r.eduyrs, 30) if r.eduyrs < 77 else np.nan,
                         act=int(r.mnactic) if r.mnactic < 66 else 9, mar=int(r.maritalb) if getattr(r, "maritalb", 99) < 66 else 9,
                         hh=r.hhmmb if r.hhmmb < 77 else np.nan, dom=int(r.domicil) if r.domicil < 7 else 9, w=r.pspwght))
D = pd.DataFrame(rows).dropna()
D["cr"] = D.c + D.rnd.astype(str)
D["reg"] = D.c + ":" + D.region.map(lambda x: x if len(x) != 4 or not x.startswith("FR") else FR_OLD.get(x, x[:3]))

def ols(D, fe):
    X = pd.DataFrame({"pm": D.pm, "lninc": D.lninc, "age": D.age, "age2": D.age ** 2 / 100, "fem": D.fem, "edu": D.edu, "hh": D.hh})
    for col in ["act", "mar", "dom"] + fe:
        X = X.join(pd.get_dummies(D[col], prefix=col, drop_first=True, dtype=float))
    X.insert(0, "const", 1.0)
    Xv = X.values.astype(float); y = D.ls.values.astype(float); w = D.w.values.astype(float)
    sw = np.sqrt(w); Xw = Xv * sw[:, None]; yw = y * sw
    XtXi = np.linalg.pinv(Xw.T @ Xw); b = XtXi @ Xw.T @ yw; e = yw - Xw @ b
    meat = np.zeros((Xv.shape[1],) * 2)
    for g, ix in D.groupby("reg").indices.items():
        s = Xw[ix].T @ e[ix]; meat += np.outer(s, s)
    G = D.reg.nunique(); n, k = Xv.shape
    V = XtXi @ meat @ XtXi * G / (G - 1) * (n - 1) / (n - k)
    se = np.sqrt(np.diag(V)); cols = list(X.columns)
    return {c: (b[cols.index(c)], se[cols.index(c)]) for c in ("pm", "lninc")}, n, G

out = []
for lab, fe in (("country by round", ["cr"]), ("country by round and region", ["cr", "reg"])):
    res, n, G = ols(D, fe)
    (bp, sp), (bi, si) = res["pm"], res["lninc"]
    out.append([lab, round(bp, 4), round(sp, 4), round(bi, 4), round(si, 4), round(-bp / bi, 4), n, G])
    print(f"{lab}: PM2.5 {bp:+.4f} ({sp:.4f}) per µg/m3 | ln income {bi:+.4f} ({si:.4f}) | income share lost per µg/m3 {-bp / bi:.4f} | n {n}, regions {G}")
with open(os.path.join(HERE, "pm25_valuation.csv"), "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n")
    w.writerow(["# Life satisfaction (0 to 10) on regional PM2.5 (µg/m3) and log equivalised income, ESS rounds 6, 7, 10, 11, France, Germany, Italy; "
                "method of Ferreira and co-authors (2013); script data/environment/ess_pm25_life_satisfaction.py; aggregates only"])
    w.writerow(["fixed_effects", "pm25_coef", "pm25_se", "lninc_coef", "lninc_se", "share_of_income_per_ugm3", "n", "regions"])
    w.writerows(out)
print("mean PM2.5 in the sample", round(D.pm.mean(), 2), "| by country", D.groupby("c").pm.mean().round(2).to_dict())

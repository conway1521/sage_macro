"""Official income distribution figures for the working-age population, EU-SILC 2021:
the income quintile share ratio S80/S20 of people under 65 (ilc_di11), which the
dispersion of the model's income process is fitted to in version 3, and the
in-work at-risk-of-poverty rate (60% of the median, employed aged 18 to 64,
ilc_iw01) and the Gini of equivalised disposable income (ilc_di12), which are
validation figures, never inputs.

    python3 data/validation/income_distribution.py
"""
import csv, json, os, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
def get(ds, q):
    url = f"https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/{ds}?format=JSON&{q}"
    d = json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=120))
    idx = d["dimension"]
    geos = {i: g for g, i in idx["geo"]["category"]["index"].items()}
    times = {i: t for t, i in idx["time"]["category"]["index"].items()}
    ng, nt = len(geos), len(times)
    return {(geos[(int(k) // nt) % ng], times[int(k) % nt]): v for k, v in d["value"].items()}

G = "geo=FR&geo=DE&geo=IT"
rows = []
for year in ("2019", "2021", "2022"):
    for (g, t), v in sorted(get("ilc_di11", f"{G}&time={year}&sex=T&age=Y_LT65").items()):
        rows.append(("s80s20_under65", g, t, v, "ratio", "ilc_di11, age under 65"))
    for (g, t), v in sorted(get("ilc_iw01", f"{G}&time={year}&sex=T&age=Y18-64&wstatus=EMP").items()):
        rows.append(("inwork_poverty60", g, t, round(v / 100, 4), "share", "ilc_iw01, employed aged 18 to 64, 60% of the median"))
    for (g, t), v in sorted(get("ilc_di12", f"{G}&time={year}").items()):
        rows.append(("gini_disposable", g, t, round(v / 100, 4), "index", "ilc_di12, whole population"))
with open(os.path.join(HERE, "income_distribution.csv"), "w", newline="") as f:
    w = csv.writer(f); w.writerow(["indicator", "country", "year", "value", "unit", "source"]); w.writerows(rows)
for r in rows:
    if r[2] == "2021": print(r)

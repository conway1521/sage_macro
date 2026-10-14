"""Decile midpoints of equivalised disposable income, EUR, by country and year (Eurostat ilc_di01, top
cut-offs): P5 for the first decile, the mean of adjacent cut-offs for the second to the ninth, P95 for the
tenth. Read by ess_pm25_life_satisfaction.py.    python3 data/environment/fetch_income_deciles.py"""
import csv, json, os, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
out = []
for c in ("FR", "DE", "IT"):
    for y in (2012, 2013, 2014, 2021, 2023):
        d = json.load(urllib.request.urlopen(f"https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ilc_di01?geo={c}&time={y}&statinfo=TC&unit=EUR", timeout=120))
        idx = d["dimension"]["quant_inc"]["category"]["index"]; pos = d["id"].index("quant_inc")
        stride = 1
        for s in d["size"][pos + 1:]: stride *= s
        val = {k: d["value"].get(str(i * stride)) for k, i in idx.items()}
        tc = [val[f"D{k}"] for k in range(1, 10)]
        mid = [val["P5"]] + [(tc[k - 1] + tc[k]) / 2 for k in range(1, 9)] + [val["P95"]]
        out += [[c, y, k + 1, round(m, 1)] for k, m in enumerate(mid)]
with open(os.path.join(HERE, "income_decile_midpoints.csv"), "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n"); w.writerow(["country", "year", "decile", "midpoint_eur"]); w.writerows(out)
print(len(out), "rows")

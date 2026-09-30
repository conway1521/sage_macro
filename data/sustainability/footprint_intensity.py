"""Greenhouse-gas intensity of household consumption, by country: the E cost side
(E_PLACE_CONCEPT.md, "Sustainability").

Footprint: Eurostat env_ac_ghgfp, greenhouse-gas emission footprints in CO2
equivalent (the FIGARO inter-country input-output application), final use by
households (P31_S14), all products, all origins (WORLD): it includes emissions
embodied in imports, so it covers both "later" and "elsewhere" in the CES frame.
Consumption: Eurostat nama_10_co3_p3, household final consumption expenditure,
current prices, million euro; population: demo_gind, average population. Intensity = footprint / consumption, kg CO2e per
euro. National only; place variation needs a regional source (to find).

    python3 data/sustainability/footprint_intensity.py
"""
import csv, json, os, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
def get(ds, q):
    url = f"https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/{ds}?format=JSON&{q}"
    d = json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=180))
    if "error" in d:
        raise RuntimeError(f"{ds}: {d['error']}")
    times = {i: t for t, i in d["dimension"]["time"]["category"]["index"].items()}
    geos = {i: g for g, i in d["dimension"]["geo" if "geo" in d["id"] else "c_dest"]["category"]["index"].items()}
    nt = len(times)
    return {(geos[int(k) // nt], times[int(k) % nt]): v for k, v in d["value"].items()}

rows = []
pops = {}
for c in ("FR", "DE", "IT"):
    pops.update(get("demo_gind", f"geo={c}&indic_de=AVG&sinceTimePeriod=2015"))
for c in ("FR", "DE", "IT"):
    fp = get("env_ac_ghgfp", f"c_dest={c}&c_orig=WORLD&nace_r2=TOTAL&na_item=P31_S14&unit=THS_T&sinceTimePeriod=2015")
    cons = get("nama_10_co3_p3", f"geo={c}&coicop=TOTAL&unit=CP_MEUR&sinceTimePeriod=2015")
    for (g, t), v in sorted(fp.items()):
        if (c, t) in cons:
            kg_per_eur = v * 1e6 / (cons[(c, t)] * 1e6)   # thousand tonnes -> kg; million euro -> euro
            pc = cons[(c, t)] * 1e6 / pops[(c, t)] if (c, t) in pops else float("nan")
            rows.append((c, t, round(v, 1), round(cons[(c, t)], 1), round(kg_per_eur, 5), round(pc, 1), round(v * 1e3 / pops[(c, t)], 3) if (c, t) in pops else ""))
with open(os.path.join(HERE, "footprint_intensity.csv"), "w", newline="") as f:
    w = csv.writer(f); w.writerow(["country", "year", "hh_footprint_kt_co2e", "hh_consumption_meur", "kg_co2e_per_eur", "hh_consumption_eur_per_head", "t_co2e_per_head"]); w.writerows(rows)
for r in rows:
    if r[1] in ("2019", "2021"):
        print(r)

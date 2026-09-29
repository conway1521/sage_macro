"""The place schema at the OECD TL2 level (E_PLACE_CONCEPT.md, "The standard").

TL2 is NUTS 1 in France and Germany and NUTS 2 in Italy (OECD Regional
Well-Being user's guide, October 2025, Table 1). France: the 13 metropolitan
regions and the overseas regions as one place (FRY; TL2 splits them into five).
Writes data/place/place_tl2.csv in the same schema as place_by_degurba.csv:
indicator, country, place, year, value, source.

    python3 data/place/build_tl2.py

Indicators (Eurostat regional statistics):
  pop_share                 population on 1 January, demo_r_pjanaggr3 (percent of the country)
  tertiary_share_25_64      edat_lfse_04, ED5-8, ages 25 to 64
  unemployment_rate_20_64   lfst_r_lfu3rt, all education levels
  ltu_share                 lfst_r_lfu2ltu, long-term unemployed as percent of the
                            unemployed, ages 20 to 64, mean of the latest two years
  hh_income_per_head        nama_10r_2hhinc, balance of disposable income (B6N) per
                            inhabitant, EUR, latest year
"""
import csv, json, os, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
REGIONS = {
    "FR": ["FR1", "FRB", "FRC", "FRD", "FRE", "FRF", "FRG", "FRH", "FRI", "FRJ", "FRK", "FRL", "FRM", "FRY"],
    "DE": ["DE1", "DE2", "DE3", "DE4", "DE5", "DE6", "DE7", "DE8", "DE9", "DEA", "DEB", "DEC", "DED", "DEE", "DEF", "DEG"],
    "IT": ["ITC1", "ITC2", "ITC3", "ITC4", "ITH1", "ITH2", "ITH3", "ITH4", "ITH5", "ITI1", "ITI2", "ITI3", "ITI4",
           "ITF1", "ITF2", "ITF3", "ITF4", "ITF5", "ITF6", "ITG1", "ITG2"],
}


def get(ds, **kw):
    q = "&".join(f"{k}={v}" for k, vs in kw.items() for v in (vs if isinstance(vs, list) else [vs]))
    url = f"https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/{ds}?format=JSON&{q}"
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            d = json.load(urllib.request.urlopen(req, timeout=180))
            break
        except Exception:
            if attempt == 3:
                raise
            time.sleep(5 * (attempt + 1))
    if "error" in d:
        raise RuntimeError(f"{ds}: {d['error']}")
    dims, sz = d["id"], d["size"]
    lab = {k: {i: v for v, i in d["dimension"][k]["category"]["index"].items()} for k in dims}
    out = []
    for flat, val in d["value"].items():
        f = int(flat); co = []
        for s in reversed(sz):
            co.append(f % s); f //= s
        out.append(({k: lab[k][c] for k, c in zip(dims, co[::-1])}, val))
    return out


def by_geo_year(rows):
    t = {}
    for lab, v in rows:
        t.setdefault(lab["geo"], {})[int(lab["time"])] = v
    return t


rows_out = []
allgeo = [g for c in REGIONS for g in REGIONS[c]]


def emit(ind, table, src, years=1):
    for c, regs in REGIONS.items():
        for g in regs:
            ys = sorted(table.get(g, {}))
            if not ys:
                continue
            use = ys[-years:]
            v = sum(table[g][y] for y in use) / len(use)
            rows_out.append((ind, c, g, use[-1], round(v, 4), src))


pop = by_geo_year(get("demo_r_pjanaggr3", geo=allgeo, sex="T", age="TOTAL", unit="NR", sinceTimePeriod=2021))
for c, regs in REGIONS.items():
    last = {g: pop[g][max(pop[g])] for g in regs if g in pop}
    tot = sum(last.values())
    for g, v in last.items():
        rows_out.append(("pop_share", c, g, max(pop[g]), round(100 * v / tot, 4), "demo_r_pjanaggr3"))
emit("tertiary_share_25_64", by_geo_year(get("edat_lfse_04", geo=allgeo, sex="T", isced11="ED5-8", age="Y25-64",
                                              unit="PC", sinceTimePeriod=2021)), "edat_lfse_04")
emit("unemployment_rate_20_64", by_geo_year(get("lfst_r_lfu3rt", geo=allgeo, sex="T", isced11="TOTAL", age="Y20-64",
                                                 unit="PC", sinceTimePeriod=2021)), "lfst_r_lfu3rt")
emit("ltu_share", by_geo_year(get("lfst_r_lfu2ltu", geo=allgeo, sex="T", isced11="TOTAL", age="Y20-64",
                                  unit="PC_UNE", sinceTimePeriod=2021)), "lfst_r_lfu2ltu", years=2)
emit("hh_income_per_head", by_geo_year(get("nama_10r_2hhinc", geo=allgeo, unit="EUR_HAB", na_item="B6N",
                                           direct="BAL", sinceTimePeriod=2018)), "nama_10r_2hhinc")

with open(os.path.join(HERE, "place_tl2.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["indicator", "country", "place", "year", "value", "source"])
    w.writerows(rows_out)
for c, regs in REGIONS.items():
    have = {r[0] for r in rows_out if r[1] == c}
    missing = [(r[0], r[2]) for r in rows_out if False]
    counts = {ind: sum(1 for r in rows_out if r[0] == ind and r[1] == c) for ind in sorted(have)}
    print(c, len(regs), "regions |", counts)

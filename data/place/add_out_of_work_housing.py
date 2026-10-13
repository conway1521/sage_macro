"""Rows added to the two place tables for the base with the state out of work (V3_START.md section 92).

  low_work_intensity            people under 65 in households with very low work intensity, percent, 2023
                                (Eurostat ilc_lvhl23n by degree of urbanisation, ilc_lvhl21n by region)
  housing_cost_burden_median    median share of housing costs in disposable household income, percent, 2023
                                (Eurostat ilc_lvho08b, by degree of urbanisation only: France publishes nothing by region)

The existing rows are left as they are. Run once: python3 add_out_of_work_housing.py
"""
import csv, json, os, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
YEAR = "2023"

def get(ds, **kw):
    q = "&".join(f"{k}={v}" for k, vs in kw.items() for v in (vs if isinstance(vs, list) else [vs]))
    d = json.load(urllib.request.urlopen(f"https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/{ds}?{q}", timeout=180))
    dims, sz = d["id"], d["size"]
    lab = {k: {i: v for v, i in d["dimension"][k]["category"]["index"].items()} for k in dims}
    out = []
    for flat, val in d["value"].items():
        f, co = int(flat), []
        for s in reversed(sz):
            co.append(f % s); f //= s
        out.append(({k: lab[k][c] for k, c in zip(dims, co[::-1])}, val))
    return out

def rows_of(path):
    with open(path) as f:
        return list(csv.reader(f))

def append(path, new):
    old = {(r[0], r[1], r[2], r[3]) for r in rows_of(path)[1:]}
    add = [r for r in new if (r[0], r[1], r[2], str(r[3])) not in old]
    with open(path, "a", newline="") as f:
        csv.writer(f, lineterminator="\n").writerows(add)
    print(os.path.basename(path), "rows added:", len(add))

deg = os.path.join(HERE, "place_by_degurba.csv")
new = []
for ind, ds, kw in (("low_work_intensity", "ilc_lvhl23n", {"unit": "PC"}), ("housing_cost_burden_median", "ilc_lvho08b", {})):
    for k, v in get(ds, geo=["FR", "DE", "IT"], time=YEAR, **kw):
        new.append([ind, k["geo"], k["deg_urb"], YEAR, v, ds])
append(deg, sorted(new))

tl2 = os.path.join(HERE, "place_tl2.csv")
places = sorted({(r[1], r[2]) for r in rows_of(tl2)[1:] if r[0] == "pop_share"})
got = {k["geo"]: v for k, v in get("ilc_lvhl21n", geo=[p for _, p in places], time=YEAR)}
missing = [p for _, p in places if p not in got]
print("regions without a", YEAR, "figure:", missing)
append(tl2, [["low_work_intensity", c, p, YEAR, got[p], "ilc_lvhl21n"] for c, p in places if p in got])

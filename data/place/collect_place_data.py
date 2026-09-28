"""Place feasibility data: Eurostat indicators by degree of urbanisation.

    python3 data/place/collect_place_data.py

Writes data/place/place_by_degurba.csv (indicator, country, place, year, value,
source) for France, Germany and Italy. DEG1 = cities, DEG2 = towns and suburbs,
DEG3 = rural areas. Every value is downloaded from the Eurostat API; nothing is
typed by hand. Feasibility study for E_PLACE_CONCEPT.md.
"""
import csv, json, os, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
GEOS = ["FR", "DE", "IT"]
PLACES = ["DEG1", "DEG2", "DEG3"]


def get(ds, **kw):
    q = "&".join(f"{k}={v}" for k, vs in kw.items() for v in (vs if isinstance(vs, list) else [vs]))
    url = f"https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/{ds}?{q}"
    d = json.load(urllib.request.urlopen(url, timeout=180))
    dims, sz = d["id"], d["size"]
    lab = {k: {i: v for v, i in d["dimension"][k]["category"]["index"].items()} for k in dims}
    out = []
    for flat, val in d["value"].items():
        f = int(flat); co = []
        for s in reversed(sz):
            co.append(f % s); f //= s
        out.append(({k: lab[k][c] for k, c in zip(dims, co[::-1])}, val))
    return out


ROWS = []


def add(ind, ds, year, place_key="deg_urb", place_map=None, transform=None, **kw):
    """Fetch ds for the three countries, keep one value per country and place."""
    try:
        obs = get(ds, geo=GEOS, time=year, **kw)
    except Exception as e:
        print(f"  {ind}: {ds} failed ({e})"); return
    got = {}
    for k, v in obs:
        p = k.get(place_key)
        if place_map: p = place_map.get(p)
        if p not in PLACES: continue
        got.setdefault((k["geo"], p), []).append(v)
    for (g, p), vs in sorted(got.items()):
        if len(vs) != 1:
            print(f"  {ind}: {g} {p} has {len(vs)} values, check filters"); continue
        v = transform(vs[0]) if transform else vs[0]
        ROWS.append(dict(indicator=ind, country=g, place=p, year=year, value=v, source=ds))


# population and composition
add("pop_share", "ilc_lvho01", "2023", unit="PC", building="TOTAL", rskpovth="TOTAL")
add("tertiary_share_25_64", "edat_lfs_9913", "2015", unit="PC", sex="T", age="Y25-64", isced11="ED5-8")
add("tertiary_share_25_64", "edat_lfs_9913", "2023", unit="PC", sex="T", age="Y25-64", isced11="ED5-8")
# access to work
add("unemployment_rate_20_64", "lfst_r_urgau", "2023", unit="PC", sex="T", age="Y20-64")
# Quarterly transition probabilities (experimental statistics), published by
# degree of urbanisation for 2011 to 2018 only: the four latest years are kept.
for yr in ("2015", "2016", "2017", "2018"):
    add("q_unemp_to_emp_25_54", "lfsi_long_e03", yr, unit="PC_UNE", age="Y25-54")
    add("q_emp_to_unemp_25_54", "lfsi_long_e04", yr, unit="PC_EMP", age="Y25-54")
# mean one-way commuting time of those who commute (duration MN_GE1, unit MN)
add("commute_mean_minutes", "lfso_19plwk28", "2019", unit="MN", sex="T", age="Y20-64", isced11="TOTAL", duration="MN_GE1")
for ed in ("ED0-2", "ED3_4", "ED5-8"):
    add(f"commute_mean_minutes_{ed}", "lfso_19plwk28", "2019", unit="MN", sex="T", age="Y20-64", isced11=ed, duration="MN_GE1")
# conversion: income, broadband, services
add("median_income_eur", "ilc_di17", "2023", unit="EUR", statinfo="MED_EI", sex="T", age="Y18-64")
add("internet_access_households", "isoc_ci_in_h", "2023", place_key="hhtyp",
    place_map={"HH_DEG1": "DEG1", "HH_DEG2": "DEG2", "HH_DEG3": "DEG3"}, unit="PC_HH")
add("broadband_households", "isoc_ci_it_h", "2021", place_key="hhtyp",
    place_map={"HH_DEG1": "DEG1", "HH_DEG2": "DEG2", "HH_DEG3": "DEG3"}, indic_is="H_BROAD", unit="PC_HH")
add("unmet_medical_too_far", "hlth_silc_21", "2023", unit="PC", sex="T", age="Y_GE16", reason="TFAR")
add("unmet_medical_any_access", "hlth_silc_21", "2023", unit="PC", sex="T", age="Y_GE16", reason="TXP_TFAR_WLIST")
# community
add("formal_volunteering", "ilc_scp20", "2015", acl00="AC41A", quant_inc="TOTAL", hhcomp="TOTAL", unit="PC")
add("formal_volunteering", "ilc_scp20", "2022", acl00="AC41A", quant_inc="TOTAL", hhcomp="TOTAL", unit="PC")
add("someone_to_ask_for_help", "ilc_scp16", "2015", quant_inc="TOTAL", hhcomp="TOTAL", unit="PC")
add("trust_in_others", "ilc_pw04", "2022", statinfo="AVG", unit="RTG", quant_inc="TOTAL", hhcomp="TOTAL", domain="OTH")
# amenities and wellbeing
add("pollution_grime", "ilc_mddw05", "2023", unit="PC", rskpovth="TOTAL")
add("life_satisfaction", "ilc_pw02", "2022", statinfo="AVG", unit="RTG", quant_inc="TOTAL", hhcomp="TOTAL", life_sat="LIFE")

out = os.path.join(HERE, "place_by_degurba.csv")
with open(out, "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=["indicator", "country", "place", "year", "value", "source"])
    w.writeheader(); w.writerows(ROWS)
print(f"wrote {len(ROWS)} rows to {out}")

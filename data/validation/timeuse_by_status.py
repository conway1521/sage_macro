"""Organisational work, informal help and participatory activities by labour status,
from the harmonised time-use surveys (Eurostat tus_00selfstat, HETUS 2000 and 2010).

A VALIDATION table, never an input. It bears on the model's participation rule for
the unemployed (`unemployed_ratio`, from the twelve-month survey measure): on a diary
day the unemployed take part in organisational work about as often as the full-time
employed. Two measures of the same behaviour that disagree; see V3_START.md.

    python3 data/validation/timeuse_by_status.py
"""
import csv, json, os, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
url = ("https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/tus_00selfstat?format=JSON"
       "&geo=FR&geo=DE&geo=IT&sex=T&wstatus=POP&wstatus=EMP_FT&wstatus=EMP_PT&wstatus=UNE"
       "&acl00=AC41&acl00=AC42&acl00=AC43&unit=PTP_RT&unit=TIME_SP")
d = json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=180))
dims, sz = d["id"], d["size"]
lab = {k: {i: v for v, i in d["dimension"][k]["category"]["index"].items()} for k in dims}
name = {k: d["dimension"][k]["category"].get("label", {}) for k in dims}
rows = []
for flat, val in d["value"].items():
    f = int(flat); co = []
    for s in reversed(sz):
        co.append(f % s); f //= s
    L = {k: lab[k][c] for k, c in zip(dims, co[::-1])}
    rows.append((L["geo"], int(L["time"]), L["acl00"], name["acl00"][L["acl00"]], L["wstatus"], L["unit"], val))
rows.sort()
with open(os.path.join(HERE, "timeuse_by_status.csv"), "w", newline="") as fh:
    w = csv.writer(fh); w.writerow(["country", "year", "activity", "activity_label", "status", "unit", "value"]); w.writerows(rows)
# the comparison the model needs: daily participation rate, unemployed over full-time employed
r = {(g, y, a, s): v for g, y, a, _, s, u, v in rows if u == "PTP_RT"}
print("daily participation rate (%), unemployed against full-time employed")
for g in ("FR", "DE", "IT"):
    for y in (2000, 2010):
        for a in ("AC41", "AC42", "AC43"):
            u, e = r.get((g, y, a, "UNE")), r.get((g, y, a, "EMP_FT"))
            if u is not None and e is not None:
                print(f"  {g} {y} {a}: unemployed {u}, full-time {e}, ratio {u / e:.2f}" if e else f"  {g} {y} {a}: unemployed {u}, full-time {e}")

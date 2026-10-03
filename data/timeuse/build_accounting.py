"""The accounting layer, assembled from the pulled numbers (an illustration, not a model input).

    python3 build_accounting.py        (after pull_volunteering_by_status.py)

For a place r:   P_r = (1 - s_r) * p_LF_r + s_r * p_I_r
  P_r     participation of everyone (what the regional data measure)
  s_r     share of the survey population outside the labour force (LFS, ages 15+)
  p_LF_r  participation of the labour force (what the model produces)
  p_I_r   participation of the inactive
Two ways to fill p_I_r, both written to accounting_layer.csv:
  A  age proxy: the inactive of each age band (15-24, 25-64, 65-74, 75+; LFS, by place) take part at the
     NATIONAL EU-SILC 2015 rate of that band (16-24, 25-64, 65-74, 75+). Available for all three countries.
  B  status ratio: p_I_r = rho_r * p_LF_r, where rho_r weights national status rates relative to the labour
     force (IT: ISTAT AVQ 2015; DE: Freiwilligensurvey 2019) by the place's mix of students, retired and other
     inactive (Census 2021). Not available for France (no table by status).
Then p_LF_r = (P_r - s_r p_I_r) / (1 - s_r) under A and P_r / (1 - s_r + s_r rho_r) under B.
P_r: EU-SILC 2015 nationally and by degree of urbanisation (ilc_scp19, ilc_scp20); for TL2 regions the repo's
data/place/volunteering_by_region.csv (DE Freiwilligensurvey 2019, IT ISTAT AVQ 2023-25), read only.
"""
import csv, os
from estat import get, write_csv

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/Users/ali/Desktop/UNI/Paris 8/extra_papers/SAGE/data/place/volunteering_by_region.csv"
REGIONS = {
    "FR": ["FR1", "FRB", "FRC", "FRD", "FRE", "FRF", "FRG", "FRH", "FRI", "FRJ", "FRK", "FRL", "FRM", "FRY"],
    "DE": ["DE1", "DE2", "DE3", "DE4", "DE5", "DE6", "DE7", "DE8", "DE9", "DEA", "DEB", "DEC", "DED", "DEE", "DEF", "DEG"],
    "IT": ["ITC1", "ITC2", "ITC3", "ITC4", "ITH1", "ITH2", "ITH3", "ITH4", "ITH5", "ITI1", "ITI2", "ITI3", "ITI4",
           "ITF1", "ITF2", "ITF3", "ITF4", "ITF5", "ITF6", "ITG1", "ITG2"],
}
EU = list(REGIONS)
CTRY = {g: c for c in REGIONS for g in REGIONS[c] + [c]}
GEO = [g for c in REGIONS for g in [c] + REGIONS[c]]
AGES = ["Y15-24", "Y15-64", "Y15-74", "Y_GE15"]
YEARS = ["2015", "2019", "2024", "2025"]
DEGURBA = ("DEG1", "DEG2", "DEG3")        # degree of urbanisation; "DEG" alone is Thueringen
BAND = {"Y15-24": "Y16-24", "Y25-64": "Y25-64", "Y65-74": "Y65-74", "Y_GE75": "Y_GE75"}   # LFS band -> EU-SILC band

# labour status by place ------------------------------------------------------
L = {}       # (place key, year, age, wstatus) -> thousand
for lab, v, f in get("lfst_r_lfsd2pwc", geo=GEO, sex="T", c_birth="TOTAL", age=AGES, wstatus=["POP", "INAC", "EMP", "UNE"], time=YEARS):
    L[((CTRY[lab["geo"]], lab["geo"] if lab["geo"] not in EU else "national"), lab["time"], lab["age"], lab["wstatus"])] = v
for lab, v, f in get("lfsa_pgauws", geo=EU, sex="T", age=AGES, wstatus=["POP", "INAC", "EMP", "UNE"], time=YEARS,
                     deg_urb=["DEG1", "DEG2", "DEG3"]):
    L[((lab["geo"], lab["deg_urb"]), lab["time"], lab["age"], lab["wstatus"])] = v
places = sorted({k[0] for k in L})


def s_inactive(pl, y):
    return L[(pl, y, "Y_GE15", "INAC")] / L[(pl, y, "Y_GE15", "POP")]


def age_mix(pl, y):
    i = {a: L[(pl, y, a, "INAC")] for a in AGES}
    t = i["Y_GE15"]
    return {"Y15-24": i["Y15-24"] / t, "Y25-64": (i["Y15-64"] - i["Y15-24"]) / t,
            "Y65-74": (i["Y15-74"] - i["Y15-64"]) / t, "Y_GE75": (t - i["Y15-74"]) / t}


# EU-SILC 2015 ---------------------------------------------------------------
S = {}
for lab, v, f in get("ilc_scp19", geo=EU, sex="T", isced11="TOTAL", acl00="AC41A", time="2015", age=["Y_GE16"] + list(BAND.values())):
    S[(lab["geo"], lab["age"])] = v
PD = {(lab["geo"], lab["deg_urb"]): v for lab, v, f in get("ilc_scp20", geo=EU, hhcomp="TOTAL", quant_inc="TOTAL", acl00="AC41A", time="2015")}

# status rates relative to the labour force (national), and the Census 2021 mix of the inactive by place ---
V = {}
with open(os.path.join(HERE, "volunteering_by_status.csv")) as fh:
    for r in csv.DictReader(fh):
        if r["value"]:
            V[(r["indicator"], r["country"], r["group"], str(r["year"]))] = float(r["value"])
C = {}
for lab, v, f in get("cens_21a_r2", geo=GEO, sex="T", age=["Y15-29", "Y30-49", "Y50-64", "Y65-84", "Y_GE85"], wstatus=["EDUC", "INC", "INAC_OTH"]):
    k = (CTRY[lab["geo"]], lab["geo"] if lab["geo"] not in EU else "national")
    C[(k, lab["wstatus"])] = C.get((k, lab["wstatus"]), 0) + v
REL = {}     # country -> {census type: participation relative to the labour force}
# Italy, ISTAT AVQ 2015 (ages 15+, 12 months)
it = lambda g: V[("volunteering_in_associations_12m", "IT", g, "2015")]
REL["IT"] = {"EDUC": it("student") / it("labour force (employed and unemployed)"),
             "INC": it("retired") / it("labour force (employed and unemployed)")}
# homemakers and "other condition" together, weighted by persons
REL["IT"]["INAC_OTH"] = it("homemaker and other condition") / it("labour force (employed and unemployed)")
# Germany, Freiwilligensurvey 2019 (ages 14+): labour-force rate from full-time, part-time, unemployed
de = lambda g: V[("volunteering_12m_FWS", "DE", g, "2019")]
pt = [v for lab, v, f in get("lfsa_eppga", geo="DE", sex="T", age="Y15-64", unit="PC", time="2019")][0] / 100
u = L[(("DE", "national"), "2019", "Y_GE15", "UNE")] / (L[(("DE", "national"), "2019", "Y_GE15", "UNE")] + L[(("DE", "national"), "2019", "Y_GE15", "EMP")])
plf_de = (1 - u) * ((1 - pt) * de("employed full-time") + pt * de("employed part-time or marginal")) + u * de("unemployed")
REL["DE"] = {"EDUC": de("in education") / plf_de, "INC": de("retired") / plf_de, "INAC_OTH": de("not employed, other reasons") / plf_de}


def rho(pl):
    c = pl[0]
    if c not in REL or (pl, "INC") not in C:
        return None
    t = sum(C[(pl, k)] for k in ("EDUC", "INC", "INAC_OTH"))
    return sum(C[(pl, k)] / t * REL[c][k] for k in ("EDUC", "INC", "INAC_OTH"))


# regional participation of everyone, from the repo (read only) ----------------
PR = {}
with open(REPO) as fh:
    for r in csv.DictReader(fh):
        PR[(r["country"], r["place"])] = (float(r["value"]), r["year"], r["source"].split(",")[0])

out = []


def add(ind, pl, grp, y, v, unit, src, st="DERIVED"):
    out.append((ind, pl[0], pl[1], grp, y, round(v, 4), unit, src, st))


for c in EU:
    for k, v in REL.get(c, {}).items():
        add("status_rate_relative_to_labour_force", (c, "national"), {"EDUC": "students", "INC": "retired", "INAC_OTH": "other inactive"}[k],
            "2015" if c == "IT" else "2019", v, "ratio", "ISTAT AVQ 2015" if c == "IT" else "Freiwilligensurvey 2019, labour-force rate built with lfsa_eppga and LFS unemployment")
show = []
for pl in places:
    c = pl[0]
    for y in YEARS:
        if (pl, y, "Y_GE15", "INAC") not in L:
            continue
        s = s_inactive(pl, y)
        mix = age_mix(pl, y)
        pI = sum(mix[a] * S[(c, BAND[a])] for a in BAND)
        add("inactive_share", pl, "Y_GE15", y, 100 * s, "percent of population aged 15+", "LFS (lfst_r_lfsd2pwc, lfsa_pgauws)")
        add("p_inactive_age_proxy", pl, "inactive 15+", y, pI, "percent", "LFS age mix of the inactive x national ilc_scp19 2015 rates by age (method A)")
        add("inactive_contribution_age_proxy", pl, "inactive 15+", y, s * pI, "percentage points of P", "s x p_I (method A)")
        r = rho(pl) if pl[1] not in DEGURBA else rho((c, "national"))
        if r is not None:
            add("rho_inactive_to_labour_force", pl, "inactive 15+", y, r, "ratio",
                "national status ratios x Census 2021 mix of the inactive" + (" (national mix: no census table by degree of urbanisation)" if pl[1] in DEGURBA else "") + " (method B)")
        # which P to close the identity with
        P = None
        if pl[1] == "national" and y == "2015":
            P, psrc = S[(c, "Y_GE16")], "ilc_scp19 2015, ages 16+"
        elif pl[1] in DEGURBA and y == "2015":
            P, psrc = PD[(c, pl[1])], "ilc_scp20 2015, ages 16+"
        elif (c, pl[1]) in PR and ((c == "DE" and y == "2019") or (c == "IT" and y == "2024")):
            P, psrc = PR[(c, pl[1])][0], PR[(c, pl[1])][2] + " (repo volunteering_by_region.csv)"
        if P is None:
            continue
        add("P_everyone", pl, "survey population", y, P, "percent", psrc, "VERIFIED" if "ilc" in psrc else "FROM REPO (not re-verified here)")
        same_scale = "ilc" in psrc      # method A mixes scales when P is not EU-SILC
        if same_scale:
            add("p_labour_force_implied_A", pl, "labour force", y, (P - s * pI) / (1 - s), "percent", "(P - s p_I) / (1 - s), method A")
        if r is not None:
            add("p_labour_force_implied_B", pl, "labour force", y, P / (1 - s + s * r), "percent", "P / (1 - s + s rho), method B")
            add("p_inactive_implied_B", pl, "inactive 15+", y, r * P / (1 - s + s * r), "percent", "rho x p_LF, method B")
        show.append((c, pl[1], y, 100 * s, P, pI, (P - s * pI) / (1 - s) if same_scale else None, r, P / (1 - s + s * r) if r else None))
write_csv(os.path.join(HERE, "accounting_layer.csv"), out)
print("relative rates (inactive type / labour force):", {c: {k: round(v, 2) for k, v in d.items()} for c, d in REL.items()})
print("\nctry place     year  s_I(15+)  P_all  p_I(A)  p_LF(A)  rho(B)  p_LF(B)")
for c, p, y, s, P, pI, a, r, b in show:
    f = lambda x: "    -" if x is None else f"{x:5.2f}" if x < 3 else f"{x:5.1f}"
    print(f"{c}   {p:9s} {y}   {s:5.1f}   {P:5.1f}   {pI:5.1f}   {f(a)}   {f(r)}   {f(b)}")

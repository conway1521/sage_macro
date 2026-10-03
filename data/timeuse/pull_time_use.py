"""TASK 1. The time participation takes, in the model's units.

    python3 pull_time_use.py

Pulls (Eurostat dissemination API, standard library only):
  tus_00selfstat  HETUS waves 2000 and 2010, time spent / participation rate / participation
                  time by self-declared labour status, persons aged 20 to 74
  ilc_scp19       EU-SILC ad hoc modules 2015 and 2022, twelve-month prevalence of formal
                  volunteering (AC41A), informal volunteering (AC42A), active citizenship (AC43A)
  ilc_scp20       the same by degree of urbanisation
  lfsa_eppga      part-time share of employment (the weight used in build_country_table.py)
  demo_pjangroup  population by age, to build a 20 to 74 prevalence
Writes:
  hetus_time_by_status.csv           the diary numbers, in minutes per day
  silc_volunteering_prevalence.csv   the twelve-month prevalences
  qbar_from_data.csv                 time per annual participant as a share of committed time

The model's denominator (data/build_country_table.py, lines 147 to 157): for the employed,
committed time = AC1A + AC3 + AC41 + AC42 (main and second job and related travel, household
and family care, organisational work, informal help), mean minutes per day over all diary
days, full-time and part-time shares combined with the part-time share of employment.
work_share = AC1A / committed. The same denominator is used here for participation time.
"""
import os
from estat import get, hm, status, write_csv, url_for

HERE = os.path.dirname(os.path.abspath(__file__))
EU = ["FR", "DE", "IT"]
ACT = ["AC1A", "AC3", "AC41", "AC42", "AC43"]
WS = ["POP", "EMP_FT", "EMP_PT", "LEAV", "UNE", "EDUC", "HOME", "RET", "OTH"]
# survey year used for the part-time weight: wave 2010 as in build_country_table.py (HETUS_YEAR);
# wave 2000 by the fieldwork years in the Eurostat metadata (FR 1998-99, DE 2001-02, IT 2002-03)
PT_YEAR = {"2010": {"FR": "2010", "DE": "2013", "IT": "2010"},
           "2000": {"FR": "1999", "DE": "2002", "IT": "2003"}}
SRC_TUS = "Eurostat tus_00selfstat (HETUS, ages 20-74)"

# ---------------------------------------------------------------- HETUS --------
tus = get("tus_00selfstat", geo=EU, sex="T", acl00=ACT)
T = {}          # (geo, wave, wstatus, acl00, unit) -> (value, flag)
for L, v, f in tus:
    if isinstance(v, str) and v.startswith(":"):      # ":" with flag u: suppressed, under 25 observations
        continue
    T[(L["geo"], L["time"], L["wstatus"], L["acl00"], L["unit"])] = (v, f)


def minutes(c, w, ws, a):
    """Mean minutes per day over all persons and days: published (hh:mm, whole minutes) and
    precise (participation rate x participation time), None where a cell is suppressed."""
    sp, rt, pt = (T.get((c, w, ws, a, u), (None, "")) for u in ("TIME_SP", "PTP_RT", "PTP_TIME"))
    pub = hm(sp[0]) if sp[0] is not None else None
    prec = rt[0] / 100 * hm(pt[0]) if rt[0] is not None and pt[0] is not None else None
    return pub, prec


rows = []
for c in EU:
    for w in ("2000", "2010"):
        for ws in WS:
            for a in ACT:
                for u, unit in (("TIME_SP", "minutes per day, all persons"), ("PTP_RT", "percent of persons on a diary day"),
                                ("PTP_TIME", "minutes per day, those doing the activity")):
                    v, f = T.get((c, w, ws, a, u), (None, ""))
                    if v is None:
                        rows.append((f"{a}_{u}", c, "national", ws, w, "", unit, SRC_TUS,
                                     "NOT PUBLISHED (suppressed, under 25 observations, or no data)"))
                    else:
                        rows.append((f"{a}_{u}", c, "national", ws, w, hm(v) if u != "PTP_RT" else v, unit, SRC_TUS, status(f)))
                pub, prec = minutes(c, w, ws, a)
                if prec is not None:
                    rows.append((f"{a}_TIME_SP_precise", c, "national", ws, w, round(prec, 3), "minutes per day, all persons",
                                 SRC_TUS + ": PTP_RT x PTP_TIME / 100", "DERIVED"))
write_csv(os.path.join(HERE, "hetus_time_by_status.csv"), rows)

# ---------------------------------------------------------------- EU-SILC ------
AGES = ["Y_GE16", "Y16-24", "Y16-64", "Y20-64", "Y25-64", "Y50-64", "Y65-74", "Y_GE65", "Y_GE75"]
silc = get("ilc_scp19", geo=EU, sex="T", isced11="TOTAL", age=AGES)
P = {}
prow = []
for L, v, f in silc:
    P[(L["geo"], L["time"], L["acl00"], L["age"])] = v
    prow.append((f"prevalence_12m_{L['acl00']}", L["geo"], "national", L["age"], L["time"], v, "percent",
                 "Eurostat ilc_scp19 (EU-SILC ad hoc module)", status(f)))
for L, v, f in get("ilc_scp20", geo=EU, hhcomp="TOTAL", quant_inc="TOTAL"):
    prow.append((f"prevalence_12m_{L['acl00']}", L["geo"], L["deg_urb"], "Y_GE16", L["time"], v, "percent",
                 "Eurostat ilc_scp20 (EU-SILC ad hoc module)", status(f)))
# a 20 to 74 prevalence to match the HETUS population: 20-64 and 65-74 weighted by population, 1 January 2015
pop = {(L["geo"], L["age"]): v for L, v, f in get("demo_pjangroup", geo=EU, sex="T", unit="NR", time="2015",
       age=["Y20-24", "Y25-29", "Y30-34", "Y35-39", "Y40-44", "Y45-49", "Y50-54", "Y55-59", "Y60-64", "Y65-69", "Y70-74"])}
for c in EU:
    young = sum(v for (g, a), v in pop.items() if g == c and a not in ("Y65-69", "Y70-74"))
    old = pop[(c, "Y65-69")] + pop[(c, "Y70-74")]
    for a in ("AC41A", "AC42A", "AC43A"):
        P[(c, "2015", a, "Y20-74")] = (young * P[(c, "2015", a, "Y20-64")] + old * P[(c, "2015", a, "Y65-74")]) / (young + old)
        prow.append((f"prevalence_12m_{a}", c, "national", "Y20-74", "2015", round(P[(c, "2015", a, "Y20-74")], 3), "percent",
                     "ilc_scp19 Y20-64 and Y65-74 weighted by demo_pjangroup 2015", "DERIVED"))
write_csv(os.path.join(HERE, "silc_volunteering_prevalence.csv"), sorted(prow))

# ---------------------------------------------------------------- QBAR ---------
ptshare = {(L["geo"], L["time"]): v / 100 for L, v, f in get(
    "lfsa_eppga", geo=EU, sex="T", age="Y15-64", unit="PC", time=["1999", "2002", "2003", "2010", "2013"])}
DEFS = {"A_AC41": ["AC41"], "B_AC41+AC43": ["AC41", "AC43"], "C_AC41+AC42+AC43": ["AC41", "AC42", "AC43"]}
out, show = [], []


def add(ind, c, grp, w, val, unit, src, st="DERIVED"):
    out.append((ind, c, "national", grp, w, round(val, 5), unit, src, st))


for w in ("2010", "2000"):
    for c in EU:
        pt = ptshare[(c, PT_YEAR[w][c])]
        D = {ws: sum(minutes(c, w, ws, a)[0] for a in ("AC1A", "AC3", "AC41", "AC42")) for ws in ("EMP_FT", "EMP_PT")}
        work = (1 - pt) * minutes(c, w, "EMP_FT", "AC1A")[0] / D["EMP_FT"] + pt * minutes(c, w, "EMP_PT", "AC1A")[0] / D["EMP_PT"]
        Dbar = (1 - pt) * D["EMP_FT"] + pt * D["EMP_PT"]
        add("committed_time_employed_FT", c, "EMP_FT", w, D["EMP_FT"], "minutes per day", SRC_TUS + ": AC1A+AC3+AC41+AC42")
        add("committed_time_employed_PT", c, "EMP_PT", w, D["EMP_PT"], "minutes per day", SRC_TUS + ": AC1A+AC3+AC41+AC42")
        add("part_time_share", c, "employed 15-64", PT_YEAR[w][c], pt, "share", "Eurostat lfsa_eppga", "VERIFIED")
        add("committed_time_employed", c, "employed, FT and PT weighted", w, Dbar, "minutes per day", "FT and PT weighted by lfsa_eppga")
        add("work_share_replicated", c, "employed, FT and PT weighted", w, work, "share of committed time",
            "replicates build_country_table.py work_share")
        p_emp = P[(c, "2015", "AC41A", "Y25-64")] / 100      # the model's participation target population (ages 25 to 64)
        p_pop = P[(c, "2015", "AC41A", "Y20-74")] / 100      # matches the HETUS table population
        p_inf = P[(c, "2015", "AC42A", "Y25-64")] / 100
        for name, acts in DEFS.items():
            # employed basis, exactly parallel to work_share: share by FT and PT, then weighted
            q, tper, tpub = 0.0, 0.0, 0.0
            for ws, wgt in (("EMP_FT", 1 - pt), ("EMP_PT", pt)):
                t = sum(minutes(c, w, ws, a)[1] if minutes(c, w, ws, a)[1] is not None else minutes(c, w, ws, a)[0] for a in acts)
                tper += wgt * t
                tpub += wgt * sum(minutes(c, w, ws, a)[0] for a in acts)
                q += wgt * (t / p_emp) / D[ws]
            add(f"time_all_employed_{name}", c, "employed, FT and PT weighted", w, tper, "minutes per day, all employed",
                SRC_TUS + ": PTP_RT x PTP_TIME")
            add(f"time_per_annual_participant_{name}", c, "employed, FT and PT weighted", w, tper / p_emp,
                "minutes per day per twelve-month participant", "time of all employed / ilc_scp19 AC41A Y25-64 2015")
            add(f"qbar_{name}", c, "employed, FT and PT weighted", w, q, "share of committed time",
                "time per annual participant / (AC1A+AC3+AC41+AC42), FT and PT weighted")
            add(f"qbar_published_minutes_{name}", c, "employed, FT and PT weighted", w, tpub / p_emp / Dbar, "share of committed time",
                "same with the published whole-minute TIME_SP (rounding check)")
            # population basis: all persons 20 to 74 over the 20 to 74 prevalence, same employed denominator
            tp = sum(minutes(c, w, "POP", a)[1] for a in acts)
            add(f"time_all_persons_{name}", c, "POP 20-74", w, tp, "minutes per day, all persons", SRC_TUS + ": PTP_RT x PTP_TIME")
            add(f"qbar_popbasis_{name}", c, "POP 20-74 over employed committed time", w, tp / p_pop / Dbar, "share of committed time",
                "POP time / ilc_scp19 AC41A 20-74 (derived) / employed committed time")
            show.append((w, c, name, tper, p_emp, tper / p_emp, Dbar, q, tp, p_pop, tp / p_pop / Dbar))
        # own-prevalence variant for the widest definition: participants are formal OR informal volunteers.
        # The union lies between max(p41, p42) and p41 + p42; AC43 time has no matching prevalence and stays in the numerator.
        tC = sum((1 - pt if ws == "EMP_FT" else pt) * sum(minutes(c, w, ws, a)[1] or minutes(c, w, ws, a)[0] for a in DEFS["C_AC41+AC42+AC43"])
                 for ws in ("EMP_FT", "EMP_PT"))
        add("qbar_C_union_disjoint", c, "employed, FT and PT weighted", w, tC / (p_emp + p_inf) / Dbar, "share of committed time",
            "C time / (AC41A + AC42A prevalence, Y25-64): participants = formal or informal volunteers, no overlap (lower bound)")
        # days per year on which an annual participant does organisational work, and length of such a day
        for ws in ("EMP_FT", "EMP_PT", "UNE", "RET", "HOME", "EDUC", "POP"):
            rt = T.get((c, w, ws, "AC41", "PTP_RT"), (None, ""))[0]
            ptm = T.get((c, w, ws, "AC41", "PTP_TIME"), (None, ""))[0]
            if rt is not None:
                add("AC41_days_per_year_per_annual_participant", c, ws, w, 365 * rt / 100 / (p_pop if ws in ("POP", "RET") else p_emp), "days per year",
                    "365 x daily participation rate / twelve-month prevalence (Y25-64; Y20-74 for POP and RET)")
            if rt is not None and ptm is not None:
                t = rt / 100 * hm(ptm)
                add("AC41_time_per_annual_participant_by_status", c, ws, w, t / (p_pop if ws in ("POP", "RET") else p_emp),
                    "minutes per day per twelve-month participant",
                    "status time / national prevalence (no prevalence by labour status exists): indicative only")
write_csv(os.path.join(HERE, "qbar_from_data.csv"), out)

print("check, work_share replicated (repo table: FR 0.643232, DE 0.608669, IT 0.725221):")
for r in out:
    if r[0] == "work_share_replicated" and r[4] == "2010":
        print("  ", r[1], r[5])
print("\nwave ctry definition           t_emp  p2564  t/p   Dbar   QBAR  | t_pop  p2074  QBAR_pop")
for w, c, name, t, p, tp, D, q, tpop, pp, qp in show:
    print(f"{w} {c}  {name:18s} {t:6.2f} {p:6.3f} {tp:6.1f} {D:6.1f} {q:6.3f} | {tpop:6.2f} {pp:6.3f} {qp:6.3f}")
for u in (url_for("tus_00selfstat", geo=EU, sex="T", acl00=ACT), url_for("ilc_scp19", geo=EU, sex="T", isced11="TOTAL", age=AGES)):
    print(u)

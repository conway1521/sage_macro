"""Life satisfaction of the working-age inactive against employees on unlimited contracts, by country, from the
European Social Survey: for version 2's wellbeing account, whose state N holds jobless households outside
unemployment (V3_START.md section 136). Same sample, weights and controls as ess_life_satisfaction.py (rounds 6, 7,
10 both editions, 11; ages 20 to 64; post-stratification weights; dummies for the household income decile, the round,
sex and three age groups; HC1 errors). Groups by main activity (mnactic): unemployed not looking for work (4),
permanently sick or disabled (5), retired (6, under 65 by the age limit), housework and care (8), and the four
together; students (2) and others are left out. Raw files in data/ess/raw, not redistributed; aggregates only,
groups under 30 respondents suppressed.

    /usr/local/bin/python3 data/ess/ess_inactive_gaps.py
"""
import csv, os
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FILES = ["ESS6e02_7", "ESS7e02_3", "ESS10e03_3", "ESS10SCe03_2", "ESS11e04_2"]
COUNTRIES = ["FR", "DE", "IT"]
OUT = os.path.join(HERE, "..", "validation", "ess_life_satisfaction_inactive.csv")
GROUPS = {4: "not looking", 5: "sick or disabled", 6: "retired under 65", 8: "housework and care"}

def num(x):
    try:
        return float(x)
    except ValueError:
        return float("nan")

rows = {c: [] for c in COUNTRIES}
for d in FILES:
    with open(os.path.join(HERE, "raw", d, d + ".csv"), newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            c = r["cntry"]
            if c not in COUNTRIES: continue
            ls, act, rel, ctr = num(r["stflife"]), num(r["mnactic"]), num(r["emplrel"]), num(r["wrkctra"])
            inc, age, w, sex = num(r["hinctnta"]), num(r["agea"]), num(r["pspwght"]), num(r["gndr"])
            if not (0 <= ls <= 10 and 20 <= age <= 64 and 1 <= inc <= 10 and w > 0 and sex in (1, 2)): continue
            if act == 1 and rel == 1 and ctr == 1:
                g = "unlimited"
            elif act in GROUPS:
                g = GROUPS[int(act)]
            else:
                continue
            rows[c].append((ls, g, int(inc), r["essround"], int(sex), 0 if age < 35 else 1 if age < 50 else 2, w))

def wls(R, dummies):
    n = len(R); y = np.array([r[0] for r in R]); w = np.array([r[6] for r in R])
    rounds = sorted({r[3] for r in R})
    cols = [np.ones(n)] + dummies
    cols += [np.array([r[2] == k for r in R], float) for k in range(2, 11)]
    cols += [np.array([r[3] == k for r in R], float) for k in rounds[1:]]
    cols += [np.array([r[4] == 2 for r in R], float)] + [np.array([r[5] == k for r in R], float) for k in (1, 2)]
    X = np.column_stack(cols); sw = np.sqrt(w); Xw = X * sw[:, None]; yw = y * sw
    XtX_inv = np.linalg.inv(Xw.T @ Xw); b = XtX_inv @ Xw.T @ yw; e = yw - Xw @ b
    meat = (Xw * e[:, None]).T @ (Xw * e[:, None]); V = XtX_inv @ meat @ XtX_inv * n / (n - X.shape[1])
    return b, np.sqrt(np.diag(V)), n

out = []
for c in COUNTRIES:
    R = rows[c]
    # each group against the unlimited, the groups separately
    names = [g for g in GROUPS.values() if sum(r[1] == g for r in R) >= 30]
    b, se, n = wls(R, [np.array([r[1] == g for r in R], float) for g in names])
    for k, g in enumerate(names):
        out.append([c, "gap at the same income decile", g, round(float(b[k + 1]), 3), round(float(se[k + 1]), 3), sum(r[1] == g for r in R)])
    for g in GROUPS.values():
        if g not in names: out.append([c, "gap at the same income decile", g, "suppressed", "", "under 30"])
    # the four together
    b, se, n = wls(R, [np.array([r[1] != "unlimited" for r in R], float)])
    out.append([c, "gap at the same income decile", "inactive, the four together", round(float(b[1]), 3), round(float(se[1]), 3), sum(r[1] != "unlimited" for r in R)])

with open(OUT, "w", newline="") as f:
    wr = csv.writer(f, lineterminator="\n")
    wr.writerow(["# European Social Survey rounds 6, 7, 10, 11; ages 20 to 64; life satisfaction 0 to 10; the working-age inactive by main activity against employees on unlimited contracts; aggregates only, groups under 30 suppressed. Script: data/ess/ess_inactive_gaps.py"])
    wr.writerow(["country", "statistic", "group", "value", "se", "n"])
    wr.writerows(out)
for r in out: print(*r)

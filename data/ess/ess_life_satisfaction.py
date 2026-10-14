"""Life satisfaction of the unemployed and of employees on limited contracts, against employees on
unlimited contracts, by country, from the European Social Survey: the data test for A's wellbeing
side (DIMENSIONS_SPEC.md, phase 1 scope). Raw files in data/ess/raw, not redistributed; only the
aggregates written here are committed.

Life satisfaction is stflife (0 to 10). Ages 20 to 64. Groups: employees with an unlimited contract
(mnactic 1, emplrel 1, wrkctra 1), employees with a limited contract (wrkctra 2), the unemployed
looking for work (mnactic 3). Weighted least squares with post-stratification weights (pspwght),
by country, rounds 6, 7, 10 (both editions) and 11 pooled, with dummies for the household income
decile (hinctnta), the round, sex and three age groups; heteroskedasticity-robust standard errors
(HC1). The coefficients are gaps in life-satisfaction points at the same income decile; the raw
weighted means are written beside them.

    /usr/local/bin/python3 data/ess/ess_life_satisfaction.py
"""
import csv, os
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FILES = ["ESS6e02_7", "ESS7e02_3", "ESS10e03_3", "ESS10SCe03_2", "ESS11e04_2"]
COUNTRIES = ["FR", "DE", "IT"]
OUT = os.path.join(HERE, "..", "validation", "ess_life_satisfaction.csv")

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
            if act == 1 and rel == 1 and ctr in (1, 2):
                g = "unlimited" if ctr == 1 else "limited"
            elif act == 3:
                g = "unemployed"
            else:
                continue
            rows[c].append((ls, g, int(inc), r["essround"], int(sex), 0 if age < 35 else 1 if age < 50 else 2, w))

out = []
for c in COUNTRIES:
    R = rows[c]; n = len(R)
    y = np.array([r[0] for r in R]); w = np.array([r[6] for r in R])
    rounds = sorted({r[3] for r in R})
    cols = [np.ones(n), np.array([r[1] == "unemployed" for r in R], float), np.array([r[1] == "limited" for r in R], float)]
    cols += [np.array([r[2] == k for r in R], float) for k in range(2, 11)]
    cols += [np.array([r[3] == k for r in R], float) for k in rounds[1:]]
    cols += [np.array([r[4] == 2 for r in R], float)] + [np.array([r[5] == k for r in R], float) for k in (1, 2)]
    X = np.column_stack(cols)
    sw = np.sqrt(w); Xw = X * sw[:, None]; yw = y * sw
    XtX_inv = np.linalg.inv(Xw.T @ Xw)
    b = XtX_inv @ Xw.T @ yw
    e = yw - Xw @ b
    meat = (Xw * e[:, None]).T @ (Xw * e[:, None])
    V = XtX_inv @ meat @ XtX_inv * n / (n - X.shape[1])
    se = np.sqrt(np.diag(V))
    for g in ("unlimited", "limited", "unemployed"):
        m = np.array([r[1] == g for r in R])
        out.append([c, "mean", g, round(float(np.average(y[m], weights=w[m])), 3), "", int(m.sum())])
    out.append([c, "gap at the same income decile", "unemployed", round(float(b[1]), 3), round(float(se[1]), 3), n])
    out.append([c, "gap at the same income decile", "limited", round(float(b[2]), 3), round(float(se[2]), 3), n])
    out.append([c, "one income decile higher, mean step", "income", round(float(np.mean(np.diff(np.concatenate([[0.0], b[3:12]])))), 3), "", n])

with open(OUT, "w", newline="") as f:
    wr = csv.writer(f, lineterminator="\n")
    wr.writerow(["# European Social Survey rounds 6, 7, 10, 11; ages 20 to 64; life satisfaction 0 to 10 (stflife); against employees on unlimited contracts; aggregates only. Script: data/ess/ess_life_satisfaction.py"])
    wr.writerow(["country", "statistic", "group", "value", "se", "n"])
    wr.writerows(out)
for r in out: print(*r)

"""Version 2, stage 1b, the data step (V2_BUILD_PLAN.md; paper/sage_v2_design.md, section 3.2).

1. The stock of the unemployed by duration of unemployment (Eurostat lfsa_ugad, thousand persons, ages 15 to 74,
   both sexes) and the quarterly labour-market flows (lfsi_long_q, seasonally adjusted, as shares of the origin
   state), averaged over 2015 to 2019 and 2022 to 2024 (years outside the pandemic).
2. A homogeneous duration model at a quarterly period: spells start at the beginning of a quarter, the survey
   records completed months, so the bands below three months are the first quarter and every other band begins
   and ends on a quarter (3-5 months: quarter 2; 6-11: 3-4; 12-17: 5-6; 18-23: 7-8; 24-47: 9-16; 48+: 17 on).
   Five exit hazards, constant within their groups (quarter 1, quarter 2, quarters 3-4, quarters 5-8, 9 on), fitted
   by least squares on the seven band shares in a steady state (stock at duration d = inflow x survival to d).
   The fit is over-identified (seven shares, five hazards; the shares sum to one, so six free) and its residuals
   are written. The total exit is split between work and inactivity by the quarterly flows' shares, assumed the
   same at every duration (a stated assumption).
These are the starting values of the fit in the solved model; selection among survivors is added there.

    /usr/local/bin/python3 data/labour/duration_flows.py
"""
import json, os, subprocess
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw"); os.makedirs(RAW, exist_ok=True)
GEOS = ["FR", "DE", "IT"]
YEARS = [str(y) for y in list(range(2015, 2020)) + [2022, 2023, 2024]]
API = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/"

def fetch(ds, query, name):
    path = os.path.join(RAW, name + ".json")
    if not os.path.exists(path):
        subprocess.run(["curl", "-s", "-o", path, API + ds + "?format=JSON&" + query], check=True)
    return json.load(open(path))

def cube(d):
    ids = d["id"]; size = d["size"]; cat = {k: d["dimension"][k]["category"]["index"] for k in ids}
    out = {}
    for flat, v in d["value"].items():
        i = int(flat); key = []
        for k, n in zip(reversed(ids), reversed(size)):
            key.append(i % n); i //= n
        key = list(reversed(key))
        lab = {k: [c for c, j in cat[k].items() if j == key[n]][0] for n, k in enumerate(ids)}
        out[tuple(lab[k] for k in ids)] = v
    return ids, out

def lsq(res, x0, lo=1e-4, hi=0.99, iters=200):
    """Least squares by damped Gauss-Newton (Levenberg-Marquardt) with a numerical Jacobian, within bounds."""
    x = np.array(x0, float); lam = 1e-3; r = res(x)
    for _ in range(iters):
        J = np.column_stack([(res(np.clip(x + e, lo, hi)) - r) / 1e-7 for e in np.eye(len(x)) * 1e-7])
        A = J.T @ J; g = J.T @ r
        step = np.linalg.solve(A + lam * np.diag(np.diag(A) + 1e-12), -g)
        xn = np.clip(x + step, lo, hi); rn = res(xn)
        if rn @ rn < r @ r:
            x, r, lam = xn, rn, lam / 3
            if np.max(np.abs(step)) < 1e-10: break
        else:
            lam *= 5
    return x, r

BANDS = ["M_LT1", "M1-2", "M3-5", "M6-11", "M12-17", "M18-23", "M24-47", "M_GE48"]
GROUPS = [("q1", ["M_LT1", "M1-2"], (1, 1)), ("q2", ["M3-5"], (2, 2)), ("q3-4", ["M6-11"], (3, 4)),
          ("q5-6", ["M12-17"], (5, 6)), ("q7-8", ["M18-23"], (7, 8)), ("q9-16", ["M24-47"], (9, 16)), ("q17+", ["M_GE48"], (17, 400))]
HAZ = [(1, 1), (2, 2), (3, 4), (5, 8), (9, 400)]          # the quarters each hazard covers

def shares_model(h):
    hq = np.zeros(401)
    for (a, b), x in zip(HAZ, h):
        hq[a:b + 1] = x
    S = np.ones(401)
    for q in range(2, 401):
        S[q] = S[q - 1] * (1 - hq[q - 1])
    st = np.array([S[a:b + 1].sum() for _, _, (a, b) in GROUPS])
    return st / st.sum()

rows = []
for g in GEOS:
    du = fetch("lfsa_ugad", f"geo={g}&sex=T&age=Y15-74&unit=THS_PER&" + "&".join("time=" + y for y in YEARS), f"lfsa_ugad_{g}")
    ids, v = cube(du)
    di = ids.index("duration"); ti = ids.index("time")
    stock = {b: np.mean([val for k, val in v.items() if k[di] == b]) for b in BANDS}
    data = np.array([sum(stock[b] for b in bands) for _, bands, _ in GROUPS]); data = data / data.sum()
    # the hazards may not rise with duration (h1 >= h2 >= ... >= h5): reported durations heap at a year, which an
    # unconstrained fit absorbs by a hazard near zero in quarters 3-4 (Italy) or one that rises after a year (France)
    mono = lambda y: np.cumprod(y)                    # y[0] = h1, y[k] in (0, 1] the ratio of each hazard to the one before
    yy, resid = lsq(lambda y: np.log(shares_model(mono(y))) - np.log(data), [0.4, 0.9, 0.7, 0.8, 0.6], lo=1e-4, hi=1.0)
    h = mono(yy); model = shares_model(h)
    hu, residu = lsq(lambda x: np.log(shares_model(x)) - np.log(data), [0.3, 0.25, 0.2, 0.15, 0.1])
    fl = fetch("lfsi_long_q", f"geo={g}&sex=T&s_adj=SA&" + "&".join(f"time={y}-Q{q}" for y in YEARS for q in range(1, 5)), f"lfsi_long_q_{g}")
    idf, vf = cube(fl)
    ui, wi = idf.index("unit"), idf.index("wstatus")
    def avg(unit, w):
        xs = [val for k, val in vf.items() if k[ui] == unit and k[wi] == w]
        return np.mean(xs) / 100 if xs else float("nan")
    ue, ui_, ee, ei, ie, iu = avg("PC_UNE", "UNE_EMP"), avg("PC_UNE", "UNE_INAC"), avg("PC_EMP", "EMP_UNE"), avg("PC_EMP", "EMP_INAC"), avg("PC_INAC", "INAC_EMP"), avg("PC_INAC", "INAC_UNE")
    work_share = ue / (ue + ui_)
    for (name, _, _), d, m in zip(GROUPS, data, model):
        rows.append([g, "band share", name, round(d, 5), round(m, 5)])
    for (a, b), x in zip(HAZ, h):
        rows.append([g, "exit hazard a quarter", f"q{a}" + (f"-{b}" if b != a and b < 400 else ("+" if b >= 400 else "")), round(x, 5), ""])
    rows.append([g, "quarterly flow", "unemployed to employed", round(ue, 5), ""]); rows.append([g, "quarterly flow", "unemployed to inactive", round(ui_, 5), ""])
    rows.append([g, "quarterly flow", "employed to unemployed", round(ee, 5), ""]); rows.append([g, "quarterly flow", "employed to inactive", round(ei, 5), ""])
    rows.append([g, "quarterly flow", "inactive to employed", round(ie, 5), ""]); rows.append([g, "quarterly flow", "inactive to unemployed", round(iu, 5), ""])
    rows.append([g, "split", "share of exits to work", round(work_share, 4), ""])
    # the split read through Elsby, Hobijn and Sahin (2015): reversals between unemployment and inactivity are mostly
    # spurious and do not end the reported spell, so the exit the durations imply is close to the flow into work
    # alone; exits to work at the flows' rate, and only the rest of the duration-based exit to genuine inactivity
    mean_exit_d = float(np.sum(model * np.array([h[0], h[1], h[2], h[3], h[3], h[4], h[4]])))
    rows.append([g, "split", "share of exits to work (churn-adjusted)", round(min(ue / mean_exit_d, 1.0), 4), ""])
    rows.append([g, "fit", "largest log residual", round(float(np.max(np.abs(resid))), 4), ""])
    rows.append([g, "fit, unconstrained (for comparison)", "hazards", " ".join(str(round(x, 4)) for x in hu), ""])
    rows.append([g, "fit, unconstrained (for comparison)", "largest log residual", round(float(np.max(np.abs(residu))), 4), ""])
    mean_exit = float(np.sum(model * np.array([h[0], h[1], h[2], h[3], h[3], h[4], h[4]])))
    rows.append([g, "check", "mean exit hazard of the stock (model) against the quarterly flow out of unemployment", round(mean_exit, 4), round(ue + ui_, 4)])
    print(g, "hazards (monotone)", np.round(h, 4), "unconstrained", np.round(hu, 4), "| largest log residual %.3f (unconstrained %.3f) | share" % (np.max(np.abs(resid)), np.max(np.abs(residu))) + " of exits to work %.3f | flow out of unemployment %.3f | data" % (work_share, ue + ui_), np.round(data, 4), "| model", np.round(model, 4))

out = os.path.join(HERE, "duration_hazards.csv")
with open(out, "w") as f:
    f.write("# Eurostat lfsa_ugad and lfsi_long_q (SA), 2015-2019 and 2022-2024; homogeneous quarterly duration fit; script data/labour/duration_flows.py\n")
    f.write("country,statistic,item,value,model\n")
    for r in rows: f.write(",".join(str(x) for x in r) + "\n")
print("wrote", out)

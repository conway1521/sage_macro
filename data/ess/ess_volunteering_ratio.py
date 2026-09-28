"""Volunteering of the unemployed relative to the employed, by country, from the
European Social Survey (raw files in data/ess/raw, not redistributed; only the
aggregates written here are committed).

Rounds 6 and 7 ask wrkorg ("worked in another organisation or association,
last 12 months"). Rounds 10 and 11 ask volunfp ("volunteered for a
not-for-profit or charitable organisation, last 12 months"). Both are yes/no.
Round 10 has a self-completion edition (ESS10SC) for countries that could not
field face to face; both editions are used. Employed: main activity paid work
(mnactic 1). Unemployed: looking for a job (mnactic 3), with not looking (4)
added as a variant. Ages 20 to 64, post-stratification weights (pspwght).

    python3 data/ess/ess_volunteering_ratio.py
"""
import csv, math, os
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
FILES = [("ESS6e02_7", "wrkorg"), ("ESS7e02_3", "wrkorg"), ("ESS10e03_3", "volunfp"),
         ("ESS10SCe03_2", "volunfp"), ("ESS11e04_2", "volunfp")]
COUNTRIES = ["FR", "DE", "IT"]

def share(rows):
    """Weighted share and a standard error from Kish's effective sample size."""
    w = sum(r[0] for r in rows)
    if w == 0: return float("nan"), float("nan"), 0
    p = sum(r[0] * r[1] for r in rows) / w
    neff = w * w / sum(r[0] ** 2 for r in rows)
    return p, math.sqrt(p * (1 - p) / neff), len(rows)

def ratio(pu, su, pe, se):
    r = pu / pe
    return r, r * math.sqrt((su / pu) ** 2 + (se / pe) ** 2) if pu > 0 else float("nan")

cells = defaultdict(list)   # (country, question, round, status) -> [(w, y)]
for d, var in FILES:
    with open(os.path.join(HERE, "raw", d, d + ".csv"), newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            c = r["cntry"]
            if c not in COUNTRIES: continue
            try:
                y, act, age, w = int(r[var]), int(r["mnactic"]), int(r["agea"]), float(r["pspwght"])
            except (ValueError, KeyError):
                continue
            if y not in (1, 2) or not 20 <= age <= 64: continue
            st = {1: "E", 3: "U", 4: "U4"}.get(act)
            if st is None: continue
            key_round = "R" + r["essround"]
            for q, rd in ((var, key_round), (var, "pooled")):
                cells[(c, q, rd, st)].append((w, 1.0 if y == 1 else 0.0))

out = []
for c in COUNTRIES:
    for q in ("wrkorg", "volunfp"):
        rounds = sorted({k[2] for k in cells if k[0] == c and k[1] == q})
        for rd in rounds:
            E = cells[(c, q, rd, "E")]; U = cells[(c, q, rd, "U")]; U4 = cells[(c, q, rd, "U4")]
            if not E or not U: continue
            pe, se, ne = share(E); pu, su, nu = share(U); pa, sa, na_ = share(U + U4)
            r, rse = ratio(pu, su, pe, se); ra, rase = ratio(pa, sa, pe, se)
            out.append(dict(country=c, question=q, round=rd, n_employed=ne, n_unemployed=nu,
                            share_employed=round(pe, 4), share_unemployed=round(pu, 4),
                            ratio=round(r, 3), ratio_se=round(rse, 3),
                            n_unemployed_incl_not_looking=na_, ratio_incl_not_looking=round(ra, 3),
                            ratio_incl_not_looking_se=round(rase, 3)))
with open(os.path.join(HERE, "ess_volunteering_ratio.csv"), "w", newline="") as f:
    wr = csv.DictWriter(f, fieldnames=list(out[0])); wr.writeheader(); wr.writerows(out)
for o in out:
    print(f"{o['country']} {o['question']:8s} {o['round']:7s} E n={o['n_employed']:5d} {o['share_employed']:.3f} | "
          f"U n={o['n_unemployed']:4d} {o['share_unemployed']:.3f} | ratio {o['ratio']:.3f} (se {o['ratio_se']:.3f}) | "
          f"with not looking {o['ratio_incl_not_looking']:.3f} (se {o['ratio_incl_not_looking_se']:.3f})")

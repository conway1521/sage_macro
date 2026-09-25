"""Poor and wealthy hand-to-mouth shares in the US, Survey of Consumer Finances
1989-2022, on the baseline definition of Kaplan, Violante and Weidner (2014,
Brookings Papers on Economic Activity).

The first check is replication: their US baseline pools 1989-2010 and gives
0.138 poor and 0.202 wealthy (Table 5). The second is the update: the same
definition on 2013-2022, to see whether the shares have moved.

Definitions (their section III, applied to the Fed's summary extract variables):
  sample   reference person aged 22-79; drop negative income and households
           whose income is all from self-employment
  income   wages, self-employment, Social Security and pensions, other
           transfers; capital income excluded
  liquid   transaction accounts (LIQ), directly held mutual funds, stocks and
           bonds, minus credit card balances
  illiquid home equity, other real estate net of its debt, retirement accounts,
           cash value of life insurance, CDs, savings bonds
  HtM      pay period of two weeks: liquid balances between zero and half a
           pay period's income (income / 52), or negative and within that
           distance of a credit limit of one month's income
  poor     HtM with illiquid wealth at or below zero; wealthy otherwise
Weights: WGT over all five implicates, which leaves shares unaffected.

    python3 scf_htm.py            (data in ../../data/scf/SCFP<year>.csv)
"""
import csv, os, sys

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data", "scf")
YEARS = [1989, 1992, 1995, 1998, 2001, 2004, 2007, 2010, 2013, 2016, 2019, 2022]
KVW = {"poor": 0.138, "wealthy": 0.202}


def f(row, k):
    v = row.get(k, "")
    return float(v) if v not in ("", None) else 0.0


def shares(year):
    tot = poor = wealthy = 0.0
    with open(os.path.join(DATA, f"SCFP{year}.csv"), newline="") as fh:
        rd = csv.DictReader(fh)
        rd.fieldnames = [c.strip().strip('"').upper() for c in rd.fieldnames]
        for r in rd:
            age = f(r, "AGE")
            if not 22 <= age <= 79:
                continue
            se = f(r, "BUSSEFARMINC")
            y = f(r, "WAGEINC") + se + f(r, "SSRETINC") + f(r, "TRANSFOTHINC")
            if y < 0 or (y > 0 and se >= y):
                continue
            m = f(r, "LIQ") + f(r, "NMMF") + f(r, "STOCKS") + f(r, "BOND") - f(r, "CCBAL")
            a = (f(r, "HOMEEQ") + f(r, "ORESRE") - f(r, "RESDBT") + f(r, "RETQLIQ")
                 + f(r, "CASHLI") + f(r, "CDS") + f(r, "SAVBND"))
            half = y / 52.0
            htm = (0 <= m <= half) or (m < 0 and m <= half - y / 12.0)
            w = f(r, "WGT")
            tot += w
            if htm:
                if a <= 0:
                    poor += w
                else:
                    wealthy += w
    return poor / tot, wealthy / tot


res = {}
print(f"{'year':6s} {'poor':>7s} {'wealthy':>8s} {'total':>7s}")
for yr in YEARS:
    if not os.path.exists(os.path.join(DATA, f"SCFP{yr}.csv")):
        print(yr, "missing"); continue
    p, w = shares(yr)
    res[yr] = (p, w)
    print(f"{yr:<6d} {p:7.3f} {w:8.3f} {p + w:7.3f}")
    sys.stdout.flush()


def pooled(yrs):
    ys = [y for y in yrs if y in res]
    return sum(res[y][0] for y in ys) / len(ys), sum(res[y][1] for y in ys) / len(ys)


p, w = pooled(range(1989, 2011))
print(f"\nmean 1989-2010: poor {p:.3f}, wealthy {w:.3f}  |  KVW Table 5 baseline: poor {KVW['poor']:.3f}, wealthy {KVW['wealthy']:.3f}")
p2, w2 = pooled(range(2010, 2023))
print(f"mean 2010-2022: poor {p2:.3f}, wealthy {w2:.3f}")
p3, w3 = pooled(range(2013, 2023))
print(f"mean 2013-2022: poor {p3:.3f}, wealthy {w3:.3f}")

"""
Weekly hours of those in work by their household's wealth: aggregates only.

For scoping A (DIMENSIONS_SPEC.md, "A, reopened and scoped"): the model's households, where they choose
their hours, work much more when poor than when rich. This reads what the survey says. It follows the
protocol of hfcs_moments.py: run locally on the user database, nothing but aggregate tables leaves the
machine, and a cell with fewer than 30 unweighted persons is suppressed.

    python3 hfcs_hours.py <folder of the wave's user database> <output folder> [countries]

Persons in work (PE0100A == 1) with positive weekly hours in the main job (PE0600), aged 25 to 59 where
age is given (RA0300). Sorted into quarters by their household's deposits (DA2101) and by its net wealth
(DN3001), the quarters formed among these persons within country, with household weights (HW0010). The
mean over the five implicates.
"""
import glob, os, sys
import numpy as np
import pandas as pd

MIN_CELL = 30


def cols_of(path):
    with pd.read_stata(path, iterator=True) as r:
        names = getattr(r, "varlist", None)
        return list(names if names is not None else r.read(1).columns)


def read(path, wanted):
    have = {c.upper(): c for c in cols_of(path)}
    use = [have[w] for w in wanted if w in have]
    df = pd.read_stata(path, columns=use, convert_categoricals=False)
    df.columns = [c.upper() for c in df.columns]
    return df


def find(folder, stem):
    hits = [p for p in glob.glob(os.path.join(folder, "**", "*.dta"), recursive=True) if os.path.basename(p).lower() == stem + ".dta"]
    if not hits:
        raise SystemExit("no " + stem + ".dta under " + folder)
    return hits[0]


def wmean(x, w):
    return float(np.sum(x * w) / np.sum(w))


def quarters(x, w):
    o = np.argsort(x, kind="stable"); cw = np.cumsum(w[o]) / np.sum(w); q = np.empty(len(x), dtype=int)
    q[o] = np.minimum((cw * 4 - 1e-12).astype(int), 3)
    return q


def main():
    folder, out = sys.argv[1], sys.argv[2]
    countries = sys.argv[3].split(",") if len(sys.argv) > 3 else ["FR", "DE", "IT"]
    os.makedirs(out, exist_ok=True)
    rows = {}
    for imp in range(1, 6):
        d = read(find(folder, "d%d" % imp), ["SA0010", "SA0100", "IM0100", "HW0010", "DA2101", "DN3001"])
        if "HW0010" not in d.columns:
            h = read(find(folder, "h%d" % imp), ["SA0010", "SA0100", "HW0010"])
            d = d.merge(h, on=["SA0010", "SA0100"], how="left")
        p = read(find(folder, "p%d" % imp), ["SA0010", "SA0100", "RA0010", "RA0300", "PE0100A", "PE0600", "PA0200"])
        d = d[d["SA0100"].isin(countries)]; p = p[p["SA0100"].isin(countries)]
        m = p.merge(d, on=["SA0010", "SA0100"], how="inner")
        for c in ("PE0100A", "PE0600", "HW0010", "DA2101", "DN3001", "RA0300", "PA0200"):
            if c in m.columns:
                m[c] = pd.to_numeric(m[c], errors="coerce")
        m = m[(m["PE0100A"] == 1) & (m["PE0600"] > 0) & (m["PE0600"] <= 100) & (m["HW0010"] > 0)]
        if "RA0300" in m.columns:
            m = m[(m["RA0300"] >= 25) & (m["RA0300"] <= 59)]
        m["DA2101"] = m["DA2101"].fillna(0.0)
        for c in countries:
            s = m[m["SA0100"] == c]
            if len(s) == 0:
                continue
            w = s["HW0010"].to_numpy(); hrs = s["PE0600"].to_numpy()
            rows.setdefault((c, "all", "all"), []).append((wmean(hrs, w), len(s)))
            for key, col in (("deposits", "DA2101"), ("net_wealth", "DN3001")):
                x = s[col].fillna(0.0).to_numpy(); q = quarters(x, w)
                for k in range(4):
                    sel = q == k
                    rows.setdefault((c, key, "quarter_%d" % (k + 1)), []).append((wmean(hrs[sel], w[sel]) if sel.sum() else np.nan, int(sel.sum())))
            if "PA0200" in s.columns:
                ed = s["PA0200"].to_numpy()
                for nm, sel in (("below_tertiary", ed < 5), ("tertiary", ed >= 5)):
                    rows.setdefault((c, "education", nm), []).append((wmean(hrs[sel], w[sel]) if sel.sum() else np.nan, int(sel.sum())))
    lines = ["country,sort,group,mean_weekly_hours,persons_unweighted"]
    for (c, key, g), v in sorted(rows.items()):
        n = int(np.mean([x[1] for x in v]))
        val = "suppressed" if n < MIN_CELL else "%.2f" % float(np.mean([x[0] for x in v]))
        lines.append("%s,%s,%s,%s,%d" % (c, key, g, val, n))
    open(os.path.join(out, "hours_by_wealth.csv"), "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()

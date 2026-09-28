"""Italy: organised volunteering and non-profit density across the 21 regions and
autonomous provinces.

    python3 data/place/italy_regions.py

Question: does the stock of non-profit institutions (community infrastructure,
measured in 2011, before the volunteering we compare it with) line up with
organised volunteering across regions, and does it survive controls for the
labour market (unemployment) and education (tertiary share)?

Inputs (downloaded into data/place/raw/, not committed):
  istat_volunteering2013_regions.csv  ISTAT SDMX dataflow 85_84_DF_DCSA_VOLON1_6
      ("Volontariato - Regioni e tipo di comuni"), the ad hoc volunteering module
      of the Aspetti della vita quotidiana survey, 2013 and 2023. Used: DATA_TYPE
      PGE15_UAPV (persons 15+ who volunteered in the last 4 weeks, per 100),
      FORM_VOLUNT ORGVOL (organisation-based volunteering).
  istat_avq_associazionismo_regions.csv  ISTAT SDMX dataflow
      83_63_DF_DCCV_AVQ_PERSONE_132 ("Associazionismo - regioni e tipo di
      comune"), annual 2010-2025. Used: DATA_TYPE 14_VOL_ASS (persons 14+ who did
      unpaid work in voluntary associations in the last 12 months), MEASURE HSC
      (per 100). This is the series behind BES indicator 05REL006.
  bes_local/Indicators_NUTS3_Level_Gender_ed.2024_EC_17072024.xlsx  (from
      istat_bes_local_2024.zip) BES dei territori 2024, indicator 05REL008,
      non-profit institutions per 10,000 inhabitants, 2011 and 2015-2021.
  eurostat_lfst_r_lfu3rt_IT.csv  unemployment rate, 15-74, NUTS2, 2021-2023.
  eurostat_edat_lfse_04_IT.csv  share of 25-64 with tertiary education
      (ISCED 5-8), NUTS2, 2021-2023.

Output: data/place/italy_regions.csv (one row per region) and printed
correlations and OLS slopes (pure Python, conventional standard errors).
"""
import csv, math, os, openpyxl

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")

# (name, ISTAT SDMX code, Eurostat NUTS 2021 code, BES row label)
REGIONS = [
    ("Piemonte", "ITC1", "ITC1", "Piemonte"),
    ("Valle d'Aosta", "ITC2", "ITC2", "Valle d'Aosta/Vallée d'Aoste"),
    ("Liguria", "ITC3", "ITC3", "Liguria"),
    ("Lombardia", "ITC4", "ITC4", "Lombardia"),
    ("Bolzano", "ITD1", "ITH1", "Bolzano/Bozen"),
    ("Trento", "ITD2", "ITH2", "Trento"),
    ("Veneto", "ITD3", "ITH3", "Veneto"),
    ("Friuli-Venezia Giulia", "ITD4", "ITH4", "Friuli-Venezia Giulia"),
    ("Emilia-Romagna", "ITD5", "ITH5", "Emilia-Romagna"),
    ("Toscana", "ITE1", "ITI1", "Toscana"),
    ("Umbria", "ITE2", "ITI2", "Umbria"),
    ("Marche", "ITE3", "ITI3", "Marche"),
    ("Lazio", "ITE4", "ITI4", "Lazio"),
    ("Abruzzo", "ITF1", "ITF1", "Abruzzo"),
    ("Molise", "ITF2", "ITF2", "Molise"),
    ("Campania", "ITF3", "ITF3", "Campania"),
    ("Puglia", "ITF4", "ITF4", "Puglia"),
    ("Basilicata", "ITF5", "ITF5", "Basilicata"),
    ("Calabria", "ITF6", "ITF6", "Calabria"),
    ("Sicilia", "ITG1", "ITG1", "Sicilia"),
    ("Sardegna", "ITG2", "ITG2", "Sardegna"),
]


def num(s):
    s = (s or "").strip().replace(",", ".")
    return float(s) if s else None


# (i) volunteering
module = {}
with open(os.path.join(RAW, "istat_volunteering2013_regions.csv"), encoding="utf-8-sig") as fh:
    for r in csv.DictReader(fh):
        if r["DATA_TYPE"] == "PGE15_UAPV" and r["FORM_VOLUNT"] == "ORGVOL":
            module[(r["REF_AREA"], r["TIME_PERIOD"])] = num(r["OBS_VALUE"])
avq = {}
with open(os.path.join(RAW, "istat_avq_associazionismo_regions.csv"), encoding="utf-8-sig") as fh:
    for r in csv.DictReader(fh):
        if r["DATA_TYPE"] == "14_VOL_ASS" and r["MEASURE"] == "HSC":
            avq[(r["REF_AREA"], r["TIME_PERIOD"])] = num(r["OBS_VALUE"])
AVQ_LAST = max(int(y) for (_, y) in avq)

# (ii) non-profit institutions per 10,000 inhabitants
bes = {}
wb = openpyxl.load_workbook(os.path.join(RAW, "bes_local",
        "Indicators_NUTS3_Level_Gender_ed.2024_EC_17072024.xlsx"), read_only=True)
ws = wb.worksheets[0]
head = None
for r in ws.iter_rows(values_only=True):
    if head is None:
        head = list(r); continue
    if r[1] == "05REL008" and r[3] == "Total":
        bes[r[4]] = {h[1:]: num(v) for h, v in zip(head, r) if h and h.startswith("V2")}

# (iii) Eurostat controls, 2021-2023 mean
def eurostat(fname):
    d = {}
    with open(os.path.join(RAW, fname), encoding="utf-8-sig") as fh:
        for r in csv.DictReader(fh):
            d.setdefault(r["geo"], []).append(float(r["OBS_VALUE"]))
    return {g: sum(v) / len(v) for g, v in d.items()}
unemp = eurostat("eurostat_lfst_r_lfu3rt_IT.csv")
tert = eurostat("eurostat_edat_lfse_04_IT.csv")

rows = []
for name, ic, nc, bl in REGIONS:
    last3 = [avq.get((ic, str(y))) for y in (AVQ_LAST - 2, AVQ_LAST - 1, AVQ_LAST)]
    rows.append({
        "region": name, "istat_code": ic, "nuts2021": nc,
        "orgvol_2013": module[(ic, "2013")], "orgvol_2023": module[(ic, "2023")],
        "avq_vol_2013": avq[(ic, "2013")], f"avq_vol_{AVQ_LAST}": avq[(ic, str(AVQ_LAST))],
        f"avq_vol_{AVQ_LAST-2}_{AVQ_LAST%100:02d}": round(sum(last3) / 3, 2),
        "np_per10k_2011": bes[bl]["2011"], "np_per10k_2021": bes[bl]["2021"],
        "unemp_2021_23": round(unemp[nc], 2), "tertiary_2021_23": round(tert[nc], 2),
    })
out = os.path.join(HERE, "italy_regions.csv")
with open(out, "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0]))
    w.writeheader(); w.writerows(rows)


# ---- statistics ----------------------------------------------------------
def ols(y, X):
    """OLS with intercept. Returns coefficients and conventional SEs."""
    n = len(y); X = [[1.0] + list(x) for x in X]; k = len(X[0])
    XtX = [[sum(X[i][a] * X[i][b] for i in range(n)) for b in range(k)] for a in range(k)]
    Xty = [sum(X[i][a] * y[i] for i in range(n)) for a in range(k)]
    # invert XtX by Gauss-Jordan
    A = [row[:] + [1.0 if i == j else 0.0 for j in range(k)] for i, row in enumerate(XtX)]
    for c in range(k):
        p = max(range(c, k), key=lambda r: abs(A[r][c])); A[c], A[p] = A[p], A[c]
        pv = A[c][c]; A[c] = [v / pv for v in A[c]]
        for r in range(k):
            if r != c:
                f = A[r][c]; A[r] = [a - f * b for a, b in zip(A[r], A[c])]
    inv = [row[k:] for row in A]
    b = [sum(inv[a][j] * Xty[j] for j in range(k)) for a in range(k)]
    res = [y[i] - sum(b[a] * X[i][a] for a in range(k)) for i in range(n)]
    s2 = sum(e * e for e in res) / (n - k)
    se = [math.sqrt(s2 * inv[a][a]) for a in range(k)]
    return b, se


def corr(x, y):
    mx, my = sum(x) / len(x), sum(y) / len(y)
    sxy = sum((a - mx) * (b - my) for a, b in zip(x, y))
    return sxy / math.sqrt(sum((a - mx) ** 2 for a in x) * sum((b - my) ** 2 for b in y))


print(f"{'region':22s} {'org13':>6s} {'org23':>6s} {'avq13':>6s} {'avq'+str(AVQ_LAST)[2:]:>6s} "
      f"{'np11':>6s} {'np21':>6s} {'unemp':>6s} {'tert':>6s}")
for r in rows:
    print(f"{r['region']:22s} {r['orgvol_2013']:6.1f} {r['orgvol_2023']:6.1f} {r['avq_vol_2013']:6.1f} "
          f"{r[f'avq_vol_{AVQ_LAST}']:6.1f} {r['np_per10k_2011']:6.1f} {r['np_per10k_2021']:6.1f} "
          f"{r['unemp_2021_23']:6.1f} {r['tertiary_2021_23']:6.1f}")

avq3 = f"avq_vol_{AVQ_LAST-2}_{AVQ_LAST%100:02d}"
PAIRS = [
    ("orgvol_2023", "np_per10k_2011", "module 2023 (4 wks, 15+) vs NP 2011"),
    ("orgvol_2023", "np_per10k_2021", "module 2023 (4 wks, 15+) vs NP 2021"),
    ("orgvol_2013", "np_per10k_2011", "module 2013 (4 wks, 15+) vs NP 2011"),
    (avq3, "np_per10k_2011", f"AVQ {AVQ_LAST-2}-{AVQ_LAST} mean (12 m, 14+) vs NP 2011"),
    (avq3, "np_per10k_2021", f"AVQ {AVQ_LAST-2}-{AVQ_LAST} mean (12 m, 14+) vs NP 2021"),
    ("avq_vol_2013", "np_per10k_2011", "AVQ 2013 (12 m, 14+) vs NP 2011"),
]
print("\nr = Pearson correlation (levels); slope = log-log OLS coefficient (SE);"
      "\n'+ctrl' adds unemployment and tertiary share (levels, 2021-23)")
print(f"{'pair':44s} {'sample':>9s} {'r':>6s} {'slope':>14s} {'slope +ctrl':>14s}")
for yv, xv, label in PAIRS:
    for sample, keep in (("all 21", lambda r: True),
                         ("ex Lazio", lambda r: r["region"] != "Lazio"),
                         ("ex BZ/TN", lambda r: r["region"] not in ("Bolzano", "Trento"))):
        sub = [r for r in rows if keep(r)]
        y = [math.log(r[yv]) for r in sub]; x = [math.log(r[xv]) for r in sub]
        c = corr([r[xv] for r in sub], [r[yv] for r in sub])
        b1, s1 = ols(y, [[a] for a in x])
        b2, s2 = ols(y, [[a, r["unemp_2021_23"], r["tertiary_2021_23"]] for a, r in zip(x, sub)])
        print(f"{label:44s} {sample:>9s} {c:6.2f} {b1[1]:6.2f} ({s1[1]:4.2f}) {b2[1]:6.2f} ({s2[1]:4.2f})")

# the controls alone, for reference
y = [math.log(r[avq3]) for r in rows]
b, s = ols(y, [[r["unemp_2021_23"], r["tertiary_2021_23"]] for r in rows])
print(f"\nlog AVQ vol on controls only: unemp {b[1]:.3f} ({s[1]:.3f}), tertiary {b[2]:.3f} ({s[2]:.3f})")
print(f"corr(NP 2021, unemployment) = {corr([r['np_per10k_2021'] for r in rows], [r['unemp_2021_23'] for r in rows]):.2f}")
print(f"corr(NP 2011, NP 2021) = {corr([r['np_per10k_2011'] for r in rows], [r['np_per10k_2021'] for r in rows]):.2f}")
lz = next(r for r in rows if r["region"] == "Lazio")
print(f"Lazio: NP 2021 {lz['np_per10k_2021']}, Italy {bes['Italy']['2021']}; "
      f"org vol 2023 {lz['orgvol_2023']}, Italy {module[('IT', '2023')]}")

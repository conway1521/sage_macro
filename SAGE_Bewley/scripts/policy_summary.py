"""Three-country summary of the policy tests.

    python3 scripts/policy_summary.py            (reads policy_results_*.csv)

Participation effects are in percentage points, at the best fit with the band
of acceptable technologies in brackets. The other effects do not depend on the
technology in any visible way, so only the best fit is shown for them.
"""
import csv, glob, os

HERE = os.path.dirname(os.path.abspath(__file__))
rows = []
for f in sorted(glob.glob(os.path.join(HERE, "policy_results_*.csv"))):
    with open(f) as fh:
        rows += list(csv.DictReader(fh))

def pick(code, cfg, pol, tech):
    for r in rows:
        if (r["code"], r["config"], r["policy"], r["technology"]) == (code, cfg, pol, tech):
            return r
    return None

codes = sorted({r["code"] for r in rows})
pols = ["subsidy", "empowerment", "ui_up", "ui_down"]
pp = lambda x: 100 * float(x)

print("Participation, percentage points: best fit [low multiplier, high multiplier]")
print(f"{'':12s} {'':5s}" + "".join(f"{c:>30s}" for c in codes))
for pol in pols:
    for cfg in ["GSA", "GS"]:
        cells = []
        for c in codes:
            b = pick(c, cfg, pol, "best")
            if b is None:
                cells.append(f"{'':>30s}"); continue
            lo, hi = pick(c, cfg, pol, "low multiplier"), pick(c, cfg, pol, "high multiplier")
            cells.append(f"{pp(b['d_rate']):+7.2f} [{pp(lo['d_rate']):+6.2f}, {pp(hi['d_rate']):+6.2f}]".rjust(30))
        if any(x.strip() for x in cells):
            print(f"{pol:12s} {cfg:5s}" + "".join(cells))

print("\nOther effects at the best fit, G+S+A (agency and gap in levels, the rest in percentage points)")
fields = [("d_A", "agency", 1), ("d_agency_gap", "gap", 1), ("d_shock_loss", "loss", 100),
          ("d_consumption_drop", "drop", 100), ("d_hardship", "hardship", 100),
          ("d_hand_to_mouth_kvw", "htm", 100), ("d_mean_effort_employed", "effort", 100)]
print(f"{'':12s} {'':3s}" + "".join(f"{n:>10s}" for _, n, _ in fields))
for pol in pols:
    for c in codes:
        b = pick(c, "GSA", pol, "best")
        if b is None:
            continue
        print(f"{pol:12s} {c:3s}" + "".join(f"{s * float(b[k]):+10.4f}" if s == 1 else f"{s * float(b[k]):+10.2f}"
                                            for k, _, s in fields))

print("\nMultipliers at the three technologies, G+S+A and G+S")
for c in codes:
    for cfg in ["GSA", "GS"]:
        m = [pick(c, cfg, "ui_up", t) for t in ("best", "low multiplier", "high multiplier")]
        if m[0]:
            print(f"  {c} {cfg:4s} " + ", ".join(f"{float(x['multiplier']):.1f}" for x in m))

"""Version 2's on/off test, the comparison (onoff_v2q.jl prints the results; V3_START.md section 137).

Reads the logs of onoff_v2q.jl runs (any number, any order), collects every "RES <variant> <name> = <value>" line,
and compares each pair of the test: a calibrated configuration with a switch off against the configuration without
that switch built at the same parameters. A pair passes when every common result agrees to 1e-10 relative, or 1e-11
absolute for results near zero (budget gaps). Results that exist on one side only are listed, not failed.

    python3 compare_onoff_v2q.py CODE log1.txt [log2.txt ...]
"""
import re
import sys

PAIRS = [("GS-S", "G"), ("GA-A", "G@GA"), ("GSA-S", "GA@GSA"), ("GSA-A", "GS@GSA"), ("GSA-SA", "G@GA")]
code = sys.argv[1].upper()
res = {}
pat = re.compile(r"RES (\S+) (\S+) = (\S+)")
for f in sys.argv[2:]:
    for line in open(f, errors="replace"):
        m = pat.search(line)
        if m:
            res.setdefault(m.group(1), {})[m.group(2)] = float(m.group(3))
print(code, "variants found:", ", ".join(sorted(res)))
for a, b in PAIRS:
    if a not in res or b not in res:
        print(f"{a} against {b}: not yet run")
        continue
    ra, rb = res[a], res[b]
    common = sorted(set(ra) & set(rb))
    worst, wname, fails = 0.0, "", []
    for k in common:
        x, y = ra[k], rb[k]
        if x != x and y != y:            # both NaN
            continue
        d = abs(x - y)
        rel = d / max(abs(x), abs(y), 1e-300)
        bad = not (d <= 1e-11 or rel <= 1e-10)
        if bad:
            fails.append((k, x, y, rel))
        score = 0.0 if d <= 1e-11 else rel
        if score > worst:
            worst, wname = score, k
    only = sorted(set(ra) ^ set(rb))
    print(f"{a} against {b}: {'PASS' if not fails else 'FAIL'} on {len(common)} results; largest relative difference "
          f"{worst:.1e} ({wname or 'none above 1e-11 absolute'})" + (f"; on one side only: {len(only)}" if only else ""))
    for k, x, y, rel in sorted(fails, key=lambda t: -t[3])[:12]:
        print(f"    {k}: {x:.12g} against {y:.12g} ({rel:.1e})")

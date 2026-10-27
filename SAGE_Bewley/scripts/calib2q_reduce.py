"""One round of the quarterly two-asset calibration of G (V3_START.md section 141; design section 4.2), run by the
reduce job of .github/workflows/calib2q.yml after the round's solves.

Four parameters, four moments (HFCS 2021, households not retired, data/hfcs_targets.csv):
    annual patience of the tertiary cell   the hand-to-mouth share (narrow, the model's rule)
    its gap for the cell below tertiary    the hand-to-mouth gap by education (below tertiary minus tertiary)
    k_min, years of mean income            the home-ownership rate (all households: see the caveat in V3_START.md)
    chi0, mean quarterly income            the wealthy hand-to-mouth share
Each solve job runs test_egm2_quarterly.jl for one point, cell and permanent type and prints the weighted sums of its
moments (the RAW line). The first round evaluates the point and one step in each parameter (a forward-difference
Jacobian); later rounds evaluate one point and update the Jacobian by Broyden's rule. Steps are damped least squares
(Levenberg-Marquardt) and capped; the parameters are (patience, gap, log k_min, log chi0). Not targeted, printed as tests: the MPC, median liquid wealth is
not available here (means only), the fall.

    python3 calib2q_reduce.py CODE ROUND LOGDIR STATE_IN STATE_OUT NEXT_OUT
LOGDIR holds res-<point>-<cell>-<type>/probe_output.txt; STATE_IN the previous round's state (or "none").
Writes STATE_OUT (json) and NEXT_OUT (one line: "done", "fail", or the next point "beta,gap,kmin_years,chi0q").
"""
import csv, glob, json, math, os, re, sys

code, rnd, logdir, state_in, state_out, next_out = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]
here = os.path.dirname(os.path.abspath(__file__))

def hfcs(moment, gv, g):
    with open(os.path.join(here, "..", "..", "data", "hfcs_targets.csv")) as fh:
        rows = [l for l in fh if not l.startswith("#")]
    for r in csv.DictReader(rows):
        if r["moment"] == moment and r["country"] == code and r["wave"] == "2021" and r["group_var"] == gv and r["group"] == g:
            return float(r["value"])
    raise SystemExit(f"target {moment} {gv} {g} not found for {code}")

T = [hfcs("htm_model_narrow_total", "not_retired", "not retired"),
     hfcs("htm_model_narrow_total", "education_nr", "below tertiary") - hfcs("htm_model_narrow_total", "education_nr", "tertiary"),
     hfcs("home_ownership_rate", "all", "all"),
     hfcs("htm_model_narrow_wealthy", "not_retired", "not retired")]
NAMES = ["hand-to-mouth", "gap by education", "ownership", "wealthy hand-to-mouth"]
TOL = 0.01                                   # about one standard error of each share
H = [0.005, 0.01, 0.15, 0.3]                 # forward steps in (patience, gap, log k_min, log chi0)
CAP = [0.01, 0.02, 0.4, 0.6]                 # largest step a round may take in each

def to_x(p):   return [p[0], p[1], math.log(p[2]), math.log(p[3])]
def to_p(x):   return [min(max(x[0], 0.80), 0.995), min(max(x[1], 0.0), 0.2), math.exp(x[2]), math.exp(x[3])]

# results: point -> cell -> list of RAW vectors (wsum, own, hpoor, hwealthy, mpcq, mpc12, liq, illiq, adj, outlay, k1..k5)
res, params, notes = {}, {}, []
for d in sorted(glob.glob(os.path.join(logdir, "res-*"))):
    m = re.match(r"res-(\d+)-(\d)-(\d)$", os.path.basename(d))
    if not m: continue
    pt, ci, t = int(m.group(1)), int(m.group(2)), int(m.group(3))
    f = os.path.join(d, "probe_output.txt")
    raw = None
    for line in open(f, errors="replace") if os.path.exists(f) else []:
        if line.startswith("RAW sums"):
            raw = [float(v) for v in line.split(":", 1)[1].split()]
        if "solved in" in line or "WARNING" in line or "stall" in line.lower():
            notes.append(f"point {pt} cell {ci} type {t}: {line.strip()}")
    if raw is None:
        notes.append(f"point {pt} cell {ci} type {t}: NO RESULT")
        continue
    res.setdefault(pt, {}).setdefault(ci, []).append(raw)
points = json.load(open(os.path.join(logdir, "points.json")))      # written by the plan job: [[beta, gap, ky, cq], ...]

def moments(pt):
    cells = res.get(pt, {})
    n = sum(len(v) for v in cells.values())
    if n != 10: return None
    tot = [sum(r[i] for v in cells.values() for r in v) for i in range(15)]
    htm_c = {c: sum(r[2] + r[3] for r in v) / sum(r[0] for r in v) for c, v in cells.items()}
    w = tot[0]
    m = [(tot[2] + tot[3]) / w, htm_c[1] - htm_c[2], tot[1] / w, tot[3] / w]
    k = tot[10:15]
    tests = {"MPC quarter": tot[4] / w, "MPC 12 months": tot[5] / w, "mean liquid": tot[6] / w, "mean illiquid": tot[7] / w,
             "adjusting": tot[8] / w, "outlay": tot[9] / w, "fall": 1 - (k[4] / k[3]) / (k[1] / k[0]) if k[3] > 0 else float("nan"),
             "htm cell 1": htm_c[1], "htm cell 2": htm_c[2]}
    return m, tests

for n in notes: print(n)
st = json.load(open(state_in)) if state_in != "none" and os.path.exists(state_in) else {"history": []}
M = {pt: moments(pt) for pt in range(len(points))}
missing = [pt for pt, v in M.items() if v is None]
for pt, v in M.items():
    if v is None: continue
    m, tests = v
    print(f"round {rnd} point {pt} {points[pt]}: " + " | ".join(f"{NAMES[i]} {m[i]:.4f} (target {T[i]:.4f})" for i in range(4))
          + " || tests: " + ", ".join(f"{k} {x:.4f}" for k, x in tests.items()))
if missing:
    print(f"FAIL: no complete result for points {missing}; not stepping"); open(next_out, "w").write("fail\n")
    json.dump(st, open(state_out, "w")); sys.exit(0)

x0 = to_x(points[0]); F0 = [M[0][0][i] - T[i] for i in range(4)]
if rnd == 0:
    J = [[(M[j + 1][0][i] - T[i] - F0[i]) / H[j] for j in range(4)] for i in range(4)]
else:
    J = st["J"]; xp, Fp = st["x"], st["F"]
    dx = [x0[i] - xp[i] for i in range(4)]; dF = [F0[i] - Fp[i] for i in range(4)]
    nn = sum(v * v for v in dx)
    if nn > 0:
        Jdx = [sum(J[i][j] * dx[j] for j in range(4)) for i in range(4)]
        J = [[J[i][j] + (dF[i] - Jdx[i]) * dx[j] / nn for j in range(4)] for i in range(4)]
st["history"].append({"round": rnd, "point": points[0], "moments": M[0][0], "F": F0, "tests": M[0][1]})
best = min(st["history"], key=lambda h: max(abs(v) for v in h["F"]))
print("Jacobian (rows: moments; columns: patience, gap, log k_min, log chi0):")
for i in range(4): print("  " + " ".join(f"{v:9.4f}" for v in J[i]))
if max(abs(v) for v in F0) <= TOL:
    print(f"CALIBRATED at round {rnd}: {points[0]}, worst miss {max(abs(v) for v in F0):.4f}")
    open(next_out, "w").write("done\n")
else:
    # damped least squares (Levenberg-Marquardt, damping 0.1 of the diagonal): a near-singular Jacobian gives a short
    # step along what is identified rather than a long one along noise; then each component is capped
    JtJ = [[sum(J[k][i] * J[k][j] for k in range(4)) for j in range(4)] for i in range(4)]
    A = [[JtJ[i][j] + (0.1 * JtJ[i][i] + 1e-8 if i == j else 0.0) for j in range(4)] + [-sum(J[k][i] * F0[k] for k in range(4))] for i in range(4)]
    for c in range(4):
        piv = max(range(c, 4), key=lambda r: abs(A[r][c])); A[c], A[piv] = A[piv], A[c]
        for r in range(4):
            if r != c:
                f = A[r][c] / A[c][c]; A[r] = [A[r][k] - f * A[c][k] for k in range(5)]
    dx = [A[i][4] / A[i][i] for i in range(4)]
    sc = max(1.0, max(abs(dx[i]) / CAP[i] for i in range(4)))
    dx = [v / sc for v in dx]
    pn = to_p([x0[i] + dx[i] for i in range(4)])
    print(f"step (scaled by 1/{sc:.2f}): next point {', '.join(f'{v:.5f}' for v in pn)}; worst miss now {max(abs(v) for v in F0):.4f}; best so far round {best['round']} {best['point']}")
    open(next_out, "w").write(",".join(f"{v:.6f}" for v in pn) + "\n")
st.update({"x": x0, "F": F0, "J": J, "round": rnd})
json.dump(st, open(state_out, "w"), indent=1)

# Stage 4 -> stage 5 substitutions for paper/sage_sa.tex, generated from the
# results file so no number is typed by hand. Run without --apply to dry-run.
import re, sys
from pathlib import Path
R = {}
for l in Path("SAGE_Bewley/scripts/sa_level4_results.txt").read_text().splitlines():
    if "\t" in l and not l.startswith("#"):
        k, v = l.split("\t"); R[k] = float(v)
p = lambda x: 100*x
f1 = lambda x: f"{x:.1f}"; f3 = lambda x: f"{x:.3f}"; f2 = lambda x: f"{x:.2f}"
r0, lo, hi = R["r0"], R["r0_lo"], R["r0_hi"]
subs = [
 # abstract / intro / conclusion levels
 ("from 35 percent participation to 25", f"from {p(r0):.0f} percent participation to {p(R['r_sub']):.0f}"),
 ("raises equilibrium participation from 35 to 38 percent", f"raises equilibrium participation from {p(r0):.0f} to {p(R['r_emp']):.0f} percent"),
 ("lifts participation from 35 to 66 percent", f"lifts participation from {p(r0):.0f} to {p(R['cred_25_100_r']):.0f} percent"),
 ("from 1.40 to 1.19; at half take-up it is roughly neutral; and when the lower group claims at only a quarter of the higher group's rate the ratio rises to 1.60",
  f"from {f2(R['ratio0'])} to {f2(R['cred_25_100_hi']/R['cred_25_100_lo'])}; at half take-up it is roughly neutral; and when the lower group claims at only a quarter of the higher group's rate the ratio rises to {f2(R['cred_25_25_hi']/R['cred_25_25_lo'])}"),
 # calibration
 ("aggregate participation 0.353 and group rates 0.295 and 0.411", f"aggregate participation {f3(r0)} and group rates {f3(lo)} and {f3(hi)}"),
 ("The aggregate rate is matched almost exactly, 0.353 against a target near 0.35", f"The aggregate rate is matched closely, {f3(r0)} against a target near 0.35"),
 ("the model's 11.7-point gap between the groups", f"the model's {f1(p(hi-lo))}-point gap between the groups"),
 ("the bound comes out at $0.469$ at the model's rates", f"the bound comes out at ${f3(R['sigbar'])}$ at the model's rates"),
 # decomposition
 ("decomposes the gap of 11.7 percentage points: with tastes equalised the agency channel alone produces a gap of 3.8 points; with agency equalised the taste channel alone produces 7.9 points",
  f"decomposes the gap of {f1(p(R['gap_full']))} percentage points: with tastes equalised the agency channel alone produces a gap of {f1(p(R['gap_agency']))} points; with agency equalised the taste channel alone produces {f1(p(R['gap_taste']))} points"),
 # proposition
 ("At the calibrated equilibrium the aggregate rate is $r = 0.353$, group rates are $0.295$ and $0.411$, and $\\omega = 0.30$. The complementarity factor is $1.279$ and the density term $0.367$, so $\\bar\\sigma = 0.469$",
  f"At the calibrated equilibrium the aggregate rate is $r = {f3(r0)}$, group rates are ${f3(lo)}$ and ${f3(hi)}$, and $\\omega = 0.30$. The complementarity factor is ${f3(R['comp'])}$ and the density term ${f3(R['dens'])}$, so $\\bar\\sigma = {f3(R['sigbar'])}$"),
 ("the map's actual slope is $G'(r^*) = 0.618$ against the proposition's $0.626$", f"the map's actual slope is $G'(r^*) = {f3(R['slope0'])}$ against the proposition's ${f3(R['gprime'])}$"),
 ("multiple stable equilibria appear only at $\\sigma_m \\le 0.30$, well inside the analytical $0.469$", f"multiple stable equilibria appear only at $\\sigma_m \\le {f2(R['frontier'])}$, well inside the analytical ${f3(R['sigbar'])}$"),
 ("compressed from a log standard deviation of $0.750$ to below $0.469$ on the analytical bound, or below $0.30$ on the model's own scan", f"compressed from a log standard deviation of $0.750$ to below ${f3(R['sigbar'])}$ on the analytical bound, or below ${f2(R['frontier'])}$ on the model's own scan"),
 ("which puts the fold at a dispersion of 0.30 against the 0.75", f"which puts the fold at a dispersion of {f2(R['frontier'])} against the 0.75"),
 # subsidy
 ("The budget balances at a lump-sum tax of 0.092, about a fifth of mean labour income", f"The budget balances at a lump-sum tax of {f3(R['T_sub'])}, about a fifth of mean labour income"),
 ("is a fall from 35.3 to 31.0 percent: 4.3 points", f"is a fall from {f1(p(r0))} to {f1(p(R['r_sub_direct']))} percent: {f1(p(r0-R['r_sub_direct']))} points"),
 ("The equilibrium effect is a fall to 24.7 percent: 10.6 points, with the lower-education group down to 19.6 percent and the higher to 29.9. The ratio is 2.47.",
  f"The equilibrium effect is a fall to {f1(p(R['r_sub']))} percent: {f1(p(r0-R['r_sub']))} points, with the lower-education group down to {f1(p(R['r_sub_lo']))} percent and the higher to {f1(p(R['r_sub_hi']))}. The ratio is {f2(R['amp'])}."),
 ("At $G'(r^*) = 0.618$ that formula predicts $1/(1-0.618) = 2.62$ against the 2.47 measured", f"At $G'(r^*) = {f3(R['slope0'])}$ that formula predicts $1/(1-{f3(R['slope0'])}) = {f2(1/(1-R['slope0']))}$ against the {f2(R['amp'])} measured"),
 # empowerment
 ("Equilibrium participation rises from 35.3 to 37.8 percent, with the lower-education group moving from 29.5 to 32.9 and the higher group from 41.1 to 42.8 through the feedback alone (Figure \\ref{fig:policy}, last bar). The education gap narrows from 11.7 points to 9.9.",
  f"Equilibrium participation rises from {f1(p(r0))} to {f1(p(R['r_emp']))} percent, with the lower-education group moving from {f1(p(lo))} to {f1(p(R['r_emp_lo']))} and the higher group from {f1(p(hi))} to {f1(p(R['r_emp_hi']))} through the feedback alone (Figure \\ref{{fig:policy}}, last bar). The education gap narrows from {f1(p(hi-lo))} points to {f1(p(R['r_emp_hi']-R['r_emp_lo']))}."),
 # credit
 ("A 25 percent rebate raises equilibrium participation from 35.3 to 66.1 percent at a fiscal cost of 3.2 percent of mean labour income, about a sixth of what the work subsidy costs, with the sign reversed and with both groups strictly interior at 60 and 72 percent. The French 66 percent deduction, a much larger rebate, drives participation to 95.2 percent at a cost of 12.2 percent of mean income.",
  f"A 25 percent rebate raises equilibrium participation from {f1(p(r0))} to {f1(p(R['cred_25_100_r']))} percent at a fiscal cost of {f1(R['cred_25_100_cost'])} percent of mean labour income, about a sixth of what the work subsidy costs, with the sign reversed and with both groups strictly interior at {p(R['cred_25_100_lo']):.0f} and {p(R['cred_25_100_hi']):.0f} percent. The French 66 percent deduction, a much larger rebate, drives participation to {f1(p(R['cred_66_100_r']))} percent at a cost of {f1(R['cred_66_100_cost'])} percent of mean income."),
 ("turned the work subsidy's 4.3-point direct effect into a 10.6-point fall", f"turned the work subsidy's {f1(p(r0-R['r_sub_direct']))}-point direct effect into a {f1(p(r0-R['r_sub']))}-point fall"),
]
# take-up table rows
rows = [("baseline", r0, lo, hi, None)]
for rho, nm in ((25,"Gift Aid 25\\%"),(66,"France 66\\%")):
    for tau, lbl in ((100,"full take-up"),(50,"$\\tau = 0.5$"),(25,"$\\tau = 0.25$")):
        k=f"cred_{rho}_{tau}"; rows.append((f"{nm}, {lbl}", R[k+"_r"], R[k+"_lo"], R[k+"_hi"], R[k+"_cost"]))
old_rows = [("baseline","0.353","0.295","0.411","1.40","---"),
 ("Gift Aid 25\\%, full take-up","0.661","0.603","0.719","1.19","3.2"),
 ("Gift Aid 25\\%, $\\tau = 0.5$","0.595","0.489","0.701","1.43","2.4"),
 ("Gift Aid 25\\%, $\\tau = 0.25$","0.556","0.428","0.684","1.60","2.0"),
 ("France 66\\%, full take-up","0.952","0.936","0.969","1.04","12.1"),
 ("France 66\\%, $\\tau = 0.5$","0.839","0.712","0.967","1.36","8.8"),
 ("France 66\\%, $\\tau = 0.25$","0.759","0.558","0.960","1.72","7.5")]
for (lbl,r,l,h,c),(olbl,orr,ol,oh,orat,oc) in zip(rows,old_rows):
    assert lbl==olbl
    subs.append((f"{olbl} & {orr} & {ol} & {oh} & {orat} & {oc} \\\\", f"{lbl} & {f3(r)} & {f3(l)} & {f3(h)} & {f2(h/l)} & {'---' if c is None else f1(c)} \\\\"))
# ledger
g=lambda k: R[k]
subs += [
 ("baseline & 0.353 & --- & --- \\\\", f"baseline & {f3(r0)} & --- & --- \\\\"),
 ("work subsidy (20\\%) & 0.247 & $+5.2\\%$ & $+1.5\\%$ \\\\", f"work subsidy (20\\%) & {f3(R['r_sub'])} & $+{f1(g('gdp_work_subsidy_(20%)'))}\\%$ & $+{f1(g('gdpb_work_subsidy_(20%)'))}\\%$ \\\\"),
 ("empowerment & 0.378 & $+3.1\\%$ & $+3.5\\%$ \\\\", f"empowerment & {f3(R['r_emp'])} & $+{f1(g('gdp_empowerment'))}\\%$ & $+{f1(g('gdpb_empowerment'))}\\%$ \\\\"),
 ("participation credit (25\\%) & 0.661 & $-3.9\\%$ & $+5.6\\%$ \\\\", f"participation credit (25\\%) & {f3(R['cred_25_100_r'])} & ${f1(g('gdp_participation_credit_(25%)'))}\\%$ & $+{f1(g('gdpb_participation_credit_(25%)'))}\\%$ \\\\"),
 ("participation credit (66\\%) & 0.952 & $-6.5\\%$ & $+12.0\\%$ \\\\", f"participation credit (66\\%) & {f3(R['cred_66_100_r'])} & ${f1(g('gdp_participation_credit_(66%)'))}\\%$ & $+{f1(g('gdpb_participation_credit_(66%)'))}\\%$ \\\\"),
 ("the breakeven price at which the work subsidy's gain in material output exactly offsets its loss of fabric is 50 percent of GDP", f"the breakeven price at which the work subsidy's gain in material output exactly offsets its loss of fabric is {R['pi_star_pct']:.0f} percent of GDP"),
 ("On material GDP the work subsidy wins outright, $+5.2$ percent against the Gift Aid credit's $-3.9$", f"On material GDP the work subsidy wins outright, $+{f1(g('gdp_work_subsidy_(20%)'))}$ percent against the Gift Aid credit's ${f1(g('gdp_participation_credit_(25%)'))}$"),
 ("On GDP-B the ranking inverts, $+1.5$ against $+5.6$, and the France-rate credit widens the gap to $+12.0$", f"On GDP-B the ranking inverts, $+{f1(g('gdpb_work_subsidy_(20%)'))}$ against $+{f1(g('gdpb_participation_credit_(25%)'))}$, and the France-rate credit widens the gap to $+{f1(g('gdpb_participation_credit_(66%)'))}$"),
 ("the work subsidy still raises GDP-B, by 1.5 percent", f"the work subsidy still raises GDP-B, by {f1(g('gdpb_work_subsidy_(20%)'))} percent"),
 ("only if a fully participating society's cohesion is worth more than 50 percent of GDP, where the model's own price is 33", f"only if a fully participating society's cohesion is worth more than {R['pi_star_pct']:.0f} percent of GDP, where the model's own price is {R['pi_model_pct']:.0f}"),
 ("the breakeven price, 50 percent of GDP per unit of participation", f"the breakeven price, {R['pi_star_pct']:.0f} percent of GDP per unit of participation"),
 ("mean labour income rises by 5.2 percent here", f"mean labour income rises by {f1(g('gdp_work_subsidy_(20%)'))} percent here"),
 ("the fabric would have to be worth more than half of GDP", f"the fabric would have to be worth more than {R['pi_star_pct']:.0f} percent of GDP"),
]
tex = Path("paper/sage_sa.tex").read_text()
missing = [o for o,_ in subs if o not in tex]
changed = sum(1 for o,n in subs if o!=n)
print(f"{len(subs)} substitutions, {changed} change text, {len(missing)} old strings NOT FOUND")
for m in missing: print("   MISSING:", m[:100])
if "--apply" in sys.argv and not missing:
    for o,n in subs: tex = tex.replace(o,n,1)
    Path("paper/sage_sa.tex").write_text(tex); print("APPLIED")

# Quarantine, second design: impose the data on one set of families.
#
# WHY THE FIRST DESIGN WAS ABANDONED. quarantine.jl bracketed the truth between
# the economy as it stands (unemployed participating at 1.0000) and one where a
# time floor of 0.40 and belonging at 0.50 drive them out. Its partial log,
# quarantine.txt, settled the most important thing before it was stopped:
#
#   U1  rate 0.3574 | employed 0.3075 | unemployed 1.0000   (matches the suite)
#   U0  rate 0.0413 | employed 0.0438 | unemployed 0.0091
#
# Taking a seven percent group out of participation took the EMPLOYED from
# 0.3075 to 0.0438. The calibrated point has a map slope of 0.9706, a
# multiplier of 34 (stage7_nz7.txt), so it sits next to a fold, and removing
# the unemployed's contribution to the aggregate pushes the economy past it.
# Two consequences. Interpolating between a high and a collapsed equilibrium is
# meaningless, so the bracket cannot bound anything. And the run was never
# going to finish in reasonable time: about sixteen minutes an economy, forty
# economies.
#
# THE DESIGN. With no participation credit and no money cost, an unemployed
# household's participation has no budget effect, because its effort is zero,
# and its logit option value does not depend on assets. So what the unemployed
# do on the participation margin moves no savings or effort policy anywhere in
# the economy at a given belonging scale. It moves only the aggregate, and
# through the aggregate the scale at which everyone's family is read. That
# means the counterfactual "the unemployed participate at the data ratio, all
# else equal" can be computed on ONE set of families by rewriting their
# participating mass at each scale, with no household problem solved again.
#
# Imposed rule at every belonging scale: unemployed rate = ratio x the employed
# rate at that same scale. Ratio 0.486 is INSEE Premiere 1327 (17 against 35).
#
# CHECKS, before anything is read.
#  V0  every node's rate equals the sum of its participating mass
#  V1  the native families reproduce the suite: rate 0.357355, agency 0.494665,
#      hand-to-mouth 0.299820
#  V2  imposing an unemployed level of 0.0091 reproduces the independent full
#      re-solve U0 above (rate 0.0413, employed 0.0438). This is the test of the
#      separability argument itself, against a solve that did not assume it.
#
# QUESTIONS.
#  Q1  At the INSEE ratio, does the high-participation equilibrium survive?
#  Q2  What happens to agency, hardship and hand-to-mouth there?
#  Q3  Recalibrated under the imposed ratio, where does the social technology
#      land, and what is the multiplier range? Nearly free: families do not
#      depend on kappa or sigma.
# Policy counterfactuals are deliberately not run. If Q1 comes back no, a
# policy experiment at the current footing is an experiment on an equilibrium
# that the data rule out, and the calibration has to be redone first.
#
#   julia --project=. scripts/quarantine2.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics, Serialization, LinearAlgebra

const CAL = SAGEConfig(S = true, A = true, unemployment = true, beta_spread = 0.037,
                       kappa = 9.90, sigma_m = 0.385)
const SUITE = (rate = 0.357355, A = 0.494665, htm = 0.299820, median = 0.365028)
const U0FULL = (rate = 0.0413, E = 0.0438, U = 0.0091)
const INSEE = 0.17 / 0.35
# The suite's own anchored line: half its median, and three months of it.
const THR = [(0.5 * SUITE.median, hardship_threshold(SUITE.median; months = CAL.months))]

say(args...) = (println(args...); flush(stdout))
say("quarantine, second design | ", describe(CAL))
@printf("anchored thresholds from the suite: poverty line %.6f, asset threshold %.6f\n", THR[1]...)

# ------------------------------------------------------------- families --
const CDIR = joinpath(@__DIR__, "cache_quarantine"); isdir(CDIR) || mkpath(CDIR)
const CFILE = joinpath(CDIR, "fams_U1_nz11_k990_s385_spread037.jls")
fams = if isfile(CFILE)
    say("families from disk: ", basename(CFILE)); deserialize(CFILE)
else
    say("building the two response families, about sixteen minutes ...")
    t0 = time(); f = families(CAL; thresholds = THR)
    serialize(CFILE, f)
    @printf("  built and saved in %.1f min\n", (time() - t0) / 60); flush(stdout)
    f
end

const CT = SAGEConfig(CAL; lumptax = CAL.lumptax + ui_tax_of(CAL))
const EMP = params_of(CT, cells_of(CAL)[1])[1].transfer .== 0
EMP == (params_of(CT, cells_of(CAL)[2])[1].transfer .== 0) || error("cells disagree on the employment mask")

# V0
v0 = maximum(abs(n.rate - sum(n.part)) for f in fams for n in f)
@printf("V0 node rate against summed participating mass, worst gap %.2e: %s\n", v0, v0 < 1e-8 ? "HELD" : "FAILED")
v0 < 1e-8 || exit(1)

"Rewrite unemployed participation at every node: `ratio` x that node's employed rate, or a fixed `level`."
function impose(fam; ratio = nothing, level = nothing)
    ratio === nothing && level === nothing && return fam
    map(fam) do n
        mE = sum(n.mass[EMP]); rE = mE > 0 ? sum(n.part[EMP]) / mE : 0.0
        u = level === nothing ? min(ratio * rE, 1.0) : level
        p = copy(n.part); p[.!EMP] .= u .* n.mass[.!EMP]
        merge(n, (part = p, rate = sum(p)))
    end
end

"Every crossing of the participation map with its slope, stable or not."
function crossings(c, fs)
    cs = cells_of(c); rs = map(f -> [n.rate for n in f], fs)
    g = collect(range(0.0, 1.0, length = 401))
    o = [sum(cs[k].share * dot(node_weights(c, cs[k].B, c.omega + (1 - c.omega) * r), rs[k]) for k in 1:2) for r in g]
    out = NamedTuple[]
    for i in 1:400
        d1 = o[i] - g[i]; d2 = o[i+1] - g[i+1]
        (d1 == 0 || sign(d1) != sign(d2)) || continue
        sl = (o[i+1] - o[i]) / (g[i+1] - g[i])
        push!(out, (r = g[i] + d1 / (d1 - d2) * (g[i+1] - g[i]), slope = sl, stable = sl < 1))
    end
    out
end
fmt(xs) = join([@sprintf("%.4f%s", x.r, x.stable ? "" : "(u)") for x in xs], ", ")

function row(lbl, c, fs)
    r = _solve(c, THR; fams = fs)
    xs = crossings(c, fs)
    @printf("%-28s | %.4f %.4f %.4f | %.4f %.4f %.4f | %.4f %6.1f | %s\n", lbl,
            r.rate, r.rate_E, r.rate_U, r.A, r.hardship, r.hand_to_mouth,
            r.slope, r.slope < 1 ? 1 / (1 - r.slope) : Inf, fmt(xs))
    flush(stdout)
    r
end
hdr() = (@printf("%-28s | %-6s %-6s %-6s | %-6s %-6s %-6s | %-6s %-6s | %s\n", "unemployed participation",
                 "rate", "E", "U", "A", "hard", "htm", "slope", "mult", "all crossings, (u) unstable");
         println("-"^120))

# ----------------------------------------------------------- V1 and V2 --
say("\nVALIDATION"); hdr()
nat = row("native (as it stands)", CAL, fams)
v1 = abs(nat.rate - SUITE.rate) < 1e-4 && abs(nat.A - SUITE.A) < 1e-4 && abs(nat.hand_to_mouth - SUITE.htm) < 1e-4
@printf("V1 native reproduces the suite (%.6f %.6f %.6f): %s\n", nat.rate, nat.A, nat.hand_to_mouth, v1 ? "HELD" : "FAILED")
v1 || exit(1)
lev = row("level 0.0091 (U0 check)", CAL, [impose(f; level = U0FULL.U) for f in fams])
v2 = abs(lev.rate - U0FULL.rate) < 0.005 && abs(lev.rate_E - U0FULL.E) < 0.005
@printf("V2 imposed level reproduces the full U0 re-solve (rate %.4f against %.4f, employed %.4f against %.4f): %s\n",
        lev.rate, U0FULL.rate, lev.rate_E, U0FULL.E, v2 ? "HELD" : "FAILED, the separability argument does not hold")
v2 || exit(1)

# ------------------------------------------------------------ Q1 and Q2 --
say("\nQ1, Q2: THE CALIBRATED TECHNOLOGY, UNEMPLOYED AT A GIVEN RATIO OF THE EMPLOYED RATE"); hdr()
R = Dict{Any,Any}()
for ρ in (1.0, 0.75, INSEE, 0.25, 0.0)
    R[ρ] = row(@sprintf("ratio %.3f%s", ρ, ρ == INSEE ? " (INSEE)" : ""), CAL, [impose(f; ratio = ρ) for f in fams])
end
ri = R[INSEE]
@printf("\nQ1 at the INSEE ratio the equilibrium rate is %.4f against %.4f as it stands: %s\n", ri.rate, nat.rate,
        ri.rate > 0.5 * nat.rate ? "the high equilibrium SURVIVES" : "the high equilibrium DOES NOT SURVIVE")
@printf("Q2 agency %+.4f, hardship %+.4f, hand-to-mouth %+.4f, employed rate %+.4f relative to as it stands\n",
        ri.A - nat.A, ri.hardship - nat.hardship, ri.hand_to_mouth - nat.hand_to_mouth, ri.rate_E - nat.rate_E)

# ------------------------------------------------------------------- Q3 --
say("\nQ3: RECALIBRATED UNDER THE INSEE RATIO (group targets 0.25 and 0.45, quadrature 500)")
fi = [impose(f; ratio = INSEE) for f in fams]
rows = scan_technology(CAL, fi, collect(0.30:0.02:0.70), collect(2.0:0.05:20.0); nq = 500)
if isempty(rows)
    say("no stable equilibrium anywhere on the technology grid")
else
    ok = report_technology(rows)
    best = rows[argmin([x.loss for x in rows])]
    cb = SAGEConfig(CAL; kappa = best.κ, sigma_m = best.σ)
    say("\nthe best fit, as a full economy on the same families:"); hdr()
    rb = row(@sprintf("INSEE, kappa %.2f sigma %.2f", best.κ, best.σ), cb, fi)
    say("against the footing in use: kappa 9.90, sigma 0.385, multiplier 8.8 to 43.1 over the acceptable-fit region")
end
say("DONE")

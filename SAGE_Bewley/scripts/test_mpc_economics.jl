# The economics of the propensities, household by household (one asset, S off).
# The level of the MPC is a calibration matter; these are the properties that
# theory says must hold whatever the level, each a test:
#   1. the consumption function is concave: the MPC falls with liquid wealth
#      (Carroll and Kimball 1996), and the wealthiest approach the
#      permanent-income benchmark (R - 1) / R from above;
#   2. the hand-to-mouth spend more of a windfall than the others;
#   3. the MPC falls with the size of the windfall;
#   4. a loss moves consumption more than a gain of the same size (among
#      households with the assets to absorb it, so the comparison is on the grid);
#   5. the unemployed spend more of a windfall than the employed;
#   6. the impatient spend more than the patient (when there are patience types);
#   7. consumption, saving and earnings account for the whole windfall:
#      MPC + MPS - MPE = 1 at every size.
# The windfall is a multiple of the household's own annual labour and benefit
# income, as cash on hand at the start of the year.
#
#   julia --project=scripts/run_env scripts/test_mpc_economics.jl [CODE] [CONFIG]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
cfg = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "G"
occursin('S', cfg) && error("S off only: with S on the households are families over belonging scales")
V3 = length(ARGS) >= 3 && lowercase(ARGS[3]) in ("v3", "v3f")          # third argument v3: the version 3 economy and its calibration; v3f: the floor regime
V3F = length(ARGS) >= 3 && lowercase(ARGS[3]) == "v3f"
c = floor_effort(country_config(code; config = cfg, v3 = V3F ? :floor : V3, S = false, A = occursin('A', cfg)))
c.illiquid && error("one asset only")
cs = cells_of(c); bs, bw = betas_of(c)
cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
V3F && @printf("floor regime: floor %.4f, its tax %.5f\n", c.cfloor, floor_tax_of(c))

# one record per (education cell, patience type): weight, parameters, solution,
# and the expected consumption, saving, earnings and income at every state
hh = []
for g in 1:2, (k, p) in enumerate(params_of(cT, cs[g]))
    s = solve_participation_logit(update(p; social_strength = 0.0), 1.0; theta = c.theta, full = true)
    z, _ = SAGEBewley.income_process(p); a = s.a; na, ns = length(a), length(z)
    cb = zeros(na, ns); sb = zeros(na, ns); lb = zeros(na, ns); yb = zeros(na, ns)
    for st in 1:ns
        α = p.α[st]; credit = net_participation(p, α, z[st]); tr = transfer_at(p, st)
        for i in 1:na, d in (0, 1)
            w = d == 1 ? s.P1[i, st] : 1 - s.P1[i, st]; w <= 0 && continue
            lab = (1 + p.subsidy) * α * s.e_d[d+1][i, st] * z[st] * p.Z
            x = p.R * a[i] + lab - p.lumptax + credit * d + tr
            cb[i, st] += w * (x + floor_transfer(p, x) - s.a_d[d+1][i, st]) / p.pc          # with the floor's top-up, if any
            sb[i, st] += w * s.a_d[d+1][i, st]; lb[i, st] += w * lab; yb[i, st] += w * (lab + tr)
        end
    end
    push!(hh, (w = cs[g].share * bw[k], g = g, k = k, p = p, a = a, z = z, λ = s.lambda, c = cb, s = sb, l = lb, y = yb))
end

"Mass-weighted mean response per unit of windfall, windfall = `mult` times own annual income, over the states where `keep` holds."
function response(mult; keep = (h, i, st) -> true)
    num = zeros(3); den = 0.0
    for h in hh, st in eachindex(h.z), i in eachindex(h.a)
        m = h.w * h.λ[i, st]; (m <= 0 || !keep(h, i, st)) && continue
        Δ = mult * h.y[i, st]; Δ == 0 && continue
        ai = h.a[i] + Δ / h.p.R
        ai < h.a[1] && continue                      # a loss the household cannot absorb on the grid
        num[1] += m * h.p.pc * (interp_ext(h.a, view(h.c, :, st), ai) - h.c[i, st]) / Δ
        num[2] += m * (interp_ext(h.a, view(h.s, :, st), ai) - h.s[i, st]) / Δ
        num[3] += m * (interp_ext(h.a, view(h.l, :, st), ai) - h.l[i, st]) / Δ
        den += m
    end
    (mpc = num[1] / den, mps = num[2] / den, mpe = num[3] / den, mass = den)
end

# liquid wealth quintiles over the whole population
pts = [(h.a[i], h.w * h.λ[i, st]) for h in hh for st in eachindex(h.z) for i in eachindex(h.a) if h.λ[i, st] > 0]
sort!(pts; by = first); cm = cumsum(last.(pts)); cm ./= cm[end]
cut = [first(pts[findfirst(>=(q), cm)]) for q in (0.2, 0.4, 0.6, 0.8)]
quint(a) = 1 + count(<(a), cut)
htm(h, i, st) = h.a[i] <= h.y[i, st] / 52
results = Tuple{String,Bool}[]
check(name, ok) = (push!(results, (name, ok)); @printf("   -> %s: %s\n", name, ok ? "PASS" : "FAIL"))

M = 1 / 12
all_ = response(M)
@printf("%s %s%s, one asset: annual MPC %.3f, saving %.3f, earnings %+.3f (windfall of one month of income)\n", code, cfg, V3 ? " (version 3)" : "", all_.mpc, all_.mps, all_.mpe)

println("1. by liquid wealth quintile")
q = [response(M; keep = (h, i, st) -> quint(h.a[i]) == k) for k in 1:5]
for k in 1:5
    @printf("   quintile %d (mass %.3f): MPC %.3f\n", k, q[k].mass, q[k].mpc)
end
pih = (hh[1].p.R - 1) / hh[1].p.R
@printf("   permanent-income benchmark (R - 1) / R = %.3f\n", pih)
check("MPC falls across wealth quintiles", all(q[k].mpc >= q[k+1].mpc - 1e-4 for k in 1:4))
check("the wealthiest are above the permanent-income benchmark", q[5].mpc >= pih - 1e-4)

println("2. hand-to-mouth against the others")
h1 = response(M; keep = htm); h0 = response(M; keep = (h, i, st) -> !htm(h, i, st))
@printf("   hand-to-mouth (mass %.3f): MPC %.3f, earnings %+.3f | others: MPC %.3f, earnings %+.3f\n", h1.mass, h1.mpc, h1.mpe, h0.mpc, h0.mpe)
check("hand-to-mouth MPC above the others", h1.mpc > h0.mpc)

println("3. by size of the windfall")
sizes = (1 / 52, 1 / 12, 1 / 4, 1.0)
rs = [response(m) for m in sizes]
for (m, r) in zip(sizes, rs)
    @printf("   %5.1f%% of annual income: MPC %.3f, saving %.3f, earnings %+.3f, adding up %.6f\n", 100 * m, r.mpc, r.mps, r.mpe, r.mpc + r.mps - r.mpe)
end
check("MPC falls with the size of the windfall", all(rs[k].mpc >= rs[k+1].mpc - 1e-4 for k in 1:3))
check("consumption, saving and earnings add up at every size", all(abs(r.mpc + r.mps - r.mpe - 1) < 1e-6 for r in rs))

println("4. a loss against a gain of one month of income, households that can absorb the loss on the grid")
can(h, i, st) = h.a[i] - M * h.y[i, st] / h.p.R >= h.a[1]
gain = response(M; keep = can); loss = response(-M; keep = can)
@printf("   mass %.3f: MPC out of a gain %.3f, out of a loss %.3f\n", gain.mass, gain.mpc, loss.mpc)
check("a loss moves consumption at least as much as a gain", loss.mpc >= gain.mpc - 1e-4)

println("5. unemployed against employed")
u = response(M; keep = (h, i, st) -> h.z[st] == 0); e = response(M; keep = (h, i, st) -> h.z[st] > 0)
@printf("   unemployed (mass %.3f): MPC %.3f | employed: MPC %.3f, earnings %+.3f\n", u.mass, u.mpc, e.mpc, e.mpe)
check("unemployed MPC above employed", u.mpc > e.mpc)

if length(bs) > 1
    println("6. by patience type")
    rb = [response(M; keep = (h, i, st) -> h.k == k) for k in eachindex(bs)]
    for k in eachindex(bs)
        @printf("   beta %.4f: MPC %.3f\n", bs[k], rb[k].mpc)
    end
    check("MPC falls with patience", all(rb[k].mpc >= rb[k+1].mpc - 1e-4 for k in 1:length(bs)-1))
end
println("7. by education cell")
for g in 1:2
    rg = response(M; keep = (h, i, st) -> h.g == g)
    @printf("   cell %d: MPC %.3f, saving %.3f, earnings %+.3f\n", g, rg.mpc, rg.mps, rg.mpe)
end

nf = count(x -> !x[2], results)
@printf("\n%d of %d properties hold%s\n", length(results) - nf, length(results), nf == 0 ? "" : ": FAILED " * join([x[1] for x in results if !x[2]], "; "))
println("DONE")

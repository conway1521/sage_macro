# Stage 1d's test of the response of job finding to benefits (paper/sage_v2_design.md, section 3.4; V3_START.md
# section 135): on the calibrated quarterly G+A with its fitted search costs (search_v5q_<C>_GA.txt), the benefit of the
# entitled spell raised by 10 per cent in every quarter (the tax unchanged: a partial response), and the elasticity of
# the chance of finding work, mass-weighted over the spell's quarters, and of the expected duration out of work.
# Benchmarks: Chetty (2008), a hazard elasticity of -0.53 (weekly hazard); Schmieder and von Wachter (2016), a median
# duration elasticity of about 0.5.
#
# SEVERANCE (second argument `severance`; design section 7, item 2): the comparison with Chetty (2008) made the way
# his estimate is made. A lump sum at the start of the spell is a payment in its first quarter (every spell passes
# through it once), sized at the expected cash value per new spell of the benefit rise: the sum over the entitled
# quarters of 10 per cent of each quarter's replacement, weighted by the chance of still being unemployed there (the
# baseline's mass by quarter of the spell over the mass in the first, both cells pooled), undiscounted. It is in the
# same units as the benefit (a share of the household's income in work), as severance pay is a multiple of earnings.
# The ratio of the two responses is the model's counterpart of Chetty's liquidity share (about 0.6). It is not
# called moral hazard's complement: the rest also holds the timing of payments, their contingency and dread.
# NODREAD (third argument `nodread`): dread moved out of choices (wellbeing only), every other parameter held.
#
#   SAGE_DREAD_CHOICE=1 julia --project=scripts/run_env scripts/probe_v2_benefit.jl CODE [benefit|severance] [nodread]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); cfg = "GA"
mode = length(ARGS) >= 2 ? ARGS[2] : "benefit"; nodread = length(ARGS) >= 3 && ARGS[3] == "nodread"
readkv(f) = (d = Dict{String,String}(); for l in eachline(f); t = strip(l); (isempty(t) || startswith(t, "#") || !occursin("=", t)) && continue;
                 k, v = strip.(split(t, "=", limit = 2)); d[k] = v; end; d)
q = readkv(joinpath(@__DIR__, "calibration_v5q_$(code)_$(cfg).txt")); β = parse(Float64, q["beta_annual"]); gap = parse(Float64, q["beta_gap_annual"])
sq = readkv(joinpath(@__DIR__, "search_v5q_$(code)_$(cfg).txt"))
kq = (parse.(Float64, split(sq["search_kq_cell1"])), parse.(Float64, split(sq["search_kq_cell2"])))
ca = country_config(code; config = cfg, v3 = :v5m, S = false, A = true)
cb = duration_config(ca)
c = SAGEConfig(cb; beta_bar = β^(1 / 4), beta_cell = ((β - gap)^(1 / 4) - β^(1 / 4), 0.0), out_ls = 0.0, search = true, search_gamma = 0.35, search_kq = kq)
get(q, "dread_mode", "") == "overlay" && (c = SAGEConfig(c; dread_mode = :overlay))
nodread && (c = SAGEConfig(c; dread_mode = :overlay))
println(code, " G+A, ", mode, ", dread ", c.dread_mode === :overlay ? "in wellbeing only" : "in choices")
function exits(r)
    e = r.search_exit; nU = cb.nU
    # mass-weighted over the cells' unemployed in the entitled quarters: the cells' masses from the pooled distribution
    pg = r.pooled; num = 0.0; den = 0.0
    for g in 1:2
        w = cells_of(c)[g].share * sum(pg[g].mass[.!r.employed])
        num += w * sum(e[g][1:nU]) / nU; den += w
    end
    num / den
end
r0 = solve_economy(c; cache = false)
if mode == "severance"
    nU = cb.nU
    m = [sum(cells_of(c)[g].share * r0.search_mass[g][d] for g in 1:2) for d in 1:nU]
    surv = m ./ m[1]
    X = sum(surv .* 0.1 .* c.rrU_vec[1:nU])
    @printf("survival by quarter of the spell %s; lump sum %.5f of income in work (the first quarter's replacement %.4f -> %.4f)\n",
            string(round.(surv, digits = 4)), X, c.rrU_vec[1], c.rrU_vec[1] + X)
    rr1 = copy(c.rrU_vec); rr1[1] += X
    c1 = SAGEConfig(c; rrU_vec = rr1)
else
    c1 = SAGEConfig(c; rrU_vec = 1.1 .* c.rrU_vec)
end
r1 = solve_economy(c1; cache = false)
x0, x1 = exits(r0), exits(r1)
el = log(x1 / x0) / log(1.1)
@printf("%s G+A, %s: mean chance of finding work in the entitled quarters %.6f -> %.6f, log change %.6f; as an elasticity to a 10%% rise %.4f (Chetty 2008: -0.53 for a weekly hazard) | fall Kolsrud %.4f -> %.4f | htm %.4f -> %.4f\n",
        code, mode, x0, x1, log(x1 / x0), el, r0.fall_kolsrud, r1.fall_kolsrud, r0.hand_to_mouth_kvw, r1.hand_to_mouth_kvw)
for g in 1:2
    @printf("  cell %d chance by quarter: %s -> %s\n", g, string(round.(r0.search_exit[g], digits = 5)), string(round.(r1.search_exit[g], digits = 5)))
end
println("DONE")

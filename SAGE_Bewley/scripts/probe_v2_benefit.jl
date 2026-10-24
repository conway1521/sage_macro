# Stage 1d's test of the response of job finding to benefits (paper/sage_v2_design.md, section 3.4; V3_START.md
# section 135): on the calibrated quarterly G+A with its fitted search costs (search_v5q_<C>_GA.txt), the benefit of the
# entitled spell raised by 10 per cent in every quarter (the tax unchanged: a partial response), and the elasticity of
# the chance of finding work, mass-weighted over the spell's quarters, and of the expected duration out of work.
# Benchmarks: Chetty (2008), a hazard elasticity of -0.53 (weekly hazard); Schmieder and von Wachter (2016), a median
# duration elasticity of about 0.5.
#
#   SAGE_DREAD_CHOICE=1 julia --project=scripts/run_env scripts/probe_v2_benefit.jl CODE
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); cfg = "GA"
readkv(f) = (d = Dict{String,String}(); for l in eachline(f); t = strip(l); (isempty(t) || startswith(t, "#") || !occursin("=", t)) && continue;
                 k, v = strip.(split(t, "=", limit = 2)); d[k] = v; end; d)
q = readkv(joinpath(@__DIR__, "calibration_v5q_$(code)_$(cfg).txt")); β = parse(Float64, q["beta_annual"]); gap = parse(Float64, q["beta_gap_annual"])
sq = readkv(joinpath(@__DIR__, "search_v5q_$(code)_$(cfg).txt"))
kq = (parse.(Float64, split(sq["search_kq_cell1"])), parse.(Float64, split(sq["search_kq_cell2"])))
ca = country_config(code; config = cfg, v3 = :v5m, S = false, A = true)
cb = duration_config(ca)
c = SAGEConfig(cb; beta_bar = β^(1 / 4), beta_cell = ((β - gap)^(1 / 4) - β^(1 / 4), 0.0), out_ls = 0.0, search = true, search_gamma = 0.35, search_kq = kq)
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
c1 = SAGEConfig(c; rrU_vec = 1.1 .* c.rrU_vec)
r1 = solve_economy(c1; cache = false)
x0, x1 = exits(r0), exits(r1)
el = log(x1 / x0) / log(1.1)
@printf("%s G+A: mean chance of finding work in the entitled quarters %.4f -> %.4f with benefits +10%%: elasticity %.3f (Chetty 2008: -0.53 for a weekly hazard) | fall Kolsrud %.4f -> %.4f | htm %.4f -> %.4f\n",
        code, x0, x1, el, r0.fall_kolsrud, r1.fall_kolsrud, r0.hand_to_mouth_kvw, r1.hand_to_mouth_kvw)
for g in 1:2
    @printf("  cell %d chance by quarter: %s -> %s\n", g, string(round.(r0.search_exit[g], digits = 4)), string(round.(r1.search_exit[g], digits = 4)))
end
println("DONE")

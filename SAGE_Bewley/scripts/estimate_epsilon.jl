# E's one parameter, the community elasticity epsilon (omega_p = omega x
# (infra_p / infra_national)^epsilon), estimated on Italy's 21 TL2 regions and
# tested out of sample on France's urban-rural premium.
#
# Estimation: G+S+A with E (composition, access, conversion, community) at the
# national calibration; epsilon on a grid; the fit is level-free, the
# population-weighted sum of squares of (log model participation - log
# volunteering - their weighted mean difference), against ISTAT volunteering by
# region (2023-25). epsilon moves only the participation fixed points, so the
# regional families are built once.
# Test: France by degree of urbanisation (predetermined sports facilities),
# rural over cities participation against formal volunteering, 1.365.
#
#   julia --project=scripts/run_env scripts/estimate_epsilon.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics
grid = 0.2:0.1:1.2
function fit_it(eps)
    c = country_config("IT"; config = "GSA", S = true, A = true)
    r = solve_economy(SAGEConfig(c; E = true, typology = :tl2, epsilon = eps,
                                 e_channels = (:composition, :access, :conversion, :community)))
    d = place_data("IT"; typology = :tl2)
    names = [n for (n, _) in r.by_place]; w = r.weights
    m = log.([x.rate for (_, x) in r.by_place]); v = log.([latest(d, "formal_volunteering", n) for n in names])
    k = sum(w .* (m .- v))
    sse = sum(w .* (m .- v .- k) .^ 2)
    (sse = sse, cor = cor(m, v), spread_m = sqrt(sum(w .* (m .- sum(w .* m)) .^ 2)), spread_v = sqrt(sum(w .* (v .- sum(w .* v)) .^ 2)))
end
println("Estimation on Italy's 21 regions:")
res = []
for e in grid
    f = fit_it(e); push!(res, (e, f))
    @printf("  epsilon %.1f: weighted SSE %.4f, correlation %.3f, spread model %.3f against data %.3f\n", e, f.sse, f.cor, f.spread_m, f.spread_v)
    flush(stdout)
end
ehat = res[argmin([f.sse for (_, f) in res])][1]
@printf("estimate: epsilon %.1f\n", ehat)
println("\nOut-of-sample test, France by degree of urbanisation (data rural / cities 1.365):")
cf = country_config("FR"; config = "GSA", S = true, A = true)
for e in unique([0.3, 0.5, ehat])
    r = solve_economy(SAGEConfig(cf; E = true, typology = :degurba, epsilon = e))
    rr = [x.rate for (_, x) in r.by_place]
    @printf("  epsilon %.1f: rural / cities %.3f, towns / cities %.3f (data 1.365, 1.054)\n", e, rr[3] / rr[1], rr[2] / rr[1])
    flush(stdout)
end
println("DONE")

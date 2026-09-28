# The fast family path against the original: the same household problems,
# solved once with a shared reward table and neighbour warm starts, once from
# scratch. Reports time and the largest difference in every summary the model
# reads. France G+S+A, the lower education cell, all belonging scales.
#
#   SAGE_WORKERS=4 julia --project=scripts/run_env scripts/bench_family.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf

c = country_config("FR"; config = "GSA", S = true, A = true)
cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
cell = cells_of(c)[1]
p0s = params_of(cT, cell)
_, w = betas_of(c)
println("Julia ", VERSION, " | ", nworkers(), " workers | ", length(p0s), " discount types x ", length(c.ugrid), " belonging scales")

t_new = @elapsed fnew = build_family_ag(p0s, c.ugrid, c.theta; weights = w, chunked = true)
@printf("fast path     %.1f min\n", t_new / 60)
t_old = @elapsed fold = build_family_ag(p0s, c.ugrid, c.theta; weights = w, chunked = false)
@printf("original path %.1f min\n", t_old / 60)
@printf("speed-up %.1fx\n", t_old / t_new)

worst = Dict{Symbol,Float64}()
for (a, b) in zip(fnew, fold), f in (:rate, :minc, :pbase, :eff_E, :ymean, :mass, :part, :pmass, :dmass, :hmass, :mpcmass, :rmass)
    hasproperty(a, f) || continue
    d = maximum(abs.(getfield(a, f) .- getfield(b, f)))
    worst[f] = max(get(worst, f, 0.0), d)
end
for (f, d) in sort(collect(worst), by = x -> -x[2])
    @printf("  %-8s largest difference %.2e\n", f, d)
end
println("DONE")

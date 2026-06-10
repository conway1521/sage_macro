# Prototype: separate education (permanent type) from income (Markov state).
#
# The v1 engine conflates them: two z states carry both the income process and
# the education gradient (alpha, B), and with nz = 2, eta = 0.1 the income
# Gini badly understates data (~0.15 vs ~0.30). The clean architecture is the
# types chassis: two PERMANENT education cells (each with its own alpha and B
# level) times a RICHER within-cell income process (nz = 5 Rouwenhorst).
# This prototype asks: does the separation fix the income Gini while keeping
# the wealth facts, with zero engine surgery?
#
#   julia --project=. scripts/proto_edu_income.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf

# Education cells (thesis OECD BLI gradient), 50/50 shares as in the thesis.
cells(η) = [
    (name = "low edu",  share = 0.5,
     p = SAGEParams(nz = 5, η = η, α = fill(0.765, 5), B = fill(0.80, 5))),
    (name = "high edu", share = 0.5,
     p = SAGEParams(nz = 5, η = η, α = fill(0.911, 5), B = fill(0.94, 5))),
]

"Pooled weighted Gini across cells: values x, weights w concatenated."
function pooled_gini(parts)
    x = vcat([v for (v, _) in parts]...); w = vcat([m for (_, m) in parts]...)
    SAGEBewley._gini(x, w)
end

function run(η)
    inc_parts = Tuple{Vector{Float64},Vector{Float64}}[]
    wlt_parts = Tuple{Vector{Float64},Vector{Float64}}[]
    Q = 0.0; e_mean = 0.0; htm = 0.0
    for c in cells(η)
        s = solve_model(c.p)
        inc = vec([c.p.α[iz] * s.e[ia, iz] * s.z_vals[iz] for ia in 1:c.p.na, iz in 1:c.p.nz])
        push!(inc_parts, (inc, vec(s.λ) .* c.share))
        push!(wlt_parts, (vec(repeat(s.a_grid, 1, c.p.nz)), vec(s.λ) .* c.share))
        Q += c.share * s.Q
        e_mean += c.share * sum(s.λ .* s.e)
        htm += c.share * frac_constrained(s)
    end
    @printf("eta=%.2f  income Gini=%.3f  wealth Gini=%.3f  e_mean=%.3f  Q=%.3f  HtM=%.3f\n",
            η, pooled_gini(inc_parts), pooled_gini(wlt_parts), e_mean, Q, htm)
    flush(stdout)
end

println("Education x income separation (2 permanent cells x nz=5 Rouwenhorst)")
println("targets: income Gini ~0.30 (France disposable), wealth Gini ~0.55-0.68, e~0.53, HtM~0.30")
for η in (0.10, 0.15, 0.20, 0.25)
    run(η)
end
println("DONE")

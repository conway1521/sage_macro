# Completing the income process: persistent x transitory shocks on the
# education-cell architecture, via the new process override.
#
# The eta menu (proto_edu_income.jl) showed one risk parameter cannot hit the
# income Gini and the wealth facts together. The standard fix: log income =
# persistent AR(1) + iid transitory. Transitory shocks raise measured income
# inequality with little effect on wealth accumulation. Composite process:
# z = z_p * z_t, states = kron, transition = Pi_p (x) repeated pi_t rows.
#
# Moment targets (France): income Gini ~0.30, wealth Gini ~0.55-0.68,
# work share ~0.53, hand-to-mouth ~0.30.
#
# Validation built in: the composite with a DEGENERATE transitory component
# must reproduce the pure-persistent run exactly.
#
#   julia --project=. scripts/proto_income_complete.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using QuantEcon, LinearAlgebra, Printf

"Composite z-process: persistent Rouwenhorst(np, rho, eta_p) x iid transitory
3-point (-s, 0, +s in logs with probs 1/4, 1/2, 1/4). Normalised E[z] = 1."
function composite_process(np, ρ, ηp, ηt)
    mcp = rouwenhorst(np, ρ, ηp)
    zp = exp.(mcp.state_values); Πp = Matrix(mcp.p)
    πp = stationary_distributions(mcp)[1]
    zt = exp.([-ηt * sqrt(2), 0.0, ηt * sqrt(2)])   # matches Var = eta_t^2
    πt = [0.25, 0.5, 0.25]
    z = vec([a * b for b in zt, a in zp])           # index = (it, ip), it fastest
    Π = kron(Πp, ones(3) * πt')                     # iid transitory each period
    πz = kron(πp, πt)
    z ./= dot(πz, z)
    return z, Π
end

cells(ηp, ηt) = [
    (name = "low edu",  share = 0.5,
     p = SAGEParams(nz = 15, α = fill(0.765, 15), B = fill(0.80, 15),
                    z_vals_override = composite_process(5, 0.9, ηp, ηt)[1],
                    Π_override     = composite_process(5, 0.9, ηp, ηt)[2])),
    (name = "high edu", share = 0.5,
     p = SAGEParams(nz = 15, α = fill(0.911, 15), B = fill(0.94, 15),
                    z_vals_override = composite_process(5, 0.9, ηp, ηt)[1],
                    Π_override     = composite_process(5, 0.9, ηp, ηt)[2])),
]

function pooled_gini(parts)
    x = vcat([v for (v, _) in parts]...); w = vcat([m for (_, m) in parts]...)
    SAGEBewley._gini(x, w)
end

function run(ηp, ηt; label = "")
    inc_parts = Tuple{Vector{Float64},Vector{Float64}}[]
    wlt_parts = Tuple{Vector{Float64},Vector{Float64}}[]
    Q = 0.0; e_mean = 0.0; htm = 0.0
    for c in cells(ηp, ηt)
        s = solve_model(c.p)
        inc = vec([c.p.α[iz] * s.e[ia, iz] * s.z_vals[iz] for ia in 1:c.p.na, iz in 1:c.p.nz])
        push!(inc_parts, (inc, vec(s.λ) .* c.share))
        push!(wlt_parts, (vec(repeat(s.a_grid, 1, c.p.nz)), vec(s.λ) .* c.share))
        Q += c.share * s.Q; e_mean += c.share * sum(s.λ .* s.e); htm += c.share * frac_constrained(s)
    end
    @printf("%-24s incGini=%.3f wGini=%.3f e=%.3f HtM=%.3f\n",
            label == "" ? @sprintf("etaP=%.2f etaT=%.2f", ηp, ηt) : label,
            pooled_gini(inc_parts), pooled_gini(wlt_parts), e_mean, htm)
    flush(stdout)
end

println("[0] VALIDATION: degenerate transitory (etaT=0) vs pure persistent etaP=0.15")
run(0.15, 0.0; label = "composite, etaT=0")
# pure persistent benchmark with nz=5 (proto_edu_income gave incGini=0.185 etc.)
println("    (benchmark from proto_edu_income at eta=0.15: incGini=0.185 wGini=0.690 e=0.536 HtM=0.281)")

println("\n[1] The persistent x transitory menu")
for (ηp, ηt) in ((0.15, 0.15), (0.15, 0.25), (0.15, 0.35), (0.12, 0.30))
    run(ηp, ηt)
end
println("DONE")

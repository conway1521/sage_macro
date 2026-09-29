# The two-asset solver (egm2_core.jl): the reduction to the one-asset EGM, then
# a first look with the illiquid asset live. France G+S+A, lower-education cell,
# middle discount type, one belonging scale.
#
#   julia --project=scripts/run_env scripts/test_egm2.jl
include(joinpath(@__DIR__, "modular_stack.jl"))
using Printf

c = country_config("FR"; config = "GSA", S = true, A = true)
cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
p0 = update(params_of(cT, cells_of(c)[1])[3]; social_strength = 4.0, solver = :egm)

# 1. reduction: no adjustment affordable, mass starts at k = 0
r1 = solve_participation_egm(p0, 1.0; theta = c.theta, full = true)
p2 = update(p0; illiquid = true, chi0 = 1e10, Rk = 1.02, nk = 8, k_max = 10.0)
t = @elapsed r2 = solve_two_asset_egm(p2, 1.0; theta = c.theta, full = true)
dV = maximum(abs.(r2.V[:, 1, :] .- r1.V)); dλ = maximum(abs.(dropdims(sum(r2.lambda, dims = 2), dims = 2) .- r1.lambda))
@printf("reduction: V at k = 0 differs by %.1e, distribution by %.1e, rate %.10f vs %.10f, income %.10f vs %.10f  [%.1f s, %d iters vs %d]\n",
        dV, dλ, r2.rate, r1.rate, r2.meaninc, r1.meaninc, t, r2.iters, r1.iters)
println("mass off k = 0: ", sum(r2.lambda[:, 2:end, :]))
flush(stdout)

# 2. live: illiquid return 1.02 + the FR premium, perpetual youth (1/45), two fixed costs
for chi in (0.05, 0.2)
    p3 = update(p0; illiquid = true, chi0 = chi, Rk = 1.02 + 0.0354, death = 1 / 45, nk = 20, k_max = 60.0)
    t = @elapsed r = solve_two_asset_egm(p3, 1.0; theta = c.theta, full = true)
    λ = r.lambda; a = r.a; kg = r.k; y = r.meaninc
    bm = vec(sum(λ, dims = (2, 3))); km = vec(sum(λ, dims = (1, 3)))
    med(x, m) = x[findfirst(>=(0.5), cumsum(m) ./ sum(m))]
    htm = a .<= y / 52
    @printf("chi0 %.2f: %.1f s, %d iterations (stalled %.1e, relax %.3f) | adjusting %.3f | poor htm %.3f wealthy htm %.3f | median liquid %.3f illiquid %.3f (income %.3f) | mass at the grid tops %.1e %.1e | participation %.4f\n",
            chi, t, r.iters, r.stalled, r.relax, sum(λ .* r.Padj), sum(λ[htm, 1, :]), sum(λ[htm, 2:end, :]),
            med(a, bm), med(kg, km), y, sum(λ[end-5:end, :, :]), sum(λ[:, end, :]), r.rate)
    flush(stdout)
end
println("DONE")

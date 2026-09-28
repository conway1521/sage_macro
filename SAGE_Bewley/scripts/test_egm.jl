# The EGM solver against the reference on single household problems: France
# G+S+A parameters, both education cells, three belonging scales. The reference
# chooses effort on an 80-point grid, so it is also run at ne = 160 and 320 to
# show which way it moves as its grid refines.
#
#   julia --project=scripts/run_env scripts/test_egm.jl
include(joinpath(@__DIR__, "modular_stack.jl"))
using Printf

c = country_config("FR"; config = "GSA", S = true, A = true)
cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
stat(s) = (rate = s.rate, assets = sum(s.lambda .* s.a),
           effort = sum(s.lambda .* (s.P1 .* s.e_d[2] .+ (1 .- s.P1) .* s.e_d[1])) ,
           meaninc = s.meaninc, htm0 = sum(s.lambda[1:3, :]))
for (g, cell) in enumerate(cells_of(c)), u in (0.0, 4.0, 10.0)
    p0 = update(params_of(cT, cell)[1]; social_strength = u)
    solve_participation_logit(p0, 1.0; theta = c.theta, full = true)    # compile both
    solve_participation_logit(update(p0; solver = :egm), 1.0; theta = c.theta, full = true)
    tg = @elapsed rg = solve_participation_logit(p0, 1.0; theta = c.theta, full = true)
    te = @elapsed re = solve_participation_logit(update(p0; solver = :egm), 1.0; theta = c.theta, full = true)
    rg2 = solve_participation_logit(update(p0; ne = 320), 1.0; theta = c.theta, full = true)
    a, b, b2 = stat(rg), stat(re), stat(rg2)
    @printf("cell %d u %4.1f | grid %.2fs egm %.3fs (%.0fx, %d iters) | rate %.5f / %.5f (ne320 %.5f) | assets %.5f / %.5f (%.5f) | effort %.5f / %.5f (%.5f) | income %.5f / %.5f (%.5f)\n",
            g, u, tg, te, tg / te, re.iters, a.rate, b.rate, b2.rate, a.assets, b.assets, b2.assets,
            a.effort, b.effort, b2.effort, a.meaninc, b.meaninc, b2.meaninc)
    flush(stdout)
end
println("DONE")

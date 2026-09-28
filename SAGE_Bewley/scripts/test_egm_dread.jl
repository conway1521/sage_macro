# Behavioural dread in the EGM solver against the reference, on single household
# problems: France G+S+A, dread weight 1.5 in choices, both education cells.
#
#   julia --project=scripts/run_env scripts/test_egm_dread.jl
include(joinpath(@__DIR__, "modular_stack.jl"))
using Printf

c = country_config("FR"; config = "GSA", S = true, A = true)
cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c), dread = 1.5, dread_mode = :behaviour)
stat(s) = (rate = s.rate, assets = sum(s.lambda .* s.a),
           effort = sum(s.lambda .* (s.P1 .* s.e_d[2] .+ (1 .- s.P1) .* s.e_d[1])),
           htm0 = sum(s.lambda[1:3, :]))
for (g, cell) in enumerate(cells_of(c)), u in (0.0, 4.0)
    p0 = update(params_of(cT, cell)[1]; social_strength = u)
    @assert p0.dread > 0
    pn = update(p0; dread = 0.0)
    rg = solve_participation_logit(p0, 1.0; theta = c.theta, full = true)
    re = solve_participation_logit(update(p0; solver = :egm), 1.0; theta = c.theta, full = true)
    rn = solve_participation_logit(update(pn; solver = :egm), 1.0; theta = c.theta, full = true)
    a, b, n = stat(rg), stat(re), stat(rn)
    @printf("cell %d u %4.1f | rate %.5f / %.5f | assets %.4f / %.4f (no dread %.4f) | effort %.5f / %.5f | bottom %.4f / %.4f (no dread %.4f)\n",
            g, u, a.rate, b.rate, a.assets, b.assets, n.assets, a.effort, b.effort, a.htm0, b.htm0, n.htm0)
    flush(stdout)
end
println("DONE")

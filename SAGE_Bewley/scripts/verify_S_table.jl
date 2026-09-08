# The S paper's policy table (Table 1: financed 20 percent work subsidy under
# warm-glow cohesion, ne = 320) reproduced on the rescaled asset grid, so the
# paper can be updated from one run rather than by patching cells.
#   julia --project=. scripts/verify_S_table.jl
include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl")); using .SAGEBewley
using Printf
function financed(p; subsidy = 0.0, tol = 1e-5, maxit = 40)
    z, _ = income_process(p); T = 0.0
    s = solve_model(update(p; subsidy = subsidy, lumptax = T))
    for _ in 1:maxit
        paid = sum(s.λ[i,j]*subsidy*p.α[j]*s.e[i,j]*z[j] for j in 1:p.nz, i in 1:p.na)
        abs(paid - T) < tol && break
        T = 0.5T + 0.5paid
        s = solve_model(update(p; subsidy = subsidy, lumptax = T))
    end
    s
end
agg(s, M) = sum(s.λ .* M)
avg(s, M, z) = sum((s.λ[:,z] ./ sum(s.λ[:,z])) .* M[:,z])
for (amax, pe, lbl) in ((100.0, 1.5, "OLD grid (as published)"), (100.0, 4.0, "ENGINE DEFAULT grid"))
    p  = update(country_params("FR"); a_max = amax, pexp = pe)
    pw = update(p; ne = 320, social_mode = :warmglow, social_strength = 1.0)
    s0 = financed(pw); s1 = financed(pw; subsidy = 0.20)
    println("== ", lbl, " ==")
    @printf("consumption            %.3f -> %.3f  (%+.1f%%)\n", agg(s0,s0.c), agg(s1,s1.c), 100*(agg(s1,s1.c)/agg(s0,s0.c)-1))
    @printf("public good Q          %.3f -> %.3f  (%+.1f%%)\n", s0.Q, s1.Q, 100*(s1.Q/s0.Q-1))
    for z in 1:2
        @printf("material gain Uc g=%d   %.3f -> %.3f  (%+.1f%%)\n", z, avg(s0,s0.Uc,z), avg(s1,s1.Uc,z), 100*(avg(s1,s1.Uc,z)-avg(s0,s0.Uc,z))/abs(avg(s0,s0.Uc,z)))
    end
    for z in 1:2
        u0 = pw.Λ*pw.B[z]*s0.Q; u1 = pw.Λ*pw.B[z]*s1.Q
        @printf("social cohesion Us g=%d %.3f -> %.3f  (%+.1f%%)\n", z, u0, u1, 100*(u1-u0)/abs(u0))
    end
    sb = solve_model(p)
    @printf("baseline moments: Q %.4f  Gini %.4f  HtM %.4f\n\n", sb.Q, wealth_gini(sb), hand_to_mouth(sb))
    flush(stdout)
end
println("DONE")

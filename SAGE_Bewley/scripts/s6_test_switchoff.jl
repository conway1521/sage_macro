# STAGE6.md Part 6, check 1 (P1): with delta = 0 the four-state model must
# reproduce the stage-5b two-state family to solver tolerance.
include(joinpath(@__DIR__, "s6_common.jl"))
rd(f) = (d = readdlm(f, '\t'; skipstart = 1); (d[:,1], d[:,2], d[:,3], d[:,4]))
worst = 0.0
@printf("%-9s %-5s | %-12s %-12s | %-9s %-9s %-9s\n", "cell", "u", "rate(s6,d=0)", "rate(5b)", "d rate", "d minc", "d pbase")
println("-"^78)
for c in CELLS
    fam = rd(joinpath(CACHE5, "fam_" * replace(@sprintf("%.6f", c.α), "."=>"p") * "_0p000000_0p000000_0p000000.txt"))
    p0 = cell_params_u(c.α; δ = 0.0, f = F_FIND, rr = RR, na = NA, ne = NE,
                       a_max = GRID.a_max, pexp = GRID.pexp)
    for u in (2.0, 4.4, 5.0, 5.6, 8.0)
        global worst
        i = findfirst(==(u), fam[1])
        s = solve_participation_logit(update(p0; social_strength = u), 1.0; theta = THETA, full = true)
        d = (s.rate - fam[2][i], s.meaninc - fam[3][i], s.partbase - fam[4][i])
        worst = max(worst, maximum(abs, d))
        # mass in the unemployed states must be zero
        um = sum(s.lambda[:, 1:2])
        @printf("%-9s %5.1f | %.10f %.10f | %+.2e %+.2e %+.2e   U-mass %.1e\n",
                c.name, u, s.rate, fam[2][i], d..., um)
        flush(stdout)
    end
end
println("-"^78)
@printf("largest difference %.2e   %s\n", worst, worst < 1e-6 ? "P1 HOLDS" : "P1 FAILS")
println("DONE")

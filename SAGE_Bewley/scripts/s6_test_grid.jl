# STAGE6.md Part 6, check 3: is a_max = 4 still scaled to the wealth
# distribution once households save against job loss? Low cell (higher
# separation, the harder case), two belonging scales, a_max 4 with na 200
# against a_max 8 with na 252, which keeps the node spacing at any given
# wealth level the same (spacing goes as a_max^(1/3) / na on this grid).
include(joinpath(@__DIR__, "s6_common.jl"))
T = ui_tax(CELLS, F_FIND, RR)
@printf("UI tax %.5f\n\n", T)
c = CELLS[1]
@printf("%-5s %-4s | %-8s %-8s %-8s %-8s | %-8s %-8s | %-8s\n",
        "u", "amax", "p99", "p99.9", ">amax/2", ">2.0", "rate", "asset<.0515", "meaninc")
println("-"^84)
for u in (4.6, 5.6)
    for (am, na) in ((4.0, 200), (8.0, 252))
        p0 = cell_params_u(c.α; δ = c.δ, f = F_FIND, rr = RR, na = na, ne = NE,
                           a_max = am, pexp = GRID.pexp, lumptax = T)
        s = solve_participation_logit(update(p0; social_strength = u), 1.0; theta = THETA, full = true)
        d = cell_summary(p0, s)
        Wtot = vec(sum(d.W, dims = 1))
        q(x) = cdf_quantile(s.a, Wtot, x)
        above(x) = 1 - share_below_interp(s.a, Wtot, x)
        @printf("%5.1f %4.0f | %.4f   %.4f   %.1e  %.1e | %.4f   %.4f   | %.4f\n",
                u, am, q(0.99), q(0.999), above(am / 2), above(2.0), s.rate,
                share_below_interp(s.a, Wtot, 0.0515), s.meaninc)
        flush(stdout)
    end
end
println("rule: raise a_max if mass above a_max/2 exceeds 1e-4")
println("DONE")

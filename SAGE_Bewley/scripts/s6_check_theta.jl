# STAGE6.md Part 6, check 7: theta halved at the calibrated point, four
# belonging scales per cell placed where the taste mass sits.
include(joinpath(@__DIR__, "s6_common.jl"))
const OMEGA = 0.30
include(joinpath(@__DIR__, "s6_pop.jl"))
res = read_results()
κ, σ, r = res["kappa"], res["sigma"], res["r_base"]
ypov, abar, T = res["ypov"], res["abar"], res["T_UI"]
arg = OMEGA + (1 - OMEGA) * r
@printf("kappa %.2f sigma %.3f rate %.4f arg %.4f\n\n", κ, σ, r, arg)
@printf("%-9s %-6s | %-8s %-8s %-8s | %-8s %-8s %-8s\n", "cell", "u", "r(.005)", "r(.0025)", "diff", "h(.005)", "h(.0025)", "diff")
println("-"^80)
wr = 0.0; wh = 0.0
for c in CELLS
    p0 = cell_params_u(c.α; δ = c.δ, f = F_FIND, rr = RR, na = NA, ne = NE, a_max = GRID.a_max, pexp = GRID.pexp, lumptax = T)
    for m in (0.6, 0.9, 1.2, 1.6)
        global wr, wh
        u = κ * m * c.B * arg
        out = Dict{Float64,Tuple{Float64,Float64}}()
        for th in (0.005, 0.0025)
            s = solve_participation_logit(update(p0; social_strength = u), 1.0; theta = th, full = true)
            d = cell_summary(p0, s; thresholds = [(ypov, abar)])
            un = sum(d.jinc) + sum(share_below_interp(s.a, view(d.W, i, :), abar) for i in 1:p0.nz) - sum(d.jboth)
            out[th] = (s.rate, un)
        end
        dr = out[0.0025][1] - out[0.005][1]; dh = out[0.0025][2] - out[0.005][2]
        wr = max(wr, abs(dr)); wh = max(wh, abs(dh))
        @printf("%-9s %6.2f | %.4f   %.4f   %+.4f | %.4f   %.4f   %+.4f\n", c.name, u, out[0.005][1], out[0.0025][1], dr, out[0.005][2], out[0.0025][2], dh)
        flush(stdout)
    end
end
println("-"^80)
@printf("largest move: rate %.4f, hardship %.4f  (stage 5b: level 0.001, slope 0.002)\n", wr, wh)
println("DONE")

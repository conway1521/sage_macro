# Why does the two-asset solver cycle on the one-asset liquid grid (top 4) and
# not on tops of 15 or 30? Hypothesis: adjusters who sell illiquid wealth land
# above the top of the liquid grid and are clamped there (egm2_core.jl), which
# puts a kink in the value function. For each grid: the share of adjusting
# choices (state and target, weighted by the adjusting probability) whose
# effective liquid wealth exceeds the top, and whether the solve converged.
#
#   julia --project=scripts/run_env scripts/probe_egm2_gridtop.jl
include(joinpath(@__DIR__, "modular_stack.jl"))
using Printf
c = country_config("FR"; config = "GSA", S = true, A = true)
cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
p0 = update(params_of(cT, cells_of(c)[1])[3]; social_strength = 4.0, solver = :egm)
for (amax, na) in ((4.0, 200), (15.0, 120), (30.0, 150))
    p = update(p0; illiquid = true, chi0 = 0.05, Rk = 1.0554, death = 1 / 45, nk = 20, k_max = 60.0, a_max = amax, na = na)
    t = @elapsed r = solve_two_asset_egm(p, 1.0; theta = c.theta, full = true, maxit = 1500)
    a = r.a; nk = length(r.k); nz = size(r.lambda, 3)
    over = 0.0; tot = 0.0; overm = 0.0
    for s in 1:nz, m in 1:nk, i in 1:length(a)
        pa = r.Padj[i, m, s]; pa <= 0 && continue
        for j in 1:nk
            q = r.qadj[j, i, m, s]; q <= 1e-12 && continue
            be = a[i] + r.shift[m, j]; be < a[1] && continue
            tot += pa * q; be > a[end] && (over += pa * q; overm += r.lambda[i, m, s] * pa * q)
        end
    end
    @printf("liquid top %4.0f (na %d): %.1f s, %d iterations, stalled %.1e, relax %.3f | adjusting choices beyond the top: %.1f%% of all, mass-weighted %.2e\n",
            amax, na, t, r.iters, r.stalled, r.relax, 100 * over / tot, overm)
    flush(stdout)
end
println("DONE")

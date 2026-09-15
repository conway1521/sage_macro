# The jagged map is the discount distribution, not the belonging grid.
#
# `s7_diag_ugrid.txt` shows the coarse and fine belonging grids agreeing to
# four decimals for sigma at or above 0.40 and disagreeing below it, with the
# fine grid no smoother. So the lumpiness is not sampling error in u. The
# remaining suspect is the discretisation of beta: five permanent types give
# each cell FIVE participation thresholds instead of one, and at low taste
# dispersion the smearing is too narrow to wash them out, so the aggregate map
# has five bumps and the fixed point lands on one of them.
#
# If that is right, raising the number of beta points smooths the map and the
# slope converges. This tests 5 against 15 on the same belonging grid.
#
#   julia --project=. scripts/s7_diag_nbeta.jl
include(joinpath(@__DIR__, "s7_workers.jl"))
const OMEGA = 0.30
const NABLA = 0.030
include(joinpath(@__DIR__, "s7_pop.jl"))
res = read_results()

"Baseline family with an arbitrary number of equal-mass discount points."
function fam_nb(α, δ, nb)
    b = nb <= 1 ? [BBAR] : [BBAR - NABLA + NABLA * (2i - 1) / (2nb) for i in 1:nb]
    w = fill(1 / length(b), length(b))
    p0s = [cell_params_u(α; δ = δ, f = F_FIND, rr = RR, na = NA, ne = NE, a_max = GRID.a_max,
                         pexp = GRID.pexp, lumptax = res["T_UI"], β = x) for x in b]
    nodes = build_family_u(p0s, UGRID, THETA; weights = w)
    (u = copy(UGRID), r = [n.rate for n in nodes], nb = length(b))
end

const XG = collect(0.0:0.01:60.0)
xtab(u, r, σ) = (ms = taste_nodes_ln(σ; n = NQ); [mean(interp(u, r, x * m) for m in ms) for x in XG])
phi2(z) = exp(-z^2 / 2) / sqrt(2pi)
function best(Rl, Rh, κ; ng = 6401)
    g = range(0.0, 1.0, length = ng); out = nothing; ns = 0
    f(r) = (arg = OMEGA + (1 - OMEGA) * r;
            lo = interp(XG, Rl, κ * CELLS[1].B * arg); hi = interp(XG, Rh, κ * CELLS[2].B * arg);
            (CELLS[1].share * lo + CELLS[2].share * hi, lo, hi))
    o = [f(r)[1] for r in g]
    for i in 1:ng-1
        d1 = o[i] - g[i]; d2 = o[i+1] - g[i+1]
        (d1 == 0 || sign(d1) != sign(d2)) || continue
        sl = (o[i+1] - o[i]) / (g[i+1] - g[i]); sl < 1 || continue
        ns += 1
        rs = g[i] + d1 / (d1 - d2) * (g[i+1] - g[i]); _, lo, hi = f(rs)
        L = (lo - 0.25)^2 + (hi - 0.45)^2
        (out === nothing || L < out.L) && (out = (r = rs, lo = lo, hi = hi, slope = sl, L = L))
    end
    out === nothing ? nothing : (out..., nstable = ns)
end
function valley(FL, FH, σ)
    Rl = xtab(FL.u, FL.r, σ); Rh = xtab(FH.u, FH.r, σ); kb = nothing
    for κ in 8.0:0.02:12.0
        e = best(Rl, Rh, κ); e === nothing && continue
        (kb === nothing || e.L < kb.e.L) && (kb = (κ = κ, e = e))
    end
    kb
end

FAM = Dict{Int,Any}()
for nb in (5, 15)
    t0 = time()
    FAM[nb] = (fam_nb(CELLS[1].α, CELLS[1].δ, nb), fam_nb(CELLS[2].α, CELLS[2].δ, nb))
    @printf("%2d discount points: families built in %.1f min\n", nb, (time() - t0) / 60)
    flush(stdout)
end
println()
@printf("%-7s | %-25s | %-25s\n", "sigma", "5 discount points", "15 discount points")
@printf("%-7s | %-7s %-8s %-8s | %-7s %-8s %-8s\n", "", "kappa", "rootloss", "slope", "kappa", "rootloss", "slope")
println("-"^66)
bestof = Dict{Int,Any}()
for σ in 0.33:0.01:0.52
    a = valley(FAM[5]..., σ); b = valley(FAM[15]..., σ)
    for (nb, v) in ((5, a), (15, b))
        cur = get(bestof, nb, nothing)
        (cur === nothing || v.e.L < cur.v.e.L) && (bestof[nb] = (σ = σ, v = v))
    end
    @printf("%-7.3f | %-7.2f %-8.4f %-8.4f | %-7.2f %-8.4f %-8.4f\n",
            σ, a.κ, sqrt(a.e.L), a.e.slope, b.κ, sqrt(b.e.L), b.e.slope)
    flush(stdout)
end
println()
for nb in (5, 15)
    s = bestof[nb].σ; e = bestof[nb].v.e
    comp = (1 - OMEGA) / (OMEGA + (1 - OMEGA) * e.r)
    dens = 0.5 * phi2(quantile_normal(1 - e.lo)) + 0.5 * phi2(quantile_normal(1 - e.hi))
    @printf("%2d points: kappa %.2f sigma %.3f rootloss %.4f | rate %.4f groups %.3f/%.3f | slope %.4f mult %.1f ratio %.3f stable %d\n",
            nb, bestof[nb].v.κ, s, sqrt(e.L), e.r, e.lo, e.hi, e.slope, 1 / (1 - e.slope),
            s / (comp * dens), e.nstable)
end
println()
println("roughness of the loss surface, mean absolute change in slope between adjacent sigma:")
for nb in (5, 15)
    sl = [valley(FAM[nb]..., σ).e.slope for σ in 0.33:0.01:0.52]
    @printf("  %2d points: %.4f\n", nb, sum(abs, diff(sl)) / (length(sl) - 1))
end
println("DONE")

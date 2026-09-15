# STAGE6.md Part 6, check 2 (P2), redone for process parallelism: the pmap
# build must be identical to the serial build to the last bit.
include(joinpath(@__DIR__, "s6_workers.jl"))
println("workers: ", nworkers())
c = CELLS[1]
T = ui_tax(CELLS, F_FIND, RR)
p0 = cell_params_u(c.α; δ = c.δ, f = F_FIND, rr = RR, na = NA, ne = NE,
                   a_max = GRID.a_max, pexp = GRID.pexp, lumptax = T)
ug = [3.0, 4.6, 6.0, 8.0]
thr = [(0.194, 0.0485), (0.194, 0.0162)]
t0 = time(); fs = build_family_u(p0, ug, THETA; threaded = false, thresholds = thr); ts = time() - t0
t0 = time(); fp = build_family_u(p0, ug, THETA; threaded = true,  thresholds = thr); tp = time() - t0
ok = true
for i in eachindex(ug)
    same = all(getfield(fs[i], k) == getfield(fp[i], k) for k in (:W, :Y, :Ys, :mass, :part, :ym_s, :jinc, :jboth)) &&
           fs[i].rate == fp[i].rate && fs[i].ymean == fp[i].ymean && fs[i].eff_E == fp[i].eff_E
    global ok &= same
    @printf("u=%.1f  rate %.10f  income-poor(thr1) %.6f  identical: %s\n", ug[i], fs[i].rate,
            sum(fs[i].jinc[:, 1]), same)
end
@printf("serial %.1fs, pmap %.1fs (includes worker warm-up)\n", ts, tp)
println(ok ? "P2 HOLDS" : "P2 FAILS")
println("DONE")

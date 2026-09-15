# STAGE7.md Part 6, check 6: the asset grid, na 200 against 400, on the pooled
# baseline and on the two policies whose agency effects run through wealth
# (the subsidy) and through income (the higher replacement rate). Each state is
# held at the equilibrium rate and lump tax the na = 200 run found, so this
# isolates the distributional statistic.
include(joinpath(@__DIR__, "s7_workers.jl"))
const OMEGA = 0.30
const NABLA = 0.036
include(joinpath(@__DIR__, "s7_pop.jl"))
res = read_results7()
const KAPPA, SIGMA = res["kappa"], res["sigma"]
const THR = [(res["ypov"], res["abar"])]
T_UI = res["T_UI"]; T_sub = res["T_sub"]; T_up = res["T_UI_up"]; RRUP = RR + 0.10
states = (("baseline", 0.0, 0.0, RR, T_UI, res["r_base"]),
          ("work subsidy", 0.20, 0.0, RR, T_UI + T_sub, res["r_sub"]),
          (@sprintf("UI rr %.2f", RRUP), 0.0, 0.0, RRUP, T_up, res["r_uiup"]))
out = Dict{Tuple{String,Int},Any}()
for na in (200, 400), st in states
    nm, sub, cred, rr, T, r = st
    fl = family_u(CELLS[1].α, CELLS[1].δ; rr = rr, subsidy = sub, lumptax = T, partcredit = cred, thresholds = THR, na = na)
    fh = family_u(CELLS[2].α, CELLS[2].δ; rr = rr, subsidy = sub, lumptax = T, partcredit = cred, thresholds = THR, na = na)
    Pl = pool(fl, CELLS[1].B, KAPPA, SIGMA, r); Ph = pool(fh, CELLS[2].B, KAPPA, SIGMA, r)
    out[(nm, na)] = population(Pl, Ph)
    @printf("  %-16s na %d: union %.4f  A %.4f  inc %.4f  asset %.4f\n", nm, na, out[(nm,na)].union, out[(nm,na)].A, out[(nm,na)].inc, out[(nm,na)].asset)
    flush(stdout)
end
println()
@printf("%-16s | %-8s %-8s %-8s | %-9s %-9s %-8s\n", "state", "A(200)", "A(400)", "level", "dA(200)", "dA(400)", "move")
println("-"^76)
worst = 0.0
for st in states
    nm = st[1]; a2 = out[(nm,200)].A; a4 = out[(nm,400)].A
    d2 = a2 - out[("baseline",200)].A; d4 = a4 - out[("baseline",400)].A
    global worst = max(worst, abs(d4 - d2))
    @printf("%-16s | %.4f   %.4f   %+.4f | %+.4f    %+.4f    %+.4f\n", nm, a2, a4, a4 - a2, d2, d4, d4 - d2)
end
@printf("largest movement in a reported difference %.4f; baseline union moves %+.4f, income-poor %+.4f, asset-poor %+.4f\n",
        worst, out[("baseline",400)].union - out[("baseline",200)].union,
        out[("baseline",400)].inc - out[("baseline",200)].inc, out[("baseline",400)].asset - out[("baseline",200)].asset)
println("DONE")

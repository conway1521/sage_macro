# STAGE6.md Part 6, check 5: the stationarity identity with four states and
# the union hardship event. h(a, z) is the participation-mixed probability of
# hardship at the state; p(a, z) = E[h(a', z') | a, z] under the household's
# own transition. Their means under the stationary law must agree, and the
# mean of h must agree with the union share the stored joint indicators give,
# which checks that storage too.
include(joinpath(@__DIR__, "s6_common.jl"))
const OMEGA = 0.30
include(joinpath(@__DIR__, "s6_pop.jl"))
res = read_results()
ypov, abar, T = res["ypov"], res["abar"], res["T_UI"]
@printf("thresholds: line %.5f, asset %.5f, UI tax %.5f\n\n", ypov, abar, T)
@printf("%-9s %-5s | %-10s %-10s %-10s | %-10s %-10s\n", "cell", "u", "E[p]", "E[h]", "diff", "stored", "diff")
println("-"^76)
worst_id = 0.0; worst_st = 0.0
for c in CELLS
    p0 = cell_params_u(c.α; δ = c.δ, f = F_FIND, rr = RR, na = NA, ne = NE, a_max = GRID.a_max,
                       pexp = GRID.pexp, lumptax = T)
    z, Π = SAGEBewley.income_process(p0)
    for u in (3.0, 4.5, 5.5, 7.0, 10.0)
        global worst_id, worst_st
        p = update(p0; social_strength = u)
        s = solve_participation_logit(p, 1.0; theta = THETA, full = true)
        d = cell_summary(p, s; thresholds = [(ypov, abar)])
        a = s.a; λ = s.lambda; nz = p.nz
        # h(a, z): mixed over the participation branch
        h = zeros(NA, nz)
        for i_z in 1:nz, i_a in 1:NA
            α = p.α[i_z]; zz = z[i_z]; cap = (p.R - 1) * a[i_a]
            credit = p.partcredit * α * zz * p.Z * QBAR; tr = transfer_at(p, i_z)
            p1 = s.P1[i_a, i_z]
            for dd in (0, 1)
                pd = dd == 1 ? p1 : 1 - p1
                y = (1 + p.subsidy) * α * zz * p.Z * s.e_d[dd+1][i_a, i_z] + cap - p.lumptax + (dd == 1 ? credit : 0.0) + tr
                h[i_a, i_z] += pd * ((a[i_a] < abar || y < ypov) ? 1.0 : 0.0)
            end
        end
        Eh = sum(λ .* h)
        Ep = 0.0
        for i_z in 1:nz, i_a in 1:NA
            w = λ[i_a, i_z]; w <= 0 && continue
            p1 = s.P1[i_a, i_z]; pi_ = 0.0
            for dd in (0, 1)
                pd = dd == 1 ? p1 : 1 - p1; pd <= 0 && continue
                ap = s.a_d[dd+1][i_a, i_z]
                k = clamp(searchsortedlast(a, ap), 1, NA - 1)
                wl = clamp((a[k+1] - ap) / (a[k+1] - a[k]), 0.0, 1.0)
                for i_zn in 1:nz
                    pi_ += pd * Π[i_z, i_zn] * (wl * h[k, i_zn] + (1 - wl) * h[k+1, i_zn])
                end
            end
            Ep += w * pi_
        end
        stored = sum(d.jinc) + sum(share_below_interp(a, view(d.W, sidx, :), abar) for sidx in 1:nz) - sum(d.jboth)
        # the stored asset share interpolates; compare on the exact step reading instead
        stored_step = sum(d.jinc) + sum(share_below(a, view(d.W, sidx, :), abar) for sidx in 1:nz) - sum(d.jboth)
        worst_id = max(worst_id, abs(Ep - Eh)); worst_st = max(worst_st, abs(stored_step - Eh))
        @printf("%-9s %5.1f | %.7f  %.7f  %+.1e | %.7f  %+.1e\n", c.name, u, Ep, Eh, Ep - Eh, stored_step, stored_step - Eh)
        flush(stdout)
    end
end
println("-"^76)
@printf("largest identity departure %.1e   %s\n", worst_id, worst_id < 1e-9 ? "identity holds" : "IDENTITY FAILS")
@printf("largest storage departure  %.1e   %s\n", worst_st, worst_st < 1e-9 ? "stored indicators consistent" : "STORAGE INCONSISTENT")
println("DONE")

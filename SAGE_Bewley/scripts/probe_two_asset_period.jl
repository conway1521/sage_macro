# Is the low MPC of the two-asset model the annual period? (V3_START.md, section 27, probe 2.)
#
# On one asset the period does not move the annual MPC (probe_mpc_period.jl: 0.130
# against 0.127). On two assets it can, because the period is also how often the
# household may pay the fixed cost and reach its illiquid wealth: once a year, or
# every quarter.
#
# The quarterly household problem is built as in probe_mpc_period.jl, so that
# nothing else changes: the quarterly transition matrix is the fourth root of the
# annual one, the discount factor, the two returns and survival are fourth roots,
# every flow (pay, benefits, taxes) is a quarter of its annual value, and effort is
# set by the job. Wealth and the fixed cost are stocks and keep their grids and
# their size in goods. The logit scale of the adjustment choice is multiplied by
# 4^gamma, the factor by which the marginal value of a unit of goods rises when
# consumption per period is a quarter, so the choice is as sharp in goods as before.
#
# Reported for each period: hand-to-mouth (liquid wealth at most a week of annual
# income), poor and wealthy; the MPC within the period and over the year out of one
# month of annual income, for everyone and for each hand-to-mouth group; the share
# adjusting in a period, for everyone and among the wealthy hand-to-mouth. Ratios
# are to MEAN annual income here (the grid probe's are to the median). Not recalibrated.
#
#   julia --project=scripts/run_env scripts/probe_two_asset_period.jl [CODE] [effective patience] [chi0] [nk:k_sub] [k_max] [k_mid] [periods a year, comma separated: 1,4] [sd of a transitory part]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
bet = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 0.9578
chi0 = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 0.0131
nk, sub = (v = split(length(ARGS) >= 4 ? ARGS[4] : "32:4", ":"); (parse(Int, v[1]), length(v) > 1 ? parse(Int, v[2]) : 1))
kmax = length(ARGS) >= 5 ? parse(Float64, ARGS[5]) : 150.0
kmid = length(ARGS) >= 6 ? parse(Float64, ARGS[6]) : 8.0
periods = length(ARGS) >= 7 ? parse.(Int, split(ARGS[7], ",")) : [1, 4]
# eighth argument: standard deviation of an independent transitory draw on the income of the employed
# (three nodes, as probe_transitory_tax.jl), at the annual period only
sdt = length(ARGS) >= 8 ? parse(Float64, ARGS[8]) : 0.0
sdt > 0 && periods != [1] && error("the transitory part is built for the annual period here")
# ninth argument "payout": the illiquid return paid into liquid wealth every period (k_payout)
payout = length(ARGS) >= 9 && ARGS[9] == "payout"
premium = 0.0
for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "manual_inputs.csv"))
    f = split(ln, ","); length(f) >= 3 && f[1] == code && f[2] == "illiquid_premium" && (global premium = parse(Float64, f[3]))
end
one = country_config(code; config = "G", v3 = true, S = false, A = false)
levels = job_effort_levels(one)
c = SAGEConfig(one; illiquid = true, illiquid_premium = premium, effort_by_cell = levels, beta_spread = 0.0,
               beta_bar = bet / (1 - one.death), chi0 = chi0, nk = nk, k_sub = sub, k_max = kmax, k_mid = kmid)
cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))

@everywhere begin
    using SparseArrays, LinearAlgebra
    "Fourth (or n-th) root of a transition matrix, cleaned to a transition matrix; and how far its power is from the original."
    function root_of(Π, n)
        Q = real.(Π^(1 / n)); Q = max.(Q, 0.0); Q ./= sum(Q, dims = 2)
        (Q, maximum(abs.(Q^n .- Π)))
    end
    "The household problem with an independent transitory draw on the income of the employed: nt nodes, standard deviation sd."
    function expand_transitory(p, sd, nt)
        sd == 0 && return p
        isempty(p.dread_q) || error("not built with dread on")
        z = p.z_vals_override; Π = p.Π_override; ns = length(z)
        x = [sd * sqrt(nt - 1) * (2 * (t - 1) / (nt - 1) - 1) for t in 1:nt]
        w = [binomial(nt - 1, t - 1) / 2.0^(nt - 1) for t in 1:nt]
        ε = exp.(x); ε ./= dot(w, ε)
        ex(v) = isempty(v) ? v : repeat(v, inner = nt)
        update(p; nz = ns * nt, z_vals_override = [z[s] * ε[t] for s in 1:ns for t in 1:nt], Π_override = kron(Π, ones(nt) * w'),
               α = ex(p.α), B = ex(p.B), transfer = ex(p.transfer), effort_set = ex(p.effort_set),
               belong_scale = ex(p.belong_scale), time_floor = ex(p.time_floor))
    end
    "One education cell at `n` periods a year: the sums the table needs, over the cell's own mass of one."
    function period_cell(cT, g, n, sdt = 0.0, payout = false)
        p = params_of(cT, cells_of(cT)[g])[1]
        payout && (p = update(p; k_payout = true))
        p = expand_transitory(update(p; social_strength = 0.0), sdt, 3)
        err = 0.0; th = cT.theta; tha = 0.01
        if n > 1
            Q, err = root_of(p.Π_override, n)
            p = update(p; β = p.β^(1 / n), R = p.R^(1 / n), Rk = p.Rk^(1 / n), death = 1 - (1 - p.death)^(1 / n),
                       Z = p.Z / n, transfer = p.transfer ./ n, lumptax = p.lumptax / n,
                       ϕ = p.ϕ * float(n)^(p.γ - 1), Π_override = Q)
            th *= float(n)^(p.γ - 1); tha *= float(n)^p.γ
        end
        t0 = time()
        s = solve_two_asset_egm(p, 1.0; theta = th, theta_adj = tha, full = true, tol = 1e-9 * float(n)^p.γ, maxit = 40_000)
        a = s.a; kg = s.k; λ = s.lambda; Π = s.Pi
        na, nkk, ns = length(a), length(kg), length(s.z_vals); nb = na * nkk
        idx(i, m, st) = i + (m - 1) * na + (st - 1) * nb
        # the decision operator, as in two_asset_welfare_parts, and expected consumption over the year
        rows = Int[]; cols = Int[]; vals = Float64[]
        for st in 1:ns, m in 1:nkk, i in 1:na
            x = idx(i, m, st)
            each_branch_full(s, i, m, st) do wt, d, bp, j, e, be
                k = clamp(searchsortedlast(a, bp), 1, na - 1)
                wk = clamp((a[k+1] - bp) / (a[k+1] - a[k]), 0.0, 1.0)
                push!(rows, x); push!(cols, idx(k, j, st)); push!(vals, wt * wk)
                push!(rows, x); push!(cols, idx(k + 1, j, st)); push!(vals, wt * (1 - wk))
            end
        end
        D = sparse(rows, cols, vals, nb * ns, nb * ns)
        cb = vec(s.cbar); C = copy(cb); Πt = Matrix(transpose(Π)); surv = 1 - p.death
        for _ in 2:n
            C = cb .+ surv .* (D * vec(reshape(C, nb, ns) * Πt))
        end
        C3 = reshape(C, na, nkk, ns)
        o = (mass = 0.0, y = 0.0, hp = 0.0, hw = 0.0, mp = 0.0, my = 0.0, mpp = 0.0, myp = 0.0, mpw = 0.0, myw = 0.0,
             mpn = 0.0, myn = 0.0, adj = 0.0, adjw = 0.0, cons = 0.0)
        liq = zeros(na); nw = zeros(length(NWGRID))
        for st in 1:ns, m in 1:nkk, i in 1:na
            mm = λ[i, m, st]; mm <= 0 && continue
            ya = n * s.ybar[i, m, st]; Δ = ya / 12
            htm = a[i] <= ya / 52; poor = htm && m == 1; wealthy = htm && m > 1
            liq[i] += mm
            v = a[i] + kg[m]; q = clamp(searchsortedlast(NWGRID, v), 1, length(NWGRID) - 1)
            t = clamp((v - NWGRID[q]) / (NWGRID[q+1] - NWGRID[q]), 0.0, 1.0); nw[q] += mm * (1 - t); nw[q+1] += mm * t
            mp = 0.0; my = 0.0
            if Δ > 0
                ai = a[i] + Δ / p.R
                mp = p.pc * (interp_ext(a, view(s.cbar, :, m, st), ai) - s.cbar[i, m, st]) / Δ
                my = p.pc * (interp_ext(a, view(C3, :, m, st), ai) - C3[i, m, st]) / Δ
            end
            pa = s.Padj[i, m, st]
            o = (mass = o.mass + mm, y = o.y + mm * ya, hp = o.hp + mm * poor, hw = o.hw + mm * wealthy,
                 mp = o.mp + mm * mp, my = o.my + mm * my, mpp = o.mpp + mm * poor * mp, myp = o.myp + mm * poor * my,
                 mpw = o.mpw + mm * wealthy * mp, myw = o.myw + mm * wealthy * my,
                 mpn = o.mpn + mm * !htm * mp, myn = o.myn + mm * !htm * my,
                 adj = o.adj + mm * pa, adjw = o.adjw + mm * wealthy * pa, cons = o.cons + mm * n * s.cbar[i, m, st])
        end
        merge(o, (liq = liq, nw = nw, a = a, err = err, iters = s.iters, stalled = s.stalled, minutes = (time() - t0) / 60,
                  rss = Sys.maxrss() / 1e9))
    end
end

"Median of a mass vector on a grid."
function med(grid, m)
    cm = cumsum(m); j = findfirst(>=(0.5 * cm[end]), cm)
    j == 1 && return grid[1]
    grid[j-1] + (grid[j] - grid[j-1]) * (0.5 * cm[end] - cm[j-1]) / max(cm[j] - cm[j-1], 1e-300)
end

@printf("%s G, two assets, version 3, effective patience %.4f, fixed cost %.4f, premium %.4f, illiquid grid %d:%d to %.0f (dense to %.0f); not recalibrated\n",
        code, bet, chi0, premium, nk, sub, kmax, kmid)
sdt > 0 && @printf("with a transitory part of standard deviation %.3f on the income of the employed\n", sdt)
payout && println("the illiquid return is paid into liquid wealth every period")
sh = c.share
for n in periods
    rs = pmap(g -> period_cell(cT, g, n, sdt, payout), 1:2)
    tot(f) = sum(sh[g] * getfield(rs[g], f) for g in 1:2)
    ms = tot(:mass); y = tot(:y) / ms; hp = tot(:hp); hw = tot(:hw); hn = ms - hp - hw
    liq = sum(sh[g] .* rs[g].liq for g in 1:2); nw = sum(sh[g] .* rs[g].nw for g in 1:2)
    @printf("\n%d period%s a year (root of the transition matrix off by %.1e; value iterations %s; stalled %s; minutes %s; worker memory %.1f GB)\n",
            n, n == 1 ? "" : "s", maximum(r.err for r in rs), join([string(r.iters) for r in rs], ", "),
            join([@sprintf("%.3g", r.stalled) for r in rs], ", "), join([@sprintf("%.0f", r.minutes) for r in rs], ", "), maximum(r.rss for r in rs))
    @printf("   net wealth over mean annual income %.2f | liquid %.3f | consumption over income %.3f\n", med(NWGRID, nw) / y, med(rs[1].a, liq) / y, tot(:cons) / tot(:y))
    @printf("   hand-to-mouth: poor %.4f, wealthy %.4f\n", hp / ms, hw / ms)
    @printf("   MPC within the period: all %.3f | poor hand-to-mouth %.3f | wealthy hand-to-mouth %.3f | the rest %.3f\n",
            tot(:mp) / ms, tot(:mpp) / max(hp, 1e-12), tot(:mpw) / max(hw, 1e-12), tot(:mpn) / hn)
    @printf("   MPC over the year:     all %.3f | poor hand-to-mouth %.3f | wealthy hand-to-mouth %.3f | the rest %.3f\n",
            tot(:my) / ms, tot(:myp) / max(hp, 1e-12), tot(:myw) / max(hw, 1e-12), tot(:myn) / hn)
    @printf("   adjusting in a period: all %.3f | wealthy hand-to-mouth %.3f\n", tot(:adj) / ms, tot(:adjw) / max(hw, 1e-12))
    for (g, grp) in enumerate(("below tertiary", "tertiary"))
        r = rs[g]
        @printf("   %-15s hand-to-mouth %.3f (poor %.3f, wealthy %.3f) | MPC over the year %.3f | liquid %.3f | net wealth %.2f (both over own mean income)\n",
                grp, (r.hp + r.hw) / r.mass, r.hp / r.mass, r.hw / r.mass, r.my / r.mass, med(r.a, r.liq) / (r.y / r.mass), med(NWGRID, r.nw) / (r.y / r.mass))
    end
    flush(stdout)
end
println("DONE")

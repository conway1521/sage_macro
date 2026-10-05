# Would a transitory income shock and a proportional tax repair what the base gets wrong?
# (V3_START.md, section 27, probe 3.) Three things are open on one asset: the MPC is low
# at the right hand-to-mouth share, consumption absorbs too much of a job loss, and the
# hand-to-mouth share moves too much with the benefit rate (plus 0.25 for ten points in
# the policy check). The income process has a persistent part only, and the benefit bill
# is paid by a lump-sum tax that the unemployed and the lowest paid owe in full.
#
# The probe, at the level of the household problem, on the calibrated economy with
# patience by education and no floor (v3e), configuration G:
#   - a transitory part: log income of the employed plus an independent draw each year,
#     three nodes with standard deviation sd (the persistent part untouched, so the
#     cross-section is wider: read each row against its own hand-to-mouth share);
#   - a proportional tax on labour income raising what the lump-sum tax raised.
# Effort is set by the job at the base economy's levels in every row. Not recalibrated:
# each variant is run at three levels of patience, to compare the MPC at a like
# hand-to-mouth share, and once with the benefit rate ten points higher (the tax with it).
#
#   julia --project=scripts/run_env scripts/probe_transitory_tax.jl [CODE] [sd of the transitory part, comma separated: 0,0.15,0.25]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
sds = length(ARGS) >= 2 ? parse.(Float64, split(ARGS[2], ",")) : [0.0, 0.15, 0.25]
const NT = 3
c0 = country_config(code; config = "G", v3 = :edu, S = false, A = false)
c0 = SAGEConfig(c0; effort_by_cell = job_effort_levels(c0))

@everywhere begin
    using LinearAlgebra
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
    "Labour income per head of a cell at the job's effort levels, from the stationary distribution of its states."
    function labour_income(p)
        z, Π = SAGEBewley.income_process(p); π = fill(1 / length(z), length(z))
        for _ in 1:100_000
            πn = Π' * π; d = maximum(abs, πn - π); π = πn; d < 1e-14 && break
        end
        sum(π[s] * p.α[s] * p.effort_set[s] * z[s] * p.Z for s in eachindex(z))
    end
    "One household problem: the sums the table needs, over its own mass of one."
    function shock_cell(p, theta)
        s = solve_participation_logit(p, 1.0; theta = theta, full = true)
        a = s.a; z, _ = SAGEBewley.income_process(p); na, ns = length(a), length(z); nh = count(>(0.0), z)
        cb = zeros(na, ns); yb = zeros(na, ns)
        for st in 1:ns
            α = p.α[st]; credit = net_participation(p, α, z[st]); tr = transfer_at(p, st)
            for i in 1:na, d in (0, 1)
                w = d == 1 ? s.P1[i, st] : 1 - s.P1[i, st]; w <= 0 && continue
                lab = (1 + p.subsidy) * α * s.e_d[d+1][i, st] * z[st] * p.Z
                cb[i, st] += w * (p.R * a[i] + lab - p.lumptax + credit * d + tr - s.a_d[d+1][i, st]) / p.pc
                yb[i, st] += w * (lab + tr)
            end
        end
        mass = 0.0; y = 0.0; htm = 0.0; mpc = 0.0; mpch = 0.0; drop = 0.0; emp = 0.0; liq = zeros(na)
        for st in 1:ns, i in 1:na
            m = s.lambda[i, st]; m <= 0 && continue
            ya = yb[i, st]; Δ = ya / 12; h = a[i] <= ya / 52
            mass += m; y += m * ya; htm += m * h; liq[i] += m
            if Δ > 0
                v = p.pc * (interp_ext(a, view(cb, :, st), a[i] + Δ / p.R) - cb[i, st]) / Δ
                mpc += m * v; h && (mpch += m * v)
            end
            if z[st] > 0 && cb[i, st] > 0
                drop += m * max(0.0, 1 - cb[i, st - nh] / cb[i, st]); emp += m
            end
        end
        (mass = mass, y = y, htm = htm, mpc = mpc, mpch = mpch, drop = drop, emp = emp, liq = liq, a = a)
    end
end

"All household problems of an economy: (weight, parameters), the tax lump-sum or proportional."
function problems(c, sd, prop)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c)); T = ui_tax_of(c)
    cs = cells_of(cT); _, bw = betas_of(cT)
    ps = [params_of(cT, cs[g]) for g in 1:2]
    L = sum(cs[g].share * labour_income(ps[g][1]) for g in 1:2)
    out = Tuple{Float64,Any}[]
    for g in 1:2, (j, p) in enumerate(ps[g])
        prop && (p = update(p; lumptax = p.lumptax - T, subsidy = p.subsidy - T / L))
        push!(out, (cs[g].share * bw[j], expand_transitory(p, sd, NT)))
    end
    (out, T / L)
end

function med(grid, m)
    cm = cumsum(m); j = findfirst(>=(0.5 * cm[end]), cm)
    j == 1 && return grid[1]
    grid[j-1] + (grid[j] - grid[j-1]) * (0.5 * cm[end] - cm[j-1]) / max(cm[j] - cm[j-1], 1e-300)
end

function run_economy(c, sd, prop)
    pr, τ = problems(c, sd, prop)
    rs = pmap(x -> shock_cell(x[2], c.theta), pr)
    tot(f) = sum(pr[i][1] * getfield(rs[i], f) for i in eachindex(rs))
    ms = tot(:mass); liq = sum(pr[i][1] .* rs[i].liq for i in eachindex(rs))
    (htm = tot(:htm) / ms, mpc = tot(:mpc) / ms, mpch = tot(:mpch) / max(tot(:htm), 1e-12), drop = tot(:drop) / tot(:emp),
     liq = med(rs[1].a, liq) / (tot(:y) / ms), tau = τ)
end

@printf("%s G, one asset, patience by education (v3e), household problem with a transitory part and a proportional tax; not recalibrated\n", code)
@printf("benefit rate (household) %.3f, of which public %.3f; the lump-sum tax %.4f of mean pay\n", c0.rr, c0.rr_public, ui_tax_of(c0))
@printf("%-10s %-12s %-9s | %6s %6s %10s %8s %9s | %s\n", "transitory", "tax", "patience", "htm", "MPC", "MPC of htm", "liq/inc", "job loss", "htm with the benefit rate ten points higher")
for sd in sds, prop in (false, true)
    for shift in (0.0, -0.02, -0.04)
        t0 = time()
        c = shift == 0 ? c0 : SAGEConfig(c0; beta_bar = c0.beta_bar + shift)
        r = run_economy(c, sd, prop)
        extra = ""
        if shift == 0
            r2 = run_economy(SAGEConfig(c; rr = c.rr + 0.10, rr_public = c.rr_public + 0.10), sd, prop)
            extra = @sprintf("%.3f (%+.3f)", r2.htm, r2.htm - r.htm)
        end
        @printf("%-10s %-12s %-9s | %6.3f %6.3f %10.3f %8.3f %9.3f | %s   [%.1f min%s]\n", sd == 0 ? "none" : @sprintf("sd %.2f", sd),
                prop ? @sprintf("prop. %.3f", r.tau) : "lump-sum", shift == 0 ? "fitted" : @sprintf("%+.2f", shift),
                r.htm, r.mpc, r.mpch, r.liq, r.drop, extra, (time() - t0) / 60, "")
        flush(stdout)
    end
end
println("DONE")

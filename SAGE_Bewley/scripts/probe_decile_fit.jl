# The permanent component of income fitted to the official deciles (V3_START.md, sections 41 to 43):
# a design probe for the redesign of the income side, not a calibration.
#
# The published income process (Ampudia, Cooper, Le Blanc and Zhu) with its two variances in the
# order of the source's equation (the persistent innovation the smaller: section 42), no permanent
# component and no floor, is solved once per education cell. A household with permanent factor f is
# that household scaled by f (CRRA, effort set by the job, benefits and tax in proportion), so the
# income distribution of any permanent distribution is a mixture of scaled copies and needs no new
# solve. Three permanent distributions are fitted to Eurostat's decile cut-offs over the median, P5,
# P95 and the top tenth's share (data/validation/income_shape.csv):
#   sym3   three nodes, symmetric in logs (the version 4 form, one parameter)
#   free3  three nodes, free positions and weights (four parameters)
#   free5  five nodes, free positions and weights (eight parameters)
#
#   julia --project=scripts/run_env scripts/probe_decile_fit.jl [CONFIG] [CODE ...]     (ASREAD: the variances as version 4 read them)
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
cfg = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "GA"
codes = length(ARGS) >= 2 ? uppercase.(ARGS[2:end]) : ["FR", "DE", "IT"]
ASREAD = "ASREAD" in codes; codes = filter(!=("ASREAD"), codes); isempty(codes) && (codes = ["FR", "DE", "IT"])
function official(code, ind; file = "income_shape.csv")
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "validation", file))
        f = split(ln, ","); length(f) >= 4 && f[1] == ind && f[2] == code && (file != "income_distribution.csv" || f[3] == "2021") && return parse(Float64, f[4])
    end
    NaN
end
function records(c)
    c0 = floor_effort(SAGEConfig(c; S = false))
    cs = cells_of(c0); _, bw = betas_of(c0); cT = SAGEConfig(c0; lumptax = c0.lumptax + ui_tax_of(c0))
    jobs = [(g, k, p) for g in 1:2 for (k, p) in enumerate(params_of(cT, cs[g]))]
    recs = (nworkers() > 1 ? pmap : map)(jobs) do (g, k, p)
        p = update(p; social_strength = 0.0)
        s = solve_participation_logit(p, 1.0; theta = c0.theta, full = true)
        ys = Float64[]; ws = Float64[]; es = Bool[]
        for st in eachindex(s.z_vals), i in eachindex(s.a), d in (0, 1)
            pd = d == 1 ? s.P1[i, st] : 1 - s.P1[i, st]; m = cs[g].share * bw[k] * s.lambda[i, st] * pd; m <= 1e-12 && continue
            x = p.R * s.a[i] + (1 + p.subsidy) * p.α[st] * s.e_d[d+1][i, st] * s.z_vals[st] * p.Z - p.lumptax +
                net_participation(p, p.α[st], s.z_vals[st]) * d + transfer_at(p, st)
            push!(ys, (x + floor_transfer(p, x) - s.a[i]) / p.pc); push!(ws, m); push!(es, s.z_vals[st] > 0)
        end
        (ys, ws, es)
    end
    y = reduce(vcat, [r[1] for r in recs]); w = reduce(vcat, [r[2] for r in recs]); e = reduce(vcat, [r[3] for r in recs])
    # binned in the log of income (2,000 bins by status), so that a mixture is cheap to evaluate
    ly = log.(max.(y, 1e-9)); lo, hi = minimum(ly), maximum(ly); nb = 2000; h = (hi - lo) / nb
    B = zeros(nb, 2)
    for i in eachindex(y); b = clamp(1 + floor(Int, (ly[i] - lo) / h), 1, nb); B[b, e[i] ? 1 : 2] += w[i]; end
    (l = [lo + (b - 0.5) * h for b in 1:nb], m = B ./ sum(B))
end
const QS = (("P5", 0.05), ("D1", 0.1), ("D2", 0.2), ("D3", 0.3), ("D4", 0.4), ("D6", 0.6), ("D7", 0.7), ("D8", 0.8), ("D9", 0.9), ("P95", 0.95))
"The mixture's statistics: nodes `lf` (log factors) with weights `wk`."
function stats(R, lf, wk)
    n = length(R.l); K = length(lf)
    l = vcat([R.l .+ lf[k] for k in 1:K]...); mE = vcat([R.m[:, 1] .* wk[k] for k in 1:K]...); mU = vcat([R.m[:, 2] .* wk[k] for k in 1:K]...)
    o = sortperm(l); l = l[o]; mE = mE[o]; mU = mU[o]; m = mE .+ mU; cw = cumsum(m); y = exp.(l)
    q(p) = y[min(searchsortedfirst(cw, p), length(y))]; med = q(0.5); tot = dot(m, y); cy = cumsum(m .* y)
    share(lo, hi) = (i1 = searchsortedfirst(cw, lo); i2 = min(searchsortedfirst(cw, hi), length(y)); (cy[i2] - (i1 > 1 ? cy[i1-1] : 0.0)) / tot)
    below(t, mm) = sum(mm[i] for i in eachindex(y) if y[i] < t * med; init = 0.0)
    mu = dot(m, l)
    (cut = [q(p) / med for (_, p) in QS], top10 = 100 * share(0.9, 1.0), s8020 = share(0.8, 1.0) / share(0.0, 0.2),
     below = [below(t, m) for t in (0.4, 0.5, 0.6, 0.7)], inwork60 = below(0.6, mE) / sum(mE), varlog = dot(m, (l .- mu) .^ 2))
end
function nelder_mead(f, x0; step = 0.3, iters = 1500)
    n = length(x0); X = [copy(x0) for _ in 1:n+1]; for i in 1:n; X[i+1][i] += step; end
    F = [f(x) for x in X]
    for _ in 1:iters
        o = sortperm(F); X = X[o]; F = F[o]
        F[end] - F[1] < 1e-10 && break
        c = sum(X[1:n]) ./ n; xr = c .+ (c .- X[end]); fr = f(xr)
        if fr < F[1]
            xe = c .+ 2 .* (c .- X[end]); fe = f(xe); (fe < fr) ? (X[end] = xe; F[end] = fe) : (X[end] = xr; F[end] = fr)
        elseif fr < F[n]
            X[end] = xr; F[end] = fr
        else
            xc = c .+ 0.5 .* (X[end] .- c); fc = f(xc)
            if fc < F[end]; X[end] = xc; F[end] = fc
            else; for i in 2:n+1; X[i] = X[1] .+ 0.5 .* (X[i] .- X[1]); F[i] = f(X[i]); end; end
        end
    end
    o = argmin(F); (X[o], F[o])
end
softmax(a) = (e = exp.(a .- maximum(a)); e ./ sum(e))
# parameter vector -> (log factors, weights)
sym3(x) = (s = abs(x[1]); ([-s * sqrt(2), 0.0, s * sqrt(2)], [0.25, 0.5, 0.25]))
free3(x) = ([x[1], 0.0, x[2]], softmax([x[3], 0.0, x[4]]))
free5(x) = ([x[1], x[2], 0.0, x[3], x[4]], softmax([x[5], x[6], 0.0, x[7], x[8]]))
for code in codes
    c = country_config(code; config = cfg, v3 = :v4, S = false, A = occursin('A', cfg))
    ASREAD || (c = SAGEConfig(c; eta_cell = c.sd_eps_cell, sd_eps_cell = c.eta_cell))
    c = SAGEConfig(c; perm_sd = 0.0, cfloor = 0.0)
    R = records(c)
    offc = [official(code, "cutoff_over_median_" * nm) for (nm, _) in QS]; offt = official(code, "share_D10")
    offb = [official(code, "below$(t)_under65") for t in (40, 50, 60, 70)]
    loss(st) = sum(abs2, log.(st.cut ./ offc)) + abs2(log(st.top10 / offt))
    @printf("\n================ %s %s | variances %s | persistent innovation %.3f, %.3f, transitory %.3f, %.3f | official: S80/S20 under 65 %.2f, in-work poverty %.3f\n", code, cfg,
            ASREAD ? "as version 4 read them" : "in the order of the source's equation", (c.eta_cell .^ 2)..., (c.sd_eps_cell .^ 2)...,
            official(code, "s80s20_under65"; file = "income_distribution.csv"), official(code, "inwork_poverty60"; file = "income_distribution.csv"))
    rows = Any[("official", nothing)]
    push!(rows, ("no permanent part", stats(R, [0.0], [1.0])))
    for (nm, par, x0s) in (("sym3", sym3, [[0.3]]), ("free3", free3, [[-0.5, 0.5, 0.0, 0.0], [-0.8, 0.9, -0.5, -1.5]]),
                           ("free5", free5, [[-0.9, -0.4, 0.4, 0.9, 0.0, 0.0, 0.0, 0.0], [-1.0, -0.4, 0.5, 1.3, -1.0, 0.0, 0.0, -2.0]]))
        best = nothing
        for x0 in x0s
            x, fv = nelder_mead(x -> loss(stats(R, par(x)...)), x0)
            (best === nothing || fv < best[2]) && (best = (x, fv))
        end
        lf, wk = par(best[1]); f = exp.(lf); f ./= dot(wk, f)
        push!(rows, (nm, stats(R, lf, wk)))
        @printf("  %-6s nodes (mean one) %s | weights %s | loss %.4f\n", nm, join([@sprintf("%.3f", v) for v in f], " "), join([@sprintf("%.3f", v) for v in wk], " "), best[2])
    end
    @printf("  %-18s %s | top tenth %% | S80/S20 | below 40 50 60 70%% of the median   | in-work 60%% | var of log\n", "", join([@sprintf("%5s", nm) for (nm, _) in QS], " "))
    for (nm, st) in rows
        if st === nothing
            @printf("  %-18s %s | %10.1f | %7s | %.3f %.3f %.3f %.3f (under 65) | %11s |\n", nm, join([@sprintf("%5.3f", v) for v in offc], " "), offt, "", offb..., "")
        else
            @printf("  %-18s %s | %10.1f | %7.2f | %.3f %.3f %.3f %.3f            | %11.3f | %.3f\n", nm, join([@sprintf("%5.3f", v) for v in st.cut], " "), st.top10, st.s8020, st.below..., st.inwork60, st.varlog)
        end
    end
    flush(stdout)
end
println("DONE")

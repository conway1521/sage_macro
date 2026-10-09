# The permanent component of income fitted to the official decile cut-offs (V3_START.md, sections
# 41 to 44). Shared by the calibration (calibrate_country.jl, version 5) and the design probe
# (probe_decile_fit.jl). Not a solver file.
#
# With effort set by the job and benefits and the tax in proportion, a household with permanent
# factor f is the household of factor one scaled by f. One solve per education cell without a
# permanent component then gives the income distribution under any permanent distribution as a
# mixture of scaled copies, and the fit below needs no further solve. It does not hold with the
# means-tested floor, which is an amount, so the floor is off in the solve the fit uses.
using Printf, LinearAlgebra
function official_shape(code, ind; file = "income_shape.csv")
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "validation", file))
        f = split(ln, ","); length(f) >= 4 && f[1] == ind && f[2] == code && (file != "income_distribution.csv" || f[3] == "2021") && return parse(Float64, f[4])
    end
    NaN
end
function income_records(c)
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
const SHAPE_QS = (("P5", 0.05), ("D1", 0.1), ("D2", 0.2), ("D3", 0.3), ("D4", 0.4), ("D6", 0.6), ("D7", 0.7), ("D8", 0.8), ("D9", 0.9), ("P95", 0.95))
"The mixture's statistics: nodes `lf` (log factors) with weights `wk`."
function mix_stats(R, lf, wk)
    n = length(R.l); K = length(lf)
    l = vcat([R.l .+ lf[k] for k in 1:K]...); mE = vcat([R.m[:, 1] .* wk[k] for k in 1:K]...); mU = vcat([R.m[:, 2] .* wk[k] for k in 1:K]...)
    kk = vcat([fill(k, n) for k in 1:K]...)
    o = sortperm(l); l = l[o]; mE = mE[o]; mU = mU[o]; kk = kk[o]; m = mE .+ mU; cw = cumsum(m); y = exp.(l)
    q(p) = y[min(searchsortedfirst(cw, p), length(y))]; med = q(0.5); tot = dot(m, y); cy = cumsum(m .* y)
    share(lo, hi) = (i1 = searchsortedfirst(cw, lo); i2 = min(searchsortedfirst(cw, hi), length(y)); (cy[i2] - (i1 > 1 ? cy[i1-1] : 0.0)) / tot)
    below(t, mm) = sum(mm[i] for i in eachindex(y) if y[i] < t * med; init = 0.0)
    mu = dot(m, l)
    (cut = [q(p) / med for (_, p) in SHAPE_QS], top10 = 100 * share(0.9, 1.0), s8020 = share(0.8, 1.0) / share(0.0, 0.2),
     below = [below(t, m) for t in (0.4, 0.5, 0.6, 0.7)], inwork60 = below(0.6, mE) / sum(mE), varlog = dot(m, (l .- mu) .^ 2),
     # the same among the employed of every type but the lowest, and the lowest type's place in the distribution
     # (for the state out of work, V3_START.md section 55)
     inwork60_above = K > 1 ? sum(mE[i] for i in eachindex(y) if kk[i] > 1 && y[i] < 0.6 * med; init = 0.0) / sum(mE[kk .> 1]) : NaN,
     low_below60 = K > 1 ? sum(m[i] for i in eachindex(y) if kk[i] == 1 && y[i] < 0.6 * med; init = 0.0) / sum(m[kk .== 1]) : NaN,
     low_median = K > 1 ? (c1 = cumsum(m[kk .== 1]); y[kk .== 1][min(searchsortedfirst(c1, 0.5 * c1[end]), length(c1))] / med) : NaN)
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

"""
    fit_permanent(c, code; starts = [])

Five permanent types, free positions and weights, fitted to Eurostat's decile cut-offs over the
median, P5, P95 and the top tenth's share of income (data/validation/income_shape.csv; equivalised
disposable income, all persons). `c` is the economy with its other parameters set; its permanent
component and floor are switched off for the one solve. Returns the factors (mean one, ascending),
their weights, the loss and the fitted and official statistics.
"""
function fit_permanent(c, code; starts = Vector{Float64}[])
    R = income_records(SAGEConfig(c; perm_sd = 0.0, perm_f = Float64[], perm_w = Float64[], cfloor = 0.0, S = false))
    offc = [official_shape(code, "cutoff_over_median_" * nm) for (nm, _) in SHAPE_QS]; offt = official_shape(code, "share_D10")
    loss(st) = sum(abs2, log.(st.cut ./ offc)) + abs2(log(st.top10 / offt))
    best = nothing
    for x0 in vcat(starts, [[-0.9, -0.4, 0.4, 0.9, 0.0, 0.0, 0.0, 0.0], [-1.0, -0.4, 0.5, 1.3, -1.0, 0.0, 0.0, -2.0]])
        x, fv = nelder_mead(x -> loss(mix_stats(R, free5(x)...)), x0)
        (best === nothing || fv < best[2]) && (best = (x, fv))
    end
    lf, wk = free5(best[1]); o = sortperm(lf); lf = lf[o]; wk = wk[o]
    f = exp.(lf); f ./= dot(wk, f)
    (f = f, w = wk, loss = best[2], model = mix_stats(R, log.(f), wk), none = mix_stats(R, [0.0], [1.0]), offc = offc, offt = offt,
     offb = [official_shape(code, "below$(t)_under65") for t in (40, 50, 60, 70)])
end
"The fitted income distribution against the official one, as a table."
function show_permanent(P; io = stdout)
    @printf(io, "  permanent types (mean one) %s | weights %s | loss %.4f\n", join([@sprintf("%.3f", v) for v in P.f], " "), join([@sprintf("%.3f", v) for v in P.w], " "), P.loss)
    @printf(io, "  %-18s %s | top tenth %% | S80/S20 | below 40 50 60 70%% of the median   | in-work 60%% | var of log\n", "", join([@sprintf("%5s", nm) for (nm, _) in SHAPE_QS], " "))
    @printf(io, "  %-18s %s | %10.1f | %7s | %.3f %.3f %.3f %.3f (under 65) | %11s |\n", "official", join([@sprintf("%5.3f", v) for v in P.offc], " "), P.offt, "", P.offb..., "")
    for (nm, st) in (("no permanent part", P.none), ("five types", P.model))
        @printf(io, "  %-18s %s | %10.1f | %7.2f | %.3f %.3f %.3f %.3f            | %11.3f | %.3f\n", nm, join([@sprintf("%5.3f", v) for v in st.cut], " "), st.top10, st.s8020, st.below..., st.inwork60, st.varlog)
    end
    flush(io)
end

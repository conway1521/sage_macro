# Where the model's income distribution departs from the official one (V3_START.md, section 41).
# The model's household disposable income at a version 4 calibration, against Eurostat 2021
# (data/validation/income_shape.csv: decile cut-offs over the median and decile shares, ilc_di01;
# the share of people under 65 below 40, 50, 60 and 70% of the median, ilc_li02; people under 65 in
# households with very low work intensity, ilc_lvhl11n). Then who is at the bottom in the model:
# by employment status, education and permanent income type.
#
#   julia --project=scripts/run_env scripts/probe_income_shape.jl [CONFIG] [CODE ...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
cfg = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "GA"
codes = length(ARGS) >= 2 ? uppercase.(ARGS[2:end]) : ["FR", "DE", "IT"]
function official(code, ind)
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "validation", "income_shape.csv"))
        f = split(ln, ","); length(f) >= 4 && f[1] == ind && f[2] == code && return parse(Float64, f[4])
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
        ys = Float64[]; ws = Float64[]; es = Bool[]; ls = Float64[]
        for st in eachindex(s.z_vals), i in eachindex(s.a), d in (0, 1)
            pd = d == 1 ? s.P1[i, st] : 1 - s.P1[i, st]; m = cs[g].share * bw[k] * s.lambda[i, st] * pd; m <= 0 && continue
            lab = (1 + p.subsidy) * p.α[st] * s.e_d[d+1][i, st] * s.z_vals[st] * p.Z + transfer_at(p, st)          # non-asset income after the tax
            x = p.R * s.a[i] + lab - p.lumptax + net_participation(p, p.α[st], s.z_vals[st]) * d
            push!(ys, (x + floor_transfer(p, x) - s.a[i]) / p.pc); push!(ws, m); push!(es, s.z_vals[st] > 0); push!(ls, lab)
        end
        (ys, ws, es, fill(g, length(ys)), fill(k, length(ys)), ls)
    end
    cat(i) = reduce(vcat, [r[i] for r in recs])
    (y = cat(1), w = cat(2) ./ sum(cat(2)), e = cat(3), g = cat(4), k = cat(5), lab = cat(6), nk = length(bw))
end
for code in codes
    c = country_config(code; config = cfg, v3 = :v4, S = false, A = occursin('A', cfg))
    R = records(c); o = sortperm(R.y); y = R.y[o]; w = R.w[o]; e = R.e[o]; g = R.g[o]; k = R.k[o]; cw = cumsum(w)
    q(p) = y[findfirst(>=(p), cw)]; med = q(0.5)
    println("\n================ ", code, " ", cfg, ", version 4 | permanent sd ", c.perm_sd, " | household disposable income, the model against Eurostat 2021")
    println("quantile over the median      model  official")
    for (nm, p) in (("P5", 0.05), ("D1", 0.1), ("D2", 0.2), ("D3", 0.3), ("D4", 0.4), ("D6", 0.6), ("D7", 0.7), ("D8", 0.8), ("D9", 0.9), ("P95", 0.95))
        @printf("  %-4s                       %6.3f   %6.3f\n", nm, q(p) / med, official(code, "cutoff_over_median_" * nm))
    end
    tot = sum(w .* y)
    println("share of income by tenth, per cent: model, then official")
    println("  ", join([@sprintf("%5.1f", 100 * sum(w[i] * y[i] for i in eachindex(y) if (d - 1) / 10 < cw[i] <= d / 10; init = 0.0) / tot) for d in 1:10], " "))
    println("  ", join([@sprintf("%5.1f", official(code, "share_D$d")) for d in 1:10], " "))
    below(t, sel) = sum(w[i] for i in eachindex(y) if sel[i] && y[i] < t * med; init = 0.0)
    all_ = trues(length(y)); un = .!e
    println("share below a fraction of the median: model, official (under 65) | of the model's: unemployed, employed below tertiary, employed tertiary")
    for t in (0.4, 0.5, 0.6, 0.7)
        b = below(t, all_)
        @printf("  below %2.0f%%: %.3f  %.3f | %.3f  %.3f  %.3f\n", 100t, b, official(code, @sprintf("below%.0f_under65", 100t)),
                below(t, un), below(t, e .& (g .== 1)), below(t, e .& (g .== 2)))
    end
    mu = sum(w[un])
    @printf("not in work: model %.3f of households (all unemployed) | official, people under 65 in households with very low work intensity %.3f\n", mu, official(code, "very_low_work_intensity_under65"))
    @printf("rate below 60%% of the median: among the unemployed %.3f, among the employed %.3f\n", below(0.6, un) / mu, below(0.6, e) / (1 - mu))
    lv(sel) = (ww = w[sel] ./ sum(w[sel]); l = log.(max.(y[sel], 1e-9)); m_ = sum(ww .* l); sum(ww .* (l .- m_) .^ 2))
    @printf("variance of log income: all %.3f | employed %.3f | employed below tertiary %.3f | employed tertiary %.3f\n", lv(all_), lv(e), lv(e .& (g .== 1)), lv(e .& (g .== 2)))
    println("the lowest fifth by permanent income type (", R.nk, " types a cell): ", join([@sprintf("%.3f", sum(w[i] for i in eachindex(y) if cw[i] <= 0.2 && k[i] == kk; init = 0.0) / 0.2) for kk in 1:R.nk], " "))
    flush(stdout)
end
println("DONE")

# Untargeted tests of the agency side (V3_START.md, section 4), one asset, S off:
#  1. the expected loss of income to unemployment against OECD labour market
#     insecurity (data/validation/agency_benchmarks.csv);
#  2. France: the drop in income and in consumption on job loss, and the share of
#     the income loss that consumption absorbs, by quartile of liquid wealth,
#     against INSEE Analyses 104 (58% in the lowest quartile, 17% in the highest).
# The model's drop is at the same wealth in the year of the loss; INSEE's is six
# months into the spell.
#
#   julia --project=scripts/run_env scripts/corroborate_agency.jl [CONFIG]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
cfg = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "GA"
bench = Dict{Tuple{String,String},Float64}()
for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "validation", "agency_benchmarks.csv"))
    (startswith(ln, "#") || startswith(ln, "indicator")) && continue
    f = split(ln, ","); bench[(f[1], f[2])] = parse(Float64, f[3])
end
println("1. expected income loss to unemployment, percent (model: a year ahead, employed today; OECD: labour market insecurity 2016)")
for code in ("FR", "DE", "IT")
    c = country_config(code; config = cfg, S = false, A = occursin('A', cfg))
    r = solve_economy(c; cache = false)
    @printf("   %s: model %.2f | OECD %.2f | consumption loss expected %.2f, drop if hit %.1f\n", code, 100 * r.shock_loss_income,
            bench[("labour_market_insecurity", code)], 100 * r.shock_loss, 100 * r.consumption_drop)
    flush(stdout)
    code == "FR" || continue
    # household by household: the employed, and what job loss does at the same wealth
    cs = cells_of(c); bs, bw = betas_of(c); cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    rec = NamedTuple[]
    for g in 1:2, (k, p0) in enumerate(params_of(cT, cs[g]))
        p = update(p0; social_strength = 0.0)
        s = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
        z = s.z_vals; a = s.a; na, ns = length(a), length(z); nh = ns ÷ 2
        cb = zeros(na, ns); yb = zeros(na, ns)
        for st in 1:ns, i in 1:na, d in (0, 1)
            w = d == 1 ? s.P1[i, st] : 1 - s.P1[i, st]; w <= 0 && continue
            lab = (1 + p.subsidy) * p.α[st] * s.e_d[d+1][i, st] * z[st] * p.Z
            tr = transfer_at(p, st)
            cb[i, st] += w * (p.R * a[i] + lab - p.lumptax + net_participation(p, p.α[st], z[st]) * d + tr - s.a_d[d+1][i, st]) / p.pc
            yb[i, st] += w * (lab + tr)
        end
        for st in nh+1:ns, i in 1:na          # employed states; the same productivity unemployed is st - nh
            m = cs[g].share * bw[k] * s.lambda[i, st]; m <= 0 && continue
            push!(rec, (m = m, a = a[i], dc = cb[i, st] - cb[i, st-nh], dy = yb[i, st] - yb[i, st-nh], c = cb[i, st], y = yb[i, st]))
        end
    end
    sort!(rec; by = x -> x.a); cm = cumsum([x.m for x in rec]); cm ./= cm[end]
    tot(f, sel) = sum(f(x) * x.m for x in rec[sel])
    all_ = 1:length(rec)
    @printf("2. France, on job loss: income falls %.0f%% (INSEE %.0f%%), consumption %.0f%% (INSEE %.0f%% at six months); consumption absorbs %.0f%% of the income loss (INSEE %.0f%%)\n",
            100 * tot(x -> x.dy, all_) / tot(x -> x.y, all_), bench[("income_drop_on_job_loss", "FR")],
            100 * tot(x -> x.dc, all_) / tot(x -> x.c, all_), bench[("consumption_drop_six_months", "FR")],
            100 * tot(x -> x.dc, all_) / tot(x -> x.dy, all_), bench[("consumption_share_of_income_loss", "FR")])
    println("   by quartile of liquid wealth among the employed: share of the income loss absorbed by consumption")
    for q in 1:4
        sel = findall(i -> (q - 1) / 4 < cm[i] <= q / 4 || (q == 1 && cm[i] <= 0.25), all_)
        @printf("     quartile %d: %.0f%%%s\n", q, 100 * tot(x -> x.dc, sel) / tot(x -> x.dy, sel),
                q == 1 ? @sprintf("   (INSEE lowest: %.0f%%)", bench[("consumption_share_of_income_loss_lowest_liquidity_quartile", "FR")]) :
                q == 4 ? @sprintf("   (INSEE highest: %.0f%%)", bench[("consumption_share_of_income_loss_highest_liquidity_quartile", "FR")]) : "")
    end
end
println("DONE")

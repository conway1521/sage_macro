# How dispersed are the model's incomes, against official figures, and what does
# a more dispersed income process do? Version 3 economy (G), France by default.
# For each standard deviation of the innovation to the persistent component
# (eta; 0.10 is the calibration so far, the persistent part of hourly wages
# alone, Bayer and Juessen 2012), phi and top patience are refitted to effort
# and the hand-to-mouth share, and the distribution of disposable income is
# measured household by household.
# Official, 2021, EU-SILC: the income quintile share ratio S80/S20 of people
# under 65 (ilc_di11) and the in-work at-risk-of-poverty rate, 60% of the
# median, employed aged 18 to 64 (ilc_iw01).
#
#   julia --project=scripts/run_env scripts/probe_income_process.jl [CODE]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
DATA = Dict("FR" => (s8020 = 4.72, inwork = 0.067, htm = 0.222, liq = 0.059, mpc = 0.392),
            "DE" => (s8020 = 5.08, inwork = 0.086, htm = 0.225, liq = 0.140, mpc = 0.468),
            "IT" => (s8020 = 6.04, inwork = 0.117, htm = 0.179, liq = 0.272, mpc = 0.469))[code]
E = parse(Float64, country_rows()[code]["effort_target"])
base = SAGEConfig(country_config(code; config = "G", v3 = true, missing_ok = true, S = false, A = false); beta_spread = 0.0)

"Income statistics, household by household: (S80/S20, Gini, share below 50% and 60% of the median, the same among the employed)."
function income_stats(c)
    cs = cells_of(c); _, bw = betas_of(c); cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    ys = Float64[]; ws = Float64[]; emp = Bool[]
    for g in 1:2, (k, p0) in enumerate(params_of(cT, cs[g]))
        p = update(p0; social_strength = 0.0)
        s = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
        for st in eachindex(s.z_vals), i in eachindex(s.a), d in (0, 1)
            pd = d == 1 ? s.P1[i, st] : 1 - s.P1[i, st]; m = cs[g].share * bw[k] * s.lambda[i, st] * pd; m <= 0 && continue
            y = (1 + p.subsidy) * p.α[st] * s.e_d[d+1][i, st] * s.z_vals[st] * p.Z + (p.R - 1) * s.a[i] - p.lumptax + transfer_at(p, st)
            push!(ys, y); push!(ws, m); push!(emp, s.z_vals[st] > 0)
        end
    end
    o = sortperm(ys); y = ys[o]; w = ws[o] ./ sum(ws); e = emp[o]; cw = cumsum(w)
    med = y[findfirst(>=(0.5), cw)]
    bot = sum(w[i] * y[i] for i in eachindex(y) if cw[i] <= 0.2); top = sum(w[i] * y[i] for i in eachindex(y) if cw[i] > 0.8)
    tot = sum(w .* y); L = cumsum(w .* y) ./ tot
    gini = 1 - sum(w[i] * (L[i] + (i > 1 ? L[i-1] : 0.0)) for i in eachindex(y))
    below(q, sel) = sum(w[i] for i in eachindex(y) if sel[i] && y[i] < q * med; init = 0.0) / sum(w[sel])
    (s8020 = top / bot, gini = gini, p50 = below(0.5, trues(length(y))), p60 = below(0.6, trues(length(y))), inwork60 = below(0.6, e))
end
"phi to the effort target and top patience to the hand-to-mouth share, a few alternating steps."
function fit(c)
    lp = log(6.5); bb = 0.94; r = nothing
    for it in 1:7
        r = solve_economy(SAGEConfig(c; phi = exp(lp), beta_bar = bb); cache = false)
        de = r.mean_effort_employed - E; dh = r.hand_to_mouth_kvw - DATA.htm
        (abs(de) < 1e-3 && abs(dh) < 5e-3) && break
        lp += (c.psi + 2.0) * log(r.mean_effort_employed / E)
        bb = clamp(bb + 0.085 * dh, 0.86, 0.975)        # about 0.012 of patience per 0.14 of hand-to-mouth (probe_liquid_calibration)
    end
    (r, exp(lp), bb)
end
@printf("%s, version 3 G. Official 2021: S80/S20 under 65 %.2f | in-work poverty (60%% of the median) %.3f | hand-to-mouth %.3f | liquid wealth / income %.3f | self-reported MPC %.3f\n",
        code, DATA.s8020, DATA.inwork, DATA.htm, DATA.liq, DATA.mpc)
@printf("%5s | %7s %8s | %8s %6s %7s %7s %9s | %6s %8s %6s %7s %9s\n", "eta", "phi", "patience", "S80/S20", "Gini", "<50%", "<60%", "in-work", "htm", "liq/inc", "MPC", "MPC htm", "job drop")
for eta in (0.10, 0.15, 0.20, 0.25, 0.30)
    c = SAGEConfig(base; eta_z = eta)
    r, ph, bb = fit(c)
    st = income_stats(SAGEConfig(c; phi = ph, beta_bar = bb))
    @printf("%5.2f | %7.3f %8.4f | %8.2f %6.3f %7.3f %7.3f %9.3f | %6.3f %8.3f %6.3f %7.3f %9.3f\n", eta, ph, bb, st.s8020, st.gini, st.p50, st.p60, st.inwork60,
            r.hand_to_mouth_kvw, r.wealth_p50 / r.median_income, r.mpc, r.mpc_htm, r.consumption_drop)
    flush(stdout)
end
println("DONE")

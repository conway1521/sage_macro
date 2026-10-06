# The transitory part and the proportional tax in the engine (V3_START.md, section 29, step 1).
#
#   1. Off, nothing moves: France G of the education regime gives the numbers it gave before the
#      change (the refit probe's base row, runs of 2026-10-06, read with the old engine).
#   2. On, the engine gives what the probe gave at the household level (probe_transitory_tax.jl,
#      fit mode, France): the hand-to-mouth share, the MPC and the fall in consumption on job loss
#      at the probe's refitted patience, gap and persistent dispersion. The probe took the job's
#      effort levels at the base's patience and the engine takes them at the economy's own, so the
#      agreement is to the second decimal, not exact.
#   3. The benefit bill is covered: the proportional tax raises what the lump-sum tax raised.
#   4. Every switch still solves with both on: S, A (dread), and the means-tested floor.
#
#   julia --project=scripts/run_env scripts/test_transitory_engine.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
results = Tuple{String,Bool}[]
check(name, ok) = (push!(results, (name, ok)); @printf("   -> %s: %s\n", name, ok ? "PASS" : "FAIL"); flush(stdout))
row(tag, r) = (@printf("   %-34s htm %.4f | MPC %.4f | fall on job loss %.4f | liquid over mean income %.4f | effort %.4f\n", tag,
                       r.hand_to_mouth_kvw, r.mpc, r.consumption_drop, r.wealth_p50 / r.mean_labour_income, r.mean_effort_employed); flush(stdout))

println("1. Both off: France G, education regime")
c0 = country_config("FR"; config = "G", v3 = :edu, S = false, A = false)
r0 = solve_economy(c0; cache = false); row("base", r0)
check("off: hand-to-mouth 0.221 to 0.222 and MPC 0.305, as before the change", abs(r0.hand_to_mouth_kvw - 0.2215) < 0.002 && abs(r0.mpc - 0.305) < 0.002)

println("2. On, against the probe at the household level (France, refit of 2026-10-06)")
# (transitory sd, tax, persistent sd, top patience, gap) -> the probe's (htm, MPC, fall on job loss)
cases = [((0.178, :prop, 0.2534, 0.8933, 0.0423), (0.222, 0.412, 0.149)),
         ((0.178, :lump, 0.2534, 0.8774, 0.0487), (0.222, 0.440, 0.182)),
         ((0.0, :prop, 0.2628, 0.9287, 0.0370), (0.221, 0.265, 0.156)),
         ((0.126, :prop, 0.2581, 0.9056, 0.0384), (0.222, 0.376, 0.157))]
for ((sd, tax, eta, top, gap), (h, m, dj)) in cases
    c = SAGEConfig(c0; sd_eps = sd, tax_mode = tax, eta_z = eta, beta_bar = top, beta_cell = (-gap, 0.0))
    r = solve_economy(c; cache = false)
    tag = @sprintf("sd %.3f, %s", sd, tax === :prop ? "proportional" : "lump-sum"); row(tag, r)
    @printf("   %-34s htm %.3f  | MPC %.3f  | fall on job loss %.3f\n", "   the probe", h, m, dj)
    check(tag * ": within 0.015 of the probe on the three", abs(r.hand_to_mouth_kvw - h) < 0.015 && abs(r.mpc - m) < 0.015 && abs(r.consumption_drop - dj) < 0.015)
end

println("3. The budget: revenue of the proportional tax against the benefit bill")
let c = floor_effort(SAGEConfig(c0; sd_eps = 0.178, tax_mode = :prop))
    T = ui_tax_of(c); cT = SAGEConfig(c; lumptax = c.lumptax + T); cs = cells_of(cT); _, bw = betas_of(cT)
    rev = 0.0; mass = 0.0
    for g in 1:2, (k, p) in enumerate(params_of(cT, cs[g]))
        s = solve_participation_logit(update(p; social_strength = 0.0), 1.0; theta = cT.theta, full = true)
        z, _ = SAGEBewley.income_process(p)
        for st in eachindex(z), i in eachindex(s.a), d in (0, 1)
            w = cs[g].share * bw[k] * s.lambda[i, st] * (d == 1 ? s.P1[i, st] : 1 - s.P1[i, st]); w <= 0 && continue
            rev += w * (-p.subsidy) * p.α[st] * s.e_d[d+1][i, st] * z[st] * p.Z; mass += w
        end
    end
    @printf("   revenue per head %.6f | benefit bill per head %.6f | off by %.2e\n", rev / mass, T, rev / mass - T)
    check("revenue equals the bill to 1e-5 of mean pay", abs(rev / mass - T) < 1e-5)
end

println("4. The switches, both on")
for (code, cfg, reg) in (("FR", "GS", :edu), ("FR", "GSA", :edu), ("FR", "GA", :edu), ("IT", "G", :floor_edu))
    try
        c = SAGEConfig(country_config(code; config = cfg, v3 = reg, S = occursin('S', cfg), A = occursin('A', cfg)); sd_eps = 0.178, tax_mode = :prop)
        r = solve_economy(c; cache = false); st = income_stats(c)
        row(code * " " * cfg * " " * string(reg), r)
        @printf("      participation %.4f | S80/S20 %.2f | below half the median %.3f | floor's budget off by %.2e\n", r.rate, st.s8020, st.p50, r.budget_gap)
        check(code * " " * cfg * ": solves, finite, budget of the floor within 1e-4",
              isfinite(r.hand_to_mouth_kvw) && isfinite(r.mpc) && isfinite(st.s8020) && abs(r.budget_gap) < 1e-4)
    catch err
        println("      ", first(replace(sprint(showerror, err), "\n" => " "), 300)); check(code * " " * cfg * ": solves", false)
    end
end
println("5. Places under the proportional tax: one national rate, the budget covered")
for code in ("FR", "IT")
    try
        c = SAGEConfig(country_config(code; config = "GE", v3 = :floor_edu, S = false, A = false); sd_eps = 0.178, tax_mode = :prop)
        c0 = SAGEConfig(c; E = false)
        places, w = places_from_data(c.country, c0; typology = c.typology, channels = c.e_channels, epsilon = c.epsilon)
        T = national_tax(c0, places, w); cps = [place_config(c0, pl, T) for pl in places]
        L = NAT_TAX_BASE[][2]
        rs = [solve_economy(cp; cache = false) for cp in cps]
        own = [labour_base(floor_effort(SAGEConfig(cp; S = false))) for cp in cps]
        rev = sum(w[i] * (T / L) * own[i] for i in eachindex(w))                      # the rate on each place's labour income
        bill = sum(w[i] * (ui_only_tax_of(cps[i]) + rs[i].floor_outlay) for i in eachindex(w)) + c0.lumptax
        @printf("   %s: %d places | national rate %.4f | revenue per head %.6f | benefits and floor per head %.6f | off by %.2e\n", code, length(w), T / L, rev, bill, rev - bill)
        @printf("      hand-to-mouth by place %s | national %.4f | MPC %.4f\n", join([@sprintf("%.3f", r.hand_to_mouth_kvw) for r in rs], " "),
                sum(w[i] * rs[i].hand_to_mouth_kvw for i in eachindex(w)), sum(w[i] * rs[i].mpc for i in eachindex(w)))
        check(code * " with places: revenue covers the bill to 1e-4 of mean pay", abs(rev - bill) < 1e-4)
    catch err
        println("      ", first(replace(sprint(showerror, err), "\n" => " "), 400)); check(code * " with places: solves", false)
    end
end
np = count(last, results)
println(np, " of ", length(results), " checks pass", np == length(results) ? "" : "; FAILED: " * join([n for (n, ok) in results if !ok], "; "))
println("DONE")

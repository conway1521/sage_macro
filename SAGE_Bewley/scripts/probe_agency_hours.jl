# Scoping A (DIMENSIONS_SPEC.md, "A, reopened and scoped", 11 October 2026): what a household does
# with its hours when it can choose them, on the base with the state out of work. No fit and no change
# to the model: G of each country as calibrated, solved twice, with hours set by the job (the base)
# and with every household choosing its own, and a third time with the risk of job loss half as high
# again. The engine does not yet solve chosen hours with the means-tested floor, so the floor is off in
# the three solves (those out of work beyond a year keep the minimum income as their transfer); the
# comparison is between the three, not with the calibrated economy.
#
#   julia --project=scripts/run_env scripts/probe_agency_hours.jl [CODE ...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
codes = isempty(ARGS) ? ["FR", "DE", "IT"] : uppercase.(ARGS)
function households(c0; free)
    c = floor_effort(c0); cs = cells_of(c); _, bw = betas_of(c); cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c)); th = c.theta
    jobs = [(g, k, p, cs[g].share * bw[k]) for g in 1:2 for (k, p) in enumerate(params_of(cT, cs[g]))]
    recs = (nworkers() > 1 ? pmap : map)(jobs) do (g, k, p, w)
        p = update(p; social_strength = 0.0)
        free && (p = update(p; job_effort = false, effort_set = Float64[]))
        s = solve_participation_logit(p, 1.0; theta = th, full = true)
        n3 = length(s.z_vals) ÷ 3; rows = NTuple{6,Float64}[]
        for st in eachindex(s.z_vals), i in eachindex(s.a), d in (0, 1)
            m = w * s.lambda[i, st] * (d == 1 ? s.P1[i, st] : 1 - s.P1[i, st]); m <= 1e-13 && continue
            status = s.z_vals[st] > 0 ? 1.0 : st > 2n3 ? 3.0 : 2.0          # in work, first year out of work, beyond a year
            push!(rows, (m, s.a[i], s.e_d[d+1][i, st], s.c_d[d+1][i, st], status, Float64(g)))
        end
        rows
    end
    reduce(vcat, recs)
end
function table(R)
    m = [r[1] for r in R]; a = [r[2] for r in R]; e = [r[3] for r in R]; cc = [r[4] for r in R]; st = [r[5] for r in R]; g = [r[6] for r in R]
    w = st .== 1; mean_(x, k) = sum(m[k] .* x[k]) / sum(m[k])
    cbar = sum(m .* cc) / sum(m); thr = cbar / 24                      # two weeks of mean consumption
    o = sortperm(a[w]); cw = cumsum(m[w][o]) ./ sum(m[w]); aw = a[w][o]; ew = e[w][o]; mw = m[w][o]
    q(lo, hi) = (k = findall(x -> lo < x <= hi, cw); isempty(k) ? NaN : sum(mw[k] .* ew[k]) / sum(mw[k]))
    (effort = mean_(e, w), effort_low = mean_(e, w .& (g .== 1)), effort_high = mean_(e, w .& (g .== 2)),
     e_q = (q(0.0, 0.25), q(0.25, 0.5), q(0.5, 0.75), q(0.75, 1.0)),
     nobuffer = sum(m[a .<= thr]) / sum(m), assets = sum(m .* a) / sum(m) / cbar,
     c_first = mean_(cc, st .== 2) / mean_(cc, w), c_long = mean_(cc, st .== 3) / mean_(cc, w), cons = cbar)
end
for code in codes
    c = SAGEConfig(country_config(code; config = "G", v3 = :v5m, S = false, A = false); cfloor = 0.0)
    J = table(households(c; free = false)); F = table(households(c; free = true))
    R = table(households(SAGEConfig(c; delta = (1.5 * c.delta[1], 1.5 * c.delta[2])); free = true))
    @printf("\n%s G, the floor off | hours set by the job, hours chosen, hours chosen with job loss 1.5 times as likely\n", code)
    for (nm, f) in (("hours of those in work", x -> x.effort), ("  below tertiary", x -> x.effort_low), ("  tertiary", x -> x.effort_high),
                    ("  lowest quarter of assets", x -> x.e_q[1]), ("  second", x -> x.e_q[2]), ("  third", x -> x.e_q[3]), ("  highest quarter", x -> x.e_q[4]),
                    ("no buffer (under two weeks of spending)", x -> x.nobuffer), ("assets over a year's spending", x -> x.assets),
                    ("spending, first year out of work over in work", x -> x.c_first), ("spending, beyond a year over in work", x -> x.c_long), ("mean spending", x -> x.cons))
        @printf("  %-48s %8.4f %8.4f %8.4f\n", nm, f(J), f(F), f(R))
    end
    @printf("  hours respond to the higher risk by %+.2f%% (taxes move with it); the lowest quarter of assets works %+.1f%% more than the highest when hours are chosen\n",
            100 * (R.effort / F.effort - 1), 100 * (F.e_q[1] / F.e_q[4] - 1))
    flush(stdout)
end
println("DONE")

# A as built on 11 October 2026 (DIMENSIONS_SPEC.md, "A, the definition"): G against G+A in each country,
# read from the calibration of G (A adds no fitted parameter). The first run of the engine with hours
# chosen under the means-tested floor. Prints the economy's moments with A off and on, then, household by
# household with A on, those who choose their hours beside those who do not: hours, hours by assets, who is
# on the floor and not working (the benefit trap), buffers.
#
#   julia --project=scripts/run_env scripts/probe_agency_build.jl [CODE ...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
codes = isempty(ARGS) ? ["FR", "DE", "IT"] : uppercase.(ARGS)
fld(r, f) = hasproperty(r, f) ? getproperty(r, f) : NaN
function households(c0)
    c = floor_effort(c0); cs = cells_of(c); _, bw = betas_by_cell(c); cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c)); th = c.theta
    jobs = [(g, k, p, cs[g].share * bw[g][k]) for g in 1:2 for (k, p) in enumerate(params_of(cT, cs[g]))]
    recs = (nworkers() > 1 ? pmap : map)(jobs) do (g, k, p, w)
        p = update(p; social_strength = 0.0)
        s = solve_participation_logit(p, 1.0; theta = th, full = true)
        rows = NTuple{7,Float64}[]
        for st in eachindex(s.z_vals), i in eachindex(s.a), d in (0, 1)
            m = w * s.lambda[i, st] * (d == 1 ? s.P1[i, st] : 1 - s.P1[i, st]); m <= 1e-13 && continue
            push!(rows, (m, s.a[i], s.e_d[d+1][i, st], s.c_d[d+1][i, st], s.z_vals[st] > 0 ? 1.0 : 0.0, p.job_effort ? 0.0 : 1.0, s.floor_d[d+1][i, st] ? 1.0 : 0.0))
        end
        rows
    end
    reduce(vcat, recs)
end
function side(R, chooser)
    k = [r[6] == chooser for r in R]; any(k) || return nothing
    m = [r[1] for r in R][k]; a = [r[2] for r in R][k]; e = [r[3] for r in R][k]; cc = [r[4] for r in R][k]; w = [r[5] for r in R][k] .== 1; fl = [r[7] for r in R][k] .== 1
    cbar = sum(m .* cc) / sum(m); o = sortperm(a[w]); cw = cumsum(m[w][o]) ./ sum(m[w]); ew = e[w][o]; mw = m[w][o]
    q(lo, hi) = (j = findall(x -> lo < x <= hi, cw); isempty(j) ? NaN : sum(mw[j] .* ew[j]) / sum(mw[j]))
    (mass = sum(m), hours = sum(m[w] .* e[w]) / sum(m[w]), q1 = q(0.0, 0.25), q4 = q(0.75, 1.0),
     idle = sum(m[w .& (e .< 1e-6)]) / sum(m[w]), floor = sum(m[fl]) / sum(m), floor_work = sum(m[fl .& w]) / sum(m[w]),
     nobuffer = sum(m[a .<= cbar / 24]) / sum(m), cons = cbar)
end
for code in codes
    g = country_config(code; config = "G", v3 = :v5m, S = false, A = false); a = country_config(code; config = "GA", v3 = :v5m, S = false, A = true)
    @printf("\n%s | who chooses their hours: below tertiary %.3f, tertiary %.3f | household problems a cell: %d\n", code, a.control_share..., length(betas_by_cell(a)[2][1]))
    rg = solve_economy(g; cache = false); ra = solve_economy(a; cache = false)
    @printf("  %-44s %9s %9s\n", "the economy", "G", "G+A")
    for (nm, f) in (("hand-to-mouth", r -> r.hand_to_mouth_kvw), ("median liquid wealth over income", r -> r.wealth_p50 / r.median_income), ("MPC", r -> r.mpc),
                    ("hours of those in work", r -> r.mean_effort_employed), ("fall in consumption on job loss", r -> r.consumption_drop),
                    ("earnings response to a windfall", r -> fld(r, :mpe)), ("mean consumption", r -> fld(r, :consumption)), ("budget gap", r -> fld(r, :budget_gap)),
                    ("protection if hit", r -> fld(r, :protection)), ("expected loss to unemployment", r -> fld(r, :expected_loss)), ("agency", r -> fld(r, :A)))
        @printf("  %-44s %9.4f %9.4f\n", nm, f(rg), f(ra))
    end
    sg = income_stats(g); sa = income_stats(a)
    @printf("  %-44s %9.4f %9.4f\n  %-44s %9.4f %9.4f\n", "Gini", sg.gini, sa.gini, "in-work poverty", sg.inwork60, sa.inwork60)
    R = households(a); J = side(R, 0.0); F = side(R, 1.0)
    @printf("  %-44s %9s %9s\n", "households with A on", "job sets", "chooses")
    for (nm, f) in (("share of households", x -> x.mass), ("hours of those in work", x -> x.hours), ("  lowest quarter of assets", x -> x.q1), ("  highest quarter", x -> x.q4),
                    ("in work and working no hours", x -> x.idle), ("on the floor, all", x -> x.floor), ("on the floor, among those in work", x -> x.floor_work),
                    ("no buffer", x -> x.nobuffer), ("mean consumption", x -> x.cons))
        @printf("  %-44s %9.4f %9.4f\n", nm, f(J), F === nothing ? NaN : f(F))
    end
    flush(stdout)
end
println("DONE")

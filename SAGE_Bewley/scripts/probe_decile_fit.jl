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
include(joinpath(@__DIR__, "decile_fit.jl"))
cfg = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "GA"
codes = length(ARGS) >= 2 ? uppercase.(ARGS[2:end]) : ["FR", "DE", "IT"]
ASREAD = "ASREAD" in codes; codes = filter(!=("ASREAD"), codes); isempty(codes) && (codes = ["FR", "DE", "IT"])
for code in codes
    c = country_config(code; config = cfg, v3 = :v4, S = false, A = occursin('A', cfg))
    ASREAD || (c = SAGEConfig(c; eta_cell = c.sd_eps_cell, sd_eps_cell = c.eta_cell))
    c = SAGEConfig(c; perm_sd = 0.0, cfloor = 0.0)
    R = income_records(c)
    offc = [official_shape(code, "cutoff_over_median_" * nm) for (nm, _) in SHAPE_QS]; offt = official_shape(code, "share_D10")
    offb = [official_shape(code, "below$(t)_under65") for t in (40, 50, 60, 70)]
    loss(st) = sum(abs2, log.(st.cut ./ offc)) + abs2(log(st.top10 / offt))
    @printf("\n================ %s %s | variances %s | persistent innovation %.3f, %.3f, transitory %.3f, %.3f | official: S80/S20 under 65 %.2f, in-work poverty %.3f\n", code, cfg,
            ASREAD ? "as version 4 read them" : "in the order of the source's equation", (c.eta_cell .^ 2)..., (c.sd_eps_cell .^ 2)...,
            official_shape(code, "s80s20_under65"; file = "income_distribution.csv"), official_shape(code, "inwork_poverty60"; file = "income_distribution.csv"))
    rows = Any[("official", nothing)]
    push!(rows, ("no permanent part", mix_stats(R, [0.0], [1.0])))
    for (nm, par, x0s) in (("sym3", sym3, [[0.3]]), ("free3", free3, [[-0.5, 0.5, 0.0, 0.0], [-0.8, 0.9, -0.5, -1.5]]),
                           ("free5", free5, [[-0.9, -0.4, 0.4, 0.9, 0.0, 0.0, 0.0, 0.0], [-1.0, -0.4, 0.5, 1.3, -1.0, 0.0, 0.0, -2.0]]))
        best = nothing
        for x0 in x0s
            x, fv = nelder_mead(x -> loss(mix_stats(R, par(x)...)), x0)
            (best === nothing || fv < best[2]) && (best = (x, fv))
        end
        lf, wk = par(best[1]); f = exp.(lf); f ./= dot(wk, f)
        push!(rows, (nm, mix_stats(R, lf, wk)))
        @printf("  %-6s nodes (mean one) %s | weights %s | loss %.4f\n", nm, join([@sprintf("%.3f", v) for v in f], " "), join([@sprintf("%.3f", v) for v in wk], " "), best[2])
    end
    @printf("  %-18s %s | top tenth %% | S80/S20 | below 40 50 60 70%% of the median   | in-work 60%% | var of log\n", "", join([@sprintf("%5s", nm) for (nm, _) in SHAPE_QS], " "))
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

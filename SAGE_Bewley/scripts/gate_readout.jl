# The untargeted rows at the calibrated point, old base against the regime with the transitory part and
# the proportional tax (V3_START.md, section 29, step 2): the MPC, the fall in consumption on job loss,
# liquid wealth, and what ten points more of benefit rate do to the hand-to-mouth share.
#
#   julia --project=scripts/run_env scripts/gate_readout.jl [CONFIG] [CODE ...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
cfg = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "G"
codes = length(ARGS) >= 2 ? uppercase.(ARGS[2:end]) : ["FR", "DE", "IT"]
function hf(code, moment)
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        f = split(ln, ",")
        length(f) >= 6 && f[1] == moment && f[2] == code && f[3] == "2021" && f[4] == "all" && f[5] == "all" && return parse(Float64, f[6])
    end
    NaN
end
@printf("%-4s %-22s | %7s %7s %7s | %6s %6s %8s %8s | %s\n", "", "regime", "top b", "gap", "floor", "htm", "MPC", "liq/inc", "job loss", "htm with the benefit rate ten points higher")
for code in codes, reg in (:floor_edu, :floor_edu_trans)
    try
        c = country_config(code; config = cfg, v3 = reg, S = occursin('S', cfg), A = occursin('A', cfg))
        r = solve_economy(c; cache = false)
        r2 = solve_economy(SAGEConfig(c; rr = c.rr + 0.10, rr_public = c.rr_public + 0.10); cache = false)
        @printf("%-4s %-22s | %7.4f %7.4f %7.4f | %6.3f %6.3f %8.3f %8.3f | %.3f (%+.3f)\n", code, reg === :floor_edu ? "base" : "with shock and tax",
                c.beta_bar, -c.beta_cell[1], c.cfloor, r.hand_to_mouth_kvw, r.mpc, r.wealth_p50 / r.median_income, r.consumption_drop,
                r2.hand_to_mouth_kvw, r2.hand_to_mouth_kvw - r.hand_to_mouth_kvw)
    catch err
        @printf("%-4s %-22s | %s\n", code, string(reg), first(replace(sprint(showerror, err), "\n" => " "), 200))
    end
    reg === :floor_edu_trans && @printf("%-4s %-22s | %23s | %6.3f %6.3f %8.3f\n", "", "HFCS 2021", "", hf(code, "htm_model_narrow_total"), hf(code, "mpc_mean"), hf(code, "liquid_kvw_to_disposable_income_ratio_of_medians"))
    flush(stdout)
end
println("DONE")

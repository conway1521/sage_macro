# A calibration run as a probe, for a variant whose switch the calibration workflow does not have
# yet: sets the switches, runs calibrate_country.jl as it is, and prints the calibration file it
# wrote into the log (a probe keeps its log and nothing else). No checkpoints are kept, so the run
# has to finish inside the probe's six hours.
#
#   julia --project=scripts/run_env scripts/probe_calibrate_variant.jl CODE CFG [population] [SWITCH=value ...]
#   e.g. probe_calibrate_variant.jl FR G not_retired SAGE_OUT=1
length(ARGS) >= 2 || error("usage: probe_calibrate_variant.jl CODE CFG [population] [SWITCH=value ...]")
let code = uppercase(ARGS[1]), cfg = uppercase(ARGS[2]), rest = ARGS[3:end]
    ENV["SAGE_V5"] = "1"
    for a in rest
        occursin("=", a) ? (ENV[String(first(split(a, "=")))] = String(last(split(a, "=")))) : (ENV["SAGE_POP"] = a)
    end
    haskey(ENV, "SAGE_TIME_BUDGET_MIN") || (ENV["SAGE_TIME_BUDGET_MIN"] = "335")
    tag = get(ENV, "SAGE_OUT", "0") == "1" ? "v5o" : get(ENV, "SAGE_OUT", "0") == "2" ? "v5m" : "v5"
    out = joinpath(@__DIR__, "calibration_$(tag)_$(code)_$(cfg).txt"); t0 = time()
    atexit() do
        if isfile(out) && mtime(out) >= t0
            println("\n===== ", basename(out), " =====")
            foreach(println, eachline(out))
        else
            println("\nno calibration file written")
        end
    end
    empty!(ARGS); push!(ARGS, code, cfg)
end
include(joinpath(@__DIR__, "calibrate_country.jl"))

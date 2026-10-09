# A diagnostic, not a calibration (V3_START.md, section 53): the version 5 fit of G with the HFCS
# moments taken over the households in the labour force (SAGE_POP=labour_force), or over the not
# retired with a second argument `not_retired`, in place of all households. Runs the calibration
# script; the file it writes stays on the runner.
#
#   julia --project=scripts/run_env scripts/probe_fit_population.jl CODE [labour_force | not_retired]
ENV["SAGE_V5"] = "1"; ENV["SAGE_FLOOR_FROM"] = "G"; ENV["SAGE_POP"] = length(ARGS) >= 2 ? ARGS[2] : "labour_force"
code = uppercase(ARGS[1]); empty!(ARGS); push!(ARGS, code, "G")
include(joinpath(@__DIR__, "calibrate_country.jl"))

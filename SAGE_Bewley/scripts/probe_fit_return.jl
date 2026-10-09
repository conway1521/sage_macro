# A diagnostic, not a calibration (V3_START.md, section 57): the version 5 fit of G with the single
# asset earning the measured real return on households' overnight deposits (about -1% a year in the
# three countries, 2003 to 2021) where the engine has 2%. The one asset is narrow liquid wealth,
# mostly sight accounts. What it does to patience, the wealth moments, the MPC and the fall in
# consumption on job loss. Runs the calibration script; the file stays on the runner.
#
#   julia --project=scripts/run_env scripts/probe_fit_return.jl CODE
ENV["SAGE_V5"] = "1"; ENV["SAGE_RLIQ"] = "deposits"
code = uppercase(ARGS[1]); empty!(ARGS); push!(ARGS, code, "G")
include(joinpath(@__DIR__, "calibrate_country.jl"))

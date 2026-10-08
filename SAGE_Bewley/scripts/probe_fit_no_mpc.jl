# A diagnostic, not a calibration (V3_START.md, section 41): the version 4 fit of G with the MPC taken
# out of the criterion, so that the hand-to-mouth share, its gap by education, median liquid wealth,
# effort and S80/S20 are the moments and the MPC is what the model then gives. It shows whether the
# wealth moments can be met together in a country, which the fit with the MPC in cannot show.
# Runs the calibration script itself; the file it writes stays on the runner and is not committed.
#
#   julia --project=scripts/run_env scripts/probe_fit_no_mpc.jl CODE
ENV["SAGE_V4"] = "1"; ENV["SAGE_FLOOR_FROM"] = "G"; ENV["SAGE_NO_MPC"] = "1"
code = uppercase(ARGS[1]); empty!(ARGS); push!(ARGS, code, "G")
include(joinpath(@__DIR__, "calibrate_country.jl"))

# A variant of the version 5 fit of G, put to the user (V3_START.md, section 49): the hand-to-mouth
# share and its split by education are met first; the floor is searched from 0.10 in every country
# and meets median liquid wealth where it stays positive; where it goes to zero the median is
# reported as a test. Runs the calibration script; the file stays on the runner.
#
#   julia --project=scripts/run_env scripts/probe_fit_htm_first.jl CODE
ENV["SAGE_V5"] = "1"; ENV["SAGE_FLOOR_FROM"] = "G"; ENV["SAGE_HTM_FIRST"] = "1"
code = uppercase(ARGS[1]); empty!(ARGS); push!(ARGS, code, "G")
include(joinpath(@__DIR__, "calibrate_country.jl"))

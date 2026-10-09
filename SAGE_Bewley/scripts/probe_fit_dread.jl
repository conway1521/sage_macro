# Decision A1 (DIMENSIONS_SPEC.md; V3_START.md section 54): dread of job loss acting on choices.
# The version 5 fit of G+A with the dread term in the household's problem at the published weight
# (dread_mode = :behaviour), the floor free again since dread changes how much is saved, the
# permanent types those of G. The question: can the hand-to-mouth share, its split by education and
# median liquid wealth still be met, and at what patience. Runs the calibration script; the file
# stays on the runner.
#
#   julia --project=scripts/run_env scripts/probe_fit_dread.jl CODE
ENV["SAGE_V5"] = "1"; ENV["SAGE_FLOOR_FROM"] = "GA"; ENV["SAGE_DREAD_CHOICE"] = "1"
code = uppercase(ARGS[1]); empty!(ARGS); push!(ARGS, code, "GA")
include(joinpath(@__DIR__, "calibrate_country.jl"))

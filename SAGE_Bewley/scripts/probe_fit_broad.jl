# A diagnostic, not a calibration (V3_START.md, section 47): the version 5 fit of G with liquid wealth
# on the broad definition (saving accounts counted as liquid), so that the hand-to-mouth share, its
# gap by education and the median are those of the broad definition. France keeps its liquid savings
# in regulated saving accounts, which the narrow definition (Kaplan, Violante and Weidner 2014)
# counts as illiquid: narrow median 0.059 of income against 0.380 broad, where Italy's are 0.272 and
# 0.316. Runs the calibration script; the file it writes stays on the runner and is not committed.
#
#   julia --project=scripts/run_env scripts/probe_fit_broad.jl CODE
ENV["SAGE_V5"] = "1"; ENV["SAGE_FLOOR_FROM"] = "G"; ENV["SAGE_LIQ_DEF"] = "broad"
code = uppercase(ARGS[1]); empty!(ARGS); push!(ARGS, code, "G")
include(joinpath(@__DIR__, "calibrate_country.jl"))

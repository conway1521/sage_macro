# A full calibration of one configuration in the base regime at a trial income process (V3_START.md,
# section 31): the persistence of the persistent part and the standard deviation of the transitory
# part given on the command line, everything else the calibration of calibrate_country.jl. For the
# probe workflow, which passes arguments and no environment.
#
#   julia --project=scripts/run_env scripts/calibrate_trial.jl CODE CONFIG RHO SD_EPS [floor from]
ENV["SAGE_V3"] = "1"; ENV["SAGE_FLOOR"] = "1"; ENV["SAGE_EDU"] = "1"; ENV["SAGE_TRANS"] = "1"
ENV["SAGE_RHO"] = ARGS[3]; ENV["SAGE_SDEPS"] = ARGS[4]; ENV["SAGE_FLOOR_FROM"] = length(ARGS) >= 5 ? ARGS[5] : "G"
let a = copy(ARGS)
    empty!(ARGS); push!(ARGS, a[1], a[2])
end
include(joinpath(@__DIR__, "calibrate_country.jl"))

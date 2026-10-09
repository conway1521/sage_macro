# The lowest permanent type and the households out of work (V3_START.md, section 55): a reading of
# the calibrated G of version 5, no new fit. The decile fit puts 9 to 13% of households in a lowest
# type at about 0.4 of mean income; Eurostat counts 9.5 to 10.8% of people under 65 in households
# with very low work intensity. If that type is the households out of work, in-work poverty should
# be read over the other types. This prints, by country: the lowest type's weight against the
# official count, where it sits in the income distribution, and in-work poverty (60% of the median)
# over all the employed and over the employed of the other types, against the official rate.
#
#   julia --project=scripts/run_env scripts/probe_out_of_work.jl [CODE ...]
include(joinpath(@__DIR__, "modular_workers.jl"))
include(joinpath(@__DIR__, "decile_fit.jl"))
codes = isempty(ARGS) ? ["FR", "DE", "IT"] : uppercase.(ARGS)
for code in codes
    c = country_config(code; config = "G", v3 = :v5, S = false, A = false)
    R = income_records(SAGEConfig(c; perm_sd = 0.0, perm_f = Float64[], perm_w = Float64[], cfloor = 0.0, S = false))
    st = mix_stats(R, log.(c.perm_f), c.perm_w)
    @printf("\n%s G, version 5 | types %s | weights %s\n", code, join([@sprintf("%.3f", v) for v in c.perm_f], " "), join([@sprintf("%.3f", v) for v in c.perm_w], " "))
    @printf("  the lowest type: weight %.3f | official, people under 65 in households with very low work intensity %.3f\n", c.perm_w[1], official_shape(code, "very_low_work_intensity_under65"))
    @printf("  its median income over the national median %.3f | share of it below 60%% of the median %.3f\n", st.low_median, st.low_below60)
    @printf("  in-work poverty (60%% of the median): all the employed %.3f | the employed of the other types %.3f | official %.3f\n",
            st.inwork60, st.inwork60_above, official_shape(code, "inwork_poverty60"; file = "income_distribution.csv"))
    @printf("  below 50%% and 60%% of the median, everyone: %.3f, %.3f | official under 65: %.3f, %.3f\n", st.below[2], st.below[3], official_shape(code, "below50_under65"), official_shape(code, "below60_under65"))
    flush(stdout)
end
println("DONE")

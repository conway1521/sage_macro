# Place feasibility, modelling test: does the access-to-work channel alone make
# participation differ by place as the data do?
#
#   julia --project=. scripts/probe_place_fr.jl
#
# France's calibrated G+S+A economy is solved three times, once per Eurostat
# degree of urbanisation (cities, towns and suburbs, rural areas), changing only
# the labour-market flows. The job-finding rate is scaled by each place's
# quarterly unemployment-to-employment probability relative to the national one
# (lfsi_long_e03, 2015 to 2018 mean), and the separation rate follows from the
# place's unemployment rate (lfst_r_urgau, 2023) in steady state. Everything
# else, including the social technology, stays at the national calibration. The
# inputs are the pre-audit ones: this tests the mechanism, not the numbers.
#
# Data (data/place/place_by_degurba.csv): formal volunteering 2015, cities 20.3,
# towns 21.4, rural 27.7 percent.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
say(args...) = (println(args...); flush(stdout))

base = country_config("FR"; config = "GSA", S = true, A = true)
u_nat = 7.0       # lfst_r_urgau, all places, 2023, ages 20 to 64
q_ue_nat = 21.5  # lfsi_long_e03, all places, 2015 to 2018 mean, ages 25 to 54
places = [("cities", 7.9, 20.5, 20.3), ("towns", 7.5, 21.5, 21.4), ("rural", 5.5, 25.2, 27.7)]

b0 = solve_economy(base)
say(@sprintf("national: participation %.4f, unemployment %.4f, poor htm %.4f, A %.4f, A_cond %.4f",
             b0.rate, b0.unemployment, b0.hand_to_mouth_kvw, b0.A, b0.A_cond))
for (name, u_pct, q_ue, vol) in places
    f = min(0.99, base.f_find * q_ue / q_ue_nat)
    # the two education cells keep their relative separation rates, scaled so
    # the place's unemployment rate holds in steady state
    s = (u_pct / 100) / (1 - u_pct / 100) * f / ((u_nat / 100) / (1 - u_nat / 100) * base.f_find)
    c = SAGEConfig(base; f_find = f, delta = (base.delta[1] * s, base.delta[2] * s))
    r = solve_economy(c)
    say(@sprintf("%-7s f %.3f delta %.4f/%.4f | participation %.4f (data volunteering %.1f), unemployment %.4f, poor htm %.4f, A %.4f, A_cond %.4f",
                 name, f, c.delta..., r.rate, vol, r.unemployment, r.hand_to_mouth_kvw, r.A, r.A_cond))
end
say("DONE")

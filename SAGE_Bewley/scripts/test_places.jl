# The place layer (E1). 1: three places identical to the nation give back the
# national economy exactly (G+A and G+S+A). 2: France with composition and access
# to work by place (E2, first two channels), against formal volunteering by place
# (EU-SILC 2015, ilc_scp20: cities 20.3, towns 21.4, rural 27.7), which is
# untargeted.
#
#   julia --project=scripts/run_env scripts/test_places.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
w = [0.366, 0.298, 0.336]
same = [(name = n,) for (n, _) in DEGURBA]
for (lab, c) in (("G+A", country_config("FR"; config = "GA", S = false, A = true)),
                 ("G+S+A", country_config("FR"; config = "GSA", S = true, A = true)))
    r0 = solve_economy(c)
    sp = solve_places(c, same; weights = w)
    worst = maximum(abs(getfield(sp.national, f) - getfield(r0, f)) for (f, _) in PLACE_FIELDS)
    @printf("REDUCTION %s, three identical places -> the nation: largest difference %.1e  %s\n", lab, worst, worst < 1e-12 ? "pass" : "FAIL")
    flush(stdout)
end

c = country_config("FR"; config = "GSA", S = true, A = true)
r0 = solve_economy(c)
for ch in ((:composition,), (:access,), (:composition, :access))
    places, wd = places_from_data("FR", c; channels = ch)
    sp = solve_places(c, places; weights = wd)
    println("\nFrance G+S+A, channels ", join(string.(ch), " + "), " (national tax per head ", round(sp.T_nat; digits = 4), ")")
    @printf("  %-18s %8s %8s %8s %8s %8s %8s %8s %6s\n", "place", "tertiary", "part.", "unempl.", "agency", "prot.", "hardship", "poor htm", "mult")
    for ((name, r), pl) in zip(sp.by_place, places)
        @printf("  %-18s %8.3f %8.4f %8.4f %8.4f %8.4f %8.4f %8.4f %6.1f\n", name, get(pl, :tertiary, c.share[2]), r.rate,
                r.unemployment, r.A, r.A_cond, r.hardship, r.hand_to_mouth_kvw, 1 / (1 - r.slope))
    end
    n = sp.national
    @printf("  %-18s %8s %8.4f %8.4f %8.4f %8.4f %8.4f %8.4f\n", "places together", "", n.rate, n.unemployment, n.A, n.A_cond, n.hardship, n.hand_to_mouth_kvw)
    @printf("  %-18s %8s %8.4f %8.4f %8.4f %8.4f %8.4f %8.4f\n", "national economy", "", r0.rate, r0.unemployment, r0.A, r0.A_cond, r0.hardship, r0.hand_to_mouth_kvw)
    rr = [r.rate for (_, r) in sp.by_place]
    @printf("  rural / cities participation: model %.3f, volunteering data 1.365\n", rr[3] / rr[1])
    flush(stdout)
end
println("DONE")

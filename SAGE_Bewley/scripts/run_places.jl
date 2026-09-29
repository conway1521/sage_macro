# E with all channels, by country: composition, access to work, conversion,
# commuting and (France) community, each alone and all together, at both ends of
# the community elasticity. Untargeted checks by place: formal volunteering
# (ilc_scp20, 2015) and unemployment (lfst_r_urgau, the access input, so a
# consistency check, not a test).
#
#   julia --project=scripts/run_env scripts/run_places.jl FR
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? ARGS[1] : "FR"
c = country_config(code; config = "GSA", S = true, A = true)
d = place_data(code)
vol = [meanyrs(d, "formal_volunteering", p, 2015:2015) for (_, p) in DEGURBA]
all_ch = code == "FR" ? (:composition, :access, :conversion, :commute, :community) : (:composition, :access, :conversion, :commute)
runs = Any[(string(ch), (ch,), 0.4) for ch in all_ch]
push!(runs, ("all channels, epsilon 0.3", all_ch, 0.3))
code == "FR" && push!(runs, ("all channels, epsilon 0.5", all_ch, 0.5))
r0 = solve_economy(c)
@printf("%s national G+S+A: participation %.4f, agency %.4f, protection %.4f, hardship %.4f, poor htm %.4f\n",
        code, r0.rate, r0.A, r0.A_cond, r0.hardship, r0.hand_to_mouth_kvw)
println("volunteering by place (2015): ", join([v === nothing ? "NA" : string(v) for v in vol], " / "))
for (lab, ch, eps) in runs
    places, w = places_from_data(code, c; channels = ch, epsilon = eps)
    t = @elapsed sp = solve_places(c, places; weights = w)
    println("\n", lab, @sprintf("  [%.1f min]", t / 60))
    @printf("  %-18s %8s %8s %8s %8s %8s %8s %6s\n", "place", "part.", "unempl.", "agency", "prot.", "hardship", "poor htm", "mult")
    for (name, r) in sp.by_place
        @printf("  %-18s %8.4f %8.4f %8.4f %8.4f %8.4f %8.4f %6.1f\n", name, r.rate, r.unemployment, r.A, r.A_cond,
                r.hardship, r.hand_to_mouth_kvw, 1 / (1 - r.slope))
    end
    n = sp.national
    @printf("  %-18s %8.4f %8.4f %8.4f %8.4f %8.4f %8.4f\n", "together", n.rate, n.unemployment, n.A, n.A_cond, n.hardship, n.hand_to_mouth_kvw)
    rr = [r.rate for (_, r) in sp.by_place]
    any(isnothing, vol) || @printf("  rural / cities participation: model %.3f, volunteering %.3f | towns / cities: model %.3f, volunteering %.3f\n",
                                   rr[3] / rr[1], vol[3] / vol[1], rr[2] / rr[1], vol[2] / vol[1])
    flush(stdout)
end
println("DONE")

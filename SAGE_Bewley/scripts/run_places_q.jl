# E on version 2's quarterly economy (decided by the user, 2 November 2026; V3_START.md): the country as the three
# types of place of the degree of urbanisation, each its own quarterly economy under one national tax, at the
# calibrated quarterly G's parameters (nothing refitted). Channels: composition, access to work on the quarterly chain
# (:access_q, place_layer.jl), commuting; community enters with S.
#   reduction   three places identical to the nation against the national economy (must agree to about 1e-10)
#   places      the three places from data, with the time each solve takes, and the hand-to-mouth share by place
#               against the HFCS 2021 (households not retired), untargeted
#
#   julia --project=scripts/run_env scripts/run_places_q.jl CODE [reduction | places] [G | GS]
# For G+S and G+S+A the solve with places is longer than one job: use places_staged.jl (workflow places.yml).
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); mode = length(ARGS) >= 2 ? ARGS[2] : "places"; cfg = length(ARGS) >= 3 ? uppercase(ARGS[3]) : "G"
S_ON = occursin('S', cfg)
readkv(f) = (d = Dict{String,String}(); for l in eachline(f); t = strip(l); (isempty(t) || startswith(t, "#") || !occursin("=", t)) && continue;
                 k, v = strip.(split(t, "=", limit = 2)); d[k] = v; end; d)
# the calibrated configuration as every other version 2 script reads it: with S, kappa and sigma_m from the file and the
# 22 belonging scales it was calibrated on (without them a G+S solve did not finish in six hours, 2 November)
c = quarterly_calibrated(code, cfg)
ch = S_ON ? (:composition, :access_q, :commute, :community) : (:composition, :access_q, :commute)
t0 = @elapsed r0 = solve_economy(c; cache = false)
@printf("%s %s quarterly, the nation [%.1f min]: unemployment %.4f, hand-to-mouth %.4f, MPC 12 months %.4f, fall %.4f, participation %.4f\n",
        code, cfg, t0 / 60, r0.unemployment, r0.hand_to_mouth_kvw, r0.mpc12, r0.fall_kolsrud, r0.rate)
flush(stdout)
if mode == "reduction"
    same = [(name = "identical $i",) for i in 1:3]
    t1 = @elapsed sp = solve_places(c, same; weights = [0.4, 0.35, 0.25])
    worst = maximum(abs(getfield(sp.national, f) - getfield(r0, f)) for (f, _) in PLACE_FIELDS if isfinite(getfield(r0, f)))
    @printf("REDUCTION [%.1f min]: three identical places against the nation, largest difference %.1e: %s\n", t1 / 60, worst, worst < 1e-10 ? "PASS" : "FAIL")
    # the channel itself on identical data: places_from_data must hand back the nation's chain
    pls, w = places_from_data(code, c; typology = :degurba, channels = (:access_q,))
    println("  access_q specs (data): ", [(p.name, round.(p.hU_vec[1:2], digits = 4), round.(p.delta, digits = 5), round.(p.iotaE, digits = 5)) for p in pls])
    @printf("  nation: hU %s, delta %s, iota %s\n", string(round.(c.hU_vec[1:2], digits = 4)), string(round.(c.delta, digits = 5)), string(round.(c.iotaE, digits = 5)))
    println("DONE"); exit()
end
cE = SAGEConfig(c; E = true, typology = :degurba, e_channels = ch)
t1 = @elapsed rE = solve_economy(cE; cache = false)
@printf("%s %s quarterly with E, three places [%.1f min in all]: unemployment %.4f, hand-to-mouth %.4f, participation %.4f\n",
        code, cfg, t1 / 60, rE.unemployment, rE.hand_to_mouth_kvw, rE.rate)
htm = Dict{String,Float64}()
for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
    startswith(ln, "#") && continue
    f = split(ln, ",")
    length(f) >= 6 && f[1] == "htm_model_narrow_total" && f[2] == code && f[3] == "2021" && f[4] == "degurba_nr" && (htm[f[5]] = parse(Float64, f[6]))
end
for (nm, r) in rE.by_place
    @printf("  %-18s unemployment %.4f, hand-to-mouth %.4f (HFCS %s), MPC 12 months %.4f, fall %.4f, participation %.4f\n", nm, r.unemployment,
            r.hand_to_mouth_kvw, haskey(htm, nm) ? @sprintf("%.4f", htm[nm]) : "n/a", r.mpc12, r.fall_kolsrud, r.rate)
end
println("DONE")

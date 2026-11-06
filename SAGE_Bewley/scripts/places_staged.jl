# E on version 2's quarterly economy in stages, for configurations whose solve with places is longer than one job
# (G+S+E and G+S+A+E: one family build on the 22 belonging scales takes 100 to 185 minutes, and a solve with three
# places needs six). The steps are those of `solve_economy_places` (place_layer.jl), each saved to a file that the next
# job reads, so the result is the same as one long solve. Index 0 is the nation without E, solved alongside.
#   setup        the places, the national tax and every configuration                   -> setup.jls
#   pass1 I      place I (0: the nation) with any thresholds                             -> r1_I.jls
#   pass2 I      place I at the thresholds from every place's first pass (the nation's own) -> r2_I.jls
#   aggregate    the national aggregates with E, against the nation without, by place, and hand-to-mouth by place
#                against the HFCS 2021 households not retired (France only; untargeted)
#
#   julia --project=scripts/run_env scripts/places_staged.jl CODE CFG STAGE [I] DIR
#
# SAGE_PLACES_VARIANT (unset by default, which gives the calibrated configuration) takes one channel of A out at the
# same calibration, to decompose a result: `overlay` keeps dread in wellbeing only, `nosearch` switches job search off.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Serialization
code = uppercase(ARGS[1]); cfg = uppercase(ARGS[2]); stage = ARGS[3]
idx = stage in ("pass1", "pass2") ? parse(Int, ARGS[4]) : -1
dir = ARGS[end]; mkpath(dir)
say(x...) = (println(x...); flush(stdout))
f(name) = joinpath(dir, name)

if stage == "setup"
    c = quarterly_calibrated(code, cfg)
    variant = get(ENV, "SAGE_PLACES_VARIANT", "")
    variant == "overlay" && (c = SAGEConfig(c; dread_mode = :overlay))
    variant == "nosearch" && (c = SAGEConfig(c; search = false))
    variant in ("", "overlay", "nosearch") || error("unknown variant $variant")
    isempty(variant) || say("variant: $variant (dread $(c.dread_mode), search $(c.search))")
    ch = c.S ? (:composition, :access_q, :commute, :community) : (:composition, :access_q, :commute)
    cE = SAGEConfig(c; E = true, typology = :degurba, e_channels = ch)
    t = @elapsed st = places_setup(cE)
    serialize(f("setup.jls"), (st = st, nation = c))
    say(@sprintf("%s %s setup [%.1f min]: places %s, weights %s, national total per head %.6f", code, cfg, t / 60,
                 join([p.name for p in st.places], ", "), string(round.(st.w, digits = 3)), st.T_nat))
elseif stage == "pass1"
    s = deserialize(f("setup.jls"))
    cp = idx == 0 ? s.nation : s.st.cps[idx]
    t = @elapsed r1 = _solve(cp, nothing; disk = true, any_thresholds = true)   # disk: a killed job keeps each cell it finished
    serialize(f("r1_$(idx).jls"), r1)
    say(@sprintf("%s %s pass 1, %s [%.1f min]: mean income %.5f, median %.5f", code, cfg, idx == 0 ? "the nation" : s.st.places[idx].name,
                 t / 60, r1.mean_income, r1.median_income))
elseif stage == "pass2"
    s = deserialize(f("setup.jls"))
    if idx == 0
        r1 = deserialize(f("r1_0.jls")); m = r1.median_income
        thr = [(0.5 * m, hardship_threshold(m; months = s.nation.months))]
        cp = s.nation
    else
        thr = places_thresholds(s.st, [deserialize(f("r1_$(i).jls")) for i in eachindex(s.st.cps)])
        cp = s.st.cps[idx]
    end
    t = @elapsed r = solve_economy(cp; thresholds = thr, cache = true)
    serialize(f("r2_$(idx).jls"), (r = r, thr = thr))
    say(@sprintf("%s %s pass 2, %s [%.1f min]: unemployment %.4f, hand-to-mouth %.4f, participation %.4f", code, cfg,
                 idx == 0 ? "the nation" : s.st.places[idx].name, t / 60, r.unemployment, r.hand_to_mouth_kvw, r.rate))
elseif stage == "aggregate"
    s = deserialize(f("setup.jls"))
    n = length(s.st.cps)
    p2 = [deserialize(f("r2_$(i).jls")) for i in 1:n]
    rE = places_aggregate(s.st, [x.r for x in p2], p2[1].thr)
    r0 = deserialize(f("r2_0.jls")).r
    htm = Dict{String,Float64}()
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        x = split(ln, ",")
        length(x) >= 6 && x[1] == "htm_model_narrow_total" && x[2] == code && x[3] == "2021" && x[4] == "degurba_nr" && (htm[x[5]] = parse(Float64, x[6]))
    end
    hf(nm) = haskey(htm, nm) ? @sprintf("%.4f", htm[nm]) : haskey(htm, replace(nm, " areas" => "")) ? @sprintf("%.4f", htm[replace(nm, " areas" => "")]) : "n/a"
    say(@sprintf("%s %s quarterly, the nation without E: unemployment %.4f, hand-to-mouth %.4f, MPC 12 months %.4f, fall %.4f, participation %.4f",
                 code, cfg, r0.unemployment, r0.hand_to_mouth_kvw, r0.mpc12, r0.fall_kolsrud, r0.rate))
    say(@sprintf("%s %s quarterly with E: unemployment %.4f, hand-to-mouth %.4f, participation %.4f, multiplier %.3f",
                 code, cfg, rE.unemployment, rE.hand_to_mouth_kvw, rE.rate, 1 / (1 - rE.slope)))
    for (nm, r) in rE.by_place
        say(@sprintf("  %-18s unemployment %.4f, hand-to-mouth %.4f (HFCS %s), MPC 12 months %.4f, fall %.4f, participation %.4f",
                     nm, r.unemployment, r.hand_to_mouth_kvw, hf(nm), r.mpc12, r.fall_kolsrud, r.rate))
    end
    serialize(f("result.jls"), (with_E = rE, without_E = r0))
    say("DONE")
else
    error("stage is setup, pass1, pass2 or aggregate")
end

# The identification check (V3_START.md, method): how each moment moves with
# each parameter, at a point, in one table. A parameter is identified by the
# targets it owns when its column is large and the owned block of the table is
# well conditioned. A flat column means the parameter is not identified by
# these moments (as omega and the two-asset fixed cost turned out to be).
#
# Entries are the change in each moment, in units of its tolerance band, for a
# 10% change in the parameter (or 0.05 in a share); the last columns give the
# condition number of the owned block and, for each parameter, the moment that
# moves most per band.
#
# Default: France, one asset, G with effort set by the job, at a pilot point
# with an impatient group, the v3 parameter set and targets.
#
# With a third argument v3: at the version 3 calibration of the country, the
# four parameters of the version 3 fit (effort scale, top patience, patience
# spread, income dispersion) against its four moments (effort, median liquid
# wealth over income, the hand-to-mouth share, S80/S20), in the bands of
# calibrate_country.jl, with the MPC and the consumption drop as untargeted rows.
#
# With a third argument base: at the base's calibration of the country (the floor, patience by
# education, the transitory part and the proportional tax; calibration_v3fet_*): the parameters of its
# fit (effort scale, top patience, income dispersion, the patience gap by education, and the floor
# where it is not zero) against their moments (effort, the hand-to-mouth share, S80/S20, the
# difference in the hand-to-mouth share by education, and median liquid wealth for the floor).
#
#   julia --project=scripts/run_env scripts/identification.jl [CODE] [CONFIG] [v3 | base]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
cfg = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "G"
BASEID = length(ARGS) >= 3 && lowercase(ARGS[3]) == "base"
V3 = BASEID || (length(ARGS) >= 3 && lowercase(ARGS[3]) == "v3")
c0 = BASEID ? country_config(code; config = cfg, v3 = :floor_edu_trans, S = false, A = occursin('A', cfg)) :
     V3 ? country_config(code; config = cfg, v3 = true, S = false, A = occursin('A', cfg)) :
     SAGEConfig(country_config(code; config = cfg, S = false, A = occursin('A', cfg)); effort_mode = :job,
                beta_spread = 0.0, impatient_share = 0.20, beta_low = 0.75)

# parameters: name, getter, setter, step (relative unless `abs`)
params = [
    (:phi, c -> c.phi, (c, v) -> SAGEConfig(c; phi = v), 0.10, false),
    (:impatient_share, c -> c.impatient_share, (c, v) -> SAGEConfig(c; impatient_share = v), 0.05, true),
    (:beta_low, c -> c.beta_low, (c, v) -> SAGEConfig(c; beta_low = v), 0.05, true),
    (:beta_bar, c -> c.beta_bar, (c, v) -> SAGEConfig(c; beta_bar = v), 0.005, true),
]
V3 && (params = [
    (:phi, c -> c.phi, (c, v) -> SAGEConfig(c; phi = v), 0.10, false),
    (:beta_bar, c -> c.beta_bar, (c, v) -> SAGEConfig(c; beta_bar = v), 0.005, true),
    (:beta_spread, c -> c.beta_spread, (c, v) -> SAGEConfig(c; beta_spread = v), 0.02, true),
    (:eta_z, c -> c.eta_z, (c, v) -> SAGEConfig(c; eta_z = v), 0.02, true),
])
# moments: name, getter, tolerance band
moments = [
    (:effort, r -> r.mean_effort_employed, 0.005),
    (:htm_total, r -> r.hand_to_mouth_kvw, 0.01),
    (:mpc, r -> r.mpc, 0.05),
    (:liquid_wealth, r -> r.wealth_p50 / r.median_income, 0.05),
    (:consumption_drop, r -> r.consumption_drop, 0.02),
]
owned = Dict(:phi => :effort, :impatient_share => :htm_total, :beta_low => :mpc, :beta_bar => :liquid_wealth)
if V3
    moments = [
        (:effort, r -> r.mean_effort_employed, 0.005),
        (:htm_total, r -> r.hand_to_mouth_kvw, 0.02),
        (:liquid_wealth, r -> r.wealth_p50 / r.median_income, 0.09),
        (:s8020, r -> r.s8020, 0.25),
        (:mpc, r -> r.mpc, 0.05),
        (:consumption_drop, r -> r.consumption_drop, 0.02),
    ]
    owned = Dict(:phi => :effort, :beta_bar => :htm_total, :beta_spread => :liquid_wealth, :eta_z => :s8020)
end
if BASEID
    params = [
        (:phi, c -> c.phi, (c, v) -> SAGEConfig(c; phi = v), 0.10, false),
        (:beta_bar, c -> c.beta_bar, (c, v) -> SAGEConfig(c; beta_bar = v), 0.005, true),
        (:eta_z, c -> c.eta_z, (c, v) -> SAGEConfig(c; eta_z = v), 0.02, true),
        (:patience_gap, c -> -c.beta_cell[1], (c, v) -> SAGEConfig(c; beta_cell = (-v, 0.0)), 0.01, true),
    ]
    c0.cfloor > 0 && push!(params, (:floor, c -> c.cfloor, (c, v) -> SAGEConfig(c; cfloor = v), 0.10, false))
    hgap(r) = sum(r.pooled[1].hmass) / sum(r.pooled[1].mass) - sum(r.pooled[2].hmass) / sum(r.pooled[2].mass)
    moments = [
        (:effort, r -> r.mean_effort_employed, 0.005),
        (:htm_total, r -> r.hand_to_mouth_kvw, 0.02),
        (:s8020, r -> r.s8020, 0.25),
        (:htm_by_education, hgap, 0.03),
        (:liquid_wealth, r -> r.wealth_p50 / r.median_income, c0.cfloor > 0 ? 0.03 : 0.09),
        (:mpc, r -> r.mpc, 0.05),
        (:consumption_drop, r -> r.consumption_drop, 0.02),
    ]
    owned = Dict(:phi => :effort, :beta_bar => :htm_total, :eta_z => :s8020, :patience_gap => :htm_by_education, :floor => :liquid_wealth)
end
# the income distribution is a property of the configuration, not of the solved economy: carried beside it
solve_at(c) = (r = solve_economy(c; cache = false); V3 ? merge(r, (s8020 = income_stats(c).s8020,)) : r)

r0 = solve_at(c0)
m0 = [g(r0) for (_, g, _) in moments]
BASEID ? @printf("%s %s, one asset, the base, at: phi %.3f, top patience %.4f, eta %.4f, patience gap %.4f, floor %.4f\n", code, cfg, c0.phi, c0.beta_bar, c0.eta_z, -c0.beta_cell[1], c0.cfloor) :
V3 ? @printf("%s %s, one asset, version 3, at: phi %.3f, top patience %.4f, spread %.4f, eta %.4f\n", code, cfg, c0.phi, c0.beta_bar, c0.beta_spread, c0.eta_z) :
@printf("%s %s, one asset, effort set by the job, at: phi %.3f, impatient share %.2f at %.2f, beta_bar %.3f\n", code, cfg,
        c0.phi, c0.impatient_share, c0.beta_low, c0.beta_bar)
@printf("moments: %s\n", join([@sprintf("%s %.4f", n, v) for ((n, _, _), v) in zip(moments, m0)], ", "))
J = zeros(length(moments), length(params))
for (j, (pn, get, set, h, isabs)) in enumerate(params)
    v = get(c0); dv = isabs ? h : h * v
    r = solve_at(set(c0, v + dv))
    for (i, (_, g, tol)) in enumerate(moments)
        J[i, j] = (g(r) - m0[i]) / tol           # bands per step
    end
end
println("\nchange in each moment, in tolerance bands, for one step in the parameter (", BASEID ? "phi +10%; top patience +0.005; eta +0.02; patience gap +0.01; floor +10%" : V3 ? "phi +10%; top patience +0.005; spread +0.02; eta +0.02" : "phi +10%; shares and patience +0.05; beta_bar +0.005", ")")
@printf("%-18s", ""); for (pn, _, _, _, _) in params; @printf("%17s", pn); end; println()
for (i, (mn, _, _)) in enumerate(moments)
    @printf("%-18s", mn); for j in eachindex(params); @printf("%17.2f", J[i, j]); end; println()
end
own = [findfirst(m -> m[1] == owned[p[1]], moments) for p in params]
B = J[own, :]
@printf("\nowned block (rows: each parameter's own target): condition number %.1f\n", cond(B))
for (j, (pn, _, _, _, _)) in enumerate(params)
    i = argmax(abs.(J[:, j]))
    @printf("  %-16s owns %-14s (%+.2f bands); moves most: %-16s (%+.2f)%s\n", pn, owned[pn], J[own[j], j], moments[i][1], J[i, j],
            maximum(abs.(J[:, j])) < 0.5 ? "   FLAT: not identified at this step" : "")
end
println("DONE")

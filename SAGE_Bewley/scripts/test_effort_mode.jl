# Effort set by the job (SAGEParams.job_effort, SAGEConfig.effort_mode = :job):
# checks on one country, one asset, S off, at the calibrated parameters.
#  1. the effort condition holds on average in every employed state, and the
#     fixed point converged;
#  2. a household's own wealth does not move its effort: the earnings response
#     to a windfall is exactly zero, and consumption and saving add up to one;
#  3. effort still responds to the return to work: a 10% wage subsidy (paid for
#     by the lump-sum tax in the config, not balanced here) raises effort;
#  4. the limit: with effort nearly inelastic (psi = 40) wealth hardly moves
#     freely chosen effort either, so the two modes agree;
#  5. the comparison that motivates the switch: the MPC, overall and of the
#     hand-to-mouth, under both modes.
# Effort is not refitted: phi is the free-effort calibration's, so mean effort
# under :job differs a little from the target.
#
#   julia --project=scripts/run_env scripts/test_effort_mode.jl [CODE] [CONFIG]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
cfg = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "G"
c = country_config(code; config = cfg, S = false, A = occursin('A', cfg))
cj = SAGEConfig(c; effort_mode = :job)
results = Tuple{String,Bool}[]
check(name, ok) = (push!(results, (name, ok)); @printf("   -> %s: %s\n", name, ok ? "PASS" : "FAIL"); flush(stdout))

println("1. the effort condition on average, household problems one by one")
cs = cells_of(cj); cT = SAGEConfig(cj; lumptax = cj.lumptax + ui_tax_of(cj))
worst = 0.0; wgap = 0.0; its = 0
for g in 1:2, p0 in params_of(cT, cs[g])
    p = update(p0; social_strength = 0.0)
    s = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
    z = s.z_vals; κ = 1 + p.commute
    global wgap = max(wgap, s.effort_gap); global its = max(its, s.effort_iters)
    for st in eachindex(z)
        z[st] > 0 || continue
        w = (1 + p.subsidy) * p.α[st] * z[st] * p.Z; tr = transfer_at(p, st); tf = floor_at(p, st)
        m = 0.0; lhs = 0.0; rhs = 0.0; spread = 0.0
        for i in eachindex(s.a), d in (0, 1)
            pd = d == 1 ? s.P1[i, st] : 1 - s.P1[i, st]; l = s.lambda[i, st] * pd; l <= 0 && continue
            e = s.e_d[d+1][i, st]
            cc = (p.R * s.a[i] + w * e - p.lumptax + net_participation(p, p.α[st], z[st]) * d + tr - s.a_d[d+1][i, st]) / p.pc
            lhs += l * (w / p.pc) * cc^(-p.γ); rhs += l * p.ϕ * κ * (tf + κ * e + p.qbar * d)^p.ψ; m += l
            spread = max(spread, abs(e - s.effort_set[st]))
        end
        global worst = max(worst, abs(lhs / m - rhs / m) / (rhs / m), spread)
    end
end
@printf("   largest relative gap in the average condition, or effort off its set level: %.1e; fixed point gap %.1e in at most %d steps\n", worst, wgap, its)
check("the average effort condition holds", worst < 1e-5)

println("2. the economy under both modes")
rf = solve_economy(c; cache = false); rj = solve_economy(cj; cache = false)
row(tag, r) = @printf("   %-6s effort %.4f | htm %.3f | MPC %.3f (of the htm %.3f) | saving %.3f | earnings %+.4f | adding up %.6f | drop on job loss %.3f | liquid wealth p50 %.3f\n",
                      tag, r.mean_effort_employed, r.hand_to_mouth_kvw, r.mpc, r.mpc_htm, r.mps, r.mpe, r.mpc + r.mps - r.mpe, r.consumption_drop, r.wealth_p50)
row("free", rf); row("job", rj)
check("the earnings response to a windfall is zero", abs(rj.mpe) < 1e-10)
check("consumption and saving add up", abs(rj.mpc + rj.mps - 1) < 1e-6)
check("the hand-to-mouth spend more of a windfall than under free effort", rj.mpc_htm > rf.mpc_htm)

println("3. effort responds to the return to work")
rs = solve_economy(SAGEConfig(cj; subsidy = 0.10); cache = false); rsf = solve_economy(SAGEConfig(c; subsidy = 0.10); cache = false)
@printf("   10%% wage subsidy: effort %+.2f%% under job (%+.2f%% under free)\n", 100 * (rs.mean_effort_employed / rj.mean_effort_employed - 1),
        100 * (rsf.mean_effort_employed / rf.mean_effort_employed - 1))
check("a wage subsidy moves effort set by the job", abs(rs.mean_effort_employed / rj.mean_effort_employed - 1) > 1e-4)

println("4. the inelastic limit, psi = 40 (phi rescaled so effort stays near its level)")
# keep the effort condition at the same effort: phi T^psi unchanged at T = the free mean
T0 = rf.mean_effort_employed; ph = c.phi * T0^(c.psi - 40.0)
lf = solve_economy(SAGEConfig(c; psi = 40.0, phi = ph); cache = false); lj = solve_economy(SAGEConfig(cj; psi = 40.0, phi = ph); cache = false)
row("free", lf); row("job", lj)
d = maximum(abs.([lf.mean_effort_employed - lj.mean_effort_employed, lf.mpc - lj.mpc, lf.hand_to_mouth_kvw - lj.hand_to_mouth_kvw]))
@printf("   largest difference in effort, MPC and hand-to-mouth: %.1e\n", d)
check("the two modes agree when effort is nearly inelastic", d < 5e-3)

nf = count(x -> !x[2], results)
@printf("\n%d of %d checks hold%s\n", length(results) - nf, length(results), nf == 0 ? "" : ": FAILED " * join([x[1] for x in results if !x[2]], "; "))
println("DONE")

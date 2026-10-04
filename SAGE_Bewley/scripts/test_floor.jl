# The means-tested floor (SAGEParams.cfloor; Hubbard, Skinner and Zeldes 1995),
# one country, one asset, effort set by the job.
#  1. a floor no one reaches is no floor: every result identical;
#  2. at a real floor: no household's resources end below it, the outlay equals
#     the tax raised for it (the budget balances), and the share on the floor;
#  3. the direction of its effects, which is the standard one: liquid buffers
#     fall as the floor rises (insurance crowds out precautionary saving,
#     Hubbard, Skinner and Zeldes 1995), so asset poverty and the hand-to-mouth
#     share rise. The consumption drop on job loss is reported, not asserted:
#     in Italy it does NOT fall (0.435 to 0.449 as the floor goes to 40% of
#     reference earnings), because households give up the buffers that
#     cushioned it. The floor is not a remedy for large drops;
#  4. with S on the budget is still balanced to a small gap.
# The floor is given as a share of the reference effort's earnings (e_ref), the
# model's unit for a full year's pay at mean productivity.
#
#   julia --project=scripts/run_env scripts/test_floor.jl [CODE] [CONFIG] [v3]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "IT"
cfg = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "G"
V3 = length(ARGS) >= 3 && lowercase(ARGS[3]) == "v3"          # third argument v3: the version 3 economy and its calibration
c = V3 ? country_config(code; config = cfg, v3 = true, S = false, A = occursin('A', cfg)) :
         SAGEConfig(country_config(code; config = cfg, S = false, A = occursin('A', cfg)); effort_mode = :job)
results = Tuple{String,Bool}[]
check(name, ok) = (push!(results, (name, ok)); @printf("   -> %s: %s\n", name, ok ? "PASS" : "FAIL"); flush(stdout))
F = (:rate, :mean_effort_employed, :hand_to_mouth_kvw, :mpc, :mps, :consumption, :consumption_drop, :income_poor, :asset_poor, :mean_income)
line(tag, r) = (@printf("   %-12s tax for the floor %.5f | outlay %.5f | gap %+.1e | effort %.4f | htm %.3f | MPC %.3f | drop on job loss %.3f | income poor %.3f | asset poor %.3f | liquid p50 %.3f\n",
                        tag, floor_tax_of(r.config), r.floor_outlay, r.budget_gap, r.mean_effort_employed, r.hand_to_mouth_kvw, r.mpc, r.consumption_drop,
                        r.income_poor, r.asset_poor, r.wealth_p50); flush(stdout))
r0 = solve_economy(c; cache = false)
thr = [(r0.ypov, r0.abar)]
println("1. a floor no one reaches")
r1 = solve_economy(SAGEConfig(c; cfloor = 1e-9); thresholds = thr, cache = false)
# with a floor the job's effort levels are the no-floor economy's, by education cell; the comparison is at those levels
r0 = solve_economy(SAGEConfig(c; effort_by_cell = job_effort_levels(c)); thresholds = thr, cache = false)
d = maximum(abs(getfield(r0, f) - getfield(r1, f)) for f in F)
@printf("   largest difference %.1e\n", d)
check("a floor no one reaches changes nothing", d < 1e-10)

println("2 and 3. the floor as a share of a year's reference earnings (e_ref = $(c.e_ref))")
r0 = solve_economy(c; thresholds = thr, cache = false)
line("no floor", r0)
rs = Any[]
for sh in (0.20, 0.30, 0.40)
    r = solve_economy(SAGEConfig(c; cfloor = sh * c.e_ref); thresholds = thr, cache = false)
    line(@sprintf("floor %.2f", sh), r); push!(rs, r)
end
check("the budget balances at every floor", all(abs(r.budget_gap) < 1e-6 for r in rs))
@printf("   consumption drop on job loss, no floor to the highest: %.3f to %.3f (reported, not asserted)\n", r0.consumption_drop, rs[end].consumption_drop)
check("the hand-to-mouth share rises with the floor", r0.hand_to_mouth_kvw <= rs[1].hand_to_mouth_kvw + 1e-9 && all(rs[k].hand_to_mouth_kvw <= rs[k+1].hand_to_mouth_kvw + 1e-9 for k in 1:2))
check("liquid buffers fall as the floor rises (asset poverty rises)", all(rs[k].asset_poor <= rs[k+1].asset_poor + 1e-9 for k in 1:2) && r0.asset_poor <= rs[1].asset_poor + 1e-9)
# no household below the floor: resources after the transfer, household problems one by one
let cc = SAGEConfig(c; cfloor = 0.30 * c.e_ref), worst = Inf, onfloor = 0.0
    cs = cells_of(cc); _, bw = betas_of(cc); cT = SAGEConfig(cc; lumptax = cc.lumptax + ui_tax_of(cc))
    for g in 1:2, (k, p0) in enumerate(params_of(cT, cs[g]))
        p = update(p0; social_strength = 0.0)
        s = solve_participation_logit(p, 1.0; theta = cc.theta, full = true)
        for st in eachindex(s.z_vals), i in eachindex(s.a), dd in (0, 1)
            pd = dd == 1 ? s.P1[i, st] : 1 - s.P1[i, st]; l = s.lambda[i, st] * pd; l <= 0 && continue
            res = p.pc * s.c_d[dd+1][i, st] + s.a_d[dd+1][i, st]          # what the household disposes of
            worst = min(worst, res)
            s.floor_d[dd+1][i, st] && (onfloor += cs[g].share * bw[k] * l)
        end
    end
    @printf("   floor %.4f: lowest resources of any household %.4f; share of households on the floor %.4f\n", cc.cfloor, worst, onfloor)
    check("no household's resources end below the floor", worst >= cc.cfloor - 1e-9)
end

println("4. with S on")
cS = SAGEConfig(country_config(code; config = "GSA", S = true, A = true); effort_mode = :job, cfloor = 0.30 * c.e_ref)
t = @elapsed rS = solve_economy(cS; cache = false)
@printf("   G+S+A with the floor: participation %.4f, outlay %.5f, budget gap %+.1e (%.3f%% of mean income)  [%.1f min]\n",
        rS.rate, rS.floor_outlay, rS.budget_gap, 100 * abs(rS.budget_gap) / rS.mean_income, t / 60)
check("the budget gap with S on is below 0.05% of mean income", abs(rS.budget_gap) / rS.mean_income < 5e-4)
nf = count(x -> !x[2], results)
@printf("\n%d of %d checks hold%s\n", length(results) - nf, length(results), nf == 0 ? "" : ": FAILED " * join([x[1] for x in results if !x[2]], "; "))
println("DONE")

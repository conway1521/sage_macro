# The long-term out-of-work state (unemployment_core.jl, SAGEConfig.f_long), first run: one country
# in G of the floor regime with the state on, household problem by household problem, to see where
# anything is not finite, then the economy. And the reduction: with the state's inflow shut
# (job finding at one, so no one reaches it) the economy must be the two-block one.
#
#   julia --project=scripts/run_env scripts/probe_longterm.jl [CODE] [yearly exit from the state]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "IT"
fL = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 0.20
c0 = country_config(code; v3 = :floor, config = "G", S = false, A = false)
c = SAGEConfig(c0; f_long = (fL, fL))
@printf("%s G, floor regime: floor %.4f, patience %.4f, job finding %.3f, separation %.4f %.4f | long-term state with yearly exit %.2f\n",
        code, c.cfloor, c.beta_bar, c.f_find, c.delta..., fL)
ce = floor_effort(c)
println("effort levels, lengths: ", length.(ce.effort_by_cell), " | any not finite: ", any(!isfinite, ce.effort_by_cell[1]) || any(!isfinite, ce.effort_by_cell[2]))
T = c.lumptax + ui_only_tax_of(c)
@printf("insurance tax %.5f\n", ui_only_tax_of(c))
cs = cells_of(ce); _, bw = betas_of(ce)
for Tt in (T, T + 0.005)
    cT = SAGEConfig(ce; lumptax = Tt, floor_tax_given = 0.0)
    for g in 1:2, (k, p0) in enumerate(params_of(cT, cs[g]))
        p = update(p0; social_strength = 0.0)
        z, Π = SAGEBewley.income_process(p); nh = count(>(0), z)
        @printf("tax %.5f, cell %d: %d states, %d latent | transfer by block: %.4f %.4f %.4f | rows of the transition sum to %.6f..%.6f\n",
                Tt, g, length(z), nh, p.transfer[1], p.transfer[nh+1], p.transfer[end], extrema(sum(Π, dims = 2))...)
        s = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
        blk(v) = [sum(v[:, (b-1)*nh+1:b*nh]) for b in 1:length(z)÷nh]
        fin(x) = all(isfinite, x)
        println("   finite: lambda ", fin(s.lambda), ", c ", fin(s.c_d[1]) && fin(s.c_d[2]), ", saving ", fin(s.a_d[1]) && fin(s.a_d[2]), ", effort ", fin(s.e_d[1]) && fin(s.e_d[2]), ", P1 ", fin(s.P1))
        println("   mass by block (U, E, L): ", round.(blk(s.lambda); digits = 4), " | on the floor by block: ",
                round.(blk(s.lambda .* ((1 .- s.P1) .* s.floor_d[1] .+ s.P1 .* s.floor_d[2])); digits = 4))
        cl = cell_summary(p, s)
        println("   floor outlay ", cl.fout, " | fields not finite: ", [f for f in propertynames(cl) if getfield(cl, f) isa Union{Number,AbstractArray{<:Number}} && !all(isfinite, getfield(cl, f))])
        flush(stdout)
    end
end
println("\nthe economy")
r = solve_economy(c; cache = false)
r0 = solve_economy(c0; cache = false)
for (nm, x) in (("without the state", r0), ("with it", r))
    @printf("%-18s hand-to-mouth %.4f | liquid/income %.4f | MPC %.3f | effort %.4f | unemployment %.4f | income poor %.4f | asset poor %.4f | floor outlay %.5f, gap %+.1e\n",
            nm, x.hand_to_mouth_kvw, x.wealth_p50 / x.median_income, x.mpc, x.mean_effort_employed, x.unemployment, x.income_poor, x.asset_poor, x.floor_outlay, x.budget_gap)
end
println("DONE")

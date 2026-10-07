# The two-asset reference for wealth (V3_START.md, section 29, E), G, one country.
#
#   julia --project=scripts/run_env scripts/calibrate_two_asset_ref.jl CODE [effective patience] [chi0]
#
# The economy: the base's one-asset G of the same country (calibration_v3fet_<CODE>_G.txt: its effort
# scale, income process with the transitory part, replacement rate and proportional tax) with the
# illiquid asset on, and three differences from the two-asset version of section 20:
#   the illiquid return is paid into liquid wealth every period (k_payout);
#   liquid wealth earns nothing in real terms (r_liquid = 1), the illiquid return unchanged;
#   one patience for everyone: no floor, no patience by education, no impatient group.
# Effort is the level the job sets in the one-asset economy, state by state.
#
# Two parameters, two moments from the HFCS 2021:
#   patience          median net wealth over median after-tax income
#   fixed cost chi0   the wealthy hand-to-mouth share
# by Broyden's method: a solve takes half an hour, so the map is differenced once and then updated
# from the steps themselves. NOT targeted, and printed as the test: the poor hand-to-mouth share,
# median liquid wealth, the MPC, the net wealth Gini and top 10% share, and the split by education.
#
# Writes calibration_v3fet_<CODE>_G_I.txt when both moments are inside their bands.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
say(args...) = (println(args...); flush(stdout))
const CODE = uppercase(ARGS[1])
function hf(moment, grp = "all", sub = "all")
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        f = split(ln, ",")
        length(f) >= 6 && f[1] == moment && f[2] == CODE && f[3] == "2021" && f[4] == grp && f[5] == sub && return parse(Float64, f[6])
    end
    NaN
end
const NW = hf("networth_to_disposable_income_ratio_of_medians"); const WHTM = hf("htm_model_narrow_wealthy")
const TOL = [0.05, 0.03]                       # net wealth (relative), wealthy hand-to-mouth
const PREMIUM = manual_input(CODE, "illiquid_premium")
const OUTFILE = joinpath(@__DIR__, "calibration_v3fet_$(CODE)_G_I.txt")
const BUDGET = parse(Float64, get(ENV, "SAGE_TIME_BUDGET_MIN", "300"))
t0 = time()
one = SAGEConfig(country_config(CODE; config = "G", v3 = :floor_edu_trans, S = false, A = false); cfloor = 0.0, beta_cell = (0.0, 0.0))
levels = floor_effort(one).effort_by_cell
base = SAGEConfig(one; illiquid = true, illiquid_premium = PREMIUM, effort_by_cell = levels, beta_spread = 0.0, k_sub = 4, nk = 32, k_mid = 8.0,
                  k_payout = true, r_liquid = 1.0)
const SURV = 1 - base.death
say("two-asset reference, ", CODE, " G | targets: net wealth / income ", NW, ", wealthy hand-to-mouth ", WHTM, " | premium ", PREMIUM,
    " | transitory sd ", base.sd_eps, ", tax ", base.tax_mode, " | workers ", nworkers())
cfg_at(x) = SAGEConfig(base; beta_bar = x[1] / SURV, chi0 = exp(x[2]))
const LO = [0.93, log(5e-3)]; const HI = [0.992, log(0.6)]; const H = [0.004, 0.4]
nsolve = Ref(0)
function moments(x)
    nsolve[] += 1
    r = _solve(cfg_at(x), nothing; disk = false)
    (r = r, m = [cdf_quantile(NWGRID, r.Ntot, 0.5) / r.median_income, r.wealthy_htm])
end
resid(o) = [log(o.m[1] / NW) / TOL[1], (o.m[2] - WHTM) / TOL[2]]
function show(tag, x, o, F)
    r = o.r
    @printf("%s patience %.4f fixed cost %.4f | net wealth/income %.2f, wealthy htm %.4f | misses in bands %+.2f %+.2f | poor htm %.4f, liquid/income %.3f, MPC %.3f (wealthy htm %.3f)  [%d solves, %.0f min]\n",
            tag, x[1], exp(x[2]), o.m..., F..., r.hand_to_mouth_kvw, cdf_quantile(r.agrid, r.Wtot, 0.5) / r.median_income, r.mpc, r.mpc_wealthy, nsolve[], (time() - t0) / 60)
    flush(stdout)
end
x = [length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 0.965, log(length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 0.05)]
o = moments(x); F = resid(o); show("start ", x, o, F)
best = (x = copy(x), o = o, F = copy(F))
if maximum(abs.(F)) > 1.0
    # the map, differenced once (in steps of H)
    J = zeros(2, 2)
    for k in 1:2
        xk = copy(x); xk[k] += (xk[k] + H[k] > HI[k]) ? -H[k] : H[k]
        ok = moments(xk); Fk = resid(ok); show("  diff", xk, ok, Fk)
        J[:, k] = (Fk .- F) ./ ((xk[k] - x[k]) / H[k])
        sum(abs2, Fk) < sum(abs2, best.F) && (global best = (x = copy(xk), o = ok, F = copy(Fk)))
    end
    say("  the map at the start (per step of 0.004 in patience and 0.4 in the log of the cost): ", round.(J; digits = 2))
    x = copy(best.x); F = copy(best.F); o = best.o
    for it in 1:8
        maximum(abs.(F)) <= 1.0 && break
        if (time() - t0) / 60 + 1.3 * (time() - t0) / 60 / nsolve[] > BUDGET
            say(@sprintf("TIME BUDGET: stopping after %d solves; restart from patience %.4f, fixed cost %.4f", nsolve[], best.x[1], exp(best.x[2]))); break
        end
        d = -(J \ F); d = clamp.(d, -3.0, 3.0)                       # in steps of H
        xn = clamp.(x .+ d .* H, LO, HI); dx = (xn .- x) ./ H
        on = moments(xn); Fn = resid(on); show("step $it", xn, on, Fn)
        nd = dot(dx, dx)
        nd > 1e-12 && (global J = J .+ ((Fn .- F) .- J * dx) * dx' ./ nd)          # Broyden's update
        sum(abs2, Fn) < sum(abs2, best.F) && (global best = (x = copy(xn), o = on, F = copy(Fn)))
        if sum(abs2, Fn) < sum(abs2, F)
            global x = xn; global F = Fn; global o = on
        else
            global x = copy(best.x); global F = copy(best.F); global o = best.o       # step back to the best point, the map updated
        end
    end
end
x = best.x; o = best.o; F = best.F; r = o.r
show("\nbest  ", x, o, F)
let cm = r.Ntot ./ r.Ntot[end], g = NWGRID
    dm = diff(vcat(0.0, cm)); tot = sum(dm .* g); cw = cumsum(dm .* g) ./ tot
    gini = 1 - sum(dm .* (cw .+ vcat(0.0, cw[1:end-1]))); k = findfirst(>=(0.9), cm); top = 1 - cw[max(k - 1, 1)]
    @printf("THE TEST, untargeted: poor hand-to-mouth %.4f (HFCS %.4f) | liquid wealth over income %.3f (HFCS %.3f) | MPC %.3f (survey %.3f), of the poor hand-to-mouth %.3f, of the wealthy %.3f\n",
            r.hand_to_mouth_kvw, hf("htm_model_narrow_poor"), cdf_quantile(r.agrid, r.Wtot, 0.5) / r.median_income, hf("liquid_kvw_to_disposable_income_ratio_of_medians"),
            r.mpc, hf("mpc_mean"), r.mpc_htm, r.mpc_wealthy)
    @printf("   net wealth Gini %.3f (HFCS %.3f) | top 10%% share %.3f (HFCS %.3f) | fall in consumption on job loss %.3f | effort %.4f\n",
            gini, hf("networth_gini"), top, hf("networth_top10_share"), r.consumption_drop, r.mean_effort_employed)
end
for (gi, grp) in enumerate(("below tertiary", "tertiary"))
    P = r.pooled[gi]; ms = sum(P.mass)
    lq = (cmw = vec(sum(P.W, dims = 1)); cdf_quantile(r.agrid, cmw ./ cmw[end], 0.5) / r.median_income)
    nw = (cmn = vec(sum(P.N, dims = 1)); cdf_quantile(NWGRID, cmn ./ cmn[end], 0.5) / r.median_income)
    @printf("   %-15s hand-to-mouth %.3f (HFCS %.3f) | liquid over national median income %.3f (HFCS, own income %.3f) | net wealth %.2f (HFCS, own income %.2f)\n",
            grp, (sum(P.hmass) + sum(P.whmass)) / ms, hf("htm_model_narrow_total", "education", grp), lq,
            hf("liquid_kvw_to_disposable_income_ratio_of_medians", "education", grp), nw, hf("networth_to_disposable_income_ratio_of_medians", "education", grp))
end
body = sprint() do io
    println(io, "# written by calibrate_two_asset_ref.jl $(CODE): the two-asset reference for wealth (V3_START.md section 29); effort levels are the one-asset economy's")
    @printf(io, "phi = %.3f\nbeta_spread = 0.0\nbeta_bar = %.4f\nchi0 = %.5f\nilliquid_premium = %.4f\neta_z = %.4f\ncfloor = 0.0\nbeta_gap = 0.0\nk_payout = 1\nr_liquid = 1.0\n",
            base.phi, x[1] / SURV, exp(x[2]), PREMIUM, base.eta_z)
    println(io, "effort_cell1 = ", join([@sprintf("%.6f", v) for v in levels[1]], " "))
    println(io, "effort_cell2 = ", join([@sprintf("%.6f", v) for v in levels[2]], " "))
end
println("--- the calibration file ---"); print(body); println("--- end ---")
if maximum(abs.(F)) <= 1.0
    write(OUTFILE, body); say("wrote ", basename(OUTFILE))
else
    say(@sprintf("NOT CALIBRATED: the best point leaves a moment at %.2f of its band; the file above is the best point and is not written", maximum(abs.(F))))
end
@printf("DONE %s (two-asset reference) in %.0f min, %d solves\n", CODE, (time() - t0) / 60, nsolve[])

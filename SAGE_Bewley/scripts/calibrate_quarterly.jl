# Stage 1d: calibrate G (or G+A) on the quarterly economy (V2_BUILD_PLAN.md; V3_START.md section 130). The quarterly
# economy of stage 1c (`duration_config`: durations from Eurostat, TaxBEN's benefit profile, no spell without
# entitlement) from the country's annual calibration, with two parameters refitted: annual patience (of the tertiary
# cell) and its gap below it for the cell below tertiary, to the hand-to-mouth share and its gap by education (HFCS
# 2021, households not retired, as version 1). Everything else as the annual calibration (the job's hours recomputed
# on the quarterly economy). Tests, not targets (the user's rule of version 5): median liquid wealth, the MPC over
# twelve months, the fall as Kolsrud et al. measure it. Broyden steps from finite differences; every solve printed;
# the file's lines are printed at the end, to be committed by hand (CI never commits).
#
#   SAGE_DREAD_CHOICE=1 julia --project=scripts/run_env scripts/calibrate_quarterly.jl CODE CONFIG BETA0 GAP0 [MAXSOLVES]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); cfg = uppercase(ARGS[2]); x = [parse(Float64, ARGS[3]), parse(Float64, ARGS[4])]
maxs = length(ARGS) >= 5 ? parse(Int, ARGS[5]) : 9
say(x...) = (println(x...); flush(stdout))
function hfcs(moment, group, sub)
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        f = split(ln, ",")
        length(f) >= 6 && f[1] == moment && f[2] == code && f[3] == "2021" && f[4] == group && f[5] == sub && return parse(Float64, f[6])
    end
    error("no HFCS $moment for $code, $group, $sub")
end
T_HTM = hfcs("htm_model_narrow_total", "not_retired", "not retired")
T_GAP = hfcs("htm_model_narrow_total", "education_nr", "below tertiary") - hfcs("htm_model_narrow_total", "education_nr", "tertiary")
T_LIQ = hfcs("liquid_kvw_to_disposable_income_ratio_of_medians", "not_retired", "not retired")
T_MPC = hfcs("mpc_mean", "not_retired", "not retired")
TOL_HTM, TOL_GAP = 0.01, 0.03
A = occursin('A', cfg)
ca = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
cb = duration_config(ca)
wt = A ? country_config(code; config = "GA", v3 = :v5m, S = false, A = true).dread : 0.0
say(@sprintf("%s %s quarterly: targets hand-to-mouth %.4f, gap by education %.4f | tests: median liquid/yr %.4f, MPC %.4f | annual start: patience %.4f, gap %.4f",
             code, cfg, T_HTM, T_GAP, T_LIQ, T_MPC, ca.beta_bar, -ca.beta_cell[1]))
function econ(β, gap)
    c = SAGEConfig(cb; beta_bar = β^(1 / 4), beta_cell = ((β - gap)^(1 / 4) - β^(1 / 4), 0.0))
    A && (c = SAGEConfig(c; A = true, dread = wt, dread_mode = :behaviour, search = false, out_ls = 0.0))
    c
end
nsolve = Ref(0)
function F(x)
    nsolve[] += 1
    t = @elapsed r = solve_economy(econ(x...); cache = false)
    h = r.hand_to_mouth_kvw; g = r.hand_to_mouth_cell[1] - r.hand_to_mouth_cell[2]
    say(@sprintf("solve %d: patience %.4f, gap %.4f | htm %.4f (%.4f), gap %.4f (%.4f) | median/yr %.4f | MPC 12m %.4f | fall Kolsrud %.4f | effort %.4f | budget %.1e | %.1f min",
                 nsolve[], x[1], x[2], h, T_HTM, g, T_GAP, r.wealth_p50 / (4 * r.median_income), r.mpc12, r.fall_kolsrud, r.mean_effort_employed, r.budget_gap, t / 60))
    ([h - T_HTM, g - T_GAP], r)
end
ok(f) = abs(f[1]) < TOL_HTM && abs(f[2]) < TOL_GAP
clampx(x) = [clamp(x[1], 0.70, 0.995), clamp(x[2], 0.0, min(0.15, x[1] - 0.6))]
f, r = F(x); best = (x = copy(x), f = f, r = r)
if !ok(f)
    # the Jacobian by finite differences, then Broyden
    J = zeros(2, 2)
    for k in 1:2
        h = k == 1 ? -0.02 : 0.02; xk = copy(x); xk[k] += h
        fk, rk = F(xk); J[:, k] = (fk - f) / h
        sum(abs2, fk) < sum(abs2, best.f) && (best = (x = xk, f = fk, r = rk))
        ok(fk) && (x = xk; f = fk; break)
    end
    while !ok(f) && nsolve[] < maxs
        dx = -(J \ f)
        n = sqrt(sum(abs2, dx)); n > 0.05 && (dx .*= 0.05 / n)          # steps of at most 0.05 in patience or gap
        xn = clampx(x .+ dx); fn, rn = F(xn)
        J .+= ((fn - f) - J * (xn - x)) * (xn - x)' / max(sum(abs2, xn - x), 1e-12)
        x, f = xn, fn
        sum(abs2, fn) < sum(abs2, best.f) && (best = (x = copy(xn), f = fn, r = rn))
    end
end
cal = ok(best.f)
say(@sprintf("%s %s: %s | patience %.4f, gap %.4f | htm %.4f (%.4f), gap %.4f (%.4f)", code, cfg, cal ? "CALIBRATED" : "NOT CALIBRATED (best point)",
             best.x[1], best.x[2], best.f[1] + T_HTM, T_HTM, best.f[2] + T_GAP, T_GAP))
say("# calibration_v5q_$(code)_$(cfg).txt, written by calibrate_quarterly.jl ($(cal ? "calibrated" : "best point, not calibrated"))")
say(@sprintf("beta_annual = %.6f", best.x[1])); say(@sprintf("beta_gap_annual = %.6f", best.x[2]))
println("DONE")

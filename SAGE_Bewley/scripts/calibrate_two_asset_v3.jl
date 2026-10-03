# Version 3 calibration of the two-asset model (G or GA) for one country
# (V3_START.md, sections 13 and 14; TWO_ASSET_DESIGN.md for the model).
#
#   julia --project=scripts/run_env scripts/calibrate_two_asset_v3.jl FR G
#
# The economy: the version 3 one-asset economy of the same configuration (its
# effort scale, income process and replacement rate, read from
# calibration_v3_<CODE>_<CFG>.txt) with the illiquid asset on. Effort is the
# level the job sets in that one-asset economy, state by state: hours do not
# depend on how wealth is held, so nothing about effort is fitted here.
#
# Three parameters, four moments from the HFCS 2021 (data/hfcs_targets.csv), by
# damped least squares:
#   patience          median net wealth over median after-tax income
#   fixed cost chi0   median LIQUID wealth over median after-tax income (narrow
#                     definition) and the wealthy hand-to-mouth share
#   impatient share   the poor hand-to-mouth share
# Hand-to-mouth on the model's rule (liquid wealth at most one week of income;
# poor without illiquid wealth, wealthy with). The wealthy hand-to-mouth share
# alone did not identify the fixed cost (audit, 2026-10-02); the liquid median
# is the moment the standard two-asset calibrations add (Kaplan, Moll and
# Violante 2018 fit liquid and illiquid wealth jointly with the two shares).
# NOT targeted, and printed as the test: the MPC against the survey's
# self-reported MPC, and the net wealth Gini and top 10% share.
#
# Writes calibration_v3_<CODE>_<CFG>_I.txt (exit 0), or a not-calibrated marker
# (exit 2). SAGE_TIME_BUDGET_MIN: stops with a checkpoint and exit 3.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
say(args...) = (println(args...); flush(stdout))

const CODE = ARGS[1]
const CFG = uppercase(ARGS[2])
CFG in ("G", "GA") || error("version 3 two-asset calibration covers G and GA, got $CFG")
const A_ON = CFG == "GA"
function hfcs_target(moment; wave = "2021")
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        f = split(ln, ",")
        length(f) >= 6 && f[1] == moment && f[2] == CODE && f[3] == wave && f[4] == "all" && return parse(Float64, f[6])
    end
    error("no HFCS target $moment for $CODE in $wave")
end
const NW = hfcs_target("networth_to_disposable_income_ratio_of_medians")
const LIQ = hfcs_target("liquid_kvw_to_disposable_income_ratio_of_medians")
const PHTM = hfcs_target("htm_model_narrow_poor")
const WHTM = hfcs_target("htm_model_narrow_wealthy")
const MPC_DATA = hfcs_target("mpc_mean")
const GINI_DATA = hfcs_target("networth_gini"); const TOP_DATA = hfcs_target("networth_top10_share")
const TOL = [0.05, 0.03, 0.01, 0.02]            # net wealth (relative), liquid over income, poor htm, wealthy htm
manual = Dict{Tuple{String,String},Float64}()
for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "manual_inputs.csv"))
    startswith(ln, "#") && continue
    f = split(ln, ","); length(f) >= 3 || continue
    v = tryparse(Float64, f[3]); v === nothing || (manual[(f[1], f[2])] = v)
end
const PREMIUM = manual[(CODE, "illiquid_premium")]
const OUTFILE = joinpath(@__DIR__, "calibration_v3_$(CODE)_$(CFG)_I.txt")
const NOTCAL = replace(OUTFILE, r"\.txt$" => ".not_calibrated.txt")
const CKPT = joinpath(@__DIR__, "checkpoint_v3_two_asset_$(CODE)_$(CFG).txt")
const BUDGET = parse(Float64, get(ENV, "SAGE_TIME_BUDGET_MIN", "Inf"))

one = country_config(CODE; config = CFG, v3 = true, S = false, A = A_ON)          # the one-asset version 3 calibration
t0 = time()
levels = job_effort_levels(one)
say("calibrating ", CODE, " ", CFG, " on two assets, version 3 | targets: net wealth / income ", NW, ", liquid / income ", LIQ,
    ", poor htm ", PHTM, ", wealthy htm ", WHTM, " | premium ", PREMIUM, " | workers ", nworkers())
@printf("effort set by the job, from the one-asset economy: cell means %.4f and %.4f  [%.1f min]\n",
        sum(levels[1]) / max(count(>(0), levels[1]), 1), sum(levels[2]) / max(count(>(0), levels[2]), 1), (time() - t0) / 60)
base = SAGEConfig(one; illiquid = true, illiquid_premium = PREMIUM, effort_by_cell = levels, beta_spread = 0.0)
const SURV = 1 - base.death
const BETA_LOW_EFF = 0.85
unpack(x) = (beta_bar = x[1] / SURV, chi0 = exp(x[2]), impatient_share = clamp(x[3], 0.0, 0.5))
cfg_at(x) = (u = unpack(x); SAGEConfig(base; beta_bar = u.beta_bar, chi0 = u.chi0, impatient_share = u.impatient_share, beta_low = BETA_LOW_EFF / SURV))
const LO = [0.90, log(2e-3), 0.0]; const HI = [0.995, log(1.0), 0.5]; const H = [0.004, 0.3, 0.02]
qmed(x, cm) = cdf_quantile(x, cm, 0.5)
nsolve = Ref(0)
function moments(x)
    nsolve[] += 1
    r = _solve(cfg_at(x), nothing; disk = false)
    (r = r, m = [qmed(NWGRID, r.Ntot) / r.median_income, qmed(r.agrid, r.Wtot) / r.median_income, r.hand_to_mouth_kvw, r.wealthy_htm])
end
resid(o) = [log(o.m[1] / NW) / TOL[1], (o.m[2] - LIQ) / TOL[2], (o.m[3] - PHTM) / TOL[3], (o.m[4] - WHTM) / TOL[4]]
show(tag, x, o, F) = (u = unpack(x);
    @printf("%s beta_bar %.4f chi0 %.4f impatient share %.4f | net wealth/income %.2f, liquid/income %.3f, poor htm %.4f, wealthy htm %.4f | misses in bands %+.2f %+.2f %+.2f %+.2f | MPC %.3f  [%d solves, %.1f min]\n",
            tag, u.beta_bar, u.chi0, u.impatient_share, o.m..., F..., o.r.mpc, nsolve[], (time() - t0) / 60); flush(stdout))
write_ckpt(x, lam) = open(io -> println(io, join(string.(vcat(x, lam)), ",")), CKPT, "w")
x = [0.955, log(0.05), PHTM]; lam = 0.3          # effective patience 0.975 started at twice the net wealth target (France, 2026-10-03)
if isfile(CKPT)
    v = parse.(Float64, split(strip(read(CKPT, String)), ",")); x = v[1:3]; lam = v[4]
    say("  resuming from the checkpoint: ", round.(x; digits = 5))
end
o = moments(x); F = resid(o); show("start ", x, o, F); write_ckpt(x, lam)
for it in 1:10
    maximum(abs.(F)) <= 0.5 && break
    per = (time() - t0) / 60 / nsolve[]
    if (time() - t0) / 60 + per * 6 > BUDGET
        write_ckpt(x, lam)
        say(@sprintf("\nTIME BUDGET: %.0f of %.0f minutes used; checkpoint written, to resume in a new job.", (time() - t0) / 60, BUDGET)); exit(3)
    end
    J = zeros(4, 3)
    for k in 1:3
        xk = copy(x); h = (xk[k] + H[k] > HI[k]) ? -H[k] : H[k]; xk[k] += h
        J[:, k] = (resid(moments(xk)) .- F) ./ h
    end
    it == 1 && say("  the map at the start, singular values: ", join([@sprintf("%.2f", v) for v in svdvals(J)], ", "))
    moved = false
    for _ in 1:5
        A = J' * J; d = -((A + lam * Diagonal(diag(A))) \ (J' * F))
        xn = clamp.(x .+ d, LO, HI); on = moments(xn); Fn = resid(on)
        if sum(abs2, Fn) < sum(abs2, F) - 1e-6
            global x = xn; global o = on; global F = Fn; global lam = max(lam / 3, 1e-4); moved = true; break
        end
        global lam *= 4
    end
    show("step $it", x, o, F); write_ckpt(x, lam)
    moved || (say("  no improving step; stopping at the best fit"); break)
end
r = o.r
let cm = r.Ntot ./ r.Ntot[end], g = NWGRID
    dm = diff(vcat(0.0, cm)); tot = sum(dm .* g); cw = cumsum(dm .* g) ./ tot
    gini = 1 - sum(dm .* (cw .+ vcat(0.0, cw[1:end-1]))); k = findfirst(>=(0.9), cm); top = 1 - cw[max(k - 1, 1)]
    say(@sprintf("\nTHE TEST, untargeted: MPC %.3f against %.3f self-reported (HFCS 2021); of the poor hand-to-mouth %.3f, of the wealthy %.3f | net wealth Gini %.3f (HFCS %.3f), top 10%% share %.3f (HFCS %.3f)",
                 r.mpc, MPC_DATA, r.mpc_htm, r.mpc_wealthy, gini, GINI_DATA, top, TOP_DATA))
end
say(@sprintf("other untargeted: effort %.4f | drop on job loss %.3f | protection if hit %.4f | saving out of a windfall %.3f | income poverty %.4f", r.mean_effort_employed,
             r.consumption_drop, r.A_cond, r.mps, r.income_poor))
if maximum(abs.(F)) > 1.0
    isfile(OUTFILE) && rm(OUTFILE); isfile(CKPT) && rm(CKPT)
    open(io -> println(io, "# not calibrated; the reason is in the run log"), NOTCAL, "w")
    say(@sprintf("\nNOT CALIBRATED: the best fit leaves a moment at %.2f of its band. No calibration file written.", maximum(abs.(F)))); exit(2)
end
u = unpack(x)
open(OUTFILE, "w") do io
    println(io, "# written by calibrate_two_asset_v3.jl $(CODE) $(CFG); version 3, illiquid asset on; effort levels are the one-asset economy's")
    @printf(io, "phi = %.3f\nbeta_spread = 0.0\nbeta_bar = %.4f\nimpatient_share = %.4f\nbeta_low = %.4f\nchi0 = %.5f\nilliquid_premium = %.4f\neta_z = %.4f\n",
            base.phi, u.beta_bar, u.impatient_share, BETA_LOW_EFF / SURV, u.chi0, PREMIUM, base.eta_z)
    println(io, "effort_cell1 = ", join([@sprintf("%.6f", v) for v in levels[1]], " "))
    println(io, "effort_cell2 = ", join([@sprintf("%.6f", v) for v in levels[2]], " "))
end
isfile(NOTCAL) && rm(NOTCAL); isfile(CKPT) && rm(CKPT)
say("wrote ", basename(OUTFILE))
@printf("\nDONE %s %s (two assets, version 3) in %.1f min, %d solves\n", CODE, CFG, (time() - t0) / 60, nsolve[])

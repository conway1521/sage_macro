# Calibrate the two-asset model (TWO_ASSET_DESIGN.md) for one country and a
# configuration without the social dimension (G or GA; the S configurations
# follow the same pattern with the technology scans added later).
#
#   julia --project=scripts/run_env scripts/calibrate_two_asset.jl FR GA
#
# Four parameters, four targets, fitted jointly by a damped Newton iteration
# with a finite-difference Jacobian:
#   mean patience beta_bar   -> median net wealth / median gross income (HFCS 2021)
#   fixed cost chi0          -> wealthy hand-to-mouth (Kaplan, Violante and Weidner 2014)
#   discount spread          -> poor hand-to-mouth (same table)
#   effort scale phi         -> effort of the employed (HETUS)
# Not fitted, from the data table: the illiquid premium (JST data), death 1/45.
# Starts from the committed one-asset calibration of the same configuration.
# Writes calibration_country_<CODE>_<CFG>_I.txt, or a not-calibrated marker
# (exit 2) if the iteration does not bring every target inside its tolerance.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
say(args...) = (println(args...); flush(stdout))

const CODE = ARGS[1]
const CFG = uppercase(ARGS[2])
CFG in ("G", "GA") || error("two-asset calibration covers G and GA so far, got $CFG")
const A_ON = CFG == "GA"
const ROW = country_rows()[CODE]
const E_TARGET = parse(Float64, ROW["effort_target"])
const HTM_TARGET = parse(Float64, ROW["htm_target"])
manual = Dict{Tuple{String,String},Float64}()
for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "manual_inputs.csv"))
    startswith(ln, "#") && continue
    f = split(ln, ","); length(f) >= 3 || continue
    v = tryparse(Float64, f[3]); v === nothing || (manual[(f[1], f[2])] = v)
end
const WHTM_TARGET = manual[(CODE, "whtm_target")]
const NW_TARGET = manual[(CODE, "nw_income_target")]
const PREMIUM = manual[(CODE, "illiquid_premium")]
const TOL = (nw = 0.05, whtm = 0.01, htm = 0.005, e = 0.005)   # nw relative, the rest absolute
const OUTFILE = joinpath(@__DIR__, "calibration_country_$(CODE)_$(CFG)_I.txt")
const NOTCAL = replace(OUTFILE, r"\.txt$" => ".not_calibrated.txt")

base = country_config(CODE; config = CFG, S = false, A = A_ON)
base = SAGEConfig(base; illiquid = true, illiquid_premium = PREMIUM)
say("calibrating ", CODE, " ", CFG, " with the illiquid asset | targets: net wealth / income ", NW_TARGET,
    ", wealthy htm ", WHTM_TARGET, ", poor htm ", HTM_TARGET, ", effort ", round(E_TARGET; digits = 4),
    " | premium ", PREMIUM, ", death ", round(base.death; digits = 4), " | workers ", nworkers())

qmed(x, cm) = (k = findfirst(>=(0.5 * cm[end]), cm); x[k])
# parameters in the transformed space the iteration works in
unpack(x) = (beta_bar = x[1], chi0 = exp(x[2]), beta_spread = max(x[3], 0.0), phi = exp(x[4]))
cfg_at(x) = (u = unpack(x); SAGEConfig(base; beta_bar = u.beta_bar, chi0 = u.chi0, beta_spread = u.beta_spread, phi = u.phi))
const LO = [0.93, log(1e-3), 0.0, log(0.3)]
const HI = [0.998, log(2.0), 0.15, log(40.0)]
const STEP = [0.004, 0.25, 0.006, 0.05]    # finite-difference steps
const MAXMOVE = [0.012, 1.0, 0.03, 0.3]

nsolve = Ref(0)
function moments(x)
    nsolve[] += 1
    r = _solve(cfg_at(x), nothing; disk = false)
    nw = qmed(NWGRID, r.Ntot) / r.median_income
    (r = r, nw = nw, whtm = r.wealthy_htm, htm = r.hand_to_mouth_kvw, e = r.mean_effort_employed)
end
# residuals scaled by the tolerances, so 1 means "at the edge of the band"
resid(m) = [log(m.nw / NW_TARGET) / TOL.nw, (m.whtm - WHTM_TARGET) / TOL.whtm,
            (m.htm - HTM_TARGET) / TOL.htm, (m.e - E_TARGET) / TOL.e]
report(tag, x, m, t0) = (u = unpack(x);
    @printf("%s beta_bar %.4f chi0 %.4f spread %.4f phi %.3f | net wealth/income %.2f, wealthy htm %.4f, poor htm %.4f, effort %.4f | worst %.2f band  [%d solves, %.1f min]\n",
            tag, u.beta_bar, u.chi0, u.beta_spread, u.phi, m.nw, m.whtm, m.htm, m.e, maximum(abs.(resid(m))), nsolve[], (time() - t0) / 60);
    flush(stdout))

t0 = time()
x = [0.99, log(0.05), base.beta_spread, log(base.phi)]
m = moments(x); report("start", x, m, t0)
ok = false
for it in 1:8
    F = resid(m)
    global ok = maximum(abs.(F)) <= 1.0
    ok && break
    J = zeros(4, 4)
    for k in 1:4
        xk = copy(x); h = (xk[k] + STEP[k] > HI[k]) ? -STEP[k] : STEP[k]; xk[k] += h
        J[:, k] = (resid(moments(xk)) .- F) ./ h
    end
    Δ = -(J \ F)
    any(!isfinite, Δ) && (Δ = -pinv(J) * F)
    # damp: no coordinate moves more than its cap, then a backtracking line search
    s = minimum(min(1.0, MAXMOVE[k] / max(abs(Δ[k]), 1e-12)) for k in 1:4)
    accepted = false
    for _ in 1:4
        xn = clamp.(x .+ s .* Δ, LO, HI)
        mn = moments(xn)
        if maximum(abs.(resid(mn))) < maximum(abs.(F))
            global x = xn; global m = mn; accepted = true; break
        end
        s /= 2
    end
    report("step $it", x, m, t0)
    accepted || (say("  no improving step; stopping"); break)
end
ok = maximum(abs.(resid(m))) <= 1.0

r = m.r
say(@sprintf("\nvalidation (not targeted): MPC %.3f (poor htm %.3f, wealthy %.3f) | drop on job loss %.3f | protection if hit %.4f | room %.3f | median liquid / median income %.3f | net wealth top 10%% share and Gini below",
             r.mpc, r.mpc_htm, r.mpc_wealthy, r.consumption_drop, r.A_cond, r.room, qmed(r.agrid, r.Wtot) / r.median_income))
let cm = r.Ntot ./ r.Ntot[end], x = NWGRID
    dm = diff(vcat(0.0, cm)); tot = sum(dm .* x)
    cw = cumsum(dm .* x) ./ tot
    g = 1 - sum(dm .* (cw .+ vcat(0.0, cw[1:end-1])))
    k = findfirst(>=(0.9), cm); top = 1 - cw[max(k - 1, 1)]
    say(@sprintf("  net wealth: top 10%% share %.3f, Gini %.3f", top, g))
end
if !ok
    open(io -> println(io, "# not calibrated; the reason is in the run log"), NOTCAL, "w")
    say(@sprintf("\nNOT CALIBRATED: worst target at %.2f of its band after the iteration. No calibration file written.", maximum(abs.(resid(m)))))
    exit(2)
end
u = unpack(x)
open(OUTFILE, "w") do io
    println(io, "# written by calibrate_two_asset.jl $(CODE) $(CFG); illiquid asset on")
    @printf(io, "phi = %.3f\nbeta_spread = %.4f\nbeta_bar = %.4f\nchi0 = %.4f\nilliquid_premium = %.4f\n",
            u.phi, u.beta_spread, u.beta_bar, u.chi0, PREMIUM)
end
isfile(NOTCAL) && rm(NOTCAL)
say("wrote ", basename(OUTFILE))
@printf("\nDONE %s %s (illiquid) in %.1f min, %d solves\n", CODE, CFG, (time() - t0) / 60, nsolve[])

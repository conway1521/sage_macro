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
# Optional third argument, a country code: take the fixed cost chi0 from that
# country's calibration of the same configuration and drop the wealthy
# hand-to-mouth target. For Germany and Italy (2026-09-29): with their illiquid
# premium of about 2.2 points the annual model cannot make wealth illiquid while
# cash is short, whatever chi0 is, so chi0 is not identified there and is
# borrowed, as sigma is in G+S. The wealthy hand-to-mouth are then reported as
# an untargeted miss.
const CHI_FROM = length(ARGS) >= 3 ? uppercase(ARGS[3]) : ""
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

qmed(x, cm) = cdf_quantile(x, cm, 0.5)      # interpolated: the node above the median was up to 5% high, the width of the band (audit 2026-10-02)
# parameters in the transformed space the iteration works in. The first is
# EFFECTIVE patience, beta_bar times survival, bounded by 0.995 so the household
# problem stays a contraction. A cap on beta_bar itself at 0.998 held effective
# patience at 0.976 and left Germany and Italy far short of their net wealth
# (2026-09-29): with death, effective patience times the illiquid return near or
# above one is what two-asset models need, and death keeps the distribution
# stationary.
const SURV = 1 - base.death
# Two patience groups (2026-09-29): the third parameter is the share of an
# impatient minority at effective patience BETA_LOW_EFF; the patient majority is
# at the first parameter. A uniform spread wide enough for the German and
# Italian poor hand-to-mouth pulled the median household below what their net
# wealth needs (logs_two_asset, runs 1 and 2).
const BETA_LOW_EFF = 0.85
unpack(x) = (beta_bar = x[1] / SURV, chi0 = exp(x[2]), impatient_share = clamp(x[3], 0.0, 0.4), phi = exp(x[4]))
cfg_at(x) = (u = unpack(x); SAGEConfig(base; beta_bar = u.beta_bar, chi0 = u.chi0, beta_spread = 0.0,
                                       impatient_share = u.impatient_share, beta_low = BETA_LOW_EFF / SURV, phi = u.phi))
const LO = [0.90, log(1e-3), 0.0, log(0.3)]
const HI = [0.995, log(2.0), 0.4, log(40.0)]
const STEP = [0.004, 0.25, 0.01, 0.05]    # finite-difference steps
const MAXMOVE = [0.012, 1.0, 0.05, 0.3]

nsolve = Ref(0)
function moments(x)
    nsolve[] += 1
    r = _solve(cfg_at(x), nothing; disk = false)
    nw = qmed(NWGRID, r.Ntot) / r.median_income
    (r = r, nw = nw, whtm = r.wealthy_htm, htm = r.hand_to_mouth_kvw, e = r.mean_effort_employed)
end
# residuals scaled by the tolerances, so 1 means "at the edge of the band"
const ACT = isempty(CHI_FROM) ? [1, 2, 3, 4] : [1, 3, 4]      # parameters fitted and targets owned
ract(m) = resid(m)[ACT]
resid(m) = [log(m.nw / NW_TARGET) / TOL.nw, (m.whtm - WHTM_TARGET) / TOL.whtm,
            (m.htm - HTM_TARGET) / TOL.htm, (m.e - E_TARGET) / TOL.e]
report(tag, x, m, t0) = (u = unpack(x);
    @printf("%s beta_bar %.4f chi0 %.4f impatient share %.4f phi %.3f | net wealth/income %.2f, wealthy htm %.4f, poor htm %.4f, effort %.4f | worst targeted %.2f band  [%d solves, %.1f min]\n",
            tag, u.beta_bar, u.chi0, u.impatient_share, u.phi, m.nw, m.whtm, m.htm, m.e, maximum(abs.(ract(m))), nsolve[], (time() - t0) / 60);
    flush(stdout))

t0 = time()
# CHECKPOINTS (2026-09-29). GitHub stops a job at six hours. The iteration writes
# its point after every step to CKPT and starts from it when the file exists.
# With SAGE_TIME_BUDGET_MIN set, it stops before a step that would not finish
# inside the budget, with exit code 3; the workflow then starts a new job that
# resumes. SAGE_START ("beta_bar, chi0, impatient share, phi", as the log prints
# them) restarts from a point read off a log. Until 2026-10-01 the first entry
# was effective patience, which the log does not print: two France GA restarts
# were given beta_bar there and started 2% too patient.
const CKPT = joinpath(@__DIR__, "checkpoint_two_asset_$(CODE)_$(CFG).txt")
const BUDGET = parse(Float64, get(ENV, "SAGE_TIME_BUDGET_MIN", "Inf"))
write_ckpt(x) = open(io -> println(io, join(string.(x), ",")), CKPT, "w")
function read_start()
    isfile(CKPT) && return parse.(Float64, split(strip(read(CKPT, String)), ","))
    if haskey(ENV, "SAGE_START") && !isempty(ENV["SAGE_START"])
        v = parse.(Float64, split(ENV["SAGE_START"], ","))
        return [v[1] * SURV, log(v[2]), v[3], log(v[4])]
    end
    nothing
end
chi_start = isempty(CHI_FROM) ? 0.02 :
    country_config(CHI_FROM; config = CFG, S = false, A = A_ON, illiquid = true).chi0
isempty(CHI_FROM) || say("  chi0 taken from ", CHI_FROM, ": ", chi_start, "; the wealthy hand-to-mouth are not targeted")
x = [0.985, log(chi_start), HTM_TARGET, log(base.phi)]
let st = read_start()
    st === nothing || (global x = st; say("  resuming from ", isfile(CKPT) ? "the checkpoint" : "SAGE_START", ": ", round.(st; digits = 5)))
end
m = moments(x); report("start", x, m, t0); write_ckpt(x)
ok = false
for it in 1:10
    # stop before a step that would not finish inside the budget (a step is
    # about the Jacobian plus two line-search solves)
    per = (time() - t0) / 60 / nsolve[]
    if (time() - t0) / 60 + per * (length(ACT) + 2) > BUDGET
        write_ckpt(x)
        say(@sprintf("\nTIME BUDGET: %.0f of %.0f minutes used; checkpoint written, to resume in a new job.", (time() - t0) / 60, BUDGET))
        exit(3)
    end
    F = ract(m)
    global ok = maximum(abs.(F)) <= 1.0
    ok && break
    na_ = length(ACT)
    J = zeros(na_, na_)
    tried = Tuple{Vector{Float64},Any}[]      # every point evaluated this iteration
    for (col, k) in enumerate(ACT)
        xk = copy(x); h = (xk[k] + STEP[k] > HI[k]) ? -STEP[k] : STEP[k]; xk[k] += h
        mk = moments(xk); push!(tried, (xk, mk))
        J[:, col] = (ract(mk) .- F) ./ h
    end
    Δa = -(J \ F)
    any(!isfinite, Δa) && (Δa = -pinv(J) * F)
    Δ = zeros(4); Δ[ACT] .= Δa
    # damp: no coordinate moves more than its cap, then a backtracking line search
    s = minimum(min(1.0, MAXMOVE[k] / max(abs(Δ[k]), 1e-12)) for k in ACT)
    # a step is accepted when the sum of squared (scaled) misses falls
    accepted = false
    for _ in 1:4
        xn = clamp.(x .+ s .* Δ, LO, HI)
        mn = moments(xn); push!(tried, (xn, mn))
        if sum(abs2, ract(mn)) < sum(abs2, F)
            global x = xn; global m = mn; accepted = true; break
        end
        s /= 2
    end
    if !accepted
        # fall back on the best point evaluated this iteration, if it improves
        kb = argmin([sum(abs2, ract(t[2])) for t in tried])
        if sum(abs2, ract(tried[kb][2])) < sum(abs2, F)
            global x = tried[kb][1]; global m = tried[kb][2]; accepted = true
            say("  Newton step failed; moved to the best point evaluated")
        end
    end
    report("step $it", x, m, t0); write_ckpt(x)
    accepted || (say("  no improving point; stopping"); break)
end
ok = maximum(abs.(ract(m))) <= 1.0
isempty(CHI_FROM) || say(@sprintf("  untargeted: wealthy hand-to-mouth %.4f against %.4f in the data", m.whtm, WHTM_TARGET))

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
    # no earlier calibration file and no checkpoint survive a failed run
    isfile(OUTFILE) && rm(OUTFILE); isfile(CKPT) && rm(CKPT)
    open(io -> println(io, "# not calibrated; the reason is in the run log"), NOTCAL, "w")
    say(@sprintf("\nNOT CALIBRATED: worst target at %.2f of its band after the iteration. No calibration file written.", maximum(abs.(ract(m)))))
    exit(2)
end
u = unpack(x)
open(OUTFILE, "w") do io
    println(io, "# written by calibrate_two_asset.jl $(CODE) $(CFG); illiquid asset on", isempty(CHI_FROM) ? "" : "; chi0 from $(CHI_FROM), wealthy hand-to-mouth untargeted")
    @printf(io, "phi = %.3f\nbeta_spread = 0.0\nbeta_bar = %.4f\nimpatient_share = %.4f\nbeta_low = %.4f\nchi0 = %.5f\nilliquid_premium = %.4f\n",
            u.phi, u.beta_bar, u.impatient_share, BETA_LOW_EFF / SURV, u.chi0, PREMIUM)
end
isfile(NOTCAL) && rm(NOTCAL)
isfile(CKPT) && rm(CKPT)
say("wrote ", basename(OUTFILE))
@printf("\nDONE %s %s (illiquid) in %.1f min, %d solves\n", CODE, CFG, (time() - t0) / 60, nsolve[])

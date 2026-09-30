# Calibrate the two-asset model with E on (GE or GAE) for one country: the
# economy over places (place_layer.jl, TL2 by default), with the same four G
# targets as calibrate_two_asset.jl. Needs the two-asset calibration of the same
# configuration without E (G for GE, GA for GAE).
#
#   julia --project=scripts/run_env scripts/calibrate_two_asset_e.jl FR GE
#
# 1. Start from the E-off calibration (effective patience, chi0, impatient
#    share, phi) and solve the economy over places. E redistributes across
#    places but keeps the national targets, so in the one-asset calibrations it
#    moved the national parameters by about 1% (2026-09-30). If every owned
#    target is within half its band, the E-off point is kept.
# 2. Otherwise, the E-off Jacobian of the targets at that point (finite
#    differences on the national economy, a few minutes a solve), and up to
#    three quasi-Newton corrections on the E-on residuals: each costs one solve
#    of the economy over places (about 75 minutes for France's 14 regions).
# 3. Checked (every owned target within its band); written to
#    calibration_country_<CODE>_<CFG>_I.txt.
# chi0 borrowed in the E-off calibration (Germany, Italy) stays borrowed here.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
say(args...) = (println(args...); flush(stdout))

const CODE = ARGS[1]
const CFG = uppercase(ARGS[2])
CFG in ("GE", "GAE") || error("two-asset E calibration covers GE and GAE, got $CFG")
const A_ON = CFG == "GAE"
const OFF = A_ON ? "GA" : "G"
const ROW = country_rows()[CODE]
const E_TARGET = parse(Float64, ROW["effort_target"]); const HTM_TARGET = parse(Float64, ROW["htm_target"])
manual = Dict{Tuple{String,String},Float64}()
for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "manual_inputs.csv"))
    startswith(ln, "#") && continue
    f = split(ln, ","); length(f) >= 3 || continue
    v = tryparse(Float64, f[3]); v === nothing || (manual[(f[1], f[2])] = v)
end
const WHTM_TARGET = manual[(CODE, "whtm_target")]; const NW_TARGET = manual[(CODE, "nw_income_target")]
const TOL = (nw = 0.05, whtm = 0.01, htm = 0.005, e = 0.005)
const OUTFILE = joinpath(@__DIR__, "calibration_country_$(CODE)_$(CFG)_I.txt")
const NOTCAL = replace(OUTFILE, r"\.txt$" => ".not_calibrated.txt")
notcal(msg) = (open(io -> println(io, "# not calibrated; the reason is in the run log"), NOTCAL, "w");
               say("\nNOT CALIBRATED: ", msg, " No calibration file written."); exit(2))

const OFFFILE = joinpath(@__DIR__, "calibration_country_$(CODE)_$(OFF)_I.txt")
isfile(OFFFILE) || error("needs the two-asset $(OFF) calibration first")
off = country_config(CODE; config = OFF, S = false, A = A_ON, illiquid = true)
const CHI_BORROWED = occursin("chi0 from", readline(OFFFILE))
const ACT = CHI_BORROWED ? [1, 3, 4] : [1, 2, 3, 4]
say("calibrating ", CODE, " ", CFG, " with the illiquid asset over places (", off.typology, "), from the ", OFF,
    " calibration | targets: net wealth / income ", NW_TARGET, ", wealthy htm ", WHTM_TARGET, CHI_BORROWED ? " (untargeted, chi0 borrowed)" : "",
    ", poor htm ", HTM_TARGET, ", effort ", round(E_TARGET; digits = 4), " | workers ", nworkers())

qmed(x, cm) = (k = findfirst(>=(0.5 * cm[end]), cm); x[k])
# the parameterisation of calibrate_two_asset.jl: effective patience, log chi0,
# the impatient share (at effective patience 0.85), log phi
const SURV = 1 - off.death
const BETA_LOW_EFF = 0.85
unpack(x) = (beta_bar = x[1] / SURV, chi0 = exp(x[2]), impatient_share = clamp(x[3], 0.0, 0.4), phi = exp(x[4]))
with(c, x) = (u = unpack(x); SAGEConfig(c; beta_bar = u.beta_bar, chi0 = u.chi0, beta_spread = 0.0,
                                       impatient_share = u.impatient_share, beta_low = BETA_LOW_EFF / SURV, phi = u.phi))
const LO = [0.90, log(1e-3), 0.0, log(0.3)]; const HI = [0.995, log(2.0), 0.4, log(40.0)]
const STEP = [0.004, 0.25, 0.01, 0.05]; const MAXMOVE = [0.012, 1.0, 0.05, 0.3]
mom(r) = (nw = qmed(NWGRID, r.Ntot) / r.median_income, whtm = r.wealthy_htm, htm = r.hand_to_mouth_kvw, e = r.mean_effort_employed)
resid(m) = [log(m.nw / NW_TARGET) / TOL.nw, (m.whtm - WHTM_TARGET) / TOL.whtm, (m.htm - HTM_TARGET) / TOL.htm, (m.e - E_TARGET) / TOL.e]
t0 = time()
elapsed() = (time() - t0) / 60
solveE(x) = (r = solve_economy(SAGEConfig(with(off, x); E = true)); (r = r, m = mom(r)))
showr(tag, x, s) = (u = unpack(x);
    @printf("%s beta_bar %.4f chi0 %.4f impatient share %.4f phi %.3f | net wealth/income %.2f, wealthy htm %.4f, poor htm %.4f, effort %.4f | worst owned %.2f band  [%.1f min]\n",
            tag, u.beta_bar, u.chi0, u.impatient_share, u.phi, s.m.nw, s.m.whtm, s.m.htm, s.m.e, maximum(abs.(resid(s.m)[ACT])), elapsed()); flush(stdout))

# CHECKPOINTS, as in calibrate_two_asset_s.jl: the stage k (the point after k
# corrections, not yet evaluated), the point, and the E-off Jacobian (zeros
# until it is needed). With SAGE_TIME_BUDGET_MIN set, the run stops before a
# solve over places that would not finish inside the budget (exit 3).
const CKPT = joinpath(@__DIR__, "checkpoint_two_asset_$(CODE)_$(CFG).txt")
const BUDGET = parse(Float64, get(ENV, "SAGE_TIME_BUDGET_MIN", "Inf"))
save_ckpt(k, x, J) = open(CKPT, "w") do io
    println(io, k); println(io, join(string.(x), ",")); println(io, join(string.(vec(J)), ","))
end
function load_ckpt()
    isfile(CKPT) || return nothing
    l = readlines(CKPT)
    (parse(Int, l[1]), parse.(Float64, split(l[2], ",")), reshape(parse.(Float64, split(l[3], ",")), 4, 4))
end
const LAST = Ref(90.0)       # minutes the last solve over places took (a first guess until measured)
function budget_check(k, x, J; need = 1.2 * LAST[])
    if elapsed() + need > BUDGET
        save_ckpt(k, x, J)
        say(@sprintf("\nTIME BUDGET: %.0f of %.0f minutes used; checkpoint written at stage %d, to resume in a new job.", elapsed(), BUDGET, k))
        exit(3)
    end
end

ck = load_ckpt()
if ck === nothing
    stage = 0; x = [off.beta_bar * SURV, log(off.chi0), off.impatient_share, log(off.phi)]; J = zeros(4, 4)
else
    stage, x, J = ck
    say("resumed from the checkpoint at stage ", stage)
end

s = nothing
while true
    budget_check(stage, x, J)
    t1 = time(); global s = solveE(x); LAST[] = (time() - t1) / 60
    showr(stage == 0 ? "1. E-off point over places" : "2. correction $stage", x, s)
    F = resid(s.m)[ACT]
    (maximum(abs.(F)) <= 0.5 || stage >= 3) && break
    if all(iszero, J)
        # the E-off Jacobian at the E-off point, on the national economy
        x0 = [off.beta_bar * SURV, log(off.chi0), off.impatient_share, log(off.phi)]
        F0 = resid(mom(_solve(with(off, x0), nothing; disk = false)))
        for k in ACT
            xk = copy(x0); h = (xk[k] + STEP[k] > HI[k]) ? -STEP[k] : STEP[k]; xk[k] += h
            J[:, k] = (resid(mom(_solve(with(off, xk), nothing; disk = false))) .- F0) ./ h
        end
        say(@sprintf("   the E-off Jacobian  [%.1f min]", elapsed()))
    end
    Δ = zeros(4); Δ[ACT] .= -(J[ACT, ACT] \ F)
    sfac = minimum(min(1.0, MAXMOVE[k] / max(abs(Δ[k]), 1e-12)) for k in ACT)
    global x = clamp.(x .+ sfac .* Δ, LO, HI)
    global stage += 1; save_ckpt(stage, x, J)
end

maximum(abs.(resid(s.m)[ACT])) <= 1.0 || notcal(@sprintf("worst owned target at %.2f of its band over places.", maximum(abs.(resid(s.m)[ACT]))))
CHI_BORROWED && say(@sprintf("  untargeted: wealthy hand-to-mouth %.4f against %.4f in the data (chi0 borrowed with the %s calibration)", s.m.whtm, WHTM_TARGET, OFF))
r = s.r
say(@sprintf("  validation (not targeted): MPC %.3f | drop on job loss %.3f | protection if hit %.4f | agency %.4f | hardship %.4f | room %.3f",
             r.mpc, r.consumption_drop, r.A_cond, r.A, r.hardship, r.room))
say("  by place: agency, hardship, poor and wealthy hand-to-mouth")
for (name, q) in r.by_place
    @printf("    %-6s %.3f  %.3f  %.4f  %.4f\n", name, q.A, q.hardship, q.hand_to_mouth_kvw, q.wealthy_htm)
end
u = unpack(x)
open(OUTFILE, "w") do io
    println(io, "# written by calibrate_two_asset_e.jl $(CODE) $(CFG); illiquid asset on, E on (", off.typology, ")",
            CHI_BORROWED ? "; chi0 from the $(OFF) calibration (borrowed there), wealthy hand-to-mouth untargeted" : "")
    @printf(io, "phi = %.3f\nbeta_spread = 0.0\nbeta_bar = %.4f\nimpatient_share = %.4f\nbeta_low = %.4f\nchi0 = %.4f\nilliquid_premium = %.4f\n",
            u.phi, u.beta_bar, u.impatient_share, BETA_LOW_EFF / SURV, u.chi0, off.illiquid_premium)
end
isfile(NOTCAL) && rm(NOTCAL)
isfile(CKPT) && rm(CKPT)
say("wrote ", basename(OUTFILE))
@printf("\nDONE %s %s (illiquid, E on) in %.1f min\n", CODE, CFG, elapsed())

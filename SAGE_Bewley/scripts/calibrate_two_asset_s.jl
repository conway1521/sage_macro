# Calibrate the two-asset model with the social dimension on (GSA, or GS) for
# one country. Needs the two-asset calibration of the same configuration
# without S (GA for GSA, G for GS) and, for GS, the two-asset GSA calibration
# (G+S takes sigma from it: target ownership, calibrate_country.jl).
#
#   julia --project=scripts/run_env scripts/calibrate_two_asset_s.jl FR GSA
#
# 1. Start from the cohesion-off calibration (beta_bar, chi0, spread, phi).
# 2. The S-off Jacobian of the four G targets (net wealth / income, wealthy
#    and poor hand-to-mouth, effort) at that point, by finite differences.
# 3. Families with S on (coarse belonging grid), the social technology scanned
#    against the participation targets it owns, under the stability gate.
# 4. The S-on economy solved; if a G target is outside its band, one
#    quasi-Newton step with the S-off Jacobian on the S-on residuals, then back
#    to 3. Up to three corrections: cohesion shifts the G moments but hardly
#    their sensitivities, so each correction costs one family build.
# 5. The technology re-scanned and the economy solved on the full belonging
#    grid; checked; written to calibration_country_<CODE>_<CFG>_I.txt.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
say(args...) = (println(args...); flush(stdout))

const CODE = ARGS[1]
const CFG = uppercase(ARGS[2])
CFG in ("GS", "GSA") || error("configuration must be GS or GSA, got $CFG")
const A_ON = CFG == "GSA"
const OFF = A_ON ? "GA" : "G"
const ROW = country_rows()[CODE]
num(k) = parse(Float64, ROW[k])
const E_TARGET = num("effort_target"); const HTM_TARGET = num("htm_target")
const PART = (num("part_low"), num("part_high")); const RATIO = num("ratio")
manual = Dict{Tuple{String,String},Float64}()
for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "manual_inputs.csv"))
    startswith(ln, "#") && continue
    f = split(ln, ","); length(f) >= 3 || continue
    v = tryparse(Float64, f[3]); v === nothing || (manual[(f[1], f[2])] = v)
end
const WHTM_TARGET = manual[(CODE, "whtm_target")]; const NW_TARGET = manual[(CODE, "nw_income_target")]
const TOL = (nw = 0.05, whtm = 0.01, htm = 0.005, e = 0.005)
const MULT_MAX = 5.0
const OWN_GAP = A_ON
const OUTFILE = joinpath(@__DIR__, "calibration_country_$(CODE)_$(CFG)_I.txt")
const NOTCAL = replace(OUTFILE, r"\.txt$" => ".not_calibrated.txt")
# a failed run leaves neither an earlier calibration file (it would be uploaded and
# read as if it were this run's) nor its checkpoint (a rerun would resume the failure)
notcal(msg) = (isfile(OUTFILE) && rm(OUTFILE); isfile(CKPT) && rm(CKPT);
               open(io -> println(io, "# not calibrated; the reason is in the run log"), NOTCAL, "w");
               say("\nNOT CALIBRATED: ", msg, " No calibration file written."); exit(2))

isfile(joinpath(@__DIR__, "calibration_country_$(CODE)_$(OFF)_I.txt")) ||
    error("needs the two-asset $(OFF) calibration first")
off = country_config(CODE; config = OFF, S = false, A = A_ON, illiquid = true)
# If the cohesion-off calibration borrowed chi0 and left the wealthy hand-to-mouth
# untargeted (Germany and Italy: calibrate_two_asset.jl with a third argument),
# so does this one: chi0 stays at its value and the target is reported, not fitted.
const CHI_BORROWED = occursin("chi0 from", readline(joinpath(@__DIR__, "calibration_country_$(CODE)_$(OFF)_I.txt")))
const ACT = CHI_BORROWED ? [1, 3, 4] : [1, 2, 3, 4]
const SIGMA_FIX = OWN_GAP ? NaN : country_config(CODE; config = "GSA", illiquid = true).sigma_m
cs0 = cells_of(SAGEConfig(off; S = true))
const AGG = cs0[1].share * PART[1] + cs0[2].share * PART[2]
say("calibrating ", CODE, " ", CFG, " with the illiquid asset, from the ", OFF, " calibration | targets: net wealth / income ",
    NW_TARGET, ", wealthy htm ", WHTM_TARGET, ", poor htm ", HTM_TARGET, ", effort ", round(E_TARGET; digits = 4), ", ",
    OWN_GAP ? "participation by cell $(PART)" : @sprintf("overall participation %.4f with sigma %.2f from G+S+A", AGG, SIGMA_FIX),
    " | workers ", nworkers())

qmed(x, cm) = cdf_quantile(x, cm, 0.5)      # interpolated: the node above the median was up to 5% high, the width of the band (audit 2026-10-02)
# the first parameter is effective patience, beta_bar times survival (calibrate_two_asset.jl)
const SURV = 1 - off.death
# two patience groups, as in calibrate_two_asset.jl
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

# CHECKPOINTS (2026-09-29), as in calibrate_two_asset.jl. The file holds the
# stage k (the point after k corrections, not yet evaluated; 4 = the corrections
# are over and the full-grid stage is next), the point and the S-off Jacobian.
# With SAGE_TIME_BUDGET_MIN set, the run stops before a stage that would not
# finish inside the budget, with exit code 3, and the workflow resumes it.
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
const LAST = Ref(60.0)      # minutes the last families-and-solve stage took
function budget_check(k, x, J; factor = 1.2)
    if elapsed() + factor * LAST[] > BUDGET
        save_ckpt(k, x, J)
        say(@sprintf("\nTIME BUDGET: %.0f of %.0f minutes used; checkpoint written at stage %d, to resume in a new job.", elapsed(), BUDGET, k))
        exit(3)
    end
end

# 1 and 2
ck = load_ckpt()
if ck === nothing
    x = [off.beta_bar * SURV, log(off.chi0), off.impatient_share, log(off.phi)]
    F0 = resid(mom(_solve(with(off, x), nothing; disk = false)))
    J = zeros(4, 4)
    for k in ACT
        xk = copy(x); h = (xk[k] + STEP[k] > HI[k]) ? -STEP[k] : STEP[k]; xk[k] += h
        J[:, k] = (resid(mom(_solve(with(off, xk), nothing; disk = false))) .- F0) ./ h
    end
    stage = 0; save_ckpt(stage, x, J)
    say(@sprintf("1-2. %s point and its S-off Jacobian  [%.1f min]", OFF, elapsed()))
else
    stage, x, J = ck
    say("1-2. resumed from the checkpoint at stage ", stage)
end

# 3. technology scan on the families
function scan(x; ugrid = UGRID_COARSE)
    c = with(SAGEConfig(off; S = true, ugrid = ugrid), x)
    t1 = time(); raw = collect(build_families(c, nothing; disk = true))
    emp = employment_mask(c)
    fi = [impose_unemployed_ratio(f, emp, RATIO) for f in raw]
    cr = SAGEConfig(c; unemployed_ratio = RATIO)
    rows = OWN_GAP ? scan_technology(cr, fi, collect(0.30:0.02:3.00), collect(2.0:0.05:25.0); targets = PART, max_mult = MULT_MAX, selected_only = true) :
                     scan_technology(cr, fi, [SIGMA_FIX], collect(2.0:0.05:25.0); aggregate = AGG, max_mult = MULT_MAX, selected_only = true)
    isempty(rows) && notcal("no stable equilibrium with a multiplier of at most 5.")
    best = rows[argmin([r.loss for r in rows])]
    std = OWN_GAP ? 0.035 : 0.005
    best.loss > std && notcal(@sprintf("best participation fit %.4f, above the %.3f standard.", best.loss, std))
    @printf("  families in %.1f min; best kappa %.2f sigma %.2f, loss %.4f, multiplier %.1f\n", (time() - t1) / 60, best.κ, best.σ, best.loss, best.mult)
    flush(stdout)
    (c = SAGEConfig(cr; kappa = best.κ, sigma_m = best.σ), best = best)
end
solveS(sc) = (r = _solve(sc.c, nothing; disk = true); (r = r, m = mom(r)))
showr(tag, x, s) = (u = unpack(x);
    @printf("%s beta_bar %.4f chi0 %.4f impatient share %.4f phi %.3f | participation %.4f (cells %.4f, %.4f), multiplier %.1f | net wealth/income %.2f, wealthy htm %.4f, poor htm %.4f, effort %.4f | worst %.2f band  [%.1f min]\n",
            tag, u.beta_bar, u.chi0, u.impatient_share, u.phi, s.r.rate, s.r.pooled[1].rate, s.r.pooled[2].rate, 1 / (1 - s.r.slope),
            s.m.nw, s.m.whtm, s.m.htm, s.m.e, maximum(abs.(resid(s.m)[ACT])), elapsed()); flush(stdout))

say("3-4. families, technology and corrections")
while stage < 4
    budget_check(stage, x, J)
    t2 = time()
    global sc = scan(x); global s = solveS(sc)
    LAST[] = (time() - t2) / 60
    showr(stage == 0 ? "  start" : "  correction $stage", x, s)
    F = resid(s.m)[ACT]
    (maximum(abs.(F)) <= 0.5 || stage >= 3) && break
    Δ = zeros(4); Δ[ACT] .= -(J[ACT, ACT] \ F)     # the owned targets on the fitted parameters
    sfac = minimum(min(1.0, MAXMOVE[k] / max(abs(Δ[k]), 1e-12)) for k in ACT)
    global x = clamp.(x .+ sfac .* Δ, LO, HI)
    global stage += 1; save_ckpt(stage, x, J)
end
stage = 4; save_ckpt(stage, x, J)

say("5. the full belonging grid")
budget_check(4, x, J; factor = 2.5)       # the full grid has about twice the scales
sc = scan(x; ugrid = UGRID_DEFAULT); s = solveS(sc); showr("  final", x, s)
maximum(abs.(resid(s.m)[ACT])) <= 1.0 || notcal(@sprintf("worst G target at %.2f of its band on the full grid.", maximum(abs.(resid(s.m)[ACT]))))
CHI_BORROWED && say(@sprintf("  untargeted: wealthy hand-to-mouth %.4f against %.4f in the data (chi0 borrowed with the %s calibration)", s.m.whtm, WHTM_TARGET, OFF))
1 / (1 - s.r.slope) <= MULT_MAX || notcal(@sprintf("multiplier %.1f above the gate.", 1 / (1 - s.r.slope)))
OWN_GAP || say(@sprintf("  untargeted: participation gap between the cells %.4f against %.4f in the data", s.r.pooled[2].rate - s.r.pooled[1].rate, PART[2] - PART[1]))
r = s.r
say(@sprintf("  validation (not targeted): MPC %.3f (poor htm %.3f, wealthy %.3f) | drop on job loss %.3f | protection if hit %.4f | agency %.4f | room %.3f | median liquid / median income %.3f",
             r.mpc, r.mpc_htm, r.mpc_wealthy, r.consumption_drop, r.A_cond, r.A, r.room, qmed(r.agrid, r.Wtot) / r.median_income))
u = unpack(x)
open(OUTFILE, "w") do io
    println(io, "# written by calibrate_two_asset_s.jl $(CODE) $(CFG); illiquid asset on", CHI_BORROWED ? "; chi0 from the $(OFF) calibration (borrowed there), wealthy hand-to-mouth untargeted" : "")
    @printf(io, "phi = %.3f\nbeta_spread = 0.0\nbeta_bar = %.4f\nimpatient_share = %.4f\nbeta_low = %.4f\nchi0 = %.5f\nilliquid_premium = %.4f\nkappa = %.2f\nsigma_m = %.2f\n",
            u.phi, u.beta_bar, u.impatient_share, BETA_LOW_EFF / SURV, u.chi0, off.illiquid_premium, sc.best.κ, sc.best.σ)
end
isfile(NOTCAL) && rm(NOTCAL)
isfile(CKPT) && rm(CKPT)
say("wrote ", basename(OUTFILE))
@printf("\nDONE %s %s (illiquid) in %.1f min\n", CODE, CFG, elapsed())

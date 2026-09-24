# Calibrate one country and one configuration on the modular engine.
#
#   julia --project=. scripts/calibrate_country.jl DE        # G+S+A, the headline
#   julia --project=. scripts/calibrate_country.jl DE GA     # G+A calibrated on its own
#   julia --project=. scripts/calibrate_country.jl DE G      # G
#   julia --project=. scripts/calibrate_country.jl DE GS     # G+S
#
# TWO DIFFERENT PROPERTIES. The reductions in test_modular.jl show that
# switching a dimension off gives back exactly the economy without it, at the
# same parameters. That certifies the switches. It does not make each economy
# fit the data: at France's calibrated point, switching cohesion off moves
# hand-to-mouth from 0.308 to 0.262, because participation takes time from work
# and so changes saving. So every configuration is also calibrated to its own
# targets: G and G+A to effort and hand-to-mouth, G+S and G+S+A to those plus
# participation by education. The fixed-parameter comparison says what a
# mechanism does; the recalibrated one says what each economy looks like when it
# is made to fit. Both are reported.
#
# Inputs: the country's row in data/country_labour_participation.csv. Output:
# calibration_country_<code>.txt for G+S+A, calibration_country_<code>_<cfg>.txt
# for the others, which `country_config(code; config)` reads.
#
# THE RECIPE:
#  0. Preflight: the no-cohesion path must reproduce the suite's France G+A
#     economy to 1e-6, or nothing below is trusted. On another machine this is
#     also the check that its Julia build reproduces the reference numbers.
#  1. Effort scale and discount spread with cohesion off: effort to the target,
#     hand-to-mouth to the target less France's cohesion gap for this
#     configuration (zero when cohesion is off). Two passes.
#  Cohesion off: 2. solve the economy on its own thresholds, write the file.
#  Cohesion on:
#  2. The response families at that point (one build, cached on disk).
#  3. The social technology scanned against the two education participation
#     targets at the national unemployed ratio, and for G+S+A also at the other
#     national ratios in the data (free: the rule is applied after the families).
#  4. The calibrated economy solved on its own thresholds.
#  5. One correction if hand-to-mouth misses by more than 0.02.
#  6. For G+S+A, the four economies at its parameters: the fixed-parameter view.
#
# STOPPING RULES. If no technology gives a stable equilibrium, or the best root
# loss exceeds 0.035 (stage 7's absolute standard), the configuration is
# reported as not calibrated and no file is written: exit 2. A failed preflight
# exits 3. Nothing is tuned by hand.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics, SHA
say(args...) = (println(args...); flush(stdout))

const CODE = ARGS[1]
const CFG = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "GSA"
CFG in ("G", "GA", "GS", "GSA") || error("configuration must be G, GA, GS or GSA, got $CFG")
const S_ON = occursin('S', CFG)
const A_ON = occursin('A', CFG)
const ROW = country_rows()[CODE]
num(k) = parse(Float64, ROW[k])
const E_TARGET = num("effort_target")
const HTM_TARGET = num("htm_target")
const PART = (num("part_low"), num("part_high"))
const RATIO = num("ratio")
# The national ratio exactly, and for the headline configuration the other
# national figures in the data as a sensitivity.
const RATIOS = CFG == "GSA" ? vcat(RATIO, [x for x in (0.486, 0.574, 0.857, 0.937) if abs(x - RATIO) > 0.002]) : [RATIO]
# How much switching cohesion on raises hand-to-mouth, used to aim the
# cohesion-off fit. G+S+A: France on EU-SILC, 0.2804 with cohesion against 0.2512
# without (calibrate_country_FR.txt, 2026-09-23). The INSEE footing's gap, 0.046,
# came from a multiplier of 21 and overshot by 0.02 at the EU-SILC multiplier of 2.
# G+S: still the INSEE-footing value; the correction step covers any miss.
const GAP = CFG == "GSA" ? 0.2804 - 0.2512 : CFG == "GS" ? 0.285162 - 0.251030 : 0.0
# Switching S on must still hit the G targets, so hand-to-mouth gets one
# correction when it misses by more than this.
const HTM_TOL = 0.01
const SKIP_GS = get(ENV, "SKIP_GS", "0") == "1"
const OUTFILE = joinpath(@__DIR__, CFG == "GSA" ? "calibration_country_$(CODE).txt" :
                                                  "calibration_country_$(CODE)_$(CFG).txt")
const NOTCAL = replace(OUTFILE, r"\.txt$" => ".not_calibrated.txt")
mark_not_calibrated() = open(io -> println(io, "# not calibrated; the reason is in the run log"), NOTCAL, "w")

# CHECKPOINTS, so a run stopped part-way loses at most the family build in
# progress. Response families are cached by build_families already; what is
# not is the fitted effort scale and discount spread (step 1, about ten
# minutes) and the corrected spread (step 5). A checkpoint is reused only for
# exactly the same inputs: the country's data row, the configuration, the
# hand-to-mouth aim and the solver's source code.
const CKDIR = joinpath(@__DIR__, "checkpoints"); isdir(CKDIR) || mkpath(CKDIR)
const CKKEY = bytes2hex(sha1(string(sort(collect(ROW)), "|", CFG, "|", GAP, "|", SOLVER_DIGEST)))[1:16]
ckfile(stage) = joinpath(CKDIR, "$(CODE)_$(CFG)_$(stage)_$(CKKEY).txt")
function ck_read(stage)
    f = ckfile(stage); isfile(f) || return nothing
    d = Dict{String,Float64}()
    for ln in eachline(f)
        k, v = split(ln, "="); d[strip(k)] = parse(Float64, v)
    end
    d
end
function ck_write(stage, d)
    f = ckfile(stage)
    open(f * ".tmp", "w") do io
        for (k, v) in d
            println(io, k, " = ", v)
        end
    end
    mv(f * ".tmp", f; force = true)
end

say("calibrating ", CODE, " ", CFG, " | effort target ", E_TARGET, " | hand-to-mouth target ", HTM_TARGET,
    S_ON ? " | participation targets $(PART) | national ratio $(RATIO)" : "", " | workers ", nworkers())
t_start = time()

function write_cal(phi, spread; kappa = nothing, sigma = nothing)
    open(OUTFILE, "w") do io
        println(io, "# written by calibrate_country.jl $(CODE) $(CFG); read by country_config")
        @printf(io, "phi = %.2f\nbeta_spread = %.3f\n", phi, spread)
        kappa === nothing || @printf(io, "kappa = %.2f\nsigma_m = %.2f\n", kappa, sigma)
    end
    isfile(NOTCAL) && rm(NOTCAL)
    say("wrote ", basename(OUTFILE))
end

# ------------------------------------------------------------- 0. preflight --
let fr = SAGEConfig(A = true, unemployment = true, beta_spread = 0.037, unemployed_ratio = 0.17 / 0.35),
    r = _solve(fr, nothing; disk = true)
    gap = max(abs(r.mean_effort_employed - 0.518873), abs(r.hand_to_mouth - 0.261599), abs(r.median_income - 0.376010))
    @printf("preflight, France G+A through the parallel path: worst gap %.1e against the suite: %s\n", gap,
            gap < 1e-6 ? "HELD" : "FAILED")
    flush(stdout)
    gap < 1e-6 || exit(3)
end

# --------------------------------------------------- 1. effort and spread --
soff(phi, sp) = _solve(country_config(CODE; config = CFG, S = false, A = A_ON, phi = phi, beta_spread = sp),
                       nothing; disk = true)
function fit_phi(sp; lo = 3.0, hi = 40.0, steps = 12)
    for _ in 1:steps
        mid = 0.5 * (lo + hi)
        soff(mid, sp).mean_effort_employed > E_TARGET ? (lo = mid) : (hi = mid)
    end
    round(0.5 * (lo + hi); digits = 2)
end
function fit_spread(phi, target; grid = 0.0:0.005:0.10)
    hs = [soff(phi, sp).hand_to_mouth for sp in grid]
    k = findfirst(>=(target), hs)
    k === nothing && return (sp = grid[end], htm = hs[end], edge = true)
    k == 1 && return (sp = grid[1], htm = hs[1], edge = true)
    t = (target - hs[k-1]) / (hs[k] - hs[k-1])
    (sp = round(grid[k-1] + t * (grid[k] - grid[k-1]); digits = 3), htm = target, edge = false)
end
say("\n1. effort scale and discount spread, cohesion off, hand-to-mouth aim ", round(HTM_TARGET - GAP; digits = 4))
ck1 = ck_read("stage1")
if ck1 === nothing
    phi = fit_phi(0.037)
    fs = fit_spread(phi, HTM_TARGET - GAP)
    phi = fit_phi(fs.sp; lo = max(3.0, phi - 4), hi = phi + 4, steps = 8)
    fs = fit_spread(phi, HTM_TARGET - GAP; grid = max(0.0, fs.sp - 0.015):0.005:(fs.sp + 0.015))
    spread = fs.sp; edge = fs.edge
    chk = soff(phi, spread)
    chk_e, chk_h = chk.mean_effort_employed, chk.hand_to_mouth
    ck_write("stage1", Dict("phi" => phi, "spread" => spread, "edge" => Float64(edge),
                            "effort" => chk_e, "htm" => chk_h))
else
    phi, spread, edge = ck1["phi"], ck1["spread"], ck1["edge"] == 1.0
    chk_e, chk_h = ck1["effort"], ck1["htm"]
    say("  from checkpoint ", basename(ckfile("stage1")))
end
@printf("  phi %.2f, spread %.3f%s: effort %.4f (target %.4f), hand-to-mouth %.4f (aim %.4f)  [%.1f min]\n",
        phi, spread, edge ? " (ON THE GRID EDGE)" : "", chk_e, E_TARGET,
        chk_h, HTM_TARGET - GAP, (time() - t_start) / 60)
flush(stdout)

# If no discount spread on the grid brings hand-to-mouth near its aim, nothing
# downstream can: families, scans and the one correction all take the spread as
# given. So record the configuration as not calibrated here rather than spend
# hours on it. First seen for the US, whose benefit runs out after five months
# (twelve-month replacement 0.13): hand-to-mouth 0.019 at spread 0.115 against
# an aim of 0.281.
if edge && abs(chk_h - (HTM_TARGET - GAP)) > 0.05
    say(@sprintf("\nNOT CALIBRATED: hand-to-mouth reaches only %.4f at the largest spread tried (%.3f), against an aim of %.4f. No calibration file written.",
                 chk_h, spread, HTM_TARGET - GAP))
    mark_not_calibrated(); exit(2)
end

if !S_ON
    say("\n2. the ", CFG, " economy on its own thresholds")
    r = solve_economy(country_config(CODE; config = CFG, S = false, A = A_ON, phi = phi, beta_spread = spread))
    @printf("  participation %.4f | agency %.4f | hardship %.4f | hand-to-mouth %.4f (target %.2f) | effort %.4f (target %.4f) | median %.4f\n",
            r.rate, r.A, r.hardship, r.hand_to_mouth, HTM_TARGET, r.mean_effort_employed, E_TARGET, r.median_income)
    abs(r.hand_to_mouth - HTM_TARGET) > HTM_TOL && say("  hand-to-mouth off target by more than ", HTM_TOL, "; recorded, not tuned")
    write_cal(phi, spread)
    @printf("\nDONE %s %s in %.1f min\n", CODE, CFG, (time() - t_start) / 60)
    exit(0)
end

# ------------------------------------------- 2 and 3. families and scans --
const SIGMAS = 0.30:0.02:1.50
const KAPPAS = 2.0:0.05:25.0
function scans(phi, spread)
    c = country_config(CODE; config = CFG, S = true, A = A_ON, phi = phi, beta_spread = spread)
    t0 = time()
    raw = collect(build_families(c, nothing; disk = true))
    @printf("  families built or loaded in %.1f min\n", (time() - t0) / 60); flush(stdout)
    emp = employment_mask(c)
    out = Dict{Float64,Any}()
    for ρ in RATIOS
        cr = SAGEConfig(c; unemployed_ratio = ρ)
        fi = [impose_unemployed_ratio(f, emp, ρ) for f in raw]
        # Wide on purpose: France on EU-SILC put its first best sigma on the old
        # 0.80 bound, and a best value on an edge only says the search stopped there.
        rows = scan_technology(cr, fi, collect(SIGMAS), collect(KAPPAS); targets = PART)
        if isempty(rows)
            @printf("  ratio %.3f: no stable equilibrium anywhere on the grid\n", ρ); out[ρ] = nothing; continue
        end
        best = rows[argmin([x.loss for x in rows])]
        ok = [x for x in rows if x.loss <= 0.035]
        edge = (best.σ <= first(SIGMAS) || best.σ >= last(SIGMAS) ? " SIGMA ON THE GRID EDGE" : "") *
               (best.κ <= first(KAPPAS) || best.κ >= last(KAPPAS) ? " KAPPA ON THE GRID EDGE" : "")
        @printf("  ratio %.3f%s: best kappa %.2f sigma %.2f, root loss %.4f, rate %.4f, multiplier %.1f%s",
                ρ, ρ == RATIO ? " (national)" : "", best.κ, best.σ, best.loss, best.r, best.mult, edge)
        isempty(ok) ? println(" | nothing within 0.035") :
            @printf(" | within 0.035: sigma %.2f to %.2f, multiplier %.1f to %.1f\n",
                    minimum(x.σ for x in ok), maximum(x.σ for x in ok), minimum(x.mult for x in ok), maximum(x.mult for x in ok))
        flush(stdout)
        out[ρ] = (best = best, ok = ok)
    end
    out
end
say("\n2-3. ", CFG, " families and technology scans, participation targets ", PART)
S = scans(phi, spread)
if S[RATIO] === nothing || S[RATIO].best.loss > 0.035
    say("\nNOT CALIBRATED: at the national ratio the best fit is ", S[RATIO] === nothing ? "absent" :
        @sprintf("%.4f, above the 0.035 standard", S[RATIO].best.loss), ". No calibration file written.")
    mark_not_calibrated(); exit(2)
end

# ------------------------------------------------------ 4 and 5. solve --
function solve_at(phi, spread, best)
    c = country_config(CODE; config = CFG, S = true, A = A_ON, phi = phi, beta_spread = spread,
                       kappa = best.κ, sigma_m = best.σ)
    t0 = time(); r = solve_economy(c)
    @printf("  %s: participation %.4f (cells %.4f, %.4f against %.3f, %.3f; employed %.4f, unemployed %.4f)\n",
            CFG, r.rate, r.pooled[1].rate, r.pooled[2].rate, PART..., r.rate_E, r.rate_U)
    @printf("         agency %.4f, hardship %.4f, hand-to-mouth %.4f (target %.2f), effort %.4f, multiplier %.1f  [%.1f min]\n",
            r.A, r.hardship, r.hand_to_mouth, HTM_TARGET, r.mean_effort_employed, 1 / (1 - r.slope), (time() - t0) / 60)
    flush(stdout)
    r
end
say("\n4. the calibrated ", CFG, " economy on its own thresholds")
best = S[RATIO].best
r = solve_at(phi, spread, best)
if abs(r.hand_to_mouth - HTM_TARGET) > HTM_TOL
    gap_c = r.hand_to_mouth - chk_h
    say(@sprintf("\n5. hand-to-mouth off by %+.4f, more than the %.2f tolerance; this economy's own cohesion gap is %+.4f against France's %+.4f. One correction.",
                 r.hand_to_mouth - HTM_TARGET, HTM_TOL, gap_c, GAP))
    ck5 = ck_read("stage5")
    if ck5 === nothing
        fs2 = fit_spread(phi, HTM_TARGET - gap_c)
        spread = fs2.sp; edge2 = fs2.edge
        ck_write("stage5", Dict("spread" => spread, "edge" => Float64(edge2)))
    else
        spread, edge2 = ck5["spread"], ck5["edge"] == 1.0
        say("  from checkpoint ", basename(ckfile("stage5")))
    end
    @printf("  new spread %.3f%s\n", spread, edge2 ? " (ON THE GRID EDGE)" : ""); flush(stdout)
    S = scans(phi, spread)
    if S[RATIO] === nothing || S[RATIO].best.loss > 0.035
        say("\nNOT CALIBRATED after the correction. No calibration file written.")
        mark_not_calibrated(); exit(2)
    end
    best = S[RATIO].best
    r = solve_at(phi, spread, best)
    abs(r.hand_to_mouth - HTM_TARGET) > HTM_TOL &&
        say("  hand-to-mouth still off target after the one allowed correction; recorded, not tuned further")
end
write_cal(phi, spread; kappa = best.κ, sigma = best.σ)

# ------------------------------------- 6. the fixed-parameter four economies --
if CFG == "GSA"
    say("\n6. the four economies at ", CODE, "'s G+S+A parameters (the fixed-parameter view)")
    for (nm, S_, A_) in (("G     ", false, false), ("G+A   ", false, true), ("G+S   ", true, false), ("G+S+A ", true, true))
        (SKIP_GS && S_ && !A_) && (say(nm, " skipped (SKIP_GS)"); continue)
        rr_ = solve_economy(country_config(CODE; S = S_, A = A_))
        @printf("%s participation %.4f (E %.4f, U %.4f) | agency %.4f | hardship %.4f | htm %.4f | effort %.4f | median %.4f\n",
                nm, rr_.rate, rr_.rate_E, rr_.rate_U, rr_.A, rr_.hardship, rr_.hand_to_mouth,
                rr_.mean_effort_employed, rr_.median_income)
        flush(stdout)
    end
end
@printf("\nDONE %s %s in %.1f min\n", CODE, CFG, (time() - t_start) / 60)

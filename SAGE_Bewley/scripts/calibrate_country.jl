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
# participation (G+S+A by education, G+S overall: see TARGET OWNERSHIP below).
# The fixed-parameter comparison says what a
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
#  5. Up to two corrections if a target misses by more than half the tolerance;
#     a configuration still outside it is not calibrated.
#  6. For G+S+A, the four economies at its parameters: the fixed-parameter view.
#
# STOPPING RULES. If no technology gives a stable equilibrium with a multiplier
# of at most MULT_MAX, or the best root loss exceeds the standard (0.035 on the
# two cell targets, AGG_TOL on overall participation), the configuration is
# reported as not calibrated and no file is written: exit 2. A failed preflight
# exits 3. Nothing is tuned by hand.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics, SHA
say(args...) = (println(args...); flush(stdout))

const CODE = ARGS[1]
const CFG = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "GSA"
CFG in ("G", "GA", "GS", "GSA", "GE", "GAE", "GSE", "GSAE") ||
    error("configuration must be G, GA, GS, GSA, or one of them with E (GE, GAE, GSE, GSAE), got $CFG")
const S_ON = occursin('S', CFG)
const A_ON = occursin('A', CFG)
# VERSION 3 (SAGE_V3=1; V3_START.md, sections 13 and 14). The same recipe on the
# version 3 economy (country_config with v3 = true: effort set by the job, the
# household replacement rate, participation time from the time-use surveys), with
# the single asset read as LIQUID wealth on the narrow definition and its targets
# from the HFCS (data/hfcs_targets.csv, wave 2021):
#   phi          -> effort of the employed
#   top patience -> median liquid wealth over median after-tax income
#   spread       -> hand-to-mouth, total, on the model's rule (one week of income)
# The two patience parameters move the two wealth moments along nearly one line,
# so step 1 is a best fit (damped least squares) and the misses are reported.
# The MPC is not targeted; it is printed against the survey's self-reported MPC.
# Writes calibration_v3_<code>_<cfg>.txt. Version 2 is untouched when the flag is off.
# VERSION 4 (SAGE_V4=1; V3_START.md, sections 34 to 36): the regime of country_config with v3 = :v4 (the
# floor, patience by education, the transitory part and the proportional tax, every parameter under
# the rule of section 34: the income process as published, by education, nothing of it fitted), and
# the fit by the simulated method of moments: one criterion over the effort of the employed, the
# hand-to-mouth share, its difference by education, median liquid wealth over income and the MPC, each
# HFCS moment weighted by the inverse of its sampling variance (the standard errors of
# data/hfcs_targets.csv), as in Ampudia, Cooper, Le Blanc and Zhu (2024, equation 10). No tolerance
# band is set by hand for a moment that has a standard error. S80/S20 is a test. Files calibration_v4_*.
const V4 = get(ENV, "SAGE_V4", "0") == "1"
const V3 = V4 || get(ENV, "SAGE_V3", "0") == "1"
# THE FLOOR IN THE BASE (SAGE_FLOOR=1 with SAGE_V3=1; V3_START.md, section 22). A means-tested floor
# (Hubbard, Skinner and Zeldes 1995), financed by the lump-sum tax, with patience the same for all
# (no spread). In G the floor's level is the fourth parameter of the fit and median liquid wealth is
# the moment it owns, beside the hand-to-mouth share that patience owns: at a given hand-to-mouth
# share a higher floor means more patient households with more liquid wealth, which the spread could
# not give (it moves the two moments along the same line as patience). In every other configuration
# the floor is the country's, read from its G file. Files calibration_v3f_<code>_<cfg>.txt.
const FLOORREG = V4 || (V3 && get(ENV, "SAGE_FLOOR", "0") == "1")
# The configuration in which the country's floor is fitted (SAGE_FLOOR_FROM, default G); every other
# configuration reads it from that one's file. One rule for every country, 2026-10-05: GE, the base
# with places. Fitted in G, Italy's floor (0.215 of reference earnings) is too high once the poorer
# regions are in, and no configuration with places then meets the hand-to-mouth share.
const FLOOR_CFG = uppercase(get(ENV, "SAGE_FLOOR_FROM", "G"))
# PATIENCE BY EDUCATION (SAGE_EDU=1 with SAGE_V3=1; V3_START.md, section 24). The lower-education
# cell's discount factor lies a gap below the other's; the gap is a parameter of the fit and the
# difference between the two cells' hand-to-mouth shares (HFCS, by education) is the moment it owns.
# No spread within a cell. Files calibration_v3e_* and, with the floor, calibration_v3fe_*.
const EDUREG = V4 || (V3 && get(ENV, "SAGE_EDU", "0") == "1")
# THE TRANSITORY PART AND THE PROPORTIONAL TAX (SAGE_TRANS=1 with SAGE_V3=1; V3_START.md, section 29).
# The same regime with both on; files with a t added to the tag (calibration_v3fet_* for the base).
const TRANS = V4 || (V3 && get(ENV, "SAGE_TRANS", "0") == "1")
const VTAG0 = V4 ? "v3fet" : "v3" * (FLOORREG ? "f" : "") * (EDUREG ? "e" : "")          # the regime the starting point is read from
const V3ARG = V4 ? :v4 : TRANS ? Symbol((FLOORREG ? "floor_" : "") * (EDUREG ? "edu_" : "") * "trans") :
              FLOORREG ? (EDUREG ? :floor_edu : :floor) : (EDUREG ? :edu : V3)
# A TRIAL INCOME PROCESS (SAGE_RHO, SAGE_SDEPS with SAGE_TRANS=1): the persistence of the persistent part
# and the size of the transitory part given here in place of the country table's; files tagged with an
# r more (V3_START.md, section 31). The fit is as always: the persistent innovation to S80/S20.
const RHO_TRIAL = TRANS && haskey(ENV, "SAGE_RHO") ? parse(Float64, ENV["SAGE_RHO"]) : NaN
const SDEPS_TRIAL = TRANS && haskey(ENV, "SAGE_SDEPS") ? parse(Float64, ENV["SAGE_SDEPS"]) : NaN
const VTAG = V4 ? "v4" : VTAG0 * (TRANS ? "t" : "") * ((isnan(RHO_TRIAL) && isnan(SDEPS_TRIAL)) ? "" : "r")
function hfcs_target(moment; wave = "2021")
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        f = split(ln, ",")
        length(f) >= 6 && f[1] == moment && f[2] == CODE && f[3] == wave && f[4] == "all" && return parse(Float64, f[6])
    end
    error("no HFCS target $moment for $CODE in $wave")
end
# E ON (2026-09-29): the economy over places (TL2 by default, place_layer.jl).
# E fits nothing: the national targets are the same as with E off, and the place
# outcomes are untargeted tests. Every solve below dispatches through
# solve_economy, and the technology scan becomes place-aware.
const E_ON = occursin('E', CFG)
const ROW = country_rows()[CODE]
num(k) = parse(Float64, ROW[k])
const E_TARGET = num("effort_target")
const HTM_TARGET = V3 ? hfcs_target("htm_model_narrow_total") : num("htm_target")
const LIQ_TARGET = V3 ? hfcs_target("liquid_kvw_to_disposable_income_ratio_of_medians") : NaN
const MPC_DATA = V3 ? hfcs_target("mpc_mean") : NaN
# The dispersion of the income process (the standard deviation eta of the
# innovation to its persistent part) is fitted in version 3 to the official
# income quintile share ratio of people under 65; in-work poverty is the check.
function incdist(ind; year = "2021")
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "validation", "income_distribution.csv"))
        f = split(ln, ","); length(f) >= 4 && f[1] == ind && f[2] == CODE && f[3] == year && return parse(Float64, f[4])
    end
    error("no $ind for $CODE in $year")
end
const S8020_TARGET = V3 ? incdist("s80s20_under65") : NaN
const INWORK_DATA = V3 ? incdist("inwork_poverty60") : NaN
const S8020_TOL = 0.25
const ETA = Ref(NaN)
const FL = Ref(0.0)              # the floor, as a share of a year's reference earnings (cfloor = FL e_ref)
const BGAP = Ref(0.0)            # patience of the lower-education cell below the other's
function hfcs_group(moment, group, sub; wave = "2021")
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        f = split(ln, ",")
        length(f) >= 6 && f[1] == moment && f[2] == CODE && f[3] == wave && f[4] == group && f[5] == sub && return parse(Float64, f[6])
    end
    error("no HFCS target $moment for $CODE, $group, $sub")
end
const HGAP_TARGET = EDUREG ? hfcs_group("htm_model_narrow_total", "education", "below tertiary") - hfcs_group("htm_model_narrow_total", "education", "tertiary") : NaN
const HGAP_TOL = 0.03
# the sampling standard errors of the HFCS moments (column 7 of data/hfcs_targets.csv), the weights of version 4
function hfcs_se(moment, group = "all", sub = "all"; wave = "2021")
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        f = split(ln, ",")
        length(f) >= 7 && f[1] == moment && f[2] == CODE && f[3] == wave && f[4] == group && f[5] == sub && return parse(Float64, f[7])
    end
    error("no HFCS standard error for $moment, $CODE, $group, $sub")
end
const SE_HTM = V4 ? hfcs_se("htm_model_narrow_total") : NaN
const SE_LIQ = V4 ? hfcs_se("liquid_kvw_to_disposable_income_ratio_of_medians") : NaN
const SE_MPC = V4 ? hfcs_se("mpc_mean") : NaN
const SE_GAP = V4 ? sqrt(hfcs_se("htm_model_narrow_total", "education", "below tertiary")^2 + hfcs_se("htm_model_narrow_total", "education", "tertiary")^2) : NaN
const E_REF_C = V3 ? num("e_ref") : NaN
v3kw() = V3 && !isnan(ETA[]) ? merge(V4 ? (perm_sd = ETA[],) : (eta_z = ETA[],), FLOORREG ? (cfloor = FL[] * E_REF_C,) : (;), EDUREG ? (beta_cell = (-BGAP[], 0.0),) : (;),
                                     isnan(RHO_TRIAL) ? (;) : (rho = RHO_TRIAL,), isnan(SDEPS_TRIAL) ? (;) : (sd_eps = SDEPS_TRIAL,)) : ()
if FLOORREG
    if CFG == FLOOR_CFG
        FL[] = 0.10                 # where the search for the floor starts (a configuration with places starts from the same one without)
    else
        fg = joinpath(@__DIR__, "calibration_$(VTAG)_$(CODE)_$(FLOOR_CFG).txt")
        isfile(fg) || error("the floor regime needs the country's $(FLOOR_CFG) calibration first: $(basename(fg)) is missing")
        for l in eachline(fg)
            startswith(strip(l), "cfloor") && (FL[] = parse(Float64, last(split(l, "="))) / E_REF_C)
        end
    end
end
const PART = (num("part_low"), num("part_high"))
const RATIO = num("ratio")
# The national ratio exactly, and for the headline configuration the other
# national figures in the data as a sensitivity.
const RATIOS = CFG == "GSA" ? vcat(RATIO, [x for x in (0.486, 0.574, 0.857, 0.937) if abs(x - RATIO) > 0.002]) : [RATIO]
# TARGET OWNERSHIP (2026-09-28). A configuration is fitted only to the targets
# its switches own. The participation gap between the education cells comes from
# S and A together: capability is what separates the cells, and with A off the
# only lever left is social feedback, which France G+S could use only by pushing
# the multiplier to 38, next to the loss of a unique equilibrium. So G+S fits
# overall participation alone and reports the gap as untargeted. The taste
# dispersion sigma, which the gap pins down, is held at the country's G+S+A
# value (the unemployed ratio cannot pin it: it is imposed as a rule, and
# probe_gs_identification.jl shows what it does when it is not).
const OWN_GAP = A_ON
const AGG_TOL = 0.005
const LOSS_STD = OWN_GAP ? 0.035 : AGG_TOL
# STABILITY GATE. The calibrated equilibrium must sit away from a fold: a
# multiplier 1/(1 - slope) of at most 5, a map slope of at most 0.8. A numerical
# rule, not an estimate; the calibrated G+S+A economies sit at 1.3 to 1.9.
const MULT_MAX = 5.0
const CELLS0 = cells_of(country_config(CODE; v3 = V3ARG, config = "GSA", S = true, A = A_ON, missing_ok = true))   # the data table only
const AGG = CELLS0[1].share * PART[1] + CELLS0[2].share * PART[2]
const SIGMA_FIX = (OWN_GAP || !S_ON) ? NaN : country_config(CODE; v3 = V3ARG, config = E_ON ? "GSAE" : "GSA", E = E_ON).sigma_m

# How much switching cohesion on raises hand-to-mouth, used to aim the
# cohesion-off fit. G+S+A: France on EU-SILC, 0.2804 with cohesion against 0.2512
# without (calibrate_country_FR.txt, 2026-09-23). The INSEE footing's gap, 0.046,
# came from a multiplier of 21 and overshot by 0.02 at the EU-SILC multiplier of 2.
# G+S: still the INSEE-footing value; the correction step covers any miss.
# 2026-09-25: the target is now poor hand-to-mouth on the Kaplan, Violante and
# Weidner definition (hand_to_mouth_kvw), and how much cohesion adds to it is not
# yet known, so the aim starts at the target and the one correction measures it.
const GAP = 0.0
# Switching S on must still hit the G targets, so hand-to-mouth gets one
# correction when it misses by more than this.
const HTM_TOL = V3 ? 0.02 : 0.005   # v2: the poor hand-to-mouth targets are 0.03 to 0.14; v3: the total share, 0.18 to 0.23
# v3, liquid wealth over income. The hand-to-mouth share OWNS the patience parameters: the MPC rests on it,
# and it is the moment the calibration was agreed to hit. Median liquid wealth stays in the fit at a low
# weight (its band is 4.5 times the hand-to-mouth band) and is REPORTED with its miss, not required.
# Why, from the grids of 2026-10-03 (V3_START.md, section 16):
#  - both moments required at fixed bands (0.02, 0.03): France calibrates; Germany sits at spread 0 with both
#    too high (0.255 against 0.225, 0.18 against 0.14), Italy at spread 0.15 with both too low;
#  - bands of two standard errors of the survey with a floor (run 37140582030): none of the six German and
#    Italian configurations calibrates (Italy: liquid wealth inside, hand-to-mouth 0.11 against 0.18);
#  - income persistence as a fifth fitted parameter (commit 9e9175a, Germany G on the laptop): the fit stalls
#    at the same place; persistence is close to collinear with patience in France and Italy
#    (probe_wealth_shape.jl), so it was taken out again.
# One patience distribution over one asset does not give both moments in Germany and Italy. That is the
# wealthy hand-to-mouth, and the two-asset model's job.
const LIQ_TOL = 0.09
const E_TOL = 0.005          # effort
const SKIP_GS = get(ENV, "SKIP_GS", "0") == "1"
const OUTFILE = V3 ? joinpath(@__DIR__, "calibration_$(VTAG)_$(CODE)_$(CFG).txt") :
                joinpath(@__DIR__, CFG == "GSA" ? "calibration_country_$(CODE).txt" :
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
const CKKEY = bytes2hex(sha1(string(sort(collect(ROW)), "|", CFG, "|", GAP, "|", SOLVER_DIGEST, V3 ? "|$(VTAG)|$(HTM_TARGET)|$(LIQ_TARGET)|$(S8020_TARGET)" : "")))[1:16]
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

V3 && say("VERSION 3: liquid wealth over income target ", LIQ_TARGET, " | self-reported MPC in the survey ", MPC_DATA, " (not targeted)")
say("calibrating ", CODE, " ", CFG, " | effort target ", E_TARGET, " | hand-to-mouth target ", HTM_TARGET,
    S_ON ? " | participation targets $(PART) | national ratio $(RATIO)" : "", " | workers ", nworkers())
t_start = time()
# TIME BUDGET (2026-09-29). With SAGE_TIME_BUDGET_MIN set, the run stops before
# a families-and-scan stage that would not finish inside the budget, with exit
# code 3. The stage checkpoints above (stage 1, each correction) and the family
# cache let the next job resume; the workflow starts it.
const BUDGET = parse(Float64, get(ENV, "SAGE_TIME_BUDGET_MIN", "Inf"))
const LASTSCAN = Ref(30.0)
function budget_check(tag; factor = 1.3)
    used = (time() - t_start) / 60
    if used + factor * LASTSCAN[] > BUDGET
        say(@sprintf("\nTIME BUDGET: %.0f of %.0f minutes used before %s; checkpoints kept, to resume in a new job.", used, BUDGET, tag))
        exit(3)
    end
end
timed_scans(args...; kw...) = (t_ = time(); out = scans(args...; kw...); LASTSCAN[] = (time() - t_) / 60 + 5; out)

function write_cal(phi, spread; kappa = nothing, sigma = nothing)
    open(OUTFILE, "w") do io
        println(io, "# written by calibrate_country.jl $(CODE) $(CFG)", V3 ? ", version 3 (effort set by the job, household replacement rate, liquid-wealth targets from the HFCS)" : "", "; read by country_config")
        V3 ? @printf(io, "phi = %.3f\nbeta_spread = %.4f\nbeta_bar = %.4f\n%s = %.4f\n%s", phi, spread, BB[], V4 ? "perm_sd" : "eta_z", ETA[], (FLOORREG ? @sprintf("cfloor = %.6f\n", FL[] * E_REF_C) : "") * (EDUREG ? @sprintf("beta_gap = %.4f\n", BGAP[]) : "")) :
             @printf(io, "phi = %.2f\nbeta_spread = %.3f\nbeta_bar = %.4f\n", phi, spread, BB[])
        kappa === nothing || @printf(io, "kappa = %.2f\nsigma_m = %.2f\n", kappa, sigma)
    end
    isfile(NOTCAL) && rm(NOTCAL)
    say("wrote ", basename(OUTFILE))
end

# ------------------------------------------------------------- 0. preflight --
let fr = SAGEConfig(A = true, unemployment = true, beta_spread = 0.037, unemployed_ratio = 0.17 / 0.35),
    r = _solve(fr, nothing; disk = true)
    gap = max(abs(r.mean_effort_employed - 0.559130), abs(r.hand_to_mouth - 0.261599), abs(r.median_income - 0.376010))
    # The reference numbers are the grid solver's; the EGM solver is held to the
    # grid solver's discretisation error (euler_errors.jl).
    ptol = DEFAULT_SOLVER === :grid ? 1e-6 : 5e-3
    @printf("preflight, France G+A through the parallel path (solver %s): worst gap %.1e against the suite: %s\n",
            DEFAULT_SOLVER, gap, gap < ptol ? "HELD" : "FAILED")
    flush(stdout)
    gap < ptol || exit(4)      # not 3: that is the time budget, which the workflow answers by resuming
end

# --------------------------------------------------- 1. effort and spread --
# Average patience. The spread lowers patience below 0.96 for part of the
# population and so raises hand-to-mouth. A target below what equal patience
# delivers is reached instead by raising average patience, with no spread,
# up to the model's stationarity limit (beta times R below 0.995).
const BB = Ref(0.96)
# one pass without thresholds for E off (as before); with E on, the full place solve
_solve_any(cc, thr = nothing; disk = true) = E_ON ? solve_economy(cc) : _solve(cc, thr; disk = disk)
cfg_off(phi, sp) = country_config(CODE; v3 = V3ARG, config = CFG, missing_ok = true, v3kw()..., S = false, A = A_ON, E = E_ON, phi = phi, beta_spread = sp, beta_bar = BB[])
soff(phi, sp) = _solve_any(country_config(CODE; v3 = V3ARG, config = CFG, missing_ok = true, v3kw()..., S = false, A = A_ON, E = E_ON, phi = phi, beta_spread = sp,
                                      beta_bar = BB[]), nothing; disk = true)
function fit_phi(sp; lo = 0.5, hi = 40.0, steps = 14, aim = E_TARGET)   # lo was 3.0: Italy's effort target needs less
    for _ in 1:steps
        mid = 0.5 * (lo + hi)
        soff(mid, sp).mean_effort_employed > aim ? (lo = mid) : (hi = mid)
    end
    round(0.5 * (lo + hi); digits = 2)
end
# One search bound on the discount spread for every stage. Types run from
# beta_bar - spread up to beta_bar, so at 0.15 the most impatient type has an
# annual discount factor of 0.81. A search limit, not an economic claim. It was
# 0.115, but stage 1's refinement went past it (Italy G at 0.129) while the
# correction could not, which left Italy G+S unable to reach its own G target.
const SPREAD_MAX = 0.15
function fit_spread(phi, target; grid = 0.0:0.005:SPREAD_MAX)
    BB[] = 0.96
    hs = [soff(phi, sp).hand_to_mouth_kvw for sp in grid]
    k = findfirst(>=(target), hs)
    k === nothing && return (sp = grid[end], bb = 0.96, edge = true)
    if k > 1 || grid[1] > 0
        k == 1 && return fit_spread(phi, target)          # refined grid started too high
        t = (target - hs[k-1]) / (hs[k] - hs[k-1])
        return (sp = round(grid[k-1] + t * (grid[k] - grid[k-1]); digits = 3), bb = 0.96, edge = false)
    end
    lo, hi = 0.96, 0.975
    BB[] = hi; top = soff(phi, 0.0).hand_to_mouth_kvw
    top > target && return (sp = 0.0, bb = hi, edge = true)
    for _ in 1:10
        BB[] = 0.5 * (lo + hi)
        soff(phi, 0.0).hand_to_mouth_kvw > target ? (lo = BB[]) : (hi = BB[])
    end
    (sp = 0.0, bb = round(0.5 * (lo + hi); digits = 4), edge = false)
end
"""
Version 3, the three G parameters by damped least squares: (log phi, top
patience, spread) against (effort, liquid wealth over income, hand-to-mouth),
each miss in units of its tolerance. Top patience stays below 0.975 (beta R
below one for the most patient type). Returns the point and its moments.
"""
function fit_v3(aim_e, aim_h; x0 = [log(7.5), FLOORREG ? 0.93 : 0.90, 0.01, 0.22, FL[]], iters = 16, tag = "fit3")
    # fifth parameter: the floor's level. Free in G of the floor regime (0 to 0.30 of reference earnings),
    # fixed elsewhere (at zero without the regime). In the floor regime patience has no spread.
    flfree = FLOORREG && CFG == FLOOR_CFG
    # sixth parameter: the patience gap between the education cells, free in the education regime
    length(x0) == 5 && (x0 = vcat(x0, EDUREG ? max(BGAP[], 0.03) : 0.0))
    nospread = FLOORREG || EDUREG
    gapfree = EDUREG && !E_ON          # with places the gap is the one found without them (the cells' shares are not kept by place)
    lo = [log(0.5), 0.84, 0.0, 0.05, flfree ? 0.0 : FL[], gapfree ? 0.0 : x0[6]]
    hi = [log(60.0), 0.975, nospread ? 0.0 : SPREAD_MAX, 0.40, flfree ? 0.30 : FL[], gapfree ? 0.14 : x0[6]]
    H = [0.05, 0.004, 0.01, 0.02, 0.02, 0.01]; np = 6; nm = V4 ? 6 : 5
    # version 4: the income process is the published one. The fourth parameter is the dispersion of the
    # permanent component of income (no risk), which S80/S20 identifies; the floor is free wherever
    # it is fitted, with liquid wealth in the criterion at its standard error
    V4 && (lo[4] = 0.0; hi[4] = 1.2; H[4] = 0.05)
    # A point where the economy has no solution (a floor that cannot be financed: Italy at 0.35,
    # 2026-10-04) is not an error of the fit: it is a point to step away from.
    function at(x)
        BB[] = x[2]; ETA[] = x[4]; FL[] = x[5]; BGAP[] = x[6]
        try
            r = soff(exp(x[1]), x[3]); st = income_stats(cfg_off(exp(x[1]), x[3]))
            hc = (hasproperty(r, :pooled) && hasproperty(r.pooled[1], :hmass)) ? [sum(r.pooled[g].hmass) / sum(r.pooled[g].mass) for g in 1:2] : [NaN, NaN]   # not kept with places
            m = [r.mean_effort_employed, r.wealth_p50 / r.median_income, r.hand_to_mouth_kvw, st.s8020, hc[1] - hc[2]]
            V4 && push!(m, r.mpc)
            return (r = r, st = st, m = m, ok = true)
        catch err
            say("    no solution at floor ", round(x[5]; digits = 4), ", patience ", round(x[2]; digits = 4), ": ", first(replace(sprint(showerror, err), "\n" => " "), 160))
            return (r = nothing, st = nothing, m = fill(NaN, nm), ok = false)
        end
    end
    liqtol = Ref(flfree ? 0.03 : LIQ_TOL)          # the floor owns liquid wealth in G
    # EVERY EVALUATION KEPT (2026-10-08). With places, a floor and three types of household per cell one
    # step of the fit (the point, a column per free parameter, the trial steps) did not fit in a job:
    # Italy G+E of version 4 was cancelled at the six-hour limit inside its first step with nothing
    # kept. The moments of every point evaluated are appended to a checkpoint file, a resumed job reads
    # them back, and the run hands over before an evaluation that would not finish inside the budget.
    memo = Dict{String,Tuple{Bool,Vector{Float64}}}(); mfile = ckfile(tag * "_evals"); leval = Ref(0.0)
    if isfile(mfile)
        for ln in eachline(mfile)
            q = split(ln, "|"); length(q) == 3 || continue
            memo[q[1]] = (q[2] == "1", [parse(Float64, v) for v in split(q[3], ",")])
        end
        isempty(memo) || say("    ", length(memo), " evaluations of the fit read from the checkpoint")
    end
    function atm(x)
        key = join((@sprintf("%.10g", v) for v in x), ",")
        haskey(memo, key) && (e = memo[key]; return (r = nothing, st = nothing, m = e[2], ok = e[1]))
        leval[] > 0 && (time() - t_start) / 60 + 1.3 * leval[] > BUDGET &&
            (say(@sprintf("\nTIME BUDGET: %.0f of %.0f minutes used inside the fit, %d evaluations kept; to resume in a new job.",
                          (time() - t_start) / 60, BUDGET, length(memo))); exit(3))
        t_ = time(); o_ = at(x); leval[] = max(leval[], (time() - t_) / 60)
        memo[key] = (o_.ok, o_.m)
        open(io -> println(io, key, "|", o_.ok ? 1 : 0, "|", join((@sprintf("%.12g", v) for v in o_.m), ",")), mfile, "a")
        o_
    end
    # the fifth moment, the gap in the hand-to-mouth share between the cells, counts in the education regime only
    res(o) = V4 ? (r_ = (o.m .- [aim_e, LIQ_TARGET, aim_h, S8020_TARGET, HGAP_TARGET, MPC_DATA]) ./ [E_TOL, SE_LIQ, SE_HTM, 0.05, SE_GAP, SE_MPC];
                   gapfree || (r_[5] = 0.0); r_) :          # version 4: in standard errors; effort and S80/S20, which have none, to a numerical tolerance
             (r_ = (o.m .- [aim_e, LIQ_TARGET, aim_h, S8020_TARGET, EDUREG ? HGAP_TARGET : 0.0]) ./ [E_TOL, liqtol[], HTM_TOL, S8020_TOL, HGAP_TOL];
              gapfree || (r_[5] = 0.0); r_)
    # Resumable: with places on, one step of the fit takes half an hour on a runner and sixteen
    # do not fit in a job (France, Italy and Germany with E, 2026-10-04: cancelled at the six-hour
    # limit with nothing kept). The point is checkpointed after every step.
    ckf = ck_read(tag); it0 = 1
    x = clamp.(x0, lo, hi); lam = 0.1
    if ckf !== nothing
        x = [ckf["x1"], ckf["x2"], ckf["x3"], ckf["x4"], get(ckf, "x5", FL[]), get(ckf, "x6", BGAP[])]; lam = ckf["lam"]; it0 = Int(ckf["it"]) + 1
        get(ckf, "nofloor", 0.0) == 1.0 && (flfree = false; lo[5] = hi[5] = 0.0; liqtol[] = LIQ_TOL)
        say("    fit resumed after step ", it0 - 1)
    end
    o = atm(x)
    while !o.ok && x[5] > lo[5]          # a start with no solution: halve the floor
        x[5] = max(lo[5], x[5] / 2 - 1e-3); o = atm(x)
    end
    o.ok || error("the fit's starting point has no solution")
    F = res(o); tfit = time(); nstep = 0
    owned(F) = V4 ? maximum(abs.(F)) : maximum(abs.(flfree ? F : F[[1, 3, 4, 5]]))          # effort, hand-to-mouth, S80/S20, the gap by education (zero outside its regime); liquid wealth too where the floor is fitted; version 4: every moment of the criterion
    for it in it0:iters
        # Liquid wealth is not required and often cannot be reached, so the stop is on the moments
        # the calibration owns; until 2026-10-04 it was on all four and the fit ran its sixteen
        # steps without moving (Germany: misses 0.05, 0.61, 0.26, 0.01 from step 14 to 16).
        owned(F) <= 0.25 && break
        # The floor at zero and the wealth moments still apart: the country needs no floor (Germany,
        # whose minimum income is already inside the replacement rate). The fit goes on as without
        # the regime's extra target: the hand-to-mouth share owns patience, liquid wealth is reported.
        if flfree && x[5] <= 1e-3 && it > it0
            flfree = false; x[5] = 0.0; lo[5] = hi[5] = 0.0; liqtol[] = LIQ_TOL; F = res(o)
            say("    the floor is at zero: fitting on without it", V4 ? "" : ", liquid wealth reported")
            owned(F) <= 0.25 && break
        end
        nstep > 0 && (time() - t_start) / 60 + 1.5 * (time() - tfit) / 60 / nstep > BUDGET &&
            (say(@sprintf("\nTIME BUDGET: %.0f of %.0f minutes used inside the fit, after step %d; checkpoint kept, to resume in a new job.",
                          (time() - t_start) / 60, BUDGET, it - 1)); exit(3))
        ss0 = sum(abs2, F)
        J = zeros(nm, np)
        for k in 1:np
            hi[k] - lo[k] < 1e-12 && continue          # a fixed parameter: no column, no solve
            xk = copy(x); h = (xk[k] + H[k] > hi[k]) ? -H[k] : H[k]; xk[k] += h
            ok_ = atm(xk)
            if !ok_.ok && x[k] - H[k] >= lo[k]          # no solution on that side: the other
                xk = copy(x); h = -H[k]; xk[k] += h; ok_ = atm(xk)
            end
            ok_.ok && (J[:, k] = (res(ok_) .- F) ./ h)
        end
        moved = false
        for _ in 1:6
            A = J' * J; d = -((A + lam * Diagonal(diag(A)) + 1e-10 * I) \ (J' * F))
            xn = clamp.(x .+ d, lo, hi); on = atm(xn); Fn = res(on)
            if on.ok && sum(abs2, Fn) < sum(abs2, F) - 1e-6
                x = xn; o = on; F = Fn; lam = max(lam / 3, 1e-4); moved = true; break
            end
            lam *= 4
        end
        FLOORREG && @printf("    floor %.4f of reference earnings\n", x[5])
        EDUREG && @printf("    patience gap %.4f | hand-to-mouth, below tertiary less tertiary %.4f (HFCS %.4f), %+.2f bands\n", x[6], o.m[5], HGAP_TARGET, F[5])
        V4 ? @printf("    fit %2d: phi %.3f, top patience %.4f, permanent sd %.4f | effort %.4f, liquid/income %.4f, hand-to-mouth %.4f, MPC %.4f, S80/S20 %.2f | misses in standard errors: liquid %+.2f, hand-to-mouth %+.2f, by education %+.2f, MPC %+.2f | criterion %.2f\n",
                     it, exp(x[1]), x[2], x[4], o.m[1], o.m[2], o.m[3], o.m[6], o.m[4], F[2], F[3], F[5], F[6], sum(abs2, F)) :
        @printf("    fit %2d: phi %.3f, top patience %.4f, spread %.4f, eta %.4f | effort %.4f, liquid/income %.4f, hand-to-mouth %.4f, S80/S20 %.2f | misses in bands %+.2f %+.2f %+.2f %+.2f\n",
                it, exp(x[1]), x[2], x[3], x[4], o.m[1:4]..., F[1:4]...); flush(stdout)
        nstep += 1
        ck_write(tag, Dict("x1" => x[1], "x2" => x[2], "x3" => x[3], "x4" => x[4], "x5" => x[5], "x6" => x[6], "lam" => lam, "it" => Float64(it),
                           "nofloor" => (FLOORREG && CFG == FLOOR_CFG && !flfree) ? 1.0 : 0.0))
        moved || (flfree && x[5] <= 1e-3) || break
        sum(abs2, F) > 0.98 * ss0 && (V4 || owned(F) <= 1.0) && break          # no longer improving, owned moments inside their bands (version 4: the criterion is at its minimum)
    end
    xr = [log(round(exp(x[1]); digits = 3)), round(x[2]; digits = 4), round(x[3]; digits = 4), round(x[4]; digits = 4), round(x[5]; digits = 4), round(x[6]; digits = 4)]
    o = at(xr); o.ok || error("the fitted point has no solution after rounding")
    EDUREG && @printf("  hand-to-mouth by education: below tertiary less tertiary %.4f (HFCS %.4f) with a patience gap of %.4f\n", o.m[5], HGAP_TARGET, xr[6])
    if V4
        Fr = res(o)
        @printf("  version 4, the criterion at its minimum: %.2f over %d moments and %d free parameters | misses in standard errors: effort (band) %+.2f, liquid wealth %+.2f, hand-to-mouth %+.2f, by education %+.2f, MPC %+.2f\n",
                sum(abs2, Fr), count(!=(0.0), Fr), count(k -> hi[k] - lo[k] > 1e-12, 1:np), Fr[1], Fr[2], Fr[3], Fr[5], Fr[6])
        @printf("  version 4, moments: hand-to-mouth %.4f (HFCS %.4f, s.e. %.4f) | liquid wealth over income %.4f (%.4f, %.4f) | MPC %.4f (%.4f, %.4f) | S80/S20 %.2f (official %.2f) with a permanent sd of %.4f\n",
                o.m[3], HTM_TARGET, SE_HTM, o.m[2], LIQ_TARGET, SE_LIQ, o.m[6], MPC_DATA, SE_MPC, o.m[4], S8020_TARGET, xr[4])
    end
    (phi = exp(xr[1]), bb = xr[2], sp = xr[3], eta = xr[4], fl = xr[5], gap = xr[6], r = o.r, st = o.st)
end
say("\n1. effort scale and discount spread, cohesion off, hand-to-mouth aim ", round(HTM_TARGET - GAP; digits = 4))
ck1 = ck_read("stage1")
if ck1 === nothing && V3
    # with E on, start at the calibration of the same configuration without places, which is close:
    # the place layer keeps the national means of what it distributes
    x0e = nothing
    if E_ON
        fb = joinpath(@__DIR__, "calibration_$(VTAG)_$(CODE)_$(replace(CFG, "E" => "")).txt")
        if isfile(fb)
            kv = Dict(strip(first(split(l, "="))) => parse(Float64, last(split(l, "="))) for l in eachline(fb) if occursin("=", l) && !startswith(l, "#"))
            x0e = [log(kv["phi"]), kv["beta_bar"], kv["beta_spread"], kv[V4 ? "perm_sd" : "eta_z"],
                   CFG == FLOOR_CFG ? get(kv, "cfloor", FL[] * E_REF_C) / E_REF_C : FL[], get(kv, "beta_gap", 0.0)]
            say("  starting from ", basename(fb))
        end
    end
    if x0e === nothing && TRANS
        # start at the calibration of the same configuration without the transitory part, patience a
        # little lower (the refit of section 28 found 0.02 to 0.03)
        fb = joinpath(@__DIR__, "calibration_$(VTAG0)_$(CODE)_$(CFG).txt")
        if isfile(fb)
            kv = Dict(strip(first(split(l, "="))) => parse(Float64, last(split(l, "="))) for l in eachline(fb) if occursin("=", l) && !startswith(l, "#"))
            # at a trial persistence the innovation starts where the variance of log income is the file's
            # (the table's persistence is 0.92 in the three countries)
            e0 = V4 ? 0.30 : isnan(RHO_TRIAL) ? kv["eta_z"] : clamp(kv["eta_z"] * sqrt((1 - RHO_TRIAL^2) / (1 - 0.92^2)), 0.06, 0.39)          # version 4: where the search for the permanent dispersion starts
            x0e = [log(kv["phi"]), kv["beta_bar"] - ((V4 || !isnan(RHO_TRIAL)) ? 0.0 : 0.02), kv["beta_spread"], e0,
                   CFG == FLOOR_CFG ? get(kv, "cfloor", FL[] * E_REF_C) / E_REF_C : FL[], get(kv, "beta_gap", 0.0)]
            say("  starting from ", basename(fb), isnan(RHO_TRIAL) ? ", patience 0.02 lower" : ", the persistent innovation rescaled to the trial persistence")
        end
    end
    f3 = x0e === nothing ? fit_v3(E_TARGET, HTM_TARGET - GAP) : fit_v3(E_TARGET, HTM_TARGET - GAP; x0 = x0e)
    phi = f3.phi; spread = f3.sp; BB[] = f3.bb; ETA[] = f3.eta; FL[] = f3.fl; BGAP[] = f3.gap; edge = false
    chk_e, chk_h = f3.r.mean_effort_employed, f3.r.hand_to_mouth_kvw
    ck_write("stage1", Dict("phi" => phi, "spread" => spread, "edge" => 0.0, "effort" => chk_e, "htm" => chk_h, "bb" => BB[], "eta" => ETA[], "fl" => FL[], "gap" => BGAP[]))
    @printf("  income distribution: S80/S20 %.2f (official, under 65: %.2f) with eta %.4f | Gini %.3f | in-work poverty %.3f untargeted (official %.3f) | below half the median %.3f\n",
            f3.st.s8020, S8020_TARGET, ETA[], f3.st.gini, f3.st.inwork60, INWORK_DATA, f3.st.p50)
    @printf("  version 3 fit: liquid wealth over income %.4f (target %.4f, band %.2f) | MPC %.3f untargeted (survey %.3f) | earnings response %+.4f | drop on job loss %.3f\n",
            f3.r.wealth_p50 / f3.r.median_income, LIQ_TARGET, LIQ_TOL, f3.r.mpc, MPC_DATA, f3.r.mpe, f3.r.consumption_drop)
elseif ck1 === nothing
    phi = fit_phi(0.037)
    fs = fit_spread(phi, HTM_TARGET - GAP)
    BB[] = fs.bb
    phi = fit_phi(fs.sp; lo = max(0.5, phi - 4), hi = phi + 4, steps = 8)
    fs = fit_spread(phi, HTM_TARGET - GAP;
                    grid = fs.bb == 0.96 && fs.sp > 0 ? (max(0.0, fs.sp - 0.015):0.005:min(SPREAD_MAX, fs.sp + 0.015)) : (0.0:0.005:0.10))
    spread = fs.sp; edge = fs.edge; BB[] = fs.bb
    chk = soff(phi, spread)
    chk_e, chk_h = chk.mean_effort_employed, chk.hand_to_mouth_kvw
    ck_write("stage1", Dict("phi" => phi, "spread" => spread, "edge" => Float64(edge),
                            "effort" => chk_e, "htm" => chk_h, "bb" => BB[]))
else
    phi, spread, edge = ck1["phi"], ck1["spread"], ck1["edge"] == 1.0
    chk_e, chk_h = ck1["effort"], ck1["htm"]; BB[] = get(ck1, "bb", 0.96); V3 && (ETA[] = ck1["eta"]; FL[] = get(ck1, "fl", FL[]); BGAP[] = get(ck1, "gap", BGAP[]))
    say("  from checkpoint ", basename(ckfile("stage1")))
end
@printf("  phi %.2f, spread %.3f, mean patience %.4f%s: effort %.4f (target %.4f), poor hand-to-mouth %.4f (aim %.4f)  [%.1f min]\n",
        phi, spread, BB[], edge ? " (ON THE GRID EDGE)" : "", chk_e, E_TARGET,
        chk_h, HTM_TARGET - GAP, (time() - t_start) / 60)
flush(stdout)

# If no discount spread on the grid brings hand-to-mouth near its aim, nothing
# downstream can: families, scans and the one correction all take the spread as
# given. So record the configuration as not calibrated here rather than spend
# hours on it. First seen for the US, whose benefit runs out after five months
# (twelve-month replacement 0.13): hand-to-mouth 0.019 at spread 0.115 against
# an aim of 0.281.
# 2026-09-28: the allowance was max(0.01, a quarter of the aim), which let
# Italy through at 0.066 against 0.083. Every configuration must hit its G
# targets, so the standard is now the promised tolerance.
if edge && abs(chk_h - (HTM_TARGET - GAP)) > HTM_TOL
    say(@sprintf("\nNOT CALIBRATED: hand-to-mouth reaches only %.4f at the largest spread tried (%.3f), against an aim of %.4f. No calibration file written.",
                 chk_h, spread, HTM_TARGET - GAP))
    mark_not_calibrated(); exit(2)
end

if !S_ON
    say("\n2. the ", CFG, " economy on its own thresholds")
    r = solve_economy(country_config(CODE; v3 = V3ARG, config = CFG, missing_ok = true, v3kw()..., S = false, A = A_ON, E = E_ON, phi = phi, beta_spread = spread,
                                     beta_bar = BB[]))
    @printf("  participation %.4f | agency %.4f | hardship %.4f | hand-to-mouth %.4f (target %.2f) | effort %.4f (target %.4f) | median %.4f\n",
            r.rate, r.A, r.hardship, r.hand_to_mouth_kvw, HTM_TARGET, r.mean_effort_employed, E_TARGET, r.median_income)
    @printf("  expected loss to unemployment %.4f (income alone %.4f) | drop on job loss %.4f | agency on the old hardship reading %.4f\n",
            r.shock_loss, r.shock_loss_income, r.consumption_drop, r.A_hardship)
    V3 && @printf("  version 3, untargeted: MPC %.3f (survey %.3f), of the hand-to-mouth %.3f, earnings response %+.4f | liquid wealth over income %.4f (HFCS %.4f) | protection if hit %.4f | income poverty %.4f\n",
                  r.mpc, MPC_DATA, hasproperty(r, :mpc_htm) ? r.mpc_htm : NaN, r.mpe, r.wealth_p50 / r.median_income, LIQ_TARGET, r.A_cond, r.income_poor)
    if (!V4 && abs(r.hand_to_mouth_kvw - HTM_TARGET) > HTM_TOL) || abs(r.mean_effort_employed - E_TARGET) > E_TOL
        say(@sprintf("\nNOT CALIBRATED: hand-to-mouth %.4f (target %.4f) or effort %.4f (target %.4f) outside tolerance. No calibration file written.",
                     r.hand_to_mouth_kvw, HTM_TARGET, r.mean_effort_employed, E_TARGET))
        mark_not_calibrated(); exit(2)
    end
    write_cal(phi, spread)
    @printf("\nDONE %s %s in %.1f min\n", CODE, CFG, (time() - t_start) / 60)
    exit(0)
end

# ------------------------------------------- 2 and 3. families and scans --
const SIGMAS = 0.30:0.02:3.00      # to 3.0: the band's lower end sat at 1.5 (2026-09-27)
const KAPPAS = 2.0:0.05:25.0
# With E on: families for every place, then the place-aware scan on a global
# coarse grid (sigma step 0.06, kappa step 0.1) and a refinement around its best
# point (steps 0.02 and 0.05). The kappa search stays global at every sigma.
function scans_places(c)
    c0 = SAGEConfig(c; E = false)
    places, w = places_from_data(CODE, c0; typology = c.typology, channels = c.e_channels, epsilon = c.epsilon)
    cps = [place_config(c0, pl, national_tax(c0, places, w)) for pl in places]
    t0 = time()
    raws = [collect(build_families(cp, nothing; disk = true)) for cp in cps]
    @printf("  families for %d places built or loaded in %.1f min\n", length(cps), (time() - t0) / 60); flush(stdout)
    fis = [[impose_unemployed_ratio(f, employment_mask(cps[i]), RATIO) for f in raws[i]] for i in eachindex(cps)]
    cpr = [SAGEConfig(cp; unemployed_ratio = RATIO) for cp in cps]
    kw = OWN_GAP ? (targets = PART,) : (aggregate = AGG,)
    sig = OWN_GAP ? collect(0.30:0.06:3.00) : [SIGMA_FIX]
    rows = scan_technology_places(cpr, fis, w, sig, collect(2.0:0.1:25.0); kw..., max_mult = MULT_MAX)
    if isempty(rows)
        @printf("  no stable equilibrium with a multiplier of at most %.0f anywhere on the grid\n", MULT_MAX)
        return Dict(RATIO => nothing)
    end
    b0 = rows[argmin([x.loss for x in rows])]
    sig2 = OWN_GAP ? collect(max(0.30, b0.σ - 0.06):0.02:min(3.00, b0.σ + 0.06)) : [SIGMA_FIX]
    rows2 = scan_technology_places(cpr, fis, w, sig2, collect(max(2.0, b0.κ - 0.2):0.05:min(25.0, b0.κ + 0.2)); kw..., max_mult = MULT_MAX)
    allr = vcat(rows, rows2)
    best = allr[argmin([x.loss for x in allr])]
    ok = [x for x in allr if x.loss <= LOSS_STD]
    @printf("  places (%d): best kappa %.2f sigma %.2f, root loss %.4f, rate %.4f, multiplier %.1f", length(cps), best.κ, best.σ, best.loss, best.r, best.mult)
    isempty(ok) ? @printf(" | nothing within %.3f\n", LOSS_STD) :
        @printf(" | within %.3f: multiplier %.1f to %.1f\n", LOSS_STD, minimum(x.mult for x in ok), maximum(x.mult for x in ok))
    flush(stdout)
    Dict(RATIO => (best = best, ok = ok))
end

# COARSE TO FINE (2026-09-28). The search (scans, corrections) runs on half the
# belonging scales; the calibration is then re-scanned and solved once on the
# full grid, and only that economy is checked against the targets and written.
function scans(phi, spread; ugrid = UGRID_COARSE)
    c = country_config(CODE; v3 = V3ARG, config = CFG, missing_ok = true, v3kw()..., S = true, A = A_ON, E = E_ON, phi = phi, beta_spread = spread, beta_bar = BB[],
                       ugrid = ugrid)
    E_ON && return scans_places(c)
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
        sig = OWN_GAP ? collect(SIGMAS) : [SIGMA_FIX]
        kw = OWN_GAP ? (targets = PART,) : (aggregate = AGG,)
        rows = scan_technology(cr, fi, sig, collect(KAPPAS); kw..., max_mult = MULT_MAX, selected_only = true)   # the crossing the economy selects
        # what the gate costs, reported at the national ratio only (a second scan)
        free = ρ == RATIO ? scan_technology(cr, fi, sig, collect(KAPPAS); kw..., selected_only = true) : NamedTuple[]
        if !isempty(free)
            fb = free[argmin([x.loss for x in free])]
            fb.mult > MULT_MAX && @printf("  ratio %.3f: without the stability gate the best fit would be %.4f at multiplier %.1f (kappa %.2f sigma %.2f)\n",
                                          ρ, fb.loss, fb.mult, fb.κ, fb.σ)
        end
        if isempty(rows)
            @printf("  ratio %.3f: no stable equilibrium with a multiplier of at most %.0f anywhere on the grid\n", ρ, MULT_MAX)
            out[ρ] = nothing; continue
        end
        best = rows[argmin([x.loss for x in rows])]
        ok = [x for x in rows if x.loss <= LOSS_STD]
        edge = (best.σ <= first(SIGMAS) || best.σ >= last(SIGMAS) ? " SIGMA ON THE GRID EDGE" : "") *
               (best.κ <= first(KAPPAS) || best.κ >= last(KAPPAS) ? " KAPPA ON THE GRID EDGE" : "")
        @printf("  ratio %.3f%s: best kappa %.2f sigma %.2f, root loss %.4f, rate %.4f, multiplier %.1f%s",
                ρ, ρ == RATIO ? " (national)" : "", best.κ, best.σ, best.loss, best.r, best.mult, edge)
        isempty(ok) ? @printf(" | nothing within %.3f\n", LOSS_STD) :
            @printf(" | within %.3f: sigma %.2f to %.2f, multiplier %.1f to %.1f\n", LOSS_STD,
                    minimum(x.σ for x in ok), maximum(x.σ for x in ok), minimum(x.mult for x in ok), maximum(x.mult for x in ok))
        flush(stdout)
        out[ρ] = (best = best, ok = ok)
    end
    out
end
say("\n2-3. ", CFG, " families and technology scans, ",
    OWN_GAP ? "participation targets $(PART)" :
              @sprintf("overall participation %.4f (the cell gap is not this configuration's target), sigma held at the G+S+A value %.2f", AGG, SIGMA_FIX))
# READY FOR THE FULL GRID (2026-10-07). A job that reaches stage 5b after the coarse scans, the solve
# and the corrections may have too little of its budget left for the full-grid scan, and a resumed
# job repeated all of them before reaching it again (Italy G+S+A+E with places: 151 minutes each
# time, three jobs, never past this point). The parameters the full grid starts from are kept when
# stage 5b is reached, and a job that finds them goes straight there.
const PRE5B = ck_read("pre5b")
if PRE5B !== nothing
    phi = PRE5B["phi"]; spread = PRE5B["spread"]; BB[] = PRE5B["bb"]
    V3 && (ETA[] = PRE5B["eta"]; FL[] = PRE5B["fl"]; BGAP[] = PRE5B["gap"])
    say("  from checkpoint ", basename(ckfile("pre5b")), ": the coarse scans, the solve and the corrections were done in an earlier job")
else
budget_check("the first technology scan")
S = timed_scans(phi, spread)
if S[RATIO] === nothing || S[RATIO].best.loss > LOSS_STD
    say("\nNOT CALIBRATED: at the national ratio the best fit is ", S[RATIO] === nothing ? "absent" :
        @sprintf("%.4f, above the %.3f standard", S[RATIO].best.loss, LOSS_STD), ". No calibration file written.")
    mark_not_calibrated(); exit(2)
end
end

# ------------------------------------------------------ 4 and 5. solve --
function solve_at(phi, spread, best; ugrid = UGRID_COARSE)
    c = country_config(CODE; v3 = V3ARG, config = CFG, missing_ok = true, v3kw()..., S = true, A = A_ON, E = E_ON, phi = phi, beta_spread = spread,
                       beta_bar = BB[], kappa = best.κ, sigma_m = best.σ, ugrid = ugrid)
    t0 = time(); r = solve_economy(c)
    @printf("  %s: participation %.4f (cells %.4f, %.4f against %.3f, %.3f; employed %.4f, unemployed %.4f)\n",
            CFG, r.rate, r.pooled[1].rate, r.pooled[2].rate, PART..., r.rate_E, r.rate_U)
    @printf("         agency %.4f, hardship %.4f, hand-to-mouth %.4f (target %.2f), effort %.4f, multiplier %.1f  [%.1f min]\n",
            r.A, r.hardship, r.hand_to_mouth_kvw, HTM_TARGET, r.mean_effort_employed, 1 / (1 - r.slope), (time() - t0) / 60)
    @printf("         expected loss to unemployment %.4f (income alone %.4f), drop on job loss %.4f, agency on the old hardship reading %.4f\n",
            r.shock_loss, r.shock_loss_income, r.consumption_drop, r.A_hardship)
    V3 && @printf("         version 3, untargeted: MPC %.3f (survey %.3f), earnings response %+.4f | liquid wealth over income %.4f (HFCS %.4f) | protection if hit %.4f | income poverty %.4f\n",
                  r.mpc, MPC_DATA, r.mpe, r.wealth_p50 / r.median_income, LIQ_TARGET, r.A_cond, r.income_poor)
    flush(stdout)
    r
end
if PRE5B === nothing
say("\n4. the calibrated ", CFG, " economy on its own thresholds")
best = S[RATIO].best
r = solve_at(phi, spread, best)
# Cohesion takes time from work and changes saving, so with S on both G targets
# move: effort falls by about 0.01 and hand-to-mouth rises. Each correction
# measures this economy's own gaps against the cohesion-off economy at the same
# parameters and re-fits the effort scale and the discount spread to aims
# shifted by them. A correction runs whenever a target misses by more than half
# its tolerance: the search aims at the centre of the band, so the move from the
# coarse to the full belonging grid (a few 1e-4) cannot push an economy that
# sat at the edge outside it (Italy G+S+A on egm, 2026-09-28: effort inside at
# the coarse grid by 1e-5, outside at the full grid by 5e-5).
for correction in 1:2
    (!V4 && abs(r.hand_to_mouth_kvw - HTM_TARGET) <= HTM_TOL / 2 && abs(r.mean_effort_employed - E_TARGET) <= E_TOL / 2) && break
    global spread, best, r, S, phi
    s0 = soff(phi, spread)
    gap_h = r.hand_to_mouth_kvw - s0.hand_to_mouth_kvw
    gap_e = r.mean_effort_employed - s0.mean_effort_employed
    # version 4: the fit is on the economy without cohesion, so a correction is called for only when
    # cohesion itself moves the two moments (it does not when the job sets effort and saving is unchanged)
    (V4 && abs(gap_h) <= HTM_TOL / 2 && abs(gap_e) <= E_TOL / 2) && break
    say(@sprintf("\n5.%d hand-to-mouth off by %+.4f, effort off by %+.4f; this economy's own cohesion gaps are %+.4f and %+.4f. Correction %d of 2.",
                 correction, r.hand_to_mouth_kvw - HTM_TARGET, r.mean_effort_employed - E_TARGET, gap_h, gap_e, correction))
    ck5 = ck_read("stage5_$(correction)")
    if ck5 === nothing
        if V3
            f3 = fit_v3(E_TARGET - gap_e, HTM_TARGET - gap_h; x0 = [log(phi), BB[], spread, ETA[], FL[], BGAP[]], iters = 8, tag = "fit3_c$(correction)")
            phi = f3.phi; spread = f3.sp; BB[] = f3.bb; ETA[] = f3.eta; FL[] = f3.fl; BGAP[] = f3.gap; edge2 = false
        else
            phi = fit_phi(spread; lo = max(0.5, phi - 4), hi = phi + 4, steps = 10, aim = E_TARGET - gap_e)
            fs2 = fit_spread(phi, HTM_TARGET - gap_h)
            spread = fs2.sp; edge2 = fs2.edge; BB[] = fs2.bb
        end
        ck_write("stage5_$(correction)", Dict("phi" => phi, "spread" => spread, "edge" => Float64(edge2), "bb" => BB[], "eta" => V3 ? ETA[] : NaN))
    else
        phi, spread, edge2 = ck5["phi"], ck5["spread"], ck5["edge"] == 1.0; BB[] = get(ck5, "bb", 0.96); V3 && (ETA[] = ck5["eta"])
        say("  from checkpoint ", basename(ckfile("stage5_$(correction)")))
    end
    @printf("  new phi %.2f, spread %.3f, mean patience %.4f%s\n", phi, spread, BB[], edge2 ? " (ON THE GRID EDGE)" : ""); flush(stdout)
    budget_check("correction $(correction)'s scan")
    S = timed_scans(phi, spread)
    if S[RATIO] === nothing || S[RATIO].best.loss > LOSS_STD
        say("\nNOT CALIBRATED after the correction. No calibration file written.")
        mark_not_calibrated(); exit(2)
    end
    best = S[RATIO].best
    r = solve_at(phi, spread, best)
end
ck_write("pre5b", Dict("phi" => phi, "spread" => spread, "bb" => BB[], "eta" => V3 ? ETA[] : NaN, "fl" => V3 ? FL[] : NaN, "gap" => V3 ? BGAP[] : NaN))
end
say("\n5b. the calibration on the full belonging grid (", length(UGRID_DEFAULT), " scales): technology re-scanned, economy solved and checked")
budget_check("the full-grid scan"; factor = 2.5)
S = timed_scans(phi, spread; ugrid = UGRID_DEFAULT)
if S[RATIO] === nothing || S[RATIO].best.loss > LOSS_STD
    say("\nNOT CALIBRATED on the full grid. No calibration file written.")
    mark_not_calibrated(); exit(2)
end
best = S[RATIO].best
r = solve_at(phi, spread, best; ugrid = UGRID_DEFAULT)
if (!V4 && abs(r.hand_to_mouth_kvw - HTM_TARGET) > HTM_TOL) || abs(r.mean_effort_employed - E_TARGET) > E_TOL
    say(@sprintf("\nNOT CALIBRATED after two corrections: hand-to-mouth %.4f (target %.4f), effort %.4f (target %.4f). No calibration file written.",
                 r.hand_to_mouth_kvw, HTM_TARGET, r.mean_effort_employed, E_TARGET))
    mark_not_calibrated(); exit(2)
end
if 1 / (1 - r.slope) > MULT_MAX
    say(@sprintf("\nNOT CALIBRATED: the solved economy's multiplier is %.1f, above the stability gate of %.0f. No calibration file written.",
                 1 / (1 - r.slope), MULT_MAX))
    mark_not_calibrated(); exit(2)
end
OWN_GAP || say(@sprintf("  untargeted: participation gap between the cells %.4f against %.4f in the data (what A adds)",
                        r.pooled[2].rate - r.pooled[1].rate, PART[2] - PART[1]))
write_cal(phi, spread; kappa = best.κ, sigma = best.σ)

# ------------------------------------- 6. the fixed-parameter four economies --
if CFG == "GSA"
    say("\n6. the four economies at ", CODE, "'s G+S+A parameters (the fixed-parameter view)")
    for (nm, S_, A_) in (("G     ", false, false), ("G+A   ", false, true), ("G+S   ", true, false), ("G+S+A ", true, true))
        (SKIP_GS && S_ && !A_) && (say(nm, " skipped (SKIP_GS)"); continue)
        rr_ = solve_economy(country_config(CODE; v3 = V3ARG, S = S_, A = A_))
        @printf("%s participation %.4f (E %.4f, U %.4f) | agency %.4f | loss %.4f | hardship %.4f | poor htm %.4f | effort %.4f | median %.4f\n",
                nm, rr_.rate, rr_.rate_E, rr_.rate_U, rr_.A, rr_.shock_loss, rr_.hardship, rr_.hand_to_mouth_kvw,
                rr_.mean_effort_employed, rr_.median_income)
        flush(stdout)
    end
end
@printf("\nDONE %s %s in %.1f min\n", CODE, CFG, (time() - t_start) / 60)

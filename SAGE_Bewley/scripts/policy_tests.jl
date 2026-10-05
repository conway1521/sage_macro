# Policy tests on a country's calibrated configurations, with A on and off.
#
#   julia --project=. scripts/policy_tests.jl FR          (all four configurations)
#
# POLICIES (stage 7's set on the corrected basis):
#   subsidy      a 20 percent subsidy on labour income, financed by a lump-sum
#                levy on the employed, closed so the budget balances. A levy on
#                everyone exceeds the lowest benefit in Germany and Italy, which
#                leaves those unemployed households no feasible choice.
#   empowerment  the lower-education cell's alpha raised halfway to the upper
#                cell's; A on only (with A off both cells share one alpha)
#   ui_up        replacement rate +0.10, the insurance tax adjusting
#   ui_down      replacement rate -0.10, likewise
# The participation credit is left out: paying participants gives the unemployed
# a budget reason to join, which the unemployed participation rule cannot
# represent, and `check_ratio` refuses it.
#
# PROTOCOL. Every economy is solved on the thresholds of its own baseline, so the
# poverty line and the asset threshold are anchored. With cohesion on, the
# social technology is held fixed at three points that all fit the data: the
# best fit, and the acceptable fits (root loss up to 0.035) with the smallest
# and the largest multiplier. Participation effects are reported as that band.
# Where the social technology allows several stable equilibria the solver takes
# the highest, so the scan for the band considers only that one.
# A policy's response families do not depend on the technology, so the band
# costs no household solves. The levy for the subsidy is closed at the
# best fit and reused at the other two points. Prices (the interest rate and the
# wage) are fixed: this is partial equilibrium.
#
# REGIME (SAGE_REGIME: v3, v3f, v3e or v3fe; empty is version 2). The version 3 regimes read their own
# calibration files. There the replacement rate has a state-paid part, which moves with it; where the
# country has a means-tested floor it is moved up and down by a quarter, and where it has none one is
# introduced at 0.15 of reference earnings.
#
# THE PRIVATE SHARE OF BELONGING (omega) is not identified by the participation targets and alone
# decides the multiplier (V3_START.md, section 11). In G+S+A the band therefore also carries two more
# technologies, omega at 0.15 and at 0.60 with kappa and sigma refitted to the same targets, beside
# the three at the calibrated omega. No participation effect is to be read at one technology alone.
#
# Output: a table per configuration on stdout, and policy_results_<CODE>.csv
# (policy_results_<REGIME>_<CODE>.csv in a regime) with every level and difference.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics
say(args...) = (println(args...); flush(stdout))

const CODE = ARGS[1]
const REG = get(ENV, "SAGE_REGIME", "")
const V3ARG = get(Dict("v3" => true, "v3f" => :floor, "v3e" => :edu, "v3fe" => :floor_edu), REG, false)
calfile(cfg) = REG != "" ? joinpath(@__DIR__, "calibration_$(REG)_$(CODE)_$(cfg).txt") :
               joinpath(@__DIR__, cfg == "GSA" ? "calibration_country_$(CODE).txt" :
                                                  "calibration_country_$(CODE)_$(cfg).txt")
const OMEGAS = REG != "" ? (0.15, 0.60) : ()
# Only configurations calibrated on the current inputs: a missing file would
# silently give the table's defaults.
const CFGS = [c for c in (length(ARGS) >= 2 ? [uppercase(ARGS[2])] : ["GSA", "GS", "GA", "G"]) if isfile(calfile(c))]
println("configurations calibrated for ", CODE, ": ", join(CFGS, ", "))
const TAU = 0.20
const DRR = 0.10
const FIELDS = [:rate, :rate_E, :rate_U, :A, :A_cond, :room, :dread_cost_E, :mpc, :shock_loss, :shock_loss_income, :consumption_drop,
                :hardship, :hand_to_mouth_kvw, :mean_effort_employed, :median_income, :mean_labour_income, :income_poor, :asset_poor]
agap(r) = r.A_cell[2] - r.A_cell[1]
cgap(r) = r.A_cond_cell[2] - r.A_cond_cell[1]
const ROWS = Vector{Dict{String,Any}}()

# The technology band: the best point and the lowest- and highest-multiplier
# points that still fit, all under the stability gate (multiplier at most 5,
# calibrate_country.jl). Target ownership as in the calibration: G+S+A fits the
# two education cells; G+S fits overall participation only, over the sigma range
# its own G+S+A band accepts (sigma is not identified without A, so it inherits
# that band), with kappa fitted at each sigma.
const MULT_MAX = 5.0
const SIGMA_BAND = Ref((NaN, NaN))
function technology_points(c, thr; own_gap = true)
    fi = families(c; thresholds = thr)
    part = (parse(Float64, country_rows()[CODE]["part_low"]), parse(Float64, country_rows()[CODE]["part_high"]))
    if own_gap
        rows = scan_technology(c, fi, collect(0.30:0.02:3.00), collect(2.0:0.05:25.0);
                               targets = part, selected_only = true, max_mult = MULT_MAX)
        ok = [x for x in rows if x.loss <= 0.035]
        SIGMA_BAND[] = (minimum(x.σ for x in ok), maximum(x.σ for x in ok))
    else
        isnan(SIGMA_BAND[][1]) && error("G+S needs the G+S+A band first")
        cs = cells_of(c); agg = cs[1].share * part[1] + cs[2].share * part[2]
        rows = scan_technology(c, fi, collect(SIGMA_BAND[][1]:0.02:SIGMA_BAND[][2]), collect(2.0:0.05:25.0);
                               aggregate = agg, selected_only = true, max_mult = MULT_MAX)
        ok = [x for x in rows if x.loss <= 0.005]
    end
    lo = ok[argmin([x.mult for x in ok])]; hi = ok[argmax([x.mult for x in ok])]
    pts = [(tag = "best", κ = c.kappa, σ = c.sigma_m, r = NaN, ω = c.omega),
           (tag = "low multiplier", κ = lo.κ, σ = lo.σ, r = lo.r, ω = c.omega),
           (tag = "high multiplier", κ = hi.κ, σ = hi.σ, r = hi.r, ω = c.omega)]
    # the private share at other values, kappa and sigma refitted to the cells (the families do not depend on it)
    if own_gap
        for ω in OMEGAS
            rw = scan_technology(SAGEConfig(c; omega = ω), fi, collect(0.30:0.02:3.00), collect(2.0:0.05:25.0);
                                 targets = part, selected_only = true, max_mult = MULT_MAX)
            isempty(rw) && continue
            b = rw[argmin([x.loss for x in rw])]
            b.loss <= 0.035 || (say(@sprintf("  private share %.2f: no technology fits the cells (best root loss %.4f); left out", ω, b.loss)); continue)
            push!(pts, (tag = @sprintf("private %.2f", ω), κ = b.κ, σ = b.σ, r = b.r, ω = ω))
        end
    end
    pts
end

for cfg in CFGS
    S_ = occursin('S', cfg); A_ = occursin('A', cfg)
    base = country_config(CODE; config = cfg, v3 = V3ARG, S = S_, A = A_)
    t0 = time()
    b0 = solve_economy(base)
    thr = [(b0.ypov, b0.abar)]
    say("\n", "="^100, "\n", CODE, " ", cfg, " | ", describe(base), "\n", "="^100)
    pts = S_ ? technology_points(base, thr; own_gap = A_) : [(tag = "no cohesion", κ = base.kappa, σ = base.sigma_m, r = NaN, ω = base.omega)]
    at(c, pt) = SAGEConfig(c; kappa = pt.κ, sigma_m = pt.σ, omega = pt.ω)
    bases = [solve_economy(at(base, pt); thresholds = thr) for pt in pts]
    for (pt, b) in zip(pts, bases)
        @printf("  technology %-16s kappa %5.2f sigma %4.2f | participation %.4f, multiplier %.1f\n",
                pt.tag, pt.κ, pt.σ, b.rate, b.slope < 1 ? 1 / (1 - b.slope) : 1.0)
        # the scan's equilibrium must be the one the full solve selects
        isnan(pt.r) || abs(b.rate - pt.r) < 0.005 ||
            @printf("  MISMATCH technology %s: scan rate %.4f but the full solve selects %.4f\n", pt.tag, pt.r, b.rate)
    end
    flush(stdout)

    pols = Pair{String,Any}[]
    # subsidy with the budget closed at the best fit
    # revenue L * (1 - u) pays for TAU * mean labour income
    # The required levy g(T) rises with T at a slope near 0.1 (France: 0.0841,
    # 0.0874, 0.0877), so the first step extrapolates with that slope and later
    # steps use the secant through the last two points.
    T = TAU * b0.mean_labour_income / (1 - b0.unemployment); rs = nothing; prev = nothing
    for it in 1:5
        rs = solve_economy(at(SAGEConfig(base; subsidy = TAU, levy_employed = T), pts[1]); thresholds = thr)
        Tn = TAU * rs.mean_labour_income / (1 - rs.unemployment)
        @printf("  subsidy budget iteration %d: levy %.5f -> %.5f\n", it, T, Tn); flush(stdout)
        abs(Tn - T) < 1e-4 && break
        slope = prev === nothing ? 0.1 : clamp(((Tn - T) - prev[2]) / (T - prev[1]) + 1, 0.0, 0.5)
        prev = (T, Tn - T)
        T = T + (Tn - T) / (1 - slope)
    end
    push!(pols, "subsidy" => SAGEConfig(base; subsidy = TAU, levy_employed = T))
    A_ && push!(pols, "empowerment" => SAGEConfig(base; alpha = ((base.alpha[1] + base.alpha[2]) / 2, base.alpha[2])))
    # the state-paid part of the replacement rate, where there is one (version 3), moves with the rate
    pub(d) = isnan(base.rr_public) ? NaN : base.rr_public + d
    push!(pols, "ui_up" => SAGEConfig(base; rr = base.rr + DRR, rr_public = pub(DRR)))
    push!(pols, "ui_down" => SAGEConfig(base; rr = base.rr - DRR, rr_public = pub(-DRR)))
    if REG != "" && base.effort_mode === :job
        if base.cfloor > 0
            push!(pols, "floor_up" => SAGEConfig(base; cfloor = 1.25 * base.cfloor))
            push!(pols, "floor_down" => SAGEConfig(base; cfloor = 0.75 * base.cfloor))
        else
            push!(pols, "floor_in" => SAGEConfig(base; cfloor = 0.15 * base.e_ref))
        end
    end

    say(@sprintf("\n  %-12s %-16s | %8s %8s %8s | %8s %8s %8s %8s | %8s %8s %8s",
                 "policy", "technology", "d part", "d emp", "d unemp", "d agency", "d gap", "d loss", "d drop",
                 "d hard", "d htm", "d effort"))
    for (name, pc) in pols
        for (pt, b) in zip(pts, bases)
            r = try
                solve_economy(at(pc, pt); thresholds = thr)
            catch err          # a policy with no solution (a floor that cannot be financed) is said and left out
                @printf("  %-12s %-16s | no solution: %s\n", name, pt.tag, first(replace(sprint(showerror, err), "\n" => " "), 110)); flush(stdout)
                continue
            end
            d(f) = getfield(r, f) - getfield(b, f)
            @printf("  %-12s %-16s | %+8.4f %+8.4f %+8.4f | %+8.4f %+8.4f %+8.4f %+8.4f | %+8.4f %+8.4f %+8.4f\n",
                    name, pt.tag, d(:rate), d(:rate_E), d(:rate_U), d(:A), agap(r) - agap(b), d(:shock_loss),
                    d(:consumption_drop), d(:hardship), d(:hand_to_mouth_kvw), d(:mean_effort_employed))
            flush(stdout)
            row = Dict{String,Any}("code" => CODE, "config" => cfg, "policy" => name, "technology" => pt.tag,
                                   "kappa" => pt.κ, "sigma" => pt.σ, "omega" => pt.ω,
                                   "multiplier" => b.slope < 1 ? 1 / (1 - b.slope) : 1.0,
                                   "agency_gap" => agap(r), "d_agency_gap" => agap(r) - agap(b),
                                   "cond_gap" => cgap(r), "d_cond_gap" => cgap(r) - cgap(b))
            for f in FIELDS
                row[string(f)] = getfield(r, f); row["d_" * string(f)] = d(f)
            end
            push!(ROWS, row)
        end
    end
    @printf("  [%s done in %.1f min]\n", cfg, (time() - t0) / 60); flush(stdout)
end

cols = vcat(["code", "config", "policy", "technology", "kappa", "sigma", "omega", "multiplier", "agency_gap", "d_agency_gap",
             "cond_gap", "d_cond_gap"],
            [string(f) for f in FIELDS], ["d_" * string(f) for f in FIELDS])
const OUTCSV = REG != "" ? "policy_results_$(REG)_$(CODE).csv" : "policy_results_$(CODE).csv"
open(joinpath(@__DIR__, OUTCSV), "w") do io
    println(io, join(cols, ","))
    for r in ROWS
        println(io, join([v isa AbstractString ? v : @sprintf("%.6f", v) for v in (r[c] for c in cols)], ","))
    end
end
say("\nwrote ", OUTCSV, "\nDONE")

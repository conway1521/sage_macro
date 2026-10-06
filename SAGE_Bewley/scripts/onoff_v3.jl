# Version 3, one asset: every switch on and off, country by country, and whether
# the result makes sense each time (V3_START.md, section 13, the on/off pass).
#
# Two views of the four economies G, G+A, G+S, G+S+A:
#   fixed parameters  the country's G+S+A calibration with switches turned off:
#                     what each dimension does, nothing refitted;
#   own calibration   each configuration at its own file: every configuration
#                     must be a usable model that hits its own targets.
# Checks, each PASS or FAIL:
#   1. S off: no participation beyond the logit's tremble (below 1e-4) and no
#      belonging in welfare;
#   2. S on, fixed parameters: welfare rises by the belonging part and nothing in
#      the consumption or effort parts moves by more than the G bands allow;
#   3. A on, fixed parameters: the participation gap between the education cells
#      widens (A is what separates the cells);
#   4. own calibration: effort and the hand-to-mouth share inside their bands,
#      and with S on, participation within 0.005 of the country's rate;
#   5. the budget balances (no floor: the gap is zero);
#   6. the MPC stays in the range of the version 3 base in every configuration
#      (0.2 to 0.5): no switch breaks spending behaviour.
#
# With "floor" among the arguments: the floor regime (calibration_v3f_*, V3_START.md section 22).
#
# With "edu": patience by education (calibration_v3e_*, or calibration_v3fe_* with the floor).
#
# With "trans": the transitory part and the proportional tax as well (calibration_v3fet_* with both).
#
#   julia --project=scripts/run_env scripts/onoff_v3.jl [floor] [edu] [trans] [CODE ...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
FLOORREG = any(a -> lowercase(a) == "floor", ARGS)
EDUREG = any(a -> lowercase(a) == "edu", ARGS)          # patience by education (V3_START.md section 24)
TRANS = any(a -> lowercase(a) == "trans", ARGS)        # the transitory part and the proportional tax (V3_START.md section 29)
V3ARG = TRANS ? Symbol((FLOORREG ? "floor_" : "") * (EDUREG ? "edu_" : "") * "trans") : FLOORREG ? (EDUREG ? :floor_edu : :floor) : (EDUREG ? :edu : true)
VTAG = "v3" * (FLOORREG ? "f" : "") * (EDUREG ? "e" : "") * (TRANS ? "t" : "")
codes = (cc = [uppercase(a) for a in ARGS if !(lowercase(a) in ("floor", "edu", "trans"))]; isempty(cc) ? ["FR", "DE", "IT"] : cc)
(FLOORREG || EDUREG || TRANS) && println("regime: ", VTAG)
function hfcs(code, moment)
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        f = split(ln, ",")
        length(f) >= 6 && f[1] == moment && f[2] == code && f[3] == "2021" && f[4] == "all" && return parse(Float64, f[6])
    end
    NaN
end
results = Tuple{String,Bool}[]
check(name, ok) = (push!(results, (name, ok)); @printf("   -> %s: %s\n", name, ok ? "PASS" : "FAIL"))
mult(r) = r.rate > 0 ? 1 / (1 - r.slope) : NaN
function row(nm, r)
    @printf("%-7s part %.4f (cells %.4f %.4f) | protection %.4f | income poor %.4f | htm %.4f | effort %.4f | MPC %.3f | job-loss drop %.3f | liquid/inc %.3f | welfare %+.4f = c %+.4f, effort %+.4f, belonging %+.4f | multiplier %s\n",
            nm, r.rate, r.pooled[1].rate, r.pooled[2].rate, r.A_cond, r.income_poor, r.hand_to_mouth_kvw, r.mean_effort_employed, r.mpc, r.consumption_drop,
            r.wealth_p50 / r.median_income, r.welfare.V, r.welfare.Vc, r.welfare.Ve, r.welfare.Vb, isnan(mult(r)) ? "-" : @sprintf("%.2f", mult(r)))
    flush(stdout)
end
CFGS = (("G", false, false), ("GA", false, true), ("GS", true, false), ("GSA", true, true))
for code in codes
    row_ = country_rows()[code]
    E = parse(Float64, row_["effort_target"]); H = hfcs(code, "htm_model_narrow_total")
    sh = parse(Float64, row_["share_high"]); P = (1 - sh) * parse(Float64, row_["part_low"]) + sh * parse(Float64, row_["part_high"])
    @printf("\n================ %s | targets: effort %.4f, hand-to-mouth %.4f, participation %.4f\n", code, E, H, P)
    println("fixed parameters (the G+S+A calibration, switches turned off)")
    fx = Dict{String,Any}()
    for (nm, S_, A_) in CFGS
        fx[nm] = solve_economy(country_config(code; v3 = V3ARG, S = S_, A = A_)); row(nm, fx[nm])
    end
    @printf("   S off: participation %.2e (G), %.2e (G+A); belonging in welfare %.2e, %.2e\n", fx["G"].rate, fx["GA"].rate, fx["G"].welfare.Vb, fx["GA"].welfare.Vb)
    check("$code 1. S off: participation below 1e-4 and no belonging in welfare", all(fx[k].rate < 1e-4 && abs(fx[k].welfare.Vb) < 1e-8 for k in ("G", "GA")))
    for (off, on) in (("G", "GS"), ("GA", "GSA"))
        check("$code 2. $on against $off: belonging adds to welfare; hand-to-mouth within 0.03 and effort within 0.01 of S off",
              fx[on].welfare.Vb > 0 && abs(fx[on].hand_to_mouth_kvw - fx[off].hand_to_mouth_kvw) < 0.03 && abs(fx[on].mean_effort_employed - fx[off].mean_effort_employed) < 0.01)
    end
    gap(r) = r.pooled[2].rate - r.pooled[1].rate
    @printf("   participation gap between the cells: %.4f without A, %.4f with A\n", gap(fx["GS"]), gap(fx["GSA"]))
    check("$code 3. A widens the participation gap between the cells", gap(fx["GSA"]) > gap(fx["GS"]))
    println("own calibration (each configuration at its own file)")
    for (nm, S_, A_) in CFGS
        f = joinpath(@__DIR__, "calibration_$(VTAG)_$(code)_$(nm).txt")
        isfile(f) || (println(nm, "      no calibration file yet"); push!(results, ("$code 4. $nm has a calibration", false)); continue)
        r = solve_economy(country_config(code; v3 = V3ARG, config = nm, S = S_, A = A_)); row(nm, r)
        ok = abs(r.mean_effort_employed - E) <= 0.005 && abs(r.hand_to_mouth_kvw - H) <= 0.02 && (!S_ || abs(r.rate - P) <= 0.005)
        check("$code 4. $nm hits its own targets", ok)
        check("$code 5. $nm: the budget balances" * (FLOORREG ? " (to 0.05% of mean income with S on)" : ""), abs(r.budget_gap) < (FLOORREG && S_ ? 5e-4 * r.mean_income : 1e-8))
        FLOORREG && @printf("      floor %.4f, outlay per head %.5f, budget gap %+.1e\n", r.config.cfloor, r.floor_outlay, r.budget_gap)
        check("$code 6. $nm: MPC between 0.2 and 0.5", 0.2 <= r.mpc <= 0.5)
    end
end
nf = count(x -> !x[2], results)
@printf("\n%d of %d checks pass%s\n", length(results) - nf, length(results), nf == 0 ? "" : "; FAILED:\n  " * join([x[1] for x in results if !x[2]], "\n  "))
println("DONE")

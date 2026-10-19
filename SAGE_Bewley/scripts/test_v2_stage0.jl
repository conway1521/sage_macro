# The regression harness for version 2's stage 0 (V2_BUILD_PLAN.md): with the version 2 switch off, the
# refactor to labelled labour states must leave version 1 exactly as it was. This prints, to full precision,
# the economy's moments for G and G+A (dread in choices and search) in three countries, and a checksum of
# G+S+A household problems at three belonging scales. Run once on version 1's code to make the baseline
# (`data/validation/v1_regression_baseline.txt`, committed by hand from the log), then after each change;
# with a baseline given, it compares and reports the largest relative difference.
#
#   julia --project=scripts/run_env scripts/test_v2_stage0.jl [compare]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
const KEYS = (:hand_to_mouth_kvw, :wealth_p50, :median_income, :mean_income, :mpc, :consumption_drop, :unemployment,
              :mean_effort_employed, :rate, :dread_cost_E, :search_cost_out, :shock_loss, :A, :consumption, :budget_gap)
out = Pair{String,Float64}[]
put!(k, v) = (push!(out, k => Float64(v)); @printf("%s %.15g\n", k, v); flush(stdout))
for code in ("FR", "DE", "IT"), (cfg, A_) in (("G", false), ("GA", true))
    r = solve_economy(country_config(code; config = cfg, v3 = :v5m, S = false, A = A_); cache = false)
    for k in KEYS
        hasproperty(r, k) || continue
        v = getfield(r, k); v isa Number && put!("$code.$cfg.$k", v)
    end
    put!("$code.$cfg.welfare.V", r.welfare.V); put!("$code.$cfg.welfare.Vd", r.welfare.Vd); put!("$code.$cfg.welfare.Vk", r.welfare.Vk)
    A_ && put!("$code.$cfg.search_U", r.search_UL[1])
end
for code in ("FR", "DE", "IT")
    c = floor_effort(country_config(code; config = "GSA", v3 = :v5m, S = true, A = true))
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c)); cs = cells_of(c)
    for g in 1:2, u in (0.0, 8.2, 30.0)
        p = update(params_of(cT, cs[g])[1]; social_strength = u)
        s = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
        put!("$code.GSAhh.$g.$u.V", sum(s.lambda .* s.V)); put!("$code.GSAhh.$g.$u.P1", sum(s.lambda .* s.P1))
        put!("$code.GSAhh.$g.$u.x", sum(s.lambda .* s.search_x)); put!("$code.GSAhh.$g.$u.a", sum(s.lambda .* s.a))
    end
end
base = joinpath(@__DIR__, "..", "..", "data", "validation", "v1_regression_baseline.txt")
if length(ARGS) >= 1 && ARGS[1] == "compare" && isfile(base)
    ref = Dict{String,Float64}()
    for l in eachline(base)
        f = split(l); length(f) == 2 && (ref[f[1]] = parse(Float64, f[2]))
    end
    worst = 0.0; wk = ""
    for (k, v) in out
        haskey(ref, k) || (println("missing in the baseline: ", k); continue)
        d = abs(v - ref[k]) / max(abs(ref[k]), 1e-8)
        d > worst && (worst = d; wk = k)
    end
    @printf("\nlargest relative difference against version 1: %.2e at %s -> %s\n", worst, wk, worst < 1e-10 ? "PASS" : "FAIL")
end
println("DONE")

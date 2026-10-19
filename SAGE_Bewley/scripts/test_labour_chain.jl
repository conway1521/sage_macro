# Tests of labour_chain.jl (V2_BUILD_PLAN.md, stage 1a), before it is wired into the model.
# 1. At an annual period with one duration of unemployment, the chain's income moments equal version 1's
#    (`income_chain_moments`) for every country and education cell, at the purged sds.
# 2. At a quarter, with version 1's flows converted (four quarters of insured unemployment, then L), the refitted
#    income process reproduces the published annual autocovariances at lags 0, 1, 2; lag 3 is reported as a check.
#
#   julia --project=scripts/run_env scripts/test_labour_chain.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
include(joinpath(@__DIR__, "labour_chain.jl"))
using Printf
q4(x) = 1 - (1 - x)^(1 / 4)
worst = 0.0
for code in ("FR", "DE", "IT")
    c = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
    pub(k) = manual_input(code, k)
    for g in 1:2
        lo = g == 1 ? "low" : "high"
        ρ = pub("rho_$lo"); sη = sqrt(pub("var_persistent_$lo")); sε = sqrt(pub("var_transitory_$lo"))
        δ = c.delta[g]; f = c.f_find; fL = c.f_long[g]
        # 1. the annual chain against version 1
        a, b = c.eta_cell[g], c.sd_eps_cell[g]
        v1 = income_chain_moments(c.nz, c.n_eps, ρ, a, b, δ, f, fL, c.rr, c.rr_long)
        base = SAGEParams(nz = c.nz, α = fill(1.0, c.nz), B = fill(1.0, c.nz), ρ = ρ, η = a)
        ch = labour_chain(base; nU = 1, hU = [f], hL = fL, δ = δ)
        qy = chain_log_income(ch, b, c.n_eps, [c.rr], c.rr_long)
        m = averaged_autocov(qy.y, qy.P; k = 1, lags = 1)
        d = max(abs(m[1] - v1.var), abs(m[2] - v1.ac1)); global worst = max(worst, d)
        @printf("%s cell %d | annual chain: var %.8f (v1 %.8f), ac1 %.8f (v1 %.8f), difference %.1e\n", code, g, m[1], v1.var, m[2], v1.ac1, d)
        # 2. the quarterly refit with version 1's flows converted
        t = @elapsed r = quarterly_income(c.nz, c.n_eps, ρ, sη, sε; nU = 4, hU = fill(q4(f), 4), hL = q4(fL), δ = q4(δ), rrU = fill(c.rr, 4), rrL = c.rr_long)
        @printf("   quarterly: rho %.4f (annual %.3f, rho^(1/4) %.4f), s_eta %.4f, s_eps %.4f | annual autocov %s against %s | lag 3 %.5f against %.5f [%.1f s]\n",
                r.ρq, ρ, ρ^(1 / 4), r.sηq, r.sεq, string(round.(r.fit[1:3]; digits = 5)), string(round.(r.target[1:3]; digits = 5)), r.fit[4], r.target[4], t)
    end
end
@printf("\nannual chain against version 1: largest difference %.1e -> %s\n", worst, worst < 1e-10 ? "PASS" : "FAIL")
println("DONE")

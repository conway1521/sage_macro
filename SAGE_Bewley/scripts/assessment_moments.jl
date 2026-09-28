# Untargeted moments of each calibrated G+S+A economy against the validation
# benchmarks in PLAN_MASTER.md. None of these is a calibration target. The
# wealth moments compare a one-asset (liquid) model with HFCS net wealth, so a
# large miss there measures what the one-asset limit costs, which is what the
# illiquid-asset switch is for.
#
#   julia --project=scripts/run_env scripts/assessment_moments.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf

function gini_top(x, m)
    o = sortperm(x); x = x[o]; m = m[o] ./ sum(m)
    cm = cumsum(m); cw = cumsum(m .* x) ./ sum(m .* x)
    g = 1 - sum(m .* (cw .+ vcat(0.0, cw[1:end-1])))
    k = findfirst(>=(0.9), cm)
    top = 1 - (k == 1 ? 0.0 : cw[k-1] + (0.9 - cm[k-1]) / m[k] * (cw[k] - cw[k-1]))
    g, top
end
function median_of(x, m)
    o = sortperm(x); cm = cumsum(m[o]) ./ sum(m); x[o][findfirst(>=(0.5), cm)]
end

BENCH = Dict("DE" => (mpc = "0.50 (0.40-0.55)", drop = "0.06 (0.04-0.09)", top = "0.555", gini = "0.727", liq = "0.295"),
             "FR" => (mpc = "0.42 (0.35-0.50)", drop = "0.09 (0.05-0.13)", top = "0.499", gini = "0.676", liq = "0.248"),
             "IT" => (mpc = "0.48 (0.45-0.52)", drop = "0.08 (0.05-0.13)", top = "0.546", gini = "0.671", liq = "0.271"))
for code in ("FR", "DE", "IT")
    t0 = time()
    r = solve_economy(country_config(code; config = "GSA", S = true, A = true))
    g, top = gini_top(r.agrid, r.Wtot)
    liq = median_of(r.agrid, r.Wtot) / r.mean_income
    b = BENCH[code]
    @printf("\n%s G+S+A  (solved in %.1f min; participation %.4f, multiplier %.1f)\n", code, (time() - t0) / 60, r.rate, 1 / (1 - r.slope))
    @printf("  %-44s %8s   %s\n", "moment", "model", "data")
    @printf("  %-44s %8.3f   %s\n", "annual MPC, one-month windfall", r.mpc, b.mpc)
    @printf("  %-44s %8.3f   %s\n", "  among the hand-to-mouth", r.mpc_htm, "higher by 25-35 pp at the bottom")
    @printf("  %-44s %8.3f   %s\n", "consumption drop on job loss", r.consumption_drop, b.drop)
    @printf("  %-44s %8.3f   %s\n", "top 10% wealth share (model liquid, data net)", top, b.top)
    @printf("  %-44s %8.3f   %s\n", "wealth Gini (model liquid, data net)", g, b.gini)
    @printf("  %-44s %8.3f   %s\n", "median liquid assets / mean income", liq, b.liq * " (gross income)")
    @printf("  %-44s %8.3f   %s\n", "room to manoeuvre (3 months of income)", r.room, "HFCS, pending")
    flush(stdout)
end
println("DONE")

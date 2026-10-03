# Is median liquid wealth in the two-asset model a property of the economy or of
# the illiquid grid? An adjuster chooses its illiquid wealth among the grid's
# nodes and holds the rest as liquid (egm2_core.jl), so with nodes far apart the
# remainder sits in liquid wealth. In the version 3 calibration for France
# (2026-10-03) liquid wealth over income stayed at 0.21 against 0.059 while the
# fixed cost fell from 0.05 to 0.002. The same economy on finer illiquid grids:
# if the liquid median and the hand-to-mouth shares move with the grid, they are
# not yet results.
#
#   julia --project=scripts/run_env scripts/probe_two_asset_grid.jl [CODE] [effective patience] [chi0] [grids, comma separated]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
bet = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 0.9595
chi0 = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 0.0022
grids = length(ARGS) >= 4 ? parse.(Int, split(ARGS[4], ",")) : [24, 48, 96]
premium = 0.0
for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "manual_inputs.csv"))
    f = split(ln, ","); length(f) >= 3 && f[1] == code && f[2] == "illiquid_premium" && (global premium = parse(Float64, f[3]))
end
one = country_config(code; config = "G", v3 = true, S = false, A = false)
levels = job_effort_levels(one)
base = SAGEConfig(one; illiquid = true, illiquid_premium = premium, effort_by_cell = levels, beta_spread = 0.0, beta_bar = bet / (1 - one.death), chi0 = chi0)
@printf("%s G, two assets, version 3, effective patience %.4f, fixed cost %.4f, premium %.4f; illiquid grid to %.0f with exponent %.1f\n", code, bet, chi0, premium, base.k_max, base.pexp)
@printf("%5s | %10s %10s %9s %11s %7s %9s | %8s | %s\n", "nk", "net w/inc", "liquid/inc", "poor htm", "wealthy htm", "MPC", "adjusting", "minutes", "illiquid nodes around the median, in years of median income")
for nk in grids
    t0 = time()
    c = SAGEConfig(base; nk = nk)
    r = _solve(c, nothing; disk = false)
    kg = SAGEBewley.exponential_grid(0.0, c.k_max, c.nk, c.pexp) ./ r.median_income
    nwm = cdf_quantile(NWGRID, r.Ntot, 0.5) / r.median_income
    j = clamp(searchsortedlast(kg, nwm), 1, nk - 2)
    adj = hasproperty(r, :adjust_share) ? r.adjust_share : NaN
    @printf("%5d | %10.2f %10.3f %9.4f %11.4f %7.3f %9.3f | %8.1f | %s\n", nk, nwm, cdf_quantile(r.agrid, r.Wtot, 0.5) / r.median_income, r.hand_to_mouth_kvw, r.wealthy_htm, r.mpc, adj,
            (time() - t0) / 60, join([@sprintf("%.2f", v) for v in kg[max(j - 1, 1):j+2]], " "))
    flush(stdout)
end
println("DONE")

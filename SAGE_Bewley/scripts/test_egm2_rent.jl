# Tenure in the two-asset solver (V3_START.md section 139; design section 4.1), a mechanical test, not a calibration.
# The problem of test_egm2_howard.jl (stage 1c's quarterly G, the illiquid asset at version 1's two-asset reference),
# solved (1) as it is, with no rent, to be compared with H = 0 of test_egm2_howard.jl (the same numbers to every
# printed digit: tenure off changes nothing), and (2) with the design's cash flows at placeholder values: the gain
# accruing inside the asset (no payout), RK a quarter, tenants below KMIN paying RENT a quarter in every income state
# (model units: a period's income in work is about one). Reported: iterations, minutes, liquid and illiquid wealth,
# the share adjusting, the ownership rate (mass at or above k_min), hand-to-mouth poor and wealthy, mean consumption of
# tenants and owners, and the lowest consumption over states with mass (positive if the budget holds everywhere).
#
#   JULIA_NUM_THREADS=4 julia --project=scripts/run_env scripts/test_egm2_rent.jl CODE NK KSUB NB RK KMIN RENT [H]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); nk = parse(Int, ARGS[2]); ksub = parse(Int, ARGS[3]); nb = parse(Int, ARGS[4])
Rk = parse(Float64, ARGS[5]); kmin = parse(Float64, ARGS[6]); rent = parse(Float64, ARGS[7])
H = length(ARGS) >= 8 ? parse(Int, ARGS[8]) : 0
say(x...) = (println(x...); flush(stdout))
ref = Dict{String,Float64}()
for l in eachline(joinpath(@__DIR__, "calibration_v3fet_$(code)_G_I.txt"))
    t = strip(l); (isempty(t) || startswith(t, "#") || !occursin("=", t)) && continue
    k, v = strip.(split(t, "=")); x = tryparse(Float64, split(v)[1]); x === nothing || (ref[k] = x)
end
ca = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
cq = floor_effort(SAGEConfig(duration_config(ca); cfloor = 0.0))
p1 = update(params_of(cq, cells_of(cq)[1])[1]; social_strength = 0.0)
p2 = update(p1; illiquid = true, Rk = p1.R + ref["illiquid_premium"] / 4, chi0 = ref["chi0"], death = 1 - (1 - 1 / 45)^(1 / 4),
            nk = nk, k_max = 4 * 150.0, k_sub = ksub, k_mid = 0.0, a_max = 4 * 15.0, na = nb, k_payout = true, R = 1.0,
            β = ref["beta_bar"]^(1 / 4), solver = :egm)
p3 = update(p2; k_payout = false, Rk = Rk, k_min = kmin, rent = fill(rent, p2.nz))
say(@sprintf("%s: %d income states, liquid %d x illiquid %d (%d targets an interval), %d threads, Howard %d", code, p2.nz, nb, nk, ksub, Threads.nthreads(), H))
ENV["SAGE_WARM2"] = "0"
function report(tag, p, t, s)
    a = s.a; kg = s.k; λ = s.lambda
    b = sum(λ .* reshape(a, :, 1, 1)); k = sum(λ .* reshape(kg, 1, :, 1)); adj = sum(λ .* s.Padj)
    own = sum(λ[:, m, :] for m in 1:length(kg) if kg[m] >= p.k_min && p.k_min > 0; init = zeros(size(λ, 1), size(λ, 3)))
    own = p.k_min > 0 ? sum(own) : NaN
    htm = 0.0; whtm = 0.0; ct = 0.0; mt = 0.0; co = 0.0; mo = 0.0; cmin = Inf
    for st in axes(λ, 3), m in axes(λ, 2), i in axes(λ, 1)
        w = λ[i, m, st]; w <= 1e-14 && continue
        h = a[i] <= s.ybar[i, m, st] / 52
        h && (m == 1 ? (htm += w) : (whtm += w))
        c = s.cbar[i, m, st]; cmin = min(cmin, c)
        if p.k_min > 0 && kg[m] < p.k_min
            ct += w * c; mt += w
        else
            co += w * c; mo += w
        end
    end
    say(@sprintf("%-8s %5d full steps, %.1f min; liquid %.6f, illiquid %.6f, adjusting %.6f, ownership %.4f, htm poor %.4f wealthy %.4f, consumption tenants %.4f owners %.4f, lowest %.4g",
                 tag, s.iters, t / 60, b, k, adj, own, htm, whtm, mt > 0 ? ct / mt : NaN, mo > 0 ? co / mo : NaN, cmin))
    say("         illiquid grid: ", join([@sprintf("%.3g", x) for x in kg], " "), "; tenant nodes ", count(s.tenant))
end
solve_two_asset_egm(p2, 1.0; maxit = 2, howard = H); solve_two_asset_egm(p3, 1.0; maxit = 2, howard = H)    # compile
t = @elapsed s = solve_two_asset_egm(p2, 1.0; full = true, howard = H); report("no rent", p2, t, s)
t = @elapsed s = solve_two_asset_egm(p3, 1.0; full = true, howard = H); report("tenure", p3, t, s)
println("DONE")

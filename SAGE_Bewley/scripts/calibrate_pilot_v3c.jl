# Pilot of the version 3 one-asset calibration: the single asset is LIQUID wealth
# (narrow definition of Kaplan, Violante and Weidner 2014, computed from the HFCS
# 2021 by hfcs_protocol/hfcs_moments.py), effort is set by the job, and patience
# is spread uniformly below its top value (Krusell and Smith 1998; Carroll,
# Slacalek, Tokuoka and White 2017).
#   phi          -> effort of the employed (HETUS)
#   top patience -> median liquid wealth over median after-tax income
#   spread       -> hand-to-mouth, total, on the model's rule (liquid wealth at
#                   most one week of income)
# No free parameter. The MPC is NOT targeted: it is the test, against the
# self-reported MPC of the same survey.
#
#   julia --project=scripts/run_env scripts/calibrate_pilot_v3c.jl [CODE] [CONFIG]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
cfg = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "G"
D = Dict("FR" => (liq = 0.059, htm = 0.222, mpc = 0.392), "DE" => (liq = 0.140, htm = 0.225, mpc = 0.468),
         "IT" => (liq = 0.272, htm = 0.179, mpc = 0.469))[code]
E = parse(Float64, country_rows()[code]["effort_target"])
TOL = [0.005, 0.02, 0.01]          # effort, liquid wealth over income, hand-to-mouth
base = SAGEConfig(country_config(code; config = cfg, S = false, A = occursin('A', cfg)); effort_mode = :job, nbeta = 5)
LO = [log(0.5), 0.86, 0.0]; HI = [log(60.0), 0.985, 0.15]
at(x) = SAGEConfig(base; phi = exp(x[1]), beta_bar = x[2], beta_spread = x[3])
mom(r) = [r.mean_effort_employed, r.wealth_p50 / r.median_income, r.hand_to_mouth_kvw]
resid(m) = (m .- [E, D.liq, D.htm]) ./ TOL
t0 = time(); ns = Ref(0)
solve(x) = (ns[] += 1; solve_economy(at(x); cache = false))
show(tag, x, r, F) = (@printf("%-8s phi %.3f top patience %.4f spread %.4f | effort %.4f liquid/income %.4f htm %.4f | MPC %.3f | worst %.2f band [%d solves, %.1f min]\n",
                              tag, exp(x[1]), x[2], x[3], mom(r)..., r.mpc, maximum(abs.(F)), ns[], (time() - t0) / 60); flush(stdout))
x = [log(base.phi), 0.94, 0.03]
r = solve(x); F = resid(mom(r)); show("start", x, r, F)
H = [0.05, 0.004, 0.01]
# Best fit, not an exact solve: top patience and the spread move median liquid
# wealth and the hand-to-mouth share along nearly the same line, so the two
# targets may not both be met. Damped least squares (Levenberg-Marquardt) finds
# the closest point and the misses are reported in bands.
lam = 0.1
for it in 1:14
    maximum(abs.(F)) <= 0.5 && break
    J = zeros(3, 3)
    for k in 1:3
        xk = copy(x); h = (xk[k] + H[k] > HI[k]) ? -H[k] : H[k]; xk[k] += h
        J[:, k] = (resid(mom(solve(xk))) .- F) ./ h
    end
    it == 1 && @printf("         conditioning of the map at the start: singular values %s\n", join([@sprintf("%.1f", v) for v in svdvals(J)], ", "))
    moved = false
    for _ in 1:6
        A = J' * J; Δ = -((A + lam * Diagonal(diag(A))) \ (J' * F))
        xn = clamp.(x .+ Δ, LO, HI)
        rn = solve(xn); Fn = resid(mom(rn))
        if sum(abs2, Fn) < sum(abs2, F) - 1e-6
            global x = xn; global r = rn; global F = Fn; global lam = max(lam / 3, 1e-4); moved = true; break
        end
        global lam *= 4
    end
    show("step $it", x, r, F)
    moved || break
end
ok = maximum(abs.(F)) <= 1.0
@printf("\n%s: %s %s, one asset as liquid wealth, effort set by the job | misses in bands: effort %+.2f, liquid wealth %+.2f, hand-to-mouth %+.2f\n",
        ok ? "FITTED (pilot)" : "BEST FIT, outside a band", code, cfg, F...)
h = r.hand_to_mouth_kvw
@printf("THE TEST, untargeted: MPC %.3f against %.3f self-reported (HFCS 2021) | hand-to-mouth %.3f, others %.3f | earnings response %+.4f\n",
        r.mpc, D.mpc, r.mpc_htm, (r.mpc - h * r.mpc_htm) / (1 - h), r.mpe)
@printf("other untargeted: consumption drop on job loss %.3f | protection if hit %.4f | income poverty %.4f | asset poverty %.4f | wealth p90 / median income %.3f\n",
        r.consumption_drop, r.A_cond, r.income_poor, r.asset_poor, r.wealth_p90 / r.median_income)
println("DONE")

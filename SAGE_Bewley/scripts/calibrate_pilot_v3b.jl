# Pilot of the liquid-wealth calibration of the one-asset model (V3_START.md),
# one country, G, effort set by the job. The single asset is LIQUID wealth on the
# narrow definition of Kaplan, Violante and Weidner (2014), as computed from the
# HFCS (hfcs_protocol/hfcs_moments.py):
#   phi              -> effort of the employed (HETUS)
#   mean patience    -> median liquid wealth over median after-tax income
#   impatient share  -> hand-to-mouth, total, on the model's rule (liquid wealth
#                       at most one week of income)
# The impatient group's patience is fixed (argument, 0.85 by default). The MPC is
# NOT targeted: it is the test.
#
#   julia --project=scripts/run_env scripts/calibrate_pilot_v3b.jl [CODE] [beta_low]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
BL = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 0.85
# HFCS 2021 (2017 in brackets): narrow liquid wealth over after-tax income, ratio of medians; hand-to-mouth, model rule, narrow
LIQ = Dict("FR" => 0.059, "DE" => 0.140, "IT" => 0.272)[code]
HTM = Dict("FR" => 0.222, "DE" => 0.225, "IT" => 0.179)[code]
MPCD = Dict("FR" => 0.392, "DE" => 0.468, "IT" => 0.469)[code]
E = parse(Float64, country_rows()[code]["effort_target"])
TOL = [0.005, 0.01, 0.01]
base = SAGEConfig(country_config(code; config = "G", S = false, A = false); effort_mode = :job, beta_spread = 0.0, beta_low = BL)
at(x) = SAGEConfig(base; phi = exp(x[1]), beta_bar = clamp(x[2], 0.80, 0.975), impatient_share = clamp(x[3], 0.0, 0.6))
mom(r) = [r.mean_effort_employed, r.wealth_p50 / r.median_income, r.hand_to_mouth_kvw]
resid(m) = (m .- [E, LIQ, HTM]) ./ TOL
x = [log(base.phi), 0.93, 0.10]
t0 = time(); ns = Ref(0)
solve(x) = (ns[] += 1; solve_economy(at(x); cache = false))
r = solve(x); F = resid(mom(r))
show(tag, x, r, F) = (@printf("%-8s phi %.3f beta_bar %.4f share %.3f | effort %.4f liquid/income %.4f htm %.4f | MPC %.3f | worst %.2f band [%d solves, %.1f min]\n",
                              tag, exp(x[1]), x[2], x[3], mom(r)..., r.mpc, maximum(abs.(F)), ns[], (time() - t0) / 60); flush(stdout))
show("start", x, r, F)
H = [0.05, 0.005, 0.03]
for it in 1:10
    maximum(abs.(F)) <= 0.5 && break
    J = zeros(3, 3)
    for k in 1:3
        xk = copy(x); xk[k] += H[k]
        J[:, k] = (resid(mom(solve(xk))) .- F) ./ H[k]
    end
    Δ = -(J \ F); Δ[2] = clamp(Δ[2], -0.02, 0.02); Δ[3] = clamp(Δ[3], -0.1, 0.1); Δ[1] = clamp(Δ[1], -0.3, 0.3)
    s = 1.0; moved = false
    for _ in 1:4
        xn = x .+ s .* Δ; xn[2] = clamp(xn[2], 0.80, 0.975); xn[3] = clamp(xn[3], 0.0, 0.6)
        rn = solve(xn); Fn = resid(mom(rn))
        if sum(abs2, Fn) < sum(abs2, F)
            global x = xn; global r = rn; global F = Fn; moved = true; break
        end
        s /= 2
    end
    show("step $it", x, r, F)
    moved || break
end
@printf("\n%s: %s G, impatient group at %.2f\n", maximum(abs.(F)) <= 1.0 ? "CALIBRATED (pilot)" : "NOT CALIBRATED", code, BL)
@printf("the test, untargeted: MPC %.3f against %.3f self-reported in the HFCS (2021) | of the hand-to-mouth %.3f | earnings response %+.4f\n", r.mpc, MPCD, r.mpc_htm, r.mpe)
@printf("other untargeted: consumption drop on job loss %.3f | protection if hit %.4f | income poverty %.4f | asset poverty %.4f | wealth p90 / median income %.3f\n",
        r.consumption_drop, r.A_cond, r.income_poor, r.asset_poor, r.wealth_p90 / r.median_income)
println("DONE")

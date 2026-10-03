# Pilot of the version 3 one-asset calibration (V3_START.md), one country, G or
# G+A, effort set by the job:
#   phi              -> effort of the employed (HETUS)
#   impatient share  -> TOTAL hand-to-mouth (Kaplan, Violante and Weidner 2014,
#                       Table 5, poor plus wealthy: the single asset read as
#                       liquid wealth)
#   impatient beta   -> annual MPC out of a one-month windfall (Drescher, Fessler
#                       and Lindner 2020, HFCS 2017)
# Mean patience stays at 0.96 until the HFCS gives median liquid wealth to own
# it (identification.jl). Newton steps with a finite-difference Jacobian, bands
# as tolerances. Writes nothing to the repository's calibration files: the
# result is printed, with the untargeted moments beside it.
#
#   julia --project=scripts/run_env scripts/calibrate_pilot_v3.jl [CODE] [CONFIG]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
cfg = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "G"
HTM = Dict("FR" => 0.032 + 0.173, "DE" => 0.074 + 0.248, "IT" => 0.083 + 0.155)[code]
MPC = Dict("FR" => 0.418, "DE" => 0.513, "IT" => 0.481)[code]
E = parse(Float64, country_rows()[code]["effort_target"])
TOL = [0.005, 0.01, 0.05]            # effort, hand-to-mouth, MPC: half the band used to stop
base = SAGEConfig(country_config(code; config = cfg, S = false, A = occursin('A', cfg)); effort_mode = :job, beta_spread = 0.0)
at(x) = SAGEConfig(base; phi = exp(x[1]), impatient_share = clamp(x[2], 0.01, 0.6), beta_low = clamp(x[3], 0.5, 0.95))
mom(r) = [r.mean_effort_employed, r.hand_to_mouth_kvw, r.mpc]
resid(m) = (m .- [E, HTM, MPC]) ./ TOL
x = [log(base.phi), 0.20, 0.75]
t0 = time(); ns = Ref(0)
solve(x) = (ns[] += 1; solve_economy(at(x); cache = false))
r = solve(x); F = resid(mom(r))
show(tag, x, r, F) = (@printf("%-8s phi %.3f share %.3f beta_low %.3f | effort %.4f htm %.4f MPC %.4f | worst %.2f band [%d solves, %.1f min]\n",
                              tag, exp(x[1]), x[2], x[3], mom(r)..., maximum(abs.(F)), ns[], (time() - t0) / 60); flush(stdout))
show("start", x, r, F)
H = [0.05, 0.03, 0.03]
for it in 1:8
    maximum(abs.(F)) <= 0.5 && break
    J = zeros(3, 3)
    for k in 1:3
        xk = copy(x); xk[k] += H[k]
        J[:, k] = (resid(mom(solve(xk))) .- F) ./ H[k]
    end
    Δ = -(J \ F); s = 1.0
    for _ in 1:4
        xn = x .+ s .* Δ; xn[2] = clamp(xn[2], 0.01, 0.6); xn[3] = clamp(xn[3], 0.5, 0.95)
        rn = solve(xn); Fn = resid(mom(rn))
        if sum(abs2, Fn) < sum(abs2, F)
            global x = xn; global r = rn; global F = Fn; break
        end
        s /= 2
    end
    show("step $it", x, r, F)
end
@printf("\n%s: %s\n", maximum(abs.(F)) <= 1.0 ? "CALIBRATED (pilot)" : "NOT CALIBRATED", code * " " * cfg)
@printf("untargeted: earnings response %+.4f | MPC of the hand-to-mouth %.3f | median liquid wealth / median income %.3f | consumption drop on job loss %.3f | poor hand-to-mouth (one week, no illiquid) %.4f | protection if hit %.4f | income poverty %.4f, asset poverty %.4f\n",
        r.mpe, r.mpc_htm, r.wealth_p50 / r.median_income, r.consumption_drop, r.hand_to_mouth_kvw, r.A_cond, r.income_poor, r.asset_poor)
println("DONE")

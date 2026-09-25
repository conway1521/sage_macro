# Checks for the shock-protection agency measure and the poor hand-to-mouth
# statistic (agency_shock.jl), and a reachability map for the new targets, before
# any recalibration. All on the G+A economy, cohesion off, which is cheap.
#
#   SAGE_WORKERS=4 julia --project=. scripts/test_agency_kvw.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
say(args...) = (println(args...); flush(stdout))
ok = Ref(true); check(name, cond) = (say(cond ? "  PASS " : "  FAIL ", name); cond || (ok[] = false))

say("1. no unemployment risk: nobody can lose a job, so p is zero and agency is alpha")
r0 = _solve(SAGEConfig(A = true), nothing; disk = false)
@printf("   agency %.10f, alpha mean %.10f, expected loss %.2e\n", r0.A, (0.765 + 0.911) / 2, r0.shock_loss)
check("agency equals mean alpha", abs(r0.A - (0.765 + 0.911) / 2) < 1e-12)
check("expected loss is zero (to floating-point dust on unreachable states)", r0.shock_loss < 1e-12)

say("\n2. the old statistics are untouched (France G+A, INSEE footing, against the suite)")
r1 = _solve(SAGEConfig(A = true, unemployment = true, beta_spread = 0.037, unemployed_ratio = 0.17 / 0.35), nothing; disk = false)
@printf("   effort %.6f (0.518873), hand-to-mouth, old measure %.6f (0.261599), poor hand-to-mouth %.4f\n",
        r1.mean_effort_employed, r1.hand_to_mouth, r1.hand_to_mouth_kvw)
check("effort and old hand-to-mouth reproduce the suite", abs(r1.mean_effort_employed - 0.518873) < 1e-6 && abs(r1.hand_to_mouth - 0.261599) < 1e-6)
check("the one-week measure is below the four-week one", r1.hand_to_mouth_kvw < r1.hand_to_mouth)

say("\n3. direction: a more generous benefit protects more (France, new data, spread 0.02)")
rs = [(rr, _solve(country_config("FR"; config = "GA", A = true, S = false, phi = 14.38, beta_spread = 0.02, rr = rr),
                  nothing; disk = false)) for rr in (0.30, 0.653, 0.90)]
for (rr, r) in rs
    @printf("   rr %.3f: agency %.4f, expected loss %.4f (income alone %.4f), drop on job loss %.4f, poor htm %.4f\n",
            rr, r.A, r.shock_loss, r.shock_loss_income, r.consumption_drop, r.hand_to_mouth_kvw)
end
check("agency rises with the benefit", rs[1][2].A < rs[2][2].A < rs[3][2].A)
check("savings make the consumption loss smaller than the income loss", all(r.shock_loss < r.shock_loss_income for (_, r) in rs))

say("\n4. reachability of the poor hand-to-mouth targets (new benefit, effort scale from the last calibration)")
for (code, phi) in (("FR", 14.38), ("DE", 19.0), ("IT", 9.2), ("US", 21.2))
    tgt = parse(Float64, country_rows()[code]["htm_target"])
    hs = [(sp, _solve(country_config(code; config = "GA", A = true, S = false, phi = phi, beta_spread = sp), nothing;
                      disk = false).hand_to_mouth_kvw) for sp in (0.0, 0.02, 0.04, 0.06, 0.08)]
    extra = code == "FR" ? [(bb, _solve(country_config(code; config = "GA", A = true, S = false, phi = phi, beta_spread = 0.0,
                                                       beta_bar = bb), nothing; disk = false).hand_to_mouth_kvw) for bb in (0.965, 0.97)] : []
    say(@sprintf("   %s target %.3f | by spread: ", code, tgt), join([@sprintf("%.2f:%.3f", s, h) for (s, h) in hs], "  "),
        isempty(extra) ? "" : " | spread 0, mean patience: " * join([@sprintf("%.3f:%.3f", b, h) for (b, h) in extra], "  "))
end
say(ok[] ? "\nALL CHECKS PASS" : "\nSOME CHECKS FAIL")

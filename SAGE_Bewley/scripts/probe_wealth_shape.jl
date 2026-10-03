# Which inputs move the two wealth moments of the version 3 fit INDEPENDENTLY?
# The hand-to-mouth share and median liquid wealth over income are two readings
# of the bottom of one distribution. Patience, its spread and the dispersion of
# income shocks all moved the pair along nearly one line in France
# (identification.jl, 2026-10-03), which is why Germany (both moments too high)
# and Italy (both too low) could not be fitted. This asks which other inputs,
# measured or conventional, move the pair off that line: the persistence of
# income, the replacement rate, job finding and separation. (The floor is left out: the
# household problem with the floor on does not always converge, an open item.)
# For each: the change in (hand-to-mouth, liquid wealth over income) for one
# step, and its angle to the patience direction in units of the survey bands
# (0 or 180 degrees: collinear with patience; 90: independent).
#
#   julia --project=scripts/run_env scripts/probe_wealth_shape.jl CODE [phi top_patience spread eta]
# With the four numbers, the point is given (a country with no version 3 file
# yet); without, the country's version 3 G calibration.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
code = uppercase(ARGS[1])
c0 = country_config(code; config = "G", v3 = true, missing_ok = length(ARGS) >= 5, S = false, A = false)
length(ARGS) >= 5 && (c0 = SAGEConfig(c0; phi = parse(Float64, ARGS[2]), beta_bar = parse(Float64, ARGS[3]), beta_spread = parse(Float64, ARGS[4]), eta_z = parse(Float64, ARGS[5])))
DATA = Dict("FR" => (htm = 0.2216, liq = 0.0590, bh = 0.020, bl = 0.030), "DE" => (htm = 0.2249, liq = 0.1397, bh = 0.022, bl = 0.030),
            "IT" => (htm = 0.1789, liq = 0.2718, bh = 0.058, bl = 0.056))[code]
at(c) = (r = solve_economy(c; cache = false); st = income_stats(c);
         (htm = r.hand_to_mouth_kvw, liq = r.wealth_p50 / r.median_income, s = st.s8020, iw = st.inwork60, mpc = r.mpc, drop = r.consumption_drop, e = r.mean_effort_employed))
steps = [
    ("top patience +0.005", c -> SAGEConfig(c; beta_bar = c.beta_bar + 0.005)),
    ("spread +0.02", c -> SAGEConfig(c; beta_spread = c.beta_spread + 0.02)),
    ("shock dispersion eta +0.02", c -> SAGEConfig(c; eta_z = c.eta_z + 0.02)),
    ("persistence rho +0.03", c -> SAGEConfig(c; rho = c.rho + 0.03)),
    ("persistence rho -0.10", c -> SAGEConfig(c; rho = c.rho - 0.10)),
    ("replacement rate +0.05", c -> SAGEConfig(c; rr = c.rr + 0.05)),
    ("replacement rate -0.05", c -> SAGEConfig(c; rr = c.rr - 0.05)),
    ("job finding +0.05", c -> SAGEConfig(c; f_find = c.f_find + 0.05)),
    ("separation +20%", c -> SAGEConfig(c; delta = c.delta .* 1.2)),
]
m0 = at(c0)
@printf("%s G, version 3, one asset, at phi %.3f, top patience %.4f, spread %.4f, eta %.4f, rho %.2f, replacement %.3f, job finding %.3f\n", code, c0.phi, c0.beta_bar, c0.beta_spread, c0.eta_z, c0.rho, c0.rr, c0.f_find)
@printf("here: hand-to-mouth %.4f (data %.4f), liquid/income %.4f (data %.4f) | S80/S20 %.2f, in-work poverty %.3f, MPC %.3f, drop on job loss %.3f, effort %.4f\n",
        m0.htm, DATA.htm, m0.liq, DATA.liq, m0.s, m0.iw, m0.mpc, m0.drop, m0.e)
need = [(DATA.htm - m0.htm) / DATA.bh, (DATA.liq - m0.liq) / DATA.bl]
@printf("needed move, in bands: hand-to-mouth %+.2f, liquid %+.2f\n\n", need...)
@printf("%-32s %9s %9s %8s %8s %8s %8s %8s | %s\n", "step", "d htm", "d liq", "d S8020", "d inwork", "d MPC", "d drop", "d effort", "angle to patience, cosine with the needed move")
pat = nothing
for (name, f) in steps
    m = try at(f(c0)) catch err; @printf("%-32s failed: %s\n", name, sprint(showerror, err)[1:min(end, 80)]); continue end
    d = [(m.htm - m0.htm) / DATA.bh, (m.liq - m0.liq) / DATA.bl]
    global pat; pat === nothing && (pat = d)
    ang = acosd(clamp(dot(d, pat) / (norm(d) * norm(pat) + 1e-12), -1, 1)); cs = dot(d, need) / (norm(d) * norm(need) + 1e-12)
    @printf("%-32s %+9.4f %+9.4f %+8.2f %+8.3f %+8.3f %+8.3f %+8.4f | %5.0f deg, %+.2f\n", name, m.htm - m0.htm, m.liq - m0.liq, m.s - m0.s, m.iw - m0.iw, m.mpc - m0.mpc, m.drop - m0.drop, m.e - m0.e, ang, cs)
    flush(stdout)
end
println("DONE")

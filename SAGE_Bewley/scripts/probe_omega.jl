# How much does the private share omega, which no target owns, matter? For each
# omega the social technology (kappa, sigma) is refitted to the same two
# participation targets on the same household families (omega enters only the
# belonging argument omega + (1 - omega) r, not the household problem), and the
# multiplier at the fit is read off. If the fit is as good at every omega, the
# participation data cannot tell them apart, and the multiplier is conditional
# on the omega assumed.
#
#   julia --project=scripts/run_env scripts/probe_omega.jl [CODE]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
row = country_rows()[code]
part = (parse(Float64, row["part_low"]), parse(Float64, row["part_high"]))
c = country_config(code; config = "GSA", S = true, A = true)
t = @elapsed fams = collect(build_families(SAGEConfig(c; unemployed_ratio = nothing), nothing; disk = false))
emp = employment_mask(c)
fi = [impose_unemployed_ratio(f, emp, c.unemployed_ratio) for f in fams]
@printf("%s G+S+A: participation targets %.3f, %.3f; families in %.1f min; calibrated omega %.2f, kappa %.2f, sigma %.2f\n",
        code, part[1], part[2], t / 60, c.omega, c.kappa, c.sigma_m)
@printf("%6s %8s %8s %10s %8s %8s %11s\n", "omega", "kappa", "sigma", "root loss", "low", "high", "multiplier")
for om in (0.0, 0.15, 0.30, 0.50, 0.70, 0.90)
    rows = scan_technology(SAGEConfig(c; omega = om), fi, collect(0.30:0.02:3.00), collect(2.0:0.05:25.0); targets = part, selected_only = true)
    if isempty(rows)
        @printf("%6.2f   no stable equilibrium in the scan\n", om); continue
    end
    b = rows[argmin([r.loss for r in rows])]
    @printf("%6.2f %8.2f %8.2f %10.4f %8.4f %8.4f %11.2f\n", om, b.κ, b.σ, b.loss, b.lo, b.hi, b.mult)
    flush(stdout)
end
println("DONE")

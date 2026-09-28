# How many belonging scales does a family need? The calibrated France G+S+A at
# the default grid (83 scales) against coarser ones, on the reference's
# thresholds, for every headline output and for the technology fit.
#
#   SAGE_WORKERS=4 julia --project=scripts/run_env scripts/grid_test.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
say(args...) = (println(args...); flush(stdout))

c = country_config("FR"; config = "GSA", S = true, A = true)
grids = [("default, 83", UGRID_DEFAULT),
         ("half, 42", vcat(collect(0.0:0.4:12.0), collect(13.0:1.0:16.0), collect(18.0:2.0:30.0))),
         ("third, 28", vcat(collect(0.0:0.6:12.0), collect(13.5:1.5:16.5), collect(19.0:3.0:30.0)))]
ref = nothing
row = country_rows()["FR"]
targets = (parse(Float64, row["part_low"]), parse(Float64, row["part_high"]))
for (name, U) in grids
    t = @elapsed r = solve_economy(SAGEConfig(c; ugrid = U); thresholds = ref === nothing ? nothing : [(ref.ypov, ref.abar)])
    global ref = ref === nothing ? r : ref
    fi = families(SAGEConfig(c; ugrid = U); thresholds = [(ref.ypov, ref.abar)])
    rows = scan_technology(SAGEConfig(c; ugrid = U), fi, collect(0.30:0.02:3.00), collect(2.0:0.05:25.0);
                           targets = targets, selected_only = true)
    best = rows[argmin([x.loss for x in rows])]; ok = [x for x in rows if x.loss <= 0.035]
    say(@sprintf("%-12s %5.1f min | part %.5f mult %.3f A %.5f A_cond %.5f htm %.5f effort %.5f room %.4f mpc %.4f | scan best kappa %.2f sigma %.2f loss %.4f, band %.2f to %.2f",
                 name, t / 60, r.rate, 1 / (1 - r.slope), r.A, r.A_cond, r.hand_to_mouth_kvw, r.mean_effort_employed,
                 r.room, r.mpc, best.κ, best.σ, best.loss, minimum(x.mult for x in ok), maximum(x.mult for x in ok)))
end
say("DONE")

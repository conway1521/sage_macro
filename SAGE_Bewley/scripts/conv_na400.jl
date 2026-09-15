# The doubled asset grid convergence row, on its own. Each worker needs 4 to 5
# GB at na 400, which thirteen workers cannot fit in 24 GB, so this runs apart
# from the suite on fewer workers (SAGE_WORKERS). Same comparison as the suite:
# France's calibrated G+S+A, anchored to the reference's thresholds, settled if
# agency moves within 0.005 and the median within 0.002.
#
#   SAGE_WORKERS=4 julia --project=. scripts/conv_na400.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
const FF = france_footing()
println("France's footing: ", FF.source, " | workers ", nworkers()); flush(stdout)
base = SAGEConfig(FF.config; S = true, A = true)
ref = solve_economy(base)
@printf("reference, na 200: agency %.6f, asset poverty %.6f, median %.6f\n", ref.A, ref.asset_poor, ref.median_income)
flush(stdout)
t0 = time()
r = solve_economy(SAGEConfig(base; na = 400); thresholds = [(ref.ypov, ref.abar)])
d = r.A - ref.A; dm = r.median_income - ref.median_income
@printf("asset grid, na 400 against 200: agency %.6f, asset poverty %.6f, move %+.5f, median move %+.5f  [%.0f min]\n",
        r.A, r.asset_poor, d, dm, (time() - t0) / 60)
println(abs(d) <= 0.005 && abs(dm) <= 0.002 ? "SETTLED" : "NOT SETTLED")
println("DONE")

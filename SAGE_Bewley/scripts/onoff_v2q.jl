# Version 2's on/off test (V3_START.md section 137): a switch turned off must give the model without it, exactly.
# Each job solves one variant and prints every scalar result at full precision; pairs are compared afterwards
# (compare_onoff_v2q.py, on the logs). A pair is the full configuration Y with a switch off ("Y-S", "Y-A", "Y-SA")
# against X@Y: Y with the switch's own parameters taken from X's own file instead (S: the flag, kappa, sigma_m and
# the belonging grid; A: the flag, dread and job search). Everything else is Y's, including what each configuration's
# calibration fits for itself (patience, the job's hours phi, the floor, the permanent-income nodes): those differ
# across configurations by design (section 137, first comparison). The pair agrees exactly only if a switch that is off
# leaves nothing of its own parameters behind.
#   GS-S    against  G@GS      GA-A    against  G@GA      GSA-S   against  GA@GSA
#   GSA-A   against  GS@GSA    GSA-SA  against  G@GSA
#
#   julia --project=scripts/run_env scripts/onoff_v2q.jl CODE VARIANT[,VARIANT...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1])
say(x...) = (println(x...); flush(stdout))
OWN = Dict('S' => (:S, :kappa, :sigma_m, :ugrid),
           'A' => (:A, :dread, :dread_mode, :dread_horizon, :search, :search_gamma, :search_kU, :search_kL, :search_kq, :out_ls, :out_M, :out_betaY))
# X@Y: Y's configuration with the own parameters of every switch on in Y and off in X taken from X's file
function at(x, y)
    cx, cy = quarterly_calibrated(code, x), quarterly_calibrated(code, y)
    kw = Dict{Symbol,Any}()
    for sw in ('S', 'A')
        occursin(sw, y) && !occursin(sw, x) && for f in OWN[sw]; kw[f] = getfield(cx, f); end
    end
    SAGEConfig(cy; kw...)
end
function variant(v)
    if occursin('@', v)
        x, y = split(v, '@'); return at(String(x), String(y))
    elseif occursin('-', v)
        y, off = split(v, '-'); return SAGEConfig(quarterly_calibrated(code, String(y)); (Symbol(string(sw)) => false for sw in off)...)
    end
    quarterly_calibrated(code, v)
end
for v in uppercase.(split(ARGS[2], ","))
c = variant(v)
say(@sprintf("%s %s: S %s, A %s, search %s, dread %s (%s), patience %.6f, cell gap %.6f", code, v, c.S, c.A, c.search, c.dread, c.dread_mode, c.beta_bar, c.beta_cell[1]))
t = @elapsed r = solve_economy(c; cache = false)
say(@sprintf("%s solved in %.1f min", v, t / 60))
for k in keys(r)
    x = r[k]
    if x isa Real
        say(@sprintf("RES %s %s = %.17g", v, k, x))
    elseif x isa Tuple && !isempty(x) && all(y -> y isa Real, x)
        for (i, y) in enumerate(x); say(@sprintf("RES %s %s[%d] = %.17g", v, k, i, y)); end
    elseif x isa Tuple && !isempty(x) && all(y -> y isa AbstractVector{<:Real}, x)
        for (i, y) in enumerate(x), (j, z) in enumerate(y); say(@sprintf("RES %s %s[%d][%d] = %.17g", v, k, i, j, z)); end
    end
end
end
println("DONE")

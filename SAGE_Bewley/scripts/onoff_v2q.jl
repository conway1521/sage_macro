# Version 2's on/off test (V3_START.md section 137): a switch turned off must give the model without it, exactly.
# Each job solves one variant and prints every scalar result at full precision; pairs are compared afterwards
# (compare_onoff_v2q.py, on the logs). The pairs, all at the calibrated parameters of version 2:
#   GS-S    G+S with S off                    against  G       (G+S keeps G's patience)
#   GA-A    G+A with A off                    against  G@GA    G at G+A's patience and gap
#   GSA-S   G+S+A with S off                  against  GA@GSA  G+A at G+S+A's patience and gap
#   GSA-A   G+S+A with A off                  against  GS@GSA  G+S at G+S+A's patience, gap, kappa and sigma
#   GSA-SA  G+S+A with both off               against  G@GA    (G+S+A keeps G+A's patience)
# "Off" sets the switch to false on the calibrated configuration and changes nothing else, so any difference is
# a parameter that a switch leaves behind.
#
#   julia --project=scripts/run_env scripts/onoff_v2q.jl CODE VARIANT[,VARIANT...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1])
say(x...) = (println(x...); flush(stdout))
pat(c, from) = SAGEConfig(c; beta_bar = from.beta_bar, beta_cell = from.beta_cell)
variant(v) = if v == "G"
    quarterly_calibrated(code, "G")
elseif v == "GS-S"
    SAGEConfig(quarterly_calibrated(code, "GS"); S = false)
elseif v == "GA-A"
    SAGEConfig(quarterly_calibrated(code, "GA"); A = false)
elseif v == "G@GA"
    pat(quarterly_calibrated(code, "G"), quarterly_calibrated(code, "GA"))
elseif v == "GSA-S"
    SAGEConfig(quarterly_calibrated(code, "GSA"); S = false)
elseif v == "GA@GSA"
    (s = quarterly_calibrated(code, "GSA"); SAGEConfig(pat(quarterly_calibrated(code, "GA"), s); dread_mode = s.dread_mode))
elseif v == "GSA-A"
    SAGEConfig(quarterly_calibrated(code, "GSA"); A = false)
elseif v == "GS@GSA"
    (s = quarterly_calibrated(code, "GSA"); SAGEConfig(pat(quarterly_calibrated(code, "GS"), s); kappa = s.kappa, sigma_m = s.sigma_m))
elseif v == "GSA-SA"
    SAGEConfig(quarterly_calibrated(code, "GSA"); S = false, A = false)
else
    error("unknown variant $v")
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

# Stable participation equilibria of every economy in the policy tests.
#
#   julia --project=. scripts/policy_equilibria.jl FR DE IT
#
# Takes the technology points from policy_results_<CODE>.csv and the subsidy
# levy from policy_tests_<CODE>.txt, and the response families from the disk
# cache, so it solves no households once the policy tests have run. For each
# economy it lists every stable fixed point of the participation map. The
# solver selects the highest. When a policy removes the equilibrium the
# baseline sat on, the selected rate jumps to another branch, and the reported
# participation effect is a jump across a fold rather than a slope.
include(joinpath(@__DIR__, "modular_stack.jl"))
using Printf, LinearAlgebra

const TAU = 0.20
const DRR = 0.10

function stable_points(c, fams)
    cs = cells_of(c)
    rs = map(f -> [n.rate for n in f], fams)
    grid = collect(range(0.0, 1.0, length = 401))
    out = [sum(cs[g].share * dot(node_weights(c, cs[g].B, c.omega + (1 - c.omega) * r), rs[g]) for g in 1:2)
           for r in grid]
    pts = Tuple{Float64,Float64}[]
    for i in 1:400
        d1 = out[i] - grid[i]; d2 = out[i+1] - grid[i+1]
        (d1 == 0 || sign(d1) != sign(d2)) || continue
        sl = (out[i+1] - out[i]) / (grid[i+1] - grid[i]); sl < 1 || continue
        push!(pts, (grid[i] + d1 / (d1 - d2) * (grid[i+1] - grid[i]), sl))
    end
    pts
end

function read_csv(path)
    lines = readlines(path); head = split(lines[1], ",")
    [Dict(zip(head, split(l, ","))) for l in lines[2:end]]
end

"The levy each configuration's budget closed at: the last iteration's input."
function levies(path)
    d = Dict{String,Float64}(); cfg = ""
    for l in eachline(path)
        m = match(r"^[A-Z]{2} (GSA|GS|GA|G) \|", l); m === nothing || (cfg = m[1])
        m = match(r"levy ([0-9.]+) ->", l); m === nothing || (d[cfg] = parse(Float64, m[1]))
    end
    d
end

for code in ARGS
    rows = read_csv(joinpath(@__DIR__, "policy_results_$(code).csv"))
    T = levies(joinpath(@__DIR__, "policy_tests_$(code).txt"))
    for cfg in ("GSA", "GS")
        isfile(joinpath(@__DIR__, cfg == "GSA" ? "calibration_country_$(code).txt" :
                                                 "calibration_country_$(code)_$(cfg).txt")) || continue
        any(r -> r["config"] == cfg, rows) || continue
        A_ = cfg == "GSA"
        base = country_config(code; config = cfg, S = true, A = A_)
        b0 = solve_economy(base); thr = [(b0.ypov, b0.abar)]
        pols = Pair{String,SAGEConfig}["baseline" => base,
                                       "subsidy" => SAGEConfig(base; subsidy = TAU, levy_employed = T[cfg])]
        A_ && push!(pols, "empowerment" => SAGEConfig(base; alpha = ((base.alpha[1] + base.alpha[2]) / 2, base.alpha[2])))
        push!(pols, "ui_up" => SAGEConfig(base; rr = base.rr + DRR), "ui_down" => SAGEConfig(base; rr = base.rr - DRR))
        techs = unique([(r["technology"], parse(Float64, r["kappa"]), parse(Float64, r["sigma"]))
                        for r in rows if r["config"] == cfg])
        println("\n", code, " ", cfg)
        for (name, pc) in pols
            fi = families(pc; thresholds = thr)
            for (tag, κ, σ) in techs
                sp = stable_points(SAGEConfig(pc; kappa = κ, sigma_m = σ), fi)
                @printf("  %-12s %-16s %d stable: %s\n", name, tag, length(sp),
                        join([@sprintf("%.4f (mult %.1f)", r, 1 / (1 - s)) for (r, s) in sp], ", "))
            end
            flush(stdout)
        end
    end
end

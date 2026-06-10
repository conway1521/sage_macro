# S+A paper, main analysis. Stages:
#   1. Build response families r(u; alpha) for alpha in {0.765, 0.911, 0.838}
#      (low, high, counterfactual mean) at production resolution; save to disk.
#   2. Calibrate (kappa, sigma_taste) to the INSEE 2013 participation moments:
#      group rates near (0.25, 0.45) at a stable equilibrium, aggregate ~0.35.
#   3. Trace the calibrated map: all equilibria, group rates, taste gradient.
#   4. Decompose the education gradient: taste (B) channel vs agency (alpha,
#      opportunity-cost) channel.
#   5. Policy: budget-balanced 20 percent make-work-pay subsidy. Does
#      activation tip the economy out of the participating equilibrium?
#   6. Empowerment: raise low-education agency to the population mean. The
#      time-price tension: does empowerment erode participation?
#
#   julia --project=. scripts/sa_main.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles

const OMEGA = 0.30
const FAMFILE = joinpath(@__DIR__, "sa_families.txt")

println("[1] Response families (production grid)")
fams = Dict{Float64,Tuple{Vector{Float64},Vector{Float64},Vector{Float64}}}()
if isfile(FAMFILE)
    d = readdlm(FAMFILE, '\t'; skipstart = 1)
    u = d[:, 1]
    fams[0.765] = (u, d[:, 2], d[:, 3])
    fams[0.911] = (u, d[:, 4], d[:, 5])
    fams[0.838] = (u, d[:, 6], d[:, 7])
    println("    families loaded from sa_families.txt")
else
    for α in (0.765, 0.911, 0.838)
        fams[α] = response_family(α; verbose = false)
        @printf("    family alpha=%.3f built: rate range [%.3f, %.3f]\n",
                α, minimum(fams[α][2]), maximum(fams[α][2]))
        flush(stdout)
    end
    open(FAMFILE, "w") do io
        u = fams[0.765][1]
        hdr = ["u", "r765", "mi765", "r911", "mi911", "r838", "mi838"]
        println(io, join(hdr, '\t'))
        for i in eachindex(u)
            println(io, join([u[i], fams[0.765][2][i], fams[0.765][3][i],
                              fams[0.911][2][i], fams[0.911][3][i],
                              fams[0.838][2][i], fams[0.838][3][i]], '\t'))
        end
    end
    println("    families saved to sa_families.txt")
end

flow = fams[0.765]; fhigh = fams[0.911]; fmid = fams[0.838]

println("\n[2] Calibration to INSEE participation moments (targets 0.25, 0.45)")
function best_equilibrium(eqs, fl, fh, Bl, Bh, κ, ω, σ)
    best = nothing; bl = Inf
    for (r, st) in eqs
        st || continue
        agg, rlo, rhi = population_rate(fl, fh, Bl, Bh, κ, ω, σ, r)
        loss = (rlo - 0.25)^2 + (rhi - 0.45)^2
        loss < bl && (bl = loss; best = (r, rlo, rhi, loss))
    end
    best
end
function calibrate()
    bestpt = nothing; bl = Inf
    for κ in 0.5:0.25:40.0, σ in 0.2:0.1:1.2
        _, _, eqs = trace_map(flow, fhigh, CELL_LOW.B, CELL_HIGH.B, κ, OMEGA, σ)
        isempty(eqs) && continue
        b = best_equilibrium(eqs, flow, fhigh, CELL_LOW.B, CELL_HIGH.B, κ, OMEGA, σ)
        b === nothing && continue
        if b[4] < bl
            bl = b[4]; bestpt = (κ, σ, b...)
        end
    end
    bestpt
end
cal = calibrate()
κs, σs, req, rloeq, rhieq, loss = cal
@printf("    kappa* = %.2f  sigma* = %.2f  at stable equilibrium rate %.3f\n", κs, σs, req)
@printf("    group rates: low %.3f (target 0.25), high %.3f (target 0.45), loss %.5f\n",
        rloeq, rhieq, loss)
flush(stdout)

println("\n[3] The calibrated map and ALL equilibria")
grid, out, eqs = trace_map(flow, fhigh, CELL_LOW.B, CELL_HIGH.B, κs, OMEGA, σs)
for (r, st) in eqs
    agg, rlo, rhi = population_rate(flow, fhigh, CELL_LOW.B, CELL_HIGH.B, κs, OMEGA, σs, r)
    @printf("    equilibrium rate %.3f (%s): low %.3f high %.3f\n",
            r, st ? "stable" : "unstable", rlo, rhi)
end
writedlm(joinpath(@__DIR__, "sa_map_baseline.txt"), [grid out])
flush(stdout)

println("\n[4] Gradient decomposition at the calibrated equilibrium")
Bbar = 0.5 * (CELL_LOW.B + CELL_HIGH.B)
# (a) taste channel off: equal B, own alphas
_, _, eqB = trace_map(flow, fhigh, Bbar, Bbar, κs, OMEGA, σs)
stB = [e for e in eqB if e[2]]
if !isempty(stB)
    rB = stB[argmin([abs(e[1] - req) for e in stB])][1]
    _, rloB, rhiB = population_rate(flow, fhigh, Bbar, Bbar, κs, OMEGA, σs, rB)
    @printf("    equal B (taste off):   low %.3f  high %.3f  gap %.3f (baseline gap %.3f)\n",
            rloB, rhiB, rhiB - rloB, rhieq - rloeq)
end
# (b) agency channel off: equal alpha (mid family), own Bs
_, _, eqA = trace_map(fmid, fmid, CELL_LOW.B, CELL_HIGH.B, κs, OMEGA, σs)
stA = [e for e in eqA if e[2]]
if !isempty(stA)
    rA = stA[argmin([abs(e[1] - req) for e in stA])][1]
    _, rloA, rhiA = population_rate(fmid, fmid, CELL_LOW.B, CELL_HIGH.B, κs, OMEGA, σs, rA)
    @printf("    equal alpha (agency off): low %.3f  high %.3f  gap %.3f\n",
            rloA, rhiA, rhiA - rloA)
end
flush(stdout)

println("\n[4b] Where the moment fit and multiplicity overlap (interpolation scan)")
function region_scan(ω)
    fitted = 0; multi = 0; both = 0
    bestboth = nothing; bb = Inf
    for κ in 0.5:0.25:40.0, σ in 0.2:0.05:1.2
        _, _, e = trace_map(flow, fhigh, CELL_LOW.B, CELL_HIGH.B, κ, ω, σ)
        nst = count(x -> x[2], e)
        b = best_equilibrium(e, flow, fhigh, CELL_LOW.B, CELL_HIGH.B, κ, ω, σ)
        fit = b !== nothing && b[4] < 0.005      # within ~5pp on each moment
        fit && (fitted += 1)
        nst > 1 && (multi += 1)
        if fit && nst > 1
            both += 1
            b[4] < bb && (bb = b[4]; bestboth = (κ, σ, b[1], b[2], b[3], nst))
        end
    end
    @printf("    omega=%.2f: fit %d, multiple-stable %d, BOTH %d\n", ω, fitted, multi, both)
    if bestboth !== nothing
        κb, σb, rb, rlob, rhib, nstb = bestboth
        @printf("      best joint point: kappa=%.2f sigma=%.2f, eq %.3f (low %.3f high %.3f), %d stable eqs\n",
                κb, σb, rb, rlob, rhib, nstb)
    end
    flush(stdout)
    bestboth
end
joint = Dict{Float64,Any}()
for ω in (0.15, 0.30, 0.50)
    joint[ω] = region_scan(ω)
end

println("\n[5] Policy: budget-balanced 20 percent make-work-pay subsidy")
function policy_stage(κs, σs, req)
    τ = 0.20
    T = τ * population_meaninc(flow, fhigh, CELL_LOW.B, CELL_HIGH.B, κs, OMEGA, σs, req)
    gridP = Float64[]; outP = Float64[]; eqsP = Tuple{Float64,Bool}[]
    flowP = flow; fhighP = fhigh
    for it in 1:3
        @printf("    budget iteration %d: T = %.4f (building policy families)\n", it, T)
        flush(stdout)
        flowP  = response_family(0.765; subsidy = τ, lumptax = T, verbose = false)
        fhighP = response_family(0.911; subsidy = τ, lumptax = T, verbose = false)
        gridP, outP, eqsP = trace_map(flowP, fhighP, CELL_LOW.B, CELL_HIGH.B, κs, OMEGA, σs)
        sts = [e for e in eqsP if e[2]]
        rP = isempty(sts) ? 0.0 : sts[argmin([abs(e[1] - req) for e in sts])][1]
        Tnew = τ * population_meaninc(flowP, fhighP, CELL_LOW.B, CELL_HIGH.B, κs, OMEGA, σs, rP)
        abs(Tnew - T) < 1e-4 && (T = Tnew; break)
        T = Tnew
    end
    println("    policy equilibria:")
    for (r, st) in eqsP
        agg, rlo, rhi = population_rate(flowP, fhighP, CELL_LOW.B, CELL_HIGH.B, κs, OMEGA, σs, r)
        @printf("      rate %.3f (%s): low %.3f high %.3f\n", r, st ? "stable" : "unstable", rlo, rhi)
    end
    writedlm(joinpath(@__DIR__, "sa_map_policy.txt"), [gridP outP])
    open(joinpath(@__DIR__, "sa_policy_families.txt"), "w") do io
        u = flowP[1]
        println(io, join(["u", "r765", "mi765", "r911", "mi911"], '\t'))
        for i in eachindex(u)
            println(io, join([u[i], flowP[2][i], flowP[3][i], fhighP[2][i], fhighP[3][i]], '\t'))
        end
    end
    flush(stdout)
end
policy_stage(κs, σs, req)

println("\n[6] Empowerment: low-education agency raised to the mean (0.765 -> 0.838)")
gridE, outE, eqsE = trace_map(fmid, fhigh, CELL_LOW.B, CELL_HIGH.B, κs, OMEGA, σs)
for (r, st) in eqsE
    agg, rlo, rhi = population_rate(fmid, fhigh, CELL_LOW.B, CELL_HIGH.B, κs, OMEGA, σs, r)
    @printf("    equilibrium rate %.3f (%s): low %.3f high %.3f\n",
            r, st ? "stable" : "unstable", rlo, rhi)
end
writedlm(joinpath(@__DIR__, "sa_map_empower.txt"), [gridE outE])

@printf("\nCALIBRATED: kappa=%.2f sigma=%.2f omega=%.2f, equilibrium %.3f (low %.3f, high %.3f)\n",
        κs, σs, OMEGA, req, rloeq, rhieq)
println("DONE")

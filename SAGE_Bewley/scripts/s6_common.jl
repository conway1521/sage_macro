# Shared constants for stage 6. STAGE6.md Part 4 is the source of every value.
include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
include(joinpath(@__DIR__, "agency_core.jl"))
include(joinpath(@__DIR__, "unemployment_core.jl"))
using Printf, Statistics, DelimitedFiles, Serialization, LinearAlgebra

const THETA = 0.005
const GRID  = (a_max = 4.0, pexp = 3.0)
const NA, NE = 200, 80
const UGRID = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
const NQ = 2000
const MONTHS = 3.0

# labour market, STAGE6.md Part 4
const LTU_SHARE = 0.233                      # Eurostat une_ltu_a, FR 2024
const F_FIND    = 1.0 - LTU_SHARE            # 0.767
const U_LOW, U_HIGH = 0.094, 0.050           # INSEE 2024, non-tertiary (implied) / tertiary
const DELTA_LOW  = U_LOW  * F_FIND / (1 - U_LOW)
const DELTA_HIGH = U_HIGH * F_FIND / (1 - U_HIGH)
const RR = 0.68                              # Tresor-Eco 188, single, initial NRR
const RR_FLOOR = 0.57                        # OECD TaxBEN France 2025, statutory floor

const CELLS = ((name = "low edu",  share = 0.5, α = CELL_LOW.α,  B = CELL_LOW.B,  δ = DELTA_LOW),
               (name = "high edu", share = 0.5, α = CELL_HIGH.α, B = CELL_HIGH.B, δ = DELTA_HIGH))

const CACHE5 = joinpath(@__DIR__, @sprintf("cache_l5_theta%.4f_amax%.1f_pexp%.1f_ne%d",
                                          THETA, GRID.a_max, GRID.pexp, NE))

"Read a stage-6 results file (key = value) into a Dict."
function read_results(tag = "")
    d = Dict{String,Float64}()
    for ln in eachline(joinpath(@__DIR__, "sa_stage6_results" * tag * ".txt"))
        startswith(ln, "#") && continue
        p = split(strip(ln), '\t'); length(p) == 2 && (d[p[1]] = parse(Float64, p[2]))
    end
    d
end

# Stage 7 constants. STAGE7.md Parts 2 to 4 is the source of every value.
include(joinpath(@__DIR__, "s6_common.jl"))

const NBETA = 5               # equal-mass discount-factor points
const BBAR  = 0.96            # centre of the spread, the inherited discount factor

# Calibration targets added at this stage.
const HTM_TARGET = 0.30       # hand-to-mouth share, as inherited from the S paper
const RATIO_UE   = 0.17 / 0.35  # unemployed-to-employed membership, INSEE Premiere 1327
const R_LOW, R_HIGH = 0.25, 0.45  # group participation, INSEE, as in the S+A paper

"""
    beta_types(nabla; twosided = false)

Discount-factor nodes and equal weights. The symmetric form of Carroll,
Slacalek, Tokuoka and White (2017) is capped by stationarity at a spread of
about 0.019 around 0.96, and `s7_probe.txt` shows that whole admissible range
moves the hand-to-mouth share by three points against the nineteen needed. The
binding direction is impatience, and impatience faces no stationarity limit,
so the default here spreads DOWNWARD from the inherited discount factor:
uniform on [0.96 - nabla, 0.96], five equal-mass midpoints. The patient end is
the inherited value, so no household is closer to the stationarity boundary
than the model already was.
"""
function beta_types(∇; twosided = false)
    ∇ <= 0 && return ([BBAR], [1.0])
    b = twosided ? beta_nodes(∇; bbar = BBAR, n = NBETA) :
                   [BBAR - ∇ + ∇ * (2i - 1) / (2 * NBETA) for i in 1:NBETA]
    (b, fill(1 / length(b), length(b)))
end

"Belonging-payoff scale by state: `zeta` in the unemployed states, one in the
employed ones. See SAGEParams.belong_scale for what it represents."
function belong_scale_vec(ζ, employed)
    ζ == 1.0 && return Float64[]
    [e ? 1.0 : ζ for e in employed]
end

"Read a stage-7 results file (key = value) into a Dict."
function read_results7(tag = "")
    d = Dict{String,Float64}()
    for ln in eachline(joinpath(@__DIR__, "sa_stage7_results" * tag * ".txt"))
        startswith(ln, "#") && continue
        p = split(strip(ln), '\t'); length(p) == 2 && (d[p[1]] = parse(Float64, p[2]))
    end
    d
end

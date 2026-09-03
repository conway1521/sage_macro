# Cross-country robustness for the S+A policy results. The SOCIAL TECHNOLOGY
# (interaction strength kappa, taste dispersion sigma_m, private share omega)
# is held at the French calibration; only the country's agency gap alpha and
# belonging tastes B move, taken from the engine's country rows. So this asks
# a specific question: given the same social technology, does the sign and
# rough size of the policy results survive the observed cross-country spread
# in agency and belonging? It is robustness, not seven separate calibrations.
#
#   julia --project=. scripts/sa_countries.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using Printf, Statistics

const OMEGA = 0.30; const KAPPA = 10.0; const SIGMA = 0.5
const SUB = 0.20        # work subsidy rate
const RHO = 0.25        # Gift Aid style credit

"Response family under a given fiscal configuration."
function build(α, T; subsidy = 0.0, partcredit = 0.0, nu = 41, na = 200, ne = 40)
    u = collect(range(0.0, 60.0, length = nu))
    r = Float64[]; mi = Float64[]; pb = Float64[]
    for uu in u
        p = update(cell_params(α; na = na, ne = ne, subsidy = subsidy, lumptax = T);
                   social_strength = uu, partcredit = partcredit)
        _, rate, m, b = solve_participation(p, 1.0)
        push!(r, rate); push!(mi, m); push!(pb, b)
    end
    (u, r, mi, pb)
end

function eqr(fl, fh, Bl, Bh)
    _, _, e = trace_map(fl, fh, Bl, Bh, KAPPA, OMEGA, SIGMA)
    s = [x for x in e if x[2]]
    isempty(s) ? NaN : s[argmax([x[1] for x in s])][1]
end
popmi(fl, fh, Bl, Bh, r) = population_meaninc(fl, fh, Bl, Bh, KAPPA, OMEGA, SIGMA, r)
cell(fam, B, r, col) = begin
    ms = taste_nodes_ln(SIGMA; n = 15); arg = OMEGA + (1-OMEGA)*clamp(r,0.0,1.0)
    mean(interp(fam[1], fam[col], KAPPA*m*B*arg) for m in ms)
end

@printf("%-3s | %-6s | %-6s | %-6s | %-6s | %-6s\n",
        "cty","alpha gap","base r","subsidy","credit","dSub/dCred")
results = []
for code in ("FR","DE","IT","US","CO","ZA","CN")
    p = country_params(code); αl, αh = p.α[1], p.α[2]; Bl, Bh = p.B[1], p.B[2]
    # baseline
    fl = build(αl, 0.0); fh = build(αh, 0.0)
    r0 = eqr(fl, fh, Bl, Bh); mi0 = popmi(fl, fh, Bl, Bh, r0)
    # financed work subsidy
    T = SUB*mi0; local rs
    for _ in 1:2
        sl = build(αl, T; subsidy = SUB); sh = build(αh, T; subsidy = SUB)
        rs = eqr(sl, sh, Bl, Bh)
        T = SUB*popmi(sl, sh, Bl, Bh, rs)
    end
    # financed participation credit (Gift Aid rate)
    Tc = 0.0; local rc
    for _ in 1:2
        cl = build(αl, Tc; partcredit = RHO); ch = build(αh, Tc; partcredit = RHO)
        rc = eqr(cl, ch, Bl, Bh)
        pbl = cell(cl, Bl, rc, 4); pbh = cell(ch, Bh, rc, 4)
        Tc = QBAR*RHO*(0.5*pbl + 0.5*pbh)
    end
    push!(results, (code=code, gap=αh-αl, r0=r0, rs=rs, rc=rc))
    @printf("%-3s |  %.3f     | %.3f  | %.3f   | %.3f  | %+.3f / %+.3f\n",
            code, αh-αl, r0, rs, rc, rs-r0, rc-r0)
    flush(stdout)
end
println("\nDONE")

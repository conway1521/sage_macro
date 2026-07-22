# WISE benchmark (collaboration plan, task 3.1). Set the model's country
# orderings on agency and equilibrium cohesion beside the WISE Recoupling
# Agency and Solidarity indices (Lima de Miranda and Snower 2020), and report
# how well the orderings agree. This is the artefact the outreach leads with:
# the structural model's predictions set against the measurement programme's
# own published indices.
#
# The two comparisons are not on equal footing, and the script says so.
#   Agency: the model's mean agency (share-weighted alpha, calibrated from OECD
#     How's Life) against the WISE Agency Index (labour insecurity, vulnerable
#     employment, life expectancy, education, institutions). Different
#     constructs, so this is a calibration-consistency check.
#   Solidarity: the model's EQUILIBRIUM cohesion Q = E[1-e], an endogenous
#     output of the solve, against the WISE Solidarity Index. This is the real
#     test, with one honest caveat: the belonging taste B is calibrated partly
#     from social-support data, so some cohesion information enters upstream.
#
#   julia --project=. scripts/wise_benchmark.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using DelimitedFiles, Printf, Statistics, LinearAlgebra
ENV["GKSwstype"] = "100"
using Plots
gr()

const YEAR = 2018
const ISO = Dict("FR"=>"FRA","DE"=>"DEU","IT"=>"ITA","US"=>"USA","CN"=>"CHN","ZA"=>"ZAF")
const CODES = ["FR","DE","IT","US","CN","ZA"]          # the six WISE covers
const CLEAN = ["FR","DE","IT","US"]                     # OECD, no data-quality caveats

# ---------- WISE indices at the reference year ------------------------------
W = readdlm(joinpath(@__DIR__, "..", "..", "data", "wise_recoupling.csv"), ','; skipstart = 1)
wise = Dict{String,NamedTuple{(:agency,:sol),Tuple{Float64,Float64}}}()
for i in 1:size(W,1)
    (W[i,3] isa Number && Int(W[i,3]) == YEAR) || continue
    wise[String(W[i,2])] = (agency = Float64(W[i,4]), sol = Float64(W[i,5]))
end

# ---------- model orderings --------------------------------------------------
"Share-weighted mean agency and equilibrium cohesion Q for a country."
function model_country(code)
    p = country_params(code)
    s = solve_model(p)
    zm = vec(sum(s.λ, dims = 1)); zm ./= sum(zm)     # stationary marginal over z
    (agency = dot(zm, p.α), Q = s.Q)
end

rows = NamedTuple[]
for code in CODES
    m = model_country(code); w = wise[ISO[code]]
    push!(rows, (code = code, m_agency = m.agency, m_Q = m.Q,
                 w_agency = w.agency, w_sol = w.sol))
end

# ---------- Spearman rank correlation ---------------------------------------
_rank(v) = invperm(sortperm(v))
spearman(x, y) = cor(Float64.(_rank(x)), Float64.(_rank(y)))

function report(sub)
    idx = [findfirst(r -> r.code == c, rows) for c in sub]
    ma = [rows[i].m_agency for i in idx]; wa = [rows[i].w_agency for i in idx]
    mq = [rows[i].m_Q for i in idx];      ws = [rows[i].w_sol for i in idx]
    (agency = spearman(ma, wa), sol = spearman(mq, ws), n = length(sub))
end

# ---------- output -----------------------------------------------------------
println("WISE benchmark, reference year $YEAR")
println("model orderings vs Recoupling indices\n")
@printf("%-3s | %-18s | %-18s\n", "cty", "agency  model/WISE", "cohesion  model/WISE")
for r in rows
    @printf("%-3s |   %.3f / %.2f     |    %.3f / %.2f\n",
            r.code, r.m_agency, r.w_agency, r.m_Q, r.w_sol)
end

all6 = report(CODES); oecd4 = report(CLEAN)
println()
@printf("Spearman rank correlation (all %d):   agency %+.2f,  solidarity %+.2f\n",
        all6.n, all6.agency, all6.sol)
@printf("Spearman rank correlation (OECD %d):  agency %+.2f,  solidarity %+.2f\n",
        oecd4.n, oecd4.agency, oecd4.sol)
println("\n(China and South Africa carry the authors' data-quality caveats and the")
println(" model's one-asset limits, so the OECD-only row is the cleaner read.)")

# ---------- figure: rank vs rank --------------------------------------------
function panel(mv, wv, title, rho)
    mr = _rank(mv); wr = _rank(wv); n = length(mv)
    pl = plot([1,n],[1,n], c=:gray, ls=:dash, label="", legend=false,
              title="$title  (Spearman $(@sprintf("%+.2f", rho)))",
              xlabel="model rank", ylabel="WISE rank", xlims=(0.5,n+0.5), ylims=(0.5,n+0.5),
              xticks=1:n, yticks=1:n)
    scatter!(pl, mr, wr, c=RGB(0.17,0.35,0.62), ms=6)
    for i in 1:n
        annotate!(pl, mr[i]+0.12, wr[i]+0.16, text(rows[i].code, 8, :left))
    end
    pl
end
ma = [r.m_agency for r in rows]; wa = [r.w_agency for r in rows]
mq = [r.m_Q for r in rows];      ws = [r.w_sol for r in rows]
fig = plot(panel(ma, wa, "Agency", all6.agency),
           panel(mq, ws, "Cohesion vs Solidarity", all6.sol),
           layout=(1,2), size=(900,380), bottom_margin=5Plots.mm)
savefig(fig, joinpath(@__DIR__, "..", "..", "paper", "figures", "wise_benchmark.png"))

# ---------- save the table ---------------------------------------------------
open(joinpath(@__DIR__, "wise_benchmark.txt"), "w") do io
    println(io, join(["code","model_agency","wise_agency","model_Q","wise_solidarity"], '\t'))
    for r in rows
        println(io, join([r.code, round(r.m_agency,digits=4), r.w_agency,
                          round(r.m_Q,digits=4), r.w_sol], '\t'))
    end
    println(io, "# Spearman all6: agency $(round(all6.agency,digits=2)) solidarity $(round(all6.sol,digits=2))")
    println(io, "# Spearman OECD4: agency $(round(oecd4.agency,digits=2)) solidarity $(round(oecd4.sol,digits=2))")
end
println("\nsaved wise_benchmark.txt and paper/figures/wise_benchmark.png")
println("DONE")

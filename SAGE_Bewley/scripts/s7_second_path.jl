# STAGE7.md Part 6, check 10: every taste node solved directly at its own
# belonging scale, no response family and no interpolation, pooled by mass.
# Shares nothing with the driver but the household solver and cell_summary.
include(joinpath(@__DIR__, "s7_workers.jl"))
const OMEGA = 0.30
const NABLA = 0.036
include(joinpath(@__DIR__, "s7_pop.jl"))
res = read_results7()
κ, σ, r = res["kappa"], res["sigma"], res["r_base"]
ypov, abar, T = res["ypov"], res["abar"], res["T_UI"]
const NDIRECT = 61
arg = OMEGA + (1 - OMEGA) * r
ms = taste_nodes_ln(σ; n = NDIRECT)
@printf("%d taste nodes per cell solved directly; kappa %.2f sigma %.3f r %.4f\n\n", NDIRECT, κ, σ, r)
acc = Dict{String,Float64}()
Wtot = nothing; agrid = nothing
for c in CELLS
    # Every (discount type, taste node) pair solved on its own, then mixed.
    # The stage-6 version of this file solved ONE parameter set per taste node,
    # which at stage 7 silently drops the discount heterogeneity and reproduces
    # the stage-6 economy instead; that is what the first run of this script
    # did, and it is why the mixing is spelled out here.
    bs, w = beta_types(NABLA)
    nt = length(bs)
    p0s = [cell_params_u(c.α; δ = c.δ, f = F_FIND, rr = RR, na = NA, ne = NE,
                         a_max = GRID.a_max, pexp = GRID.pexp, lumptax = T, β = b) for b in bs]
    p0 = p0s[1]
    jobs = [(i, j) for j in 1:NDIRECT for i in 1:nt]
    out = pmap(ij -> begin
            i, j = ij
            p = update(p0s[i]; social_strength = κ * ms[j] * c.B * arg)
            sol = solve_participation_logit(p, 1.0; theta = THETA, full = true)
            cell_summary(p, sol; thresholds = [(ypov, abar)])
        end, jobs)
    ds = [collapse(out[(j-1)*nt+1 : j*nt], w) for j in 1:NDIRECT]
    base = SAGEParams(α = fill(c.α, 2), B = fill(1.0, 2)); up = unemployment_process(base, c.δ, F_FIND)
    ag = SAGEBewley.exponential_grid(p0.a_min, p0.a_max, p0.na, p0.pexp)
    global agrid = ag
    nz = p0.nz
    W = sum(d.W for d in ds) ./ NDIRECT; mass = sum(d.mass for d in ds) ./ NDIRECT
    part = sum(d.part for d in ds) ./ NDIRECT; jinc = sum(d.jinc for d in ds) ./ NDIRECT; jboth = sum(d.jboth for d in ds) ./ NDIRECT
    rate = mean(d.rate for d in ds); minc = mean(d.minc for d in ds)
    ast = sum(share_below_interp(ag, view(W, i, :), abar) for i in 1:nz)
    un = sum(jinc) + ast - sum(jboth)
    mU = sum(mass[.!up.employed])
    A = c.α * (1 - un)
    @printf("%-9s rate %.4f (E %.4f, U %.4f)  inc %.4f asset %.4f union %.4f  U^a %.4f\n",
            c.name, rate, sum(part[up.employed]) / (1 - mU), sum(part[.!up.employed]) / mU, sum(jinc), ast, un, A)
    for (k, v) in (("rate", rate), ("inc", sum(jinc)), ("asset", ast), ("union", un), ("A", A), ("minc", minc))
        acc[k] = get(acc, k, 0.0) + c.share * v
    end
    global Wtot = Wtot === nothing ? c.share .* vec(sum(W, dims = 1)) : Wtot .+ c.share .* vec(sum(W, dims = 1))
    flush(stdout)
end
htm = share_below_interp(agrid, Wtot, (4 / 52) * acc["minc"])
println()
@printf("%-16s | %-8s %-8s %s\n", "quantity", "family", "direct", "difference")
println("-"^50)
for (nm, k, fk) in (("participation", "rate", "r_base"), ("income-poor", "inc", "inc_base"), ("asset-poor", "asset", "asset_base"),
                    ("union", "union", "union_base"), ("agency A", "A", "A_base"))
    @printf("%-16s | %.4f   %.4f   %+.4f\n", nm, res[fk], acc[k], acc[k] - res[fk])
end
@printf("%-16s | %.4f   %.4f   %+.4f\n", "hand-to-mouth", res["htm"], htm, htm - res["htm"])
println("DONE")

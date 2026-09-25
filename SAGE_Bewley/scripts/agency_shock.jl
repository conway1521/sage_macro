# Agency as protection against being knocked off course.
#
# Snower and Lima de Miranda (2020, section 3.3) write the agency component of
# wellbeing as alpha times (1 - p): alpha, how well a person's effort turns into
# outcomes, and (1 - p), how far outcomes stay in the person's own hands. An
# earlier stage read (1 - p) as freedom from asset poverty. That turned agency
# into a mirror of the hand-to-mouth share, which is calibrated, so the column
# returned its own target (MODULAR.md, 2026-09-25).
#
# Here p is the expected share of next year's consumption a household loses to
# unemployment: the chance of being out of work next year, times the shortfall
# of consumption then against what it would be in work at the same assets and
# productivity. It depends on the risk of job loss, the chance of finding work,
# the benefit, and the household's own savings, so the model produces it rather
# than reading it off an input. The same quantity from labour and benefit income
# alone, leaving savings out, is the model's counterpart of the OECD labour
# market insecurity indicator (Cazes, Hijzen and Saint-Martin 2015), and the gap
# between the two is what households' own buffers contribute. The consumption
# drop at the moment a job is lost is kept as a diagnostic against the
# consumption-smoothing literature (Gruber 1997; Ganong and Noel 2019).
#
# Also here, because it needs each household's own income: the hand-to-mouth
# share on the baseline definition of Kaplan, Violante and Weidner (2014): liquid
# balances no larger than half a two-week pay period's income, that is wealth at
# most one week of the household's own labour and benefit income. A one-asset
# model has no illiquid wealth, so its hand-to-mouth are their poor
# hand-to-mouth, and the targets are the poor shares.
#
# Everything is a sum over the stationary distribution, so it pools exactly
# across discount types and belonging scales, like every other family field.
# This file is part of the family cache key (SOLVER_FILES in sage_modular.jl):
# a change here rebuilds the families.

using Distributed

"""
    agency_summary(p, sol)

Per-state sums over the stationary distribution: `pmass` of lambda times p from
consumption, `pinc` of lambda times the same from labour and benefit income, and
`dmass`, over employed states, of lambda times the consumption drop if the job
were lost now at the same assets. States with zero productivity are the
unemployed ones and state u + nz/2 is the employed state with the same latent
productivity (see `unemployment_process`). Without unemployed states all three
are zero.
"""
function agency_summary(p::SAGEParams, sol)
    a = sol.a; λ = sol.lambda; P1 = sol.P1; na = p.na
    z, Π = SAGEBewley.income_process(p)
    ns = length(z)
    pmass = zeros(ns); pinc = zeros(ns); dmass = zeros(ns); hmass = zeros(ns)
    U = findall(==(0.0), z)
    nh = length(U)
    haveU = !isempty(U) && 2 * nh == ns
    # Expected consumption and labour-plus-benefit income at every grid point,
    # mixing the participation choice with its own probability, from the same
    # budget the solver uses.
    cbar = zeros(na, ns); ybar = zeros(na, ns)
    for s in 1:ns
        α = p.α[s]; credit = net_participation(p, α, z[s]); tr = transfer_at(p, s)
        for i in 1:na, d in (0, 1)
            w = d == 1 ? P1[i, s] : 1 - P1[i, s]
            w <= 0 && continue
            lab = (1 + p.subsidy) * α * sol.e_d[d+1][i, s] * z[s] * p.Z
            cbar[i, s] += w * (p.R * a[i] + lab - p.lumptax + credit * d + tr - sol.a_d[d+1][i, s])
            ybar[i, s] += w * (lab + tr)
        end
    end
    for s in 1:ns, i in 1:na
        m = λ[i, s]; m <= 0 && continue
        a[i] <= ybar[i, s] / 52 && (hmass[s] += m)
        haveU || continue
        pc = 0.0; py = 0.0
        for d in (0, 1)
            w = d == 1 ? P1[i, s] : 1 - P1[i, s]
            w <= 0 && continue
            ap = sol.a_d[d+1][i, s]
            for u in U
                pr = Π[s, u]; pr <= 0 && continue
                cE = SAGEBewley.interp_lin(a, view(cbar, :, u + nh), ap)
                cU = SAGEBewley.interp_lin(a, view(cbar, :, u), ap)
                yE = SAGEBewley.interp_lin(a, view(ybar, :, u + nh), ap)
                yU = SAGEBewley.interp_lin(a, view(ybar, :, u), ap)
                cE > 0 && (pc += w * pr * max(0.0, 1 - cU / cE))
                yE > 0 && (py += w * pr * max(0.0, 1 - yU / yE))
            end
        end
        pmass[s] += m * pc; pinc[s] += m * py
        s > nh && cbar[i, s] > 0 && (dmass[s] += m * max(0.0, 1 - cbar[i, s - nh] / cbar[i, s]))
    end
    (pmass = pmass, pinc = pinc, dmass = dmass, hmass = hmass)
end

"Mix the agency sums across discount types or belonging scales, as `collapse` does the rest."
collapse_agency(ds, w) = (pmass = sum(w[i] .* ds[i].pmass for i in eachindex(ds)),
                          pinc  = sum(w[i] .* ds[i].pinc  for i in eachindex(ds)),
                          dmass = sum(w[i] .* ds[i].dmass for i in eachindex(ds)),
                          hmass = sum(w[i] .* ds[i].hmass for i in eachindex(ds)))
collapse_all(ds, w) = merge(collapse(ds, w), collapse_agency(ds, w))

"""
    build_family_ag(p0s, ugrid, theta; weights, thresholds)

`build_family_u` with the agency sums added to every summary: the same
household problems in the same order, mixed the same way.
"""
function build_family_ag(p0s::Vector{SAGEParams}, ugrid, theta; weights, thresholds = nothing)
    nt = length(p0s); nu = length(ugrid)
    jobs = [(i, j) for j in 1:nu for i in 1:nt]
    solve1 = ij -> begin
        i, j = ij
        p = update(p0s[i]; social_strength = ugrid[j])
        s = solve_participation_logit(p, 1.0; theta = theta, full = true)
        merge(cell_summary(p, s; thresholds = thresholds), agency_summary(p, s))
    end
    out = nworkers() > 1 ? pmap(solve1, jobs) : [solve1(ij) for ij in jobs]
    [collapse_all(out[(j-1)*nt+1 : j*nt], weights) for j in 1:nu]
end

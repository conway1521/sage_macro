# A brute-force benchmark for households who choose their hours under the means-tested floor
# (V3_START.md section 94, item 4). The fast solver (endogenous grid, egm_core.jl) handles the kink
# where the floor starts with a rule: a household that could be on the floor is on it unless the
# choice found without the floor lifts it above the floor and is worth more. Here the same household
# problem is solved by plain value iteration with no rule at all: on a fine asset grid, next assets
# by full search, hours on a fine grid refined by golden section, and the floor as one more option
# (no work, resources topped up to the floor) whenever resources without work fall short of it.
# The two are compared at the fast solver's grid points, weighted by its stationary distribution.
#
# Problems: the households with control over their working time (A on, S off) in the lowest and
# a middle permanent-income type of each education cell, at the base's calibration of G+A.
#
# Set before the run, a pass is: on-floor status the same for 99% of the mass; consumption within
# 0.1% on average; mean hours of the employed within 0.5%; values within 1e-4 relative on average.
#
#   julia --project=scripts/run_env scripts/benchmark_chosen_hours.jl CODE [fine points] [hours points] [one problem: 1l 1m 2l 2m]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
NF = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 1500
NE = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 120
ONLY = length(ARGS) >= 4 ? ARGS[4] : ""          # e.g. 2m: cell 2, middle type alone (a finer benchmark where one failed)
results = Tuple{String,Bool}[]
check(name, ok) = (push!(results, (name, ok)); @printf("   -> %s: %s\n", name, ok ? "PASS" : "FAIL"); flush(stdout))

c = floor_effort(country_config(code; config = "GA", v3 = :v5m, S = false, A = true))
cfgT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
cs = cells_of(c)

function brute(p, egm; nf = NF, ne = NE, tol = 1e-8, maxit = 4000)
    af = SAGEBewley.exponential_grid(p.a_min, p.a_max, nf, p.pexp)
    z, Π = SAGEBewley.income_process(p); nz = length(z)
    κ = 1.0 + p.commute; X = p.cfloor
    w = [(1 + p.subsidy) * p.α[s] * z[s] * p.Z for s in 1:nz]
    oth = [-p.lumptax + transfer_at(p, s) for s in 1:nz]
    tfl = [floor_at(p, s) for s in 1:nz]
    lab(T) = p.Γ * p.ϕ * T^(1 + p.ψ) / (1 + p.ψ)
    u(cc) = cc > 0 ? p.Γ * cc^(1 - p.γ) / (1 - p.γ) : -Inf
    D = [p.dread > 0 ? dread_at(p, s, af[k]) : 0.0 for k in 1:nf, s in 1:nz]
    xmax = p.R * p.a_max + maximum(w) + maximum(oth) + X + 1.0
    xg = SAGEBewley.exponential_grid(1e-6, xmax, 2 * nf, p.pexp)
    nx = length(xg)
    # the fixed point is unique: start from the fast solver's values, read onto the fine grid
    V = [SAGEBewley.interp_lin(egm.a, view(egm.V, :, s), af[k]) for k in 1:nf, s in 1:nz]
    EV = similar(V); G = zeros(nx, nz); Vn = similar(V)
    Gat(s, x) = x <= xg[1] ? -Inf : SAGEBewley.interp_lin(xg, view(G, :, s), x)
    function best_e(s, a_)
        tmax = (1.0 - tfl[s]) / κ
        (w[s] <= 0 || tmax <= 0) && return (0.0, -lab(tfl[s]) + Gat(s, p.R * a_ + oth[s]))
        f(e) = -lab(tfl[s] + κ * e) + Gat(s, p.R * a_ + w[s] * e + oth[s])
        es = range(0.0, tmax, length = ne); vs = f.(es); j = argmax(vs)
        lo = es[max(j - 1, 1)]; hi = es[min(j + 1, ne)]
        for _ in 1:40                                   # golden section between the neighbours
            m1 = lo + 0.382 * (hi - lo); m2 = lo + 0.618 * (hi - lo)
            f(m1) < f(m2) ? (lo = m1) : (hi = m2)
        end
        e = 0.5 * (lo + hi); v = f(e)
        v >= vs[j] ? (e, v) : (es[j], vs[j])
    end
    it = 0
    for outer it in 1:maxit
        EV .= V * Π'
        Threads.@threads for s in 1:nz
            for ix in 1:nx                              # full search over next assets: no monotonicity assumed
                x = xg[ix]; b = -Inf
                for k in 1:nf
                    af[k] < x || break
                    v = u((x - af[k]) / p.pc) - D[k, s] + p.β * EV[k, s]
                    v > b && (b = v)
                end
                G[ix, s] = b
            end
        end
        for s in 1:nz, k in 1:nf
            _, vw = best_e(s, af[k])
            vf = p.R * af[k] + oth[s] < X ? -lab(tfl[s]) + Gat(s, X) : -Inf
            Vn[k, s] = max(vw, vf)
        end
        d = maximum(abs.(Vn .- V)); V, Vn = Vn, V
        d < tol && break
    end
    # policies at the fast solver's grid points
    na = length(egm.a)
    pol = map(Iterators.product(1:na, 1:nz)) do (i, s)
        a_ = egm.a[i]
        e, vw = best_e(s, a_)
        elig = p.R * a_ + oth[s] < X
        vf = elig ? -lab(tfl[s]) + Gat(s, X) : -Inf
        onf = vf > vw
        x = onf ? X : p.R * a_ + w[s] * e + oth[s]
        b = -Inf; kb = 1
        for k in 1:nf
            af[k] < x || break
            v = u((x - af[k]) / p.pc) - D[k, s] + p.β * EV[k, s]
            v > b && (b = v; kb = k)
        end
        (e = onf ? 0.0 : e, c = (x - af[kb]) / p.pc, floor = onf, v = max(vw, vf))
    end
    (pol = pol, iters = it, w = w)
end

probs = Any[]
for g in 1:2
    ps = [update(q; social_strength = 0.0) for q in params_of(cfgT, cs[g]) if isempty(q.effort_set) && !q.job_effort]
    isempty(ps) && continue
    zs = [q.Z for q in ps]; o = sortperm(zs)
    (ONLY == "" || ONLY == "$(g)l") && push!(probs, ("cell $g, lowest type", ps[o[1]]))
    (ONLY == "" || ONLY == "$(g)m") && push!(probs, ("cell $g, middle type", ps[o[cld(length(o), 2)]]))
end
@printf("%s G+A, households who choose their hours: %d problems | fine grid %d points, hours %d points refined\n", code, length(probs), NF, NE)
for (lab, p) in probs
    t0 = @elapsed egm = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
    t1 = @elapsed bf = brute(p, egm)
    na, nz = size(egm.lambda)
    m = egm.lambda; tot = sum(m)
    emp = [bf.w[s] > 0 for s in 1:nz]
    dfl = 0.0; dc = 0.0; dv = 0.0; dcmax = 0.0; hE = 0.0; hB = 0.0; mE = 0.0; fE = 0.0; fB = 0.0
    worst = (0.0, 0, 0); byq = zeros(3); mq = zeros(3)
    acdf = cumsum(vec(sum(m, dims = 2))) ./ tot; qof(i) = acdf[i] <= 1 / 3 ? 1 : acdf[i] <= 2 / 3 ? 2 : 3
    for s in 1:nz, i in 1:na
        q = m[i, s]; q > 0 || continue
        r = bf.pol[i, s]; ce = egm.c_d[1][i, s]; fe = egm.floor_d[1][i, s]
        dfl += q * (fe != r.floor)
        rel = abs(ce - r.c) / max(r.c, 1e-12); dc += q * rel; dcmax = max(dcmax, rel)
        byq[qof(i)] += q * rel; mq[qof(i)] += q
        q * rel > worst[1] && (worst = (q * rel, i, s))
        dv += q * abs(egm.V[i, s] - r.v) / max(abs(r.v), 1e-12)
        fE += q * fe; fB += q * r.floor
        if emp[s]
            mE += q; hE += q * egm.e_d[1][i, s]; hB += q * r.e
        end
    end
    dfl /= tot; dc /= tot; dv /= tot; fE /= tot; fB /= tot; hE /= mE; hB /= mE
    @printf("\n%s (permanent scale %.3f) | fast solver %.1f s, benchmark %.1f s in %d iterations\n", lab, p.Z, t0, t1, bf.iters)
    @printf("   on the floor: fast %.4f, benchmark %.4f of the mass | status differs for %.4f\n", fE, fB, dfl)
    @printf("   consumption: mean relative difference %.1e, largest %.1e | value: mean relative difference %.1e\n", dc, dcmax, dv)
    @printf("   mean hours of the employed: fast %.5f, benchmark %.5f (%+.2f%%)\n", hE, hB, 100 * (hE / hB - 1))
    @printf("   consumption gap by third of the wealth distribution: %.1e, %.1e, %.1e | largest contribution at assets %.3f (grid point %d of %d), state %d, mass %.1e\n",
            (byq ./ max.(mq, eps()))..., egm.a[worst[2]], worst[2], na, worst[3], m[worst[2], worst[3]])
    check("$lab: on-floor status the same for 99% of the mass", dfl < 0.01)
    check("$lab: consumption within 0.1% on average", dc < 1e-3)
    check("$lab: mean hours of the employed within 0.5%", abs(hE / hB - 1) < 5e-3)
    check("$lab: values within 1e-4 relative on average", dv < 1e-4)
end
nf_ = count(x -> !x[2], results)
@printf("\n%d of %d checks pass%s\n", length(results) - nf_, length(results), nf_ == 0 ? "" : "; FAILED: " * join([x[1] for x in results if !x[2]], "; "))
println("DONE")

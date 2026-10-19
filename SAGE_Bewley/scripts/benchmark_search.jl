# A brute-force benchmark for job search (scorecard: the benchmark extended to search; the methods review of
# 18 October). The fast solver (egm_core.jl) chooses the chance of finding work in closed form at each next-asset
# node, from the gap between the continuation values towards work and away from it, and splits each searching
# state's transition row accordingly. Here the same household problem is solved by plain value iteration with
# no closed form: next assets by full search on a fine grid, search effort by a grid of 201 values refined by
# golden section between the neighbours of the best, the means-tested floor as a top-up of resources, dread in
# choices as in the fast solver. The two are compared at the fast solver's grid points, weighted by its
# stationary distribution.
#
# Problems: households whose hours are set by the job (the large majority), lowest and middle permanent type of
# each education cell, at the G+A calibration with dread in choices and search (SAGE_DREAD_CHOICE=1).
#
# Set before the run, a pass is: on-floor status the same for 99% of the mass; consumption within 0.1% on
# average; values within 1e-4 relative on average; the chance of finding work within 0.005 on average over the
# searching states.
#
#   julia --project=scripts/run_env scripts/benchmark_search.jl CODE [fine points] [effort points]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
NF = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 1500
NX = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 201
results = Tuple{String,Bool}[]
check(name, ok) = (push!(results, (name, ok)); @printf("   -> %s: %s\n", name, ok ? "PASS" : "FAIL"); flush(stdout))

c = floor_effort(country_config(code; config = "GA", v3 = :v5m, S = false, A = true))
c.search || error("search is off: run with SAGE_DREAD_CHOICE=1 and the search file in place")
cfgT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
cs = cells_of(c)

function brute(p, egm; nf = NF, nx = NX, tol = 1e-8, maxit = 4000)
    af = SAGEBewley.exponential_grid(p.a_min, p.a_max, nf, p.pexp)
    z, Π = SAGEBewley.income_process(p); nz = length(z)
    isEmp = z .> 0
    eh = [isEmp[s] ? p.effort_set[s] : 0.0 for s in 1:nz]               # hours set by the job
    κ = 1.0 + p.commute; X = p.cfloor; γs = p.search_gamma
    w = [(1 + p.subsidy) * p.α[s] * z[s] * p.Z for s in 1:nz]
    oth = [-p.lumptax + transfer_at(p, s) for s in 1:nz]
    T = [floor_at(p, s) + κ * eh[s] for s in 1:nz]
    lab = [p.Γ * p.ϕ * T[s]^(1 + p.ψ) / (1 + p.ψ) for s in 1:nz]
    u(cc) = cc > 0 ? p.Γ * cc^(1 - p.γ) / (1 - p.γ) : -Inf
    D = [(p.dread > 0 && !isempty(p.dread_q)) ? dread_at(p, s, af[k]) : 0.0 for k in 1:nf, s in 1:nz]
    srch = [p.search_k[s] > 0 for s in 1:nz]
    Pf = copy(Π); Ps = copy(Π)
    for s in 1:nz
        srch[s] || continue
        rowE = Π[s, :] .* isEmp; fs = sum(rowE)
        Pf[s, :] = rowE ./ fs; Ps[s, :] = (Π[s, :] .- rowE) ./ (1 - fs)
    end
    res = [max(p.R * af[k] + w[s] * eh[s] + oth[s], X > 0 ? X : -Inf) for k in 1:nf, s in 1:nz]
    xmax = maximum(res) + 1.0
    xg = SAGEBewley.exponential_grid(1e-6, xmax, 2 * nf, p.pexp); ng = length(xg)
    V = [SAGEBewley.interp_lin(egm.a, view(egm.V, :, s), af[k]) for k in 1:nf, s in 1:nz]
    W = similar(V); XB = zeros(nf, nz); G = zeros(ng, nz); Vn = similar(V)
    xs = range(0.0, 1.0, length = nx)
    # the search choice at one next-asset node: the best of a grid, refined by golden section, boundaries included
    function best_x(ef, es, k_)
        obj(x) = x * ef + (1 - x) * es - k_ * x^(1 + γs) / ((1 + γs) * p.β)
        vals = obj.(xs); j = argmax(vals)
        lo = xs[max(j - 1, 1)]; hi = xs[min(j + 1, nx)]
        for _ in 1:50
            m1 = lo + 0.382 * (hi - lo); m2 = lo + 0.618 * (hi - lo)
            obj(m1) < obj(m2) ? (lo = m1) : (hi = m2)
        end
        xm = 0.5 * (lo + hi); vm = obj(xm)
        vm >= vals[j] ? (xm, vm) : (xs[j], vals[j])
    end
    it = 0
    for outer it in 1:maxit
        EVf = V * Pf'; EVs = V * Ps'; EV = V * Π'
        Threads.@threads for s in 1:nz
            for k in 1:nf
                if srch[s]
                    XB[k, s], W[k, s] = best_x(EVf[k, s], EVs[k, s], p.search_k[s])
                else
                    W[k, s] = EV[k, s]
                end
            end
            for ix in 1:ng                                # full search over next assets
                x = xg[ix]; b = -Inf
                for k in 1:nf
                    af[k] < x || break
                    v = u((x - af[k]) / p.pc) - D[k, s] + p.β * W[k, s]
                    v > b && (b = v)
                end
                G[ix, s] = b
            end
        end
        for s in 1:nz, k in 1:nf
            Vn[k, s] = SAGEBewley.interp_lin(xg, view(G, :, s), res[k, s]) - lab[s]
        end
        d = maximum(abs.(Vn .- V)); V, Vn = Vn, V
        d < tol && break
    end
    # policies at the fast solver's grid points
    na = length(egm.a)
    pol = map(Iterators.product(1:na, 1:nz)) do (i, s)
        a_ = egm.a[i]
        r0 = p.R * a_ + w[s] * eh[s] + oth[s]
        onf = X > 0 && r0 < X
        x = onf ? X : r0
        b = -Inf; kb = 1
        for k in 1:nf
            af[k] < x || break
            v = u((x - af[k]) / p.pc) - D[k, s] + p.β * W[k, s]
            v > b && (b = v; kb = k)
        end
        (c = (x - af[kb]) / p.pc, floor = onf, v = b - lab[s], x = srch[s] ? XB[kb, s] : NaN)
    end
    (pol = pol, iters = it, srch = srch)
end

probs = Any[]
for g in 1:2
    ps = [update(q; social_strength = 0.0) for q in params_of(cfgT, cs[g]) if !isempty(q.effort_set) && !isempty(q.search_k)]
    isempty(ps) && continue
    zs = [q.Z for q in ps]; o = sortperm(zs)
    push!(probs, ("cell $g, lowest type", ps[o[1]]))
    push!(probs, ("cell $g, middle type", ps[o[cld(length(o), 2)]]))
end
@printf("%s G+A with search, households with hours set by the job: %d problems | fine grid %d points, effort %d points refined\n", code, length(probs), NF, NX)
for (lab, p) in probs
    t0 = @elapsed egm = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
    t1 = @elapsed bf = brute(p, egm)
    na, nz = size(egm.lambda); m = egm.lambda; tot = sum(m)
    dfl = 0.0; dc = 0.0; dv = 0.0; dx = 0.0; mx = 0.0; dxmax = 0.0; xE = 0.0; xB = 0.0
    for s in 1:nz, i in 1:na
        q = m[i, s]; q > 0 || continue
        r = bf.pol[i, s]
        dfl += q * (egm.floor_d[1][i, s] != r.floor)
        dc += q * abs(egm.c_d[1][i, s] - r.c) / max(r.c, 1e-12)
        dv += q * abs(egm.V[i, s] - r.v) / max(abs(r.v), 1e-12)
        if bf.srch[s]
            e_ = abs(egm.search_x[i, s] - r.x)
            dx += q * e_; mx += q; dxmax = max(dxmax, e_); xE += q * egm.search_x[i, s]; xB += q * r.x
        end
    end
    dfl /= tot; dc /= tot; dv /= tot; dx /= mx; xE /= mx; xB /= mx
    @printf("\n%s (permanent scale %.3f) | fast solver %.1f s, benchmark %.1f s in %d iterations\n", lab, p.Z, t0, t1, bf.iters)
    @printf("   on-floor status differs for %.4f of the mass | consumption: mean relative difference %.1e | value: %.1e\n", dfl, dc, dv)
    @printf("   chance of finding work, searching states: fast %.4f, benchmark %.4f | mean absolute difference %.1e, largest %.1e\n", xE, xB, dx, dxmax)
    check("$lab: on-floor status the same for 99% of the mass", dfl < 0.01)
    check("$lab: consumption within 0.1% on average", dc < 1e-3)
    check("$lab: values within 1e-4 relative on average", dv < 1e-4)
    check("$lab: chance of finding work within 0.005 on average", dx < 5e-3)
end
nf_ = count(x -> !x[2], results)
@printf("\n%d of %d checks pass%s\n", length(results) - nf_, length(results), nf_ == 0 ? "" : "; FAILED: " * join([x[1] for x in results if !x[2]], "; "))
println("DONE")

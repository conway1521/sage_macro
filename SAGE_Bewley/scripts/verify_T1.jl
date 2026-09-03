# TIER 1 verification. Four jobs:
#   T1.1 Euler-equation errors (the standard accuracy check, previously absent)
#   T1.2 stationary distribution residual: is lambda actually invariant
#   T1.3 hand-to-mouth on an ECONOMIC threshold rather than a grid-point count
#   T1.4 effort-grid convergence of the S paper's financed-subsidy result
#
#   julia --project=. scripts/verify_T1.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf, Statistics, LinearAlgebra

pass(b) = b ? "PASS" : "**FAIL**"
E = SAGEBewley
println("="^72); println("TIER 1"); println("="^72)

# ---------- T1.1 Euler errors -------------------------------------------------
# For unconstrained states the Euler equation is u_c(c) = beta*R*E[u_c(c')].
# Marginal utility of consumption here is Gamma * c^(-gamma), so the implied
# consumption is (beta*R*E[c'^(-gamma)])^(-1/gamma). Report |c_implied/c - 1|
# in log10 units, the usual convention.
function euler_errors(s)
    p = s.p; a = s.a_grid; _, Π = E.income_process(p)
    errs = Float64[]
    for iz in 1:p.nz, ia in 1:p.na
        ap = s.a_next[ia, iz]
        ap <= a[1] + 1e-9 && continue                     # constrained, Euler slack
        rhs = 0.0
        for izn in 1:p.nz
            cn = E.interp_lin(a, view(s.c, :, izn), ap)
            cn <= 0 && (cn = 1e-12)
            rhs += Π[iz, izn] * cn^(-p.γ)
        end
        cimp = (p.β * p.R * rhs)^(-1/p.γ)
        push!(errs, abs(cimp / s.c[ia, iz] - 1))
    end
    errs
end
println("\nT1.1 Euler-equation errors (unconstrained states), log10 units")
@printf("%-14s | %-10s | %-10s | %-8s\n", "grid", "mean", "max", "verdict")
for (na, ne) in ((200,40), (300,60), (400,80))
    s = solve_model(SAGEParams(na = na, ne = ne))
    er = euler_errors(s)
    lm = log10(mean(er)); lx = log10(maximum(er))
    @printf("na=%-3d ne=%-3d | %+8.2f   | %+8.2f   | %s\n", na, ne, lm, lx, pass(lm < -3))
end
println("   convention: mean log10 error below -3 is comfortable for this model class")

# ---------- T1.2 stationary distribution residual -----------------------------
println("\nT1.2 stationary distribution invariance")
let s = solve_model(SAGEParams()), p = s.p
    a = s.a_grid; _, Π = E.income_process(p); na, nz = p.na, p.nz
    # push lambda through the Young lottery once and compare
    λ2 = zeros(na, nz)
    for iz in 1:nz, ia in 1:na
        m = s.λ[ia, iz]; m == 0 && continue
        ap = s.a_next[ia, iz]
        k = searchsortedlast(a, ap); k = clamp(k, 1, na-1)
        w = (ap - a[k]) / (a[k+1] - a[k]); w = clamp(w, 0.0, 1.0)
        for izn in 1:nz
            λ2[k,   izn] += m * Π[iz, izn] * (1 - w)
            λ2[k+1, izn] += m * Π[iz, izn] * w
        end
    end
    r = maximum(abs.(λ2 .- s.λ))
    @printf("   max |lambda*T - lambda| = %.3e   %s\n", r, pass(r < 1e-8))
end

# ---------- T1.3 hand-to-mouth on an economic threshold -----------------------
# Kaplan, Violante and Weidner measure low LIQUID WEALTH, not exactly zero
# assets. Use wealth below `weeks` of mean labour income. This is grid-stable:
# refining the grid resolves the same economic set better rather than shrinking
# the set itself, which is what the grid-point-count definition did.
function htm_threshold(s; weeks = 2.0)
    p = s.p; z, _ = E.income_process(p)
    minc = sum(s.λ[ia,iz] * p.α[iz] * s.e[ia,iz] * z[iz] for iz in 1:p.nz, ia in 1:p.na)
    thr = (weeks / 52) * minc
    sum(s.λ[ia, iz] for iz in 1:p.nz, ia in 1:p.na if s.a_grid[ia] < thr)
end
println("\nT1.3 hand-to-mouth: grid-count definition vs economic threshold")
@printf("%-14s | %-14s | %-16s | %-16s\n", "grid", "old (node 1)", "new (2wk income)", "new (4wk income)")
for (na, ne) in ((100,20), (200,40), (300,60), (400,80))
    s = solve_model(SAGEParams(na = na, ne = ne))
    @printf("na=%-3d ne=%-3d | %.4f         | %.4f           | %.4f\n",
            na, ne, frac_constrained(s), htm_threshold(s; weeks=2), htm_threshold(s; weeks=4))
end

# ---------- T1.4 effort-grid convergence of the S policy ----------------------
function financed(p; subsidy, tol = 1e-6, maxit = 60)
    z, _ = E.income_process(p); T = 0.0; s = solve_model(update(p; subsidy=subsidy, lumptax=T))
    resid = Inf
    for _ in 1:maxit
        paid = sum(s.λ[ia,iz]*subsidy*p.α[iz]*s.e[ia,iz]*z[iz] for iz in 1:p.nz, ia in 1:p.na)
        resid = abs(paid - T)
        resid < tol && break
        T = 0.5T + 0.5paid
        s = solve_model(update(p; subsidy=subsidy, lumptax=T))
    end
    (s, resid)
end
println("\nT1.4 effort-grid convergence of the financed 20% subsidy (na = 300)")
@printf("%-8s | %-9s | %-9s | %-12s\n", "ne", "dC %", "dQ %", "budget resid")
for ne in (40, 80, 160)
    pw = update(SAGEParams(na = 300, ne = ne); social_mode = :warmglow, social_strength = 1.0)
    s0, r0 = financed(pw; subsidy = 0.0); s1, r1 = financed(pw; subsidy = 0.20)
    agg(s,M) = sum(s.λ .* M)
    @printf("ne=%-5d | %+7.2f   | %+7.2f   | %.2e\n", ne,
            100*(agg(s1,s1.c)/agg(s0,s0.c)-1), 100*(s1.Q/s0.Q-1), max(r0,r1))
    flush(stdout)
end
println("\nDONE")

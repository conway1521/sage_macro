# The numerical evidence for the base (V3_START.md, section 27, rows N3 and N6), one country:
#   1. Euler-equation errors (Judd 1992) of every household problem of G+S+A, at no belonging and at
#      a belonging scale in the range the equilibrium uses: log10 of the relative consumption error,
#      mass-weighted mean and worst, over the states where the Euler equation holds with equality
#      (next assets inside the grid, the household not on the means-tested floor);
#   2. convergence: the economy with the asset grid doubled and with its top doubled, G+A and G+S+A,
#      each moment's change set against its calibration tolerance;
#   3. the stable participation equilibria at the calibrated technology, G+S and G+S+A.
# The income grid is not varied: with the lump-sum tax a finer one has no solution (section 23).
#
#   julia --project=scripts/run_env scripts/numerics_base.jl CODE [regime: v3fe | v3e | v3f | v3]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
code = uppercase(ARGS[1]); reg = length(ARGS) >= 2 ? lowercase(ARGS[2]) : "v3fe"
V3ARG = Dict("v3f" => :floor, "v3e" => :edu, "v3fe" => :floor_edu, "v3" => true, "v3fet" => :floor_edu_trans, "v3et" => :edu_trans)[reg]
results = Tuple{String,Bool}[]
check(name, ok) = (push!(results, (name, ok)); @printf("   -> %s: %s\n", name, ok ? "PASS" : "FAIL"); flush(stdout))

function euler_error(p, s)
    a = s.a; _, Π = SAGEBewley.income_process(p); na, nz = p.na, p.nz
    mu = [(1 - s.P1[i, j]) * (s.floor_d[1][i, j] ? 0.0 : max(s.c_d[1][i, j], 1e-12)^(-p.γ)) +
          s.P1[i, j] * (s.floor_d[2][i, j] ? 0.0 : max(s.c_d[2][i, j], 1e-12)^(-p.γ)) for i in 1:na, j in 1:nz]
    num = 0.0; den = 0.0; worst = 0.0; tot = 0.0
    for j in 1:nz, i in 1:na, d in (0, 1)
        pd = d == 1 ? s.P1[i, j] : 1 - s.P1[i, j]; m = s.lambda[i, j] * pd; m <= 0 && continue
        tot += m
        ap = s.a_d[d+1][i, j]
        (s.floor_d[d+1][i, j] || ap <= a[1] + 1e-9 || ap >= a[end]) && continue
        rhs = p.β * p.R * sum(Π[j, k] * SAGEBewley.interp_lin(a, view(mu, :, k), ap) for k in 1:nz)
        rhs > 0 || continue
        err = abs(1 - rhs^(-1 / p.γ) / s.c_d[d+1][i, j])
        num += m * err; den += m; worst = max(worst, err)
    end
    (mean = num / max(den, 1e-300), worst = worst, share = den / tot)
end

println(code, ", regime ", reg)
println("\n1. Euler-equation errors, G+S+A household problems (log10 of the relative consumption error)")
c = floor_effort(country_config(code; v3 = V3ARG, config = "GSA", S = true, A = true))
cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
worst_mean = -Inf
for (g, cell) in enumerate(cells_of(cT)), (k, p0) in enumerate(params_of(cT, cell)), u in (0.0, 4.0)
    p = update(p0; social_strength = u)
    s = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
    e = euler_error(p, s)
    global worst_mean = max(worst_mean, log10(e.mean))
    @printf("   cell %d, patience %.4f, belonging scale %.0f: mean 10^%.2f, worst 10^%.2f, over %.0f%% of households (the rest constrained or on the floor)\n",
            g, p.β, u, log10(e.mean), log10(e.worst), 100 * e.share)
    flush(stdout)
end
check("mean Euler error below 10^-3 in every household problem", worst_mean < -3)

println("\n2. convergence in the asset grid")
mom(r, S_) = (htm = r.hand_to_mouth_kvw, liq = r.wealth_p50 / r.median_income, mpc = r.mpc, eff = r.mean_effort_employed,
              part = S_ ? r.rate : 0.0, mult = S_ ? 1 / (1 - r.slope) : 1.0, drop = r.consumption_drop)
TOL = (htm = 0.02, liq = 0.03, mpc = 0.02, eff = 0.005, part = 0.005, mult = 0.2, drop = 0.02)
for cfg in ("GA", "GSA")
    S_ = cfg == "GSA"
    c0 = country_config(code; v3 = V3ARG, config = cfg, S = S_, A = true)
    @printf("   %s: asset grid %d points to %.1f\n", cfg, c0.na, c0.a_max)
    b = mom(solve_economy(c0; cache = false), S_)
    @printf("   %-22s htm %.4f | liquid/income %.4f | MPC %.4f | effort %.4f | participation %.4f | multiplier %.2f | job-loss drop %.4f\n", "base", b...)
    for (nm, cv) in (("grid doubled", SAGEConfig(c0; na = 2 * c0.na)), ("top doubled", SAGEConfig(c0; a_max = 2 * c0.a_max, na = round(Int, 1.3 * c0.na))))
        v = mom(solve_economy(cv; cache = false), S_)
        d = [getfield(v, f) - getfield(b, f) for f in keys(TOL)]
        @printf("   %-22s htm %+.4f | liquid/income %+.4f | MPC %+.4f | effort %+.4f | participation %+.4f | multiplier %+.2f | job-loss drop %+.4f\n", nm, d...)
        check("$cfg, $nm: every moment moves by less than half its tolerance", all(abs(d[i]) <= 0.5 * TOL[i] for i in eachindex(d)))
    end
end

println("\n3. stable participation equilibria at the calibrated technology")
function stable_points(c, fams)
    cs = cells_of(c); rs = map(f -> [n.rate for n in f], fams)
    grid = collect(range(0.0, 1.0, length = 401))
    out = [sum(cs[g].share * dot(node_weights(c, cs[g].B, c.omega + (1 - c.omega) * r), rs[g]) for g in 1:2) for r in grid]
    pts = Tuple{Float64,Float64}[]
    for i in 1:400
        d1 = out[i] - grid[i]; d2 = out[i+1] - grid[i+1]
        (d1 == 0 || sign(d1) != sign(d2)) || continue
        sl = (out[i+1] - out[i]) / (grid[i+1] - grid[i]); sl < 1 || continue
        push!(pts, (grid[i] + d1 / (d1 - d2) * (grid[i+1] - grid[i]), sl))
    end
    pts
end
for cfg in ("GS", "GSA")
    c0 = country_config(code; v3 = V3ARG, config = cfg, S = true, A = cfg == "GSA")
    b0 = solve_economy(c0); thr = [(b0.ypov, b0.abar)]
    sp = stable_points(c0, families(c0; thresholds = thr))
    @printf("   %s: %d stable: %s | the solver's: %.4f\n", cfg, length(sp), join([@sprintf("%.4f (multiplier %.1f)", r, 1 / (1 - s)) for (r, s) in sp], ", "), b0.rate)
    check("$cfg: one stable equilibrium, and it is the solver's", length(sp) == 1 && abs(sp[1][1] - b0.rate) < 0.005)
end
nf = count(x -> !x[2], results)
@printf("\n%d of %d checks pass%s\n", length(results) - nf, length(results), nf == 0 ? "" : "; FAILED: " * join([x[1] for x in results if !x[2]], "; "))
println("DONE")

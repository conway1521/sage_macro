# Prototype: discrete social-participation margin (Brock-Durlauf route to
# multiplicity under HONEST elasticities).
#
# Why: under the v1.1 literature parameters the smooth intensive-margin
# multiplier has no fold anywhere (kappa up to 50). Theory says multiplicity
# in social-interaction models comes from a DISCRETE choice with
# complementarity (Brock-Durlauf 2001). Here the discrete choice is
# participation in the social sphere: join (d = 1) and contribute a minimum
# meaningful time lump qbar, or do not (d = 0). The public good is the
# participation fabric Q = qbar * P(d = 1), and the belonging return to
# participating is kappa * Lambda * B * Q * qbar (complementarity: worth more
# when others participate).
#
# Honesty anchors: qbar = 0.10 of the time endowment (participants' social/
# volunteer time in time-use surveys is of this order); the participation
# RATE is the calibration target (France associative participation ~ 1/3);
# all other parameters are the v1.1 literature values.
#
# Question: does the discrete margin restore multiple equilibria at plausible
# kappa, or does wealth heterogeneity (heterogeneous participation
# thresholds) smooth the aggregate response back to uniqueness?
#
#   julia --project=. scripts/proto_participation.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using QuantEcon, SparseArrays, LinearAlgebra, Printf

const QBAR = 0.10

"Solve the household problem with work effort AND discrete participation,
given aggregate fabric Q_agg. Coarser grids than production: a probe."
function solve_participation(p::SAGEParams, Q_agg::Float64)
    a = SAGEBewley.exponential_grid(p.a_min, p.a_max, p.na, p.pexp)
    z_vals, Π = SAGEBewley.income_process(p)
    na, nz = p.na, p.nz
    e_grid = range(0.0, 1.0, length = p.ne)
    n_s = na * nz
    sidx(i_a, i_z) = (i_z - 1) * na + i_a

    s_ind = Int[]; a_ind = Int[]; Rvec = Float64[]
    rows = Int[]; cols = Int[]; vals = Float64[]
    Dpol = zeros(Int, n_s, na)              # participation at the joint optimum
    pair = 0
    for i_z in 1:nz
        z = z_vals[i_z]; α = p.α[i_z]; Bz = p.B[i_z]
        belong = p.social_strength * p.Λ * Bz * Q_agg * QBAR   # reward if d=1
        for i_a in 1:na
            res = p.R * a[i_a]; s = sidx(i_a, i_z)
            for k in 1:na
                anext = a[k]
                best = -Inf; bestd = 0
                for d in (0, 1)
                    tmax = 1.0 - QBAR * d
                    for e in e_grid
                        e > tmax && break
                        c = res + α * e * z * p.Z - anext
                        c <= 0 && continue
                        T = e + QBAR * d        # total non-leisure time
                        ut = p.Γ * (c^(1 - p.γ) / (1 - p.γ) -
                                    p.ϕ * T^(1 + p.ψ) / (1 + p.ψ)) + belong * d
                        ut > best && (best = ut; bestd = d)
                    end
                end
                best == -Inf && continue
                Dpol[s, k] = bestd
                pair += 1
                push!(s_ind, s); push!(a_ind, k); push!(Rvec, best)
                for i_zn in 1:nz
                    push!(rows, pair); push!(cols, sidx(k, i_zn)); push!(vals, Π[i_z, i_zn])
                end
            end
        end
    end
    ddp = DiscreteDP(Rvec, sparse(rows, cols, vals, pair, n_s), p.β, s_ind, a_ind)
    res = solve(ddp, PFI)
    σ = res.sigma

    # stationary distribution on the grid policy (no continuous refinement:
    # this is a probe of the aggregate map, not of policy smoothness)
    drows = Int[]; dcols = Int[]; dvals = Float64[]
    for i_z in 1:nz, i_a in 1:na
        s = sidx(i_a, i_z); k = σ[s]
        for i_zn in 1:nz
            push!(drows, s); push!(dcols, sidx(k, i_zn)); push!(dvals, Π[i_z, i_zn])
        end
    end
    T = Matrix(sparse(drows, dcols, dvals, n_s, n_s))
    for _ in 1:45
        T = T * T; T ./= sum(T, dims = 2)
    end
    λ = vec(sum(T .* (1.0 / n_s), dims = 1)); λ ./= sum(λ)

    part = sum(λ[s] * Dpol[s, σ[s]] for s in 1:n_s)   # participation rate
    return QBAR * part, part
end

function fixed_point(p, Q0; damp = 0.5, tol = 1e-5, maxit = 120)
    Q = Q0; rate = 0.0
    for _ in 1:maxit
        Qout, rate = solve_participation(p, Q)
        abs(Qout - Q) < tol && return Qout, rate
        Q = damp * Q + (1 - damp) * Qout
    end
    return Q, rate
end

p0 = SAGEParams(na = 120, ne = 40)

println("[1] kappa sweep, two starts: is the participation economy bistable?")
println("    kappa    Q_lo   rate_lo    Q_hi   rate_hi   bistable")
for κ in (2.0, 5.0, 10.0, 20.0, 40.0, 80.0)
    p = update(p0; social_strength = κ)
    Qlo, rlo = fixed_point(p, 0.001)
    Qhi, rhi = fixed_point(p, QBAR * 0.99)
    @printf("    %5.1f  %.4f  %.3f     %.4f  %.3f     %s\n",
            κ, Qlo, rlo, Qhi, rhi, abs(Qhi - Qlo) > 0.005 ? "YES" : "no")
    flush(stdout)
end

println("\n[2] The aggregate participation map at a mid kappa (shape probe)")
const KMAP = 20.0
pm = update(p0; social_strength = KMAP)
for Qin in 0.0:0.01:0.10
    Qout, rate = solve_participation(pm, Qin)
    @printf("    Q_in=%.3f -> Q_out=%.4f (rate %.3f)\n", Qin, Qout, rate)
    flush(stdout)
end
println("DONE")

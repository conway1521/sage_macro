# Shared core for the participation-margin prototypes: household problem with
# work effort AND a discrete participation choice (lump QBAR), given the
# aggregate participation fabric Q_agg. Coarse-grid probe, no continuous
# refinement. Requires SAGEBewley to be included first.

using QuantEcon, SparseArrays, LinearAlgebra

const QBAR = 0.10

function solve_participation(p::SAGEParams, Q_agg::Float64)
    a = SAGEBewley.exponential_grid(p.a_min, p.a_max, p.na, p.pexp)
    z_vals, Π = SAGEBewley.income_process(p)
    na, nz = p.na, p.nz
    e_grid = range(0.0, 1.0, length = p.ne)
    n_s = na * nz
    sidx(i_a, i_z) = (i_z - 1) * na + i_a

    s_ind = Int[]; a_ind = Int[]; Rvec = Float64[]
    rows = Int[]; cols = Int[]; vals = Float64[]
    Dpol = zeros(Int, n_s, na)
    Epol = zeros(n_s, na)                  # effort at the joint optimum
    pair = 0
    for i_z in 1:nz
        z = z_vals[i_z]; α = p.α[i_z]; Bz = p.B[i_z]
        belong = p.social_strength * p.Λ * Bz * Q_agg * QBAR
        for i_a in 1:na
            res = p.R * a[i_a]; s = sidx(i_a, i_z)
            for k in 1:na
                anext = a[k]
                best = -Inf; bestd = 0; beste = 0.0
                # participation tax credit: rebate on the opportunity cost of
                # the time lump, paid only when the household participates (d=1)
                credit = p.partcredit * α * z * p.Z * QBAR
                for d in (0, 1)
                    tmax = 1.0 - QBAR * d
                    for e in e_grid
                        e > tmax && break
                        c = res + (1 + p.subsidy) * α * e * z * p.Z - p.lumptax - anext + credit * d
                        c <= 0 && continue
                        T = e + QBAR * d
                        ut = p.Γ * (c^(1 - p.γ) / (1 - p.γ) -
                                    p.ϕ * T^(1 + p.ψ) / (1 + p.ψ)) + belong * d
                        ut > best && (best = ut; bestd = d; beste = e)
                    end
                end
                best == -Inf && continue
                Dpol[s, k] = bestd
                Epol[s, k] = beste
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

    part = sum(λ[s] * Dpol[s, σ[s]] for s in 1:n_s)
    # mean pre-subsidy labour income E[alpha e z], for budget-balance loops;
    # and the participation wage base E[alpha z | d=1] * P, which is the credit's
    # fiscal-cost base (the credit pays partcredit * alpha * z * Z * QBAR per
    # participating household, so cost per capita = partcredit * QBAR * Z * partbase)
    meaninc = 0.0; partbase = 0.0
    for i_z in 1:nz, i_a in 1:na
        s = sidx(i_a, i_z)
        meaninc  += λ[s] * p.α[i_z] * Epol[s, σ[s]] * z_vals[i_z]
        partbase += λ[s] * p.α[i_z] * z_vals[i_z] * Dpol[s, σ[s]]
    end
    return QBAR * part, part, meaninc, partbase
end

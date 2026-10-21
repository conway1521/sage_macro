# Stage 1c's chain before any solve (V3_START.md section 125): by country, the benefit profile read, the chain with the
# spell without entitlement, and its masses (the unemployment rate against version 1's, the inactive share, the share
# of the unemployed without entitlement), the labels (durations and the entry states), and the tax of the benefits,
# against stage 1b's chain with the same flows.
#
#   julia --project=scripts/run_env scripts/test_v2_stage1c.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
for code in ("FR", "DE", "IT")
    ca = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
    for prof in (false, true)
        cb = duration_config(ca; profile = prof)
        @printf("%s %s: rrU %s | rrL %.4f (public share %.3f) | job loss %.5f %.5f | E->N %.4f %.4f\n", code, prof ? "1c" : "1b",
                string(round.(isempty(cb.rrU_vec) ? fill(cb.rr, cb.nU) : cb.rrU_vec, digits = 3)), cb.rr_long, cb.long_public_share,
                cb.delta..., cb.iotaE...)
        for gi in 1:2
            cell = cells_of(cb)[gi]
            ch = labour_chain(SAGEParams(nz = 2, α = fill(1.0, 2), B = fill(1.0, 2)); nU = cb.nU, hU = chain_hU(cb), hL = cell.fL, δ = cell.δ, chain_flows(cb, gi)...)
            mu = sum(ch.mass[ch.iU]) + ch.mass[ch.iL]
            @printf("   cell %d: mass %.12f | unemployment %.4f (version 1 %.4f) | inactive %.4f | without entitlement %.4f of the unemployed | labels U %s\n",
                    gi, sum(ch.mass), mu / (mu + ch.mass[ch.iE]), ca.delta[gi] / (ca.delta[gi] + ca.f_find), ch.mass[ch.iN],
                    sum(ch.mass[ch.iUn]) / mu, string(unique(ch.dur[ch.stype .=== :U])))
        end
        p = params_of(SAGEConfig(cb; effort_mode = :free), cells_of(cb)[1])[1]      # the labels only
        pU = partner_index(p, :U); nx = next_out_index(p); st = stypes(p)
        e1 = findfirst(st .=== :E)
        @printf("   entry state of the first employed state: duration %d | where U^e_8 and U^n_8 go: %s %s | tax of benefits %.6f\n",
                p.dur[pU[e1]], string(st[nx[findfirst((st .=== :U) .& (p.dur .== cb.nU))]]), (k = findfirst((st .=== :U) .& (p.dur .== NONENT + cb.nU)); k === nothing ? "none" : string(st[nx[k]])),
                ui_only_tax_of(cb))
    end
end
println("DONE")

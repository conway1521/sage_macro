# Stage 7 probe: what magnitudes do the two new parameters need?
#
# Not a result, a scoping exercise, and recorded as such (STAGE7.md Part 4
# says the parameter VALUES are what the calibration is for). The hand-to-mouth
# share barely depends on the social scale and the employed-to-unemployed
# participation ratio depends on it only through the level, so both can be read
# at a few belonging scales instead of a whole response family. That turns a
# four-hour search into a five-minute one.
#
#   julia --project=. scripts/s7_probe.jl
include(joinpath(@__DIR__, "s7_workers.jl"))
const T_UI = ui_tax(CELLS, F_FIND, RR)
const US = [4.0, 5.0, 6.0]
const NABLAS = [0.0, 0.005, 0.010, 0.0155, 0.019]
const PCOSTS = [0.0, 0.005, 0.010, 0.020, 0.035]

@printf("UI tax %.5f; belonging scales %s; %d discount-factor points\n\n", T_UI, string(US), NBETA)

"One (nabla, pcost) point: pooled hand-to-mouth, and participation by status."
function probe(∇, pc)
    bs, w = beta_types(∇)
    fams = map(CELLS) do c
        p0s = [cell_params_u(c.α; δ = c.δ, f = F_FIND, rr = RR, na = NA, ne = NE,
                             a_max = GRID.a_max, pexp = GRID.pexp, lumptax = T_UI,
                             β = b, pcost = pc) for b in bs]
        build_family_u(p0s, US, THETA; weights = w)
    end
    ag = SAGEBewley.exponential_grid(1e-10, GRID.a_max, NA, GRID.pexp)
    emp = cell_params_u(CELLS[1].α; δ = CELLS[1].δ, f = F_FIND, rr = RR).transfer .== 0
    out = NamedTuple[]
    for (k, u) in enumerate(US)
        nl = fams[1][k]; nh = fams[2][k]
        minc = 0.5 * nl.minc + 0.5 * nh.minc
        Wt = 0.5 .* vec(sum(nl.W, dims = 1)) .+ 0.5 .* vec(sum(nh.W, dims = 1))
        htm = share_below_interp(ag, Wt, (4 / 52) * minc)
        pE = 0.5 * sum(nl.part[emp]) + 0.5 * sum(nh.part[emp])
        mE = 0.5 * sum(nl.mass[emp]) + 0.5 * sum(nh.mass[emp])
        pU = 0.5 * sum(nl.part[.!emp]) + 0.5 * sum(nh.part[.!emp])
        mU = 0.5 * sum(nl.mass[.!emp]) + 0.5 * sum(nh.mass[.!emp])
        rE = pE / mE; rU = pU / mU
        push!(out, (u = u, htm = htm, rE = rE, rU = rU, ratio = rE > 0 ? rU / rE : NaN,
                    rate = pE + pU, minc = minc))
    end
    out
end

@printf("%-8s %-8s | %-24s | %-34s\n", "nabla", "pcost", "hand-to-mouth by scale", "rate E / rate U / ratio at u = 5")
println("-"^86)
best = (d = Inf,)
for ∇ in NABLAS, pc in PCOSTS
    global best
    o = probe(∇, pc)
    m = o[2]
    @printf("%-8.4f %-8.3f | %s | %.4f / %.4f / %s\n", ∇, pc,
            join([@sprintf("%7.4f", x.htm) for x in o]), m.rE, m.rU,
            isnan(m.ratio) ? "   n/a" : @sprintf("%6.3f", m.ratio))
    flush(stdout)
    d = (m.htm - HTM_TARGET)^2 / HTM_TARGET^2 + (isnan(m.ratio) ? 4.0 : (m.ratio - RATIO_UE)^2 / RATIO_UE^2)
    d < best.d && (best = (d = d, ∇ = ∇, pc = pc, htm = m.htm, ratio = m.ratio))
end
println("-"^86)
@printf("targets: hand-to-mouth %.2f, ratio %.3f\n", HTM_TARGET, RATIO_UE)
@printf("closest probe point: nabla %.4f, pcost %.3f  (htm %.4f, ratio %.3f)\n",
        best.∇, best.pc, best.htm, best.ratio)
@printf("pcost as a share of mean labour income at that point: %.1f percent\n",
        100 * best.pc / probe(best.∇, best.pc)[2].minc)
println("DONE")

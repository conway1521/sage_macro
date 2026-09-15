# Stage 7, second probe. The first (s7_probe.txt) rejected both fixes as
# specified:
#
#   the symmetric discount spread is capped by stationarity at 0.019, and the
#   whole admissible range moves the hand-to-mouth share from 0.105 to 0.132
#   against a target of 0.30;
#
#   the monetary participation cost moves the employed-to-unemployed ratio the
#   WRONG WAY, from 3.3 to 43, because consumption smoothing leaves the
#   unemployed consuming nearly what they did in work, so a fixed money cost
#   does not discriminate by employment status, while the employed, who were
#   already near indifference, drop out first.
#
# STAGE7.md Part 5 anticipated the second: "If it cannot, the time-cost model
# of participation is wrong in a way one fixed cost does not repair, and that
# is a finding." This probes the two repairs the evidence points to.
#
#   A  discount factors spread DOWNWARD only, which stationarity does not cap
#   B  the belonging payoff scaled by zeta when unemployed, the reduced form of
#      the source's own agency-solidarity complementarity
#
#   julia --project=. scripts/s7_probe2.jl
include(joinpath(@__DIR__, "s7_workers.jl"))
const T_UI = ui_tax(CELLS, F_FIND, RR)
const US = [4.0, 5.0, 6.0]
const AG = SAGEBewley.exponential_grid(1e-10, GRID.a_max, NA, GRID.pexp)
const EMP = cell_params_u(CELLS[1].α; δ = CELLS[1].δ, f = F_FIND, rr = RR).transfer .== 0

function probe(∇, ζ; pc = 0.0)
    bs, w = beta_types(∇)
    bsc = belong_scale_vec(ζ, EMP)
    fams = map(CELLS) do c
        p0s = [cell_params_u(c.α; δ = c.δ, f = F_FIND, rr = RR, na = NA, ne = NE,
                             a_max = GRID.a_max, pexp = GRID.pexp, lumptax = T_UI,
                             β = b, pcost = pc) for b in bs]
        p0s = [update(p; belong_scale = bsc) for p in p0s]
        build_family_u(p0s, US, THETA; weights = w)
    end
    map(1:length(US)) do k
        nl = fams[1][k]; nh = fams[2][k]
        minc = 0.5 * nl.minc + 0.5 * nh.minc
        Wt = 0.5 .* vec(sum(nl.W, dims = 1)) .+ 0.5 .* vec(sum(nh.W, dims = 1))
        htm = share_below_interp(AG, Wt, (4 / 52) * minc)
        rE = (0.5 * sum(nl.part[EMP]) + 0.5 * sum(nh.part[EMP])) /
             (0.5 * sum(nl.mass[EMP]) + 0.5 * sum(nh.mass[EMP]))
        rU = (0.5 * sum(nl.part[.!EMP]) + 0.5 * sum(nh.part[.!EMP])) /
             (0.5 * sum(nl.mass[.!EMP]) + 0.5 * sum(nh.mass[.!EMP]))
        (u = US[k], htm = htm, rE = rE, rU = rU, ratio = rE > 1e-8 ? rU / rE : NaN,
         rate = 0.5 * nl.rate + 0.5 * nh.rate, minc = minc)
    end
end

println("A. DOWNWARD discount spread, no belonging scaling. Target hand-to-mouth 0.30.")
@printf("%-8s %-10s | %-24s | %s\n", "nabla", "beta range", "hand-to-mouth by scale", "rate at u = 5")
println("-"^76)
for ∇ in (0.0, 0.02, 0.04, 0.06, 0.09, 0.12, 0.16)
    b, _ = beta_types(∇)
    o = probe(∇, 1.0)
    @printf("%-8.3f %-10s | %s | %.4f\n", ∇,
            @sprintf("%.3f-%.3f", minimum(b), maximum(b)),
            join([@sprintf("%7.4f", x.htm) for x in o]), o[2].rate)
    flush(stdout)
end
println()
println("B. BELONGING SCALING when unemployed, at zero discount spread.")
@printf("%-8s | %-8s %-8s %-8s | %s\n", "zeta", "rate E", "rate U", "ratio", "hand-to-mouth")
println("-"^60)
for ζ in (1.0, 0.8, 0.6, 0.5, 0.4, 0.3, 0.2)
    o = probe(0.0, ζ)[2]
    @printf("%-8.2f | %.4f   %.4f   %s | %.4f\n", ζ, o.rE, o.rU,
            isnan(o.ratio) ? "  n/a " : @sprintf("%6.3f", o.ratio), o.htm)
    flush(stdout)
end
@printf("\ntarget ratio %.3f (INSEE Premiere 1327: 0.17 / 0.35)\n", RATIO_UE)
println("DONE")

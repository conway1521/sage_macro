# Stage 7, third probe. How far does the belonging payoff have to fall on job
# loss to match the observed collapse in membership, and why is the answer so
# large?
#
# The arithmetic of the asymmetry, at the belonging scale u = 5 and the low
# cell. The belonging payoff is u * Lambda * Qbar = 0.438. For an EMPLOYED
# household at the calibrated work share T = 0.54, taking on the participation
# lump raises the time disutility by phi * ((T + 0.1)^3 - T^3) / 3 = 0.489, so
# it sits near indifference, which is why its rate is 0.30. For an UNEMPLOYED
# household at T = 0, the same lump costs phi * 0.1^3 / 3 = 0.0047, a hundred
# times less, because the disutility is convex and they are at the bottom of
# it. Their surplus is so large that halving or quartering the payoff changes
# nothing, which is what probe 2 found.
#
# So this measures the scaling that WOULD match, and reports it as the price of
# the time-cost model of participation rather than hiding it in a calibration.
#
#   julia --project=. scripts/s7_probe3.jl
include(joinpath(@__DIR__, "s7_workers.jl"))
const T_UI = ui_tax(CELLS, F_FIND, RR)
const AG = SAGEBewley.exponential_grid(1e-10, GRID.a_max, NA, GRID.pexp)
const EMP = cell_params_u(CELLS[1].α; δ = CELLS[1].δ, f = F_FIND, rr = RR).transfer .== 0

function probe(∇, ζ, us)
    bs, w = beta_types(∇); bsc = belong_scale_vec(ζ, EMP)
    fams = map(CELLS) do c
        p0s = [update(cell_params_u(c.α; δ = c.δ, f = F_FIND, rr = RR, na = NA, ne = NE,
                                    a_max = GRID.a_max, pexp = GRID.pexp, lumptax = T_UI, β = b);
                      belong_scale = bsc) for b in bs]
        build_family_u(p0s, us, THETA; weights = w)
    end
    map(eachindex(us)) do k
        nl = fams[1][k]; nh = fams[2][k]
        minc = 0.5 * nl.minc + 0.5 * nh.minc
        Wt = 0.5 .* vec(sum(nl.W, dims = 1)) .+ 0.5 .* vec(sum(nh.W, dims = 1))
        rE = (0.5 * sum(nl.part[EMP]) + 0.5 * sum(nh.part[EMP])) /
             (0.5 * sum(nl.mass[EMP]) + 0.5 * sum(nh.mass[EMP]))
        rU = (0.5 * sum(nl.part[.!EMP]) + 0.5 * sum(nh.part[.!EMP])) /
             (0.5 * sum(nl.mass[.!EMP]) + 0.5 * sum(nh.mass[.!EMP]))
        (u = us[k], htm = share_below_interp(AG, Wt, (4 / 52) * minc), rE = rE, rU = rU,
         ratio = rE > 1e-8 ? rU / rE : NaN, rate = 0.5 * nl.rate + 0.5 * nh.rate)
    end
end

println("the time arithmetic behind the asymmetry, phi = 14, psi = 2, Qbar = 0.10:")
for T in (0.0, 0.10, 0.16, 0.30, 0.54)
    @printf("  at a time commitment of %.2f, the participation lump costs %.4f in utility\n",
            T, 14 * ((T + 0.10)^3 - T^3) / 3)
end
@printf("  the belonging payoff at u = 5 is %.4f\n\n", 5 * 0.8757834 * 0.10)

println("belonging scaling when unemployed, at the discount spread that fixes wealth (nabla = 0.04):")
@printf("%-7s | %-8s %-8s %-8s | %-8s %s\n", "zeta", "rate E", "rate U", "ratio", "htm", "aggregate")
println("-"^62)
for ζ in (1.0, 0.30, 0.15, 0.10, 0.07, 0.05, 0.03, 0.01)
    o = probe(0.04, ζ, [5.0])[1]
    @printf("%-7.2f | %.4f   %.4f   %s | %.4f   %.4f\n", ζ, o.rE, o.rU,
            isnan(o.ratio) ? "  n/a " : @sprintf("%6.3f", o.ratio), o.htm, o.rate)
    flush(stdout)
end
@printf("\ntarget ratio %.3f; target hand-to-mouth %.2f\n", RATIO_UE, HTM_TARGET)
println()
println("discount spread against hand-to-mouth, fine, no belonging scaling:")
@printf("%-7s | %-11s | %-8s %s\n", "nabla", "beta range", "htm", "aggregate rate")
println("-"^50)
for ∇ in (0.030, 0.035, 0.040, 0.045, 0.050)
    b, _ = beta_types(∇); o = probe(∇, 1.0, [5.0])[1]
    @printf("%-7.3f | %.3f-%.3f | %.4f   %.4f\n", ∇, minimum(b), maximum(b), o.htm, o.rate)
    flush(stdout)
end
println("DONE")

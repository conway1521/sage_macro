# The one known defect, retested on the corrected footing.
#
# THE DEFECT. In the model the unemployed participate at a rate of ONE at every
# belonging scale. In the data they participate at about half the employed rate
# (INSEE Premiere 1327: 17 percent against 35). The cause is the convexity of
# the time cost: joining costs a household at the calibrated work share about
# 0.49 in utility and one at zero hours about 0.005, a factor of a hundred, so
# participation is nearly free to anyone not working.
#
# WHAT FAILED BEFORE, AND WHY IT IS WORTH RETRYING. A fixed money cost moved the
# ratio the WRONG WAY, and no scaling of the belonging payoff fixed it down to
# one percent of its value (STAGE7.md). But that was on a model whose
# hand-to-mouth share was 0.12, where every unemployed household could smooth
# its consumption by running down savings, so a money cost bit equally on both
# states. On the corrected footing hand-to-mouth is 0.30: a third of households
# hold nothing at all, and for them losing work is a real consumption drop. The
# mechanism may work now for a reason that has nothing to do with the mechanism.
#
# THREE MECHANISMS, and their combinations:
#   pcost        a fixed money cost of joining
#   search_time  committed time when out of work: job search under benefit
#                conditionality, plus the home production that replaces market
#                work (Aguiar, Hurst and Karabarbounis 2013)
#   belong_u     the value of belonging when out of work, as a fraction of its
#                employed value: work-linked networks and the withdrawal the
#                unemployment literature documents
#
# Read at three belonging scales rather than on whole response families, which
# is what makes a search over three mechanisms affordable.
#
#   julia --project=. scripts/probe_defect.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics

const CAL = SAGEConfig(A = true, unemployment = true, beta_spread = 0.037,
                       kappa = 9.90, sigma_m = 0.385)
const US = [4.0, 5.0, 6.0]
const TARGET = 0.17 / 0.35
const AG = SAGEBewley.exponential_grid(1e-10, CAL.a_max, CAL.na, CAL.pexp)

"Participation by employment status at three belonging scales, plus hand-to-mouth."
function probe(; pcost = 0.0, search_time = 0.0, belong_u = 1.0)
    c = SAGEConfig(CAL; pcost = pcost, search_time = search_time, belong_u = belong_u)
    cs = cells_of(c); bs, bw = betas_of(c); T = c.lumptax + ui_tax_of(c)
    cT = SAGEConfig(c; lumptax = T)
    fams = [build_family_u(params_of(cT, cell), US, c.theta; weights = bw) for cell in cs]
    emp = params_of(cT, cs[1])[1].transfer .== 0
    map(eachindex(US)) do k
        nl = fams[1][k]; nh = fams[2][k]
        mE = 0.5 * sum(nl.mass[emp]) + 0.5 * sum(nh.mass[emp])
        mU = 0.5 * sum(nl.mass[.!emp]) + 0.5 * sum(nh.mass[.!emp])
        rE = (0.5 * sum(nl.part[emp]) + 0.5 * sum(nh.part[emp])) / mE
        rU = (0.5 * sum(nl.part[.!emp]) + 0.5 * sum(nh.part[.!emp])) / mU
        minc = 0.5 * nl.minc + 0.5 * nh.minc
        Wt = 0.5 .* vec(sum(nl.W, dims = 1)) .+ 0.5 .* vec(sum(nh.W, dims = 1))
        (rE = rE, rU = rU, ratio = rE > 1e-8 ? rU / rE : NaN,
         htm = share_below_interp(AG, Wt, (4 / 52) * minc), rate = 0.5 * nl.rate + 0.5 * nh.rate)
    end
end
row(lbl, o) = (@printf("%-34s | %.4f %.4f %s | %.4f %.4f\n", lbl, o.rE, o.rU,
                       isnan(o.ratio) ? "   n/a" : @sprintf("%6.3f", o.ratio), o.htm, o.rate);
               flush(stdout))

@printf("corrected footing: %s\n", describe(CAL))
@printf("target ratio %.3f (INSEE Premiere 1327: 0.17 employed against 0.35)\n\n", TARGET)
@printf("%-34s | %-6s %-6s %-6s | %-6s %s\n", "mechanism", "rate E", "rate U", "ratio", "htm", "rate")
println("-"^76)
row("none, the defect as it stands", probe()[2])
println()
println("1. money cost of joining, which failed at hand-to-mouth 0.12")
for pc in (0.005, 0.010, 0.020, 0.035, 0.050)
    row(@sprintf("   pcost %.3f", pc), probe(pcost = pc)[2])
end
println()
println("2. committed time when out of work")
for st in (0.10, 0.20, 0.30, 0.40, 0.50)
    row(@sprintf("   search time %.2f", st), probe(search_time = st)[2])
end
println()
println("3. value of belonging when out of work")
for bu in (0.7, 0.5, 0.3, 0.15, 0.05)
    row(@sprintf("   belonging %.2f", bu), probe(belong_u = bu)[2])
end
println()
println("4. combinations, since none of the three is likely to do it alone")
for (st, bu) in ((0.30, 0.7), (0.30, 0.5), (0.40, 0.5), (0.40, 0.3), (0.50, 0.5), (0.50, 0.3))
    row(@sprintf("   search %.2f, belonging %.2f", st, bu), probe(search_time = st, belong_u = bu)[2])
end
for (st, pc) in ((0.30, 0.02), (0.40, 0.02), (0.40, 0.035))
    row(@sprintf("   search %.2f, money %.3f", st, pc), probe(search_time = st, pcost = pc)[2])
end
println("DONE")

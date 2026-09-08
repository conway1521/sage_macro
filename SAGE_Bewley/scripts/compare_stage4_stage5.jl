# Side by side: every S+A scalar on the hard-threshold footing (stage 4,
# snapshot in stage4_hardthreshold/) against the logit core (stage 5). The
# point is to see which numbers moved, by how much, and whether any
# conclusion changed, before a single word of the paper is edited.
#   julia --project=. scripts/compare_stage4_stage5.jl
using Printf
rd(f) = Dict(String(split(l,'\t')[1]) => parse(Float64, split(l,'\t')[2])
             for l in eachline(f) if !startswith(l, "#") && occursin('\t', l))
old = rd(joinpath(@__DIR__, "stage4_hardthreshold", "sa_level4_results.txt"))
new = rd(joinpath(@__DIR__, "sa_level4_results.txt"))
groups = [
 ("baseline",     ["r0","r0_lo","r0_hi","slope0","mi0"]),
 ("gradient",     ["gap_full","gap_agency","gap_taste"]),
 ("proposition",  ["sigbar","ratio","gprime","frontier"]),
 ("work subsidy", ["T_sub","r_sub_direct","r_sub","amp","r_sub_lo","r_sub_hi","mi_sub"]),
 ("empowerment",  ["r_emp","r_emp_lo","r_emp_hi","mi_emp"]),
 ("Gift Aid 25%", ["cred_25_100_r","cred_25_100_lo","cred_25_100_hi","cred_25_100_cost",
                   "cred_25_50_r","cred_25_25_r"]),
 ("France 66%",   ["cred_66_100_r","cred_66_100_lo","cred_66_100_hi","cred_66_100_cost",
                   "cred_66_50_r","cred_66_25_r"]),
 ("take-up ratio",["ratio0"]),
 ("ledger",       ["pi_model_pct","pi_star_pct","gdp_work_subsidy_(20%)","gdpb_work_subsidy_(20%)",
                   "gdp_empowerment","gdpb_empowerment",
                   "gdp_participation_credit_(25%)","gdpb_participation_credit_(25%)"]),
]
@printf("%-32s | %-10s | %-10s | %-10s | %s\n", "quantity", "stage 4", "stage 5", "delta", "rel")
for (g, ks) in groups
    println("-- ", g)
    for k in ks
        (haskey(old,k) && haskey(new,k)) || continue
        o, n = old[k], new[k]
        rel = o == 0 ? NaN : 100*(n-o)/abs(o)
        flag = abs(rel) > 20 ? "  <-- moved" : ""
        @printf("%-32s | %10.4f | %10.4f | %+10.4f | %+6.1f%%%s\n", k, o, n, n-o, rel, flag)
    end
end
# the derived take-up ratios, which are what the paper's incidence claim rests on
println("-- take-up high/low ratios")
for (ρ, τ) in ((25,100),(25,50),(25,25),(66,100),(66,50),(66,25))
    kl="cred_$(ρ)_$(τ)_lo"; kh="cred_$(ρ)_$(τ)_hi"
    (haskey(old,kl) && haskey(new,kl)) || continue
    @printf("%-32s | %10.3f | %10.3f |\n", "rho $ρ tau $τ", old[kh]/old[kl], new[kh]/new[kl])
end
println("DONE")

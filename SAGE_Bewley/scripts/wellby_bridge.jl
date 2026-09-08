# The WELLBY bridge: policy effects in life-satisfaction points and in money,
# priced from published coefficients rather than from the model's own internal
# shadow price.
#
# Why this exists. The GDP-B ledger in the S+A paper prices the social fabric
# at pi = (Lambda/Gamma) Bbar cbar^gamma, an object built from Lambda, which
# the engine's own identification note says is NOT identified from behaviour
# (only the product kappa*Lambda is). So the ledger's price is internal and a
# reader is entitled to discount it. This script replaces it with external
# coefficients, which is what makes the beyond-GDP claim disciplined.
#
# The two anchors, both verified against the primary documents on 2026-09-08
# and recorded in data/EVIDENCE_WELLBY.md:
#
#   HM Treasury, Wellbeing Guidance for Appraisal: Supplementary Green Book
#   Guidance (July 2021, still current). One WELLBY, a one-point change in life
#   satisfaction on the 0-10 scale per person per year, is worth GBP 13,000 in
#   2019 prices, range 10,000 to 16,000. The equivalent-surplus formula is
#     ES = M [ exp(beta_Q dQ / beta_Y) - 1 ],  beta_Y = 1.96105 (Fujiwara 2021)
#   with beta_Y stated on the 0-10 scale.
#
#   World Happiness Report 2025, Chapter 2 Statistical Appendix, Table 10,
#   column (1). Pooled OLS on the Cantril ladder (0-10) with BOTH year and
#   country fixed effects, 2234 observations, 155 countries, country-clustered
#   standard errors. Log GDP per capita 0.588 (0.125); social support 2.510
#   (0.319); freedom to make life choices 0.947 (0.239).
#
# THE LOAD-BEARING ASSUMPTION, stated here rather than buried. The model's
# aggregate participation rate P(d=1) is mapped onto the WHR "social support"
# variable, which is the national share answering that they have someone to
# count on. Both are 0-1 population shares of a social connection, which is why
# they are mapped, but they are not the same survey item and nobody has shown
# they move one-for-one. Everything below is proportional to that assumption,
# so the script reports an elasticity-style sensitivity: if a one-point rise in
# the participation rate moves measured social support by only a fraction s,
# every money figure scales by s. s = 1 is the maximal reading and is NOT the
# recommended one; it is the upper end.
#
# A point in the bridge's favour, since the obvious objection is value transfer
# from a cross-country regression: the WHR specification carries country fixed
# effects, so its coefficients come from within-country variation over time,
# which is the same kind of variation a policy counterfactual generates.
#
#   julia --project=. scripts/wellby_bridge.jl
using Printf, DelimitedFiles

const HERE = @__DIR__
R = Dict{String,Float64}()
for l in eachline(joinpath(HERE, "sa_level4_results.txt"))
    (isempty(l) || startswith(l, "#") || !occursin('\t', l)) && continue
    k, v = split(l, '\t'); R[k] = parse(Float64, v)
end

# ---- verified coefficients --------------------------------------------------
const B_LNY   = 0.588      # WHR25 T10(1), log GDP per capita
const B_SOC   = 2.510      # WHR25 T10(1), social support (0-1 share)
const B_FREE  = 0.947      # WHR25 T10(1), freedom to make life choices (0-1 share)
const SE_SOC  = 0.319
const WELLBY  = 13_000.0   # Green Book central, 2019 GBP
const WELLBY_LO, WELLBY_HI = 10_000.0, 16_000.0
const BETA_Y  = 1.96105    # Green Book / Fujiwara (2021), 0-10 scale

# Average net personal income, the M in the ES formula. The Green Book applies
# this to a UK population; the model is calibrated to France. Both are reported
# so the money figures can be read against either, and neither is load-bearing
# for the ratios, which are unit-free.
const M_UK = 30_000.0

policies = [
    ("work subsidy (20%)",        R["r_sub"],          R["mi_sub"]),
    ("empowerment",               R["r_emp"],          R["mi_emp"]),
    ("participation credit (25%)",R["cred_25_100_r"],  R["cred_25_100_mi"]),
    ("participation credit (66%)",R["cred_66_100_r"],  R["cred_66_100_mi"]),
]
r0, mi0 = R["r0"], R["mi0"]

println("="^92)
println("THE WELLBY BRIDGE: policy effects in life-satisfaction points and money")
println("="^92)
@printf("baseline participation %.4f, baseline mean labour income %.4f (model units)\n", r0, mi0)
@printf("coefficients: log income %.3f, social support %.3f, freedom %.3f (WHR 2025 T10 col 1)\n",
        B_LNY, B_SOC, B_FREE)
@printf("WELLBY %.0f GBP (range %.0f to %.0f), beta_Y %.5f (Green Book 2021)\n\n", WELLBY, WELLBY_LO, WELLBY_HI, BETA_Y)

println("(1) LIFE-SATISFACTION DECOMPOSITION, at the maximal mapping s = 1")
println("    dLS_G = 0.588 * dln(income);  dLS_S = 2.510 * d(participation rate)")
@printf("\n%-28s | %-9s | %-9s | %-9s | %-9s | %s\n",
        "policy", "d ln inc", "dLS_G", "d partic", "dLS_S", "dLS total")
for (nm, r, mi) in policies
    dlny = log(mi/mi0); dG = B_LNY*dlny
    dP = r - r0;        dS = B_SOC*dP
    @printf("%-28s | %+9.4f | %+9.4f | %+9.4f | %+9.4f | %+9.4f\n", nm, dlny, dG, dP, dS, dG+dS)
end

println("\n(2) MONEY, GBP per person per year, at s = 1")
println("    linear: dLS * 13,000 (Green Book default). ES: M[exp(dLS/1.96)-1], M = 30,000.")
@printf("\n%-28s | %-12s | %-12s | %-12s | %-12s\n",
        "policy", "linear (GBP)", "low 10k", "high 16k", "ES formula")
for (nm, r, mi) in policies
    dLS = B_LNY*log(mi/mi0) + B_SOC*(r - r0)
    @printf("%-28s | %+12.0f | %+12.0f | %+12.0f | %+12.0f\n",
            nm, dLS*WELLBY, dLS*WELLBY_LO, dLS*WELLBY_HI, M_UK*(exp(dLS/BETA_Y)-1))
end

println("\n(3) SENSITIVITY TO THE MAPPING ASSUMPTION s")
println("    s is how much measured social support moves per point of participation.")
println("    Every social term scales by s; the material term does not.")
@printf("\n%-28s | %-11s %-11s %-11s %-11s %s\n", "policy (linear GBP)", "s=1.00", "s=0.50", "s=0.25", "s=0.10", "sign flips at s =")
for (nm, r, mi) in policies
    dG = B_LNY*log(mi/mi0); dS1 = B_SOC*(r - r0)
    line = @sprintf("%-28s |", nm)
    for s in (1.00, 0.50, 0.25, 0.10)
        line *= @sprintf(" %+11.0f", (dG + s*dS1)*WELLBY)
    end
    sflip = (dG*dS1 < 0) ? @sprintf("%.3f", -dG/dS1) : "no flip"
    println(line * "  " * sflip)
end

println("\n(4) THE PRICE OF THE FABRIC: model-internal against external")
pi_model_pct = R["pi_model_pct"]; pi_star_pct = R["pi_star_pct"]
# external price of going from zero to full participation, as a share of income
ext_linear_ratio = B_SOC * WELLBY / M_UK           # linear method, share of income
ext_es_ratio     = exp(B_SOC/BETA_Y) - 1           # ES method, share of income
@printf("  model's own shadow price          %6.1f %% of GDP per unit of participation\n", pi_model_pct)
@printf("  breakeven for the work subsidy    %6.1f %% of GDP (subsidy is GDP-B neutral here)\n", pi_star_pct)
@printf("  external, linear WELLBY method    %6.1f %% of income  (2.510 * 13,000 / 30,000)\n", 100*ext_linear_ratio)
@printf("  external, ES method               %6.1f %% of income  (exp(2.510/1.96) - 1)\n", 100*ext_es_ratio)
@printf("  external at s = 0.25, linear      %6.1f %% of income\n", 100*0.25*ext_linear_ratio)
s_break = pi_star_pct / (100 * ext_linear_ratio)
@printf("\n  The external price equals the breakeven at a mapping strength of s = %.2f.\n", s_break)
println("  Above that the work subsidy is GDP-B reducing; below it, GDP-B improving.")
println("  The model's own price sat only a few points above its own breakeven, which is")
println("  why the paper hedges the sign; the external anchor clears it by a factor of")
@printf("  %.1f at s = 1 and still clears it at any s above %.2f.\n", ext_linear_ratio*100/pi_star_pct, s_break)

println("\n(5) COEFFICIENT UNCERTAINTY on the social term (WHR standard error)")
@printf("    social support 2.510 (SE 0.319), so a 95%% interval is %.3f to %.3f,\n",
        B_SOC - 1.96*SE_SOC, B_SOC + 1.96*SE_SOC)
@printf("    which moves the s = 1 linear value of the work subsidy between %+.0f and %+.0f GBP.\n",
        (B_LNY*log(R["mi_sub"]/mi0) + (B_SOC-1.96*SE_SOC)*(R["r_sub"]-r0))*WELLBY,
        (B_LNY*log(R["mi_sub"]/mi0) + (B_SOC+1.96*SE_SOC)*(R["r_sub"]-r0))*WELLBY)

println("\n(6) THE AGENCY SLOT, not yet filled")
@printf("    freedom to make life choices carries %.3f (SE %.3f), about %.2f times the\n",
        B_FREE, 0.239, B_FREE/B_LNY)
println("""    log-income coefficient, so the A dimension has a published price waiting for
    it. It cannot be used until the model produces an agency object on a 0-1
    population-share scale, which it does not yet: agency is currently a wage
    multiplier in the budget constraint and does not enter experienced wellbeing.
    This is the next build step, and the coefficient above is what will price it.""")
println("\nDONE")

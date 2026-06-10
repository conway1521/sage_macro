# The model's own GDP-B exercise (Plan phase 4.1). GDP-B (Brynjolfsson and
# co-authors) adds the value of non-marketed goods to GDP. Here:
#
#   material GDP  Y = mean labour income (the model's output, what the work
#                    subsidy raises)
#   social fabric P = the participation rate (the cohesion stock)
#   GDP-B         = Y + pi * P,  pi = shadow price of the fabric in income units
#
# The shadow price. Phase 2 (the WELLBY bridge) will replace pi with the
# Green Book money value of wellbeing. Here we use the model's OWN price: the
# marginal rate of substitution between the social fabric and consumption in
# experienced wellbeing W = Gamma * u(c) + Lambda * Bbar * P, evaluated at the
# baseline. With u'(c) = Gamma * c^(-gamma),
#
#   pi = (Lambda * Bbar) / (Gamma * cbar^(-gamma)) = (Lambda/Gamma) * Bbar * cbar^gamma,
#
# a fixed shadow price (baseline consumption proxied by baseline mean income).
# We also report the result for a sweep of prices and the breakeven price, so
# the qualitative ranking does not hinge on the exact number.
#
#   julia --project=. scripts/model_gdpb.jl
# Requires sa_credit_summary.txt (run scripts/sa_partcredit_real.jl first) and
# sa_policy_families.txt (run scripts/sa_main.jl first).

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf, Statistics

const OMEGA = 0.30; const KAPPA = 10.0; const SIGMA = 0.5
const Blow = CELL_LOW.B; const Bhigh = CELL_HIGH.B
const Bbar = CELL_LOW.share * Blow + CELL_HIGH.share * Bhigh   # 0.87
const GAMMA = 2.0; const LAMBDA = 0.8757834; const GAM_GAIN = 1.0  # gamma, Lambda, Gamma

# ---------- baseline and empowerment families (cached) -----------------------
d = readdlm(joinpath(@__DIR__, "sa_families.txt"), '\t'; skipstart = 1)
flow  = (d[:, 1], d[:, 2], d[:, 3])
fhigh = (d[:, 1], d[:, 4], d[:, 5])
fmid  = (d[:, 1], d[:, 6], d[:, 7])     # low-edu agency raised to the mean

# ---------- work-subsidy families (cached from sa_main) ----------------------
dp = readdlm(joinpath(@__DIR__, "sa_policy_families.txt"), '\t'; skipstart = 1)
flowP  = (dp[:, 1], dp[:, 2], dp[:, 3])
fhighP = (dp[:, 1], dp[:, 4], dp[:, 5])

Y(fl, fh, r) = population_meaninc(fl, fh, Blow, Bhigh, KAPPA, OMEGA, SIGMA, r)

# ---------- the four states: (name, fabric rate P, material GDP Y) -----------
# Equilibrium rates are the published S+A results; Y computed at each.
r0      = 0.371
r_work  = 0.081
r_emp   = 0.507

# France credit from the real-rate run
cs = readdlm(joinpath(@__DIR__, "sa_credit_summary.txt"), '\t'; skipstart = 1)
row_fr = cs[findfirst(==("france"), cs[:, 1]), :]
r_cred  = row_fr[3]; Y_cred = row_fr[5]

states = [
    ("baseline",            r0,     Y(flow,  fhigh,  r0)),
    ("work subsidy (20%)",  r_work, Y(flowP, fhighP, r_work)),
    ("empowerment",         r_emp,  Y(fmid,  fhigh,  r_emp)),
    ("participation credit",r_cred, Y_cred),
]

Y0 = states[1][3]; P0 = states[1][2]
cbar = Y0                                   # baseline consumption proxy
pi_model = (LAMBDA / GAM_GAIN) * Bbar * cbar^GAMMA   # model-implied shadow price

@printf("Shadow price of the social fabric (model-implied, baseline MRS):\n")
@printf("  pi = (Lambda/Gamma) * Bbar * cbar^gamma = %.4f income units per unit of P\n", pi_model)
@printf("  i.e. a fully participating society's cohesion is worth %.0f%% of GDP\n\n",
        100 * pi_model / Y0)

# ---------- GDP-B table at the model price -----------------------------------
@printf("%-22s | %-6s | %-8s | %-8s | %-8s | %-8s\n",
        "state", "P", "GDP", "dGDP%", "GDP-B", "dGDPB%")
gdpb0 = Y0 + pi_model * P0
for (name, P, Yv) in states
    gdpb = Yv + pi_model * P
    @printf("%-22s | %.3f  | %.4f  | %+5.1f   | %.4f  | %+5.1f\n",
            name, P, Yv, 100 * (Yv - Y0) / Y0, gdpb, 100 * (gdpb - gdpb0) / gdpb0)
end

# ---------- breakeven price for the work subsidy -----------------------------
# subsidy GDP-B = baseline GDP-B  =>  pi* = (Y_work - Y0) / (P0 - P_work)
Y_work = states[2][3]; P_work = states[2][2]
pi_star = (Y_work - Y0) / (P0 - P_work)
@printf("\nBreakeven: the work subsidy raises GDP by %+.1f%% but cuts participation\n",
        100 * (Y_work - Y0) / Y0)
@printf("from %.3f to %.3f. Its GDP-B equals baseline when pi = %.4f (= %.0f%% of GDP\n",
        P0, P_work, pi_star, 100 * pi_star / Y0)
@printf("per unit of P). Above that price the make-work-pay subsidy LOWERS inclusive\n")
@printf("output. The model price pi = %.4f is %.1fx the breakeven, so under the\n",
        pi_model, pi_model / pi_star)
@printf("model's own valuation the subsidy is GDP-B-reducing.\n")

# ---------- price sweep (robustness of the ranking) --------------------------
println("\nGDP-B ranking under a sweep of shadow prices (fraction theta of GDP per unit P):")
@printf("%-8s | %-12s | %-12s | %-12s | %-12s\n",
        "theta", "baseline", "work subsidy", "empowerment", "credit")
for theta in (0.10, 0.20, 0.33, 0.50)
    pit = theta * Y0
    vals = [Yv + pit * P for (_, P, Yv) in states]
    @printf("%.2f     | %.4f      | %.4f      | %.4f      | %.4f\n",
            theta, vals[1], vals[2], vals[3], vals[4])
end

# ---------- save for the papers ----------------------------------------------
open(joinpath(@__DIR__, "model_gdpb_table.txt"), "w") do io
    println(io, join(["state", "P", "GDP", "GDP_B_model"], '\t'))
    for (name, P, Yv) in states
        println(io, join([name, P, Yv, Yv + pi_model * P], '\t'))
    end
end
println("\nsaved model_gdpb_table.txt")
println("DONE")

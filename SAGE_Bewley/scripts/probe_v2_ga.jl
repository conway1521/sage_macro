# Stage 1b with dread in choices (V3_START.md section 123): the quarterly economy with flows fitted to the duration of
# unemployment, G against G+A at the same patience, so that the difference in the fall on job loss is dread's. Dread
# is Pagel's weight on the quarter's employment lottery (the same term as version 1, read per period). Job search is
# off: the exits are the data's hazards, since version 1's search costs are annual and are refitted at stage 1d. The
# cost of being out of work is in wellbeing only and is left out. Patience: the annual level given (nearest each
# country's hand-to-mouth target in section 121), the cells' gap kept. The persistence of income is fixed (`fix_rho`).
#
#   SAGE_DREAD_CHOICE=1 julia --project=scripts/run_env scripts/probe_v2_ga.jl CODE BETA_ANNUAL MODE    (MODE: G or GA)
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); βa = parse(Float64, ARGS[2]); mode = uppercase(ARGS[3])
get(ENV, "SAGE_DREAD_CHOICE", "0") == "1" || error("run with SAGE_DREAD_CHOICE=1 (dread in choices)")
ca = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
wt = country_config(code; config = "GA", v3 = :v5m, S = false, A = true).dread
cb = duration_config(ca)
gap = -ca.beta_cell[1]
c = SAGEConfig(cb; beta_bar = βa^(1 / 4), beta_cell = ((βa - gap)^(1 / 4) - βa^(1 / 4), 0.0))
mode == "GA" && (c = SAGEConfig(c; A = true, dread = wt, dread_mode = :behaviour, search = false, out_ls = 0.0))
HTM = Dict("FR" => 0.2680, "DE" => 0.2517, "IT" => 0.2028)
t = @elapsed r = solve_economy(c; cache = false)
@printf("%s stage 1b %s (dread weight %.2f), annual patience %.4f: htm %.4f (target %.4f) | median/yr %.4f | MPC %.4f | fall %.4f | out %.4f | budget %.1e | %.1f min\n",
        code, mode, mode == "GA" ? wt : 0.0, βa, r.hand_to_mouth_kvw, HTM[code], r.wealth_p50 / (4 * r.median_income), r.mpc, r.consumption_drop, r.unemployment, r.budget_gap, t / 60)
println("DONE")

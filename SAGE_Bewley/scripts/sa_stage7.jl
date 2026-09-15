# Stage 7 driver: stage 6 plus permanent discount-factor heterogeneity, the one
# of the two stage-7 fixes that the probes accepted. Specification in
# STAGE7.md; the record there also carries the rejection of the other fix.
#
# The monetary participation cost is NOT in this run. Probes 1 to 3 rejected
# it: a fixed money cost moves the employed-to-unemployed participation ratio
# the wrong way, and no scaling of the belonging payoff, down to one percent of
# its value, reproduces the observed collapse on job loss. The reason is in
# `s7_probe3.txt`: the participation time lump costs 0.489 in utility to a
# household at the calibrated work share and 0.005 to one at zero, a factor of
# a hundred, so participation is nearly free to anyone not working. That is a
# defect in how the participation margin is specified, not a parameter, and it
# is left standing and flagged rather than papered over.
#
#   julia --project=. scripts/sa_stage6.jl            # omega 0.30
#   julia --project=. scripts/sa_stage6.jl 0.15       # another omega
# Parallel over 13 worker processes (s6_workers.jl); do not use -t.
#
# Writes sa_stage7*.txt (log), sa_stage7_results*.txt (key = value),
# sa_stage7_valley*.txt (the calibration valley). The suffix records a pinned
# sigma and a non-central omega when either is used.

include(joinpath(@__DIR__, "s7_workers.jl"))
const OMEGA = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 0.30
# Optionally PIN the social technology instead of calibrating it. The loss
# surface in sigma is jagged at a scale of 0.005 and the scan's minimum sits on
# a narrow spike whose slope, and so whose policy multiplier, is nothing like
# the surrounding region's; see the calibration-robustness section below. Every
# discretisation has been ruled out as the cause (s7_diag_ugrid, s7_diag_nbeta,
# s7_diag_quad), so the spike is a property of the model, and pinning is how
# the headline is checked at a point the moments fit almost as well.
#   julia --project=. scripts/sa_stage7.jl 0.30 9.90 0.400
const PIN = length(ARGS) >= 3 ? (parse(Float64, ARGS[2]), parse(Float64, ARGS[3])) : nothing
const TAG   = (PIN !== nothing ? @sprintf("_pin%03d", round(Int, 1000 * PIN[2])) : "") *
              (abs(OMEGA - 0.30) < 1e-9 ? "" : @sprintf("_om%03d", round(Int, 100 * OMEGA)))
const NABLA = 0.036          # downward discount spread, calibrated to hand-to-mouth 0.30
const ALPHA_MID = 0.838
const TAU_SUB = 0.20
const RHO_CRED = 0.25
const RR_UP = RR + 0.10

const RESULTS = Dict{String,Any}()
rec!(k, v) = (RESULTS[k] = v)

@printf("stage 7 | omega %.2f | workers %d | theta %.4f | grid a_max %.1f pexp %.1f na %d ne %d\n",
        OMEGA, nworkers(), THETA, GRID.a_max, GRID.pexp, NA, NE)
let (bs, _) = beta_types(NABLA)
    @printf("discount factors: nabla %.3f, %d equal-mass points %s, max beta*R %.4f\n",
            NABLA, length(bs), string(round.(bs, digits = 4)), maximum(bs) * 1.02)
    rec!("nabla", NABLA)
end
@printf("labour market: f %.4f, delta low %.4f high %.4f, u low %.4f high %.4f, rr %.2f\n",
        F_FIND, DELTA_LOW, DELTA_HIGH, DELTA_LOW/(DELTA_LOW+F_FIND), DELTA_HIGH/(DELTA_HIGH+F_FIND), RR)
println()

include(joinpath(@__DIR__, "s7_pop.jl"))

# ========================================================== A. baseline ====
println("="^78); println("A. BASELINE FAMILIES AND THE STAGE-5B POINT (P3)"); println("="^78)
const T_UI = ui_tax(CELLS, F_FIND, RR)
@printf("closed-form UI tax  %.5f\n", T_UI); rec!("T_UI", T_UI)
fl0 = family_u(CELLS[1].α, CELLS[1].δ; lumptax = T_UI)
fh0 = family_u(CELLS[2].α, CELLS[2].δ; lumptax = T_UI)
E5 = equilibrium(fl0, fh0, 10.00, 0.510)
if E5 === nothing
    println("no stable equilibrium at (10.00, 0.510)")
    rec!("r_at_5b_point", NaN)
else
    @printf("at (kappa, sigma) = (10.00, 0.510): rate %.4f (stage 6: 0.4136), groups %.4f / %.4f\n",
            E5.r, E5.lo, E5.hi)
    rec!("r_at_5b_point", E5.r)
    println("P3 ", E5.r > 0.3526 ? "holds: participation rises before recalibration" :
                                   "FAILS: participation does not rise")
end

# =================================================== B. dense recalibration
println(); println("="^78); println("B. RECALIBRATION: dense scan, kappa free at each sigma"); println("="^78)
# For each sigma, the cell rate depends on the product kappa*B*arg only, so it is
# tabulated once on a fine x grid; the scan is then interpolation on that.
const XGRID = collect(0.0:0.02:60.0)
function xtable(fam, σ)
    ms = tastes(σ)
    [mean(interp(fam.u, fam.r, x * m) for m in ms) for x in XGRID]
end
function scan_loss(Rl, Rh, κ; ngrid = 401)
    g = range(0.0, 1.0, length = ngrid)
    f(r) = (arg = OMEGA + (1-OMEGA)*r;
            lo = interp(XGRID, Rl, κ * CELLS[1].B * arg); hi = interp(XGRID, Rh, κ * CELLS[2].B * arg);
            (CELLS[1].share*lo + CELLS[2].share*hi, lo, hi))
    o = [f(r)[1] for r in g]; best = Inf; bestr = NaN; blo = NaN; bhi = NaN; nst = 0
    for i in 1:ngrid-1
        d1 = o[i]-g[i]; d2 = o[i+1]-g[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            sl = (o[i+1]-o[i])/(g[i+1]-g[i]); sl < 1 || continue
            nst += 1
            rs = g[i] + d1/(d1-d2)*(g[i+1]-g[i]); _, lo, hi = f(rs)
            L = (lo - 0.25)^2 + (hi - 0.45)^2
            L < best && (best = L; bestr = rs; blo = lo; bhi = hi)
        end
    end
    (L = best, r = bestr, lo = blo, hi = bhi, nstable = nst)
end
const SIGMAS = collect(0.30:0.01:1.00)
const KAPPAS = collect(2.0:0.05:20.0)
valley = NamedTuple[]
gbest = (L = Inf, κ = NaN, σ = NaN)
for σ in SIGMAS
    global gbest
    Rl = xtable(fl0, σ); Rh = xtable(fh0, σ)
    kb = (L = Inf, κ = NaN, e = nothing)
    for κ in KAPPAS
        e = scan_loss(Rl, Rh, κ)
        isfinite(e.L) && e.L < kb.L && (kb = (L = e.L, κ = κ, e = e))
    end
    isfinite(kb.L) || continue
    push!(valley, (σ = σ, κ = kb.κ, L = kb.L, r = kb.e.r, lo = kb.e.lo, hi = kb.e.hi, nstable = kb.e.nstable))
    kb.L < gbest.L && (gbest = (L = kb.L, κ = kb.κ, σ = σ))
end
@printf("coarse global minimum: kappa %.2f sigma %.3f root loss %.4f\n", gbest.κ, gbest.σ, sqrt(gbest.L))
# refine on the exact quadrature around the coarse minimum, wide enough to
# cross into neighbouring basins if there are any
fine = (L = Inf, κ = NaN, σ = NaN, e = nothing)
for σ in (gbest.σ - 0.03):0.005:(gbest.σ + 0.03), κ in (gbest.κ - 0.6):0.02:(gbest.κ + 0.6)
    global fine
    σ <= 0 && continue
    e = equilibrium(fl0, fh0, κ, σ); e === nothing && continue
    L = (e.lo - 0.25)^2 + (e.hi - 0.45)^2
    L < fine.L && (fine = (L = L, κ = κ, σ = σ, e = e))
end
const KAPPA = PIN === nothing ? fine.κ : PIN[1]
const SIGMA = PIN === nothing ? fine.σ : PIN[2]
E0 = PIN === nothing ? fine.e : equilibrium(fl0, fh0, KAPPA, SIGMA)
PIN === nothing || @printf("PINNED instead of calibrated: kappa %.2f sigma %.3f, root loss %.4f\n",
                           KAPPA, SIGMA, sqrt((E0.lo - 0.25)^2 + (E0.hi - 0.45)^2))
@printf("refined:               kappa %.2f sigma %.3f root loss %.4f\n", KAPPA, SIGMA, sqrt(fine.L))
@printf("equilibrium rate %.4f, groups %.4f / %.4f (targets 0.25 / 0.45), slope %.4f, stable equilibria %d\n",
        E0.r, E0.lo, E0.hi, E0.slope, E0.nstable)
rec!("kappa", KAPPA); rec!("sigma", SIGMA); rec!("rootloss", sqrt(fine.L))
rec!("r_base", E0.r); rec!("lo_base", E0.lo); rec!("hi_base", E0.hi); rec!("slope_base", E0.slope)
rec!("mult_base", 1 / (1 - E0.slope)); rec!("nstable_base", E0.nstable)
# the valley, with the bound computed by the stage-5b formula on the population cell rates
open(joinpath(@__DIR__, "sa_stage7_valley" * TAG * ".txt"), "w") do io
    println(io, join(["sigma", "kappa", "rootloss", "rate", "lo", "hi", "sigbar", "ratio", "nstable"], '\t'))
    for v in valley
        comp = (1 - OMEGA) / (OMEGA + (1 - OMEGA) * v.r)
        dens = 0.5 * phi(quantile_normal(1 - v.lo)) + 0.5 * phi(quantile_normal(1 - v.hi))
        sb = comp * dens
        println(io, join([v.σ, v.κ, sqrt(v.L), v.r, v.lo, v.hi, sb, v.σ / sb, v.nstable], '\t'))
    end
end
println("valley written; loss along the floor at selected sigma:")
for v in valley
    mod(round(Int, 100v.σ), 10) == 0 || continue
    @printf("  sigma %.2f  kappa %.2f  root loss %.4f  rate %.4f  groups %.3f/%.3f\n", v.σ, v.κ, sqrt(v.L), v.r, v.lo, v.hi)
end
let comp = (1 - OMEGA) / (OMEGA + (1 - OMEGA) * E0.r),
    dens = 0.5 * phi(quantile_normal(1 - E0.lo)) + 0.5 * phi(quantile_normal(1 - E0.hi))
    sb = comp * dens
    @printf("bound sigma-bar %.4f, ratio sigma/sigma-bar %.3f (stage 5b: 0.4626, 1.103)\n", sb, SIGMA / sb)
    rec!("sigbar", sb); rec!("ratio", SIGMA / sb)
end

# ---- is the multiplier identified? ------------------------------------------
println()
println("calibration robustness: the slope, and so the policy multiplier, across the")
println("region the moments fit almost as well. Every discretisation has been ruled")
println("out as the cause of the roughness (s7_diag_ugrid, s7_diag_nbeta, s7_diag_quad).")
@printf("%-8s %-8s %-10s %-8s %-8s %-8s %s\n", "sigma", "kappa", "rootloss", "rate", "slope", "mult", "ratio")
println("-"^62)
let acc = NamedTuple[]
    for σ in 0.34:0.005:0.50
        Rl = xtable(fl0, σ); Rh = xtable(fh0, σ)
        kb = nothing
        for κ in KAPPAS
            e = scan_loss(Rl, Rh, κ)
            isfinite(e.L) && (kb === nothing || e.L < kb.L) && (kb = (L = e.L, κ = κ, e = e))
        end
        kb === nothing && continue
        ee = equilibrium(fl0, fh0, kb.κ, σ); ee === nothing && continue
        comp = (1 - OMEGA) / (OMEGA + (1 - OMEGA) * ee.r)
        dens = 0.5 * phi(quantile_normal(1 - ee.lo)) + 0.5 * phi(quantile_normal(1 - ee.hi))
        push!(acc, (σ = σ, κ = kb.κ, L = sqrt(kb.L), r = ee.r, slope = ee.slope, ratio = σ / (comp * dens)))
    end
    lmin = minimum(x.L for x in acc)
    for x in acc
        mark = x.L <= 1.5 * lmin ? " <- acceptable fit" : ""
        @printf("%-8.3f %-8.2f %-10.4f %-8.4f %-8.4f %-8.1f %.3f%s\n",
                x.σ, x.κ, x.L, x.r, x.slope, 1 / (1 - x.slope), x.ratio, mark)
    end
    ok = [x for x in acc if x.L <= 1.5 * lmin]
    @printf("\nover the acceptable-fit region, root loss within half again of the minimum:\n")
    @printf("  sigma %.3f to %.3f, slope %.4f to %.4f, multiplier %.1f to %.1f, ratio %.3f to %.3f\n",
            minimum(x.σ for x in ok), maximum(x.σ for x in ok),
            minimum(x.slope for x in ok), maximum(x.slope for x in ok),
            minimum(1 / (1 - x.slope) for x in ok), maximum(1 / (1 - x.slope) for x in ok),
            minimum(x.ratio for x in ok), maximum(x.ratio for x in ok))
    rec!("slope_lo", minimum(x.slope for x in ok)); rec!("slope_hi", maximum(x.slope for x in ok))
    rec!("mult_lo", minimum(1 / (1 - x.slope) for x in ok)); rec!("mult_hi", maximum(1 / (1 - x.slope) for x in ok))
    rec!("ratio_lo", minimum(x.ratio for x in ok)); rec!("ratio_hi", maximum(x.ratio for x in ok))
    println("  the moments do not identify the multiplier; policy magnitudes inherit this range")
end

# ====================================================== C. poverty line ====
println(); println("="^78); println("C. THE POVERTY LINE, ANCHORED AT THIS BASELINE"); println("="^78)
Pl0 = pool(fl0, CELLS[1].B, KAPPA, SIGMA, E0.r); Ph0 = pool(fh0, CELLS[2].B, KAPPA, SIGMA, E0.r)
Ypop = CELLS[1].share * Pl0.Y + CELLS[2].share * Ph0.Y
med0 = cdf_quantile(YGRID, Ypop, 0.5)
const YPOV = 0.5 * med0
const ABAR = hardship_threshold(med0; months = MONTHS)
ymean0 = CELLS[1].share * Pl0.ymean + CELLS[2].share * Ph0.ymean
@printf("median disposable income %.4f (mean %.4f, ratio %.3f)\n", med0, ymean0, med0 / ymean0)
@printf("poverty line %.4f, asset threshold %.4f\n", YPOV, ABAR)
@printf("lowest employed disposable income %.4f / %.4f  (must exceed the line: %s)\n",
        Pl0.ymin_E, Ph0.ymin_E, min(Pl0.ymin_E, Ph0.ymin_E) > YPOV ? "yes" : "NO")
@printf("benefit net of tax, low cell z1/z2: %.4f / %.4f ; high cell: %.4f / %.4f\n",
        (fl0.transfer[1:2] .- T_UI)..., (fh0.transfer[1:2] .- T_UI)...)
rec!("median0", med0); rec!("ypov", YPOV); rec!("abar", ABAR); rec!("ymean0", ymean0)
for (nm, v) in (("bnet_lo_z1", fl0.transfer[1] - T_UI), ("bnet_lo_z2", fl0.transfer[2] - T_UI),
                ("bnet_hi_z1", fh0.transfer[1] - T_UI), ("bnet_hi_z2", fh0.transfer[2] - T_UI))
    rec!(nm, v); rec!(nm * "_gap_pct", 100 * (v / YPOV - 1))
end
@printf("net benefit relative to the line, percent: low z1 %+.1f, low z2 %+.1f, high z1 %+.1f, high z2 %+.1f\n",
        RESULTS["bnet_lo_z1_gap_pct"], RESULTS["bnet_lo_z2_gap_pct"], RESULTS["bnet_hi_z1_gap_pct"], RESULTS["bnet_hi_z2_gap_pct"])
# threshold pairs stored in every family: anchored first, then the horizons
# and the plus and minus ten percent moves the sensitivity section reports
const THR = [(YPOV, ABAR),
             (YPOV, hardship_threshold(med0; months = 1.0)),
             (YPOV, hardship_threshold(med0; months = 6.0)),
             (YPOV, hardship_threshold(med0; months = 12.0)),
             (0.9 * YPOV, 0.9 * ABAR), (1.1 * YPOV, 1.1 * ABAR)]
const THR_LABEL = ["3 months", "1 month", "6 months", "12 months", "line -10%", "line +10%"]

# rebuild the baseline with the joint indicators stored; the rate column must not move
fl0t = family_u(CELLS[1].α, CELLS[1].δ; lumptax = T_UI, thresholds = THR)
fh0t = family_u(CELLS[2].α, CELLS[2].δ; lumptax = T_UI, thresholds = THR)
@printf("rate column identical after rebuild: %s\n", fl0t.r == fl0.r && fh0t.r == fh0.r ? "yes" : "NO")
Pl0 = pool(fl0t, CELLS[1].B, KAPPA, SIGMA, E0.r); Ph0 = pool(fh0t, CELLS[2].B, KAPPA, SIGMA, E0.r)
B = population(Pl0, Ph0)

# ================================================== D. baseline dashboard ==
println(); println("="^78); println("D. BASELINE: S, A AND THE OECD CATEGORIES"); println("="^78)
@printf("participation            %.4f   (by cell %.4f / %.4f)\n", B.rate, Pl0.rate, Ph0.rate)
@printf("  employed / unemployed  %.4f / %.4f   INSEE membership 0.35 / 0.17\n", B.rate_E, B.rate_U)
@printf("  by cell, employed      %.4f / %.4f ; unemployed %.4f / %.4f\n", Pl0.rate_E, Ph0.rate_E, Pl0.rate_U, Ph0.rate_U)
println("P4 ", B.rate_U > B.rate_E ? "holds: the unemployed participate MORE in the model, against the data" :
                                     "FAILS: the unemployed participate less, which the prediction did not expect")
@printf("unemployment rate        %.4f   (INSEE 0.074; model cells 0.094 / 0.050)\n", B.u)
@printf("mean effort, employed    %.4f   (phi was set for a population mean of 0.53)\n", B.eff_E)
htm = share_below_interp(B.agrid, B.Wtot, (4 / 52) * B.minc)
@printf("hand-to-mouth (4 weeks)  %.4f   (0.30 in the data, 0.32 at stage 5b)\n", htm)
@printf("wealth p50 / p90 / p99   %.4f / %.4f / %.4f\n",
        cdf_quantile(B.agrid, B.Wtot, 0.5), cdf_quantile(B.agrid, B.Wtot, 0.9), cdf_quantile(B.agrid, B.Wtot, 0.99))
println()
println("OECD categories, population and by employment status:")
@printf("  income-poor            %.4f   (INSEE 2024 at 50 percent: 0.088)\n", B.inc)
@printf("    among unemployed     %.4f   (INSEE: 0.243)\n", B.inc_U)
@printf("    among employed       %.4f   (INSEE, salaried: 0.034)\n", B.inc_E)
@printf("  asset-poor             %.4f   (OECD 2025, France: below 0.40; stage 5b model 0.428)\n", B.asset)
@printf("    among unemployed     %.4f\n", B.asset_U)
@printf("    among employed       %.4f\n", B.asset_E)
@printf("  both                   %.4f\n", B.both)
@printf("  vulnerable             %.4f   (OECD average 0.36)\n", B.vulnerable)
@printf("  union (hardship)       %.4f\n", B.union)
@printf("agency A                 %.4f   (by cell %.4f / %.4f; stage 5b 0.4795)\n", B.A, B.A_l, B.A_h)
for (k, v) in (("rate_E", B.rate_E), ("rate_U", B.rate_U), ("rate_lo_E", Pl0.rate_E), ("rate_hi_E", Ph0.rate_E),
               ("rate_lo_U", Pl0.rate_U), ("rate_hi_U", Ph0.rate_U), ("u_base", B.u), ("eff_E", B.eff_E), ("htm", htm),
               ("inc_base", B.inc), ("inc_U_base", B.inc_U), ("inc_E_base", B.inc_E), ("asset_base", B.asset),
               ("asset_U_base", B.asset_U), ("asset_E_base", B.asset_E), ("both_base", B.both),
               ("vuln_base", B.vulnerable), ("union_base", B.union), ("A_base", B.A), ("A_lo_base", B.A_l),
               ("A_hi_base", B.A_h), ("ymin_E_lo", Pl0.ymin_E), ("ymin_E_hi", Ph0.ymin_E))
    rec!(k, v)
end
println()
println()
println("STAGE 7 CHECKS on the baseline")
@printf("  hand-to-mouth %.4f against the 0.30 target: %s\n", htm,
        abs(htm - 0.30) < 0.02 ? "on target" : "OFF TARGET, nabla needs adjusting")
@printf("  asset poverty %.4f against stage 6's 0.2132 and stage 5b's 0.428\n", B.asset)
@printf("  unemployed participation %.4f against employed %.4f: the stage-6 artefact %s\n",
        B.rate_U, B.rate_E, B.rate_U > B.rate_E ? "REMAINS, as expected and flagged" : "is gone")

# ============================================================ E. policies ==
println(); println("="^78); println("E. POLICIES at the recalibrated point"); println("="^78)
function fiscal_subsidy(τ)
    T = τ * meaninc(fl0t, fh0t, KAPPA, SIGMA, E0.r)
    local fl, fh, E
    for it in 1:8
        fl = family_u(CELLS[1].α, CELLS[1].δ; subsidy = τ, lumptax = T_UI + T, thresholds = THR)
        fh = family_u(CELLS[2].α, CELLS[2].δ; subsidy = τ, lumptax = T_UI + T, thresholds = THR)
        E = equilibrium(fl, fh, KAPPA, SIGMA)
        Tn = τ * meaninc(fl, fh, KAPPA, SIGMA, E.r)
        @printf("  subsidy iteration %d: rate %.4f, T %.5f -> %.5f\n", it, E.r, T, Tn)
        abs(Tn - T) < 1e-4 && break          # do not advance T past the families just built
        T = Tn
    end
    (fl = fl, fh = fh, E = E, T = T)
end
function fiscal_credit(ρ)
    T = 0.0
    local fl, fh, E
    for it in 1:8
        fl = family_u(CELLS[1].α, CELLS[1].δ; partcredit = ρ, lumptax = T_UI + T, thresholds = THR)
        fh = family_u(CELLS[2].α, CELLS[2].δ; partcredit = ρ, lumptax = T_UI + T, thresholds = THR)
        E = equilibrium(fl, fh, KAPPA, SIGMA)
        Tn = QBAR * ρ * partbase(fl, fh, KAPPA, SIGMA, E.r)
        @printf("  credit iteration %d: rate %.4f, T %.5f -> %.5f\n", it, E.r, T, Tn)
        abs(Tn - T) < 1e-4 && break
        T = Tn
    end
    (fl = fl, fh = fh, E = E, T = T)
end
S = fiscal_subsidy(TAU_SUB)
CELLS_EMP = ((CELLS[1]..., α = ALPHA_MID), CELLS[2])
T_UI_EMP = ui_tax(CELLS_EMP, F_FIND, RR)
fmid = family_u(ALPHA_MID, CELLS[1].δ; lumptax = T_UI_EMP, thresholds = THR)
fh_emp = family_u(CELLS[2].α, CELLS[2].δ; lumptax = T_UI_EMP, thresholds = THR)
EM = equilibrium(fmid, fh_emp, KAPPA, SIGMA)
C = fiscal_credit(RHO_CRED)
T_UI_UP = ui_tax(CELLS, F_FIND, RR_UP)
fl_up = family_u(CELLS[1].α, CELLS[1].δ; rr = RR_UP, lumptax = T_UI_UP, thresholds = THR)
fh_up = family_u(CELLS[2].α, CELLS[2].δ; rr = RR_UP, lumptax = T_UI_UP, thresholds = THR)
EU = equilibrium(fl_up, fh_up, KAPPA, SIGMA)
T_UI_FL = ui_tax(CELLS, F_FIND, RR_FLOOR)
fl_fl = family_u(CELLS[1].α, CELLS[1].δ; rr = RR_FLOOR, lumptax = T_UI_FL, thresholds = THR)
fh_fl = family_u(CELLS[2].α, CELLS[2].δ; rr = RR_FLOOR, lumptax = T_UI_FL, thresholds = THR)
EF = equilibrium(fl_fl, fh_fl, KAPPA, SIGMA)
@printf("\nlump taxes: UI %.5f, subsidy %.5f, credit %.5f; UI at rr %.2f: %.5f, at rr %.2f: %.5f\n",
        T_UI, S.T, C.T, RR_UP, T_UI_UP, RR_FLOOR, T_UI_FL)
rec!("T_sub", S.T); rec!("T_cred", C.T); rec!("T_UI_up", T_UI_UP); rec!("T_UI_floor", T_UI_FL); rec!("T_UI_emp", T_UI_EMP)

POL = [(name = "baseline", tag = "base", fl = fl0t, fh = fh0t, E = E0),
       (name = "work subsidy", tag = "sub", fl = S.fl, fh = S.fh, E = S.E),
       (name = "empowerment", tag = "emp", fl = fmid, fh = fh_emp, E = EM),
       (name = "participation credit", tag = "cred", fl = C.fl, fh = C.fh, E = C.E),
       (name = @sprintf("UI rr %.2f", RR_UP), tag = "uiup", fl = fl_up, fh = fh_up, E = EU),
       (name = @sprintf("UI rr %.2f", RR_FLOOR), tag = "uifloor", fl = fl_fl, fh = fh_fl, E = EF)]
rows = NamedTuple[]
for P in POL
    Pl = pool(P.fl, CELLS[1].B, KAPPA, SIGMA, P.E.r); Ph = pool(P.fh, CELLS[2].B, KAPPA, SIGMA, P.E.r)
    push!(rows, (P..., Pl = Pl, Ph = Ph, pop = population(Pl, Ph)))
end
println()
@printf("%-22s | %-6s | %-6s %-6s | %-6s %-6s %-6s %-6s | %-6s %-7s\n",
        "policy", "r (S)", "r_E", "r_U", "inc", "asset", "vuln", "union", "A", "dA")
println("-"^96)
for x in rows
    b = x.pop
    @printf("%-22s | %.4f | %.4f %.4f | %.4f %.4f %.4f %.4f | %.4f %+.4f\n",
            x.name, b.rate, b.rate_E, b.rate_U, b.inc, b.asset, b.vulnerable, b.union, b.A, b.A - rows[1].pop.A)
    # income-only agency: the source's own concept, p = Pr[income below the line]
    Ainc = CELLS[1].share * x.Pl.alpha * (1 - b.hl.inc) + CELLS[2].share * x.Ph.alpha * (1 - b.hh.inc)
    for (k, v) in (("r", b.rate), ("rE", b.rate_E), ("rU", b.rate_U), ("inc", b.inc), ("asset", b.asset),
                   ("vuln", b.vulnerable), ("union", b.union), ("A", b.A), ("A_lo", b.A_l), ("A_hi", b.A_h),
                   ("Ainc", Ainc), ("inc_U", b.inc_U), ("inc_E", b.inc_E), ("asset_E", b.asset_E), ("asset_U", b.asset_U),
                   ("inc_lo", b.hl.inc), ("inc_hi", b.hh.inc), ("asset_lo", b.hl.asset), ("asset_hi", b.hh.asset),
                   ("both_lo", b.hl.both), ("both_hi", b.hh.both),
                   ("union_lo", b.hl.union), ("union_hi", b.hh.union), ("ymean", b.ymean),
                   ("ymin_E", min(x.Pl.ymin_E, x.Ph.ymin_E)))
        rec!(k * "_" * x.tag, v)
    end
end
println()
println("by employment status: hardship (union) and asset poverty, employed / unemployed")
for x in rows
    b = x.pop
    uE = (CELLS[1].share*(1-x.Pl.u)*b.hl.union_E + CELLS[2].share*(1-x.Ph.u)*b.hh.union_E) / (CELLS[1].share*(1-x.Pl.u) + CELLS[2].share*(1-x.Ph.u))
    uU = (CELLS[1].share*x.Pl.u*b.hl.union_U + CELLS[2].share*x.Ph.u*b.hh.union_U) / (CELLS[1].share*x.Pl.u + CELLS[2].share*x.Ph.u)
    @printf("  %-22s union %.4f / %.4f   asset %.4f / %.4f   income %.4f / %.4f\n",
            x.name, uE, uU, b.asset_E, b.asset_U, b.inc_E, b.inc_U)
    rec!("union_E_" * x.tag, uE); rec!("union_U_" * x.tag, uU)
end
println()
println("decomposition of the change in A: alpha channel, hardship channel, interaction")
base = rows[1].pop
for x in rows[2:end]
    b = x.pop
    dα = 0.0; dh = 0.0; cr = 0.0
    for (sh, a0, h0, a1, h1) in ((CELLS[1].share, rows[1].Pl.alpha, base.hl.union, x.Pl.alpha, b.hl.union),
                                 (CELLS[2].share, rows[1].Ph.alpha, base.hh.union, x.Ph.alpha, b.hh.union))
        dα += sh * (a1 - a0) * (1 - h0); dh += sh * a0 * (h0 - h1); cr += sh * (a1 - a0) * (h0 - h1)
    end
    @printf("  %-22s dA %+.4f = alpha %+.4f + hardship %+.4f + interaction %+.4f\n", x.name, b.A - base.A, dα, dh, cr)
    rec!("dA_" * x.tag, b.A - base.A); rec!("dA_alpha_" * x.tag, dα); rec!("dA_hard_" * x.tag, dh)
end
println()
println("two hardship concepts side by side: A on the OECD union (headline) and A on income only (the source's p)")
@printf("%-22s | %-8s %-8s | %-8s %-8s\n", "policy", "A union", "dA", "A income", "dA")
println("-"^62)
for x in rows
    Au = RESULTS["A_" * x.tag]; Ai = RESULTS["Ainc_" * x.tag]
    @printf("%-22s | %.4f   %+.4f | %.4f   %+.4f\n", x.name, Au, Au - RESULTS["A_base"], Ai, Ai - RESULTS["Ainc_base"])
    rec!("dAinc_" * x.tag, Ai - RESULTS["Ainc_base"])
end
println()
let sub = rows[2].pop, emp = rows[3].pop, cr = rows[4].pop, up = rows[5].pop
    println("STAGE 7 PREDICTIONS, scored against STAGE7.md Part 5")
    @printf("P4  sigma_m below stage 6's 0.395: %.3f, %s\n", SIGMA, SIGMA < 0.395 ? "holds" : "FAILS")
    @printf("P5  map slope within 0.03 of stage 6's 0.947: %.4f, %s\n", E0.slope,
            abs(E0.slope - 0.947) <= 0.03 ? "holds" : "FAILS")
    @printf("P6  asset poverty in [0.35, 0.45]: %.4f, %s; hand-to-mouth %.4f\n", base.asset,
            0.35 <= base.asset <= 0.45 ? "holds" : "FAILS", RESULTS["htm"])
    @printf("P7  agency A in [0.48, 0.58]: %.4f, %s\n", base.A, 0.48 <= base.A <= 0.58 ? "holds" : "FAILS")
    @printf("P8  subsidy raises A and lowers participation: %s (dA %+.4f, dr %+.4f)\n",
            (sub.A > base.A && sub.rate < base.rate) ? "holds" : "FAILS", sub.A - base.A, sub.rate - base.rate)
    @printf("P9  higher replacement rate still lowers A, by at least a third less than 0.0944: %+.4f, %s\n",
            up.A - base.A, (up.A < base.A && abs(up.A - base.A) <= 0.0944 * 2/3) ? "holds" :
                           (up.A >= base.A ? "FAILS on sign" : "FAILS on magnitude"))
    @printf("P10 the two hardship concepts still disagree in sign on the replacement rate: %s\n",
            sign(RESULTS["dA_uiup"]) != sign(RESULTS["dAinc_uiup"]) ? "holds, the stage-6 finding survives" :
                                                                      "FAILS, the finding must be withdrawn")
    @printf("    union %+.4f against income-only %+.4f\n", RESULTS["dA_uiup"], RESULTS["dAinc_uiup"])
    println()
    println("carried over from stage 6, for continuity:")
    @printf("    empowerment mostly mechanical: %s\n",
            abs(RESULTS["dA_alpha_emp"]) > 0.8 * abs(RESULTS["dA_emp"]) ? "yes" : "no")
    @printf("    credit small positive on A: %s (%+.4f)\n",
            (0 < cr.A - base.A < 0.02) ? "yes" : "no", cr.A - base.A)
    @printf("    low-cell hardship change under the subsidy %+.4f (stage 6: -0.0538)\n",
            sub.hl.union - base.hl.union)
end

# ======================================================== F. sensitivity ==
println(); println("="^78); println("F. SENSITIVITY"); println("="^78)
println("stored threshold pairs, exact: union hardship / A")
@printf("%-22s |%s\n", "policy", join([@sprintf("%18s", l) for l in THR_LABEL[[2, 1, 3, 4]]]))
for x in rows
    vals = String[]
    for q in (2, 1, 3, 4)
        b = population(x.Pl, x.Ph, q)
        push!(vals, @sprintf("   %.4f / %.4f", b.union, b.A))
        rec!(@sprintf("union_%s_thr%d", x.tag, q), b.union); rec!(@sprintf("A_%s_thr%d", x.tag, q), b.A)
    end
    @printf("%-22s |%s\n", x.name, join(vals))
end
println()
println("poverty line and asset threshold moved together, exact: union / A")
@printf("%-22s | %-18s %-18s %s\n", "policy", "line -10%", "anchored", "line +10%")
for x in rows
    vals = String[]
    for q in (5, 1, 6)
        b = population(x.Pl, x.Ph, q)
        push!(vals, @sprintf("%.4f / %.4f    ", b.union, b.A))
        rec!(@sprintf("union_%s_thr%d", x.tag, q), b.union); rec!(@sprintf("A_%s_thr%d", x.tag, q), b.A)
    end
    @printf("%-22s | %s\n", x.name, join(vals))
end
println()
println("anchored versus floating line, three months: A (floating is exact only where no employed household is income-poor at the floating line)")
for x in rows
    Yp = CELLS[1].share * x.Pl.Y + CELLS[2].share * x.Ph.Y
    mf = cdf_quantile(YGRID, Yp, 0.5); yf = 0.5 * mf; af = hardship_threshold(mf; months = MONTHS)
    hl = hardship_at(x.Pl, yf, af); hh = hardship_at(x.Ph, yf, af)
    Af = (hl === nothing || hh === nothing) ? NaN :
         CELLS[1].share * x.Pl.alpha * (1 - hl.union) + CELLS[2].share * x.Ph.alpha * (1 - hh.union)
    @printf("  %-22s median %.4f  anchored A %.4f  floating A %s\n", x.name, mf, x.pop.A, isnan(Af) ? "(employed poor)" : @sprintf("%.4f", Af))
end

# ============================================ G. linearisation identity ==
println(); println("="^78); println("G. LINEARISATION IDENTITY at a one percent shock to kappa"); println("="^78)
let κ1 = KAPPA * 1.01
    E1 = equilibrium(fl0t, fh0t, κ1, SIGMA)
    shift = agg(fl0t, fh0t, κ1, SIGMA, E0.r)[1] - agg(fl0t, fh0t, KAPPA, SIGMA, E0.r)[1]
    pred = shift / (1 - E0.slope)
    meas = E1.r - E0.r
    @printf("map shift at fixed r %+.5f, slope %.4f, predicted dr %+.5f, measured %+.5f, ratio %.3f\n",
            shift, E0.slope, pred, meas, meas / pred)
    rec!("lin_pred", pred); rec!("lin_meas", meas); rec!("lin_ratio", meas / pred)
end

open(joinpath(@__DIR__, "sa_stage7_results" * TAG * ".txt"), "w") do io
    println(io, "# Stage 6 results, omega $(OMEGA); see STAGE6.md")
    for k in sort(collect(keys(RESULTS)))
        println(io, k, "\t", RESULTS[k])
    end
end
println("\nsaved sa_stage7_results" * TAG * ".txt")
println("DONE")

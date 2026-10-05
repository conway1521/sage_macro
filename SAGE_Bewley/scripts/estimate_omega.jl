# The private share of belonging (omega) from the dispersion of participation across regions.
# The participation targets do not identify omega, and it alone decides the multiplier (V3_START.md,
# section 11). What does bear on it: regions differ in fundamentals (composition, access to work,
# pay), and social feedback amplifies those differences, the more the smaller the private share. For
# each omega, kappa and sigma are refitted to the national cells, every region is solved with its
# own feedback, and the spread of participation across regions is set against the spread of formal
# volunteering in the data (Italy: ISTAT by region; Germany: Freiwilligensurvey by Land).
#
# What it can and cannot give. Regions also differ in ways the model's fundamentals leave out, and
# all of that unexplained spread is here credited to feedback. So the omega at which the model's
# spread reaches the data's is a LOWER bound on the private share, an upper bound on the multiplier;
# shared circumstances cannot be told from social effects by dispersion alone (Manski 1993). The
# correlation across regions says how much of the pattern the fundamentals get at all.
#
#   julia --project=scripts/run_env scripts/estimate_omega.jl CODE [regime: v3 | v3f | v3e | v3fe] [omegas, comma separated]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics
code = uppercase(ARGS[1])
reg = length(ARGS) >= 2 ? lowercase(ARGS[2]) : "v3fe"
omegas = length(ARGS) >= 3 ? parse.(Float64, split(ARGS[3], ",")) : [0.15, 0.30, 0.60, 0.90]
c = country_config(code; v3 = Dict("v3f" => :floor, "v3e" => :edu, "v3fe" => :floor_edu, "v3" => true)[reg], config = "GSA", S = true, A = true)
vol = Dict{String,Float64}()
if code == "IT"
    for (k, ln) in enumerate(eachline(joinpath(PLACE_DIR, "italy_regions.csv")))
        k == 1 && continue
        f = split(ln, ","); vol[f[3]] = parse(Float64, f[8])     # avq_vol_2023_25
    end
end
if isempty(vol)
    for ((ind, place), xs) in place_data(code; typology = :tl2)
        ind == "formal_volunteering" && (vol[place] = last(sort(xs))[2])
    end
end
isempty(vol) && error("no regional volunteering for $code")
ch = Tuple(x for x in c.e_channels if !(x in (:community, :commute)))          # fundamentals only: nothing estimated on volunteering
places, w = places_from_data(code, c; typology = :tl2, channels = ch, epsilon = c.epsilon)
row = country_rows()[code]; part = (parse(Float64, row["part_low"]), parse(Float64, row["part_high"]))
r0 = solve_economy(c); thr = [(r0.ypov, r0.abar)]
fi = families(c; thresholds = thr)
@printf("%s G+S+A (%s), %d regions, channels %s | calibrated: omega %.2f, kappa %.2f, sigma %.2f, participation %.4f, multiplier %.2f\n",
        code, reg, length(places), join(string.(ch), ", "), c.omega, c.kappa, c.sigma_m, r0.rate, 1 / (1 - r0.slope))
@printf("%6s | %6s %6s %9s | %11s | %12s %12s %8s %8s\n", "omega", "kappa", "sigma", "root loss", "multiplier", "spread model", "spread data", "slope", "corr")
for ω in omegas
    cw = SAGEConfig(c; omega = ω)
    rw = scan_technology(cw, fi, collect(0.30:0.02:3.00), collect(2.0:0.05:25.0); targets = part, selected_only = true, max_mult = 8.0)
    isempty(rw) && (@printf("%6.2f | no technology under the stability gate\n", ω); continue)
    b = rw[argmin([x.loss for x in rw])]
    cf = SAGEConfig(cw; kappa = b.κ, sigma_m = b.σ)
    t = @elapsed sp = solve_places(cf, places; weights = w)
    have = [haskey(vol, name) for (name, _) in sp.by_place]
    m = [r.rate for (name, r) in sp.by_place][have]; v = [vol[name] for (name, _) in sp.by_place if haskey(vol, name)]
    ww = w[have] ./ sum(w[have]); lm, lv = log.(m), log.(v)
    sdw(x) = sqrt(sum(ww .* (x .- sum(ww .* x)) .^ 2))
    @printf("%6.2f | %6.2f %6.2f %9.4f | %11.2f | %12.3f %12.3f %8.2f %8.2f   [%.0f min]\n", ω, b.κ, b.σ, b.loss, b.mult, sdw(lm), sdw(lv),
            cov(lm, lv) / var(lv), cor(m, v), t / 60)
    flush(stdout)
end
println("\nspread: population-weighted standard deviation of log participation (model) and of log volunteering (data) across regions; slope: of log model on log data")
println("DONE")

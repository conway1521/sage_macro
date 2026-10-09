# The base's indicators against official figures (V3_START.md, section 27, row B3), one table a country.
# Official: Eurostat (data/validation/income_distribution.csv, 2021) and the HFCS 2021 aggregates
# (data/hfcs_targets.csv). Each row says whether the calibration targets it; the others are tests.
# A row passes when the model is within a quarter of the official figure, or within 0.02 for a share
# below 0.08.
#
#   julia --project=scripts/run_env scripts/indicator_table.jl [CONFIG] [CODE ...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
cfg = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "GSA"
codes = length(ARGS) >= 2 ? uppercase.(ARGS[2:end]) : ["FR", "DE", "IT"]
REGIME = "V5" in codes ? :v5 : "V4" in codes ? :v4 : BASE_REGIME               # `V4` among the arguments: version 4 (section 36)
codes = filter(x -> !(x in ("V4", "V5")), codes); isempty(codes) && (codes = ["FR", "DE", "IT"])
println("regime ", REGIME)
function hf(code, moment)
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        f = split(ln, ",")
        length(f) >= 6 && f[1] == moment && f[2] == code && f[3] == "2021" && f[4] == "all" && f[5] == "all" && return parse(Float64, f[6])
    end
    NaN
end
function eu(code, ind)
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "validation", "income_distribution.csv"))
        f = split(ln, ","); length(f) >= 4 && f[1] == ind && f[2] == code && f[3] == "2021" && return parse(Float64, f[4])
    end
    NaN
end
tot = [0, 0]
for code in codes
    c = country_config(code; config = cfg, v3 = REGIME, S = occursin('S', cfg), A = occursin('A', cfg))
    r = solve_economy(c; cache = false); st = income_stats(c)
    rows = [("S80/S20, under 65", st.s8020, eu(code, "s80s20_under65"), "Eurostat ilc_di11", REGIME !== :v5),          # version 5 fits the decile cut-offs of all persons; this ratio for the under 65 is then a test
            ("Gini of disposable income", st.gini, eu(code, "gini_disposable"), "Eurostat ilc_di12", false),
            ("below 50% of median income", st.p50, hf(code, "income_poor50_disp_persons"), "HFCS", false),
            ("below 60% of median income", st.p60, hf(code, "income_poor60_disp_persons"), "HFCS", false),
            ("in-work poverty (60%)", st.inwork60, eu(code, "inwork_poverty60"), "Eurostat ilc_iw01", false),
            ("liquid-asset poor (3 months)", r.asset_poor, hf(code, "asset_poor_disp_persons"), "HFCS", false),
            ("income and asset poor", r.both, hf(code, "hardship_disp_persons"), "HFCS", false),
            ("hand-to-mouth", r.hand_to_mouth_kvw, hf(code, "htm_model_narrow_total"), "HFCS", true),
            ("liquid wealth over income", r.wealth_p50 / r.median_income, hf(code, "liquid_kvw_to_disposable_income_ratio_of_medians"), "HFCS", c.cfloor > 0 || REGIME === :v4),
            ("MPC out of a month's income", r.mpc, hf(code, "mpc_mean"), "HFCS, self-reported", REGIME === :v4)]      # version 4 fits both, weighted by standard errors
    @printf("\n%s %s, the base\n%-30s %8s %9s  %-22s %-9s %s\n", code, cfg, "indicator", "model", "official", "source", "", "")
    for (nm, m, d, src, tg) in rows
        ok = isnan(d) ? false : (d < 0.08 ? abs(m - d) <= 0.02 : abs(m - d) <= 0.25 * d)
        tg || (tot[2] += 1; ok && (tot[1] += 1))
        @printf("%-30s %8.3f %9.3f  %-22s %-9s %s\n", nm, m, d, src, tg ? "targeted" : "test", tg ? "" : (ok ? "within a quarter" : "OFF"))
    end
    c.S && @printf("%-30s %8.3f %9s  %-22s %-9s\n", "participation", r.rate, "", "ESS (cells targeted)", "targeted")
    flush(stdout)
end
println("\n", tot[1], " of ", tot[2], " untargeted rows within a quarter of the official figure")
println("DONE")

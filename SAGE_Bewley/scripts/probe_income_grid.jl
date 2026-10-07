# Convergence in the income grid on the base (V3_START.md, section 27, row N3). The base has eleven
# persistent income states; with the lump-sum tax a finer grid had no solution, because its lowest
# states could not pay the tax (section 21). Under the proportional tax they can. The same economy at
# 11, 15 and 21 persistent states, nothing refitted: the job's effort levels are those found at eleven
# states, interpolated in log productivity (they are found in the economy taxed per head, which does
# not exist on the finer grids).
#
#   julia --project=scripts/run_env scripts/probe_income_grid.jl [CONFIG] [CODE ...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
cfg = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "G"
codes = length(ARGS) >= 2 ? uppercase.(ARGS[2:end]) : ["FR", "DE", "IT"]
zgrid(c, nz) = SAGEBewley.income_process(SAGEParams(nz = nz, α = fill(1.0, nz), B = fill(1.0, nz), ρ = c.rho, η = c.eta_z))[1]
function levels_on(c, lv, nz)
    z0 = log.(zgrid(c, c.nz)); z1 = log.(zgrid(c, nz))
    Tuple(begin
              e0 = v[c.nz+1:2c.nz]                                   # the employed block
              e1 = [(k = clamp(searchsortedlast(z0, x), 1, c.nz - 1); t = (x - z0[k]) / (z0[k+1] - z0[k]); e0[k] + t * (e0[k+1] - e0[k])) for x in z1]
              vcat(zeros(nz), max.(e1, 0.0))
          end for v in lv)
end
tol = (htm = 0.02, liq = 0.09, mpc = 0.05, s8020 = 0.25, effort = 0.005, drop = 0.02)
for code in codes
    try
        c = country_config(code; config = cfg, v3 = :floor_edu_trans, S = false, A = occursin('A', cfg))
        lv = floor_effort(c).effort_by_cell
        @printf("%s %s, the base, persistent income states 11, 15, 21 (three transitory nodes each); nothing refitted\n", code, cfg)
        @printf("   %6s | %7s %8s %7s %8s %8s %9s | %s\n", "states", "htm", "liq/inc", "MPC", "S80/S20", "effort", "job loss", "largest change from 11, in tolerance bands")
        base = nothing
        for nz in (11, 15, 21)
            t0 = time()
            cn = SAGEConfig(c; nz = nz, effort_by_cell = nz == c.nz ? lv : levels_on(c, lv, nz))
            r = solve_economy(cn; cache = false); st = income_stats(cn)
            m = (htm = r.hand_to_mouth_kvw, liq = r.wealth_p50 / r.median_income, mpc = r.mpc, s8020 = st.s8020, effort = r.mean_effort_employed, drop = r.consumption_drop)
            nz == 11 && (base = m)
            d = maximum(abs(getfield(m, k) - getfield(base, k)) / getfield(tol, k) for k in keys(tol))
            @printf("   %6d | %7.4f %8.4f %7.4f %8.3f %8.4f %9.4f | %.2f   [%.1f min]\n", nz, m.htm, m.liq, m.mpc, m.s8020, m.effort, m.drop, d, (time() - t0) / 60)
            flush(stdout)
        end
    catch err
        println("   ", first(replace(sprint(showerror, err), "\n" => " "), 300))
    end
end
println("DONE")

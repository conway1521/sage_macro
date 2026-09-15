# Does the participation solver, with the social dimension switched off,
# reproduce the baseline engine? Everything modular rests on this: if the two
# code paths disagree at zero social strength then "baseline" and "baseline
# plus S" are different economies and no reduction test downstream means
# anything.
include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
using Printf, Statistics

p = SAGEParams(na = 200, ne = 80, a_max = 4.0, pexp = 3.0,
               α = [0.765, 0.765], B = [1.0, 1.0], social_mode = :off)

s = solve_model(p)
pp = update(p; social_strength = 0.0)
q = solve_participation_logit(pp, 1.0; theta = 0.005, full = true)

a = q.a; λq = q.lambda; z = q.z_vals
eq = [q.P1[i,j] * q.e_d[2][i,j] + (1 - q.P1[i,j]) * q.e_d[1][i,j] for i in 1:p.na, j in 1:p.nz]
aq = [q.P1[i,j] * q.a_d[2][i,j] + (1 - q.P1[i,j]) * q.a_d[1][i,j] for i in 1:p.na, j in 1:p.nz]

me(x, l) = sum(l .* x)
@printf("%-26s | %-14s %-14s %s\n", "quantity", "engine", "participation", "difference")
println("-"^70)
rows = (("participation rate", 0.0, q.rate),
        ("mean effort", me(s.e, s.λ), me(eq, λq)),
        ("mean labour income", sum(s.λ[i,j] * p.α[j] * s.e[i,j] * s.z_vals[j] for i in 1:p.na, j in 1:p.nz), q.meaninc),
        ("mean wealth", me(repeat(s.a_grid, 1, p.nz), s.λ), me(repeat(a, 1, p.nz), λq)),
        ("mean next-assets", me(s.a_next, s.λ), me(aq, λq)),
        ("hand-to-mouth", hand_to_mouth(s), begin
            minc = q.meaninc; thr = (4/52) * minc
            sum(λq[i,j] for i in 1:p.na, j in 1:p.nz if a[i] < thr) end),
        ("mass at the constraint", sum(s.λ[1, :]), sum(λq[1, :])),
        ("wealth p50", begin
            o = sortperm(vec(repeat(s.a_grid, 1, p.nz))); w = vec(s.λ)[o]
            vec(repeat(s.a_grid, 1, p.nz))[o][searchsortedfirst(cumsum(w), 0.5)] end,
         begin
            o = sortperm(vec(repeat(a, 1, p.nz))); w = vec(λq)[o]
            vec(repeat(a, 1, p.nz))[o][searchsortedfirst(cumsum(w), 0.5)] end))
worst = 0.0
for (nm, x, y) in rows
    global worst = max(worst, abs(x - y))
    @printf("%-26s | %-14.8f %-14.8f %+.2e\n", nm, x, y, y - x)
end
println("-"^70)
@printf("largest difference %.2e   %s\n", worst,
        worst < 1e-6 ? "the two paths agree: the reduction is exact" :
                       "THE TWO PATHS DISAGREE: the stack is not modular as it stands")
println("DONE")

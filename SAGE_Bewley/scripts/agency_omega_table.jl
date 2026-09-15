# Collate the agency column across the omega sweep.
#
# Each row comes from a full run of sa_agency.jl at that omega with (kappa,
# sigma_m) recalibrated to the participation moments, the pairs being those of
# sa_omega_l4.txt. Omega has no point estimate, so the gate asks whether the
# reported effects survive the whole range rather than whether they hold at a
# preferred value.
#
#   julia --project=. scripts/agency_omega_table.jl

using Printf
read1(f) = begin
    d = Dict{String,Float64}()
    for ln in eachline(f)
        startswith(ln, "#") && continue
        p = split(strip(ln), '\t'); length(p) == 2 && (d[p[1]] = parse(Float64, p[2]))
    end
    d
end

const ROWS = ((0.15, 13.00, 0.760, "sa_agency_results_om015.txt"),
              (0.30, 10.00, 0.510, "sa_agency_results.txt"),
              (0.50,  8.00, 0.430, "sa_agency_results_om050.txt"))

@printf("%-6s %-7s %-7s | %-7s %-7s %-7s | %-8s %-8s %-8s\n",
        "omega", "kappa", "sigma", "rate", "assetpv", "A", "dA sub", "dA emp", "dA cred")
println("-"^88)
sub = Float64[]; emp = Float64[]; cred = Float64[]
for (ω, κ, σ, f) in ROWS
    path = joinpath(@__DIR__, f)
    isfile(path) || (@printf("%-6.2f %-7.2f %-7.3f | (not yet run)\n", ω, κ, σ); continue)
    d = read1(path)
    push!(sub, d["dA_sub"]); push!(emp, d["dA_emp"]); push!(cred, d["dA_cred"])
    @printf("%-6.2f %-7.2f %-7.3f | %.4f  %.4f  %.4f | %+.4f  %+.4f  %+.4f\n",
            ω, κ, σ, d["r_base"], d["h_base"], d["A_base"],
            d["dA_sub"], d["dA_emp"], d["dA_cred"])
end
println("-"^88)
for (nm, v) in (("work subsidy", sub), ("empowerment", emp), ("participation credit", cred))
    isempty(v) && continue
    signok = all(x -> x > 0, v) || all(x -> x < 0, v)
    @printf("%-21s range %+.4f to %+.4f   sign %s\n",
            nm, minimum(v), maximum(v), signok ? "holds" : "CHANGES")
end
println("DONE")

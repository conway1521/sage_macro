# Collate stage 6 across the omega sweep (STAGE6.md Part 6, check 9). Each
# row is a full run of sa_stage6.jl at that omega, recalibrated by the dense
# scan. Omega has no point estimate, so the question is whether the reported
# effects keep their sign across the range.
include(joinpath(@__DIR__, "s6_common.jl"))
using Printf
const ROWS = ((0.15, "_om015"), (0.30, ""), (0.50, "_om050"))
@printf("%-6s %-6s %-6s | %-6s %-6s %-6s %-6s %-6s | %-8s %-8s %-8s %-8s %-8s\n",
        "omega", "kappa", "sigma", "rate", "r_U", "inc", "asset", "A", "dA sub", "dA emp", "dA cred", "dA ui+", "dA ui-")
println("-"^110)
acc = Dict{String,Vector{Float64}}()
for (ω, tag) in ROWS
    f = joinpath(@__DIR__, "sa_stage6_results" * tag * ".txt")
    isfile(f) || (@printf("%-6.2f (not yet run)\n", ω); continue)
    d = read_results(tag)
    @printf("%-6.2f %-6.2f %-6.3f | %.4f %.4f %.4f %.4f %.4f | %+.4f  %+.4f  %+.4f  %+.4f  %+.4f\n",
            ω, d["kappa"], d["sigma"], d["r_base"], d["rate_U"], d["inc_base"], d["asset_base"], d["A_base"],
            d["dA_sub"], d["dA_emp"], d["dA_cred"], d["dA_uiup"], d["dA_uifloor"])
    for k in ("dA_sub", "dA_emp", "dA_cred", "dA_uiup", "dA_uifloor", "A_base", "asset_base", "inc_base", "htm")
        push!(get!(acc, k, Float64[]), d[k])
    end
end
println("-"^110)
for (nm, k) in (("work subsidy", "dA_sub"), ("empowerment", "dA_emp"), ("participation credit", "dA_cred"),
                ("UI rr +0.10", "dA_uiup"), ("UI rr floor", "dA_uifloor"))
    haskey(acc, k) || continue; v = acc[k]
    @printf("%-21s range %+.4f to %+.4f   sign %s\n", nm, minimum(v), maximum(v),
            (all(x -> x > 0, v) || all(x -> x < 0, v)) ? "holds" : "CHANGES")
end
for (nm, k) in (("baseline A", "A_base"), ("asset poverty", "asset_base"), ("income poverty", "inc_base"), ("hand-to-mouth", "htm"))
    haskey(acc, k) || continue; v = acc[k]
    @printf("%-21s range %.4f to %.4f\n", nm, minimum(v), maximum(v))
end
println("DONE")

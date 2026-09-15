# Collate stage 7 across the omega sweep (STAGE7.md Part 6). Each row is a full
# run of sa_stage7.jl at that omega with the social technology recalibrated.
include(joinpath(@__DIR__, "s7_common.jl"))
using Printf
const ROWS = ((0.15, "_om015"), (0.30, ""), (0.50, "_om050"))
@printf("%-6s %-6s %-6s %-7s | %-6s %-6s %-6s %-6s | %-8s %-8s %-8s %-8s %-8s\n",
        "omega", "kappa", "sigma", "mult", "rate", "htm", "asset", "A", "dA sub", "dA emp", "dA cred", "dA ui+", "dA ui-")
println("-"^116)
acc = Dict{String,Vector{Float64}}()
for (ω, tag) in ROWS
    isfile(joinpath(@__DIR__, "sa_stage7_results" * tag * ".txt")) ||
        (@printf("%-6.2f (not yet run)\n", ω); continue)
    d = read_results7(tag)
    @printf("%-6.2f %-6.2f %-6.3f %-7.1f | %.4f %.4f %.4f %.4f | %+.4f  %+.4f  %+.4f  %+.4f  %+.4f\n",
            ω, d["kappa"], d["sigma"], 1 / (1 - d["slope_base"]), d["r_base"], d["htm"],
            d["asset_base"], d["A_base"], d["dA_sub"], d["dA_emp"], d["dA_cred"],
            d["dA_uiup"], d["dA_uifloor"])
    for k in ("dA_sub", "dA_emp", "dA_cred", "dA_uiup", "dA_uifloor", "dAinc_uiup",
              "A_base", "asset_base", "inc_base", "htm", "r_base")
        haskey(d, k) && push!(get!(acc, k, Float64[]), d[k])
    end
end
println("-"^116)
for (nm, k) in (("work subsidy", "dA_sub"), ("empowerment", "dA_emp"), ("participation credit", "dA_cred"),
                ("UI rr +0.10, union", "dA_uiup"), ("UI rr +0.10, income only", "dAinc_uiup"),
                ("UI rr floor", "dA_uifloor"))
    haskey(acc, k) || continue; v = acc[k]
    @printf("%-26s range %+.4f to %+.4f   sign %s\n", nm, minimum(v), maximum(v),
            (all(>(0), v) || all(<(0), v)) ? "holds" : "CHANGES")
end
for (nm, k) in (("baseline A", "A_base"), ("asset poverty", "asset_base"),
                ("income poverty", "inc_base"), ("hand-to-mouth", "htm"), ("participation", "r_base"))
    haskey(acc, k) || continue; v = acc[k]
    @printf("%-26s range %.4f to %.4f\n", nm, minimum(v), maximum(v))
end
println("DONE")

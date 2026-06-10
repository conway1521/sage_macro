# Per-country phi calibration: for each country, find the phi that makes the
# model's mean work share equal the country's time-use target.
#
#   julia --project=. scripts/calibrate_phi_country.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf

emean(p) = (s = solve_model(p); sum(s.λ .* s.e))

function calibrate(code; lo = 1.0, hi = 60.0, steps = 16)
    target = country_targets(code).work_share
    p0 = country_params(code)
    a, b = lo, hi
    for _ in 1:steps
        mid = 0.5 * (a + b)
        emean(update(p0; ϕ = mid)) > target ? (a = mid) : (b = mid)
    end
    φ = round(0.5 * (a + b), digits = 2)
    e = emean(update(p0; ϕ = φ))
    @printf("%s: target work share %.2f  ->  phi* = %.2f  (model %.3f)\n",
            code, target, φ, e)
    flush(stdout)
    return φ
end

println("Calibrating phi per country:")
results = Dict{String,Float64}()
for code in ("FR", "DE", "IT", "US", "CO", "ZA", "CN")
    results[code] = calibrate(code)
end

println("\nUpdate COUNTRIES row for each with phi as below:")
for code in ("FR", "DE", "IT", "US", "CO", "ZA", "CN")
    @printf("  %s: phi = %.2f\n", code, results[code])
end

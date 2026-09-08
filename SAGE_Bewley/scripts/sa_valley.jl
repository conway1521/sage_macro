# The moment fit is a valley in (kappa, sigma_m), not a point. Trace its floor
# (best kappa at each sigma) and report the verdict along it: fitted rates,
# moment loss, slope, multiplier, sigma-bar, ratio. This is the range the
# two INSEE moments actually identify.
#   julia --project=. scripts/sa_valley.jl
include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl")); using .SAGEBewley
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf, Statistics
const OMEGA = 0.30; const NQ = 2000; const Bl = CELL_LOW.B; const Bh = CELL_HIGH.B
rd(f) = (d = readdlm(f, '\t'; skipstart = 1); (d[:,1], d[:,2], d[:,3], d[:,4]))
fl = rd(joinpath(@__DIR__, "cache_l5_theta0.0100_amax4.0_pexp3.0", "fam_theta0.0050_0.765000.txt"))
fh = rd(joinpath(@__DIR__, "cache_l5_theta0.0100_amax4.0_pexp3.0", "fam_theta0.0050_0.911000.txt"))
const MS = taste_nodes_ln
const TASTE = Dict{Float64,Vector{Float64}}()
tastes(σ) = get!(TASTE, σ) do; taste_nodes_ln(σ; n = NQ) end
phi(z) = exp(-z^2/2)/sqrt(2pi)
function equil(κ, σ; ngrid = 401)
    ms = tastes(σ); g = range(0.0, 1.0, length = ngrid)
    f(rin) = (arg = OMEGA+(1-OMEGA)*clamp(rin,0,1);
              (0.5*mean(interp(fl[1],fl[2],κ*m*Bl*arg) for m in ms)+0.5*mean(interp(fh[1],fh[2],κ*m*Bh*arg) for m in ms)))
    o = [f(r) for r in g]; best = nothing; nst = 0
    for i in 1:ngrid-1
        d1=o[i]-g[i]; d2=o[i+1]-g[i+1]
        if d1==0 || sign(d1)!=sign(d2)
            sl=(o[i+1]-o[i])/(g[i+1]-g[i])
            if sl<1
                nst+=1; rs=g[i]+d1/(d1-d2)*(g[i+1]-g[i]); arg=OMEGA+(1-OMEGA)*rs
                lo=mean(interp(fl[1],fl[2],κ*m*Bl*arg) for m in ms); hi=mean(interp(fh[1],fh[2],κ*m*Bh*arg) for m in ms)
                L=(lo-0.25)^2+(hi-0.45)^2
                (best===nothing || L<best.L) && (best=(r=rs,lo=lo,hi=hi,slope=sl,L=L))
            end
        end
    end
    best===nothing ? nothing : merge(best,(nstable=nst,))
end
println("valley floor: best kappa at each sigma, omega = 0.30, 2000 nodes")
@printf("%-6s %-7s | %-7s %-13s %-8s | %-7s %-6s | %-8s %-6s | %s\n",
        "sigma","kappa*","rate","groups","rtloss","slope","mult","sigbar","ratio","stable")
for σ in 0.45:0.05:1.00
    best = nothing
    for κ in 8.0:0.05:14.0
        e = equil(κ, σ); e === nothing && continue
        (best===nothing || e.L<best.e.L) && (best=(κ=κ,e=e))
    end
    b = best; comp=(1-OMEGA)/(OMEGA+(1-OMEGA)*b.e.r)
    dens=0.5phi(quantile_normal(1-b.e.lo))+0.5phi(quantile_normal(1-b.e.hi)); sb=comp*dens
    @printf("%-6.2f %-7.2f | %-7.4f %.3f / %.3f | %-8.4f | %-7.4f %-6.2f | %-8.4f %-6.3f | %d\n",
            σ, b.κ, b.e.r, b.e.lo, b.e.hi, sqrt(b.e.L), b.e.slope, 1/(1-b.e.slope), sb, σ/sb, b.e.nstable)
    flush(stdout)
end
println("DONE")

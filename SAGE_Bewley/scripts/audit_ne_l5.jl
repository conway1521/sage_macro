# Effort-grid convergence at the final calibration, with the slope. At a map
# slope near 0.9 the multiplier is ten, so a family error of 0.001 becomes
# 0.01 on the level; ne = 40 gave 0.354 and ne = 80 and 160 both gave 0.368,
# which needs a denser sweep before ne is fixed for the production run.
#   julia --project=. scripts/audit_ne_l5.jl
include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl")); using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf, Statistics
const UG = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
const OMEGA=0.30; const KAPPA=10.00; const SIGMA=0.495; const THETA=0.005; const NQ=2000
const Bl=CELL_LOW.B; const Bh=CELL_HIGH.B; const MS=taste_nodes_ln(SIGMA; n=NQ)
const CD = joinpath(@__DIR__, "cache_ne_l5"); isdir(CD) || mkpath(CD)
function fam(α, ne)
    f = joinpath(CD, @sprintf("fam_ne%d_%.6f.txt", ne, α))
    isfile(f) && (d=readdlm(f,'\t'; skipstart=1); return (d[:,1],d[:,2],d[:,3]))
    r=Float64[]; mi=Float64[]
    for u in UG
        _,rate,m,_ = solve_participation_logit(update(cell_params(α; na=200, ne=ne, a_max=4.0, pexp=3.0); social_strength=u), 1.0; theta=THETA)
        push!(r,rate); push!(mi,m)
    end
    open(f,"w") do io; println(io,"u\tr\tminc"); for i in eachindex(UG); println(io,join([UG[i],r[i],mi[i]],'\t')); end; end
    @printf("  built alpha %.3f ne %d\n", α, ne); flush(stdout)
    (copy(UG), r, mi)
end
function eq(fl, fh)
    g=range(0.0,1.0,length=401)
    f(rin)=(arg=OMEGA+(1-OMEGA)*clamp(rin,0,1); 0.5*mean(interp(fl[1],fl[2],KAPPA*m*Bl*arg) for m in MS)+0.5*mean(interp(fh[1],fh[2],KAPPA*m*Bh*arg) for m in MS))
    o=[f(r) for r in g]; b=NaN; sl=NaN
    for i in 1:400
        d1=o[i]-g[i]; d2=o[i+1]-g[i+1]
        if d1==0 || sign(d1)!=sign(d2)
            s2=(o[i+1]-o[i])/(g[i+1]-g[i]); s2<1 && (b=g[i]+d1/(d1-d2)*(g[i+1]-g[i]); sl=s2)
        end
    end
    arg=OMEGA+(1-OMEGA)*b
    (r=b, lo=mean(interp(fl[1],fl[2],KAPPA*m*Bl*arg) for m in MS), hi=mean(interp(fh[1],fh[2],KAPPA*m*Bh*arg) for m in MS), slope=sl,
     mi=0.5*mean(interp(fl[1],fl[3],KAPPA*m*Bl*arg) for m in MS)+0.5*mean(interp(fh[1],fh[3],KAPPA*m*Bh*arg) for m in MS))
end
@printf("%-5s | %-9s %-9s %-9s | %-9s %-7s | %-9s\n","ne","r*","low","high","slope","mult","mean inc")
for ne in (40, 60, 80, 120, 160, 240, 320)
    e = eq(fam(CELL_LOW.α, ne), fam(CELL_HIGH.α, ne))
    @printf("%-5d | %-9.5f %-9.5f %-9.5f | %-9.5f %-7.2f | %-9.5f\n", ne, e.r, e.lo, e.hi, e.slope, 1/(1-e.slope), e.mi); flush(stdout)
end
println("DONE")

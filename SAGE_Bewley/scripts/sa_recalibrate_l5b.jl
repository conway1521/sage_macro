# The calibrated point on the logit core sits where the map is steep, and
# there theta = 0.01 is not yet in the limit (0.018 off on the level). Redo
# the recalibration on families built at theta = 0.005, and confirm the point
# on families at theta = 0.0025. If the two agree, theta = 0.005 is the
# working value and the point is final.
#   julia --project=. scripts/sa_recalibrate_l5b.jl
include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl")); using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf, Statistics
const UG = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
const OMEGA = 0.30; const NQ = 2000; const Bl = CELL_LOW.B; const Bh = CELL_HIGH.B
const GRID = (a_max = 4.0, pexp = 3.0)
const NE = 40
function fam(α, th)
    f = joinpath(@__DIR__, "cache_recal", @sprintf("fam_theta%.4f_ne%d_%.6f.txt", th, NE, α)); isdir(dirname(f)) || mkpath(dirname(f))
    isfile(f) && (d = readdlm(f, '\t'; skipstart = 1); return (d[:,1], d[:,2], d[:,3], d[:,4]))
    r=Float64[]; mi=Float64[]; pb=Float64[]
    for u in UG
        _,rate,m,b = solve_participation_logit(update(cell_params(α; na=200, ne=NE, a_max=GRID.a_max, pexp=GRID.pexp); social_strength=u), 1.0; theta=th)
        push!(r,rate); push!(mi,m); push!(pb,b)
    end
    open(f,"w") do io; println(io,"u\tr\tminc\tpbase"); for i in eachindex(UG); println(io,join([UG[i],r[i],mi[i],pb[i]],'\t')); end; end
    @printf("  built family alpha %.3f theta %.4f\n", α, th); flush(stdout)
    (copy(UG), r, mi, pb)
end
const TASTE = Dict{Tuple{Float64,Int},Vector{Float64}}()
tastes(σ, n) = get!(TASTE, (σ,n)) do; taste_nodes_ln(σ; n=n) end
phi(z) = exp(-z^2/2)/sqrt(2pi)
function equil(fl, fh, κ, σ; n=NQ, ngrid=401)
    ms = tastes(σ,n); g = range(0.0,1.0,length=ngrid)
    f(rin) = (arg=OMEGA+(1-OMEGA)*clamp(rin,0,1); 0.5*mean(interp(fl[1],fl[2],κ*m*Bl*arg) for m in ms)+0.5*mean(interp(fh[1],fh[2],κ*m*Bh*arg) for m in ms))
    o=[f(r) for r in g]; best=nothing; nst=0
    for i in 1:ngrid-1
        d1=o[i]-g[i]; d2=o[i+1]-g[i+1]
        if d1==0 || sign(d1)!=sign(d2)
            sl=(o[i+1]-o[i])/(g[i+1]-g[i])
            if sl<1
                nst+=1; rs=g[i]+d1/(d1-d2)*(g[i+1]-g[i]); arg=OMEGA+(1-OMEGA)*rs
                lo=mean(interp(fl[1],fl[2],κ*m*Bl*arg) for m in ms); hi=mean(interp(fh[1],fh[2],κ*m*Bh*arg) for m in ms)
                L=(lo-0.25)^2+(hi-0.45)^2
                (best===nothing||L<best.L) && (best=(r=rs,lo=lo,hi=hi,slope=sl,L=L))
            end
        end
    end
    best===nothing ? nothing : merge(best,(nstable=nst,))
end
function search(fl, fh, κs, σs; n=NQ, ngrid=401)
    bb=nothing
    for κ in κs, σ in σs
        e=equil(fl,fh,κ,σ; n=n, ngrid=ngrid); e===nothing && continue
        (bb===nothing||e.L<bb.e.L) && (bb=(κ=κ,σ=σ,e=e))
    end; bb
end
verdict(b) = (comp=(1-OMEGA)/(OMEGA+(1-OMEGA)*b.e.r); dens=0.5phi(quantile_normal(1-b.e.lo))+0.5phi(quantile_normal(1-b.e.hi)); sb=comp*dens;
  @printf("  kappa* %.2f sigma* %.3f | rate %.4f groups %.4f/%.4f rtloss %.4f | slope %.4f mult %.2f | sigbar %.4f ratio %.3f | stable %d\n",
          b.κ, b.σ, b.e.r, b.e.lo, b.e.hi, sqrt(b.e.L), b.e.slope, 1/(1-b.e.slope), sb, b.σ/sb, b.e.nstable))
fl5=fam(CELL_LOW.α,0.005); fh5=fam(CELL_HIGH.α,0.005)
fl2=fam(CELL_LOW.α,0.0025); fh2=fam(CELL_HIGH.α,0.0025)
println("recalibration on theta = 0.005 families")
c=search(fl5,fh5,8.0:0.25:13.0,0.40:0.02:0.90; n=500, ngrid=201)
b5=search(fl5,fh5,max(1,c.κ-0.5):0.05:c.κ+0.5,max(0.05,c.σ-0.03):0.005:c.σ+0.03)
verdict(b5)
println("same point on theta = 0.0025 families (convergence in theta)")
e2=equil(fl2,fh2,b5.κ,b5.σ); verdict((κ=b5.κ,σ=b5.σ,e=e2))
println("recalibration on theta = 0.0025 families (does the point itself move?)")
c=search(fl2,fh2,8.0:0.25:13.0,0.40:0.02:0.90; n=500, ngrid=201)
b2=search(fl2,fh2,max(1,c.κ-0.5):0.05:c.κ+0.5,max(0.05,c.σ-0.03):0.005:c.σ+0.03)
verdict(b2)
println("na check at the theta = 0.005 point (baseline families at na = 400)")
fl5b=let f=joinpath(@__DIR__,"cache_l5","fam_theta0.0050_na400_0.765.txt"); r=Float64[]
    for u in UG; _,rate,_,_=solve_participation_logit(update(cell_params(CELL_LOW.α; na=400, ne=NE, a_max=GRID.a_max, pexp=GRID.pexp); social_strength=u),1.0; theta=0.005); push!(r,rate); end; (UG,r) end
fh5b=let r=Float64[]
    for u in UG; _,rate,_,_=solve_participation_logit(update(cell_params(CELL_HIGH.α; na=400, ne=NE, a_max=GRID.a_max, pexp=GRID.pexp); social_strength=u),1.0; theta=0.005); push!(r,rate); end; (UG,r) end
e4=equil(fl5b,fh5b,b5.κ,b5.σ); @printf("  na=400: rate %.5f slope %.5f  (na=200: rate %.5f slope %.5f)\n", e4.r, e4.slope, b5.e.r, b5.e.slope)
println("DONE")

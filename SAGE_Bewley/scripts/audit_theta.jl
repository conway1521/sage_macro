# The theta-sensitivity test. Two questions, one run:
#   (1) at each theta, does the equilibrium converge in na?   (fixes the grid?)
#   (2) as theta falls, do the results settle?                (is theta a
#       regulariser we can send to zero, or an economic parameter?)
# Plus the check that decides per-country use: does the OECD ordering hold
# across na at the working theta.
#   julia --project=. scripts/audit_theta.jl
include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl")); using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using Printf, Statistics
const UG = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
const NQ=2000; const OM=0.30; const K=10.75; const S=0.750
const MS = taste_nodes_ln(S; n=NQ); const AMAX=4.0; const PEXP=3.0
const FAMS = Dict{Any,Any}()
fam(α,na,th) = get!(FAMS,(α,na,th)) do
    r=Float64[]; mi=Float64[]
    for u in UG
        _,rate,m,_ = solve_participation_logit(update(cell_params(α; na=na, ne=40);
                        social_strength=u, a_max=AMAX, pexp=PEXP), 1.0; theta=th)
        push!(r,rate); push!(mi,m)
    end
    (UG,r,mi)
end
function eqf(fl,fh,Bl,Bh)
    g=range(0.0,1.0,length=401)
    f(rin)=(arg=OM+(1-OM)*clamp(rin,0.0,1.0);
        (0.5*mean(interp(fl[1],fl[2],K*m*Bl*arg) for m in MS)+
         0.5*mean(interp(fh[1],fh[2],K*m*Bh*arg) for m in MS)))
    o=[f(r) for r in g]; b=NaN; sl=NaN
    for i in 1:400
        d1=o[i]-g[i]; d2=o[i+1]-g[i+1]
        if d1==0 || sign(d1)!=sign(d2)
            s2=(o[i+1]-o[i])/(g[i+1]-g[i]); s2<1 && (b=g[i]+d1/(d1-d2)*(g[i+1]-g[i]); sl=s2)
        end
    end
    arg=OM+(1-OM)*b
    lo=mean(interp(fl[1],fl[2],K*m*Bl*arg) for m in MS); hi=mean(interp(fh[1],fh[2],K*m*Bh*arg) for m in MS)
    (r=b, lo=lo, hi=hi, slope=sl)
end
println("(1)+(2): equilibrium by theta and na.  a_max=$AMAX pexp=$PEXP")
@printf("%-6s | %-10s %-10s | %-9s | %-9s %-9s | %-9s\n","theta","r* na200","r* na400","|diff|","slope200","slope400","gap400")
for th in (0.10, 0.05, 0.02, 0.01)
    e2 = eqf(fam(CELL_LOW.α,200,th), fam(CELL_HIGH.α,200,th), CELL_LOW.B, CELL_HIGH.B)
    e4 = eqf(fam(CELL_LOW.α,400,th), fam(CELL_HIGH.α,400,th), CELL_LOW.B, CELL_HIGH.B)
    @printf("%-6.2f | %-10.5f %-10.5f | %-9.5f | %-9.5f %-9.5f | %-9.5f\n",
            th, e2.r, e4.r, abs(e4.r-e2.r), e2.slope, e4.slope, e4.hi-e4.lo); flush(stdout)
end
println("\n(3): does the country ordering survive na, at theta = 0.02?")
cs=("FR","DE","IT","US","ZA"); res=Dict()
for na in (200,400)
    for c in cs
        p=country_params(c)
        res[(c,na)] = eqf(fam(p.α[1],na,0.02), fam(p.α[2],na,0.02), p.B[1], p.B[2]).r
    end
end
@printf("%-4s | %-9s %-9s | %s\n","cty","na=200","na=400","shift")
for c in cs; @printf("%-4s | %-9.5f %-9.5f | %+.5f\n", c, res[(c,200)], res[(c,400)], res[(c,400)]-res[(c,200)]); end
o2=sortperm([res[(c,200)] for c in cs]); o4=sortperm([res[(c,400)] for c in cs])
println("ordering na=200: ", join([cs[i] for i in o2]," < "))
println("ordering na=400: ", join([cs[i] for i in o4]," < "))
println(o2==o4 ? "ORDERING PRESERVED" : "ORDERING CHANGES")
println("DONE")

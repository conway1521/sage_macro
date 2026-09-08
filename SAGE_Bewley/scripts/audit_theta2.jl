# Two follow-ups that decide the working theta.
#  (a) push theta further down: does the limit hold at 0.005 and 0.0025, and
#      at what theta does the na-error start to climb back (the regulariser
#      weakening)? The working theta is the smallest one before that happens.
#  (b) the quadrature requirement. The 2000-node taste integral was forced by
#      the near-step response of the hard threshold. If the logit smooths the
#      response, the requirement should fall, which simplifies everything
#      downstream.
#   julia --project=. scripts/audit_theta2.jl
include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl")); using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using Printf, Statistics
const UG = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
const OM=0.30; const K=10.75; const S=0.750; const AMAX=4.0; const PEXP=3.0
const FAMS = Dict{Any,Any}()
fam(α,na,th) = get!(FAMS,(α,na,th)) do
    r=Float64[]
    for u in UG
        _,rate,_,_ = solve_participation_logit(update(cell_params(α; na=na, ne=40);
                        social_strength=u, a_max=AMAX, pexp=PEXP), 1.0; theta=th)
        push!(r,rate)
    end
    (UG,r)
end
function eqf(fl,fh,Bl,Bh; nq=2000)
    ms = taste_nodes_ln(S; n=nq)
    g=range(0.0,1.0,length=401)
    f(rin)=(arg=OM+(1-OM)*clamp(rin,0.0,1.0);
        (0.5*mean(interp(fl[1],fl[2],K*m*Bl*arg) for m in ms)+
         0.5*mean(interp(fh[1],fh[2],K*m*Bh*arg) for m in ms)))
    o=[f(r) for r in g]; b=NaN; sl=NaN
    for i in 1:400
        d1=o[i]-g[i]; d2=o[i+1]-g[i+1]
        if d1==0 || sign(d1)!=sign(d2)
            s2=(o[i+1]-o[i])/(g[i+1]-g[i]); s2<1 && (b=g[i]+d1/(d1-d2)*(g[i+1]-g[i]); sl=s2)
        end
    end
    (r=b, slope=sl)
end
println("(a) pushing theta toward zero")
@printf("%-7s | %-10s %-10s | %-9s | %-9s %-9s\n","theta","r* na200","r* na400","|diff|","slope200","slope400")
for th in (0.02, 0.01, 0.005, 0.0025)
    e2 = eqf(fam(CELL_LOW.α,200,th), fam(CELL_HIGH.α,200,th), CELL_LOW.B, CELL_HIGH.B)
    e4 = eqf(fam(CELL_LOW.α,400,th), fam(CELL_HIGH.α,400,th), CELL_LOW.B, CELL_HIGH.B)
    @printf("%-7.4f | %-10.5f %-10.5f | %-9.5f | %-9.5f %-9.5f\n", th, e2.r, e4.r, abs(e4.r-e2.r), e2.slope, e4.slope); flush(stdout)
end
println("\n(b) taste-quadrature requirement at na=200 (reference: 8000 nodes)")
@printf("%-7s | %-8s %-8s %-8s %-8s %-8s | %s\n","theta","n=50","n=100","n=200","n=500","n=2000","nodes for 0.002")
for th in (0.02, 0.01, 0.005)
    fl=fam(CELL_LOW.α,200,th); fh=fam(CELL_HIGH.α,200,th)
    ref = eqf(fl,fh,CELL_LOW.B,CELL_HIGH.B; nq=8000).r
    line = @sprintf("%-7.4f | ", th); need = "none"
    for n in (50,100,200,500,2000)
        r = eqf(fl,fh,CELL_LOW.B,CELL_HIGH.B; nq=n).r
        line *= @sprintf("%-8.4f ", r)
        need == "none" && abs(r-ref) < 0.002 && (need = string(n))
    end
    println(line * "| " * need); flush(stdout)
end
println("DONE")

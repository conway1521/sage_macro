# The WISE Solidarity comparison, redone on the logit core at small theta.
# This is the validation that FAILED on the hard threshold because the
# country levels were inside the grid noise. Now the levels are resolved to
# about 0.0003, so the ordering is real and the comparison is meaningful.
#   julia --project=. scripts/wise_participation_logit.jl
include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl")); using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using Printf, Statistics, DelimitedFiles
const UG = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
const NQ=2000; const OM=0.30; const K=10.00; const S=0.495
const MS = taste_nodes_ln(S; n=NQ); const AMAX=4.0; const PEXP=3.0; const TH=0.005
const FAMS = Dict{Any,Any}()
fam(α) = get!(FAMS,α) do
    r=Float64[]
    for u in UG
        _,rate,_,_ = solve_participation_logit(update(cell_params(α; na=200, ne=40);
                        social_strength=u, a_max=AMAX, pexp=PEXP), 1.0; theta=TH)
        push!(r,rate)
    end
    (UG,r)
end
function eqr(fl,fh,Bl,Bh)
    g=range(0.0,1.0,length=401)
    f(rin)=(arg=OM+(1-OM)*clamp(rin,0.0,1.0);
        (0.5*mean(interp(fl[1],fl[2],K*m*Bl*arg) for m in MS)+
         0.5*mean(interp(fh[1],fh[2],K*m*Bh*arg) for m in MS)))
    o=[f(r) for r in g]; b=NaN
    for i in 1:400
        d1=o[i]-g[i]; d2=o[i+1]-g[i+1]
        if d1==0 || sign(d1)!=sign(d2)
            (o[i+1]-o[i])/(g[i+1]-g[i]) < 1 && (b=g[i]+d1/(d1-d2)*(g[i+1]-g[i]))
        end
    end
    b
end
function ranks(x); o=sortperm(x); r=zeros(length(x)); i=1
    while i<=length(o); j=i
        while j<length(o) && x[o[j+1]]==x[o[i]]; j+=1; end
        for k in i:j; r[o[k]]=(i+j)/2; end; i=j+1
    end; r end
spearman(a,b)=(ra=ranks(a); rb=ranks(b); (std(ra)==0||std(rb)==0) ? NaN : cor(ra,rb))
part = Dict{String,Float64}()
for c in ("FR","DE","IT","US","CO","ZA","CN")
    p=country_params(c); part[c]=eqr(fam(p.α[1]),fam(p.α[2]),p.B[1],p.B[2])
    @printf("%s %.5f\n", c, part[c]); flush(stdout)
end
ISO = Dict("FRA"=>"FR","DEU"=>"DE","ITA"=>"IT","USA"=>"US","CHN"=>"CN","ZAF"=>"ZA")
raw = readdlm(joinpath(@__DIR__,"..","..","data","wise_recoupling.csv"), ','; skipstart=1)
inputs = Dict(c => (0.5*(country_params(c).B[1]+country_params(c).B[2]), country_params(c).α[1]) for c in keys(part))
println("\nlogit core, theta=$TH: model participation vs WISE Solidarity")
@printf("%-6s %-3s | %-14s | %-11s %-11s\n","year","n","participation","Bbar alone","alpha_l alone")
for y in sort(unique(string.(raw[:,3]))), samp in ("all","OECD")
    cs=String[]; sol=Float64[]
    for i in 1:size(raw,1)
        string(raw[i,3])==y || continue
        code=get(ISO,string(raw[i,2]),nothing); code===nothing && continue
        samp=="OECD" && !(code in ("FR","DE","IT","US")) && continue
        haskey(part,code) || continue
        push!(cs,code); push!(sol,Float64(raw[i,5]))
    end
    isempty(cs) && continue
    @printf("%-6s %-3d | %+14.3f | %+11.3f %+11.3f   %s\n", samp=="all" ? y : "", length(cs),
            spearman([part[c] for c in cs],sol), spearman([inputs[c][1] for c in cs],sol),
            spearman([inputs[c][2] for c in cs],sol), samp=="OECD" ? "(OECD four)" : "")
end
open(joinpath(@__DIR__,"sa_countries_logit.txt"),"w") do io
    println(io,"code\tparticipation"); for (c,v) in part; println(io,c,"\t",v); end
end
println("DONE")

# Dense scan of the calibration neighbourhood, written 2026-09-08 after the nz
# sweep recalibrated to a DIFFERENT point than the headline on identical
# footing. sa_recalibrate_l5b does a coarse pass then refines locally around
# the coarse winner; the coarse pass landed in the wrong basin and the local
# window excluded the true optimum. This scans sigma densely with kappa free at
# each step, no local windowing, so it cannot miss the way that one did.
#   julia --project=. scripts/calibration_dense_scan.jl
R="/Users/ali/Desktop/UNI/Paris 8/extra_papers/SAGE/SAGE_Bewley"
include(R*"/src/SAGEBewley.jl"); using .SAGEBewley
include(R*"/scripts/sa_core.jl")
using DelimitedFiles, Printf, Statistics
const OMEGA=0.30; const Bl=CELL_LOW.B; const Bh=CELL_HIGH.B
rd(f)=(d=readdlm(f,'\t';skipstart=1); (d[:,1],d[:,2],d[:,3],d[:,4]))
fl=rd(R*"/scripts/cache_recal/fam_theta0.0050_ne80_0.765000.txt")
fh=rd(R*"/scripts/cache_recal/fam_theta0.0050_ne80_0.911000.txt")
const T=Dict{Tuple{Float64,Int},Vector{Float64}}()
tastes(s,n)=get!(T,(s,n)) do; taste_nodes_ln(s;n=n) end
phi(z)=exp(-z^2/2)/sqrt(2pi)
function ev(k,s;nq=2000,ng=401)
    ms=tastes(s,nq); g=range(0.0,1.0,length=ng)
    f(r)=(a=OMEGA+(1-OMEGA)*clamp(r,0,1);
        0.5*mean(interp(fl[1],fl[2],k*m*Bl*a) for m in ms)+0.5*mean(interp(fh[1],fh[2],k*m*Bh*a) for m in ms))
    o=[f(r) for r in g]; out=NamedTuple[]
    for i in 1:ng-1
        d1=o[i]-g[i]; d2=o[i+1]-g[i+1]
        if d1==0 || sign(d1)!=sign(d2)
            sl=(o[i+1]-o[i])/(g[i+1]-g[i])
            if sl<1
                rs=g[i]+d1/(d1-d2)*(g[i+1]-g[i]); a=OMEGA+(1-OMEGA)*rs
                lo=mean(interp(fl[1],fl[2],k*m*Bl*a) for m in ms); hi=mean(interp(fh[1],fh[2],k*m*Bh*a) for m in ms)
                push!(out,(r=rs,lo=lo,hi=hi,slope=sl,L=(lo-0.25)^2+(hi-0.45)^2))
            end
        end
    end
    isempty(out) ? nothing : out[argmin([x.L for x in out])], length(out)
end
function show(k,s,lbl)
    e,n = ev(k,s); e===nothing && (println("$lbl: none"); return)
    comp=(1-OMEGA)/(OMEGA+(1-OMEGA)*e.r); dens=0.5phi(quantile_normal(1-e.lo))+0.5phi(quantile_normal(1-e.hi)); sb=comp*dens
    @printf("%-22s k=%.2f s=%.3f | rate %.4f groups %.3f/%.3f | rtloss %.4f | slope %.4f mult %.1f | sigbar %.4f ratio %.3f | nstable %d\n",
            lbl,k,s,e.r,e.lo,e.hi,sqrt(e.L),e.slope,1/(1-e.slope),sb,s/sb,n)
end
println("Both candidate points, identical machinery, identical families (na=200 ne=80 theta=0.005):")
show(10.00,0.510,"headline")
show(9.95,0.470,"nz-sweep winner")
println("\nDense scan of the fine neighbourhood (best loss at each sigma, kappa free):")
@printf("%-7s %-7s %-8s %-13s %-8s %-7s %s\n","sigma","kappa*","rate","groups","rtloss","slope","ratio")
for s in 0.44:0.01:0.56
    best=nothing
    for k in 9.0:0.05:11.5
        e,_=ev(k,s); e===nothing && continue
        (best===nothing || e.L<best.e.L) && (best=(k=k,e=e))
    end
    best===nothing && continue
    e=best.e; comp=(1-OMEGA)/(OMEGA+(1-OMEGA)*e.r); dens=0.5phi(quantile_normal(1-e.lo))+0.5phi(quantile_normal(1-e.hi)); sb=comp*dens
    @printf("%-7.3f %-7.2f %-8.4f %.3f/%.3f  %-8.4f %-7.4f %.3f\n",s,best.k,e.r,e.lo,e.hi,sqrt(e.L),e.slope,s/sb)
end
println("DONE")

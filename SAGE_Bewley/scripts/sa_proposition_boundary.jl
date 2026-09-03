using DelimitedFiles, Printf
include("/Users/ali/Desktop/UNI/Paris 8/extra_papers/SAGE/SAGE_Bewley/src/SAGEBewley.jl"); using .SAGEBewley
include("/Users/ali/Desktop/UNI/Paris 8/extra_papers/SAGE/SAGE_Bewley/scripts/sa_core.jl")
const OMEGA=0.30; const KAPPA=10.0
d = readdlm("/Users/ali/Desktop/UNI/Paris 8/extra_papers/SAGE/SAGE_Bewley/scripts/sa_families.txt",'\t';skipstart=1)
flow=(d[:,1],d[:,2],d[:,3]); fhigh=(d[:,1],d[:,4],d[:,5])
Bl=CELL_LOW.B; Bh=CELL_HIGH.B
phi(z)=exp(-z^2/2)/sqrt(2pi)
println(" sigma | #stable | max G'  | sigma-bar(analytic) | verdict")
for s in 0.30:0.02:0.56
    _,_,eqs = trace_map(flow,fhigh,Bl,Bh,KAPPA,OMEGA,s)
    sts=[e for e in eqs if e[2]]
    G(r)=population_rate(flow,fhigh,Bl,Bh,KAPPA,OMEGA,s,r)[1]
    # max slope over the map
    rs=0.02:0.005:0.98; h=1e-4
    gmax=maximum((G(r+h)-G(r-h))/(2h) for r in rs)
    # analytic bound at the highest stable eq
    if !isempty(sts)
        rst=sts[argmax([e[1] for e in sts])][1]
        pl,ph=population_rate(flow,fhigh,Bl,Bh,KAPPA,OMEGA,s,rst)[2:3]
        sb=((1-OMEGA)/(OMEGA+(1-OMEGA)*rst))*(0.5*phi(quantile_normal(1-pl))+0.5*phi(quantile_normal(1-ph)))
        @printf(" %.2f  |    %d    | %.3f   |   %.3f              | %s\n", s, length(sts), gmax, sb,
                length(sts)>1 ? "MULTIPLE" : "unique")
    end
end

using DelimitedFiles, Printf, Statistics
include("/Users/ali/Desktop/UNI/Paris 8/extra_papers/SAGE/SAGE_Bewley/src/SAGEBewley.jl"); using .SAGEBewley
include("/Users/ali/Desktop/UNI/Paris 8/extra_papers/SAGE/SAGE_Bewley/scripts/sa_core.jl")

# calibrated point from sa_main
const OMEGA=0.30; const KAPPA=10.0; const SIGMA=0.5
d = readdlm("/Users/ali/Desktop/UNI/Paris 8/extra_papers/SAGE/SAGE_Bewley/scripts/sa_families.txt",'\t';skipstart=1)
flow=(d[:,1],d[:,2],d[:,3]); fhigh=(d[:,1],d[:,4],d[:,5])
Bl=CELL_LOW.B; Bh=CELL_HIGH.B

G(r) = population_rate(flow,fhigh,Bl,Bh,KAPPA,OMEGA,SIGMA,r)[1]
grp(r) = population_rate(flow,fhigh,Bl,Bh,KAPPA,OMEGA,SIGMA,r)[2:3]

# find the stable equilibrium
_,_,eqs = trace_map(flow,fhigh,Bl,Bh,KAPPA,OMEGA,SIGMA)
sts=[e for e in eqs if e[2]]; rstar = sts[argmax([e[1] for e in sts])][1]
pl,ph = grp(rstar)
@printf("equilibrium r* = %.4f, group rates p_l = %.4f, p_h = %.4f\n", rstar, pl, ph)

# numerical slope of the aggregate map
h=1e-4; Gp_num = (G(rstar+h)-G(rstar-h))/(2h)
@printf("numerical G'(r*)          = %.4f\n", Gp_num)

# analytic threshold-version slope:  G' = [(1-w)/(w+(1-w)r)] * (1/sigma) * sum_g s_g phi(Phi^-1(1-p_g))
Phinv(p) = quantile_normal(p)                      # from sa_core
phi(z) = exp(-z^2/2)/sqrt(2pi)
comp = (1-OMEGA)/(OMEGA+(1-OMEGA)*rstar)
dens = 0.5*phi(Phinv(1-pl)) + 0.5*phi(Phinv(1-ph))
sigbar = comp*dens                                  # the multiplicity bound on sigma
Gp_an = sigbar/SIGMA
@printf("analytic  G'(r*) (threshold bound) = %.4f\n", Gp_an)
@printf("\nsigma-bar (multiplicity requires sigma < this) = %.4f\n", sigbar)
@printf("calibrated sigma                               = %.4f\n", SIGMA)
@printf("ratio sigma/sigma-bar                          = %.3f  (>1 means NO multiplicity)\n", SIGMA/sigbar)
@printf("\ncomplementarity factor (1-w)/(w+(1-w)r) = %.4f\n", comp)
@printf("density term sum_g s_g phi(Phi^-1(1-p_g)) = %.4f\n", dens)

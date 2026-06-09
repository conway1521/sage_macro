# Paper 1 decisive experiment: discipline the behavioural social weight, confirm
# the two solvers agree once off the knife-edge, then map the tipping boundary.
#
# We use the DiscreteDP joint optimum over (a', e) as the consistent effort
# instrument, with a single social-weight knob theta:
#   warmglow:   social reward = theta * B * (1-e)
#   multiplier: social reward = theta * B * A * (1-e)   (A = aggregate public good)
# Moments (mean effort, Q) come from the exact stationary distribution.
#
#   julia --project=. scripts/calibrate_tipping.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley, QuantEcon, SparseArrays, LinearAlgebra, Statistics, Printf

# DiscreteDP solver with a behavioural social term (theta knob). mode :off/:warm/:mult
function solve_dd(p; mode=:warm, theta=0.3, A=0.0, ne=80)
    a = SAGEBewley.exponential_grid(p.a_min, p.a_max, p.na, p.pexp)
    z_vals, Pi = SAGEBewley.income_process(p)
    na, nz = p.na, p.nz; eg = range(0.0,1.0,length=ne)
    n_s=na*nz; sidx(ia,iz)=(iz-1)*na+ia
    s_ind=Int[]; a_ind=Int[]; Rvec=Float64[]; Epol=zeros(n_s,na)
    rows=Int[];cols=Int[];vals=Float64[]; pair=0
    for iz in 1:nz
        z=z_vals[iz]; az=p.α[iz]; Bz=p.B[iz]
        for ia in 1:na
            res=p.R*a[ia]
            for k in 1:na
                anext=a[k]; best=-Inf; be=0.0
                @inbounds for e in eg
                    c=res+az*e*z*p.Z-anext
                    c<=0 && continue
                    soc = mode===:warm ? theta*Bz*(1-e) : mode===:mult ? theta*Bz*A*(1-e) : 0.0
                    u=p.Γ*(c^(1-p.γ)/(1-p.γ)-p.ϕ*e^(1+p.ψ)/(1+p.ψ)) + soc
                    u>best && (best=u; be=e)
                end
                best==-Inf && continue
                Epol[sidx(ia,iz),k]=be; pair+=1
                push!(s_ind,sidx(ia,iz));push!(a_ind,k);push!(Rvec,best)
                for izn in 1:nz; push!(rows,pair);push!(cols,sidx(k,izn));push!(vals,Pi[iz,izn]); end
            end
        end
    end
    rr=solve(DiscreteDP(Rvec,sparse(rows,cols,vals,pair,n_s),p.β,s_ind,a_ind), PFI)
    lam=reshape(stationary_distributions(rr.mc)[1],na,nz)
    e=zeros(na,nz); for iz in 1:nz,ia in 1:na; s=sidx(ia,iz); e[ia,iz]=Epol[s,rr.sigma[s]]; end
    (; meane=sum(lam.*e), Q=sum(lam.*(1 .- e)))
end

mult_fp(p, theta, A0; damp=0.6, tol=1e-4, maxit=60) = begin
    A=A0
    for _ in 1:maxit
        An=solve_dd(p; mode=:mult, theta=theta, A=A).Q
        (isnan(An)||isinf(An)) && return NaN
        abs(An-A)<tol && return An
        A=damp*A+(1-damp)*An
    end
    A
end

p = SAGEParams()
println("== 1. calibrate warm-glow social weight theta to interior effort ==")
println("   (additive :off baseline has mean effort ~0.53)")
println("  theta   mean effort   Q")
cal = Tuple{Float64,Float64,Float64}[]
for θ in (0.05,0.10,0.15,0.20,0.30,0.50,0.876)
    s = solve_dd(p; mode=:warm, theta=θ)
    push!(cal,(θ,s.meane,s.Q))
    @printf("  %.3f   %.4f       %.4f\n", θ, s.meane, s.Q)
end
# pick theta* giving mean effort closest to 0.50 (interior)
θstar = cal[argmin([abs(c[2]-0.50) for c in cal])][1]
@printf("\n  -> interior calibration theta* = %.3f\n", θstar)

println("\n== 2. solver agreement at theta* (DiscreteDP vs engine continuous) ==")
dd = solve_dd(p; mode=:warm, theta=θstar)
eng = solve_model(update(p; social_mode=:warmglow, social_strength=θstar/p.Λ))
@printf("  DiscreteDP mean effort = %.4f   engine mean effort = %.4f   (close => off knife-edge)\n",
        dd.meane, sum(eng.λ .* eng.e))

println("\n== 3. tipping map at disciplined calibration (multiplier) ==")
println("  theta   A*(low)   A*(high)   bistable?")
for θ in (θstar, 1.5θstar, 2θstar, 3θstar, 4θstar, 6θstar)
    Alo = mult_fp(p, θ, 0.05); Ahi = mult_fp(p, θ, 0.98)
    bist = (!isnan(Alo)&&!isnan(Ahi)) && abs(Alo-Ahi)>0.02
    @printf("  %.3f   %7.4f   %8.4f   %s\n", θ, Alo, Ahi, bist ? "YES" : "no")
end
println("\nDONE")

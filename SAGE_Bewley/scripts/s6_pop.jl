# Population machinery for stage 6, shared by the driver and every check.
# Requires s6_common.jl and a constant OMEGA to be defined by the includer.
const TASTE = Dict{Float64,Vector{Float64}}()
tastes(σ) = get!(TASTE, σ) do; taste_nodes_ln(σ; n = NQ); end
phi(z) = exp(-z^2 / 2) / sqrt(2pi)

# =============================================================== families ==
cache6(na) = (d = joinpath(@__DIR__, @sprintf("cache_s6_theta%.4f_amax%.1f_pexp%.1f_ne%d_na%d",
                                              THETA, GRID.a_max, GRID.pexp, NE, na)); isdir(d) || mkpath(d); d)
const FAMS = Dict{Any,Any}()
r8(x) = round(x, digits = 8)
function family_u(α, δ; rr = RR, subsidy = 0.0, lumptax = 0.0, partcredit = 0.0, thresholds = nothing, na = NA)
    thr = thresholds === nothing ? (0.0, 0.0) : (r8(thresholds[1][1]), r8(thresholds[1][2]))   # key on the anchored pair; the rest derive from it
    key = (r8(α), r8(δ), r8(rr), r8(subsidy), r8(lumptax), r8(partcredit), thr..., na)
    haskey(FAMS, key) && return FAMS[key]
    file = joinpath(cache6(na), "fam_" * join([replace(@sprintf("%.6f", k), "." => "p") for k in key[1:end-1]], "_") * ".jls")
    isfile(file) && return FAMS[key] = deserialize(file)
    t0 = time()
    p0 = cell_params_u(α; δ = δ, f = F_FIND, rr = rr, na = na, ne = NE, a_max = GRID.a_max,
                       pexp = GRID.pexp, subsidy = subsidy, lumptax = lumptax, partcredit = partcredit)
    nodes = build_family_u(p0, UGRID, THETA; threaded = true, thresholds = thresholds)
    base = SAGEParams(α = fill(α, 2), B = fill(1.0, 2))
    up = unemployment_process(base, δ, F_FIND)
    fam = (u = copy(UGRID), nodes = nodes,
           agrid = SAGEBewley.exponential_grid(p0.a_min, p0.a_max, p0.na, p0.pexp),
           employed = up.employed, transfer = copy(p0.transfer), lumptax = lumptax,
           alpha = α, delta = δ, rr = rr, thresholds = thresholds,
           r = [n.rate for n in nodes], minc = [n.minc for n in nodes], pbase = [n.pbase for n in nodes])
    @printf("  [family] alpha %.3f delta %.4f rr %.2f sub %.2f tax %.5f credit %.2f thr %s na %d  (%.1f min)\n",
            α, δ, rr, subsidy, lumptax, partcredit, thresholds === nothing ? "none" : "set", na, (time() - t0) / 60)
    flush(stdout)
    serialize(file, fam)
    FAMS[key] = fam
end

# ================================================= population aggregation ==
function node_weights(ugrid, κ, σ, B, arg)
    ms = tastes(σ); w = zeros(length(ugrid))
    for m in ms
        x = κ * m * B * arg
        if x <= ugrid[1]; w[1] += 1
        elseif x >= ugrid[end]; w[end] += 1
        else
            k = searchsortedlast(ugrid, x); t = (x - ugrid[k]) / (ugrid[k+1] - ugrid[k])
            w[k] += 1 - t; w[k+1] += t
        end
    end
    w ./ length(ms)
end
"Rate column of one cell integrated over tastes at scale kappa*B*arg."
cellrate(fam, κ, σ, B, arg) = dot(node_weights(fam.u, κ, σ, B, arg), fam.r)
"Aggregate map: (agg, lo, hi) at rate_in."
function agg(fl, fh, κ, σ, rin)
    arg = OMEGA + (1 - OMEGA) * clamp(rin, 0.0, 1.0)
    lo = cellrate(fl, κ, σ, CELLS[1].B, arg); hi = cellrate(fh, κ, σ, CELLS[2].B, arg)
    (CELLS[1].share * lo + CELLS[2].share * hi, lo, hi)
end
"All crossings of the map with stability; the highest stable one is returned."
function equilibrium(fl, fh, κ, σ; ngrid = 401)
    g = collect(range(0.0, 1.0, length = ngrid))
    o = [agg(fl, fh, κ, σ, x)[1] for x in g]
    best = nothing; nst = 0
    for i in 1:ngrid-1
        d1 = o[i] - g[i]; d2 = o[i+1] - g[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            sl = (o[i+1] - o[i]) / (g[i+1] - g[i])
            if sl < 1
                nst += 1
                rs = g[i] + d1 / (d1 - d2) * (g[i+1] - g[i])
                (best === nothing || rs > best.r) && (best = (r = rs, slope = sl))
            end
        end
    end
    best === nothing && return nothing
    _, lo, hi = agg(fl, fh, κ, σ, best.r)
    (r = best.r, lo = lo, hi = hi, slope = best.slope, nstable = nst)
end
function pool(fam, B, κ, σ, r)
    arg = OMEGA + (1 - OMEGA) * r
    w = node_weights(fam.u, κ, σ, B, arg)
    n1 = fam.nodes[1]; nz = length(n1.mass); na = length(fam.agrid)
    W = zeros(nz, na); mass = zeros(nz); part = zeros(nz); Y = zeros(length(YGRID))
    np = size(n1.jinc, 2)
    Ys = zeros(nz, length(YGRID)); ym_s = zeros(nz); jinc = zeros(nz, np); jboth = zeros(nz, np)
    ymean = 0.0; rate = 0.0; minc = 0.0; pbase = 0.0; ymin_E = Inf; eff_E = 0.0
    for (i, n) in enumerate(fam.nodes)
        wi = w[i]; wi <= 0 && continue
        W .+= wi .* n.W; mass .+= wi .* n.mass; part .+= wi .* n.part; Y .+= wi .* n.Y
        Ys .+= wi .* n.Ys; ym_s .+= wi .* n.ym_s; jinc .+= wi .* n.jinc; jboth .+= wi .* n.jboth
        ymean += wi * n.ymean; rate += wi * n.rate; minc += wi * n.minc; pbase += wi * n.pbase
        eff_E += wi * n.eff_E; ymin_E = min(ymin_E, n.ymin_E)
    end
    mU = sum(mass[.!fam.employed]); mE = 1 - mU
    (W = W, mass = mass, part = part, Y = Y, Ys = Ys, ym_s = ym_s, jinc = jinc, jboth = jboth,
     ymean = ymean, rate = rate, minc = minc, pbase = pbase, ymin_E = ymin_E,
     eff_E = eff_E / mE, u = mU,
     rate_U = sum(part[.!fam.employed]) / mU, rate_E = sum(part[fam.employed]) / mE,
     ym_U = sum(ym_s[.!fam.employed]) / mU, ym_E = sum(ym_s[fam.employed]) / mE,
     agrid = fam.agrid, employed = fam.employed, thresholds = fam.thresholds,
     alpha = fam.alpha, transfer = fam.transfer, lumptax = fam.lumptax)
end
"Hardship at thresholds other than the stored ones: exact for the unemployed
(income there is monotone in wealth), and for the employed provided none is
income-poor at that line, which is checked."
function hardship_at(P, ypov, abar; R = 1.02)
    nz = length(P.mass); inc = 0.0; ast = 0.0; both = 0.0
    P.ymin_E > ypov || return nothing
    for s in 1:nz
        Ws = view(P.W, s, :)
        as = share_below_interp(P.agrid, Ws, abar); ast += as
        P.employed[s] && continue
        astar = (ypov - (P.transfer[s] - P.lumptax)) / (R - 1)
        astar <= 0 && continue
        inc += share_below_interp(P.agrid, Ws, astar)
        both += share_below_interp(P.agrid, Ws, min(abar, astar))
    end
    (inc = inc, asset = ast, both = both, vulnerable = ast - both, union = inc + ast - both)
end
"Population objects from the two pooled cells."
function population(Pl, Ph, q::Int = 1)
    hl = hardship(Pl, q); hh = hardship(Ph, q)
    sl, sh = CELLS[1].share, CELLS[2].share
    mix(f) = sl * getfield(hl, f) + sh * getfield(hh, f)
    A_l = Pl.alpha * (1 - hl.union); A_h = Ph.alpha * (1 - hh.union)
    (hl = hl, hh = hh,
     inc = mix(:inc), asset = mix(:asset), both = mix(:both), vulnerable = mix(:vulnerable), union = mix(:union),
     u = sl * Pl.u + sh * Ph.u,
     inc_U = (sl * Pl.u * hl.inc_U + sh * Ph.u * hh.inc_U) / (sl * Pl.u + sh * Ph.u),
     inc_E = (sl * (1-Pl.u) * hl.inc_E + sh * (1-Ph.u) * hh.inc_E) / (sl * (1-Pl.u) + sh * (1-Ph.u)),
     asset_U = (sl * Pl.u * hl.asset_U + sh * Ph.u * hh.asset_U) / (sl * Pl.u + sh * Ph.u),
     asset_E = (sl * (1-Pl.u) * hl.asset_E + sh * (1-Ph.u) * hh.asset_E) / (sl * (1-Pl.u) + sh * (1-Ph.u)),
     A = sl * A_l + sh * A_h, A_l = A_l, A_h = A_h, alphabar = sl * Pl.alpha + sh * Ph.alpha,
     rate = sl * Pl.rate + sh * Ph.rate, rate_U = (sl * Pl.u * Pl.rate_U + sh * Ph.u * Ph.rate_U) / (sl * Pl.u + sh * Ph.u),
     rate_E = (sl * (1-Pl.u) * Pl.rate_E + sh * (1-Ph.u) * Ph.rate_E) / (sl * (1-Pl.u) + sh * (1-Ph.u)),
     ymean = sl * Pl.ymean + sh * Ph.ymean, minc = sl * Pl.minc + sh * Ph.minc,
     eff_E = (sl * (1-Pl.u) * Pl.eff_E + sh * (1-Ph.u) * Ph.eff_E) / (sl * (1-Pl.u) + sh * (1-Ph.u)),
     Wtot = sl * vec(sum(Pl.W, dims = 1)) + sh * vec(sum(Ph.W, dims = 1)),
     Y = sl * Pl.Y + sh * Ph.Y, agrid = Pl.agrid)
end
meaninc(fl, fh, κ, σ, r) = (arg = OMEGA + (1-OMEGA)*r;
    CELLS[1].share * dot(node_weights(fl.u, κ, σ, CELLS[1].B, arg), fl.minc) +
    CELLS[2].share * dot(node_weights(fh.u, κ, σ, CELLS[2].B, arg), fh.minc))
partbase(fl, fh, κ, σ, r) = (arg = OMEGA + (1-OMEGA)*r;
    CELLS[1].share * dot(node_weights(fl.u, κ, σ, CELLS[1].B, arg), fl.pbase) +
    CELLS[2].share * dot(node_weights(fh.u, κ, σ, CELLS[2].B, arg), fh.pbase))


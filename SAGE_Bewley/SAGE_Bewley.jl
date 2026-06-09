### A Pluto.jl notebook ###
# v0.19.47

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 528a551a-36fb-479e-aada-d70551176bd2
begin
    import Pkg
    Pkg.activate(@__DIR__)
    using Plots, PlutoUI, Printf, Statistics
    include(joinpath(@__DIR__, "src", "SAGEBewley.jl"))
    using .SAGEBewley
    gr(fmt = :png, size = (820, 300), legend = :best)
    BLUE, ORANGE = "#1f77b4", "#ff7f0e"
    function gbar(cats, series; labels, colors, kw...)
        n = length(series); m = length(cats); w = 0.8 / n
        pl = plot()
        for i in 1:n
            xs = (1:m) .+ (i - (n + 1) / 2) * w
            bar!(pl, xs, series[i], bar_width = w, label = labels[i], color = colors[i])
        end
        plot!(pl, xticks = (1:m, cats); kw...)
        pl
    end
    TableOfContents(title = "SAGE-Bewley", depth = 2)
end

# ╔═╡ 5d40d83d-685c-4003-bbfe-b61bb85e66d7
md"""
# Wellbeing and Macroeconomics: an interactive SAGE-Bewley model

*Alessandro Conway. Adapted from the master's thesis "Wellbeing and Macroeconomics: A SAGE approach" (Sciences Po, 2020).*

This notebook lets you play with a heterogeneous-agent (Bewley/Aiyagari) model in
which households care about more than consumption. Following the SAGE framework,
welfare has separate dimensions:

| | dimension | in the model |
|---|---|---|
| **S** | Social cohesion | a public good `Q` everyone contributes time to |
| **A** | Agency | how much of your labour effort becomes income (`α`) |
| **G** | material Gain | standard consumption utility |

The model is built up one idea at a time. Drag the sliders and watch the policies
and the wealth distribution respond. Each solve takes a fraction of a second.
"""

# ╔═╡ edb97b09-6ff5-434a-aa28-c3c43318c947
html"""
<style>
main { max-width: 1100px; }
pluto-output table { font-variant-numeric: tabular-nums; }
</style>
"""

# ╔═╡ f987caa2-cdb0-4090-8793-ee298667b259
md"""
## 1. The baseline Bewley economy (G)

A unit mass of households face uninsurable income risk (two productivity states,
low and high). They consume, save in a riskless bond at gross rate `R`, and choose
labour effort `e`. There are no firms, so the interest rate is exogenous (partial
equilibrium). This is the familiar incomplete-markets workhorse, before any SAGE
ingredient is switched on (full agency `α = 1`, no social good).

Drag the discount factor `β` and the interest rate `R`.
"""

# ╔═╡ 6ab5f23a-8b8c-4aa1-a226-c5da7070062a
md"**β** (patience)　$(@bind β1 Slider(0.95:0.005:0.995, default = 0.99, show_value = true))"

# ╔═╡ adae2c39-02d1-4483-85af-eabf5ced6948
md"**R** (gross rate)　$(@bind R1 Slider(1.0:0.002:1.02, default = 1.01, show_value = true))"

# ╔═╡ c60437a3-b67d-41c6-9026-30d5d972d8ca
begin
    s1 = solve_model(SAGEParams(β = β1, R = R1, α = [1.0, 1.0], Λ = 0.0))
    let a = s1.a_grid
        p1 = plot(a, s1.c[:,1], c=BLUE, lw=2, label="low", title="Consumption c(a,z)",
                  xlabel="assets a")
        plot!(p1, a, s1.c[:,2], c=ORANGE, lw=2, label="high")
        imax = findfirst(>(20.0), a); imax === nothing && (imax = length(a))
        p2 = plot(a[1:imax], s1.λ[1:imax,1], c=BLUE, lw=2, label="low",
                  title="Wealth distribution", xlabel="assets a", ylabel="mass")
        plot!(p2, a[1:imax], s1.λ[1:imax,2], c=ORANGE, lw=2, label="high")
        plot(p1, p2, layout=(1,2))
    end
end

# ╔═╡ 47c4eb25-bdff-4160-a6ae-8fbd5c15cbad
md"""
**Gini (wealth)** = $(round(wealth_gini(s1), digits=3))　·　**at credit constraint** = $(round(100*frac_constrained(s1), digits=1))%
"""

# ╔═╡ 7799ab08-3b72-4227-ba68-e1aa22621f3a
md"""
## 2. Adding Agency (A)

Agency is the degree to which people can turn effort into outcomes: labour-market
security, health, skills. We model it as a parameter `α ∈ [0,1]`, so only a fraction
`α` of labour income is retained:

$$c + a' = α_z\,e\,z + R\,a .$$

Low-income households have lower agency, `α_low < α_high`. Watch the effort panel:
when your effort is poorly rewarded, once you have a little wealth you stop working
so hard, and that wedge is what drives the social story next.
"""

# ╔═╡ 9948a4c3-afdb-402d-b979-9a05c63ddec0
md"**α** low income　$(@bind αlo Slider(0.5:0.01:1.0, default = 0.765, show_value = true))"

# ╔═╡ 4bb7a4fb-3571-460a-b908-858ec172d3ab
md"**α** high income　$(@bind αhi Slider(0.5:0.01:1.0, default = 0.911, show_value = true))"

# ╔═╡ 905ba1fd-acc0-43c2-ad78-dd6da1b05e85
begin
    s2 = solve_model(SAGEParams(α = [αlo, αhi], Λ = 0.0))
    let a = s2.a_grid
        p1 = plot(a, s2.c[:,1], c=BLUE, lw=2, label="low", title="Consumption",
                  xlabel="assets a")
        plot!(p1, a, s2.c[:,2], c=ORANGE, lw=2, label="high")
        p2 = plot(a, s2.e[:,1], c=BLUE, lw=2, label="low", title="Labour effort e(a,z)",
                  xlabel="assets a", ylims=(0,1.02))
        plot!(p2, a, s2.e[:,2], c=ORANGE, lw=2, label="high")
        plot(p1, p2, layout=(1,2))
    end
end

# ╔═╡ a8aa7fa8-8b1f-4311-b960-e2c51f21ead3
md"""
## 3. Adding Social cohesion (S)

Time not spent working is contributed to society: `q = 1 - e`. The sum of everyone's
contributions is a public good `Q`, enjoyed according to a taste parameter `B_z`
(social-cohesion utility is `Λ · B_z · Q`).

Because low-agency households work less, they supply most of the public good, even
though, with `B_low < B_high`, they enjoy it less per unit. That tension is the heart
of the thesis.

> **Honest modelling note.** In the canonical thesis code the social term is
> additively separable and does not feed back into the effort choice, so `B` and `Λ`
> here reshape welfare, not behaviour. Making cohesion an active margin (warm-glow or
> social-multiplier) is the first planned extension.
"""

# ╔═╡ 5b9e4801-dee4-4820-babd-54d3f6bde003
md"**B** low (enjoyment)　$(@bind Blo Slider(0.5:0.01:1.0, default = 0.80, show_value = true))"

# ╔═╡ 903c4b97-4b31-43bb-98ea-de5fb20e36a3
md"**B** high (enjoyment)　$(@bind Bhi Slider(0.5:0.01:1.0, default = 0.94, show_value = true))"

# ╔═╡ 1a516b90-efe6-4db1-95e2-526d21ee5fe9
md"**Λ** weight on cohesion　$(@bind Λ3 Slider(0.0:0.05:1.5, default = 0.876, show_value = true))"

# ╔═╡ fe678674-525e-4b1d-b15f-24163465b829
begin
    s3 = solve_model(SAGEParams(B = [Blo, Bhi], Λ = Λ3))
    let a = s3.a_grid
        p1 = plot(a, s3.q[:,1], c=BLUE, lw=2, label="low",
                  title="Social contribution q = 1 - e", xlabel="assets a", ylims=(0,1.02))
        plot!(p1, a, s3.q[:,2], c=ORANGE, lw=2, label="high")
        sh = public_good_shares(s3)
        p2 = bar(["low","high"], sh, c=[BLUE,ORANGE], legend=false,
                 title="Who supplies the public good?", ylabel="share of Q", ylims=(0,1))
        plot(p1, p2, layout=(1,2))
    end
end

# ╔═╡ ff3add0b-920c-43ed-9462-8fb376e96155
md"""
**Public good size** Q = $(round(s3.Q, digits=3))　·　low income supplies $(round(100*public_good_shares(s3)[1]))% of it.
"""

# ╔═╡ 0f54b399-4468-496f-8b91-63280497b24f
md"""
## 4. The balanced wellbeing dashboard

SAGE's second idea: wellbeing is the balance of the dimensions, not their sum. Here
we display the two dimensions side by side, by wealth quartile within each income
group, the stationary "optimal dashboard" against which shocks are judged. `Uᶜ`
(material) rises with wealth. `Uˢ = Λ·B·Q` (social) is flat within a group and higher
for high-income, who enjoy the good more even though they supply less.
"""

# ╔═╡ 0bb0a23c-e943-4686-b028-3e9bfe650309
let
    s = solve_model(SAGEParams(B = [Blo, Bhi], Λ = Λ3, α = [αlo, αhi]))
    function quartiles(z)
        w = s.λ[:,z] ./ sum(s.λ[:,z]); cw = cumsum(w)
        edges = (0.0,0.25,0.5,0.75,1.0); Uc=zeros(4); Us=zeros(4)
        for qi in 1:4
            m = (cw .> edges[qi]-1e-9) .& (cw .<= edges[qi+1]+1e-9)
            any(m) || (m=falses(length(w)); m[argmin(abs.(cw.-edges[qi+1]))]=true)
            ww = w[m] ./ sum(w[m])
            Uc[qi] = sum(ww .* s.Uc[m,z]); Us[qi] = sum(ww .* s.Us[m,z])
        end
        Uc, Us
    end
    Uc_l,Us_l = quartiles(1); Uc_h,Us_h = quartiles(2)
    labs = ["Q1","Q2","Q3","Q4"]
    p1 = gbar(labs, [Uc_l, Uc_h]; labels=["low","high"], colors=[BLUE,ORANGE],
              title="Material gain Uᶜ by quartile")
    p2 = gbar(labs, [Us_l, Us_h]; labels=["low","high"], colors=[BLUE,ORANGE],
              title="Social cohesion Uˢ by quartile")
    plot(p1, p2, layout=(1,2))
end

# ╔═╡ 7582284a-ce34-4af4-8672-ee311a532529
md"""
## 5. A productivity shock and the decoupling

Raise aggregate productivity by a few percent (`Z`) and compare the new stationary
economy to the old. Material gain rises for everyone. But the public good's
composition shifts toward high-income households (they now work more), and if social
belonging depends on who surrounds you (homophily, "organic solidarity"), the social
dimension can move in opposite directions across groups: the decoupling of economic
and social prosperity. Toggle homophily to let each group's `B` track its share of
the public good.
"""

# ╔═╡ 6f7f7313-4de6-4b84-9a04-97a25d29691d
md"**shock** to productivity Z　$(@bind shock Slider(0.0:0.005:0.10, default = 0.02, show_value = true))"

# ╔═╡ 7c8e0efc-2b9d-4bdc-9bdf-c01a945b1c31
md"**homophily** (organic solidarity)　$(@bind homophily CheckBox(default = true))"

# ╔═╡ 560cadcb-2dd0-4916-8103-09a46930ad85
begin
    base = SAGEParams(B = [Blo, Bhi], Λ = Λ3, α = [αlo, αhi])
    s0 = solve_model(base)
    sh0 = public_good_shares(s0)
    sh1 = public_good_shares(solve_model(update(base; Z = 1 + shock)))
    Bnew = homophily ? clamp.(base.B .* (sh1 ./ sh0), 0.0, 1.0) : base.B
    s1s = solve_model(update(base; Z = 1 + shock, B = Bnew))
    avg(s, M, z) = sum((s.λ[:,z]./sum(s.λ[:,z])) .* M[:,z])
    Uc0=[avg(s0,s0.Uc,z) for z in 1:2]; Uc1=[avg(s1s,s1s.Uc,z) for z in 1:2]
    Us0=[avg(s0,s0.Us,z) for z in 1:2]; Us1=[avg(s1s,s1s.Us,z) for z in 1:2]
    dUc = 100 .*(Uc1.-Uc0)./abs.(Uc0); dUs = 100 .*(Us1.-Us0)./abs.(Us0)
    p1 = gbar(["low","high"], [dUc, dUs]; labels=["Material Uᶜ","Social Uˢ"],
              colors=["#2ca02c","#9467bd"], title="% change in wellbeing dimensions",
              ylabel="% deviation from stationary")
    hline!(p1, [0], c=:black, lw=1, label=false)
    plot(p1, size=(560,320))
end

# ╔═╡ 633d32ba-e34f-4e7d-90eb-71c7fda0c155
md"""
Public good supplied by low income: **$(round(100*sh0[1]))% to $(round(100*sh1[1]))%**.
$(homophily ? "With homophily, low-income social belonging can fall while material gain rises, the decoupling the thesis set out to reproduce." : "With constant B, both dimensions simply rise. Turn on homophily to see the decoupling.")
"""

# ╔═╡ 10d50045-d8ec-4d30-b965-d8e023a15790
md"""
---
### What this is, and what it is not yet

A clean, stable re-implementation of the thesis model: a QuantEcon-style `DiscreteDP`
solve with smooth (interpolated) policies and an exact Young (2010) lottery
distribution. No NaNs, no post-hoc smoothing, about half a second per solve.

Faithful to the thesis: the effort and contribution divergence between income groups,
the low-income-dominated public good, the wellbeing dashboard, and the shock-induced
decoupling under homophily.

Deliberately simplified, and on the roadmap: the shock here compares stationary
economies rather than the full dynamic transition; social cohesion is a welfare
overlay rather than an active behavioural margin; and the model is partial
equilibrium. Each is a planned extension (general equilibrium, behavioural social
cohesion, a genuine non-substitutable wellbeing aggregator).

Built with QuantEcon.jl and Pluto.jl.
"""

# ╔═╡ Cell order:
# ╟─5d40d83d-685c-4003-bbfe-b61bb85e66d7
# ╠═528a551a-36fb-479e-aada-d70551176bd2
# ╟─edb97b09-6ff5-434a-aa28-c3c43318c947
# ╟─f987caa2-cdb0-4090-8793-ee298667b259
# ╟─6ab5f23a-8b8c-4aa1-a226-c5da7070062a
# ╟─adae2c39-02d1-4483-85af-eabf5ced6948
# ╠═c60437a3-b67d-41c6-9026-30d5d972d8ca
# ╟─47c4eb25-bdff-4160-a6ae-8fbd5c15cbad
# ╟─7799ab08-3b72-4227-ba68-e1aa22621f3a
# ╟─9948a4c3-afdb-402d-b979-9a05c63ddec0
# ╟─4bb7a4fb-3571-460a-b908-858ec172d3ab
# ╠═905ba1fd-acc0-43c2-ad78-dd6da1b05e85
# ╟─a8aa7fa8-8b1f-4311-b960-e2c51f21ead3
# ╟─5b9e4801-dee4-4820-babd-54d3f6bde003
# ╟─903c4b97-4b31-43bb-98ea-de5fb20e36a3
# ╟─1a516b90-efe6-4db1-95e2-526d21ee5fe9
# ╠═fe678674-525e-4b1d-b15f-24163465b829
# ╟─ff3add0b-920c-43ed-9462-8fb376e96155
# ╟─0f54b399-4468-496f-8b91-63280497b24f
# ╠═0bb0a23c-e943-4686-b028-3e9bfe650309
# ╟─7582284a-ce34-4af4-8672-ee311a532529
# ╟─6f7f7313-4de6-4b84-9a04-97a25d29691d
# ╟─7c8e0efc-2b9d-4bdc-9bdf-c01a945b1c31
# ╠═560cadcb-2dd0-4916-8103-09a46930ad85
# ╟─633d32ba-e34f-4e7d-90eb-71c7fda0c155
# ╟─10d50045-d8ec-4d30-b965-d8e023a15790

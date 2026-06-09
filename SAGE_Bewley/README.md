# SAGE-Bewley - an interactive wellbeing macro model

A clean, stable, interactive re-implementation of the heterogeneous-agent
(Bewley/Aiyagari) model from the master's thesis *"Wellbeing and Macroeconomics:
A SAGE approach"* (A. Conway, Sciences Po, 2020).

Households care about more than consumption. Following the **SAGE** framework,
welfare has separate dimensions - **S**ocial cohesion, **A**gency, material
**G**ain - and the model shows how a productivity shock can *decouple* them.

## Run the interactive notebook

```bash
cd SAGE_Bewley
julia --project=. -e 'import Pkg; Pkg.instantiate()'   # first time only
julia --project=. run.jl                               # opens Pluto in your browser
```

Then drag the sliders. The model is built up one SAGE ingredient at a time
(baseline → agency → social cohesion → wellbeing dashboard → shock & decoupling).
Each solve takes ~0.5 s.

## What's inside

| file | purpose |
|---|---|
| `SAGE_Bewley.jl` | the **Pluto notebook** (the product) |
| `src/SAGEBewley.jl` | the model: `SAGEParams`, `solve_model`, diagnostics |
| `run.jl` | launches Pluto straight to the notebook |
| `scripts/prototype.jl` | solve + qualitative checks vs. the thesis |
| `scripts/plots.jl` | saves steady-state figures to `figures/` |
| `scripts/test_notebook.jl` | headlessly runs every notebook cell (CI-style check) |

## Method (how it's stable where the original wasn't)

* Effort `e` is discretized and folded into the reward; next-assets is solved as a
  QuantEcon `DiscreteDP` - fast and stable, no NaNs.
* Policies are then refined to **continuous** values against the interpolated value
  function (the fix the thesis recommended), removing grid quantization.
* The wealth distribution is the exact **Young (2010) lottery** stationary
  distribution - smooth, no simulation.

## Known simplifications (next steps)

* The shock compares *stationary economies*, not the full dynamic transition.
* Social cohesion is a welfare overlay, not yet an active behavioural margin.
* Partial equilibrium (exogenous `R`); a general-equilibrium close is the natural
  upgrade.

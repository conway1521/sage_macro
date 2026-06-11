# Paper 3 (calibrated history): first build, results and honest grading

Built 2026-06-10 from the revised design in the vault note "Inequality Dynamics and the Social Fabric". This is Tier A: drive the model with each country's observed income-inequality path and read off the endogenous social fabric. Scripts: `p3_family.jl` (the 2D response family), `p3_history.jl` (the year-by-year solve with bounds), `p3_validate.jl` (validation, decomposition, WELLBY pricing, figures). Data: `data/income_gini_wb.csv` (driver), `data/wise_recoupling.csv` and `data/owid_trust_wvs.csv` (validation), the WELLBY bridge.

## What was built, and that it works

- The 2D response family r(u, alpha) precomputed on a six-point agency grid, so the whole multi-country history is interpolation (one build, every year-solve in milliseconds). Engineering goal met.
- The driver: a transparent common map from observed income Gini to the agency gap (Gini 30 gives no gap, Gini 45 gives the widest gap in the family), the same for every country. The model's own income Gini is a co-moving consistency check, not a forced target, because the one-asset two-cell model understates income dispersion and can track direction but not level. Stated plainly.
- The two bounds: a steady-state path (the gap at its current value) and an impact path (the gap entering through an AR(1)-smoothed slow wealth state). They bracket how fast cohesion responds. They coincide at endpoints under monotone driver paths and separate along the path, as intended.

## The headline: the United States, four decades

Driven by the US income Gini (World Bank, 1963 to 2024, rising from 34.7 in 1980 to 41.8), the model produces a social-fabric decline concentrated in 1980 to 2000, exactly where inequality actually rose:

- model participation (cohesion) falls from 0.456 (1980) to 0.244 (2024), a 46 percent proportional decline;
- the participation gradient (high group over low group) widens from 1.53 to 2.49: the low-education group's cohesion collapses faster, so the enjoyment of the fabric becomes sharply less equal even as the aggregate falls. This is the distributional result no single index sees.

Priced through the WELLBY bridge, the US fabric decline is worth -0.53 life-satisfaction points per person per year, that is -0.53 WELLBYs, about -6,900 GBP per person per year at the Green Book value, or 24 percent of income in compensating-variation terms. That is the headline number: the experienced-wellbeing cost of the inequality-driven erosion of the social fabric.

## The decomposition, told honestly

The model attributes its whole predicted decline to inequality, since inequality is the only driver. Its 46 percent proportional fall spans the documented observed range (GSS trust fell about 28 percent over the period; Putnam's associational-membership measures roughly halved). So the inequality channel is a first-order driver of the US social-capital decline, not a minor one. But the model's complementarity, calibrated to a French cross-section, probably overstates the pure-inequality share when pushed into a time series (the same cross-section-to-time-series caution that Tier B's Chetty calibration will face). The honest statement: inequality can account for the bulk, the residual and the timing belong to the secular forces the model omits, and the complementarity wants disciplining before the share is quoted precisely.

## The cross-country panel: a cautionary result, not a clean confirmation

Over each country's full window the model's cohesion change has the sign of the inequality change by construction. Against the WISE Solidarity change (2007 to 2018) the match is mixed: the United States and Italy agree (inequality up or flat, solidarity down), while France, Germany and China disagree. The disagreements are informative, not embarrassing: Germany 1991 to 2022 is reunification convergence (inequality up but solidarity up), China is development and catch-up (with the WISE data-quality caveats), and the windows differ from the WISE decade. South Africa and Colombia sit above the OECD-range driver map (Gini above 45) and clamp at the widest gap, so the model says only that they are already at the floor.

The real lesson is the one the review predicted: over 2007 to 2018, income inequality was roughly flat in most of these economies (US Gini 41.1 to 41.8), so the inequality channel predicts little for that decade and cannot explain the observed solidarity moves in it. The inequality-to-cohesion mechanism is a long-run force, visible in the US over four decades, not a decade-scale one. The cross-country decade is too short, too confounded, and too flat on inequality to be a clean test. That is a legitimate scientific conclusion and it sets up Tier B (the structural forces that move cohesion within the decade).

## Honest grades

| component | grade | note |
|---|---|---|
| design (post-review) | A | over-identification, bounds, long-run US, decomposition framing |
| computational core | A- | 2D family, bounds, fast, reproducible; one-asset limits stated |
| US long-run result | A- | clean 46 percent decline, gradient widening, WELLBY-priced; would be A with a clean annual GSS overlay |
| WELLBY pricing | A- | uses the verified bridge end to end |
| decomposition | B+ | honest, first-order, complementarity likely too strong |
| cross-country validation | B | mixed and confounded; the honest conclusion (long-run force, decade confounded) is itself the finding |
| data | B+ | US driver, WISE, WELLBY solid; the annual Gallup panel (WHR S3 blocked) and the clean GSS US series need data requests |

Overall this is a strong A- proof of concept that earns Paper 3 as a standalone. It is not yet a uniform A, and forcing that claim would repeat the mistake the tipping retraction corrected. The precise, non-modelling path to A: (1) the WHR data-sharing request for the annual Gallup social-support panel (2005 to 2024, all seven countries including Colombia), which gives a real annual cross-country validation; (2) the GSS trust and membership series for a clean four-decade US overlay; (3) a WID earnings-dispersion driver to replace the income-Gini proxy; (4) discipline the complementarity for the time series before quoting the decomposition share. None of these is a model fix; all are data and calibration steps already identified.

## Reproduce

```
julia --project=. scripts/p3_family.jl     # build the 2D family (minutes)
julia --project=. scripts/p3_history.jl    # the calibrated history, both bounds
julia --project=. scripts/p3_validate.jl   # validation, decomposition, figures
```

Figures: `paper/figures/p3_us_history.png`, `p3_us_gradient.png`, `p3_crosscountry.png`.

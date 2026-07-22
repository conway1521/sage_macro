# WISE benchmark: the model's orderings against the Recoupling indices

Built 2026-06-10 (collaboration plan task 3.1). Script `SAGE_Bewley/scripts/wise_benchmark.jl`, figure `paper/figures/wise_benchmark.png`, table `scripts/wise_benchmark.txt`. Data: the model's seven country calibrations against the WISE Recoupling Agency and Solidarity indices (`data/wise_recoupling.csv`, six countries, no Colombia).

## What was compared

- Agency: the model's mean agency (the share-weighted retained-income parameter, calibrated from OECD How's Life) against the WISE Agency Index (labour insecurity, vulnerable employment, life expectancy, education, confidence in institutions). Different underlying data, so a genuine cross-source check.
- Cohesion: the model's equilibrium public good Q = E[1-e], an endogenous output, against the WISE Solidarity Index (social support, trust, giving). Reported for both raw Q and the belonging-weighted enjoyment Lambda B Q.

Rank agreement is Spearman rho on the country ranks, with n = 6 (all) and the OECD n = 4 (France, Germany, Italy, United States) as the cleaner read, since China and South Africa carry the authors' data-quality caveats and the model's one-asset limits.

## The result, and it is split

Agency validates, strongly and robustly. Spearman +0.89 across all six and +0.80 across the OECD four, identical in 2007, 2017 and 2018. The model's agency ordering, calibrated from one data pipeline, independently reproduces the WISE Agency Index built from another. This is a clean, non-circular win.

Cohesion diverges, robustly, and in fact inverts. Spearman is negative in every year, for both cohesion measures, reaching -0.80 to -1.00 among the OECD four. Weighting Q by the support-calibrated belonging taste makes the disagreement worse, not better, so there is no hidden circularity propping up a false match; the model genuinely disagrees with WISE on cohesion. In the figure, France sits highest in the model and lowest in WISE, the United States the reverse.

| | agency | solidarity (Q) | solidarity (Lambda B Q) |
|---|---|---|---|
| all six, any year | +0.89 | -0.26 to -0.37 | +0.09 to -0.60 |
| OECD four, any year | +0.80 | -0.40 to -0.80 | -0.80 to -1.00 |

## Why cohesion inverts

The two things are cousins, not twins. The model's cohesion is time not spent working, the associative and family time an agent gives to society. That is high in low-hours Europe and low in the long-hours United States. WISE Solidarity is measured trust, support and giving behaviour, which is high in the United States and lower in France. So the model reads France as the most cohesive because the French work least, while WISE reads the United States as more solidary because Americans give and trust more. This is the long-standing tension between time-availability and behavioural social capital, not a coding error, and it is robust to year and to the cohesion measure.

## What this means

Two honest conclusions. First, the model is a good structural account of agency, and the benchmark demonstrates it against the measurement programme's own index. Second, the model's cohesion object, aggregate non-work time, is not the same construct as measured solidarity, and cross-country the two invert. The clean claim "the model reproduces the Recoupling orderings" holds for agency and fails for solidarity.

For the collaboration this is a sharper, more interesting position than a bland match would have been, because it is non-circular and it surfaces a real question: the model's time-based cohesion and the programme's behaviour-based solidarity disagree systematically, and reconciling them, or giving the model a cohesion output that tracks measured solidarity, is a concrete joint project rather than a confirmation exercise. The pitch leads with the agency validation and offers the cohesion divergence as the open question, honestly labelled.

The alternative reading, which should not be hidden, is that the model's cohesion measure needs rethinking before the model can be called the structural counterpart of the Recoupling Dashboard. The country calibration moves agency and inequality, not the cohesion output, whose cross-country range is narrow (0.36 to 0.48), so the model was never really built to differentiate solidarity across countries. That is a limitation to state plainly to any partner, and possibly a thing to fix before leaning on the dashboard comparison.

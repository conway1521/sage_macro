# SAGE-Bewley

A modern, modular, heterogeneous-agent macro model of wellbeing, built on the SAGE
framework (Snower and Lima de Miranda). A refurbishment of a 2020 master's thesis
into a stable, calibrated, reusable engine, with a ladder of papers that add the
wellbeing dimensions one at a time.

## Contents

- `SAGE_Bewley/` the Julia solver, scripts, and figures, plus an interactive Pluto
  notebook. The model is modular: social cohesion, agency, and a policy lever are
  flags on one engine.
- `paper/` the lead working paper (LaTeX), "Social Cohesion as a Coordination
  Problem", with its figures and bibliography.
- `sage-lectures/` a QuantEcon-style lecture site (its own git repository, deployed
  to GitHub Pages). Not tracked here.

## The model in one line

A standard incomplete-markets economy where households split time between market work
and contributing to a social public good. Behavioural social cohesion plus agency
inequality make cohesion a coordination problem with multiple equilibria, and a
make-work-pay policy raises consumption while eroding cohesion, a tradeoff that
single-index welfare analysis cannot see.

## Run the model

```bash
cd SAGE_Bewley
julia --project=. -e 'import Pkg; Pkg.instantiate()'
julia --project=. scripts/prototype.jl      # solve and diagnostics
julia --project=. run.jl                     # the interactive Pluto notebook
```

## Build the paper

```bash
cd paper
latexmk -pdf sage_s.tex
```

## Status

The baseline, S, and S+A results are done and reproducible. See the research notes
for the programme logic, roadmap, and live status.

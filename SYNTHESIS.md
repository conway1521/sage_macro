# Synthesis: what we found, what we fixed, and why it is better now

Written for a reader who wants the story without the technical report. The technical companion with grades, tables and every number is REVIEW.md in this folder. Everything described here is committed to this repository and reproducible by running the named scripts.

## The story in one paragraph

We took a working model that produced exciting results, subjected it to the kind of hostile examination a top referee would give it, and found that its most dramatic result was standing on a setting the evidence rejects. Rather than patch around that, we replaced every hand-set number in the model with a published consensus value or a value tuned to a stated data target, fixed three genuine defects the examination turned up, and re-ran everything. The result is a model that is slower to impress but far harder to knock down: its headline policy result survived intact and became sharper, its dramatic result was honestly retracted and then rebuilt on foundations that match the evidence, and the model now reproduces real-world wealth facts it was never told to match. The paper has been rewritten around what is true.

## Part 1: What the stress-testing found

**A solver that sometimes gave up quietly.** The routine that computes how wealth is spread across the population would, in slow-moving cases, stop before finishing and hand back a slightly wrong answer without telling anyone. In the corrected model this quiet error was worth almost two percentage points on the headline cohesion number.

**A tiny accounting slip.** The inequality measure skipped the first sliver of its calculation. Harmless in practice, wrong in principle.

**A fatal knife edge.** Two settings carried over from the thesis, how patient people are and the interest rate they face, were balanced so finely against each other that, once we used evidence-based curvature for preferences, the model's wealth distribution was being shaped by an arbitrary technical boundary inside the computer rather than by economics. Numbers moved when the grid moved, which is the numerical equivalent of a building that sways when you lean on it.

**The big one: the tipping result rested on an indefensible setting.** The model's most striking claim was that society can tip between a low-cohesion and a high-cohesion state. That claim needed people to reallocate their time roughly eight times more readily than decades of evidence say they do. With the evidence-based responsiveness, the tipping vanishes entirely, no matter how strong the social feedback is made. Two earlier findings built on top of it, that tipping requires inequality in agency, and that a committed minority can flip society, fall with it.

## Part 2: What we fixed and built

**Every number now has a source.** Risk preferences come from the largest published meta-analysis; the work-responsiveness setting comes from the quasi-experimental consensus; patience and the interest rate are the standard values of the workhorse literature; the one free dial was tuned so that the model's split between paid work and unpaid contribution matches French time-use data, where paid work averages 3h24 a day and unpaid domestic and associative work 3h01. The swept parameters that genuinely have no data, the social-return strength and the homophily weight, are declared as swept, openly.

**The solver now always finishes.** When the fast method stalls, the engine switches to a method that is mathematically guaranteed to converge for this kind of problem, and is also faster. The quiet-failure mode no longer exists.

**The knife edge is gone.** With standard patience and interest settings the wealth distribution is stable against every numerical stress test we threw at it, and as a bonus the model now matches two facts about real economies it was never aimed at: roughly a third of households living hand to mouth, and a wealth inequality figure close to the data rather than far below it as such models usually are.

**The policy result survived and got sharper.** A make-work-pay subsidy, the kind of activation policy real governments run, still raises total consumption (5.5 percent) while eroding the social fabric (4.7 percent). Under the honest settings a new and harder-hitting fact emerged: because the subsidy is financed by a flat per-head tax, the poorer group loses outright on the material dimension as well as the social one, while the richer group gains materially. The total consumption gain that a standard evaluation reports is entirely produced by the richer group. A one-number evaluation sees none of this; that is the paper's point, and it is now stronger.

**The tipping story was rebuilt on honest ground.** Theory says that abrupt social flips come from all-or-nothing choices, not from smooth dial-turning. So we built a prototype where the choice is discrete: join associative life, with a minimum meaningful commitment of time, or do not. Calibrated so that participation matches the French rate of about one third, the prototype economy genuinely has two possible states: a low one where about 15 percent participate and a high one where about half do. In other words, an economy that looks like France may sit inside a coordination region, and which state it occupies is a matter of history rather than fundamentals. That question, made rigorous, is the next paper. Stated plainly: near the flip point the prototype's exact numbers are sensitive to numerical settings, so what it establishes is the structure, not the precise figures; the full build is designed to nail those down.

**Two new channels were built and tested.** First, homophily: belonging can come from one's own group rather than from society at large. Turning that dial towards own-group-only widens the cohesion gap between education groups and redistributes social wellbeing regressively, nine percent up for the advantaged, nine percent down for the disadvantaged, a structural version of the claim that bridging ties are what the disadvantaged can least afford to lose. Second, a population of measured social types from the experimental literature, half conditional cooperators, a third free riders, a fifth committed givers, which shows that committed givers lift everyone with increasing returns, though they cannot flip society under honest settings.

**The paper was rewritten.** New title, new abstract, every number regenerated by a single script so the text and the code cannot drift apart, the retracted results replaced by the honest ones, the retraction itself reported as a finding with equal prominence, and the figures rebuilt, including one that shows the old dramatic result and the honest world side by side. Thirteen pages, compiles clean, UK spelling, no banned punctuation.

## Part 3: Why it is better now

| before | after |
|---|---|
| key behavioural setting eight times the evidence | every parameter sourced or calibrated to a stated target |
| solver could quietly return a wrong answer | solver always finishes; failure mode removed |
| wealth distribution shaped by a numerical boundary | stable under every grid and boundary stress test |
| wealth facts far from data | hand-to-mouth and wealth inequality close to data, untargeted |
| headline tipping result fragile and wrong | tipping retracted, diagnosed, and rebuilt on a discrete participation margin that matches how the data actually look |
| policy result stated in aggregates | policy result now includes who wins and who loses, and the losers lose twice |
| paper claims ahead of the model | paper claims exactly what the model delivers |

The deeper improvement is strategic. The project's pitch to the wellbeing-empirics community is a calibratable structural model they can bring their data to. A model with a hidden indefensible setting would have died at first contact with a sceptical referee or a careful collaborator. This one invites the scrutiny, because the scrutiny is already in it: the repository carries the adversarial review of its own results, including the retraction.

## Part 4: Still open, honestly

The model is partial equilibrium, so prices do not respond; that is the planned second paper, with standard modern tools. The social-return strength has no clean data and is swept rather than estimated; the cohesion weight is the one remaining thesis-era number, and a design note now exists for estimating it from life-satisfaction panels, which is also the natural collaboration offer. Matching income inequality, wealth inequality, and the hand-to-mouth share all at once runs into a known frontier of one-asset models; we mapped the menu and documented the standard two-asset escape route. And the participation model exists as a validated prototype, not yet the full estimated version.

## Where everything lives

- Engine: SAGE_Bewley/src/SAGEBewley.jl (version 1.1; version 1.0, the thesis-faithful world, is preserved under the git tag v1.0).
- Technical review with grades: REVIEW.md.
- Paper: paper/sage_s.pdf, rebuilt figures in paper/figures, every number from SAGE_Bewley/scripts/paper_v11_figures.jl.
- Participation model: SAGE_Bewley/scripts/participation_model.jl with its validation battery.
- Income-process completion: SAGE_Bewley/scripts/proto_income_complete.jl.
- Project notes and the living status file: the Obsidian vault, Macro Research/SAGE.

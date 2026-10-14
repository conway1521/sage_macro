# SAGE roadmap (from 2026-10-14)

The single roadmap from version 1 onwards. It replaces the order of work in `PLAN_MASTER.md` and the model roadmap of 4 October in the vault. State and results stay in `V3_START.md`; what each dimension is stays in `DIMENSIONS_SPEC.md`.

## The goal

In the user's words (14 October): a modular model "that can be tested in data, or that can be ready to be tested in data, where each dimension is not a small one, even if one affects behaviour and one doesn't but affects wellbeing more significantly". The macroeconomics has to hold (hours, the MPC, general equilibrium), and A and E need appropriate bite.

## What "appropriate bite" means

A dimension has bite when switching it on changes something that matters, by an amount the data set, through at least one of two channels:

- **behaviour**: it changes what households do (save, search, work, take part), sized by a published estimate it is fitted to;
- **wellbeing**: it changes how well off households are beyond what they consume, valued by a published estimate of its effect on life satisfaction (the WELLBY library in `data/EVIDENCE_WELLBY.md`).

Each channel is then tested against data it was not fitted to. **The size is the data's, never ours**: if the published estimate is small, the dimension is small, and that is a finding. Off, every dimension still gives the model without it exactly.

The weights between dimensions are a separate, last step (phase 5): within a dimension, consequences are valued from published estimates; across dimensions, the user's plan is the Better Life Index users' own rankings by country.

## Where each dimension stands at version 1

| | behaviour | wellbeing | tested in data | verdict |
|---|---|---|---|---|
| G | savings, buffers, job loss and the state out of work; hours set by the job | consumption | hand-to-mouth, poverty, MPC properties, transitions | sound in partial equilibrium; MPC level low in Germany and Italy; transfers cost almost nothing in work |
| S | participation, with a social multiplier | belonging | participation by education (fitted), by type of place in France (out of sample, good) | good; the multiplier is a band (1.2 to 1.4) |
| A | hours for the 15 to 30% who control their time | none yet (dread parked) | the Swedish windfall response (good) | correct but nearly empty |
| E | places by composition, access to work, the state out of work, commuting, community | none yet | regional poverty in order; regional size short; buffers by type of place fail | distributes results well; little mechanism of its own |

## The target design, dimension by dimension

| | behaviour channel | wellbeing channel | fitted to | tested against |
|---|---|---|---|---|
| G | two assets (cash and housing) with the state out of work; a labour market in equilibrium (vacancies, wage setting), interest rate fixed | consumption | liquid and illiquid wealth (HFCS); labour-market flows | the MPC (HFCS), wealthy hand-to-mouth, tenure tables (section 93), consumption on job loss |
| S | as now | belonging, valued (for instance Meier and Stutzer 2008 on volunteering) | participation by education | participation by region and type of place; the multiplier narrowed with regional variation |
| A | **job-search effort** (agency over job loss) and hours for those with control | **dread of job loss and the cost of being out of work beyond income** (Winkelmann and Winkelmann 1998; Green 2011 on insecurity) | the response of unemployment duration to benefits (Schmieder and von Wachter 2016 for the estimates) | long-term unemployment by country; life satisfaction by activity status (EU-SILC); the macro against the micro response of job finding (Lalive, Landais and Zweimüller 2015) |
| E | **local labour markets** (job finding by place from the equilibrium of phase 3) and **tenure by place** (from phase 1), community, commuting | commuting time, exposure to pollution (Luechinger 2009), access to services | regional data, nothing fitted by place | poverty, joblessness and hand-to-mouth by region (HFCS: France 9, Germany 4, Italy 20), volunteering by place, life satisfaction by region |

Every source in this table is to be read at the source before it is used (the steel rule); none is used yet.

## Phases

Each phase runs the same way: a scope note with a stop rule, agreed before any code; the build, tested on GitHub (exact reduction when off, a brute-force check where there is a kink); calibration of the three countries; the standing test battery; a tag, the state document, the scorecard. Nothing new enters a phase while it is open; ideas go to the list for the next scope note.

### Phase 0. Version 1 frozen, in partial equilibrium (days)

The last runs read, the specification frozen, the grid solver run against the fast one (scorecard row N4), a model note of 10 to 15 pages for a first feedback round.
- *Good enough*: version 1 shown as an S model with places, its limits stated.
- *Too much*: polishing results that phase 1 will change.

### Phase 1. G: two assets with the state out of work (two to three weeks)

The illiquid asset is housing; owners and tenants appear; the MPC and the wealth distribution are fitted the standard way (Kaplan and Violante 2014). Repairs the top of the asset grid in the fast solver (section 100).
- *Good enough*: liquid and illiquid wealth on target in the three countries; the MPC within a quarter of the HFCS; the tenure gap in hand-to-mouth reproduced in sign and order.
- *Too much*: a housing market, house prices, mortgages beyond one borrowing limit.
- *Stop rule*: if the two assets cannot match liquid and illiquid wealth together in a country within the scope note's search, that country stays on one asset and the miss is stated.

### Phase 2. A with bite: search effort and the wellbeing of insecurity (two to three weeks)

A on: households choose how hard to search, at a cost fitted to the published response of unemployment duration to benefits; dread and the non-income cost of being out of work enter wellbeing at published values. A off: job finding as measured, no dread.
- *Good enough*: the duration response on its published value in each country (or a stated transfer); A's welfare effect of a benefit change reported beside G's.
- *Too much*: reservation wages, duration-dependent benefits beyond the first year.
- **Release**: version 2 in partial equilibrium, for a wider macro audience.

### Phase 3. G: the labour market in equilibrium (four to six weeks)

Job finding from vacancies and a matching function, wages set by bargaining, the government budget closed, the interest rate fixed (a member of a currency union). Benefits then cost jobs through wages as well as through search (Landais, Michaillat and Saez 2018).
- *Good enough*: steady-state equilibrium in the three countries on official vacancy and flow data; the macro response of job finding to benefits against the micro one (A).
- *Too much*: sticky prices, monetary policy, a determined interest rate (a later validation test).

### Phase 4. E with bite: places on that labour market (three to four weeks)

Each place its own labour market (job finding responds to local conditions and to policy), tenure and housing cost by place from phase 1, community (a source for Germany), commuting and pollution in wellbeing.
- *Good enough*: regional poverty, joblessness and hand-to-mouth in order and at least half the data's spread; the French failure by type of place repaired or explained by tenure.
- *Too much*: migration between places; local prices beyond housing.

### Phase 5. Transitions through everything, then welfare across dimensions (four to six weeks)

Paths for policies and shocks with every switch on, A included (sequence-space method of Auclert, Bardóczy, Rognlie and Straub 2021). Then the weights across dimensions from the Better Life Index users' rankings by country, and the welfare tables.
- *Good enough*: a recession and a benefit reform as paths in every configuration; welfare by dimension and by group.
- **Release**: version 3, ready for the three audiences.

## Releases and who sees them

| release | when | for |
|---|---|---|
| version 1, partial equilibrium | after phase 0 | WISE and beyond-GDP readers; one or two friendly macroeconomists for direction |
| version 2, partial equilibrium with two assets and A | after phase 2 | macroeconomists more widely |
| version 3, general equilibrium, E, paths, welfare | after phase 5 | all three audiences |

Rough total: four to five months of sessions, if each stop rule holds. Calibrations and tests run on GitHub.

## Open decisions for the user

1. The wellbeing channels of A and E (dread, the cost of being out of work, commuting, pollution) come in with their dimensions (phases 2 and 4), valued from published estimates; only the weights across dimensions wait for phase 5. This brings part of the parked wellbeing account forward.
2. Two assets (phase 1) before search effort (phase 2).
3. "Tested in data" means the official and survey data already in use (HFCS, EU-SILC, ESS, Eurostat regional tables) plus the published estimates each channel is fitted to.

## Not on this roadmap

A fourth country; migration between places; a determined interest rate; an independent second solver beyond the grid check of phase 0.

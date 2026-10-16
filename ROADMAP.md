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

## Where each dimension stands on `v5.3-base` (14 October)

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

**Revised by the user on 14 October**: version 1 stays one asset and partial equilibrium, and is completed first with S, A and E and their interactions working fairly well, in the way Kaplan and Violante (2014) made their case in partial equilibrium. Version 2 is two assets. General equilibrium follows. A and E are each their own utility, as S is, in the spirit of Lima de Miranda and Snower (2020): each a term with its own argument in the household's wellbeing, which changes choices where its argument depends on them and wellbeing only where it does not.

Each phase runs the same way: a scope note with a stop rule, agreed before any code; the build, tested on GitHub (exact reduction when off, a brute-force check where there is a kink); calibration of the three countries; the standing test battery; a tag, the state document, the scorecard. Nothing new enters a phase while it is open; ideas go to the list for the next scope note.

### Phase 0. Version 1's base frozen (days)

The specification of `v5.3-base` closed, the grid solver run against the fast one (scorecard row N4).

### Phase 1. Version 1 completed: A and E as utilities, with the interactions (four to six weeks)

- **A's utility**, agency and security: its argument is the household's exposure to a fall (the chance and depth of losing work or reaching the floor, given its buffer), so it enters choices (precautionary saving: dread in choices, built and tested on 9 October as a variant) and wellbeing; with it, job-search effort as agency over job loss, and hours for those with control (built).
- **E's utility**, place and environment: its argument is the place's environment (commuting time, built; exposure to air pollution; access to services), which households do not choose in version 1 (no moving), so it acts on wellbeing; E's behaviour stays in the place channels (composition, access to work, the state out of work, community).
- **Interactions** that the design gives without new parameters: A with E (insecurity differs by place because job loss does), S with E (community, built), A with S (built).
- **How strong each term is, without tuning**: where a term changes choices, its strength is fitted to a published behavioural estimate (for search effort, the response of unemployment duration to benefits; for dread, the evidence chosen in the scope note); where it changes wellbeing only, it is valued from published life-satisfaction estimates (the WELLBY library, `data/EVIDENCE_WELLBY.md`). The weights across dimensions stay the user's Better Life Index plan (phase 5).
- *Good enough*: each of S, A and E moves at least one outcome by its published size and passes one untargeted test; the interactions reported.
- *Too much*: migration between places; reservation wages; a full health or environment block.
- **Release: version 1**, one asset, partial equilibrium, with a model note: for macroeconomists to read the choices and where version 2 goes, for the wellbeing readers to analyse the dimensions.

### Phase 2. Version 2: a quarterly period and two assets, with the state out of work (four to six weeks)

**The quarterly period (decided by the user, 16 October)**, first and in stages, each checked before the next: (1) every rate converted to a quarter, as `probe_quarterly.jl` does, and the quarterly economy shown to keep the annual one's long-run facts; (2) the one solver change, a first year out of work lasting four quarters; (3) the recalibration. The probe of 15 October (`V3_START.md` section 103) showed the period to be a large part of the fall in consumption on job loss (0.07 to 0.09 over a quarter against 0.10 to 0.15 over a year, without the state out of work and before refitting) and the quarterly MPC in the range of the quarterly literature.

**Then the two assets**: the illiquid asset is housing; owners and tenants appear; the MPC and the wealth distribution fitted the standard way (Kaplan and Violante 2014, quarterly); the top of the asset grid repaired in the fast solver (section 100). E gains tenure by place.
- *Good enough*: on the quarterly period, liquid and illiquid wealth on target; the MPC within a quarter of the HFCS; the fall in consumption on job loss inside or near the literature's range; the tenure gap in hand-to-mouth in sign and order.
- *Too much*: a housing market, house prices.
- *Stop rule for the quarterly stage*: if the refitted quarterly economy cannot meet the annual base's targets in a country, version 2 keeps the annual period there and states it.
- **Release: version 2**, partial equilibrium.

### Phase 3. The labour market in equilibrium (four to six weeks)

Job finding from vacancies and matching, wages by bargaining, the budget closed, the interest rate fixed (a member of a currency union) (Landais, Michaillat and Saez 2018). E gains local labour markets.

### Phase 4. Transitions through everything, A included (four weeks)

Sequence-space method (Auclert, Bardóczy, Rognlie and Straub 2021).

### Phase 5. Welfare across dimensions

The weights from the Better Life Index users' rankings by country, mapped to the dimensions; the welfare tables. **Release: version 3**, ready for the three audiences.

## Releases and who sees them

| release | after | for |
|---|---|---|
| version 1: one asset, partial equilibrium, S, A, E with their utilities | phase 1 | macroeconomists (the choices, and where version 2 goes) and wellbeing readers (the dimensions) |
| version 2: quarterly, two assets, partial equilibrium | phase 2 | macroeconomists more widely |
| version 3: general equilibrium, paths, welfare | phase 5 | all three audiences |

Rough total: six to seven months of sessions, if each stop rule holds.

## Decided by the user (14 October)

1. A and E are their own utilities, as S is, part of the wellbeing function (Lima de Miranda and Snower).
2. Version 1 (one asset, partial equilibrium) is completed with S, A, E and the interactions before version 2 (two assets).
3. "Tested in data": the official and survey data in use (HFCS, EU-SILC, ESS, Eurostat regional tables) and the published estimates each term is fitted to.

## Not on this roadmap

A fourth country; migration between places; a determined interest rate; an independent second solver beyond the grid check of phase 0.

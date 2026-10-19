# Version 2: the build plan

The design is `paper/sage_v2_design.md` (revision 2, after two methods reviews). This file is the order of the build, from an inventory of the code (19 October 2026) that found about sixty places depending on version 1's three blocks of labour states (U, E, L), on "employed if and only if income is positive", or on the annual period. The state document stays `V3_START.md`.

**Rule for every stage**: version 1 reproduces exactly with the version 2 switch off (`v2 = false`), checked on GitHub before the stage is used. No new or changed solver code runs on the laptop first.

## Stage 0. Labels, with version 1 unchanged

Every labour state carries explicit labels, built by the chain: its type (`:E`, `:U`, `:L`, later `:N`), its duration in periods, whether it is entitled, and the latent productivity it shares with the other types. Every place that today uses block arithmetic (`nh`, `2nh`, `n ÷ 3`, offsets of `±nh`) or the test "employed if income is positive" reads the labels instead:

- the per-state vectors (search costs, the cost of being out of work, assistance in L, the time floor and belonging scale, the effort padding of `floor_effort`);
- dread's states and partners (`dread_params`);
- the search split in `egm_core.jl`, `reporting_core.jl` and `benchmark_search.jl` (towards work = the employed states by label);
- the consumption fall and protection measures of `agency_summary` (the partner state of an employed household by label, not by offset);
- reporting: `unemployment`, `rate_U`, `search_UL`, `search_cost_out`, `impose_unemployed_ratio`, the status splits, which count the unemployed by label (so that N, when it exists, is not counted as unemployed);
- the scripts that index blocks.

**Test**: G and G+A in three countries, and G+S+A household problems, give version 1's numbers to $10^{-10}$ (a regression harness, `test_v2_stage0.jl`, against values stored from version 1's tag).

## Stage 1a. The general chain, quarterly, with version 1's flows

A chain builder from a specification: E, the unemployed by quarter of duration (entitled and not), L beyond them, N. The transition matrix and the stationary masses are computed numerically, not in closed form, and the closed-form taxes (`ui_tax`, `assist_tax_of`) become sums over states of mass times public income. The search model becomes arrival rate times effort: the chance of work is $\lambda_d x$, the row of a searching state mixing its "found" and "not found" parts with weights $\lambda_d x$ and $1 - \lambda_d x$, in the solver, the stationary distribution, the welfare parts and the benchmark. The period: patience, return, the hand-to-mouth and windfall fractions (`/52`, `/12`, `/4` of annual income become quarterly equivalents), the calibration bounds, the transition horizons. The income process refitted to the lag-0, 1 and 2 autocovariances of annual averages of quarterly income, with job loss in the chain.

Version 1's flows at a quarterly period: $U_1$ to $U_4$ with the quarterly equivalent of $f$, then L with the quarterly equivalent of $f^L$; job loss keeping each cell's unemployment rate. **Test**: the quarterly economy keeps the annual one's exogenous aggregates (income moments, annual flows, the budget), and its endogenous outcomes are reported against version 1.

## Stage 1b. Flows fitted to the duration of unemployment

The duration bands (`lfsa_ugad`), the quarterly flows (`lfsi_long_q`), the stocks; N added; arrival rates by duration group and cost levels by cell fitted in the solved model, the split of L by a simulated panel. Places: the access and out-of-work channels rewritten for the new chain.

## Stage 1c. Benefits by quarter, entitlement, partner

The household-weighted TaxBEN profile by quarter to month 60 (partner kept), entitlement fixed at entry, the eight-quarter tunnels, the floor in every state.

## Stage 1d. Recalibration and tests

All configurations, the battery, the fall and its decomposition reported after each of 1a to 1c. Then dread over several outcomes (design section 5), participation when out of work (section 6) and the decomposition of the benefit response (section 7). Tag.

## Step 2. Two assets

As in the design, section 4, on the stage 1 model.

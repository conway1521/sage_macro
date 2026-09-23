# Runbook: running the country calibrations on a second machine

The first machine (Apple M4 Pro, 24 GB) cannot run these jobs alongside daily
use, and at the doubled asset grid it ran out of memory and restarted. This
branch carries everything needed to run the whole job elsewhere from a fresh
clone. Nothing large travels through GitHub: the response-family caches
(about 1 GB) are rebuilt on the new machine.

## 1. Set up (once)

1. Rosetta, if the machine is Apple silicon and it is not installed yet:
   `softwareupdate --install-rosetta` (it asks you to accept Apple's licence).
2. Julia **1.7.2, the Intel (x86_64) build**, which is what the first machine
   runs and what the reference numbers were produced with. From the Julia
   website's older releases page, download the macOS x86 1.7.2 disk image and
   put `julia` on the PATH, so that `julia --version` prints 1.7.2. A different
   version or the native Apple silicon build can shift numbers in the last
   digits, and the run checks for that before doing anything (step 0 below).
3. Clone and switch to the branch:
   ```
   git clone https://github.com/conway1521/sage_macro.git
   cd sage_macro
   git checkout countries-modular
   ```

## 2. Run

```
bash SAGE_Bewley/scripts/run_all.sh
```

That is the whole job. It installs the exact package versions pinned in
`SAGE_Bewley/Manifest.toml`, then:

**If the environment does not install.** The full project also carries Plots,
GR, IJulia and Pluto for the notebook and the lecture site, and those are the
parts most likely to fail to build on a fresh machine. The run does not need
any of them. It therefore falls back on its own to
`SAGE_Bewley/scripts/run_env`, which holds QuantEcon alone at the identical
version, and then proves the model code loads before going any further. If you
want to skip the full project from the start:

```
cd SAGE_Bewley && julia --project=scripts/run_env -e 'using Pkg; Pkg.instantiate()'
```

Whatever environment the run ends up using, the worker processes inherit it.

| step | what | rough time |
|---|---|---|
| memory probe | measures one worker's memory, picks the worker count for a 16 GB budget | 5 min |
| France, Germany, the US, Italy, G+S+A | effort and spread, families, technology scan at four unemployed ratios, calibrated economy, the four economies at those parameters | 1.5 to 3 h each |
| each country's G+A, G and G+S on their own | every configuration calibrated to its own targets | 0.2, 0.2 and 1 to 2 h each |
| modularity suite | every reduction, the four economies at France's new footing, seven convergence rows | 2 to 4 h |
| doubled asset grid row | the eighth convergence row, on fewer workers | several hours |

The run keeps the machine awake while it works. A memory guard stops Julia if
swap grows 4 GB over its lowest level in the session and the run then ends with exit 5, rather than letting the
machine restart. Each step is retried once; a second crash ends the run.
Families are cached on disk, so running `run_all.sh` again after any stop
resumes from the builds already finished.

**Step 0, the reproduction check.** Every calibration begins by re-solving
France's no-cohesion economy and comparing it with the reference numbers to
1e-6. If this machine's Julia does not reproduce them, the run stops with exit
3 and nothing is calibrated. The fix is the exact Julia build above.

## 3. Watch

- `SAGE_Bewley/scripts/run_session.log`: one line per step, with times and exit codes.
- `bash SAGE_Bewley/scripts/run_session.sh status`: what is done and what is left.
- `SAGE_Bewley/scripts/calibrate_country_<CODE>.txt` and `..._<CODE>_<CFG>.txt`: each calibration.
- `SAGE_Bewley/scripts/test_modular.txt` and `conv_na400.txt`: the suite.

To stop: Ctrl-C in the terminal running it. Running it again resumes: finished steps are skipped, and each country's fitted effort scale and discount spread are kept in `scripts/checkpoints/`.

**On the main laptop, in pieces.** `bash SAGE_Bewley/scripts/run_session.sh` runs the same steps for 2.5 hours (`SESSION_HOURS=2` for another length) on 10 workers at low priority, then stops by itself. It leaves out the doubled asset grid row, which needs more memory than the laptop can spare alongside daily use. The two machines share progress through git: a step whose calibration file is on the branch is skipped on either.

## 4. Bring the results back

```
git add SAGE_Bewley/scripts/calibration_country_*.txt SAGE_Bewley/scripts/calibrate_country_*.txt \
        SAGE_Bewley/scripts/test_modular.txt SAGE_Bewley/scripts/conv_na400.txt SAGE_Bewley/scripts/run_session.log
git commit -m "country calibrations from the second machine"
git push
```

Then pull the branch on the first machine.

## What the run does, and why

**The goal.** A plain Bewley economy (G) with a switch for social cohesion (S),
a switch for agency (A), and both, such that switching a dimension off gives
back exactly the economy without it. The suite checks that at fixed
parameters. Separately, each configuration is calibrated to its own targets,
so every economy also fits the data: G and G+A to effort and hand-to-mouth,
G+S and G+S+A also to participation by education. Switching cohesion on at
fixed parameters moves hand-to-mouth (France: 0.262 to 0.308), so the two
views differ and both are reported.

**Decisions already taken** (do not revisit without the author):
- Every country, France included, is calibrated to EU-SILC 2015 formal
  volunteering by education (BLS 2015 for the US) and an OECD 2023 labour
  market. France's earlier INSEE-target footing stays in the repository as a
  record (`calibration_ratio.txt`); the suite switches to the EU-SILC France
  footing once `calibration_country_FR.txt` exists.
- The unemployed participate at a national ratio of the employed rate (FR
  0.486, DE 0.574, IT 0.937, US 0.857). No common source exists: Eurostat
  publishes no volunteering by activity status. Each G+S+A scan is reported at
  all four ratios.
- Income process and interest rate are France's for every country; the
  discount spread carries hand-to-mouth differences. Effort cost and the
  benefit reference are scaled by each country's paid share of committed time
  relative to France (HETUS 2010, ATUS 2025).
- Stopping rules are in the scripts and are not overridden: a configuration
  whose best fit exceeds 0.035, or has no stable equilibrium, is recorded as
  not calibrated.

**Open items the run does not settle:** agency and belonging by education and
the hand-to-mouth targets are carried over from the old engine's country table
without re-checking; the German ratio is not yet checked in the Freiwilligensurvey
report itself; the social multiplier is not identified (France 8.8 to 21);
policy experiments and the environment dimension are not part of this run.

Sources for every data value: `data/country_labour_participation_sources.md`.
The reasoning behind the unemployed participation rule: `STAGE7.md`, the
quarantine section. The modular design and its checks: `MODULAR.md`.

# Infrastructure: where things live and how to run them

Set up 2026-09-27. One page for where the code, Julia, data and compute are, so a collaborator (or a second machine) can reproduce everything.

## Repository

github.com/conway1521/sage_macro (public). Work happens on `main` (decided 2026-09-28; `countries-modular` is kept as history).

| folder | what |
|---|---|
| `SAGE_Bewley/src/` | the solver (SAGEBewley.jl) |
| `SAGE_Bewley/scripts/` | the modular stack, calibration, suites, probes, policy tests |
| `data/` | the country table and its sources note, derived tables, manifest of raw inputs |
| `data/place/` | the place (E) feasibility scripts and derived tables |
| `.github/workflows/` | CI and cloud calibration |
| `scripts/` | repository tools (data release) |

## Julia

- **Now:** Julia 1.7.2, the Intel build from Homebrew (`/usr/local/bin/julia`), running under Rosetta on an Apple-silicon Mac. All reference numbers were computed with it, and CI pins 1.7.2 to match.
- **Environments:**
  - `SAGE_Bewley/Project.toml`: the full environment, with notebooks and plots.
  - `SAGE_Bewley/scripts/run_env/`: minimal, QuantEcon only. Everything that runs models uses it: `julia --project=SAGE_Bewley/scripts/run_env ...`.
- **Planned upgrade**, after the audit (see `PLAN_AGENCY_V2.md`):
  1. Install `juliaup` from julialang.org.
  2. Install the long-term-support Julia natively for arm64.
  3. Re-instantiate `run_env`.
  4. Run `probe_reduction.jl` and `test_modular.jl` and compare with the stored reference outputs.
  5. Switch the CI version at the same time.

  The native build should be substantially faster than emulation. Do not upgrade in the middle of a calibration run.

## Data: four tiers

1. **Committed to git (small, derived or hand-entered with a citation):**
   - `data/country_labour_participation.csv` and `_sources.md`;
   - `data/place/*.csv`;
   - `data/taxben_nrr_2023_single_aw100.csv`.
2. **Raw inputs, in a GitHub release.** Files downloaded from official sources (SCF extracts, INSEE facilities and density grid, the associations register, La Poste postcodes, ISTAT tables) are not in git. `data/MANIFEST.csv` lists each one with its SHA-256, size, source URL, licence and release tag.
   - Restore on any machine: `bash data/fetch_data.sh` (or `bash data/fetch_data.sh scf` for a subset). It checks every checksum and unpacks the zips.
   - Add or refresh a file: put it in place, add it to `data/make_manifest.py`, then run `python3 data/make_manifest.py data-YYYY.MM` and `bash scripts/data_release.sh data-YYYY.MM`.
   - The release is created as a **draft**, visible only to you. Publish it from the Releases page once checked.
   - Series fetched live from APIs (Eurostat, OECD) are not stored. The scripts that fetch them are the record.
3. **Caches (rebuildable, never shared):**
   - `SAGE_Bewley/scripts/cache_families/`: household families, about 4 GB, keyed by the solver digest;
   - `SAGE_Bewley/scripts/checkpoints/`.

   Both are git-ignored. CI keeps its own copy with the Actions cache.
4. **Confidential: HFCS microdata.**
   - Only in `~/hfcs_secure`, outside iCloud-synced folders.
   - Never in the repository, the manifest or a release. `data_release.sh` refuses a manifest that mentions HFCS, and `.gitignore` excludes `data/hfcs/`.
   - Only aggregate statistics computed from them are committed.

## Compute

| where | how | when |
|---|---|---|
| Laptop | `bash SAGE_Bewley/scripts/run_session.sh` (piecemeal, 2 to 3 hours, caffeinated, memory guard) | Only with an explicit go-ahead each time; the doubled-grid convergence row never runs on the laptop |
| GitHub Actions, CI | `.github/workflows/ci.yml` runs the reduction probe on every push (about a minute) | Automatic |
| GitHub Actions, calibration | Actions tab, "calibrate", "Run workflow": choose countries and configurations. One job per pair, in parallel, up to six hours each on 4 cores, three workers. Results come back as artifacts (calibration file and log) to download and commit | Free for a public repository |
| French national HPC (GENCI, IDRIS/CINES/TGCC) | A dynamic-access request, with the supervisor named | For many countries or the doubled grid; to be requested by the user |

## After the audit

The audit (PLAN_AGENCY_V2.md, Phase 1) adds `data/build_country_table.py`, which rebuilds the country table from the sources. Its downloads will be added to the manifest and the next data release.

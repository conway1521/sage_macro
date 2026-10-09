#!/usr/bin/env python3
"""
hfcs_moments.py: the moments the SAGE model needs from the ECB Household
Finance and Consumption Survey (HFCS), for France, Germany and Italy.

Written BEFORE the data arrived, from the public ECB documentation only (see
HFCS_READINESS.md for every source). Anything that could not be confirmed in an
official document is marked "TO CONFIRM" in VARS, FILE_PATTERNS or a comment.

Usage
    HFCS_DIR=~/hfcs_secure python3 hfcs_moments.py OUTDIR
    python3 hfcs_moments.py OUTDIR --waves 2017 2021 --nrep 500
    python3 hfcs_moments.py --selftest          (synthetic data, no HFCS needed)

Requires Python 3 with pandas and numpy only.

CONFIDENTIALITY
    The HFCS microdata are confidential (ECB confidentiality commitment, section
    9 of the research dataset request form). This script
      - reads the microdata only from HFCS_DIR (default ~/hfcs_secure);
      - never writes household-level data: no cache, no pickle, no copy;
      - writes only aggregate tables, through one guarded function
        (write_aggregate_table), to the output directory given as argument;
      - suppresses every cell based on fewer than MIN_CELL unweighted households.
"""

import argparse
import os
import re
import sys
import tempfile

import numpy as np
import pandas as pd

# =============================================================================
# 1. CONFIGURATION: everything that may need a one-line fix on arrival
# =============================================================================

HFCS_DIR = os.path.expanduser(os.environ.get("HFCS_DIR", "~/hfcs_secure"))

COUNTRIES = ["FR", "DE", "IT"]
WAVES = ["2010", "2014", "2017", "2021", "2023"]

# Minimum number of unweighted households behind any published cell. The public
# ECB access form and confidentiality commitment state no numeric threshold, so
# 30 is a prudential default, not an ECB rule. TO CONFIRM ON ARRIVAL against the
# conditions sent with the data.
MIN_CELL = 30

# Number of bootstrap replicate weights used for standard errors. The HFCS ships
# 1,000 (WR0001 to WR1000); the methodological report says the first 200 or 500
# are enough for faster, slightly less stable estimates.
DEFAULT_NREP = 200

# ---- File discovery ---------------------------------------------------------
# TO CONFIRM ON ARRIVAL: the public documentation names the variables but not
# the file names. The expected layout (from the catalogue structure and the
# Stata example in the 2010 methodological report, Table 7.3) is one folder per
# wave holding
#   D  derived variables (household level), H  household core variables,
#   P  person core variables, HN / PN  non-core variables, W  replicate weights,
# either one file per implicate (D1 ... D5) or one stacked file with IM0100.
# A wave folder is any sub-folder of HFCS_DIR whose name contains one of the
# tokens below (case-insensitive). Files are searched recursively inside it.
WAVE_DIR_TOKENS = {
    "2010": ["2010", "wave1", "wave_1", "w1"],
    "2014": ["2014", "wave2", "wave_2", "w2"],
    "2017": ["2017", "wave3", "wave_3", "w3"],
    "2021": ["2021", "wave4", "wave_4", "w4"],
    "2023": ["2023", "wave5", "wave_5", "w5"],
}
# Regular expressions on the lower-case file name. Group 1, when present, is the
# implicate number.
# AS DELIVERED (October 2026): one folder per release and format,
# HFCS_UDB_<wave number>_<version>_<STATA|SAS|ASCII>, wave numbers 1 to 5 for
# 2010, 2014, 2017, 2021, 2023. The Stata folders are used. When such folders
# exist they take precedence over the name tokens above (which the self-test
# and any other layout still use).
UDB_DIR_PATTERN = r"^hfcs_udb_([1-5])_\d+_stata$"
UDB_WAVE = {"1": "2010", "2": "2014", "3": "2017", "4": "2021", "5": "2023"}
# Disposable income simulated by the ECB with EUROMOD on the HFCS (waves 2014 to
# 2023): files di1 ... di5 in <HFCS_DIR>/<year>/Stata, keyed by country,
# household and implicate, with DDI2000 (disposable income), DTI2000 (taxes on
# income), DTW2000 (taxes on wealth) and DSC2000 (social contributions).
DI_DIR = os.path.join("{year}", "Stata")
DI_PATTERN = r"^di([1-5])\.dta$"
FILE_PATTERNS = {
    "D": r"^d([1-5])?\.(csv|dta)$",
    "H": r"^h([1-5])?\.(csv|dta)$",
    "HN": r"^hn([1-5])?\.(csv|dta)$",
    "W": r"^w\.(csv|dta)$",
}
FORMAT_PREFERENCE = ["dta", "csv"]   # if both formats are present
CSV_SEP = ","                        # TO CONFIRM ON ARRIVAL

# ---- Variable map -----------------------------------------------------------
# key: (list of column names tried in order, file hint, status)
# Names are matched case-insensitively (the Stata files use lower case in the
# ECB's own example). "confirmed" means the name and definition were read in the
# official catalogue of at least one wave (URLs in HFCS_READINESS.md, section 2).
# Whether each variable is FILLED for FR, DE, IT in each wave is reported by the
# coverage table this script writes.
C = "confirmed"
T = "TO CONFIRM"
VARS = {
    # identifiers, weights
    "country":      (["SA0100"], "D/H", C),
    "hid":          (["SA0010"], "D/H", C),
    "implicate":    (["IM0100"], "D/H", C),
    "weight":       (["HW0010"], "D/H", C),   # which file carries it: TO CONFIRM
    # liquid assets and liquid debt
    "sight":        (["DA21011", "HD1110"], "D", C),   # sight (current) accounts
    "saving":       (["DA21012", "HD1210"], "D", C),   # saving accounts, time deposits, CDs
    "funds":        (["DA2102"], "D", C),               # mutual funds
    "bonds":        (["DA2103"], "D", C),
    "shares":       (["DA2105"], "D", C),               # publicly traded shares
    "overdraft":    (["DL1210", "HC0220"], "D", C),     # credit line / overdraft balance
    "ccdebt":       (["DL1220", "HC0320"], "D", C),     # credit card balance charged interest
    "dnnla":        (["DNNLA"], "D", C),                # ECB's own net liquid assets
    # illiquid wealth
    "hmr":          (["DA1110"], "D", C),               # household main residence
    "realestate":   (["DA1400"], "D", C),               # HMR + other real estate
    "mortgage":     (["DL1100"], "D", C),               # all mortgage debt
    "pension_life": (["DA2109"], "D", C),               # voluntary pension + whole life insurance
    "business":     (["DA1200"], "D", C),               # business wealth
    "networth":     (["DN3001"], "D", C),
    "housing_status": (["DHHST"], "D", C),              # 1 owner outright, 2 with mortgage, 3 tenant
    # income (annual, gross; France: gross of taxes, net of social contributions)
    "inc_gross":    (["DI2000"], "D", C),
    "inc_employee": (["DI1100"], "D", C),
    "inc_self":     (["DI1200"], "D", C),
    "inc_pubpens":  (["DI1510"], "D", C),
    "inc_unemp":    (["DI1610"], "D", C),
    "inc_othsoc":   (["DI1620"], "D", C),
    "inc_privtr":   (["DI1700"], "D", C),
    # taxes and social contributions: NON-CORE, listed for Italy (and Finland) only
    "taxes":        (["HNG0710"], "HN", T),
    # EUROMOD-simulated disposable income and its components (di files, 2014 on)
    "inc_disp":     (["DDI2000"], "DI", C),
    "tax_income":   (["DTI2000"], "DI", C),
    "tax_wealth":   (["DTW2000"], "DI", C),
    "soc_contrib":  (["DSC2000"], "DI", C),
    # household composition and groups
    "hsize":        (["DH0001"], "D", C),
    "age_rp":       (["DHAGEH1"], "D", C),
    "age_rp_b":     (["DHAGEH1B"], "D", C),             # bracket lower bound, where age is withheld
    "edu_rp":       (["DHEDUH1"], "D", C),              # 1, 2, 3 below tertiary; 5 tertiary
    "lab_rp":       (["DHEMPH1"], "D", C),              # 1 employee 2 self-employed 3 unemployed 4 retired 5 other
    "region":       (["DHREGION"], "D", C),             # waves 2017, 2021, 2023 only
    "degurba":      (["DHDEGURBA"], "D", C),            # waves 2021, 2023 only
    # self-reported MPC out of a lottery win of one month of income (waves 2017+)
    # Drescher, Fessler and Lindner (2020) print the name as "hiz0400a".
    "mpc":          (["DOLOTTGOOD", "HIZ040A", "HIZ0400A"], "D/H", C),
    # consumption (monthly amounts in the H file)
    "food_home":    (["HI0100"], "H", C),
    "food_out":     (["HI0200"], "H", C),
    "cons_goods":   (["HI0220"], "H", C),               # from wave 2014
    # credit constraints
    "cred_constr":  (["DOCREDITC"], "D", C),
    "cred_applied": (["DOCREDITAPPL"], "D", C),
    "cred_refused": (["DOCREDITREFUSAL"], "D", C),
    "cred_discour": (["DOCREDITNOTAPPL"], "D", C),
    "has_cline":    (["DLCL"], "D", C),
    "has_ccard":    (["DLCC"], "D", C),
    # portfolio adjustment proxies
    "hmr_year":     (["HB0700"], "H", C),               # year the main residence was acquired
    "refinanced":   (["DREFINANI"], "D", C),
}
REQUIRED = ["country", "hid", "implicate", "weight", "networth", "inc_gross", "hsize"]
STRING_VARS = ["country", "hid", "region"]
REPLICATE_PREFIX = "WR"   # WR0001 ... WR1000

# ---- Definitions ------------------------------------------------------------
# Kaplan, Violante and Weidner (2014), BPEA, section III.A and IV.A.
CASH_FACTOR = 1.055              # footnote 9: cash is about 5.5% of transaction accounts
KVW_PAY_PERIODS = 26             # biweekly pay in the benchmark, in every country
KVW_CREDIT_LIMIT_MONTHS = 1.0    # common credit limit of one month of income
KVW_AGE_MIN, KVW_AGE_MAX = 22, 79
# KVW say "regular public transfers". Whether public pensions are inside is not
# stated for the HFCS. TO CONFIRM against their replication files; the switch
# makes the alternative a one-line change.
KVW_INCOME_INCLUDES_PUBLIC_PENSIONS = True
# KVW list only sight accounts as liquid in the HFCS and put "certificates of
# deposit and saving bonds" in illiquid wealth; their Table 2 medians fit sight
# accounts alone. So HFCS saving accounts (which pool Livret-type accounts, time
# deposits and CDs) go to ILLIQUID in the KVW replication. TO CONFIRM.
KVW_SAVING_ACCOUNTS_ILLIQUID = True
MODEL_WEEKS = 52                 # model: hand-to-mouth if liquid <= one week of income
POVERTY_LINES = (0.5, 0.6)       # share of median equivalised income
ASSET_POVERTY_MONTHS = 3         # Balestra and Tonkin (2018): a quarter of the annual line

# First year of fieldwork, to date "recent" purchases of the main residence
# (methodological reports, tables of fieldwork periods).
FIELDWORK_YEAR = {
    ("DE", "2010"): 2010, ("FR", "2010"): 2009, ("IT", "2010"): 2011,
    ("DE", "2014"): 2014, ("FR", "2014"): 2014, ("IT", "2014"): 2015,
    ("DE", "2017"): 2017, ("FR", "2017"): 2017, ("IT", "2017"): 2017,
    ("DE", "2021"): 2021, ("FR", "2021"): 2020, ("IT", "2021"): 2021,
    ("DE", "2023"): 2023, ("FR", "2023"): 2023, ("IT", "2023"): 2023,
}

# Italy: 20 regioni grouped into three macro-areas (my grouping, ISTAT
# ripartizioni; DHREGION codes from the catalogue).
IT_MACRO = {**{f"IT{i}": "IT North" for i in (1, 2, 3, 4, 5, 6, 7, 8)},
            **{f"IT{i}": "IT Centre" for i in (9, 10, 11, 12)},
            **{f"IT{i}": "IT South and Islands" for i in range(13, 21)}}

# Published numbers the output is compared with (benchmarks.csv).
# (moment, group_var, group, country, wave, published value, source)
BENCHMARKS = [
    ("htm_kvw_poor", "all", "all", "FR", "2010", 0.032, "KVW 2014 Table 5 baseline"),
    ("htm_kvw_poor", "all", "all", "DE", "2010", 0.074, "KVW 2014 Table 5 baseline"),
    ("htm_kvw_poor", "all", "all", "IT", "2010", 0.083, "KVW 2014 Table 5 baseline"),
    ("htm_kvw_wealthy", "all", "all", "FR", "2010", 0.173, "KVW 2014 Table 5 baseline"),
    ("htm_kvw_wealthy", "all", "all", "DE", "2010", 0.248, "KVW 2014 Table 5 baseline"),
    ("htm_kvw_wealthy", "all", "all", "IT", "2010", 0.155, "KVW 2014 Table 5 baseline"),
    ("htm_kvw_weekly_poor", "all", "all", "FR", "2010", 0.021, "KVW 2014 Table 5 weekly"),
    ("htm_kvw_weekly_poor", "all", "all", "DE", "2010", 0.058, "KVW 2014 Table 5 weekly"),
    ("htm_kvw_weekly_poor", "all", "all", "IT", "2010", 0.080, "KVW 2014 Table 5 weekly"),
    ("htm_kvw_weekly_wealthy", "all", "all", "FR", "2010", 0.087, "KVW 2014 Table 5 weekly"),
    ("htm_kvw_weekly_wealthy", "all", "all", "DE", "2010", 0.161, "KVW 2014 Table 5 weekly"),
    ("htm_kvw_weekly_wealthy", "all", "all", "IT", "2010", 0.142, "KVW 2014 Table 5 weekly"),
    ("htm_kvw_monthly_poor", "all", "all", "FR", "2010", 0.048, "KVW 2014 Table 5 monthly"),
    ("htm_kvw_monthly_poor", "all", "all", "DE", "2010", 0.086, "KVW 2014 Table 5 monthly"),
    ("htm_kvw_monthly_poor", "all", "all", "IT", "2010", 0.091, "KVW 2014 Table 5 monthly"),
    ("htm_kvw_monthly_wealthy", "all", "all", "FR", "2010", 0.354, "KVW 2014 Table 5 monthly"),
    ("htm_kvw_monthly_wealthy", "all", "all", "DE", "2010", 0.370, "KVW 2014 Table 5 monthly"),
    ("htm_kvw_monthly_wealthy", "all", "all", "IT", "2010", 0.188, "KVW 2014 Table 5 monthly"),
    ("kvw_sample_median_liquid", "all", "all", "FR", "2010", 1453.0, "KVW 2014 Table 2 net liquid wealth"),
    ("kvw_sample_median_liquid", "all", "all", "DE", "2010", 1319.0, "KVW 2014 Table 2 net liquid wealth"),
    ("kvw_sample_median_liquid", "all", "all", "IT", "2010", 5226.0, "KVW 2014 Table 2 net liquid wealth"),
    ("kvw_sample_median_illiquid", "all", "all", "FR", "2010", 104214.0, "KVW 2014 Table 2 net illiquid wealth"),
    ("kvw_sample_median_illiquid", "all", "all", "DE", "2010", 39306.0, "KVW 2014 Table 2 net illiquid wealth"),
    ("kvw_sample_median_illiquid", "all", "all", "IT", "2010", 148524.0, "KVW 2014 Table 2 net illiquid wealth"),
    ("networth_to_income_ratio_of_medians", "all", "all", "FR", "2021", 4.02, "HFCS 2021 tables A1 / I1 (data/manual_inputs.csv)"),
    ("networth_to_income_ratio_of_medians", "all", "all", "DE", "2021", 2.38, "HFCS 2021 tables A1 / I1 (data/manual_inputs.csv)"),
    ("networth_to_income_ratio_of_medians", "all", "all", "IT", "2021", 5.51, "HFCS 2021 tables A1 / I1 (data/manual_inputs.csv)"),
    ("mpc_mean", "all", "all", "DE", "2017", 0.513, "Drescher, Fessler and Lindner 2020 Table 2"),
    ("mpc_mean", "all", "all", "FR", "2017", 0.418, "Drescher, Fessler and Lindner 2020 Table 2"),
    ("mpc_mean", "all", "all", "IT", "2017", 0.481, "Drescher, Fessler and Lindner 2020 Table 2"),
    ("asset_poor_oecd_persons", "all", "all", "FR", "2014", 0.405, "Balestra and Tonkin 2018 Table 6.1 (disposable income line)"),
    ("asset_poor_oecd_persons", "all", "all", "DE", "2014", 0.424, "Balestra and Tonkin 2018 Table 6.1 (disposable income line)"),
    ("asset_poor_oecd_persons", "all", "all", "IT", "2014", 0.387, "Balestra and Tonkin 2018 Table 6.1 (disposable income line)"),
    ("hardship_oecd_persons", "all", "all", "FR", "2014", 0.084, "Balestra and Tonkin 2018 Table 6.1 (disposable income line)"),
    ("hardship_oecd_persons", "all", "all", "DE", "2014", 0.114, "Balestra and Tonkin 2018 Table 6.1 (disposable income line)"),
    ("hardship_oecd_persons", "all", "all", "IT", "2014", 0.118, "Balestra and Tonkin 2018 Table 6.1 (disposable income line)"),
]

CONFIDENTIALITY_NOTICE = """
==============================================================================
 CONFIDENTIALITY NOTICE
 The HFCS microdata are confidential and proprietary to the ECB. They must not
 be duplicated, transferred or disclosed. This script reads them from
   {hfcs_dir}
 and writes ONLY aggregate tables, with cells under {min_cell} unweighted
 households suppressed. Keep the microdata in that directory, on an encrypted
 password-protected drive, outside any cloud-synchronised or version-controlled
 folder. Cite the source as 'Eurosystem Household Finance and Consumption
 Survey' and send a copy of any resulting paper to hfcs.access@ecb.europa.eu.
==============================================================================
"""

# =============================================================================
# 2. FILE DISCOVERY AND LOADING
# =============================================================================


def find_wave_dirs(hfcs_dir):
    """Map each wave label to its folder inside hfcs_dir (if present)."""
    found = {}
    if not os.path.isdir(hfcs_dir):
        return found
    for name in sorted(os.listdir(hfcs_dir)):
        m = re.match(UDB_DIR_PATTERN, name.lower())
        if m and os.path.isdir(os.path.join(hfcs_dir, name)):
            found[UDB_WAVE[m.group(1)]] = os.path.join(hfcs_dir, name)
    if found:
        return found
    for name in sorted(os.listdir(hfcs_dir)):
        path = os.path.join(hfcs_dir, name)
        if not os.path.isdir(path):
            continue
        low = name.lower()
        for wave, tokens in WAVE_DIR_TOKENS.items():
            if any(tok in low for tok in tokens) and wave not in found:
                found[wave] = path
    return found


def find_files(wave_dir):
    """Return {file type: [(implicate or None, path), ...]} for one wave folder."""
    hits = {k: {} for k in FILE_PATTERNS}
    for root, _dirs, files in os.walk(wave_dir):
        for fname in files:
            low = fname.lower()
            for ftype, pattern in FILE_PATTERNS.items():
                m = re.match(pattern, low)
                if not m:
                    continue
                groups = m.groups()
                ext = groups[-1]
                imp = int(groups[0]) if len(groups) == 2 and groups[0] else None
                hits[ftype].setdefault(ext, []).append((imp, os.path.join(root, fname)))
    out = {}
    for ftype, by_ext in hits.items():
        for ext in FORMAT_PREFERENCE:
            if ext in by_ext:
                out[ftype] = sorted(by_ext[ext], key=lambda t: (t[0] or 0, t[1]))
                break
    return out


def file_columns(path):
    """Column names of a csv or Stata file, without loading the data."""
    if path.lower().endswith(".dta"):
        # the reader's attribute for the column names differs across pandas versions
        # (varlist up to 1.x, private from 2.x); reading one row works in all of them
        with pd.read_stata(path, iterator=True) as reader:
            names = getattr(reader, "varlist", None)
            if names is None:
                names = reader.read(1).columns
            return list(names)
    return list(pd.read_csv(path, sep=CSV_SEP, nrows=0).columns)


def read_file(path, wanted_upper, countries, prefix=None, max_prefix=0):
    """
    Read from one file only the columns whose upper-case name is in
    wanted_upper (plus up to max_prefix columns starting with prefix), keep the
    rows of the requested countries, and return the frame with upper-case names.
    """
    cols = file_columns(path)
    keep = [c for c in cols if c.upper() in wanted_upper]
    if prefix:
        reps = sorted([c for c in cols if re.match(rf"^{prefix}\d+$", c.upper())], key=str.upper)
        keep += reps[:max_prefix]
    ccol = next((c for c in cols if c.upper() == VARS["country"][0][0]), None)
    if ccol is None:
        raise ValueError(f"{path}: no country column {VARS['country'][0][0]}")
    if path.lower().endswith(".dta"):
        df = pd.read_stata(path, columns=keep, convert_categoricals=False)
        df = df[df[ccol].astype(str).str.strip().str.upper().isin(countries)]
    else:
        parts = []
        for chunk in pd.read_csv(path, sep=CSV_SEP, usecols=keep, dtype=str, chunksize=50000):
            parts.append(chunk[chunk[ccol].str.strip().str.upper().isin(countries)])
        df = pd.concat(parts, ignore_index=True) if parts else pd.DataFrame(columns=keep)
    df.columns = [c.upper() for c in df.columns]
    return df


def wanted_columns():
    """All column names (upper case) the script may use, from VARS."""
    names = set()
    for aliases, _f, _s in VARS.values():
        names.update(a.upper() for a in aliases)
    return names


def load_wave(wave_dir, countries, nrep, log, di_dir=None):
    """
    Load one wave: a household-by-implicate frame with every available variable
    from the D, H and HN files, and a household-level frame of replicate weights
    (None if there is no W file).
    """
    files = find_files(wave_dir)
    if "D" not in files and "H" not in files:
        raise FileNotFoundError(f"no D or H file found under {wave_dir}; check FILE_PATTERNS")
    wanted = wanted_columns()
    k_c, k_h, k_i = VARS["country"][0][0], VARS["hid"][0][0], VARS["implicate"][0][0]
    merged = None
    for ftype in ("D", "H", "HN"):
        if ftype not in files:
            log(f"  no {ftype} file found (patterns: {FILE_PATTERNS[ftype]})")
            continue
        parts = []
        for imp, path in files[ftype]:
            part = read_file(path, wanted, countries)
            if k_i not in part.columns:
                if imp is None:
                    raise ValueError(f"{path}: no {k_i} column and no implicate number in the file name")
                part[k_i] = imp
            parts.append(part)
        frame = pd.concat(parts, ignore_index=True)
        frame[k_c] = frame[k_c].astype(str).str.strip().str.upper()
        frame[k_h] = frame[k_h].astype(str).str.strip().str.replace(r"\.0$", "", regex=True)
        frame[k_i] = pd.to_numeric(frame[k_i], errors="coerce").astype(int)
        log(f"  {ftype}: {len(files[ftype])} file(s), {len(frame)} rows, {frame.shape[1]} columns used")
        if merged is None:
            merged = frame
        else:
            new = [c for c in frame.columns if c not in merged.columns]
            merged = merged.merge(frame[[k_c, k_h, k_i] + new], on=[k_c, k_h, k_i], how="left")
    # disposable income (EUROMOD on the HFCS), where the wave has it
    if di_dir is not None and os.path.isdir(di_dir):
        parts = []
        for fname in sorted(os.listdir(di_dir)):
            m = re.match(DI_PATTERN, fname.lower())
            if not m:
                continue
            part = read_file(os.path.join(di_dir, fname), wanted, countries)
            if k_i not in part.columns:
                part[k_i] = int(m.group(1))
            parts.append(part)
        if parts:
            frame = pd.concat(parts, ignore_index=True)
            frame[k_c] = frame[k_c].astype(str).str.strip().str.upper()
            frame[k_h] = frame[k_h].astype(str).str.strip().str.replace(r"\.0$", "", regex=True)
            frame[k_i] = pd.to_numeric(frame[k_i], errors="coerce").astype(int)
            new = [c for c in frame.columns if c not in merged.columns]
            before = len(merged)
            merged = merged.merge(frame[[k_c, k_h, k_i] + new], on=[k_c, k_h, k_i], how="left")
            assert len(merged) == before, "the disposable-income merge changed the number of rows"
            log(f"  DI: {len(parts)} file(s), {len(frame)} rows, matched {int(merged[new[0]].notna().sum()) if new else 0} of {before}")
    else:
        log("  no disposable-income (di) files for this wave")
    reps = None
    if "W" in files and nrep > 0:
        reps = read_file(files["W"][0][1], {k_c, k_h}, countries, prefix=REPLICATE_PREFIX, max_prefix=nrep)
        reps[k_c] = reps[k_c].astype(str).str.strip().str.upper()
        reps[k_h] = reps[k_h].astype(str).str.strip().str.replace(r"\.0$", "", regex=True)
        reps = reps.drop_duplicates([k_c, k_h])
        rcols = [c for c in reps.columns if c.startswith(REPLICATE_PREFIX)]
        reps[rcols] = reps[rcols].apply(pd.to_numeric, errors="coerce").fillna(0.0).astype("float64")
        log(f"  W: {len(rcols)} replicate weights for {len(reps)} households")
    else:
        log("  no W file (or --nrep 0): standard errors will hold imputation variance only")
    return merged, reps


def tidy_names(df, notes):
    """
    Rename the columns to the logical keys of VARS, using the first alias found.
    Missing optional variables become NaN columns and are recorded in notes.
    Numeric variables are converted with errors coerced to NaN (the HFCS uses
    blanks or letter codes for missing values in csv: TO CONFIRM ON ARRIVAL).
    """
    out = pd.DataFrame(index=df.index)
    for key, (aliases, _file, _status) in VARS.items():
        col = next((a.upper() for a in aliases if a.upper() in df.columns), None)
        if col is None:
            if key in REQUIRED:
                raise KeyError(f"required variable '{key}' not found under any of {aliases}")
            notes.append(f"variable '{key}' ({'/'.join(aliases)}) absent")
            out[key] = np.nan
        elif key in STRING_VARS:
            out[key] = df[col].astype(str).str.strip().replace({"nan": np.nan, "": np.nan, "None": np.nan})
        else:
            out[key] = pd.to_numeric(df[col], errors="coerce")
    return out


# =============================================================================
# 3. CONCEPTS: one function per block A to I of the brief
# =============================================================================
# Each function receives the frame of ONE country and ONE wave (all implicates,
# logical column names) and adds columns. Amounts missing because the household
# does not hold the item are zero ("amt"). Moments are registered as
#   ratio moments   value = sum(w * N) / sum(w * D), columns N__name and D__name
#   quantile moments (medians, ratios of medians, Gini, top share), in QUANT.


def amt(df, key):
    """Amount held: missing means not held, so zero."""
    return df[key].fillna(0.0)


def add_share(df, name, indicator, universe=None, persons=False):
    """Share of households (or of persons) in the universe with indicator true."""
    ok = pd.Series(True, index=df.index) if universe is None else universe.fillna(False).astype(bool)
    ind = indicator.astype(float)
    ok = ok & ind.notna()
    scale = df["hsize"].fillna(1.0) if persons else 1.0
    df["N__" + name] = np.where(ok, ind.fillna(0.0) * scale, np.nan)
    df["D__" + name] = np.where(ok, 1.0 * scale, np.nan)


def add_ratio(df, name, num, den, universe=None):
    """Aggregate ratio sum(w * num) / sum(w * den); a mean when den is 1."""
    ok = num.notna() & pd.Series(den, index=df.index).notna()
    if universe is not None:
        ok = ok & universe.fillna(False).astype(bool)
    df["N__" + name] = np.where(ok, num, np.nan)
    df["D__" + name] = np.where(ok, den, np.nan)


def weighted_quantile(x, w, q):
    """Smallest x whose cumulative weight share reaches q (no interpolation)."""
    ok = np.isfinite(x) & np.isfinite(w) & (w > 0)
    if not ok.any():
        return np.nan
    order = np.argsort(x[ok], kind="mergesort")
    xs, cw = x[ok][order], np.cumsum(w[ok][order])
    return xs[np.searchsorted(cw, q * cw[-1], side="left").clip(0, len(xs) - 1)]


def by_implicate(df, func):
    """Apply func(sub-frame) -> scalar per implicate and broadcast to the rows."""
    out = pd.Series(np.nan, index=df.index)
    for _m, idx in df.groupby("implicate").groups.items():
        out.loc[idx] = func(df.loc[idx])
    return out


def build_A_wealth_income(df):
    """
    A. Liquid, illiquid and net wealth; gross, labour-plus-transfer and net income.

    KVW (2014, pp. 94-96), euro area HFCS:
      liquid assets  = cash + sight accounts + mutual funds + listed shares + bonds
      liquid debt    = credit card balance charged interest + credit line / overdraft
      cash           = not collected: transaction accounts inflated by 5.5%
      illiquid       = main residence and other property net of mortgages
                       + occupational and voluntary pensions + life insurance
                       + certificates of deposit and saving bonds
      income         = gross wages, salaries, self-employment, unemployment
                       benefits, regular private and public transfers
    Departures forced by the D file, all flagged in the brief:
      - occupational pension accounts sit in the P file and are left out;
      - unsecured loans taken to buy the home are not netted from illiquid wealth.
    """
    dep_kvw = amt(df, "sight")
    risky = amt(df, "funds") + amt(df, "bonds") + amt(df, "shares")
    liq_debt = amt(df, "overdraft") + amt(df, "ccdebt")
    saving = amt(df, "saving")
    if not KVW_SAVING_ACCOUNTS_ILLIQUID:
        dep_kvw = dep_kvw + saving
    df["liq_kvw"] = CASH_FACTOR * dep_kvw + risky - liq_debt
    df["illiq_kvw"] = (amt(df, "realestate") - amt(df, "mortgage") + amt(df, "pension_life")
                       + (saving if KVW_SAVING_ACCOUNTS_ILLIQUID else 0.0))
    # Broad pair for the two-asset model: all deposits liquid, no cash factor,
    # and illiquid as the residual, so that liquid + illiquid = net wealth (b + k).
    df["liq_broad"] = amt(df, "sight") + saving + risky - liq_debt
    df["illiq_broad"] = df["networth"] - df["liq_broad"]
    # OECD liquid financial wealth (Balestra and Tonkin 2018, Box 6.1): gross.
    df["liq_oecd"] = amt(df, "sight") + saving + risky
    # Income.
    df["inc_kvw"] = (amt(df, "inc_employee") + amt(df, "inc_self") + amt(df, "inc_unemp")
                     + amt(df, "inc_othsoc") + amt(df, "inc_privtr"))
    if KVW_INCOME_INCLUDES_PUBLIC_PENSIONS:
        df["inc_kvw"] = df["inc_kvw"] + amt(df, "inc_pubpens")
    df["inc_net"] = df["inc_gross"] - df["taxes"]        # NaN wherever taxes are not provided
    df["one"] = 1.0
    pos = df["inc_gross"] > 0
    # Disposable income as simulated by the ECB with EUROMOD (waves 2014 on): the
    # income concept of the model, whose households see income after taxes.
    # After-tax income, one measure for the three countries: the EUROMOD figure
    # where it exists (France and Germany, waves 2014 to 2021), otherwise gross
    # income less the taxes and social contributions the survey records itself
    # (Italy, every wave). Missing where neither exists.
    df["inc_dispo"] = df["inc_disp"].where(df["inc_disp"].notna(), df["inc_net"])
    add_share(df, "after_tax_income_from_euromod", df["inc_disp"].notna(), df["inc_dispo"].notna())
    posd = df["inc_dispo"] > 0
    df["liq_broad_ratio_disp"] = np.where(posd, df["liq_broad"] / df["inc_dispo"], np.nan)
    df["liq_kvw_ratio_disp"] = np.where(posd, df["liq_kvw"] / df["inc_dispo"], np.nan)
    add_ratio(df, "mean_income_disposable", df["inc_dispo"], df["one"])
    add_ratio(df, "disposable_over_gross_aggregate", df["inc_dispo"], df["inc_gross"], pos & df["inc_dispo"].notna())
    add_ratio(df, "income_tax_over_gross_aggregate", df["tax_income"], df["inc_gross"], pos & df["tax_income"].notna())
    add_ratio(df, "social_contributions_over_gross_aggregate", df["soc_contrib"], df["inc_gross"], pos & df["soc_contrib"].notna())
    add_ratio(df, "mean_networth", df["networth"], df["one"])
    add_ratio(df, "mean_liquid_kvw", df["liq_kvw"], df["one"])
    add_ratio(df, "mean_liquid_broad", df["liq_broad"], df["one"])
    add_ratio(df, "mean_illiquid_kvw", df["illiq_kvw"], df["one"])
    add_ratio(df, "mean_income_gross", df["inc_gross"], df["one"])
    add_ratio(df, "mean_income_labour_transfers", df["inc_kvw"], df["one"])
    add_ratio(df, "mean_income_net", df["inc_net"], df["one"])
    add_share(df, "share_income_nonpositive", ~pos)
    add_share(df, "share_liquid_kvw_negative", df["liq_kvw"] < 0)
    df["dnnla_ratio"] = np.where(pos, df["dnnla"] / df["inc_gross"], np.nan)
    df["liq_kvw_ratio"] = np.where(pos, df["liq_kvw"] / df["inc_gross"], np.nan)
    df["liq_broad_ratio"] = np.where(pos, df["liq_broad"] / df["inc_gross"], np.nan)
    return [("median_networth", "median", "networth", None),
            ("median_liquid_kvw", "median", "liq_kvw", None),
            ("median_liquid_broad", "median", "liq_broad", None),
            ("median_illiquid_kvw", "median", "illiq_kvw", None),
            ("median_illiquid_broad", "median", "illiq_broad", None),
            ("median_income_gross", "median", "inc_gross", None),
            ("median_income_labour_transfers", "median", "inc_kvw", None),
            ("median_income_net", "median", "inc_net", None),
            ("median_income_disposable", "median", "inc_dispo", None)]


def htm_flags(liq, illiq, income, periods_per_year, credit_limit_months):
    """
    KVW equations 8 to 11. With y the income of one pay period and the credit
    limit a number of months of income:
      at the zero kink     0 <= liquid <= y / 2
      at the credit limit  liquid < 0 and liquid <= y / 2 - limit
    Poor if illiquid wealth <= 0, wealthy if illiquid wealth > 0.
    """
    y = income / periods_per_year
    limit = credit_limit_months * income / 12.0
    htm = ((liq >= 0) & (liq <= y / 2.0)) | ((liq < 0) & (liq <= y / 2.0 - limit))
    return htm & (illiq <= 0), htm & (illiq > 0)


def build_B_hand_to_mouth(df):
    """
    B. Hand-to-mouth shares.
    KVW: biweekly pay, credit limit of one month of income, on their sample
    (head aged 22 to 79, income not negative, not all income from
    self-employment). Weekly and monthly pay are their robustness rows.
    Model (egm2_core.jl): liquid wealth <= annual labour-plus-benefit income / 52,
    no credit-limit branch, no sample restriction; wealthy if illiquid > 0.
    """
    age = df["age_rp"].where(df["age_rp"].notna(), df["age_rp_b"])
    all_self = (amt(df, "inc_self") > 0) & (amt(df, "inc_self") >= df["inc_kvw"] - 1e-9)
    sample = (age >= KVW_AGE_MIN) & (age <= KVW_AGE_MAX) & (df["inc_kvw"] >= 0) & ~all_self
    df["kvw_sample"] = sample
    for label, periods in (("", KVW_PAY_PERIODS), ("_weekly", 52), ("_monthly", 12)):
        poor, wealthy = htm_flags(df["liq_kvw"], df["illiq_kvw"], df["inc_kvw"], periods, KVW_CREDIT_LIMIT_MONTHS)
        add_share(df, f"htm_kvw{label}_poor", poor, sample)
        add_share(df, f"htm_kvw{label}_wealthy", wealthy, sample)
        add_share(df, f"htm_kvw{label}_total", poor | wealthy, sample)
        if label == "":
            df["htm_status"] = np.where(~sample, None, np.where(poor, "poor HtM", np.where(wealthy, "wealthy HtM", "not HtM")))
    add_share(df, "kvw_sample_share", sample)
    # The model's simpler rule, with the narrow (KVW) and the broad liquid wealth.
    for label, liq, illiq in (("narrow", "liq_kvw", "illiq_kvw"), ("broad", "liq_broad", "illiq_broad")):
        htm = df[liq] <= df["inc_kvw"].clip(lower=0) / MODEL_WEEKS
        add_share(df, f"htm_model_{label}_poor", htm & (df[illiq] <= 0))
        add_share(df, f"htm_model_{label}_wealthy", htm & (df[illiq] > 0))
        add_share(df, f"htm_model_{label}_total", htm)
    df["liq_kvw_s"] = df["liq_kvw"].where(sample)
    df["illiq_kvw_s"] = df["illiq_kvw"].where(sample)
    return [("kvw_sample_median_liquid", "median", "liq_kvw_s", None),
            ("kvw_sample_median_illiquid", "median", "illiq_kvw_s", None)]


def build_C_wealth_to_income(df):
    """
    C. Median net wealth over median gross household income (the calibration
    target, built from HFCS tables A1 and I1 as a ratio of two medians), the
    same for liquid wealth, the median household ratio of the ECB's net liquid
    assets to income (DNNLAratio), the net wealth Gini and the top 10% share.
    """
    return [("networth_to_income_ratio_of_medians", "ratio_of_medians", "networth", "inc_gross"),
            ("liquid_kvw_to_income_ratio_of_medians", "ratio_of_medians", "liq_kvw", "inc_gross"),
            ("liquid_broad_to_income_ratio_of_medians", "ratio_of_medians", "liq_broad", "inc_gross"),
            ("illiquid_broad_to_income_ratio_of_medians", "ratio_of_medians", "illiq_broad", "inc_gross"),
            ("dnnla_to_income_median_of_ratio", "median", "dnnla_ratio", None),
            ("liquid_kvw_to_income_median_of_ratio", "median", "liq_kvw_ratio", None),
            ("liquid_broad_to_income_median_of_ratio", "median", "liq_broad_ratio", None),
            ("networth_to_disposable_income_ratio_of_medians", "ratio_of_medians", "networth", "inc_dispo"),
            ("liquid_kvw_to_disposable_income_ratio_of_medians", "ratio_of_medians", "liq_kvw", "inc_dispo"),
            ("liquid_broad_to_disposable_income_ratio_of_medians", "ratio_of_medians", "liq_broad", "inc_dispo"),
            ("illiquid_broad_to_disposable_income_ratio_of_medians", "ratio_of_medians", "illiq_broad", "inc_dispo"),
            ("liquid_broad_to_disposable_income_median_of_ratio", "median", "liq_broad_ratio_disp", None),
            ("liquid_kvw_to_disposable_income_median_of_ratio", "median", "liq_kvw_ratio_disp", None),
            ("networth_gini", "gini", "networth", None),
            ("networth_top10_share", "top10", "networth", None)]


def build_D_poverty(df):
    """
    D. Income poverty, liquid-asset poverty and their overlap (hardship).
    Balestra and Tonkin (2018), section 6 and Box 6.1: individuals are the unit;
    income and wealth are equivalised by the square root of household size; the
    income poverty line is 50% of the national median; a person is asset poor if
    equivalised liquid financial wealth is below a quarter of that line (three
    months). The HFCS has gross income only, which they note biases asset
    poverty upwards. The national line is computed per implicate with the main
    weight and held fixed across replicate weights (a simplification).
    The 60% line and household-weighted shares are added for the model.
    """
    eq = np.sqrt(df["hsize"].clip(lower=1))
    df["inc_eq"] = df["inc_gross"] / eq
    df["liq_oecd_eq"] = df["liq_oecd"] / eq
    df["w_persons"] = df["weight"] * df["hsize"]
    med = by_implicate(df, lambda s: weighted_quantile(s["inc_eq"].values, s["w_persons"].values, 0.5))
    asset_poor = df["liq_oecd_eq"] < (ASSET_POVERTY_MONTHS / 12.0) * POVERTY_LINES[0] * med
    for line in POVERTY_LINES:
        tag = str(int(round(100 * line)))
        add_share(df, f"income_poor{tag}_persons", df["inc_eq"] < line * med, persons=True)
    income_poor = df["inc_eq"] < POVERTY_LINES[0] * med
    add_share(df, "asset_poor_oecd_persons", asset_poor, persons=True)
    add_share(df, "hardship_oecd_persons", asset_poor & income_poor, persons=True)
    add_share(df, "vulnerable_oecd_persons", asset_poor & ~income_poor, persons=True)
    add_share(df, "asset_poor_oecd_households", asset_poor)
    add_share(df, "hardship_oecd_households", asset_poor & income_poor)
    add_share(df, "income_poor50_households", income_poor)
    # The same on DISPOSABLE income, the concept of Balestra and Tonkin (2018) and
    # of the official poverty statistics, where the wave has it.
    df["inc_disp_eq"] = df["inc_dispo"] / eq
    medd = by_implicate(df, lambda s: weighted_quantile(s["inc_disp_eq"].values, s["w_persons"].values, 0.5))
    has = df["inc_disp_eq"].notna()
    asset_poor_d = df["liq_oecd_eq"] < (ASSET_POVERTY_MONTHS / 12.0) * POVERTY_LINES[0] * medd
    income_poor_d = df["inc_disp_eq"] < POVERTY_LINES[0] * medd
    for line in POVERTY_LINES:
        tag = str(int(round(100 * line)))
        add_share(df, f"income_poor{tag}_disp_persons", df["inc_disp_eq"] < line * medd, has, persons=True)
    add_share(df, "asset_poor_disp_persons", asset_poor_d, has, persons=True)
    add_share(df, "hardship_disp_persons", asset_poor_d & income_poor_d, has, persons=True)
    add_share(df, "asset_poor_disp_households", asset_poor_d, has)
    add_share(df, "income_poor50_disp_households", income_poor_d, has)
    return []


def build_E_groups(df):
    """
    E. Grouping variables: education of the reference person (ISCED 0-4 against
    5-8), labour status, region (DHREGION as delivered), Italian macro-area,
    degree of urbanisation, liquid wealth quintile and hand-to-mouth status.
    """
    df["g_education"] = df["edu_rp"].map({1: "below tertiary", 2: "below tertiary", 3: "below tertiary", 5: "tertiary"})
    df["g_labour"] = df["lab_rp"].map({1: "employed", 2: "employed", 3: "unemployed", 4: "retired", 5: "other"})
    # THE MODEL'S POPULATION (2026-10-08). The model's households are in the labour force. Households
    # with a retired reference person, about a third of the sample, hold more liquid wealth and are
    # less often hand-to-mouth, so a moment over all households is not the model population's.
    # labour_force: reference person an employee, self-employed or unemployed. not_retired adds the
    # other non-retired (for the state out of work, when the model has one). The education split is
    # repeated within each, since the calibration uses the gap between the education groups.
    lf = df["lab_rp"].isin([1, 2, 3]); nr = df["lab_rp"].isin([1, 2, 3, 5])
    df["g_labour_force"] = pd.Series("in the labour force", index=df.index).where(lf)
    df["g_not_retired"] = pd.Series("not retired", index=df.index).where(nr)
    df["g_education_lf"] = df["g_education"].where(lf)
    df["g_education_nr"] = df["g_education"].where(nr)
    df["g_region"] = df["region"]
    df["g_macro_region"] = df["region"].map(IT_MACRO)
    df["g_degurba"] = df["degurba"].map({1: "cities", 2: "towns and suburbs", 3: "rural"})
    cuts = {}
    for m, sub in df.groupby("implicate"):
        cuts[m] = [weighted_quantile(sub["liq_kvw"].values, sub["weight"].values, q) for q in (0.2, 0.4, 0.6, 0.8)]
    quint = np.array([1 + int(np.searchsorted(cuts[m], v, side="left")) for m, v in zip(df["implicate"], df["liq_kvw"])])
    df["g_liquid_quintile"] = ["Q" + str(q) for q in quint]
    df["g_htm_status"] = df["htm_status"]
    return []


def build_F_mpc(df):
    """
    F. Self-reported MPC: percentage of a lottery win equal to one month of
    household income spent on goods and services within 12 months (HIZ040a,
    derived DOLOTTGOOD), waves 2017, 2021 and 2023. Mean, median and the shares
    answering 0, 50 and 100.
    """
    mpc = df["mpc"] / 100.0
    mpc = mpc.where((mpc >= 0) & (mpc <= 1))
    df["mpc01"] = mpc
    has = mpc.notna()
    add_ratio(df, "mpc_mean", mpc, df["one"])
    add_share(df, "mpc_share_zero", mpc == 0, has)
    add_share(df, "mpc_share_half", mpc == 0.5, has)
    add_share(df, "mpc_share_all", mpc == 1, has)
    add_share(df, "mpc_response_rate", has)
    return [("mpc_median", "median", "mpc01", None)]


def build_G_consumption(df):
    """
    G. Consumption over gross income. HI0100 (food at home), HI0200 (food
    outside) and HI0220 (all consumer goods and services, excluding durables,
    rent, loan repayments and insurance; from wave 2014) are amounts for a
    typical month, annualised here. Aggregate ratios (sum over sum) and the
    median household ratio, the latter over households with positive income.
    """
    food = 12.0 * (df["food_home"] + df["food_out"].fillna(0.0))
    goods = 12.0 * df["cons_goods"]
    pos = df["inc_gross"] > 0
    add_ratio(df, "food_to_income_aggregate", food, df["inc_gross"], pos)
    add_ratio(df, "consumption_to_income_aggregate", goods, df["inc_gross"], pos)
    add_ratio(df, "mean_consumption_annual", goods, df["one"])
    df["cons_ratio"] = np.where(pos, goods / df["inc_gross"], np.nan)
    df["food_ratio"] = np.where(pos, food / df["inc_gross"], np.nan)
    return [("consumption_to_income_median_of_ratio", "median", "cons_ratio", None),
            ("food_to_income_median_of_ratio", "median", "food_ratio", None)]


def build_H_portfolio(df, country, wave):
    """
    H. Portfolio facts for the two-asset model: any illiquid wealth (real
    estate, voluntary pension or life insurance, business), home ownership,
    mortgages, illiquid over liquid, and two proxies for the frequency of large
    portfolio adjustments (main residence acquired in the last five years, read
    from HB0700; a refinanced mortgage, DREFINANi). The HFCS has no direct
    question on portfolio adjustment in FR, DE or IT.
    """
    any_illiq = (amt(df, "realestate") > 0) | (amt(df, "pension_life") > 0) | (amt(df, "business") > 0)
    owner = amt(df, "hmr") > 0
    has_mort = amt(df, "mortgage") > 0
    add_share(df, "share_any_illiquid", any_illiq)
    add_share(df, "share_illiquid_kvw_positive", df["illiq_kvw"] > 0)
    add_share(df, "share_real_estate", amt(df, "realestate") > 0)
    add_share(df, "share_pension_life", amt(df, "pension_life") > 0)
    add_share(df, "share_business", amt(df, "business") > 0)
    add_share(df, "home_ownership_rate", owner)
    add_share(df, "share_with_mortgage", has_mort)
    add_ratio(df, "mortgage_to_income_aggregate", amt(df, "mortgage"), df["inc_gross"], df["inc_gross"] > 0)
    add_share(df, "share_refinanced_mortgage", df["refinanced"] == 1, df["refinanced"].notna())
    year = FIELDWORK_YEAR.get((country, wave))
    if year is not None:
        add_share(df, "hmr_acquired_last5y_share", df["hmr_year"] >= year - 4, df["hmr_year"].notna() | ~owner)
    df["mortgage_pos"] = df["mortgage"].where(has_mort)
    df["illiq_to_liq"] = np.where(df["liq_broad"] > 0, df["illiq_broad"] / df["liq_broad"], np.nan)
    return [("median_mortgage_among_holders", "median", "mortgage_pos", None),
            ("illiquid_to_liquid_broad_ratio_of_medians", "ratio_of_medians", "illiq_broad", "liq_broad"),
            ("illiquid_to_liquid_kvw_ratio_of_medians", "ratio_of_medians", "illiq_kvw", "liq_kvw"),
            ("illiquid_to_liquid_broad_median_of_ratio", "median", "illiq_to_liq", None)]


def build_I_credit(df):
    """
    I. Credit constraints (reference period: the last three years).
    DOCREDITC = refused and not later successful, or given less than asked, or
    did not apply expecting a rejection. Also access to and use of overdrafts
    and credit cards, which bear on the model's no-borrowing assumption.
    """
    add_share(df, "credit_constrained", df["cred_constr"] == 1, df["cred_constr"].notna())
    add_share(df, "credit_applied", df["cred_applied"] == 1, df["cred_applied"].notna())
    add_share(df, "credit_refused_among_applicants", df["cred_refused"] == 1, df["cred_refused"].notna())
    add_share(df, "credit_discouraged", df["cred_discour"] == 1, df["cred_discour"].notna())
    add_share(df, "has_credit_line_or_overdraft", df["has_cline"] == 1, df["has_cline"].notna())
    add_share(df, "has_credit_card", df["has_ccard"] == 1, df["has_ccard"].notna())
    add_share(df, "has_overdraft_debt", amt(df, "overdraft") > 0)
    add_share(df, "has_credit_card_debt", amt(df, "ccdebt") > 0)
    return []


def build_all(df, country, wave):
    """Run blocks A to I in order; return the list of quantile-type moments."""
    quant = []
    quant += build_A_wealth_income(df)
    quant += build_B_hand_to_mouth(df)
    quant += build_C_wealth_to_income(df)
    quant += build_D_poverty(df)
    quant += build_E_groups(df)
    quant += build_F_mpc(df)
    quant += build_G_consumption(df)
    quant += build_H_portfolio(df, country, wave)
    quant += build_I_credit(df)
    return quant


GROUP_VARS = ["all", "education", "labour", "labour_force", "not_retired", "education_lf", "education_nr", "region", "macro_region", "degurba", "liquid_quintile", "htm_status"]

# =============================================================================
# 4. ESTIMATION: weights, replicate weights, Rubin's rules
# =============================================================================
# Every estimator returns a vector of length 1 + R: element 0 uses the main
# weight HW0010, elements 1..R the bootstrap replicate weights.


def quantiles_all_weights(x, W, q):
    """Weighted q-quantile of x for every column of W (rows already valid)."""
    order = np.argsort(x, kind="mergesort")
    xs, cw = x[order], np.cumsum(W[order], axis=0)
    total = cw[-1]
    idx = (cw >= q * total[None, :]).argmax(axis=0)
    return np.where(total > 0, xs[idx], np.nan)


def gini_all_weights(x, W):
    """Weighted Gini of x for every column of W (negative values allowed)."""
    order = np.argsort(x, kind="mergesort")
    xs, Ws = x[order], W[order]
    total = Ws.sum(axis=0)
    S = np.cumsum(Ws * xs[:, None], axis=0)
    with np.errstate(invalid="ignore", divide="ignore"):
        L = S / S[-1]
        Lprev = np.vstack([np.zeros((1, W.shape[1])), L[:-1]])
        g = 1.0 - ((Ws / total) * (L + Lprev)).sum(axis=0)
    return np.where((total > 0) & (S[-1] > 0), g, np.nan)


def top_share_all_weights(x, W, q=0.9):
    """Share of the total of x held by households above the weighted q-quantile."""
    order = np.argsort(x, kind="mergesort")
    xs, Ws = x[order], W[order]
    cw = np.cumsum(Ws, axis=0)
    S = np.cumsum(Ws * xs[:, None], axis=0)
    idx = (cw >= q * cw[-1][None, :]).argmax(axis=0)
    with np.errstate(invalid="ignore", divide="ignore"):
        share = 1.0 - S[idx, np.arange(W.shape[1])] / S[-1]
    return np.where((cw[-1] > 0) & (S[-1] > 0), share, np.nan)


def estimate_cell(sub, W, ratio_names, quant):
    """
    All moments for one cell (one implicate, one group).
    sub: frame of the cell. W: (n, 1 + R) weights. Returns {moment: (vector, n)}.
    """
    out = {}
    nan_vec = np.full(W.shape[1], np.nan)
    for name in ratio_names:
        num, den = sub["N__" + name].values, sub["D__" + name].values
        ok = np.isfinite(num) & np.isfinite(den)
        n = int((ok & (den != 0)).sum())
        if n == 0:
            out[name] = (nan_vec, 0)
            continue
        top = W[ok].T @ num[ok]
        bottom = W[ok].T @ den[ok]
        with np.errstate(invalid="ignore", divide="ignore"):
            out[name] = (np.where(bottom != 0, top / bottom, np.nan), n)
    for name, kind, cx, cy in quant:
        x = sub[cx].values.astype(float)
        ok = np.isfinite(x)
        n = int(ok.sum())
        if n == 0:
            out[name] = (nan_vec, 0)
            continue
        if kind == "median":
            vec = quantiles_all_weights(x[ok], W[ok], 0.5)
        elif kind == "gini":
            vec = gini_all_weights(x[ok], W[ok])
        elif kind == "top10":
            vec = top_share_all_weights(x[ok], W[ok], 0.9)
        elif kind == "ratio_of_medians":
            y = sub[cy].values.astype(float)
            oky = np.isfinite(y)
            if not oky.any():
                out[name] = (nan_vec, 0)
                continue
            n = int(min(n, oky.sum()))
            den = quantiles_all_weights(y[oky], W[oky], 0.5)
            with np.errstate(invalid="ignore", divide="ignore"):
                vec = np.where(den != 0, quantiles_all_weights(x[ok], W[ok], 0.5) / den, np.nan)
        else:
            raise ValueError(kind)
        out[name] = (vec, n)
    return out


def rubin_combine(vectors):
    """
    Combine the implicates (ECB methodological report, section 7.3).
    vectors: one array per implicate, element 0 the point estimate and the rest
    the replicate estimates. Returns (estimate, standard error).
      estimate = mean of the M point estimates
      W = mean over implicates of the bootstrap variance of the replicates
      Q = variance of the M point estimates
      T = W + (1 + 1/M) Q,  standard error = sqrt(T)
    Without replicate weights W is zero and the standard error is too small.
    """
    theta = np.array([v[0] for v in vectors], dtype=float)
    if not np.all(np.isfinite(theta)):
        return np.nan, np.nan
    M = len(theta)
    within = []
    for v in vectors:
        reps = v[1:][np.isfinite(v[1:])]
        within.append(np.var(reps, ddof=1) if len(reps) >= 2 else 0.0)
    Wv = float(np.mean(within))
    Q = float(np.var(theta, ddof=1)) if M > 1 else 0.0
    return float(theta.mean()), float(np.sqrt(Wv + (1.0 + 1.0 / M) * Q))


def estimate_country_wave(df, reps, country, wave, min_cell, log):
    """All moments, all groups, for one country and wave. Returns tidy rows."""
    quant = build_all(df, country, wave)
    ratio_names = [c[3:] for c in df.columns if c.startswith("N__")]
    implicates = sorted(df["implicate"].unique())
    rep_cols = [] if reps is None else [c for c in reps.columns if c.startswith(REPLICATE_PREFIX)]
    if reps is not None:
        reps = reps.set_index("hid")
    cells = {}   # (group_var, level) -> list over implicates of {moment: (vec, n)}
    for m in implicates:
        sub = df[df["implicate"] == m]
        w = sub["weight"].fillna(0.0).values
        if rep_cols:
            R = reps.reindex(sub["hid"].values)[rep_cols].fillna(0.0).values
            W = np.column_stack([w, R])
        else:
            W = w[:, None]
        for gvar in GROUP_VARS:
            if gvar == "all":
                levels = {"all": np.ones(len(sub), dtype=bool)}
            else:
                g = sub["g_" + gvar]
                levels = {str(lv): (g == lv).values for lv in sorted(g.dropna().unique(), key=str)}
            for level, mask in levels.items():
                if mask.sum() == 0:
                    continue
                cells.setdefault((gvar, level), []).append(estimate_cell(sub[mask], W[mask], ratio_names, quant))
    rows = []
    for (gvar, level), per_imp in cells.items():
        for name in per_imp[0]:
            vectors = [d[name][0] for d in per_imp]
            n = min(d[name][1] for d in per_imp) if len(per_imp) == len(implicates) else 0
            value, se = rubin_combine(vectors)
            suppressed = n < min_cell
            note = ""
            if suppressed:
                value, se, note = np.nan, np.nan, f"suppressed: fewer than {min_cell} households"
            elif not rep_cols:
                note = "no replicate weights: se is imputation variance only"
            rows.append(dict(moment=name, country=country, wave=wave, group_var=gvar, group=level,
                             value=value, se=se, n_unweighted=n, n_implicates=len(per_imp),
                             n_replicates=len(rep_cols), suppressed=suppressed, note=note))
    log(f"  {country} {wave}: {len(rows)} cells, {sum(r['suppressed'] for r in rows)} suppressed")
    return rows


def coverage_rows(df, country, wave):
    """Share of households with a non-missing value, per variable (aggregate)."""
    first = df[df["implicate"] == df["implicate"].min()]
    rows = []
    for key, (aliases, ffile, status) in VARS.items():
        if key in ("country", "hid", "implicate"):
            continue
        share = float(first[key].notna().mean()) if len(first) else np.nan
        rows.append(dict(variable=key, hfcs_names="/".join(aliases), file=ffile, status=status,
                         country=country, wave=wave, n_households=len(first),
                         share_nonmissing=round(share, 4), present=bool(share > 0)))
    return rows


def benchmark_rows(moments):
    """Compare the computed moments with the published numbers in BENCHMARKS."""
    rows = []
    key = moments.set_index(["moment", "group_var", "group", "country", "wave"])
    for moment, gvar, group, country, wave, published, source in BENCHMARKS:
        idx = (moment, gvar, group, country, wave)
        computed = float(key.loc[idx, "value"]) if idx in key.index else np.nan
        rows.append(dict(moment=moment, country=country, wave=wave, published=published, computed=computed,
                         difference=computed - published if np.isfinite(computed) else np.nan, source=source))
    return rows


# =============================================================================
# 5. OUTPUT: the only place where anything is written
# =============================================================================

ALLOWED_TABLES = {
    "hfcs_moments.csv": ["moment", "country", "wave", "group_var", "group", "value", "se", "n_unweighted",
                         "n_implicates", "n_replicates", "suppressed", "note"],
    "hfcs_coverage.csv": ["variable", "hfcs_names", "file", "status", "country", "wave", "n_households",
                          "share_nonmissing", "present"],
    "hfcs_benchmarks.csv": ["moment", "country", "wave", "published", "computed", "difference", "source"],
}


def write_aggregate_table(table, outdir, filename, min_cell):
    """
    Guarded writer. Refuses anything that is not one of the three aggregate
    tables with exactly the expected columns, and any moment row that carries a
    value from fewer than min_cell households. Household-level data cannot pass:
    the allowed columns contain no identifier, weight or survey variable.
    """
    if filename not in ALLOWED_TABLES:
        raise PermissionError(f"refusing to write '{filename}': not an approved aggregate table")
    if list(table.columns) != ALLOWED_TABLES[filename]:
        raise PermissionError(f"refusing to write '{filename}': unexpected columns {list(table.columns)}")
    if filename == "hfcs_moments.csv":
        leak = table[(table["n_unweighted"] < min_cell) & table["value"].notna()]
        if len(leak):
            raise PermissionError(f"refusing to write: {len(leak)} unsuppressed cells under {min_cell} households")
    os.makedirs(outdir, exist_ok=True)
    path = os.path.join(outdir, filename)
    table.to_csv(path, index=False)
    return path


def run(hfcs_dir, outdir, waves, countries, nrep, min_cell, log=print):
    """The whole pipeline. Returns the three aggregate tables."""
    log(CONFIDENTIALITY_NOTICE.format(hfcs_dir=hfcs_dir, min_cell=min_cell))
    wave_dirs = find_wave_dirs(hfcs_dir)
    if not wave_dirs:
        raise FileNotFoundError(f"no wave folder found in {hfcs_dir}; expected names containing {WAVE_DIR_TOKENS}")
    moment_rows, cover_rows = [], []
    for wave in waves:
        if wave not in wave_dirs:
            log(f"wave {wave}: no folder found, skipped")
            continue
        log(f"wave {wave}: {wave_dirs[wave]}")
        raw, reps = load_wave(wave_dirs[wave], countries, nrep, log,
                              di_dir=os.path.join(hfcs_dir, DI_DIR.format(year=wave)))
        ccol = VARS["country"][0][0]
        for country in countries:
            raw_c = raw[raw[ccol] == country]
            if raw_c.empty:
                log(f"  {country} {wave}: no rows")
                continue
            notes = []
            df = tidy_names(raw_c, notes).reset_index(drop=True)
            if notes:
                log(f"  {country} {wave}: " + "; ".join(notes))
            reps_c = None
            if reps is not None:
                reps_c = reps[reps[ccol] == country].rename(columns={VARS["hid"][0][0]: "hid"})
            cover_rows += coverage_rows(df, country, wave)
            moment_rows += estimate_country_wave(df, reps_c, country, wave, min_cell, log)
    moments = pd.DataFrame(moment_rows, columns=ALLOWED_TABLES["hfcs_moments.csv"])
    coverage = pd.DataFrame(cover_rows, columns=ALLOWED_TABLES["hfcs_coverage.csv"])
    bench = pd.DataFrame(benchmark_rows(moments), columns=ALLOWED_TABLES["hfcs_benchmarks.csv"])
    for name, table in (("hfcs_moments.csv", moments), ("hfcs_coverage.csv", coverage), ("hfcs_benchmarks.csv", bench)):
        log(f"written: {write_aggregate_table(table, outdir, name, min_cell)} ({len(table)} rows)")
    return moments, coverage, bench


# =============================================================================
# 6. SELF-TEST ON SYNTHETIC DATA (no HFCS data involved)
# =============================================================================


def synthetic_wave(rng, wave, n_per_country=400, n_rep=25):
    """
    A synthetic wave with the HFCS column names. Random numbers only: nothing is
    taken from the survey. Returns (D, H, W) frames with upper-case names.
    """
    d_parts, h_parts, w_parts = [], [], []
    regions = {"FR": [f"FR{i}" for i in range(1, 9)], "DE": ["DENW", "DEWW", "DEOS", "DESW"],
               "IT": [f"IT{i}" for i in range(1, 21)], "ES": ["ES1"]}
    for country in ("FR", "DE", "IT", "ES"):
        n = n_per_country
        hid = np.arange(1, n + 1) + {"FR": 0, "DE": 100000, "IT": 200000, "ES": 300000}[country]
        weight = rng.uniform(500, 5000, n)
        size = rng.integers(1, 6, n)
        age = rng.integers(18, 90, n)
        edu = rng.choice([1, 2, 3, 5], n, p=[0.15, 0.2, 0.4, 0.25])
        lab = rng.choice([1, 2, 3, 4, 5], n, p=[0.45, 0.08, 0.07, 0.3, 0.1])
        region = rng.choice(regions[country], n)
        if country == "FR":
            region[:12] = "FR0"          # a small cell, to test suppression
        employee = np.where(lab == 1, rng.lognormal(10.2, 0.5, n), 0.0)
        selfemp = np.where(lab == 2, rng.lognormal(10.0, 0.8, n), 0.0)
        pension = np.where(lab == 4, rng.lognormal(9.8, 0.4, n), 0.0)
        unemp = np.where(lab == 3, rng.lognormal(9.0, 0.3, n), 0.0)
        social = np.where(rng.random(n) < 0.3, rng.lognormal(7.5, 0.6, n), 0.0)
        owner = rng.random(n) < {"FR": 0.58, "DE": 0.45, "IT": 0.7, "ES": 0.8}[country]
        hmr = np.where(owner, rng.lognormal(12.2, 0.5, n), np.nan)
        other_re = np.where(rng.random(n) < 0.2, rng.lognormal(11.5, 0.7, n), 0.0)
        mortgage = np.where(owner & (rng.random(n) < 0.4), rng.lognormal(11.0, 0.6, n), np.nan)
        penlife = np.where(rng.random(n) < 0.35, rng.lognormal(9.5, 1.0, n), np.nan)
        business = np.where(lab == 2, rng.lognormal(10.5, 1.2, n), np.nan)
        hmr_year = np.where(owner, rng.integers(1960, 2022, n), np.nan)
        applied = rng.random(n) < 0.25
        refused = np.where(applied, (rng.random(n) < 0.15).astype(float), np.nan)
        discouraged = (rng.random(n) < 0.06).astype(float)
        for m in range(1, 6):
            # the same households in every implicate; liquid items vary a little
            noise = rng.lognormal(0.0, 0.1, n)
            sight = rng.lognormal(7.3, 1.3, n) * noise * np.where(rng.random(n) < 0.15, 0.02, 1.0)
            saving = np.where(rng.random(n) < 0.6, rng.lognormal(8.5, 1.3, n), np.nan)
            funds = np.where(rng.random(n) < 0.12, rng.lognormal(9.5, 1.0, n), np.nan)
            bonds = np.where(rng.random(n) < 0.05, rng.lognormal(9.5, 1.0, n), np.nan)
            shares = np.where(rng.random(n) < 0.12, rng.lognormal(9.0, 1.2, n), np.nan)
            overdraft = np.where(rng.random(n) < 0.12, rng.lognormal(6.8, 0.8, n), np.nan)
            cc = np.where(rng.random(n) < 0.06, rng.lognormal(6.5, 0.8, n), np.nan)
            z = lambda a: np.nan_to_num(a, nan=0.0)
            gross = employee + selfemp + pension + unemp + social
            realestate = z(hmr) + other_re
            fin = z(sight) + z(saving) + z(funds) + z(bonds) + z(shares) + z(penlife)
            net = realestate + z(business) + fin - z(mortgage) - z(overdraft) - z(cc)
            d = pd.DataFrame({
                "SA0100": country, "SA0010": hid, "IM0100": m, "HW0010": weight,
                "DA21011": sight, "DA21012": saving, "DA2102": funds, "DA2103": bonds, "DA2105": shares,
                "DL1210": overdraft, "DL1220": cc,
                "DNNLA": z(sight) + z(saving) + z(funds) + z(bonds) + z(shares) - z(overdraft) - z(cc),
                "DA1110": hmr, "DA1400": np.where(realestate > 0, realestate, np.nan), "DL1100": mortgage,
                "DA2109": penlife, "DA1200": business, "DN3001": net, "DHHST": np.where(owner, 1, 3),
                "DI2000": gross, "DI1100": employee, "DI1200": selfemp, "DI1510": pension, "DI1610": unemp,
                "DI1620": social, "DI1700": 0.0,
                "DH0001": size, "DHAGEH1": age, "DHEDUH1": edu, "DHEMPH1": lab, "DHREGION": region,
                "DOCREDITC": np.where((refused == 1) | (discouraged == 1), 1, 0),
                "DOCREDITAPPL": applied.astype(int), "DOCREDITREFUSAL": refused,
                "DOCREDITNOTAPPL": discouraged, "DLCL": (rng.random(n) < 0.4).astype(int),
                "DLCC": (rng.random(n) < 0.35).astype(int), "DREFINANI": np.where(z(mortgage) > 0, 0.0, np.nan),
            })
            if wave != "2017":
                d["DHDEGURBA"] = (hid % 3) + 1                    # not in the 2017 catalogue
            base = rng.choice([0, 20, 50, 80, 100], n, p=[0.2, 0.15, 0.3, 0.1, 0.25])
            mpc = np.clip(base - 10 * (np.log1p(z(sight)) > 8), 0, 100).astype(float)
            mpc[rng.random(n) < 0.02] = np.nan
            h = pd.DataFrame({
                "SA0100": country, "SA0010": hid, "IM0100": m,
                "HI0100": rng.lognormal(6.0, 0.3, n), "HI0200": rng.lognormal(4.5, 0.6, n),
                "HI0220": rng.lognormal(7.2, 0.4, n), "HB0700": hmr_year, "HIZ040A": mpc,
            })
            d_parts.append(d)
            h_parts.append(h)
        w = pd.DataFrame({"SA0100": country, "SA0010": hid})
        for b in range(1, n_rep + 1):
            w[f"WR{b:04d}"] = weight * rng.poisson(1.0, n)
        w_parts.append(w)
    return pd.concat(d_parts, ignore_index=True), pd.concat(h_parts, ignore_index=True), pd.concat(w_parts, ignore_index=True)


def write_synthetic(root, rng):
    """Two synthetic waves: 2017 as stacked csv files, 2021 as Stata files per implicate."""
    truth = {}
    for wave, layout in (("2017", "csv"), ("2021", "dta")):
        D, H, W = synthetic_wave(rng, wave)
        truth[wave] = (D, H, W)
        folder = os.path.join(root, f"HFCS_UDB_{wave}_synthetic")
        os.makedirs(folder)
        if layout == "csv":
            D.to_csv(os.path.join(folder, "D.csv"), index=False)
            H.to_csv(os.path.join(folder, "H.csv"), index=False)
            W.to_csv(os.path.join(folder, "W.csv"), index=False)
        else:
            sub = os.path.join(folder, "stata")
            os.makedirs(sub)
            for m in range(1, 6):
                for name, frame in (("d", D), ("h", H)):
                    part = frame[frame["IM0100"] == m].drop(columns="IM0100")
                    part.columns = [c.lower() for c in part.columns]
                    part.to_stata(os.path.join(sub, f"{name}{m}.dta"), write_index=False)
            Wl = W.copy()
            Wl.columns = [c.lower() for c in Wl.columns]
            Wl.to_stata(os.path.join(sub, "w.dta"), write_index=False)
    return truth


def selftest():
    """Generate synthetic data, run the whole pipeline, and check known answers."""
    rng = np.random.default_rng(20261002)
    checks = []

    def check(name, ok):
        checks.append((name, bool(ok)))
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}")

    print("SELF-TEST on synthetic data (no HFCS data is read)")
    # --- helper functions against hand-computed answers
    x = np.array([1.0, 2.0, 3.0, 4.0])
    Wm = np.column_stack([np.ones(4), np.array([1.0, 1.0, 1.0, 5.0])])
    check("weighted median, equal weights (2) and skewed weights (4)",
          np.allclose(quantiles_all_weights(x, Wm, 0.5), [2.0, 4.0]))
    check("Gini is 0 for equal holdings", abs(gini_all_weights(np.full(50, 7.0), np.ones((50, 1)))[0]) < 1e-12)
    one_rich = np.r_[np.zeros(99), 1.0]
    check("Gini is 0.99 when one household of 100 holds everything",
          abs(gini_all_weights(one_rich, np.ones((100, 1)))[0] - 0.99) < 1e-12)
    check("top 10% share is 0.19 for holdings 1..100 (91..100 over 5050 minus the p90 household)",
          abs(top_share_all_weights(np.arange(1.0, 101.0), np.ones((100, 1)))[0] - (1 - 4095.0 / 5050.0)) < 1e-12)
    v = [np.array([1.0, 0.9, 1.1, 1.0]), np.array([2.0, 1.9, 2.1, 2.0])]
    est, se = rubin_combine(v)
    check("Rubin: estimate 1.5, T = 0.01 + 1.5 * 0.5", abs(est - 1.5) < 1e-12 and abs(se - np.sqrt(0.01 + 0.75)) < 1e-12)
    liq = pd.Series([0.0, 400.0, 2000.0, -500.0, -3000.0, 900.0])
    ill = pd.Series([0.0, 50000.0, 0.0, 0.0, 10000.0, 1.0])
    inc = pd.Series([26000.0] * 6)                  # 1,000 per fortnight, limit 2,166.67
    poor, wealthy = htm_flags(liq, ill, inc, 26, 1.0)
    check("KVW rule: zero kink, credit limit, poor and wealthy on six hand cases",
          list(poor) == [True, False, False, False, False, False]
          and list(wealthy) == [False, True, False, False, True, False])

    with tempfile.TemporaryDirectory(prefix="hfcs_selftest_") as tmp:
        data_dir, out_dir = os.path.join(tmp, "synthetic_hfcs"), os.path.join(tmp, "out")
        os.makedirs(data_dir)
        truth = write_synthetic(data_dir, rng)
        lines = []
        moments, coverage, bench = run(data_dir, out_dir, WAVES, COUNTRIES, nrep=25, min_cell=MIN_CELL, log=lines.append)
        print("  pipeline log (abridged):")
        for line in lines[1:]:
            print("    " + str(line).strip())
        check("three aggregate tables written and nothing else",
              sorted(os.listdir(out_dir)) == sorted(ALLOWED_TABLES))
        check("both layouts load: 2017 stacked csv and 2021 per-implicate Stata, FR DE IT only",
              set(moments["wave"]) == {"2017", "2021"} and set(moments["country"]) == {"FR", "DE", "IT"})
        # --- an independent, slow computation of three moments for FR 2021
        D, H, W = truth["2021"]
        fr = D[D["SA0100"] == "FR"]
        th, um = [], []
        wr = W[W["SA0100"] == "FR"].set_index("SA0010")
        for m in range(1, 6):
            s = fr[fr["IM0100"] == m]
            own = (s["DA1110"].fillna(0) > 0).astype(float).values
            th.append(np.average(own, weights=s["HW0010"].values))
            um.append(np.var([np.average(own, weights=wr.loc[s["SA0010"], c].values) for c in wr.columns if c.startswith("WR")], ddof=1))
        t_est, t_se = np.mean(th), np.sqrt(np.mean(um) + 1.2 * np.var(th, ddof=1))
        row = moments.query("moment == 'home_ownership_rate' and country == 'FR' and wave == '2021' and group == 'all'").iloc[0]
        check("home ownership FR 2021: estimate and Rubin standard error match an independent computation",
              abs(row["value"] - t_est) < 1e-10 and abs(row["se"] - t_se) < 1e-10)
        ratios = []
        for m in range(1, 6):
            s = fr[fr["IM0100"] == m]
            ratios.append(weighted_quantile(s["DN3001"].values, s["HW0010"].values, 0.5)
                          / weighted_quantile(s["DI2000"].values, s["HW0010"].values, 0.5))
        row = moments.query("moment == 'networth_to_income_ratio_of_medians' and country == 'FR' and wave == '2021' and group == 'all'").iloc[0]
        check("net wealth over income (ratio of medians) FR 2021 matches an independent computation",
              abs(row["value"] - np.mean(ratios)) < 1e-10)
        h = H[(H["SA0100"] == "FR")].merge(fr[["SA0010", "IM0100", "HW0010"]], on=["SA0010", "IM0100"])
        mp = [np.average(g["HIZ040A"].dropna() / 100, weights=g.loc[g["HIZ040A"].notna(), "HW0010"]) for _m, g in h.groupby("IM0100")]
        row = moments.query("moment == 'mpc_mean' and country == 'FR' and wave == '2021' and group == 'all'").iloc[0]
        check("mean MPC FR 2021 (read from the H file under the alias HIZ040A) matches", abs(row["value"] - np.mean(mp)) < 1e-10)
        # --- disclosure control and optional variables
        small = moments.query("group == 'FR0'")
        check("region FR0 (12 households) is present and fully suppressed",
              len(small) > 0 and small["suppressed"].all() and small["value"].isna().all())
        check("no published cell has fewer than 30 households",
              not ((moments["n_unweighted"] < MIN_CELL) & moments["value"].notna()).any())
        check("degree of urbanisation: absent in 2017 (skipped), present in 2021",
              moments.query("wave == '2017' and group_var == 'degurba'").empty
              and not moments.query("wave == '2021' and group_var == 'degurba'").empty)
        check("coverage table flags DHDEGURBA and taxes as absent in 2017",
              not coverage.query("wave == '2017' and variable == 'degurba'")["present"].any()
              and not coverage.query("variable == 'taxes'")["present"].any())
        check("poor + wealthy = total hand-to-mouth in every published cell",
              all(abs(moments.query("moment == @a").set_index(["country", "wave", "group_var", "group"])["value"]
                      + moments.query("moment == @b").set_index(["country", "wave", "group_var", "group"])["value"]
                      - moments.query("moment == @c").set_index(["country", "wave", "group_var", "group"])["value"]).dropna().max() < 1e-9
                  for a, b, c in (("htm_kvw_poor", "htm_kvw_wealthy", "htm_kvw_total"),
                                  ("htm_model_broad_poor", "htm_model_broad_wealthy", "htm_model_broad_total"))))
        mq = moments.query("moment == 'mpc_mean' and group_var == 'liquid_quintile' and country == 'DE' and wave == '2021'").set_index("group")["value"]
        check("MPC by liquid wealth quintile is computed (five quintiles) and declines by construction",
              len(mq) == 5 and mq["Q1"] > mq["Q5"])
        check("standard errors are positive wherever a value is published",
              (moments.loc[moments["value"].notna() & (moments["moment"] == "home_ownership_rate"), "se"] > 0).all())
        check("benchmark table is produced; synthetic waves have no 2010 or 2014, so those rows are empty",
              len(bench) == len(BENCHMARKS) and bench.query("wave == '2010'")["computed"].isna().all())
        # --- the guard refuses household-level data
        refused = 0
        try:
            write_aggregate_table(D.head(50), out_dir, "hfcs_moments.csv", MIN_CELL)
        except PermissionError:
            refused += 1
        try:
            write_aggregate_table(D.head(50), out_dir, "microdata_copy.csv", MIN_CELL)
        except PermissionError:
            refused += 1
        leak = moments.head(3).copy()
        leak["n_unweighted"], leak["value"] = 5, 1.0
        try:
            write_aggregate_table(leak, out_dir, "hfcs_moments.csv", MIN_CELL)
        except PermissionError:
            refused += 1
        check("the writer refuses a household-level frame, an unknown file name and an unsuppressed small cell", refused == 3)
        show = moments.query("country == 'FR' and wave == '2021' and group == 'all' and moment in "
                             "['htm_kvw_poor', 'htm_kvw_wealthy', 'htm_model_broad_total', 'networth_to_income_ratio_of_medians',"
                             " 'networth_gini', 'hardship_oecd_persons', 'mpc_mean', 'credit_constrained']")
        print("  sample of the output (synthetic numbers, FR 2021, all households):")
        print("    " + show[["moment", "value", "se", "n_unweighted"]].round(4).to_string(index=False).replace("\n", "\n    "))
        print(f"  moments table: {len(moments)} rows, {moments['moment'].nunique()} moments, "
              f"{int(moments['suppressed'].sum())} suppressed cells")
    failed = [name for name, ok in checks if not ok]
    print(f"SELF-TEST {'PASSED' if not failed else 'FAILED'}: {len(checks) - len(failed)} of {len(checks)} checks")
    return 0 if not failed else 1


# =============================================================================
# 7. COMMAND LINE
# =============================================================================


def main():
    parser = argparse.ArgumentParser(description="HFCS moments for the SAGE model (aggregate output only).")
    parser.add_argument("outdir", nargs="?", help="directory for the aggregate tables")
    parser.add_argument("--waves", nargs="+", default=WAVES, help="waves to process (default: all found)")
    parser.add_argument("--countries", nargs="+", default=COUNTRIES)
    parser.add_argument("--nrep", type=int, default=DEFAULT_NREP, help="replicate weights used for standard errors")
    parser.add_argument("--min-cell", type=int, default=MIN_CELL, help="minimum unweighted households per cell")
    parser.add_argument("--selftest", action="store_true", help="run on synthetic data and exit")
    args = parser.parse_args()
    if args.selftest:
        sys.exit(selftest())
    if not args.outdir:
        parser.error("OUTDIR is required (or use --selftest)")
    if args.min_cell < MIN_CELL:
        parser.error(f"--min-cell cannot be set below {MIN_CELL}")
    run(HFCS_DIR, os.path.abspath(os.path.expanduser(args.outdir)), [str(w) for w in args.waves],
        [c.upper() for c in args.countries], args.nrep, args.min_cell)


if __name__ == "__main__":
    main()

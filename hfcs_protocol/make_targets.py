"""Select from the aggregate HFCS moment table (written by hfcs_moments.py in the
private folder) the moments the model uses, and write them to data/hfcs_targets.csv.

Aggregates only: every row is a weighted statistic over at least 30 households,
with its standard error (replicate weights and multiple imputation). No
household-level information leaves the private folder.

Source to be cited with any use: Eurosystem Household Finance and Consumption
Survey. This paper uses data from the Eurosystem Household Finance and
Consumption Survey.

    python3 hfcs_protocol/make_targets.py [~/hfcs_secure/out]
"""
import os, sys
import pandas as pd

src = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/hfcs_secure/out")
m = pd.read_csv(os.path.join(src, "hfcs_moments.csv"), dtype={"wave": str})
m = m[~m["suppressed"] & m["value"].notna() & (m["n_unweighted"] >= 30)]

NATIONAL = [
    "htm_kvw_poor", "htm_kvw_wealthy", "htm_kvw_total",
    "htm_model_narrow_poor", "htm_model_narrow_wealthy", "htm_model_narrow_total",
    "htm_model_broad_poor", "htm_model_broad_wealthy", "htm_model_broad_total",
    "mpc_mean", "mpc_median", "mpc_share_zero", "mpc_share_half", "mpc_share_all",
    "median_income_gross", "median_income_disposable", "median_liquid_kvw", "median_liquid_broad", "median_networth",
    "liquid_kvw_to_disposable_income_ratio_of_medians", "liquid_broad_to_disposable_income_ratio_of_medians",
    "illiquid_broad_to_disposable_income_ratio_of_medians", "networth_to_disposable_income_ratio_of_medians",
    "networth_to_income_ratio_of_medians", "liquid_kvw_to_income_ratio_of_medians", "liquid_broad_to_income_ratio_of_medians",
    "networth_gini", "networth_top10_share",
    "income_poor50_disp_persons", "income_poor60_disp_persons", "asset_poor_disp_persons", "hardship_disp_persons",
    "asset_poor_oecd_persons", "hardship_oecd_persons",
    "disposable_over_gross_aggregate", "after_tax_income_from_euromod",
    "home_ownership_rate", "share_any_illiquid", "share_with_mortgage", "credit_constrained",
    "consumption_to_income_aggregate", "illiquid_to_liquid_broad_ratio_of_medians",
]
BY_GROUP = {
    "liquid_quintile": ["mpc_mean"],
    "htm_status": ["mpc_mean"],
    "education": ["mpc_mean", "htm_model_narrow_total", "htm_model_broad_total", "htm_kvw_total",
                  "liquid_kvw_to_disposable_income_ratio_of_medians", "networth_to_disposable_income_ratio_of_medians",
                  "income_poor50_disp_persons", "asset_poor_disp_persons"],
    "labour": ["mpc_mean", "htm_model_narrow_total", "htm_model_broad_total", "asset_poor_disp_persons", "income_poor50_disp_persons",
               "liquid_kvw_to_disposable_income_ratio_of_medians", "median_income_disposable"],
    # the model's population: households in the labour force, and the not retired (2026-10-08)
    "labour_force": ["mpc_mean", "htm_model_narrow_total", "htm_model_narrow_poor", "htm_model_narrow_wealthy", "htm_model_broad_total",
                     "liquid_kvw_to_disposable_income_ratio_of_medians", "liquid_broad_to_disposable_income_ratio_of_medians",
                     "median_income_disposable", "median_liquid_kvw", "income_poor50_disp_persons", "networth_to_disposable_income_ratio_of_medians",
                     "networth_gini", "networth_top10_share"],
    "not_retired": ["mpc_mean", "htm_model_narrow_total", "htm_model_narrow_poor", "htm_model_narrow_wealthy", "htm_model_broad_total",
                    "liquid_kvw_to_disposable_income_ratio_of_medians", "liquid_broad_to_disposable_income_ratio_of_medians",
                    "median_income_disposable", "median_liquid_kvw", "income_poor50_disp_persons", "networth_to_disposable_income_ratio_of_medians",
                    "networth_gini", "networth_top10_share"],
    "education_lf": ["mpc_mean", "htm_model_narrow_total", "htm_model_broad_total", "liquid_kvw_to_disposable_income_ratio_of_medians"],
    "education_nr": ["mpc_mean", "htm_model_narrow_total", "htm_model_broad_total", "liquid_kvw_to_disposable_income_ratio_of_medians"],
    "region": ["htm_model_narrow_total", "htm_model_broad_total", "asset_poor_disp_persons", "income_poor50_disp_persons",
               "hardship_disp_persons", "mpc_mean", "median_liquid_broad", "median_networth"],
    "macro_region": ["htm_model_narrow_total", "htm_model_broad_total", "asset_poor_disp_persons", "income_poor50_disp_persons",
                     "hardship_disp_persons", "mpc_mean", "median_liquid_broad", "median_networth"],
    "degurba": ["htm_model_narrow_total", "htm_model_broad_total", "asset_poor_disp_persons", "income_poor50_disp_persons", "mpc_mean"],
}
keep = (m["group_var"] == "all") & m["moment"].isin(NATIONAL)
for gv, moms in BY_GROUP.items():
    keep |= (m["group_var"] == gv) & m["moment"].isin(moms)
out = m[keep][["moment", "country", "wave", "group_var", "group", "value", "se", "n_unweighted"]].copy()
out["value"] = out["value"].round(5); out["se"] = out["se"].round(5)
out = out.sort_values(["moment", "group_var", "country", "wave", "group"])
here = os.path.dirname(os.path.abspath(__file__))
path = os.path.join(here, "..", "data", "hfcs_targets.csv")
with open(path, "w") as fh:
    fh.write("# Aggregate moments from the Eurosystem Household Finance and Consumption Survey (HFCS), waves 2010 to 2023,\n")
    fh.write("# France, Germany, Italy. Computed by hfcs_protocol/hfcs_moments.py; definitions in hfcs_protocol/HFCS_READINESS.md.\n")
    fh.write("# Weighted, five implicates combined by Rubin's rules, standard errors from 200 replicate weights. Cells under 30\n")
    fh.write("# households are not reported. No household-level data. Source: Eurosystem Household Finance and Consumption Survey.\n")
    out.to_csv(fh, index=False)
print(len(out), "rows written to", os.path.normpath(path))
print(out[out.group_var == "all"].groupby("moment").size().shape[0], "national moments;", (out.group_var != "all").sum(), "group rows")

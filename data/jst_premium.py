"""The illiquid return premium for the two-asset switch: the real total return
on housing less the real bill rate, arithmetic mean over 1980-2015, from the
Jorda-Schularick-Taylor Macrohistory Database R6, the data behind Jorda, Knoll,
Kuvshinov, Schularick and Taylor (2019), "The Rate of Return on Everything,
1870-2015", Quarterly Journal of Economics 134(3). The dataset is not
redistributed here; download it from macrohistory.net (JSTdatasetR6.xlsx) and
pass its path.

    python3 data/jst_premium.py path/to/JSTdatasetR6.xlsx

Real returns: (1 + nominal) / (1 + CPI inflation) - 1. Housing total return
includes the rental yield, which the model has no housing services to absorb,
so the premium is an upper reading of what illiquid wealth earns.
"""
import sys
import pandas as pd

df = pd.read_excel(sys.argv[1]).sort_values(["iso", "year"])
df["infl"] = df.groupby("iso")["cpi"].pct_change()
for iso, code in (("FRA", "FR"), ("DEU", "DE"), ("ITA", "IT"), ("USA", "US")):
    for lo, hi in ((1980, 2015), (1950, 2015)):
        y = df[(df.iso == iso) & (df.year >= lo) & (df.year <= hi)]
        rb = (1 + y.bill_rate) / (1 + y.infl) - 1
        rh = (1 + y.housing_tr) / (1 + y.infl) - 1
        ok = rb.notna() & rh.notna()
        print(f"{code} {lo}-{hi}: real bills {rb[ok].mean():.4f}, real housing {rh[ok].mean():.4f}, "
              f"premium {(rh[ok] - rb[ok]).mean():.4f} ({ok.sum()} years)")

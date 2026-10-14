"""The weights the OECD Better Life Index's users gave the eleven topics, by country of the user.

The old Better Life Index site (oecdbetterlifeindex.org, replaced in 2025 by the Well-being Data
Monitor) served the averages of all indexes users had created and shared through its own data feed,
https://www.oecdbetterlifeindex.org/bli/rest/indexes/stats/country, which drew the map on its
"responses" page (one row per country: the mean share of the total weight each topic received,
and the number of responses). The feed no longer answers; the Internet Archive kept copies from
2014 to 2024. This script reads two of them and writes France, Germany, Italy and the total.

A user rated each topic from 0 to 10 (5 by default); a topic's weight is its rating over the sum
of the ratings, so equal ratings give 1/11 = 9.1% each. The users choose themselves: they are not
a sample of the population (40% of them were aged 15 to 24 on the archived age feed of 2023).

    python3 data/wellbeing/bli_user_weights.py
"""
import csv, io, os, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
FEED = "https://www.oecdbetterlifeindex.org/bli/rest/indexes/stats/country"
SNAPSHOTS = ["20200527142915", "20240220215945"]          # the last before the thesis's year of use, and the last archived
TOPICS = {"HS": "health", "SW": "life satisfaction", "ES": "education", "WL": "work-life balance", "PS": "safety",
          "HO": "housing", "EQ": "environment", "JE": "jobs", "IW": "income", "SC": "community", "CG": "civic engagement"}
KEEP = ["FRA", "DEU", "ITA", "TOTAL"]

out = []
for ts in SNAPSHOTS:
    url = f"https://web.archive.org/web/{ts}id_/{FEED}"
    text = urllib.request.urlopen(url, timeout=120).read().decode("utf-8")
    for r in csv.DictReader(io.StringIO(text), delimiter="\t"):
        if r["country"] not in KEEP: continue
        for k, name in TOPICS.items():
            out.append([ts[:8], r["country"], name, round(float(r[k]), 5), int(r["numResponses"])])

with open(os.path.join(HERE, "bli_user_weights.csv"), "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n")
    w.writerow(["# OECD Better Life Index, users' shared indexes, mean weight by topic and country of the user; "
                "source: the site's feed bli/rest/indexes/stats/country as archived by the Internet Archive on the date given. "
                "Script: data/wellbeing/bli_user_weights.py"])
    w.writerow(["snapshot", "country", "topic", "mean_weight", "responses"])
    w.writerows(out)
print(len(out), "rows")

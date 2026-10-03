"""Stylised-question checks on the diary-based QBAR, from documents read in full text.

    python3 qbar_crosschecks.py        (after pull_time_use.py)

Converts hours per volunteer reported by national surveys into the model's unit (share of the employed
committed time, AC1A + AC3 + AC41 + AC42, HETUS wave 2010) and writes qbar_crosschecks.csv.
"""
import csv, os
from estat import write_csv

HERE = os.path.dirname(os.path.abspath(__file__))
D = {}
with open(os.path.join(HERE, "qbar_from_data.csv")) as fh:
    for r in csv.DictReader(fh):
        if r["indicator"] == "committed_time_employed" and r["year"] == "2010":
            D[r["country"]] = float(r["value"])
PW = ("Prouteau and Wolff 2004, Donner son temps: les benevoles dans la vie associative, Economie et Statistique 372, Tableau 1, p. 10 "
      "(INSEE enquete Vie associative, October 2002, ages 15+; a 40-week associative year by the authors' convention)")
IS = ("ISTAT 2014, Attivita gratuite a beneficio di altri, Anno 2013, Prospetto 3, p. 7 and Prospetto 2, p. 4 "
      "(ages 14+, four weeks before the interview)")
FW = ("BMFSFJ 2021, Freiwilliges Engagement in Deutschland: Zentrale Ergebnisse des Fuenften Deutschen Freiwilligensurveys (FWS 2019), "
      "p. 31 and Abbildung 6-1 (volunteers aged 14+, most time-consuming activity)")
DOC, DER = "VERIFIED (document read, value transcribed)", "DERIVED"
rows = []
add = lambda ind, c, g, y, v, u, s, st: rows.append((ind, c, "national", g, y, v, u, s, st))
for c in D:
    add("committed_time_employed", c, "employed, FT and PT weighted", 2010, round(D[c], 2), "minutes per day", "qbar_from_data.csv", DER)
    add("QBAR_0.10_in_hours_per_week", c, "employed", 2010, round(0.10 * D[c] * 7 / 60, 2), "hours per week", "0.10 x committed time x 7 / 60", DER)
    add("QBAR_0.10_in_hours_per_year", c, "employed", 2010, round(0.10 * D[c] * 365 / 60, 1), "hours per year", "0.10 x committed time x 365 / 60", DER)
# France
add("volunteering_12m_rate", "FR", "ages 15+", 2002, 27.6, "percent", PW, DOC)
add("hours_per_volunteer_per_year", "FR", "all volunteers 15+", 2002, 99.9, "hours per year", PW, DOC)
add("hours_per_volunteer_per_year", "FR", "regular volunteers (12.1 percent of population)", 2002, 175.9, "hours per year", PW, DOC)
add("hours_per_volunteer_per_year", "FR", "occasional volunteers (18.6 percent of population)", 2002, 33.0, "hours per year", PW, DOC)
add("share_of_volunteers_6h_or_more_per_week", "FR", "all volunteers 15+", 2002, 11, "percent", PW.replace("Tableau 1, p. 10", "text, p. 9"), DOC)
for g, h in (("all volunteers 15+", 99.9), ("regular volunteers", 175.9), ("occasional volunteers", 33.0)):
    add("qbar_stylised", "FR", g, 2002, round(h * 60 / 365 / D["FR"], 4), "share of committed time", "hours per year x 60 / 365 / committed time (wave 2010)", DER)
# Italy
add("hours_per_volunteer_4w", "IT", "employed, organised volunteering", 2013, 15.1, "hours in four weeks", IS, DOC)
add("hours_per_volunteer_4w", "IT", "all, organised volunteering", 2013, 18.6, "hours in four weeks", IS, DOC)
add("organised_volunteering_4w_rate", "IT", "employed", 2013, 9.1, "percent", IS, DOC)
q4 = 15.1 * 60 / 28 / D["IT"]
add("qbar_stylised_per_4w_active_volunteer", "IT", "employed, organised volunteering", 2013, round(q4, 4), "share of committed time",
    "hours in four weeks x 60 / 28 / committed time: per volunteer ACTIVE in the four weeks (upper bound for a twelve-month participant)", DER)
add("qbar_stylised_per_12m_participant", "IT", "employed, organised volunteering", 2013, round(q4 * 9.1 / 12.6, 4), "share of committed time",
    "the same x four-week rate of the employed (9.1) / EU-SILC 2015 twelve-month rate, ages 25-64 (12.6): two surveys, indicative", DER)
# Germany
add("share_of_volunteers_up_to_2h_per_week", "DE", "volunteers 14+", 2019, 60.0, "percent", FW, DOC)
add("share_of_volunteers_6h_or_more_per_week", "DE", "volunteers 14+", 2019, 17.1, "percent", FW, DOC)
add("share_of_volunteers_3_to_5h_per_week", "DE", "volunteers 14+", 2019, 22.9, "percent", "100 - 60.0 - 17.1", DER)
add("qbar_stylised_at_2h_per_week", "DE", "upper bound for the median volunteer", 2019, round(2 * 60 / 7 / D["DE"], 4), "share of committed time",
    "2 hours a week / committed time: 60.0 percent of volunteers are at or below this", DER)
add("qbar_stylised_illustrative_mean", "DE", "volunteers 14+", 2019, round((0.6 * 1 + 0.229 * 4 + 0.171 * 8) * 60 / 7 / D["DE"], 4), "share of committed time",
    "ASSUMED band means of 1, 4 and 8 hours a week (the report gives bands, no mean)", "DERIVED FROM AN ASSUMPTION, mean hours UNVERIFIED")
write_csv(os.path.join(HERE, "qbar_crosschecks.csv"), rows)
for r in rows:
    if r[0].startswith("qbar") or r[0].startswith("QBAR"):
        print(r[1], r[0], "|", r[3], "|", r[5], r[6])

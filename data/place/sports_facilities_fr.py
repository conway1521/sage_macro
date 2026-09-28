"""France: sports facilities by degree of urbanisation and date of entry into service.

    python3 data/place/sports_facilities_fr.py

Question: does community infrastructure that PREDATES today's volunteering line up
with volunteering by place? If the rural/cities ratio of old facilities is close to
the formal volunteering ratio (EU-SILC 2015: rural 27.7 / cities 20.3 = 1.36), the
place gradient in volunteering could be inherited infrastructure rather than a
response to current conditions.

Inputs (downloaded into data/place/raw/, not committed):
  res_data_es_20260927.csv  Ministere des Sports, "Data ES - Recensement des
      equipements sportifs et lieux de pratique (Complet)", column subset exported
      from https://equipements.sports.gouv.fr/api/explore/v2.1/catalog/datasets/
      data-es/exports/csv (Licence Ouverte 2.0). One row per sports facility
      (equipement), with commune INSEE code (new_code), year of entry into service
      (equip_service_date) and period of entry into service (equip_service_periode).
  fichier_diffusion_2025.xlsx  INSEE grille communale de densite 2025, sheet
      'Maille communale': CODGEO, DENS (1 dense urban = cities, 2 intermediate =
      towns and suburbs, 3 rural), PMUN22 municipal population 2022.

Dating rule. The exact year is used when present. Otherwise the period is used.
The periods are Avant 1945, 1945-1964, 1965-1974, 1975-1984, 1985-1994, 1995-2004,
A partir de 2005, so "before 1975" and "before 1985" are exact, but "before 1990"
is not identified for undated facilities in the 1985-1994 period. Those are
allocated half to before 1990 (uniform within the decade), and the lower bound
(none of them) and upper bound (all of them) are also reported. A facility with
neither a year nor a period is "unknown". Survivorship: the census lists
facilities that exist today, so "entered service before 1990" means "built before
1990 and still standing and recorded", not the stock that existed in 1990.

Output: data/place/sports_facilities_fr.csv
"""
import csv, os, collections, openpyxl

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
RES = os.path.join(RAW, "res_data_es_20260927.csv")
VOL_RATIO = 27.7 / 20.3  # EU-SILC 2015 formal volunteering, rural / cities

# density grid
wb = openpyxl.load_workbook(os.path.join(RAW, "fichier_diffusion_2025.xlsx"), read_only=True)
ws = wb["Maille communale"]
dens, pop = {}, {}
for row in ws.iter_rows(min_row=6, values_only=True):
    if not row[0]:
        continue
    dens[str(row[0])] = int(row[2]); pop[str(row[0])] = float(row[4])
popc = collections.Counter()
for c, d in dens.items():
    popc[d] += pop[c]


def commune(code):
    """Map PLM arrondissement codes to their commune code."""
    if not code.isdigit():
        return code
    if code.startswith("751") and 75101 <= int(code) <= 75120:
        return "75056"
    if code.startswith("6938") and 69381 <= int(code) <= 69389:
        return "69123"
    if code.startswith("132") and 13201 <= int(code) <= 13216:
        return "13055"
    return code


PERIOD_END = {"Avant 1945": 1944, "1945-1964": 1964, "1965-1974": 1974,
              "1975-1984": 1984, "1985-1994": 1994, "1995-2004": 2004,
              "A partir de 2005": 9999}

# counters by class
tot = collections.Counter()
pre75 = collections.Counter()
pre85 = collections.Counter()
pre90 = collections.Counter()      # central: half of undated 1985-1994
pre90_lo = collections.Counter()   # none of undated 1985-1994
pre90_hi = collections.Counter()   # all of undated 1985-1994
unknown = collections.Counter()
exact_year = collections.Counter()
unmatched = collections.Counter()
nrows = 0

with open(RES, newline="", encoding="utf-8-sig") as fh:
    for row in csv.DictReader(fh, delimiter=";"):
        nrows += 1
        code = commune(row["new_code"].strip())
        cls = dens.get(code)
        if cls is None:
            # about 840 rows carry new_code 'None'; the installation number
            # (I + INSEE code + 4 digits) still carries the commune code
            cls = dens.get(commune(row["inst_numero"][1:6]))
        if cls is None:
            unmatched[row["new_code"][:2] or "blank"] += 1
            continue
        tot[cls] += 1
        d, p = row["equip_service_date"].strip(), row["equip_service_periode"].strip()
        if d.isdigit():
            y = int(d); exact_year[cls] += 1
            a75, a85, a90 = y < 1975, y < 1985, y < 1990
            lo = hi = mid = a90
        elif p in PERIOD_END:
            e = PERIOD_END[p]
            a75, a85 = e <= 1974, e <= 1984
            if p == "1985-1994":
                lo, hi, mid = 0, 1, 0.5
            else:
                lo = hi = mid = e <= 1984
        else:
            unknown[cls] += 1
            continue
        pre75[cls] += a75; pre85[cls] += a85
        pre90[cls] += mid; pre90_lo[cls] += lo; pre90_hi[cls] += hi

names = {1: "cities", 2: "towns", 3: "rural"}
rows = [
    ("all facilities", tot),
    ("entered service before 1990 (central)", pre90),
    ("before 1990, lower bound", pre90_lo),
    ("before 1990, upper bound", pre90_hi),
    ("entered service before 1985 (exact)", pre85),
    ("entered service before 1975 (exact)", pre75),
    ("unknown date", unknown),
]
out = os.path.join(HERE, "sports_facilities_fr.csv")
with open(out, "w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["measure", "place", "facilities", "population", "per_1000",
                "share_of_all", "rural_over_cities"])
    print(f"RES rows: {nrows}, matched to the 2025 grid: {sum(tot.values())}, "
          f"unmatched: {sum(unmatched.values())} {dict(unmatched.most_common(6))}")
    print("population (millions): " + ", ".join(f"{names[k]} {popc[k]/1e6:.1f}" for k in (1, 2, 3)))
    print(f"{'facilities per 1,000 inhabitants':38s} {'cities':>7s} {'towns':>7s} {'rural':>7s}  rural/cities")
    for label, c in rows:
        v = {k: 1000 * c[k] / popc[k] for k in (1, 2, 3)}
        ratio = v[3] / v[1]
        for k in (1, 2, 3):
            w.writerow([label, names[k], round(c[k], 1), int(popc[k]), round(v[k], 4),
                        round(c[k] / tot[k], 4), round(ratio, 3)])
        print(f"{label:38s} {v[1]:7.3f} {v[2]:7.3f} {v[3]:7.3f}  {ratio:6.2f}")
    print("share with unknown date: " + ", ".join(
        f"{names[k]} {100*unknown[k]/tot[k]:.1f}%" for k in (1, 2, 3)))
    print("share dated to an exact year: " + ", ".join(
        f"{names[k]} {100*exact_year[k]/tot[k]:.1f}%" for k in (1, 2, 3)))
    print("share of all facilities built before 1990 (central): " + ", ".join(
        f"{names[k]} {100*pre90[k]/tot[k]:.1f}%" for k in (1, 2, 3)))
    print(f"formal volunteering rural/cities (EU-SILC 2015): 27.7/20.3 = {VOL_RATIO:.2f}")

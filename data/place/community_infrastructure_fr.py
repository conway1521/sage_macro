"""France: community infrastructure by degree of urbanisation (the omega-by-place test).

    python3 data/place/community_infrastructure_fr.py

Inputs (INSEE, downloaded into data/place/raw/, not committed):
  DS_BPE_2025_data.csv   Base permanente des equipements 2025, facilities by commune
  fichier_diffusion_2025.xlsx   grille communale de densite 2025 (3 classes, which
      match Eurostat's degree of urbanisation: dense urban = cities, intermediate
      urban = towns and suburbs, rural = rural areas), municipal population 2022
Output: data/place/community_infrastructure_fr.csv, facilities per 1,000
inhabitants by class and facility group.
"""
import csv, os, collections, openpyxl

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")

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

GROUPS = {
    "sports (F1)": lambda t, s, d: s == "F1",
    "leisure (F2)": lambda t, s, d: s == "F2",
    "culture and socio-culture (F3)": lambda t, s, d: s == "F3",
    "libraries (F307)": lambda t, s, d: t == "F307",
    "all sport, leisure, culture (F)": lambda t, s, d: d == "F",
    "health and social action (D)": lambda t, s, d: d == "D",
    "general practitioners (D265)": lambda t, s, d: t == "D265",
    "France services (A128)": lambda t, s, d: t == "A128",
    "public employment service (A122)": lambda t, s, d: t == "A122",
    "all facilities": lambda t, s, d: True,
}
count = collections.defaultdict(collections.Counter)
miss = 0
with open(os.path.join(RAW, "bpe_all", "DS_BPE_2025_data.csv"), newline="") as fh:
    r = csv.DictReader(fh, delimiter=";")
    for row in r:
        if row["GEO_OBJECT"] != "COM" or row["BPE_MEASURE"] != "FACILITIES":
            continue
        t, s, d = row["FACILITY_TYPE"], row["FACILITY_SDOM"], row["FACILITY_DOM"]
        if t == "_T" or s == "_T" or d == "_T":
            continue
        cls = dens.get(row["GEO"])
        if cls is None:
            miss += 1; continue
        n = float(row["OBS_VALUE"])
        for g, f in GROUPS.items():
            if f(t, s, d):
                count[g][cls] += n

names = {1: "cities", 2: "towns", 3: "rural"}
out = os.path.join(HERE, "community_infrastructure_fr.csv")
with open(out, "w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["group", "place", "facilities", "population", "per_1000"])
    print(f"population (millions): " + ", ".join(f"{names[k]} {popc[k]/1e6:.1f}" for k in (1, 2, 3)))
    print(f"{'facilities per 1,000 inhabitants':34s} {'cities':>8s} {'towns':>8s} {'rural':>8s}  rural/cities")
    for g in GROUPS:
        v = {k: 1000 * count[g][k] / popc[k] for k in (1, 2, 3)}
        for k in (1, 2, 3):
            w.writerow([g, names[k], int(count[g][k]), int(popc[k]), round(v[k], 4)])
        print(f"{g:34s} {v[1]:8.3f} {v[2]:8.3f} {v[3]:8.3f}  {v[3]/v[1]:6.2f}")
print(f"(rows with a commune code not in the grid: {miss})")

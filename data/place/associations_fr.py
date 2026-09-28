"""France: registered associations by degree of urbanisation (community fabric).

    python3 data/place/associations_fr.py

Inputs (data/place/raw/, not committed):
  rna_waldec_20260901.zip  Repertoire national des associations, Ministere de
      l'Interieur (data.gouv.fr): associations declared or updated since 2009,
      located by the INSEE code of the seat's commune
  rna_import_20260901.zip  the pre-2009 register, located by postcode only
  laposte_hexasmal.csv     La Poste, postcode to commune
  fichier_diffusion_2025.xlsx  INSEE density grid 2025 and population 2022
Associations are counted if their status is active ('A'). A registered
association is not necessarily a living one: nothing obliges dormant ones to
dissolve. A liveness proxy, declared or updated since 2015, is also reported.
Postcodes shared by several communes are split in proportion to population.
Output: data/place/associations_fr.csv.
"""
import csv, io, os, zipfile, collections, openpyxl

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")

ws = openpyxl.load_workbook(os.path.join(RAW, "fichier_diffusion_2025.xlsx"), read_only=True)["Maille communale"]
dens, pop = {}, {}
for row in ws.iter_rows(min_row=6, values_only=True):
    if row[0]:
        dens[str(row[0])] = int(row[2]); pop[str(row[0])] = float(row[4])
popc = collections.Counter()
for c, d in dens.items():
    popc[d] += pop[c]


def city_of(code):
    """Paris, Lyon and Marseille arrondissements to their commune."""
    if code.startswith("751") and len(code) == 5 and "75101" <= code <= "75120":
        return "75056"
    if "69381" <= code <= "69389":
        return "69123"
    if "13201" <= code <= "13216":
        return "13055"
    return code

# postcode -> {class: population weight}
pc = collections.defaultdict(collections.Counter)
with open(os.path.join(RAW, "laposte_hexasmal.csv"), encoding="latin-1") as fh:
    for row in csv.reader(fh, delimiter=";"):
        if not row or row[0].startswith("#"):
            continue
        code, cp = city_of(row[0]), row[2]
        if code in dens:
            pc[cp][dens[code]] += pop[code]
pcw = {cp: {k: v / sum(c.values()) for k, v in c.items()} for cp, c in pc.items() if sum(c.values()) > 0}

count = collections.defaultdict(collections.Counter)
unplaced = collections.Counter()


def place(weights, groups):
    for g in groups:
        for k, w in weights.items():
            count[g][k] += w


def groups_of(obj, live):
    g = ["all active"]
    if obj.startswith("011"):
        g.append("sports")
    if live:
        g.append("active and declared or updated since 2015")
    return g


z = zipfile.ZipFile(os.path.join(RAW, "rna_waldec_20260901.zip"))
for name in z.namelist():
    with z.open(name) as fh:
        for row in csv.DictReader(io.TextIOWrapper(fh, encoding="utf-8-sig", errors="replace"), delimiter=";"):
            if row["position"] != "A":
                continue
            live = max(row["date_decla"], row["maj_time"][:10]) >= "2015-01-01"
            code = city_of(row["adrs_codeinsee"].strip())
            if code in dens:
                w = {dens[code]: 1.0}
            elif row["adrs_codepostal"].strip() in pcw:
                w = pcw[row["adrs_codepostal"].strip()]
            else:
                unplaced["waldec"] += 1; continue
            place(w, groups_of(row["objet_social1"], live))
z = zipfile.ZipFile(os.path.join(RAW, "rna_import_20260901.zip"))
for name in z.namelist():
    with z.open(name) as fh:
        for row in csv.DictReader(io.TextIOWrapper(fh, encoding="utf-8-sig", errors="replace"), delimiter=";"):
            if row["position"] != "A":
                continue
            live = row["maj_time"][:10] >= "2015-01-01"
            cp = row["adrs_codepostal"].strip()
            if cp not in pcw:
                unplaced["import"] += 1; continue
            place(pcw[cp], groups_of(row["objet_social1"], live))

names = {1: "cities", 2: "towns", 3: "rural"}
with open(os.path.join(HERE, "associations_fr.csv"), "w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["group", "place", "associations", "population", "per_1000"])
    print(f"{'associations per 1,000 inhabitants':42s} {'cities':>8s} {'towns':>8s} {'rural':>8s}  rural/cities")
    for g in count:
        v = {k: 1000 * count[g][k] / popc[k] for k in (1, 2, 3)}
        for k in (1, 2, 3):
            w.writerow([g, names[k], round(count[g][k]), int(popc[k]), round(v[k], 3)])
        print(f"{g:42s} {v[1]:8.2f} {v[2]:8.2f} {v[3]:8.2f}  {v[3]/v[1]:6.2f}")
print("not placed:", dict(unplaced))

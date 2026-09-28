"""Write data/MANIFEST.csv: every raw input file kept out of git, with its
checksum, size, original source and licence, and the GitHub release that
holds a copy.

    python3 data/make_manifest.py [release-tag]

Run it after adding or refreshing a raw file, then publish the files with
scripts/data_release.sh. data/fetch_data.sh reads the manifest to restore
them on any machine. Confidential data (HFCS) never appear here.
"""
import csv, hashlib, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TAG = sys.argv[1] if len(sys.argv) > 1 else "data-2026.09"

# (path relative to the repo, how to unpack, source, licence)
FILES = [
    *[(f"data/scf/scfp{y}excel.zip", "unzip", "https://www.federalreserve.gov/econres/scfindex.htm",
       "US federal government work, public domain") for y in range(1989, 2023, 3)],
    ("data/scf/bulletin.macro.txt", "", "https://www.federalreserve.gov/econres/scfindex.htm",
     "US federal government work, public domain"),
    ("data/place/raw/DS_BPE_CSV_FR.zip", "unzip:bpe_all",
     "https://www.insee.fr/fr/statistiques/8217527", "Licence Ouverte 2.0 (Etalab), INSEE"),
    ("data/place/raw/DS_BPE_SPORT_CULTURE_CSV_FR.zip", "unzip:bpe_sport",
     "https://www.insee.fr/fr/statistiques/8217527", "Licence Ouverte 2.0 (Etalab), INSEE"),
    ("data/place/raw/fichier_diffusion_2025.xlsx", "",
     "https://www.insee.fr/fr/information/8571524", "Licence Ouverte 2.0 (Etalab), INSEE"),
    ("data/place/raw/rna_waldec_20260901.zip", "",
     "https://www.data.gouv.fr/datasets/repertoire-national-des-associations/",
     "Licence Ouverte 2.0 (Etalab), Ministere de l'Interieur"),
    ("data/place/raw/rna_import_20260901.zip", "",
     "https://www.data.gouv.fr/datasets/repertoire-national-des-associations/",
     "Licence Ouverte 2.0 (Etalab), Ministere de l'Interieur"),
    ("data/place/raw/laposte_hexasmal.csv", "",
     "https://www.data.gouv.fr/datasets/base-officielle-des-codes-postaux/",
     "Licence Ouverte 2.0 (Etalab), La Poste"),
    ("data/place/raw/istat_bes_local_2024.zip", "",
     "https://www.istat.it/en/news/bes-at-local-level-2024-edition/", "Istat, reuse with attribution (CC BY)"),
    ("data/place/raw/istat_vol2023.pdf", "",
     "https://www.istat.it/wp-content/uploads/2025/07/REPORT_Il-volontariato-in-Italia_anno-2023.pdf",
     "Istat, reuse with attribution (CC BY)"),
]


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


rows = []
for rel, unpack, source, licence in FILES:
    p = os.path.join(ROOT, rel)
    if not os.path.isfile(p):
        print(f"missing, skipped: {rel}")
        continue
    rows.append(dict(path=rel, asset=os.path.basename(rel), release=TAG, sha256=sha256(p),
                     bytes=os.path.getsize(p), unpack=unpack, source=source, licence=licence))
with open(os.path.join(ROOT, "data", "MANIFEST.csv"), "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0]))
    w.writeheader(); w.writerows(rows)
print(f"wrote {len(rows)} entries, {sum(r['bytes'] for r in rows) / 1e6:.0f} MB, release {TAG}")

"""Shared helper: pull a Eurostat dataset through the dissemination API (standard library only)."""
import json, time, urllib.request, urllib.error

BASE = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/"


def url_for(ds, **kw):
    q = "&".join(f"{k}={v}" for k, vs in kw.items() for v in (vs if isinstance(vs, list) else [vs]))
    return f"{BASE}{ds}?format=JSON&lang=EN" + ("&" + q if q else "")


def raw(ds, **kw):
    url = url_for(ds, **kw)
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            return json.load(urllib.request.urlopen(req, timeout=180))
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")[:400]
            if e.code in (400, 404):
                raise RuntimeError(f"{ds}: HTTP {e.code} {body}")
            if attempt == 3:
                raise
        except Exception:
            if attempt == 3:
                raise
        time.sleep(5 * (attempt + 1))


def get(ds, **kw):
    """Rows as (labels dict, value, flag). Flags come from the 'status' block (b, u, e, ...)."""
    d = raw(ds, **kw)
    dims, sz = d["id"], d["size"]
    lab = {k: {i: v for v, i in d["dimension"][k]["category"]["index"].items()} for k in dims}
    status = d.get("status", {})
    out = []
    for flat, val in d["value"].items():
        f = int(flat); co = []
        for s in reversed(sz):
            co.append(f % s); f //= s
        out.append(({k: lab[k][c] for k, c in zip(dims, co[::-1])}, val, status.get(flat, "")))
    return out


def dims(ds, **kw):
    d = raw(ds, **kw)
    return {k: d["dimension"][k]["category"].get("label", {}) for k in d["id"]}, d.get("label"), d.get("updated")


def hm(s):
    h, m = str(s).split(":")
    return int(h) * 60 + int(m)


COLS = ["indicator", "country", "place", "group", "year", "value", "unit", "source", "status"]
FLAG = {"": "VERIFIED", "b": "VERIFIED (break in series)", "u": "VERIFIED (low reliability flag)",
        "e": "VERIFIED (estimated)", "d": "VERIFIED (definition differs)", "p": "VERIFIED (provisional)"}


def status(flag):
    return FLAG.get(flag, f"VERIFIED (flag {flag})")


def write_csv(path, rows):
    import csv
    with open(path, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(COLS)
        w.writerows(rows)

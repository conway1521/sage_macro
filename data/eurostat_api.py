import sys, json, urllib.request
def get(ds, **kw):
    q="&".join(f"{k}={v}" for k,vs in kw.items() for v in (vs if isinstance(vs,list) else [vs]))
    d=json.load(urllib.request.urlopen(f"https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/{ds}?{q}", timeout=180))
    dims=d['id']; sz=d['size']
    lab={k:{i:v for v,i in d['dimension'][k]['category']['index'].items()} for k in dims}
    out=[]
    for flat,val in d['value'].items():
        f=int(flat); co=[]
        for s in reversed(sz): co.append(f%s); f//=s
        out.append(({k:lab[k][c] for k,c in zip(dims,co[::-1])}, val))
    return out, {k:list(lab[k].values()) for k in dims}

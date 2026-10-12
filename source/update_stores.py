"""Add new Publix stores to source/stores.json (never removes any), then rebuild if anything changed.

Runs on GitHub Actions. Reads the public Publix store locator, adds stores that aren't in the list,
fills in missing details (like a missing latitude/longitude) for stores already in the list,
bumps the patch version (2.8 -> 2.8.1), adds a version-history note, and rebuilds every edition.
"""
import json, re, subprocess, sys, urllib.request, datetime

API = ("https://services.publix.com/storelocator/api/v1/stores/"
       "?types=R,G,H,N,S&count=3000&distance=5000&includeOpenAndCloseDates=true&zip={zip}")
ZIPS = ["33801", "30303", "37203", "40202", "23219", "28202"]   # several centers so nothing is out of range
KEEP_TYPES = {"R", "G"}   # Publix supermarkets and GreenWise Market
STATES = {"FL", "GA", "AL", "SC", "NC", "TN", "VA", "KY"}

def get(zipc):
    req = urllib.request.Request(API.format(zip=zipc), headers={"User-Agent": "Mozilla/5.0 (Route2 store list updater)", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r).get("stores", [])

def pick(d, *keys):
    for k in keys:
        if isinstance(d, dict) and d.get(k) not in (None, ""):
            return d[k]
    return ""

def convert(s):
    a = s.get("address") or {}
    ph = s.get("phoneNumbers") or {}
    phone = pick(ph, "Store", "store", "Main") if isinstance(ph, dict) else (ph[0] if ph else "")
    if isinstance(phone, dict): phone = pick(phone, "number", "Number")
    return {
        "Store #": int(str(s["storeNumber"]).lstrip("0") or 0),
        "Shopping Center": s.get("name") or "",
        "Address": pick(a, "streetAddress", "address1", "line1"),
        "City": pick(a, "city"),
        "State": pick(a, "state"),
        "Zip": str(pick(a, "zip", "zipCode", "postalCode")),
        "Latitude": s.get("latitude"),
        "Longitude": s.get("longitude"),
        "Phone": phone or "",
    }

def main():
    today = datetime.date.today()
    seen = {}
    for z in ZIPS:
        try:
            for s in get(z):
                seen[str(s.get("storeNumber"))] = s
        except Exception as e:
            print("warning: could not read stores near", z, "-", e)
    if len(seen) < 1000:
        sys.exit(f"Only {len(seen)} stores came back; not trusting this run, nothing changed.")
    stores = json.load(open("source/stores.json"))
    by_num = {r["Store #"]: r for r in stores}
    added, filled = [], []
    for s in seen.values():
        if s.get("type") not in KEEP_TYPES or s.get("isEnabled") is False:
            continue
        close = (s.get("closingDate") or "")[:10]
        if close and close <= today.isoformat():
            continue
        try:
            new = convert(s)
        except Exception:
            continue
        if new["State"] not in STATES or not new["Store #"]:
            continue
        old = by_num.get(new["Store #"])
        if old is None:
            stores.append(new); by_num[new["Store #"]] = new
            added.append(f'{new["Store #"]} {new["City"]}, {new["State"]}')
        else:
            changed = False
            blank = lambda x: x in (None, "") or str(x).strip().lower() in ("not available", "n/a")
            for k, v in new.items():   # only fill blanks; never overwrite or remove
                if not blank(v) and blank(old.get(k)) and old.get(k) != v:
                    old[k] = v; changed = True
            if changed:
                filled.append(str(new["Store #"]))
    if not added and not filled:
        print("Store list is up to date:", len(stores), "stores."); return
    stores.sort(key=lambda r: r["Store #"])
    json.dump(stores, open("source/stores.json", "w"), indent=1)
    # bump patch version in build script and planner source
    b = open("source/build.py").read()
    ver = re.search(r'VER="([\d.]+)"', b).group(1)
    parts = ver.split(".") + ["0"] * (3 - len(ver.split(".")))
    parts[2] = str(int(parts[2]) + 1); nv = ".".join(parts[:3])
    open("source/build.py", "w").write(b.replace(f'VER="{ver}"', f'VER="{nv}"', 1))
    src = open("source/route-planner-source.html").read()
    src = src.replace(f'const APP_VERSION = "{ver}";', f'const APP_VERSION = "{nv}";', 1)
    note = []
    if added: note.append(f"Added {len(added)} new store{'s' if len(added) > 1 else ''}: " + "; ".join(sorted(added)) + ".")
    if filled: note.append("Filled in missing details for store" + ("s " if len(filled) > 1 else " ") + ", ".join(filled) + ".")
    src = src.replace("const CHANGELOG = [\n", "const CHANGELOG = [\n  " + json.dumps([nv, "Store list update. " + " ".join(note)], ensure_ascii=False) + ",\n", 1)
    open("source/route-planner-source.html", "w").write(src)
    subprocess.run(["git", "rm", "-q", "--ignore-unmatch"] + [f"planners/{f}" for f in __import__("os").listdir("planners") if re.search(r"-v[\d.]+\.html$", f)], check=True)
    subprocess.run([sys.executable, "source/build.py"], check=True)
    open("README.md", "w").write(re.sub(r"\*\*Current version: [\d.]+\*\*", f"**Current version: {nv}**", open("README.md").read()))
    msg = f"Store list update {nv}: " + " ".join(note)
    open(".store-update-msg", "w").write(msg)
    print(msg)

if __name__ == "__main__":
    main()

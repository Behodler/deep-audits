import json, re, sys, collections
cur_p, prev_p = sys.argv[1], sys.argv[2]
cur, prev = json.load(open(cur_p)), json.load(open(prev_p))
def norm(d):
    d = re.sub(r"#\d+(-\d+)?", "#", d)
    d = re.sub(r"\b[Ll]ine \d+", "line", d)
    return re.sub(r"\s+", " ", d).strip()
def k_strict(f): return (f["contract"], f["type"], f["function"], norm(f["description"]))
def k_loose(f): return (f["contract"], f["type"], f["function"])
ps = collections.Counter(k_strict(f) for f in prev["findings"])
pl = collections.Counter(k_loose(f) for f in prev["findings"])
prev_by_strict = collections.defaultdict(list); prev_by_loose = collections.defaultdict(list)
for f in prev["findings"]:
    prev_by_strict[k_strict(f)].append(f["id"]); prev_by_loose[k_loose(f)].append(f["id"])
used = set()
# strict pass first
for f in cur["findings"]:
    k = k_strict(f)
    if ps[k] > 0:
        ps[k] -= 1; pl[k_loose(f)] -= 1
        pid = prev_by_strict[k].pop(0); used.add(pid); prev_by_loose[k_loose(f)].remove(pid)
        f["regression"] = "carried"; f["run01Id"] = pid; f["matchedBy"] = "contract+type+function+description"
for f in cur["findings"]:
    if "regression" in f: continue
    k = k_loose(f)
    if pl[k] > 0:
        pl[k] -= 1; pid = prev_by_loose[k].pop(0); used.add(pid)
        f["regression"] = "carried"; f["run01Id"] = pid; f["matchedBy"] = "contract+type+function (description/line drifted)"
    else:
        f["regression"] = "new"
# pass 3/4: run-01 rows with no/contract-level function (Aderyn test pass) -> match ignoring function
def weak(f): return (not f["function"]) or f["function"].startswith("(")
rem = [f for f in prev["findings"] if f["id"] not in used and weak(f)]
for passno, kf in ((3, lambda f: (f["contract"], f["type"], norm(f["description"]))), (4, lambda f: (f["contract"], f["type"]))):
    for f in cur["findings"]:
        if f["regression"] != "new": continue
        for r in rem:
            if r["id"] not in used and kf(r) == kf(f):
                used.add(r["id"]); f["regression"] = "carried"; f["run01Id"] = r["id"]
                f["matchedBy"] = "contract+type+description (run-01 row had no function)" if passno == 3 else "contract+type (run-01 row had no function; line drifted %s->%s)" % (r["line"], f["line"])
                break
gone = [dict(id=f["id"], contract=f["contract"], function=f["function"], line=f["line"], type=f["type"], description=f["description"][:300])
        for f in prev["findings"] if f["id"] not in used]
cur["regressionBaseline"] = {"run": "sya-harvester-01", "commit": "62c19c8", "file": prev_p,
    "new": sum(f["regression"] == "new" for f in cur["findings"]),
    "carried": sum(f["regression"] == "carried" for f in cur["findings"]),
    "notReproduced": len(gone), "notReproducedFindings": gone}
json.dump(cur, open(cur_p, "w"), indent=2)
print(json.dumps({k: v for k, v in cur["regressionBaseline"].items() if k != "notReproducedFindings"}))
for f in cur["findings"]:
    if f["regression"] == "new": print("NEW", f["id"], f["fileClass"], f["contract"], f["function"], f["line"], f["type"], f["severity"], f["sources"])
for g in gone: print("GONE", g["id"], g["contract"], g["function"], g["line"], g["type"])

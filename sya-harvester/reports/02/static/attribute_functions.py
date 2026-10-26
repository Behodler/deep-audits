import json, re, sys
fp, root = sys.argv[1], sys.argv[2]
out = json.load(open(fp)); cache = {}
def ranges(path):
    if path in cache: return cache[path]
    lines = open(f"{root}/{path}").read().split("\n"); rs = []
    hdr = re.compile(r"^\s*(function\s+(\w+)|constructor\b|receive\s*\(|fallback\s*\(|modifier\s+(\w+)|(abstract\s+)?(contract|library|interface)\s+(\w+))")
    for i, l in enumerate(lines):
        m = hdr.match(l)
        if not m: continue
        if m.group(6):
            rs.append((i+1, None, "(" + l.strip().rstrip("{").strip() + ")", True)); continue
        name = m.group(2) or m.group(3) or ("constructor" if "constructor" in l else ("receive" if "receive" in l else "fallback"))
        depth, started, j = 0, False, i
        while j < len(lines):
            for ch in lines[j]:
                if ch == "{": depth += 1; started = True
                elif ch == "}": depth -= 1
            if started and depth == 0: break
            if not started and lines[j].rstrip().endswith(";"): break
            j += 1
        rs.append((i+1, j+1, name, False))
    cache[path] = rs; return rs
n = 0
for f in out["findings"]:
    if f["function"]: continue
    rs = ranges(f["contract"]); L = f["line"]; best = None
    for s, e, name, isc in rs:
        if not isc and s <= L <= e: best = name
    if best is None:
        for s, e, name, isc in rs:
            if isc and s == L: best = name
    if best: f["function"] = best; f["functionAttributedBy"] = "line-range"; n += 1
json.dump(out, open(fp, "w"), indent=2); print("attributed", n)

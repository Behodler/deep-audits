import json, re, sys, datetime, collections

R = sys.argv[1]
SCOPE = [l.strip() for l in open(sys.argv[2]) if l.strip()]

NOISE = {
    # spec list (all tools, mapped)
    "naming-convention", "solc-version", "pragma", "assembly", "missing-zero-check", "unused-state",
    "dead-code", "constable-states", "external-function", "too-many-digits", "similar-names",
    "different-pragma",
    # aderyn equivalents of the spec list
    "unspecific-solidity-pragma", "push-zero-opcode", "large-numeric-literal", "literal-instead-of-constant",
    "state-no-address-check", "state-variable-could-be-constant", "unused-public-function",
    "internal-function-used-once", "empty-block", "storage-array-length-not-cached",
    "state-change-without-event",
}
REASON = {
    "state-change-without-event": "QA/non-critical (event hygiene); C4 non-critical",
    "unused-public-function": "dead-code/external-function equivalent",
    "internal-function-used-once": "dead-code/style equivalent",
    "empty-block": "dead-code equivalent",
    "storage-array-length-not-cached": "gas-only",
    "large-numeric-literal": "too-many-digits equivalent",
    "literal-instead-of-constant": "style (too-many-digits family)",
    "state-no-address-check": "missing-zero-check equivalent",
    "state-variable-could-be-constant": "constable-states equivalent",
    "push-zero-opcode": "pragma/EVM-version family",
    "unspecific-solidity-pragma": "pragma equivalent",
}
# cross-tool category normalisation for merge
CAT = {
    "arbitrary-send-eth": "arbitrary-send-eth", "arbitrary-low-level-call": "arbitrary-send-eth",
    "eth-send-unchecked-address": "arbitrary-send-eth", "low-level-calls": "arbitrary-send-eth",
    "incorrect-equality": "incorrect-equality", "exact-balance-check": "incorrect-equality",
    "unused-return": "unused-return", "unchecked-return": "unused-return",
    "uninitialized-local": "uninitialized-local", "uninitialized-local-variable": "uninitialized-local",
    "locked-ether": "locked-ether", "contract-locks-ether": "locked-ether",
    "missing-inheritance": "missing-inheritance",
    "reentrancy-state-change": "reentrancy-no-eth",
}
SEV = {"High": "potential-high", "Medium": "potential-medium", "Low": "potential-low"}
CONF_UP = {"low": "medium", "medium": "high", "high": "high"}

raw, filtered = [], collections.Counter()
filtered_detail = collections.defaultdict(lambda: {"count": 0, "files": set(), "reason": ""})
corroborators = []  # informational hits kept only to corroborate


def drop(source, rule, path, reason):
    k = f"{source}:{rule}"
    filtered[k] += 1
    d = filtered_detail[k]
    d["count"] += 1
    d["files"].add(path)
    d["reason"] = reason


def fclass(p):
    return "production" if p.startswith("src/") else "test"

# ---------- Slither ----------
s = json.load(open(f"{R}/slither-output.json"))
for d in s["results"]["detectors"]:
    els = [e for e in d.get("elements", []) if "source_mapping" in e]
    if not els:
        continue
    nodes = [e for e in els if e["type"] == "node"]
    main = nodes[0] if nodes else els[0]
    path = main["source_mapping"]["filename_relative"]
    line = main["source_mapping"]["lines"][0] if main["source_mapping"]["lines"] else None
    fn = None
    for e in els:
        if e["type"] == "function":
            fn = e["name"]; break
        tsp = e.get("type_specific_fields", {}).get("parent", {})
        if tsp.get("type") == "function":
            fn = tsp["name"]; break
    chk = d["check"]
    rec = dict(source="slither", rawCheck=chk, contract=path, function=fn, line=line,
               description=d["description"].strip(), confidence=d["confidence"].lower(), impact=d["impact"])
    if chk in NOISE:
        drop("slither", chk, path, REASON.get(chk, "spec noise list")); continue
    if d["impact"] in ("Informational", "Optimization"):
        if chk == "low-level-calls" and "{value:" in d["description"]:
            corroborators.append(rec)  # value transfer: keep as corroboration
        else:
            drop("slither", chk, path, f"severity {d['impact']} -> discard")
        continue
    raw.append(rec)

# ---------- Aderyn (two passes; pass-2 paths mapped back) ----------
def unmap(p):
    p = re.sub(r"^tst/", "test/", p)
    p = p.replace("test/scr/", "test/script/")
    p = re.sub(r"_t\.sol$", ".t.sol", p)
    p = re.sub(r"_s\.sol$", ".s.sol", p)
    return p

for fname in ("aderyn-report.json", "aderyn-report-tests.json"):
    a = json.load(open(f"{R}/{fname}"))
    for bucket, imp in (("high_issues", "High"), ("low_issues", "Low")):
        for iss in a.get(bucket, {}).get("issues", []):
            rule = iss["detector_name"]
            for ins in iss["instances"]:
                path = unmap(ins["contract_path"])
                if rule in NOISE:
                    drop("aderyn", rule, path, REASON.get(rule, "spec noise list")); continue
                raw.append(dict(source="aderyn", rawCheck=rule, contract=path, function=None,
                                line=ins["line_no"],
                                description=iss["title"] + (f" -- {ins['hint']}" if ins.get("hint") else "") + ". " + iss["description"][:300],
                                confidence="medium", impact=imp))

# ---------- Semgrep ----------
for fname in ("semgrep-output.json", "semgrep-decurity-security.json"):
    g = json.load(open(f"{R}/{fname}"))
    for r in g["results"]:
        rule = r["check_id"].split(".")[-1]
        sev = r["extra"]["severity"]
        path = r["path"]
        if sev == "INFO":
            drop("semgrep", rule, path, "severity INFO -> discard (p/smart-contracts perf/best-practice)"); continue
        imp = {"ERROR": "High", "WARNING": "Medium"}.get(sev, "Low")
        raw.append(dict(source="semgrep", rawCheck=r["check_id"].split("decurity.")[-1], contract=path, function=None,
                        line=r["start"]["line"], description=r["extra"]["message"][:400],
                        confidence=r["extra"].get("metadata", {}).get("confidence", "medium").lower(), impact=imp))

# ---------- merge ----------
order = {"High": 3, "Medium": 2, "Low": 1}
merged = collections.OrderedDict()
for f in raw:
    cat = CAT.get(f["rawCheck"].split(".")[-1], f["rawCheck"])
    key = (f["contract"], f["line"], cat)
    if key not in merged:
        merged[key] = dict(f, type=cat, sources=[f["source"]], rawChecks=[f["rawCheck"]], descriptions=[f["description"]])
    else:
        m = merged[key]
        if f["source"] not in m["sources"]:
            m["sources"].append(f["source"])
        if f["rawCheck"] not in m["rawChecks"]:
            m["rawChecks"].append(f["rawCheck"]); m["descriptions"].append(f["description"])
        if order[f["impact"]] > order[m["impact"]]:
            m["impact"] = f["impact"]
        if not m["function"] and f["function"]:
            m["function"] = f["function"]
for c in corroborators:
    key = (c["contract"], c["line"], "arbitrary-send-eth")
    if key in merged and "slither" in merged[key]["sources"]:
        merged[key]["rawChecks"].append(c["rawCheck"]); merged[key]["descriptions"].append(c["description"])

findings, counters = [], collections.Counter()
for (path, line, cat), m in merged.items():
    src = m["source"].upper()
    counters[src] += 1
    conf = m["confidence"] if m["confidence"] in ("high", "medium", "low") else "medium"
    if len(m["sources"]) > 1:
        conf = CONF_UP[conf]
    findings.append({
        "id": f"{src}-{counters[src]:03d}",
        "source": m["source"],
        "sources": m["sources"],
        "type": cat,
        "severity": SEV[m["impact"]],
        "contract": path,
        "fileClass": fclass(path),
        "function": m["function"],
        "line": line,
        "description": " || ".join(m["descriptions"]),
        "confidence": conf,
        "rawCheck": ",".join(m["rawChecks"]),
        "corroborated": len(m["sources"]) > 1,
    })
findings.sort(key=lambda f: (f["fileClass"] != "production", -order[{"potential-high": "High", "potential-medium": "Medium", "potential-low": "Low"}[f["severity"]]], f["contract"], f["line"] or 0))

# coverage
cov = {}
sl_files = set(json.load(open(sys.argv[3])))
ad = set()
for fname in ("aderyn-report.json", "aderyn-report-tests.json"):
    ad |= {unmap(x["file_path"]) for x in json.load(open(f"{R}/{fname}"))["files_details"]["files_details"]}
sg = set()
for fname in ("semgrep-output.json", "semgrep-decurity-security.json"):
    sg |= {p for p in json.load(open(f"{R}/{fname}"))["paths"]["scanned"] if p.endswith(".sol")}
for name, got in (("slither", sl_files), ("aderyn", ad), ("semgrep", sg)):
    cov[name] = {"analysed": len(set(SCOPE) & got), "scope": len(SCOPE), "missing": sorted(set(SCOPE) - got)}

out = {
    "project": "sya-harvester",
    "run": "sya-harvester-01",
    "commit": "62c19c8",
    "scanTimestamp": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "scanType": "static",
    "tools": {"slither": "0.11.3", "aderyn": "0.6.8", "semgrep": "1.163.0 (p/smart-contracts + Decurity semgrep-smart-contracts@2e878a8 solidity/security)"},
    "missingTools": [],
    "coverage": cov,
    "findingsCount": len(findings),
    "productionFindingsCount": sum(1 for f in findings if f["fileClass"] == "production"),
    "filteredCount": sum(filtered.values()),
    "filtered": {k: {"count": v["count"], "reason": v["reason"], "files": sorted(v["files"])} for k, v in sorted(filtered_detail.items())},
    "findings": findings,
}
json.dump(out, open(f"{R}/static-analysis-findings.json", "w"), indent=2)
print(json.dumps({"findings": len(findings), "production": out["productionFindingsCount"], "filtered": out["filteredCount"], "coverage": cov}, indent=1))

#!/usr/bin/env python3
import json, datetime, os

RD = "/home/justin/code/audits/reports/phoenix-nft-staking-22"
slither = json.load(open(f"{RD}/slither-output.json"))
aderyn = json.load(open(f"{RD}/aderyn-report.json"))

# Noise detectors dropped per agent spec (kept: timestamp -> time-driven suite)
DROP_SLITHER = {
    "naming-convention","solc-version","pragma","assembly","low-level-calls",
    "missing-zero-check","unused-state","dead-code","constable-states",
    "external-function","too-many-digits","similar-names","different-pragma",
    "costly-loop","cyclomatic-complexity","calls-loop",
}
IMPACT_MAP = {"High":"potential-high","Medium":"potential-medium","Low":"potential-low"}

def is_first_party(fn):
    return fn and fn.startswith("src/") and not fn.startswith("src/INFTSupply.sol")

findings = []
filtered = 0
sid = 0

# ---- Slither ----
for d in slither["results"]["detectors"]:
    chk = d["check"]
    impact = d["impact"]
    files = [e["source_mapping"]["filename_relative"] for e in d["elements"] if e.get("source_mapping")]
    fp_files = [f for f in files if is_first_party(f)]
    # Drop if noise, informational, or root cause not first-party
    if impact == "Informational" or chk in DROP_SLITHER or not fp_files:
        filtered += 1
        continue
    el = d["elements"][0]
    sm = el.get("source_mapping", {})
    # pick the first first-party element for contract/line
    fp_el = next((e for e in d["elements"] if e.get("source_mapping") and is_first_party(e["source_mapping"]["filename_relative"])), el)
    fsm = fp_el["source_mapping"]
    contract = fsm["filename_relative"]
    line = fsm["lines"][0] if fsm.get("lines") else 0
    func = el.get("name","?")
    sid += 1
    findings.append({
        "id": f"SLITHER-{sid:03d}",
        "source": "slither",
        "type": chk,
        "severity": IMPACT_MAP.get(impact,"potential-low"),
        "contract": contract,
        "function": func,
        "line": line,
        "description": " ".join(d["description"].split())[:400],
        "confidence": d["confidence"].lower(),
        "rawCheck": chk,
    })

# ---- Aderyn ----
# Keep security-relevant; drop pure-style/QA
ADERYN_KEEP = {
    "Reentrancy: State change after external call":"reentrancy-no-eth",
    "Unchecked Return":"unused-return",
    "Uninitialized Local Variable":"uninitialized-local",
    "Unsafe ERC20 Operation":"unchecked-transfer",
    "`nonReentrant` is Not the First Modifier":"incorrect-modifier",
}
ADERYN_SEV = {  # aderyn buckets
    "high_issues":"potential-high", "low_issues":"potential-low",
}
aid = 0
for bucket, sev in (("high_issues","potential-high"),("low_issues","potential-low")):
    for issue in aderyn[bucket]["issues"]:
        title = issue["title"]
        if title not in ADERYN_KEEP:
            filtered += 1
            continue
        mapped = ADERYN_KEEP[title]
        for inst in issue["instances"]:
            cp = inst.get("contract_path","")
            if not is_first_party(cp):
                filtered += 1
                continue
            aid += 1
            findings.append({
                "id": f"ADERYN-{aid:03d}",
                "source": "aderyn",
                "type": mapped,
                "severity": sev,
                "contract": cp,
                "function": inst.get("hint") or "",
                "line": inst.get("line_no",0),
                "description": " ".join((issue.get("description","")).split())[:400],
                "confidence": "medium",
                "rawCheck": title,
            })

# ---- Cross-tool corroboration merge: same contract:line:type ----
merged = {}
for f in findings:
    key = (f["contract"], f["line"], f["type"])
    if key in merged:
        m = merged[key]
        srcs = set(m.get("corroboratingSources", [m["source"]]))
        srcs.add(f["source"])
        m["corroboratingSources"] = sorted(srcs)
        m["confidence"] = "high"  # corroboration raises confidence
    else:
        f = dict(f)
        f["corroboratingSources"] = [f["source"]]
        merged[key] = f

out_findings = list(merged.values())

out = {
    "project": "phoenix-nft-staking",
    "scanTimestamp": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "scanType": "static",
    "submoduleCommit": "bb4fea0",
    "tools": {"slither": "0.11.3", "aderyn": "0.6.8", "semgrep": "1.163.0"},
    "solcVersion": "0.8.20",
    "missingTools": [],
    "notes": [
        "Semgrep p/smart-contracts produced 249 findings, ALL style/QA rules (use-custom-error-not-require, increment idioms, use-ownable2step, non-payable-constructor) with no security detectors; contributed 0 normalized findings.",
        "Slither High incorrect-exp and all divide-before-multiply are inside OZ Math.sol under lib/immutable/ (third-party, OOS root cause) -> dropped.",
        "src/NFTStakerDepletionV2.sol is present in src/ but ABSENT from the advisory scope array; scanned anyway under default-in-scope denylist.",
        "timestamp detectors RETAINED (time-driven emission suite) per agent spec.",
        "Aderyn 'Unsafe ERC20 Operation' on NFTStakerMigrator/InPlaceNFTStakerMigrator is documented-intentional raw transfer inside try/catch (both branches handled) -> likely FP, retained for dedup/severity to dispose, not dropped at scan.",
    ],
    "filteredCount": filtered,
    "findingsCount": len(out_findings),
    "findings": out_findings,
}
json.dump(out, open(f"{RD}/static-analysis-findings.json","w"), indent=2)
print("findings:", len(out_findings), "filtered:", filtered)
# type breakdown
from collections import Counter
c = Counter((f["type"], f["severity"]) for f in out_findings)
for k,v in sorted(c.items(), key=lambda x:-x[1]):
    print(f"  {v:3d}  {k[1]:16s} {k[0]}")

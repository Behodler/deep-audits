#!/usr/bin/env python3
"""
Normalize Slither + Aderyn + Semgrep output into the static-analyzer schema.
Scope: lib/phlimbo-ea/src/Phlimbo.sol only (other files dropped).
"""
import json
import os
import re
from datetime import datetime, timezone

BASE = os.path.dirname(os.path.abspath(__file__))
SLITHER_JSON = os.path.join(BASE, "slither-output.json")
ADERYN_JSON = os.path.join(BASE, "aderyn-report.json")
SEMGREP_JSON = os.path.join(BASE, "semgrep-output.json")
OUT_JSON = os.path.join(BASE, "static-analysis-findings.json")

# Detectors to drop globally (QA/info noise per static-analyzer spec).
NOISE = {
    "naming-convention", "solc-version", "pragma", "assembly",
    "low-level-calls", "missing-zero-check", "unused-state", "dead-code",
    "constable-states", "external-function", "too-many-digits",
    "similar-names", "different-pragma",
    # Slither timestamp warnings are almost always noise on staking pools.
    "timestamp",
    # Aderyn equivalents
    "unspecific-solidity-pragma", "push-zero-opcode", "large-numeric-literal",
    "costly-loop", "require-revert-in-loop",
    # Optimization-tier Slither
    "immutable-states",
}

# Severity mapping: tool impact -> normalized severity.
SLITHER_SEV = {
    "High": "potential-high",
    "Medium": "potential-medium",
    "Low": "potential-low",
    "Informational": None,
    "Optimization": None,
}

ADERYN_SEV = {
    "high_issues": "potential-high",
    "low_issues": "potential-low",
}

# Aderyn detector -> normalized category (best-effort mapping).
ADERYN_CATEGORY = {
    "centralization-risk": "centralization",
    "state-change-without-event": "missing-event",
    "state-no-address-check": "missing-zero-check",
    "state-variable-could-be-immutable": "immutable-states",
    "non-reentrant-not-first": "incorrect-modifier-order",
    "reentrancy-state-change": "reentrancy-no-eth",
}

SEMGREP_SEV = {
    "ERROR": "potential-high",
    "WARNING": "potential-medium",
    "INFO": None,  # drop info-only
}

# Scope filter
IN_SCOPE_RE = re.compile(r"(^|/)Phlimbo\.sol$")


def in_scope(path: str) -> bool:
    if not path:
        return False
    return IN_SCOPE_RE.search(path.replace("\\", "/")) is not None


def normalize_slither():
    findings, dropped = [], 0
    try:
        with open(SLITHER_JSON) as f:
            data = json.load(f)
    except Exception as e:
        return findings, 0, f"failed to read slither json: {e}"
    detectors = data.get("results", {}).get("detectors", []) or []
    raw_count = len(detectors)
    for i, det in enumerate(detectors):
        check = det.get("check", "")
        impact = det.get("impact", "Informational")
        confidence = det.get("confidence", "Medium")
        sev = SLITHER_SEV.get(impact)
        if sev is None or check in NOISE:
            dropped += 1
            continue
        # First element gives the primary code location
        elements = det.get("elements", []) or []
        contract_path = None
        func_name = None
        line = None
        if elements:
            first = elements[0]
            sm = first.get("source_mapping", {}) or {}
            contract_path = sm.get("filename_short") or sm.get("filename_relative")
            lines = sm.get("lines") or []
            if lines:
                line = lines[0]
            if first.get("type") == "function":
                func_name = first.get("name")
            else:
                # Walk for a containing function
                for el in elements:
                    if el.get("type") == "function":
                        func_name = el.get("name")
                        break
        if not in_scope(contract_path or ""):
            dropped += 1
            continue
        desc = (det.get("description") or "").strip()
        findings.append({
            "id": f"SLITHER-{i+1:03d}",
            "source": "slither",
            "type": check,
            "severity": sev,
            "contract": contract_path,
            "function": func_name,
            "line": line,
            "description": desc,
            "confidence": confidence.lower(),
            "rawCheck": check,
        })
    return findings, raw_count, None


def normalize_aderyn():
    findings, dropped = [], 0
    try:
        with open(ADERYN_JSON) as f:
            data = json.load(f)
    except Exception as e:
        return findings, 0, f"failed to read aderyn json: {e}"
    raw_count = 0
    idx = 0
    for bucket_key, bucket_sev in ADERYN_SEV.items():
        bucket = data.get(bucket_key, {}) or {}
        for issue in bucket.get("issues", []) or []:
            detector = issue.get("detector_name", "")
            title = issue.get("title", "")
            description = issue.get("description", "")
            mapped_type = ADERYN_CATEGORY.get(detector, detector)
            for inst in issue.get("instances", []) or []:
                raw_count += 1
                cpath = inst.get("contract_path", "")
                line = inst.get("line_no")
                if detector in NOISE or mapped_type in NOISE:
                    dropped += 1
                    continue
                if not in_scope(cpath):
                    dropped += 1
                    continue
                idx += 1
                hint = inst.get("hint")
                desc_parts = [title, description]
                if hint:
                    desc_parts.append(f"Hint: {hint}")
                findings.append({
                    "id": f"ADERYN-{idx:03d}",
                    "source": "aderyn",
                    "type": mapped_type,
                    "severity": bucket_sev,
                    "contract": cpath,
                    "function": None,
                    "line": line,
                    "description": " | ".join([p for p in desc_parts if p]),
                    "confidence": "medium",
                    "rawCheck": detector,
                })
    return findings, raw_count, None


def normalize_semgrep():
    findings, dropped = [], 0
    try:
        with open(SEMGREP_JSON) as f:
            data = json.load(f)
    except Exception as e:
        return findings, 0, f"failed to read semgrep json: {e}"
    results = data.get("results", []) or []
    raw_count = len(results)
    for i, r in enumerate(results):
        check_id = r.get("check_id", "")
        sev = SEMGREP_SEV.get(r.get("extra", {}).get("severity", "INFO"))
        if sev is None:
            dropped += 1
            continue
        short = check_id.split(".")[-1]
        if short in NOISE:
            dropped += 1
            continue
        path = r.get("path", "")
        if not in_scope(path):
            dropped += 1
            continue
        line = (r.get("start") or {}).get("line")
        msg = (r.get("extra", {}).get("message") or "").strip()
        findings.append({
            "id": f"SEMGREP-{i+1:03d}",
            "source": "semgrep",
            "type": short,
            "severity": sev,
            "contract": path,
            "function": None,
            "line": line,
            "description": msg,
            "confidence": "medium",
            "rawCheck": check_id,
        })
    return findings, raw_count, None


def merge_corroboration(findings):
    """Group by (contract, line, type); when >1 source for same key, keep first
    but record corroboration sources and bump confidence."""
    groups = {}
    order = []
    for f in findings:
        key = (f["contract"], f["line"], f["type"])
        if key not in groups:
            groups[key] = []
            order.append(key)
        groups[key].append(f)
    merged = []
    for key in order:
        items = groups[key]
        primary = items[0]
        if len(items) > 1:
            primary = dict(primary)
            primary["corroboratingSources"] = sorted({it["source"] for it in items})
            primary["confidence"] = "high"
            primary["description"] += " [corroborated by: " + ", ".join(
                sorted({it["source"] for it in items if it["source"] != primary["source"]})
            ) + "]"
        merged.append(primary)
    return merged


def main():
    slither_f, slither_raw, s_err = normalize_slither()
    aderyn_f, aderyn_raw, a_err = normalize_aderyn()
    semgrep_f, semgrep_raw, g_err = normalize_semgrep()

    all_findings = slither_f + aderyn_f + semgrep_f
    merged = merge_corroboration(all_findings)

    filtered_count = (slither_raw + aderyn_raw + semgrep_raw) - len(all_findings)

    out = {
        "project": "phlimbo-ea",
        "reportDir": "reports/phlimbo-ea-03",
        "contractPath": "lib/phlimbo-ea/src/Phlimbo.sol",
        "scanCommit": "1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301",
        "scanTimestamp": datetime.now(timezone.utc).isoformat(),
        "scanType": "static",
        "tools": {
            "slither": "0.11.3",
            "aderyn": "0.6.8",
            "semgrep": "1.163.0",
        },
        "toolRawCounts": {
            "slither": slither_raw,
            "aderyn": aderyn_raw,
            "semgrep": semgrep_raw,
        },
        "errors": {k: v for k, v in {"slither": s_err, "aderyn": a_err, "semgrep": g_err}.items() if v},
        "findingsCount": len(merged),
        "preMergeCount": len(all_findings),
        "filteredCount": filtered_count,
        "findings": merged,
    }
    with open(OUT_JSON, "w") as f:
        json.dump(out, f, indent=2)
    print(f"slither raw={slither_raw} kept={len(slither_f)}")
    print(f"aderyn raw={aderyn_raw} kept={len(aderyn_f)}")
    print(f"semgrep raw={semgrep_raw} kept={len(semgrep_f)}")
    print(f"merged candidates={len(merged)} (pre-merge={len(all_findings)}, dropped/filtered={filtered_count})")
    print(f"written to {OUT_JSON}")


if __name__ == "__main__":
    main()

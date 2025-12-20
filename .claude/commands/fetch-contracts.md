Fetch contract source code and configuration from blockchain explorer links
# Purpose
Orchestrate fetching verified contract source code from blockchain explorers and reading on-chain configuration values.

# Arguments
- `$ARGUMENTS` format: `<project-name> <source> [bounty]`
- Source can be:
  - A file path containing explorer URLs (one per line)
  - The keyword `readme` to extract links from project's README.md
  - Direct URLs separated by spaces (for small batches)
- Example: `moonwell readme` (extract links from moonwell's README)
- Example: `moonwell links.txt` (read URLs from file)
- Example: `moonwell https://basescan.org/address/0x1234 https://basescan.org/address/0x5678`
- Example: `moonwell readme bounty` (bounty mode)

# Mode Detection
Parse `$ARGUMENTS` for "bounty" keyword:
- If "bounty" present: Store results in bounty context
- Otherwise: Store in audit context
- Mode affects output directory structure

# Orchestration Flow

## 1. Resolve Project
Invoke **project-manager**: "Resolve project name to get project metadata"
- Look up project in registered-projects.json
- Get submodule path for README extraction if needed
- If project not found: Report error, suggest `/add-project`

## 2. Collect Explorer URLs
Based on source argument:

### If source is "readme":
Invoke **contract-fetcher**: "Extract explorer URLs from README"
- Read `lib/<submodule>/README.md`
- Find all blockchain explorer URLs (etherscan, basescan, etc.)
- Parse URLs from markdown links and plain text
- Return deduplicated list of URLs

### If source is a file path:
Invoke **contract-fetcher**: "Read URLs from file"
- Read the specified file
- Parse one URL per line
- Skip empty lines and comments (#)
- Validate URL format

### If source contains URLs directly:
- Parse URLs from arguments (split by space)
- Validate URL format

## 3. Create Output Directory
Invoke **project-manager**: "Create contracts directory for project"
- Create: `contracts/<project-name>/`
- Initialize metadata.json with fetch session info

## 4. Fetch Contract Sources
Invoke **contract-fetcher**: "Fetch verified source code for all contracts"
- Pass: list of explorer URLs, output directory
- For each URL:
  1. Parse chain and address from URL
  2. Fetch contract page via WebFetch
  3. Extract verified source code
  4. Save to `contracts/<project>/<chain-id>/<address>/`
  5. Record success/failure
- Return: fetch results summary

## 5. Read Configuration Values
Invoke **config-reader**: "Read config values from successfully fetched contracts"
- Pass: list of successfully fetched contracts with chain info
- For each contract:
  1. Identify view functions from source (if available)
  2. Call common config functions via `cast`
  3. Record returned values
  4. Handle errors gracefully
- Return: config values per contract

## 6. Generate Metadata File
Invoke **project-manager**: "Write contract metadata file"
- Create `contracts/<project-name>/metadata.json`:
```json
{
  "project": "<project-name>",
  "mode": "audit" | "bounty",
  "fetchedAt": "<ISO-timestamp>",
  "source": "readme" | "<filename>" | "direct",
  "summary": {
    "totalUrls": 25,
    "successfulFetches": 23,
    "failedFetches": 2,
    "configReadsAttempted": 23,
    "configReadsSuccessful": 20
  },
  "contracts": [
    {
      "address": "0x1234...",
      "name": "Comptroller",
      "chainId": 8453,
      "chainName": "Base",
      "explorerUrl": "https://basescan.org/address/0x1234...",
      "sourceFetched": true,
      "sourceDir": "8453/0x1234.../",
      "compilerVersion": "v0.8.19",
      "isProxy": false,
      "configValues": {
        "owner": "0xabcd...",
        "paused": false,
        "oracle": "0x9999..."
      },
      "configReadSuccess": true
    },
    {
      "address": "0x5678...",
      "name": null,
      "chainId": 8453,
      "chainName": "Base",
      "explorerUrl": "https://basescan.org/address/0x5678...",
      "sourceFetched": false,
      "sourceDir": null,
      "error": "Contract not verified",
      "configValues": {},
      "configReadSuccess": false
    }
  ]
}
```

## 7. Update Project Registration
Invoke **project-manager**: "Update project with contracts metadata path"
- Add to registered-projects.json:
  ```json
  {
    "contractsMetadata": "contracts/<project>/metadata.json",
    "contractsFetchedAt": "<ISO-timestamp>",
    "contractsCount": 23
  }
  ```

## 8. Present Summary
Display to user:
```
Contract Fetch Complete: moonwell
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Source: README.md extraction
Mode: bounty

Fetch Results:
  Total URLs found: 25
  Successfully fetched: 23
  Failed (unverified): 2

Chains covered:
  Base (8453): 15 contracts
  Optimism (10): 5 contracts
  Moonbeam (1284): 3 contracts

Config Read Results:
  Contracts with config: 20/23
  Total config values: 156

Output: contracts/moonwell/
Metadata: contracts/moonwell/metadata.json

Failed contracts:
  - 0x5678... (Base): Not verified
  - 0x9abc... (Optimism): Rate limited

Next Steps:
  - Review metadata.json for contract details
  - Run /analyze moonwell bounty
```

# Agent Delegation (MANDATORY)

**CRITICAL: This command MUST delegate to agents. Direct tool usage is FORBIDDEN.**

The orchestrating agent's ONLY permitted actions are:
1. Parse arguments
2. Invoke agents with specific tasks
3. Report results to user

All WebFetch, Bash (cast), Read, Write, and Glob operations MUST be performed by agents.

## Required Delegations
| Task | Agent | Prompt Pattern |
|------|-------|----------------|
| Resolve project | project-manager | "Resolve project '{name}' and get metadata" |
| Extract URLs from README | contract-fetcher | "Extract explorer URLs from README at {path}" |
| Read URLs from file | contract-fetcher | "Read explorer URLs from file {path}" |
| Create output directory | project-manager | "Create contracts directory for project '{name}'" |
| Fetch contract sources | contract-fetcher | "Fetch source code for contracts: {urls}" |
| Read config values | config-reader | "Read config values for contracts: {contracts}" |
| Write metadata | project-manager | "Write metadata file to {path}" |
| Update registration | project-manager | "Update project registration with contracts info" |

# Error Handling
- **Unknown project**: Suggest `/add-project` first
- **No URLs found**: Report empty source, check README format
- **All fetches failed**: Report errors, suggest manual verification
- **RPC failures**: Report which chains had issues
- **Partial success**: Continue with successful fetches, report failures

# Rate Limiting
Block explorers and RPCs have rate limits:
- Space out requests (200-500ms between)
- Handle 429 responses with backoff
- Report rate limit issues clearly

# Examples
```
/fetch-contracts moonwell readme
# Extract URLs from moonwell's README, fetch all contracts

/fetch-contracts moonwell readme bounty
# Same but in bounty context

/fetch-contracts aave-v4 scope-contracts.txt
# Read URLs from a file

/fetch-contracts test-project https://etherscan.io/address/0x1234
# Fetch single contract directly

/fetch-contracts moonwell https://basescan.org/address/0x1234 https://basescan.org/address/0x5678
# Fetch multiple contracts from direct URLs
```

# Critical Rules
1. **NEVER modify fetched source** - Store exactly as retrieved
2. **Record all failures** - Every fetch attempt must be logged
3. **Validate URLs** - Ensure valid explorer format before fetching
4. **Respect rate limits** - Don't spam explorers or RPCs
5. **Chain-aware** - Use correct RPC endpoints per chain

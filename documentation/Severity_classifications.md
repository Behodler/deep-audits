
Code4rena
Ask or search…
Ctrl
k

Copy

Competitions
Severity classifications
Severity definitions for Code4rena audits

Estimating Risk
Where assets refer to funds, NFTs, data, authorization, and any information intended to be private or confidential:

3 — High: Assets can be stolen/lost/compromised directly (or indirectly if there is a valid attack path that does not have hand-wavy hypotheticals).

2 — Medium: Assets not at direct risk, but the function of the protocol or its availability could be impacted, or leak value with a hypothetical attack path with stated assumptions, but external requirements.

QA (Quality Assurance) Includes Low risk (e.g. assets are not at risk: state handling, function incorrect as to spec, issues with comments) and Governance/Centralization risk (including admin privileges). Non-critical issues (code style, clarity, syntax, versioning, off-chain monitoring (events, etc) are discouraged.

Cases where loss of assets is considered Low risk
Loss of fees is evaluated as having an impact similar to any other loss of capital:

Loss of dust amounts (e.g. rounding errors, marginal variations in fees) are QA/Low risk.

Loss of real amounts depends on specific conditions and likelihood considerations.

Cases where loss of yield is considered High risk
Loss of matured yield is evaluated as having an impact similar to any other loss of capital:

Loss of dust amounts (e.g. rounding errors, marginal variations) are QA/Low risk.

Loss of real amounts depends on specific conditions and likelihood considerations.

Loss of unmatured yield or yield in motion is capped at Medium severity.

Centralization risks
Submissions describing centralization risks should be submitted as follows:

All roles assigned by the system are expected to be trustworthy and to invoke the relevant privileged functions of the system responsibly and in the best interest of the protocol.

Reckless admin mistakes are invalid. Assume calls are previewed.

Direct misuse of privileges should be submitted within a QA report.

Mistakes in code only unblocked through admin mistakes should be submitted within a QA Report.

Privilege escalation issues are judged by likelihood and impact.

Any execution scenario involving privileged functions that can result in a vulnerability if the function is used with reasonable assumptions may be classified up to a medium severity level depending on likelihood and impact.

Unsupported/non-standard tokens and fee-on-transfer tokens
All non-standard/weird ERC-20 token and fee-on-transfer token findings are considered out of scope, unless they're explicitly listed as supported tokens in the scope/documentation. The only exceptions is USDT, which should be considered in-scope despite non-standard behavior.

Judges should immediately invalidate findings in this category that don't meet the above criteria, and wardens are discouraged from submitting them.

Rather than treat EIP-20 as an authoritative document, we recognize that the commonly understood definition is the one stated here: https://ethereum.org/en/developers/docs/standards/tokens/erc-20/

View functions
Findings relating to unused view functions within the protocol are considered Low risk (QA) at best.

Fault in out-of-scope library vs. incorrect implementation
When an in-scope contract composes/inherits from an OOS contract:

If the root cause exists within the OOS contract itself, the finding is to be treated as OOS

If the issue stems from incorrect implementation of the inheritance or improper calls to the OOS library by the in-scope contract, the finding is to be treated as in-scope

Issues arising from the in-scope contract's misuse of OOS functionality are considered valid findings. Exceptional scenarios are at the discretion of the judge.

Conditional on user mistake
Findings that require the user to be careless or enter the wrong information into a contract call are QA at best, and may be judged invalid.

Non-privileged users are expected to preview their transactions to protect against input mistakes. Anyone using modern tooling will have previews built into their toolset.

Phishing attacks, and improper caution on using a protocol, fall under this rule.

Speculation on future code
Any issue that is not exploitable within the scope of the contest is considered to be speculating on future code. Any such speculation only has the potential to be valid if the root cause is demonstrated to be in the contest scope. Wardens may make an argument on why a future code change that would make the bug manifest is reasonably likely. Based on likelihood considerations, the Judge may assign a severity rating in any way they see fit.

If the exploitability relies on a particular 3rd party integration, the likelihood must factor in a competent integrator who has done due diligence.

Event-related impacts
A submission whose consequence is faulty emission of event(s) is assessed in line with its broader-level impact:

For events which are used for additional on-chain processes such as bridging, inclusion proofs, etc., the submission is assessed based on impacted functionality.

Findings that cause non-compliance with EIPs are assessed based on the impact.

Failure to demonstrate the broader level impacts above will cap the severity to Low.

For clarification, bugs leading to readability or accessibility of data, or issues of display in front-ends, are capped to Low.

Protocol does not support CryptoPunks
This is considered non-critical (refactoring) and therefore wardens are discouraged from submitting it. It cannot be argued as a vulnerability.

Approve race condition
Notes from the Fall 2023 Supreme Court decisions:

We have long rejected the finding as anything above non-critical

OZ has deprecated increaseAllowance and decreaseAllowance

We officially confirm:

Approve and safeApprove front-run is NOT a valid vulnerability

Approve and safeApprove are NOT deprecated

increaseAllowance and decreaseAllowance ARE deprecated, although usage of those functions is not regarded as a finding.

Previous
Submission guidelines
Next
Judging criteria
Last updated 2 months ago

Was this helpful?




Severity classifications | Code4rena
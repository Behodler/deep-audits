#!/usr/bin/env python3
# sya-harvester-02 exhaustive cross-check (NOT Halmos; complete over an equality abstraction).
# Validator = transcription of SYAHarvester.setRoute @ 6b862aa (L157-185).
# Router    = Curve Router NG v1.1 exchange (reports/02/profiles/evidence/RouterNG-v1.1-0x16C6.vy L223-339):
#             hop 0 always runs; hop i: swap=route[2i+1], out=route[2i+2], params=swap_params[i];
#             swap_type==0 -> "Bad swap type"; empty swap -> call to empty account reverts;
#             out==0 -> ERC20 calls on empty account revert; break if i==4 or route[2i+3]==0.
# Abstraction: path entries in {0,R,X,T} (values only matter via ==0, ==reward, ==token);
#              per-row swapParams as (swap_type!=0, any-other-field!=0), pools[h] in {0,P}.
# The validator's swapParams/pools conditions depend on path only through k, so the path space
# and the (swapParams,pools) space are enumerated separately and joined on k (sound decomposition).
import itertools
from collections import Counter

def validator_path(token, p):
    if token == 0: return None
    if p[0] != token: return None
    k = 0
    while k < 5 and p[2*k+1] != 0: k += 1
    for i in range(2*k+1, 11):
        if p[i] != 0: return None
    for i in range(1, k):
        if p[2*i] == 0: return None
    if p[2*k] != 'R': return None
    return k

def validator_sp(k, rows, pools):
    for h in range(5):
        st, other = rows[h]
        if h < k:
            if not st: return False
        else:
            if st or other: return False
            if pools[h]: return False
    return True

def router(p, rows, pools):
    out = None
    for i in range(5):
        swap = p[2*i+1]; out = p[2*i+2]; st = rows[i][0]
        if swap == 0: return 'REVERT'
        if not st: return 'REVERT'      # Bad swap type
        if out == 0: return 'REVERT'
        if i == 4 or p[2*i+3] == 0: break
    return out

# 1) path space
acc_by_k = Counter(); bad = []; k0_tokens = Counter(); total = 0
for token in ('T', 'R'):
    for rest in itertools.product((0, 'R', 'X', 'T'), repeat=10):
        p = (token,) + rest; total += 1
        k = validator_path(token, p)
        if k is None: continue
        acc_by_k[k] += 1
        if k == 0:
            k0_tokens[token] += 1; continue
        # canonical sp/pools for k (validator-accepting); router result must be R
        rows = [(h < k, False) for h in range(5)]; pools = [False]*5
        r = router(p, rows, pools)
        if r != 'R': bad.append((p, k, r))
print('path-space size:', total)
print('accepted by validator k:', dict(sorted(acc_by_k.items())))
print('k==0 accepted, by token class:', dict(k0_tokens), '(must be R only: _sellYield skips token==reward)')
print('accepted k>=1 paths where Router NG does NOT deliver R:', len(bad), bad[:3])

# 2) swapParams/pools space per k: accepted <=> executed rows swap_type!=0 and unexecuted rows+pools zero;
#    and for every accepted (path,k) x accepted (rows,pools), the router never hits Bad swap type.
rowvals = [(a, b) for a in (False, True) for b in (False, True)]
for k in range(0, 6):
    n_acc = 0; n_bad = 0
    for rows in itertools.product(rowvals, repeat=5):
        for pools in itertools.product((False, True), repeat=5):
            if not validator_sp(k, rows, pools): continue
            n_acc += 1
            # router reads only rows < n (n == k for k>=1) -> all have swap_type != 0
            if k >= 1 and any(not rows[h][0] for h in range(k)): n_bad += 1
            if any(rows[h][0] or rows[h][1] or pools[h] for h in range(k, 5)): n_bad += 1
    print(f'k={k}: accepted (rows,pools) combos={n_acc} bad={n_bad}')
print('RESULT:', 'PASS' if not bad and set(k0_tokens) <= {'R'} else 'FAIL')

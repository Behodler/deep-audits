# Exhaustive bounded check of SYAHarvester.setRoute acceptance (L130-140) vs Curve Router NG
# delivery semantics. Alphabet: 0, T (token=path[0]), R (rewardToken), X (other token), P (pool).
# Case R==T (route registered for the reward token itself) enumerated separately.
import itertools, collections, sys
def router(p):
    loud=False; out=None; hops=0
    for k in range(5):
        if p[2*k+1]=='0': loud=True
        out=p[2*k+2]; hops=k+1
        if k==4 or p[2*k+3]=='0': break
    if out=='0': loud=True
    return out,loud,hops
def accepted(p,reward):
    if p[0]=='0': return False
    last='0'
    for x in p:
        if x!='0': last=x
    return last==reward
stats=collections.Counter(); examples={}
for tail in itertools.product('0TRXP',repeat=10):
    p=('T',)+tail
    if not accepted(p,'R'): continue
    out,loud,hops=router(p)
    gap=any(p[j]!='0' for j in range(2*hops+1,11))
    cls=('OK' if out=='R' and not loud else 'LOUD' if loud else 'SILENT_MISROUTE')+('_gap' if gap else '_nogap')
    stats[cls]+=1
    examples.setdefault(cls,''.join(p))
for k,v in sorted(stats.items()): print(f"{k:24s} {v:9d}  e.g. {examples[k]}")

# Case token == rewardToken (path[0]=R). Abstraction {0,R,X}: X = any other non-zero value.
stats2=collections.Counter(); ex2={}
for tail in itertools.product('0RX',repeat=10):
    p=('R',)+tail
    if not accepted(p,'R'): continue
    out,loud,hops=router(p)
    gap=any(p[j]!='0' for j in range(2*hops+1,11))
    cls=('OK' if out=='R' and not loud else 'LOUD' if loud else 'SILENT_MISROUTE')+('_gap' if gap else '_nogap')
    stats2[cls]+=1; ex2.setdefault(cls,''.join(p))
print("-- token == rewardToken (route never executed: _sellYield skips reward, L311) --")
for k,v in sorted(stats2.items()): print(f"{k:24s} {v:9d}  e.g. {ex2[k]}")

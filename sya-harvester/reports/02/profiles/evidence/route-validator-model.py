import itertools
R,X,T='R','X','T'
def validator(token,p):
    if token==0: return 'ZeroAddress'
    if p[0]!=token: return 'Start'
    k=0
    while k<5 and p[2*k+1]!=0: k+=1
    for i in range(2*k+1,11):
        if p[i]!=0: return 'Gap'
    for i in range(1,k):
        if p[2*i]==0: return 'Token'
    if p[2*k]!=R: return 'End'
    return ('OK',k)
def router(p):
    out=None
    for i in range(5):
        swap=p[2*i+1]; out=p[2*i+2]
        if swap==0: return 'REVERT'
        if out==0: return 'REVERT'
        if i==4 or p[2*i+3]==0: break
    return out
stats={}
bad=[]
for token in (T,R):
  for rest in itertools.product((0,R,X),repeat=10):
    p=(token,)+rest
    v=validator(token,p); r=router(p)
    acc = isinstance(v,tuple)
    key=(token, 'acc' if acc else 'rej', 'deliverR' if r==R else ('revert' if r=='REVERT' else 'deliverOther'))
    stats[key]=stats.get(key,0)+1
    if acc and r!=R: bad.append((p,v,r))
for k,v in sorted(stats.items(),key=str): print(k,v)
print('accepted but router not delivering R:',len(bad)); print(bad[:5])
from collections import Counter
c=Counter()
for rest in itertools.product((0,R,X),repeat=10):
    p=(T,)+rest; v=validator(T,p); r=router(p)
    if not isinstance(v,tuple): c[(v, 'deliverR' if r==R else ('revert' if r=='REVERT' else 'other'))]+=1
print(c)

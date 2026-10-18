# Exhaustive check of the _checkMinAmountsOut window arithmetic (mirrors UniPoolerCutoverCore.sol
# L400-405) over supply in [1,40], bptIn in [0,supply], raw in [0,40], tol in [0,100].
# Exhaustive = proof over THIS small domain only. Also prints live-magnitude 1-wei witnesses.
S=32438774213867981521320; b=20401809116957261204353
for tol in (10,100,1):
  k=10000-tol
  for r in range(29500000000000000000000, 29500000000000000005000):
    q=r*b//S; c=q*k//10000; e=r*b*k//(S*10000)
    assert e-1<=c<=e
    if c==e-1: print("live witness raw=%d tol=%d computed=%d exactFloor=%d"%(r,tol,c,e)); break
n=bad=0
for S2 in range(1,41):
  for b2 in range(0,S2+1):
    for r in range(0,41):
      P=r*b2; q=P//S2
      for tol in range(0,101):
        k=10000-tol; c=q*k//10000; e=P*k//(S2*10000); n+=1
        if not (e-1<=c<=e and q*S2<=P): bad+=1
print("exhaustive cases",n,"violations",bad)

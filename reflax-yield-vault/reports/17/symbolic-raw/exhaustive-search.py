# Exhaustive small-domain counterexample search for the run-17 dominance claim.
# Runs the EXACT integer semantics of the live code (no encoding):
#   convertToShares(a) = a*Sv//Av      convertToAssets(B) = B*Av//Sv   [= _positionValue() = V]
#   totalBalanceOf     = V*p//D        _isUnderwater = totalBalanceOf < p
#   cap binds          = convertToShares(a) > B
N = 26
def run(assets_round_up=False, drop_p_le_D=False, drop_a_le_p=False):
    cex=[]; binds=0; total=0
    for Sv in range(1,N):
        for Av in range(1,N):
            for B in range(0,N):
                V = -(-B*Av//Sv) if assets_round_up else (B*Av)//Sv
                for D in range(1,N):
                    for p in range(1,D+1 if not drop_p_le_D else N):
                        tb = (V*p)//D
                        underwater = tb < p
                        hi = (p if not drop_a_le_p else N-1)
                        for a in range(0,hi+1):
                            q = (a*Sv)//Av
                            capBinds = q > B
                            total+=1
                            if capBinds: binds+=1
                            if capBinds and not underwater:
                                cex.append((a,p,D,B,Sv,Av,q,V,tb))
                                if len(cex)>3: return cex,binds,total
    return cex,binds,total

for label,kw in [("T1 baseline (assets round DOWN)",{}),
                 ("T5 assets round UP",{"assets_round_up":True}),
                 ("T2 neg-control: drop p<=D",{"drop_p_le_D":True}),
                 ("T3 neg-control: drop a<=p",{"drop_a_le_p":True})]:
    cex,binds,total = run(**kw)
    print(f"{label:38s} states={total:>9d} cap-binding={binds:>8d} counterexamples={len(cex)}")
    for c in cex[:2]:
        print("      cex (a,p,D,B,Sv,Av,q,V,tb) =",c)

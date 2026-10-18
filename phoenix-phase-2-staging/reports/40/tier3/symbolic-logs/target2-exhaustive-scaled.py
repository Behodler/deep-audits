# Exhaustive generality check of psmGemForUsds (UniswapHelper.sol L411-415) on a SCALED-DOWN model:
# WAD in {100, 1000}, conv in [1,12], tout in [0,WAD], budget in [0,300]. Checks the closed form
# g = floor(((b+1)*WAD-1)/(conv*(WAD+tout))) equals the brute-force max g with
# cost(g) = g*conv + floor(g*conv*tout/WAD) <= b. Exhaustive = proof over THIS model only.
n=bad=0
for WAD in (100,1000):
  for conv in range(1,13):
    for tout in range(0,WAD+1, 1 if WAD==100 else 7):
      cost=lambda g: g*conv + (g*conv*tout)//WAD
      for b in range(0,301):
        g=((b+1)*WAD-1)//(conv*(WAD+tout))
        gb=0
        while cost(gb+1)<=b: gb+=1
        n+=1
        if g!=gb: bad+=1; print("MISMATCH",WAD,conv,tout,b,g,gb)
print("cases",n,"mismatches",bad)

// run-36 audit helper: per-leg binding gas peak = max_i(sum gasUsed of txs before i in the leg + signed gasLimit of i)
const fs = require('fs');
const f = process.argv[2];
const j = JSON.parse(fs.readFileSync(f, 'utf8'));
const hex = (x) => (typeof x === 'string' ? parseInt(x, 16) : Number(x));
let cum = 0, peak = 0, peakIdx = -1, total = 0;
const rows = [];
j.transactions.forEach((t, i) => {
  const r = j.receipts.find((x) => x.transactionHash === t.hash);
  const used = r ? hex(r.gasUsed) : NaN;
  const status = r ? r.status : 'NA';
  const limit = t.transaction.gas ? hex(t.transaction.gas) : parseInt(require('child_process').execSync('cast tx '+t.hash+' gas --rpc-url http://127.0.0.1:8546').toString().trim());
  const b = cum + limit;
  if (b > peak) { peak = b; peakIdx = i; }
  rows.push(`${i + 1}\t${t.function || t.transactionType}\tused=${used}\tlimit=${limit}\tcum_before+limit=${b}\tstatus=${status}`);
  cum += used; total += used;
});
rows.forEach((r) => console.log(r));
console.log(`txs=${j.transactions.length} totalGasUsed=${total} bindingPeak=${peak} at tx ${peakIdx + 1} (${j.transactions[peakIdx].function})`);
console.log(`vs CUTOVER_GAS_BUDGET 27000000: headroom ${(27000000 - peak)} gas (${((27000000 / peak - 1) * 100).toFixed(2)}%); with 1.2x: ${(32400000 - peak)}`);

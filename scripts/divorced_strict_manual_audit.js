const fs = require('fs');
const path = require('path');

const dir = path.join('assets', 'config', 'journeys', 'divorced journeys');
const files = fs
  .readdirSync(dir)
  .filter((f) => /^divorced_journey_\d+.*\.json$/.test(f))
  .sort();

function walk(node, cb, p = []) {
  if (Array.isArray(node)) {
    node.forEach((v, i) => walk(v, cb, [...p, i]));
    return;
  }
  if (node && typeof node === 'object') {
    for (const [k, v] of Object.entries(node)) {
      if (k === 'text' && typeof v === 'string') cb(v, [...p, k]);
      walk(v, cb, [...p, k]);
    }
  }
}

const issues = [];
const byFile = {};

for (const file of files) {
  const data = JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'));
  byFile[file] = 0;

  walk(data, (text, pathArr) => {
    const fieldPath = pathArr.join('.');
    const paragraphs = text.split('\n\n');

    for (let i = 0; i < paragraphs.length; i++) {
      const para = paragraphs[i];
      const startsBold = para.startsWith('**');
      const stars = (para.match(/\*\*/g) || []).length;
      const hasClosingPair = stars >= 2;

      if (!startsBold) continue;

      // High-confidence malformed cases:
      // 1) Starts with ** but contains only one bold marker in that paragraph.
      // 2) Next paragraph also starts with ** (common missing closing before paragraph break).
      if (stars === 1) {
        const next = paragraphs[i + 1] || '';
        const nextStartsBold = next.startsWith('**');

        issues.push({
          file,
          fieldPath,
          paraIndex: i,
          stars,
          nextStartsBold,
          sample: para.slice(0, 220).replace(/\n/g, ' '),
        });
        byFile[file] += 1;
      } else if (!hasClosingPair) {
        issues.push({
          file,
          fieldPath,
          paraIndex: i,
          stars,
          nextStartsBold: false,
          sample: para.slice(0, 220).replace(/\n/g, ' '),
        });
        byFile[file] += 1;
      }
    }
  });
}

console.log(`FILES=${files.length}`);
console.log(`ISSUES=${issues.length}`);
for (const file of files) {
  console.log(`FILE_COUNT|${file}|${byFile[file]}`);
}
for (const row of issues) {
  console.log(
    `ISSUE|${row.file}|${row.fieldPath}|p${row.paraIndex}|stars=${row.stars}|nextBold=${row.nextStartsBold}|${row.sample}`,
  );
}

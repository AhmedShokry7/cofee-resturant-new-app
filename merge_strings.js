const fs = require('fs');
const stash = fs.readFileSync('stash_strings.dart','utf8');
const adminPath = 'app/admin_app/lib/core/locale/app_strings.dart';
const admin = fs.readFileSync(adminPath,'utf8');

const regex = /static String get (\w+)[\s\S]*?(?=static String get |\n}\s*$)/g;
const blocks = [];
let m;
while ((m = regex.exec(stash)) !== null) {
  blocks.push(m[0].trim());
}
const existingNames = new Set();
const nameRegex = /static String get (\w+)/g;
let nm;
while ((nm = nameRegex.exec(admin)) !== null) existingNames.add(nm[1]);

const toAdd = [];
for (const block of blocks) {
  const nm2 = block.match(/static String get (\w+)/);
  if (!nm2) continue;
  const name = nm2[1];
  if (existingNames.has(name)) continue;
  toAdd.push('  ' + block);
  existingNames.add(name);
}

const idx = admin.lastIndexOf('}');
const newContent = admin.slice(0, idx) + toAdd.join('\n') + '\n' + admin.slice(idx);
fs.writeFileSync(adminPath, newContent, 'utf8');
console.log('Added', toAdd.length, 'getters');

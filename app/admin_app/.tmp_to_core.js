const fs = require("fs"), path = require("path");
function walk(d, acc = []) { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) walk(p, acc); else if (p.endsWith(".dart")) acc.push(p); } return acc; }
const files = [...walk("lib"), ...walk("test")];

const moves = [
  ["lib/features/catalog/domain/entities/admin_catalog_snapshot.dart", "lib/core/catalog/admin_catalog_snapshot.dart"],
  ["lib/features/catalog/domain/failures/admin_product_exception.dart", "lib/core/catalog/admin_product_exception.dart"],
  ["lib/features/catalog/domain/repositories/catalog_repository.dart", "lib/core/catalog/catalog_repository.dart"],
  ["lib/features/catalog/domain/repositories/product_repository.dart", "lib/core/catalog/product_repository.dart"],
  ["lib/features/catalog/domain/repositories/product_image_repository.dart", "lib/core/catalog/product_image_repository.dart"],
  ["lib/features/catalog/domain/repositories/category_repository.dart", "lib/core/catalog/category_repository.dart"],
  ["lib/features/catalog/domain/repositories/branch_pricing_repository.dart", "lib/core/catalog/branch_pricing_repository.dart"],
];

// rewrite every admin_app import in every file first
const map = new Map();
for (const [from, to] of moves) {
  map.set(
    "package:admin_app/" + from.split(path.sep).join("/").replace(/^lib\//, ""),
    "package:admin_app/" + to.split(path.sep).join("/").replace(/^lib\//, "")
  );
}
let rewritten = 0;
for (const f of files) {
  let t = fs.readFileSync(f, "utf8");
  const before = t;
  for (const [from, to] of map) t = t.split(from).join(to);
  if (t !== before) { fs.writeFileSync(f, t); rewritten++; }
}

// self imports inside the moved files are dropped entirely
for (const [, to] of moves) {
  let t = fs.readFileSync(to, "utf8");
  const name = path.basename(to);
  t = t.replace(
    new RegExp("^import 'package:admin_app/core/catalog/" + name + "';\\n", "m"),
    ""
  );
  fs.writeFileSync(to, t);
}

for (const [from] of moves) {
  if (fs.existsSync(from)) fs.rmSync(from);
}
// prune now-empty directories
for (const d of ["lib/features/catalog/domain/entities", "lib/features/catalog/domain/failures", "lib/features/catalog/domain/repositories", "lib/features/catalog/domain"]) {
  if (fs.existsSync(d) && fs.readdirSync(d).length === 0) fs.rmdirSync(d);
}
console.log("imports rewritten in", rewritten, "files; moved", moves.length);

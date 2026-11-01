#!/usr/bin/env bash
# Per-feature audit for the Flutter customer app.
#
#   bash scripts/feature_audit.sh              # layout summary for every feature
#   bash scripts/feature_audit.sh cart          # one feature: sizes, coupling, literals
#
# Output is bounded on purpose: it is read by an agent before it edits, not
# after. Paths are relative to the repo root, which must be the cwd.
set -uo pipefail

ROOT="lib"
FEATURES="$ROOT/features"

if [ ! -d "$FEATURES" ]; then
  echo "run from the repo root (no $FEATURES here)"; exit 1
fi

target="${1:-}"

if [ -z "$target" ]; then
  printf "%-14s %-6s %-5s %-6s %-8s %s\n" "FEATURE" "DATA" "MGR" "VIEWS" "WIDGETS" "LAYOUT_DEVIATIONS"
  for d in "$FEATURES"/*/; do
    f=$(basename "$d")
    data=$(find "$d/data" -name "*.dart" 2>/dev/null | wc -l)
    mgr=$(find "$d/presentation/manager" -name "*.dart" 2>/dev/null | wc -l)
    views=$(find "$d/presentation/views" -name "*.dart" 2>/dev/null | wc -l)
    widgets=$(find "$d/presentation/views/widgets" -name "*.dart" 2>/dev/null | wc -l)
    dev=""
    # anything under presentation/ that is not manager/ or views/
    stray=$(find "$d/presentation" -mindepth 1 -maxdepth 1 -type d ! -name manager ! -name views 2>/dev/null | sed "s|$d/presentation/||" | tr '\n' ',')
    [ -n "$stray" ] && dev="${dev}presentation/$stray "
    loose=$(find "$d/presentation" -maxdepth 1 -name "*.dart" 2>/dev/null | wc -l)
    [ "$loose" != "0" ] && dev="${dev}files-directly-under-presentation:$loose "
    top=$(find "$d/presentation/views" -maxdepth 1 -name "*.dart" 2>/dev/null | wc -l)
    [ "$top" != "0" ] && [ "$widgets" = "0" ] && [ "$top" -gt 1 ] && dev="${dev}no-widgets-dir-with-$top-views "
    printf "%-14s %-6s %-5s %-6s %-8s %s\n" "$f" "$data" "$mgr" "$views" "$widgets" "$dev"
  done
  echo
  echo "core:"
  for d in "$ROOT/core"/*/; do
    printf "  %-12s %s\n" "$(basename "$d")" "$(find "$d" -name "*.dart" | wc -l) files"
  done
  printf "  %-12s %s\n" "lib root" "$(find "$ROOT" -maxdepth 1 -name "*.dart" | sed 's|.*/||' | tr '\n' ' ')"
  exit 0
fi

d="$FEATURES/$target"
[ -d "$d" ] || { echo "no feature named '$target'"; ls "$FEATURES"; exit 1; }

echo "=== $target: files by size ==="
find "$d" -name "*.dart" | xargs wc -l 2>/dev/null | sort -rn | head -25

echo
echo "=== $target: imports of other features (count) ==="
grep -rho "new_coffee/features/[a-z_]*/" "$d" --include="*.dart" \
  | sed 's|new_coffee/features/||; s|/$||' | grep -v "^$target$" \
  | sort | uniq -c | sort -rn | head -20
grep -rho "new_coffee/shared/[a-z_/]*/" "$d" --include="*.dart" \
  | sed 's|new_coffee/shared/||; s|/$||' | sort | uniq -c | sort -rn \
  | sed 's/^/  shared /' | head -10

echo
echo "=== $target: literals that may already have a token ==="
grep -rn --include="*.dart" -E "Color\(0x[0-9A-Fa-f]{8}\)|#[0-9A-Fa-f]{6,8}" "$d" | head -15
grep -rn --include="*.dart" -E "Duration\(milliseconds: [0-9]+\)|Duration\(seconds: [0-9]+\)" "$d" | head -15
grep -rn --include="*.dart" -E "'assets/|\"assets/" "$d" | head -10
grep -rn --include="*.dart" -E "static const double [a-zA-Z0-9_]+ = [0-9.]+" "$d" | head -15

echo
echo "=== $target: how it is named and routed ==="
grep -rn --include="*.dart" -E "static const (routeName|RouteName)" "$d" | head -10
grep -rn "AppRoutes\|routeName" "$ROOT/core/navigation/app_routes.dart" | grep -i "$target" | head -10

echo
echo "=== $target: cubit/state pairing ==="
for f in $(find "$d" -name "*_cubit.dart" -o -name "*_bloc.dart" | sort); do
  if grep -q "^part '" "$f"; then
    echo "  part-file  $f"
  else
    echo "  NO-PART    $f  -> $(dirname "$f" | tr '\n' ' ')$(ls "$(dirname "$f")" | tr '\n' ' ')"
  fi
done

echo
echo "=== tests that mention $target ==="
grep -rl "features/$target/" test --include="*.dart" 2>/dev/null | sed 's|test/||' | head -20
echo "  total: $(grep -rl "features/$target/" test --include="*.dart" 2>/dev/null | wc -l)"

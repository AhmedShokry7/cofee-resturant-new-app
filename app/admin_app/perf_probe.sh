#!/usr/bin/env bash
# Measures the real first-open latency of every admin page's load call(s)
# against the live Supabase project, with a real staff session.
# Usage: bash perf_probe.sh
set -u

URL=$(grep "^SUPABASE_URL=" .env | cut -d= -f2 | tr -d '"\r')
PUB=$(grep "^SUPABASE_PUBLISHABLE_KEY=" .env | cut -d= -f2 | tr -d '"\r')
PW=$(grep "^PASSWORD=" .env | cut -d= -f2- | tr -d '"\r')

TOKEN=$(curl -s --max-time 20 -X POST "$URL/auth/v1/token?grant_type=password" \
  -H "apikey: $PUB" -H "Content-Type: application/json" \
  -d "{\"email\":\"admin@test.local\",\"password\":\"$PW\"}" \
  | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

if [ -z "$TOKEN" ]; then echo "SIGN-IN FAILED"; exit 1; fi

call() { # name endpoint body
  local name="$1" ep="$2" body="${3:-}"
  local total=""
  for i in 1 2 3; do
    local t
    t=$(curl -s -o /dev/null -w "%{time_total}" --max-time 30 \
      -X POST "$URL/rest/v1/rpc/$ep" \
      -H "apikey: $PUB" -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" -d "$body")
    total="$total $t"
  done
  printf "%-28s %s\n" "$name" "$total"
}

call_get() { # name table+query
  local name="$1" path="$2"
  local total=""
  for i in 1 2 3; do
    local t
    t=$(curl -s -o /dev/null -w "%{time_total}" --max-time 30 \
      "$URL/rest/v1/$path" \
      -H "apikey: $PUB" -H "Authorization: Bearer $TOKEN")
    total="$total $t"
  done
  printf "%-28s %s\n" "$name" "$total"
}

echo "endpoint                        run1    run2    run3   (seconds)"
echo "----------------------------------------------------------------"
call  "dashboard.metrics"          "admin_dashboard_metrics" "{}"
call  "products.catalog"           "admin_catalog_snapshot"  '{"p_limit":20,"p_offset":0}'
call  "orders.list"                "admin_orders"            "{}"
call  "orders.statusRules"         "admin_order_status_matrix" "{}"
call  "customers.list"             "admin_customers"         "{}"
call  "customers.metrics"          "admin_customer_metrics"  "{}"
call  "kitchen.filters"            "admin_kitchen_filters"   "{}"
call  "kitchen.board"              "admin_kitchen_board"     "{}"
call  "kitchen.metrics"            "admin_kitchen_metrics"   "{}"
call  "inventory.metrics"          "admin_inventory_metrics" '{"p_branch_id":null}'
call  "inventory.filters"          "admin_inventory_filters" "{}"
call  "stockMovements"             "admin_stock_movement_directory"   '{"p_limit":20,"p_offset":0}'
call  "audit.metrics"              "admin_audit_metrics"     "{}"
call  "audit.directory"            "admin_audit_directory"   '{"p_limit":20,"p_offset":0}'
call  "banners.list(table)"        "" ""
call_get "banners.list"            "banners?select=*&order=sort_order"
call_get "bundles.list"            "bundles?select=*&limit=50"
call  "bundles?via-table"          "admin_nav_counts"        "{}"
call  "coupons.list"               "admin_coupons"           "{}"
call  "coupons.metrics"            "admin_coupon_metrics"    "{}"
call  "branches.list"              "admin_branches"          "{}"
call  "branches.metrics"           "admin_branch_metrics"    "{}"
call  "staff.list"                 "admin_staff"             "{}"
call  "roles.list"                 "admin_roles"             "{}"
call  "permissions"                "admin_permissions"       "{}"
call  "loyalty.overview"           "admin_loyalty_overview"  "{}"
call  "loyalty.rewards"            "admin_loyalty_rewards"   "{}"
call  "notifications.metrics"      "admin_notification_metrics" "{}"
call  "notifications.pushHealth"   "admin_push_health"       "{}"
call  "payments.list"              "admin_payments"          "{}"
call  "reviews.list"               "admin_reviews"           "{}"
call  "reviews.metrics"            "admin_review_metrics"    "{}"
call  "carts.abandoned"            "admin_abandoned_carts"   "{}"
call  "subscriptions.list"         "admin_subscriptions"     "{}"
call  "subscriptionPlans.list"     "admin_subscription_plans" "{}"
call  "tables.overview"            "admin_dining_overview"   "{}"
call  "shell.navCounts"            "admin_nav_counts"        "{}"

// Synthetic, in-memory fixtures for Tap webhook tests only.
// These IDs and contact details are deliberately not persisted to Supabase.
export const testCustomer = {
  id: "tap-test-customer-0001",
  email: "tap-sandbox-customer@example.invalid",
};

export const testOrder = {
  id: "tap-test-order-0001",
  user_id: testCustomer.id,
  grand_total: 100,
  currency_code: "SAR",
  payment_status: "unpaid",
};

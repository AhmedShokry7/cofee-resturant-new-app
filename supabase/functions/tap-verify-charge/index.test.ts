import { chargeMatchesTransaction } from "./index.ts";

const tx = {
  provider_reference: "ch_123",
  amount: 299,
  currency_code: "SAR",
};

Deno.test("only the matching Tap charge can verify a purchase", () => {
  if (
    !chargeMatchesTransaction(
      { id: "ch_123", amount: 299, currency: "SAR" },
      tx,
    )
  ) {
    throw new Error("valid charge rejected");
  }
  for (
    const charge of [
      { id: "ch_other", amount: 299, currency: "SAR" },
      { id: "ch_123", amount: 2.99, currency: "SAR" },
      { id: "ch_123", amount: 299, currency: "USD" },
      { id: "ch_123", amount: Number.NaN, currency: "SAR" },
    ]
  ) {
    if (chargeMatchesTransaction(charge, tx)) {
      throw new Error("mismatched charge accepted");
    }
  }
});

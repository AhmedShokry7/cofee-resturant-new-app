import 'package:new_coffee/features/profile/data/model/faq_model.dart';

List<FaqModel> getFaqsList() {
  return const [
    FaqModel(
      question: "How do I place an order?",
      answer:
          "Browse the menu, tap the + button to add items to your cart, then go to the Cart tab and press Checkout. Choose your address and payment method to finish.",
    ),
    FaqModel(
      question: "How can I track my order?",
      answer:
          "Open My Orders from your profile, then tap Track Order on any active order to see the live status timeline.",
    ),
    FaqModel(
      question: "What payment methods do you accept?",
      answer:
          "We accept credit and debit cards, Paypal, Apple Pay, Google Pay and cash on delivery.",
    ),
    FaqModel(
      question: "Can I cancel my order?",
      answer:
          "Yes, you can cancel an order from the tracking page while it is still being processed.",
    ),
    FaqModel(
      question: "How do I apply a coupon?",
      answer:
          "Open Coupon from Settings, copy the code you like, and apply it at checkout.",
    ),
  ];
}

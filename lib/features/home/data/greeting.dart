String getGreeting(DateTime time) {
  final hour = time.hour;
  if (hour < 12) return "Good Morning";
  if (hour < 17) return "Good Afternoon";
  return "Good Evening";
}

bool isDaytime(DateTime time) => time.hour >= 6 && time.hour < 18;

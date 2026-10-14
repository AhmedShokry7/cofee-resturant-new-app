enum SearchSort {
  relevance("Relevance"),
  priceLowHigh("Price: Low"),
  priceHighLow("Price: High"),
  nameAsc("Name");

  const SearchSort(this.label);

  final String label;
}

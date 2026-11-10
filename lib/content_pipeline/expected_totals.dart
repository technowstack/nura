class ExpectedTotals {
  const ExpectedTotals({
    required this.surahs,
    required this.ayahs,
    required this.books,
    required this.hadiths,
  });

  final int surahs;
  final int ayahs;
  final int books;
  final int hadiths;
}

const ExpectedTotals fullDatasetTotals = ExpectedTotals(
  surahs: 114,
  ayahs: 6236,
  books: 9,
  hadiths: 38102,
);

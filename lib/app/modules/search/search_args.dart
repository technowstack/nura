enum SearchScope { quran, hadith }

class SearchArgs {
  const SearchArgs(this.scope);

  final SearchScope scope;
}

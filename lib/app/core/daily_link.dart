/// Deep link carried by a daily widget entry.
sealed class DailyLink {
  const DailyLink();
}

class AyahLink extends DailyLink {
  const AyahLink(this.surah, this.ayah);

  final int surah;
  final int ayah;
}

class HadithLink extends DailyLink {
  const HadithLink(this.slug, this.number);

  final String slug;
  final int number;
}

int? _positive(String s) {
  if (!RegExp(r'^\d+$').hasMatch(s)) return null;
  return int.tryParse(s);
}

/// Parses `nura://ayah/<surah>/<ayat>` and `nura://hadith/<slug>/<number>`;
/// returns null for anything else.
DailyLink? parseDailyLink(String uri) {
  final u = Uri.tryParse(uri);
  if (u == null || u.scheme != 'nura' || u.pathSegments.length != 2) {
    return null;
  }
  final a = u.pathSegments[0];
  final b = u.pathSegments[1];
  switch (u.host) {
    case 'ayah':
      final surah = _positive(a);
      final ayah = _positive(b);
      return surah == null || ayah == null ? null : AyahLink(surah, ayah);
    case 'hadith':
      final n = _positive(b);
      return a.isEmpty || n == null ? null : HadithLink(a, n);
  }
  return null;
}

import 'package:flutter/material.dart';

import '../../../core/search_snippet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../controllers/search_results_controller.dart';

/// [s] as one span: "…" where the source was cut, highlights on
/// [highlight] background (spec 5.5).
InlineSpan snippetSpan(Snippet s, TextStyle base, Color highlight) {
  final mark = TextStyle(backgroundColor: highlight);
  final children = <InlineSpan>[if (s.cutStart) const TextSpan(text: '…')];
  var at = 0;
  for (final h in s.highlights) {
    if (h.start > at) {
      children.add(TextSpan(text: s.text.substring(at, h.start)));
    }
    children.add(TextSpan(text: s.text.substring(h.start, h.end), style: mark));
    at = h.end;
  }
  if (at < s.text.length) children.add(TextSpan(text: s.text.substring(at)));
  if (s.cutEnd) children.add(const TextSpan(text: '…'));
  return TextSpan(style: base, children: children);
}

// Latin letters, then the Arabic blocks (U+0600 and up).
final _strongLetter = RegExp(
  r'[A-Za-z\u00C0-\u024F\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFC]',
);

/// True when the first strong letter of [text] is Arabic.
bool _isArabic(String text) =>
    (_strongLetter.firstMatch(text)?.group(0)?.codeUnitAt(0) ?? 0) >= 0x0600;

/// One search result: label ("Ayat 45" / "No. 4.066") and its snippet.
// UI sementara: hadith and Arabic results are not designed yet; ayah
// translation results follow screen 10.
class SearchResultTile extends StatelessWidget {
  const SearchResultTile({required this.item, required this.onTap, super.key});

  final SearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final snippet = item.hit.snippet;
    final arabic = _isArabic(snippet.text);
    final base = arabic
        ? context.nuraText.arabicCard.copyWith(
            color: context.nuraColors.arabicText,
          )
        : context.nuraText.translation.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          );
    return ListTile(
      onTap: onTap,
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: NuraSpace.s16),
      title: Text(item.label, style: Theme.of(context).textTheme.labelLarge),
      subtitle: Text.rich(
        snippetSpan(snippet, base, context.nuraColors.searchHighlight),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      ),
    );
  }
}

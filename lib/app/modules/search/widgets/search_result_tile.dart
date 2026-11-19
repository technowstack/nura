import 'package:flutter/material.dart';

import '../../../core/ayah_marker.dart';
import '../../../core/search_snippet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/nura_card.dart';
import '../../../data/models/search_hit.dart';
import '../controllers/search_results_controller.dart';

/// [s] as one span: "…" where the source was cut, highlights on
/// [highlight] background (spec 5.5).
InlineSpan snippetSpan(
  Snippet s,
  TextStyle base,
  Color highlight, {
  String suffix = '',
}) {
  final mark = TextStyle(backgroundColor: highlight);
  final children = <InlineSpan>[if (s.cutStart) const TextSpan(text: '…')];
  // The marker follows the text directly, so trailing ASCII spaces go.
  var end = s.text.length;
  if (suffix.isNotEmpty) {
    while (end > 0 && s.text.codeUnitAt(end - 1) == 0x20) {
      end--;
    }
  }
  var at = 0;
  for (final h in s.highlights) {
    final hs = h.start.clamp(0, end);
    final he = h.end.clamp(0, end);
    if (hs > at) children.add(TextSpan(text: s.text.substring(at, hs)));
    if (he > hs) {
      children.add(TextSpan(text: s.text.substring(hs, he), style: mark));
    }
    at = he > at ? he : at;
  }
  if (at < end) children.add(TextSpan(text: s.text.substring(at, end)));
  if (s.cutEnd) children.add(const TextSpan(text: '…'));
  if (suffix.isNotEmpty) children.add(TextSpan(text: suffix));
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
    final hit = item.hit;
    // The end marker is display-only and only for a whole ayah; a cut
    // snippet or the snippet data itself is never altered.
    final marker =
        arabic && hit is AyahSearchHit && !snippet.cutStart && !snippet.cutEnd
        ? ayahDisplayText('', hit.ayahNumber)
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NuraSpace.s16,
        vertical: NuraSpace.s4,
      ),
      child: NuraCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.nuraColors.iconAccent,
              ),
            ),
            const SizedBox(height: NuraSpace.s8),
            Text.rich(
              snippetSpan(
                snippet,
                base,
                context.nuraColors.searchHighlight,
                suffix: marker,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/modules/hadith_list/hadith_preview.dart';

void main() {
  test('starts after the opening quote of the first bersabda:', () {
    expect(
      hadithPreview('Nabi saw bersabda: "Tidaklah beriman kalian"'),
      'Tidaklah beriman kalian"',
    );
  });

  test('curly quotes', () {
    expect(hadithPreview('Beliau bersabda: “Isi matan”'), 'Isi matan”');
  });

  test('closing curly quote is not an opener', () {
    expect(hadithPreview('Beliau bersabda: ”x”'), 'Beliau bersabda: ”x”');
  });

  // Owner decision 2026-11-23: single quotes open the quotation too (when
  // closed); this test used to pin the start-of-text fallback.
  test('closed single quote opener starts at the quoted content', () {
    expect(hadithPreview("Beliau bersabda: 'Isi'"), "Isi'");
  });

  test('no quote at all falls back to the start of the text', () {
    expect(hadithPreview('Beliau bersabda'), 'Beliau bersabda');
  });

  test('no bersabda: starts from the beginning', () {
    expect(hadithPreview('Telah menceritakan kami'), 'Telah menceritakan kami');
  });

  test('bersabda: without a quote starts from the beginning', () {
    expect(hadithPreview('Beliau bersabda: Isi'), 'Beliau bersabda: Isi');
  });

  test('empty quoted content starts from the beginning', () {
    expect(hadithPreview('Beliau bersabda: "'), 'Beliau bersabda: "');
    expect(hadithPreview('Beliau bersabda:\n  "  '), 'Beliau bersabda:\n  "  ');
  });

  test('first occurrence wins', () {
    expect(
      hadithPreview('a bersabda: "satu" b bersabda: "dua"'),
      'satu" b bersabda: "dua"',
    );
  });

  test('case-insensitive', () {
    expect(hadithPreview('Rasul Bersabda: "Isi"'), 'Isi"');
  });

  test('whitespace and newlines after the colon and quote', () {
    expect(hadithPreview('bersabda:\n\t "  \n Isi'), 'Isi');
  });

  test('truncated right at bersabda: or inside the quote', () {
    expect(hadithPreview('Beliau bersabda:'), 'Beliau bersabda:');
    expect(hadithPreview('Beliau bersabda: "Ti'), 'Ti');
  });

  test('max length with ellipsis, code points kept whole', () {
    final long = 'x' * 205;
    expect(hadithPreview(long), '${'x' * 200}…');
    expect(hadithPreview('x' * 200), 'x' * 200);
    expect(hadithPreview('\u{1F600}' * 5, maxChars: 3), '${'\u{1F600}' * 3}…');
  });

  group('single quotes', () {
    test('open the quotation when a closing single quote follows', () {
      expect(hadithPreview("Beliau bersabda: 'Isi hadis.'"), "Isi hadis.'");
      expect(
        hadithPreview('Beliau bersabda: \u2018Isi hadis.\u2019'),
        'Isi hadis.\u2019',
      );
      expect(hadithPreview("bersabda:\n '  Isi' lagi"), "Isi' lagi");
    });

    test('no closing quote: from the beginning (truncated in the quote)', () {
      expect(
        hadithPreview("Beliau bersabda: 'Isi hadis"),
        "Beliau bersabda: 'Isi hadis",
      );
      expect(hadithPreview("Beliau bersabda: 'Ti"), "Beliau bersabda: 'Ti");
    });

    test('in-word apostrophes are not closing quotes', () {
      expect(
        hadithPreview("Beliau bersabda: 'Ya'qub dan 'Umar"),
        "Beliau bersabda: 'Ya'qub dan 'Umar",
      );
      expect(
        hadithPreview('bersabda: \u2018Ibnu \u2018Umar'),
        'bersabda: \u2018Ibnu \u2018Umar',
      );
      // A later real closing quote still counts.
      expect(hadithPreview("bersabda: 'Ya'qub datang.'"), "Ya'qub datang.'");
    });

    test('double quotes are unchanged', () {
      expect(hadithPreview('bersabda: "Isi \'x\' lagi"'), "Isi 'x' lagi\"");
      expect(hadithPreview('bersabda: "Isi'), 'Isi');
    });
  });

  test('19 source-truncated hadith (Q12) never throw and stay substrings', () {
    var checked = 0;
    for (final f in Directory(
      'data-source/hadith',
    ).listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      for (final h in jsonDecode(f.readAsStringSync()) as List) {
        final tr = (h as Map)['id'] as String;
        if (utf8.encode(tr).length < 16374) continue; // Q12 threshold
        checked++;
        // Full text, and the 1000-char prefix the repository supplies.
        for (final src in [tr, String.fromCharCodes(tr.runes.take(1000))]) {
          final p = hadithPreview(src);
          expect(p, isNotEmpty);
          expect(
            src,
            contains(p.endsWith('…') ? p.substring(0, p.length - 1) : p),
          );
        }
      }
    }
    expect(checked, 7); // 7 of the 19 have a truncated translation
  });

  test('real data: how many single-quoted matan now get a quoted preview', () {
    // The repository supplies the first 1000 characters of the translation.
    final opener = RegExp(
      'bersabda:\\s*(["\u201c\'\u2018])',
      caseSensitive: false,
    );
    var single = 0;
    var fromQuote = 0;
    for (final f in Directory(
      'data-source/hadith',
    ).listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      for (final h in jsonDecode(f.readAsStringSync()) as List) {
        final full = (h as Map)['id'] as String;
        final tr = String.fromCharCodes(full.runes.take(1000));
        final m = opener.firstMatch(tr);
        if (m == null || '"\u201c'.contains(m.group(1) ?? '"')) continue;
        single++;
        final p = hadithPreview(tr, maxChars: 100000);
        if (p != tr) fromQuote++;
      }
    }
    // Measured 2026-11-23: 708 single-quoted, 473 now quoted, 235 closed-less.
    expect(fromQuote, 473);
    expect(single, greaterThan(0));
  });
}

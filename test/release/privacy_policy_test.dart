import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final md = File('docs/release/privacy-policy.md').readAsStringSync();
  final page = File('docs/release/privacy-policy.html').readAsStringSync();

  test('page and markdown have the same section headings', () {
    final inMd = RegExp(
      r'^## (.+)$',
      multiLine: true,
    ).allMatches(md).map((m) => m.group(1)).toList();
    final inPage = RegExp(
      r'<h2>(.+?)</h2>',
    ).allMatches(page).map((m) => m.group(1)).toList();
    expect(inMd, contains('Cadangan Android'));
    expect(inPage, inMd);
  });

  test('owner placeholders are still unfilled in both', () {
    for (final text in [md, page.replaceAll(RegExp(r'<\/?mark>'), '')]) {
      expect(text, contains('[ISI] (tanggal berlaku)'));
      expect(text, contains('[ISI] (email kontak)'));
    }
  });

  test('page is self-contained', () {
    expect(page, contains('lang="id"'));
    for (final external in ['<script', '<link', '<img', '@import', 'url(']) {
      expect(page, isNot(contains(external)));
    }
  });
}

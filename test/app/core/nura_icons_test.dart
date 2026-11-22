import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/nura_icons.dart';

void main() {
  test('lib has no Material Icons and no tree-shake-breaking imports', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (RegExp(r'(?<![A-Za-z])Icons\.').hasMatch(src) ||
          src.contains('material_symbols_icons/get.dart') ||
          src.contains('symbols_map.dart')) {
        bad.add(f.path);
      }
    }
    expect(bad, isEmpty);
  });

  testWidgets('NuraIcon renders weight 300 and fill by flag', (t) async {
    await t.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            NuraIcon(NuraIcons.bookmark),
            NuraIcon(NuraIcons.bookmark, filled: true),
          ],
        ),
      ),
    );
    final icons = t.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons.map((i) => i.weight), [300, 300]);
    expect(icons.map((i) => i.fill), [0, 1]);
  });
}

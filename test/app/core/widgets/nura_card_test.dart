import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/widgets/nura_card.dart';

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'NuraCard uses token color, border, radius (${theme.brightness})',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(body: NuraCard(child: Text('x'))),
          ),
        );
        final m = t.widget<Material>(
          find.descendant(
            of: find.byType(NuraCard),
            matching: find.byType(Material),
          ),
        );
        expect(m.color, theme.colorScheme.surfaceContainerLowest);
        final s = m.shape! as RoundedRectangleBorder; // set by NuraCard
        expect(s.side.color, theme.colorScheme.outlineVariant);
        expect(s.side.width, 1);
        expect(s.borderRadius, BorderRadius.circular(16));
      },
    );
  }

  testWidgets('NuraCard with onTap has >= 48 tap area and fires', (t) async {
    var n = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: NuraCard(
              padding: EdgeInsets.zero,
              onTap: () => n++,
              child: const SizedBox(width: 10, height: 10),
            ),
          ),
        ),
      ),
    );
    expect(t.getSize(find.byType(InkWell)).height, greaterThanOrEqualTo(48));
    await t.tap(find.byType(InkWell));
    expect(n, 1);
  });
}

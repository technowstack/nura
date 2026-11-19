import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/widgets/ornament_badge.dart';

void main() {
  Widget app(ThemeData theme) => MaterialApp(
    theme: theme,
    home: const Scaffold(
      body: Center(child: OrnamentBadge(label: '7')),
    ),
  );

  Color strokeColor(WidgetTester t) {
    final p = t
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(OrnamentBadge),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter!;
    return (p as dynamic).color as Color;
  }

  testWidgets('36 by default, label as semantics text', (t) async {
    await t.pumpWidget(app(AppTheme.light));
    expect(t.getSize(find.byType(OrnamentBadge)), const Size(36, 36));
    expect(find.text('7'), findsOneWidget);
    expect(find.bySemanticsLabel('7'), findsOneWidget);
  });

  testWidgets('uses iconAccent and repaints on theme switch', (t) async {
    await t.pumpWidget(app(AppTheme.light));
    expect(strokeColor(t), const Color(0xFF8A6A3E));
    await t.pumpWidget(app(AppTheme.dark));
    await t.pumpAndSettle();
    expect(strokeColor(t), const Color(0xFFD9BE92));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/widgets/ornament_badge.dart';

void main() {
  testWidgets('OrnamentBadge is 36 by default and shows its label', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(child: OrnamentBadge(label: '7')),
        ),
      ),
    );
    expect(t.getSize(find.byType(OrnamentBadge)), const Size(36, 36));
    expect(find.text('7'), findsOneWidget);
    expect(find.bySemanticsLabel('7'), findsOneWidget);
  });
}

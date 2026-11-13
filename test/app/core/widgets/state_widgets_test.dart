import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/widgets/empty_state.dart';
import 'package:nura/app/core/widgets/error_state.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('ErrorState shows text and retries', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      wrap(
        ErrorState(
          title: 'Gagal',
          description: 'Terjadi masalah',
          onRetry: () => retried++,
        ),
      ),
    );
    expect(find.text('Gagal'), findsOneWidget);
    expect(find.text('Terjadi masalah'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    expect(retried, 1);
  });

  testWidgets('EmptyState without description renders no empty text', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const EmptyState(title: 'Kosong')));
    expect(find.text('Kosong'), findsOneWidget);
    expect(find.text(''), findsNothing);
  });
}

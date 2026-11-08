import 'package:flutter_test/flutter_test.dart';
import 'package:nura/main.dart';

void main() {
  testWidgets('app boots and shows Beranda', (tester) async {
    await tester.pumpWidget(const NuraApp());
    expect(find.text('Beranda'), findsOneWidget);
  });
}

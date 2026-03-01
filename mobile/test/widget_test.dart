import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('Smart Home Controller'), findsOneWidget);
  });
}

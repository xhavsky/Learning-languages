import 'package:flutter_test/flutter_test.dart';
import 'package:trener_jezykowy/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const TrenerApp());
    await tester.pump();
    expect(find.text('Trener Językowy'), findsOneWidget);
  });
}

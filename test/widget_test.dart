import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/app.dart'; // use the "name:" from your pubspec.yaml

void main() {
  testWidgets('app shell renders with navigation', (tester) async {
    await tester.pumpWidget(const GrihSetuApp(webFonts: false));
    expect(find.text('GrihSetu'), findsOneWidget);
    expect(find.text('Today'), findsWidgets); // default role: technician
  });
}

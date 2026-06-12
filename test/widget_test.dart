import 'package:flutter_test/flutter_test.dart';
import 'package:vizion_mobile/main.dart';

void main() {
  testWidgets('App basic smoke test', (WidgetTester tester) async {
    // Build our app with a logged-out initial state and trigger a frame.
    await tester.pumpWidget(const VizionApp(isLoggedIn: false));

    // Verify that we are on the login screen
    expect(find.text('VIZION'), findsOneWidget);
  });
}

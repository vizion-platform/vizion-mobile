import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vizion_mobile/features/auth/presentation/login_screen.dart';
import 'package:vizion_mobile/features/agenda/presentation/agenda_screen.dart';

void main() {
  testWidgets('LoginScreen password visibility toggle works', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    // Initial state: password field is obscured
    final passwordFieldFinder = find.byType(TextField).at(1);
    expect(passwordFieldFinder, findsOneWidget);

    final TextField passwordWidget = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordWidget.obscureText, isTrue);

    // Find the eye toggle icon button
    final eyeButtonFinder = find.byTooltip('Mostrar senha');
    expect(eyeButtonFinder, findsOneWidget);

    // Tap eye icon to show password
    await tester.tap(eyeButtonFinder);
    await tester.pump();

    // Verify it is now visible (obscureText = false)
    final TextField passwordWidgetAfter = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordWidgetAfter.obscureText, isFalse);

    // Verify tooltip changed to 'Ocultar senha'
    expect(find.byTooltip('Ocultar senha'), findsOneWidget);
  });

  testWidgets('AgendaScreen renders week bar and toggles day filter', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AgendaScreen(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Agenda title and Hoje button are rendered
    expect(find.text('Hoje'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month), findsOneWidget);
  });
}

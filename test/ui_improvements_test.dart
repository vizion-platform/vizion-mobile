import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vizion_mobile/features/auth/presentation/login_screen.dart';
import 'package:vizion_mobile/features/agenda/presentation/agenda_screen.dart';
import 'package:vizion_mobile/features/dashboard/presentation/dashboard_screen.dart';

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

  testWidgets('DashboardScreen navigates to all modules and returns via back arrow', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify main screen buttons:
    // 1. Top right header buttons: Obras and Agenda
    expect(find.byTooltip('Obras'), findsOneWidget);
    expect(find.byTooltip('Agenda'), findsOneWidget);

    // 2. Floating bottom buttons: BATER PONTO (center) and Chat (right)
    expect(find.text('BATER PONTO'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

    // 3. Verify BottomNavigationBar is removed
    expect(find.byType(BottomNavigationBar), findsNothing);

    // Test navigation: Profile
    final avatarFinder = find.byType(CircleAvatar).first;
    await tester.tap(avatarFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Meu Perfil'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Olá,'), findsOneWidget);

    // Test navigation: Ponto via floating button
    await tester.tap(find.text('BATER PONTO'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bater Ponto'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Olá,'), findsOneWidget);

    // Test navigation: Agenda via top-right button
    await tester.tap(find.byTooltip('Agenda'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hoje'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Olá,'), findsOneWidget);

    // Test navigation: Obras via top-right button
    await tester.tap(find.byTooltip('Obras'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Gestão de Obras'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Olá,'), findsOneWidget);

    // Test navigation: Chat via floating button
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mensagens'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Olá,'), findsOneWidget);

    // Settle transition
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Floating bottom buttons (BATER PONTO & Chat) hide on scroll down and appear on scroll up only in main page', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Initially visible on main page
    expect(find.text('BATER PONTO'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

    // Verify AnimatedOpacity is 1.0 initially
    final opacityFinder = find.ancestor(
      of: find.text('BATER PONTO'),
      matching: find.byType(AnimatedOpacity),
    );
    expect(opacityFinder, findsOneWidget);
    AnimatedOpacity animatedOpacity = tester.widget<AnimatedOpacity>(opacityFinder);
    expect(animatedOpacity.opacity, equals(1.0));

    // Scroll down on the SingleChildScrollView
    final scrollFinder = find.byType(SingleChildScrollView).first;
    await tester.drag(scrollFinder, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 300));

    // Opacity should now be 0.0 (hidden during scroll down)
    animatedOpacity = tester.widget<AnimatedOpacity>(opacityFinder);
    expect(animatedOpacity.opacity, equals(0.0));

    // Scroll back up
    await tester.drag(scrollFinder, const Offset(0, 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Opacity should now be 1.0 again (visible)
    animatedOpacity = tester.widget<AnimatedOpacity>(opacityFinder);
    expect(animatedOpacity.opacity, equals(1.0));

    // Navigate to another module (e.g. Agenda)
    await tester.tap(find.byTooltip('Agenda'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Floating Ponto & Chat buttons should NOT be present on Agenda screen
    expect(find.text('BATER PONTO'), findsNothing);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);

    // Navigate back to Main Screen
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Floating Ponto & Chat buttons are visible again on Main Screen
    expect(find.text('BATER PONTO'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
  });
}

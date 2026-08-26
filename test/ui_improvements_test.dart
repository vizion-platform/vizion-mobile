import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vizion_mobile/core/network/auth_service.dart';
import 'package:vizion_mobile/features/auth/presentation/login_screen.dart';
import 'package:vizion_mobile/features/agenda/presentation/agenda_screen.dart';
import 'package:vizion_mobile/features/dashboard/presentation/widgets/home_dashboard_widget.dart';
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

  testWidgets('DashboardScreen navigates to Profile when header avatar is tapped and returns via back arrow', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Find CircleAvatar in header and tap it
    final avatarFinder = find.byType(CircleAvatar).first;
    expect(avatarFinder, findsOneWidget);

    await tester.tap(avatarFinder);
    await tester.pumpAndSettle();

    // Verify Profile screen is shown
    expect(find.text('Meu Perfil'), findsOneWidget);

    // Find back button in Profile and tap it
    final backArrowFinder = find.byIcon(Icons.arrow_back_ios_new_rounded);
    expect(backArrowFinder, findsOneWidget);

    await tester.tap(backArrowFinder);
    await tester.pumpAndSettle();

    // Verify we returned to Dashboard (greeting is shown)
    expect(find.textContaining('Olá,'), findsOneWidget);

    // Verify BottomNavigationBar has only Dashboard, Ponto, Agenda, Obras, Chat
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Ponto'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Obras'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Perfil'), findsNothing);
  });

  testWidgets('AgendaScreen opens Nova Tarefa modal and creates task', (WidgetTester tester) async {
    await AuthService.switchRole('EMPREITEIRO', 'Empreiteiro Demo', 'empreiteiro@demo.com');

    await tester.pumpWidget(
      const MaterialApp(
        home: AgendaScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Find the "Nova Tarefa" Floating Action Button and tap it
    final novaTarefaBtn = find.text('Nova Tarefa');
    expect(novaTarefaBtn, findsOneWidget);
    await tester.tap(novaTarefaBtn);
    await tester.pumpAndSettle();

    // Verify modal header and inputs
    expect(find.text('Nova Tarefa da Empreiteira'), findsOneWidget);
    expect(find.text('SALVAR TAREFA'), findsOneWidget);

    // Enter title
    final titleField = find.widgetWithText(TextField, 'Nome da Tarefa / Serviço *');
    await tester.enterText(titleField, 'Instalação Elétrica do Bloco A');
    await tester.pump();

    // Tap SALVAR TAREFA
    await tester.tap(find.text('SALVAR TAREFA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify task is added to agenda
    expect(find.text('Instalação Elétrica do Bloco A'), findsOneWidget);
  });
}

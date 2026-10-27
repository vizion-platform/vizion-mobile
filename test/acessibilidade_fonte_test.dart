import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizion_mobile/core/network/auth_service.dart';
import 'package:vizion_mobile/core/theme/app_theme.dart';
import 'package:vizion_mobile/features/agenda/presentation/agenda_screen.dart';
import 'package:vizion_mobile/features/ponto/presentation/ponto_screen.dart';
import 'package:vizion_mobile/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.definirPapelParaTeste('GESTOR', 'Gestor Demo', 'gestor@demo.com');
  });

  tearDown(() => AppTheme.fontScale.value = 1.0);

  testWidgets('letra ampliada (1,3x) aplica a escala a todo o app e nenhuma tela estoura', (tester) async {
    // Celular de 360 dp de largura.
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    AppTheme.fontScale.value = 1.3;
    await tester.pumpWidget(const VizionApp(isLoggedIn: true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: 'dashboard com letra ampliada');

    // Perfil: a opção de acessibilidade aparece e o layout cabe.
    await tester.tap(find.byType(CircleAvatar).first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Acessibilidade'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'perfil com letra ampliada');

    // Escolher uma opção salva a preferência e a aplica.
    await tester.tap(find.text('Muito maior'));
    await tester.pump();
    expect(AppTheme.fontScale.value, 1.3);

    // Agenda e Ponto também cabem na tela com a letra ampliada.
    navigatorKey.currentState!.popUntil((route) => route.isFirst);
    await tester.pump(const Duration(milliseconds: 500));
    navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const AgendaScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: 'agenda com letra ampliada');

    navigatorKey.currentState!.pop();
    await tester.pump(const Duration(milliseconds: 500));
    navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const PontoScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: 'ponto com letra ampliada');
  });
}

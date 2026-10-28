import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizion_mobile/core/network/auth_service.dart';
import 'package:vizion_mobile/core/theme/app_theme.dart';
import 'package:vizion_mobile/features/acessibilidade/presentation/acessibilidade_screen.dart';

Future<void> _abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: AcessibilidadeScreen()));
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppTheme.restaurarAcessibilidade();
  });

  tearDown(() async {
    await AppTheme.restaurarAcessibilidade();
  });

  testWidgets('mostra as opções de acessibilidade sem estourar a tela', (tester) async {
    await _abrir(tester);

    expect(find.text('Acessibilidade'), findsOneWidget);
    expect(find.text('Tamanho da letra'), findsOneWidget);
    for (final opcao in AppTheme.opcoesFonte) {
      expect(find.text(opcao.rotulo), findsOneWidget);
    }
    expect(find.text('Texto em negrito'), findsOneWidget);
    expect(find.text('Reduzir animações'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('escolher o tamanho da letra aplica e salva a preferência', (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Maior'));
    await tester.pump();

    expect(AppTheme.fontScale.value, 1.15);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('vizion_font_scale'), 1.15);
  });

  testWidgets('negrito e animações ligam e desligam', (tester) async {
    await _abrir(tester);

    await tester.ensureVisible(find.text('Texto em negrito'));
    await tester.pump();
    await tester.tap(find.text('Texto em negrito'));
    await tester.pump();
    expect(AppTheme.boldText.value, isTrue);

    await tester.ensureVisible(find.text('Reduzir animações'));
    await tester.pump();
    await tester.tap(find.text('Reduzir animações'));
    await tester.pump();
    expect(AppTheme.reduceMotion.value, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('vizion_bold_text'), isTrue);
    expect(prefs.getBool('vizion_reduce_motion'), isTrue);
  });

  testWidgets('restaurar padrão desfaz as escolhas', (tester) async {
    await _abrir(tester);
    await AppTheme.setFontScale(1.3);
    await AppTheme.setBoldText(true);
    await tester.pump();

    await tester.ensureVisible(find.text('Restaurar padrão'));
    await tester.tap(find.text('Restaurar padrão'));
    await tester.pump();

    expect(AppTheme.fontScale.value, 1.0);
    expect(AppTheme.boldText.value, isFalse);
    expect(AppTheme.acessibilidadePadrao, isTrue);
  });

  test('sair da conta não apaga as preferências de acessibilidade', () async {
    SharedPreferences.setMockInitialValues({
      'vizion_font_scale': 1.3,
      'vizion_bold_text': true,
      'vizion_reduce_motion': true,
      'vizion_theme': 'dark',
      'vizion_last_email': 'ana@empresa.com',
      'vizion_agenda_cache': 'dados de outro usuário',
    });

    await AuthService.signOut();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('vizion_font_scale'), 1.3);
    expect(prefs.getBool('vizion_bold_text'), isTrue);
    expect(prefs.getBool('vizion_reduce_motion'), isTrue);
    expect(prefs.getString('vizion_theme'), 'dark');
    expect(prefs.getString('vizion_last_email'), 'ana@empresa.com');
    expect(prefs.containsKey('vizion_agenda_cache'), isFalse);
  });
}

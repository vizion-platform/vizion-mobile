import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizion_mobile/features/auth/presentation/login_screen.dart';

Future<void> _abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    routes: {'/acessibilidade': (_) => const Scaffold(body: Text('pagina acessibilidade'))},
    home: const LoginScreen(),
  ));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('preenche o último e-mail usado no aparelho', (tester) async {
    SharedPreferences.setMockInitialValues({'vizion_last_email': 'ana@empresa.com.br'});
    await _abrir(tester);

    expect(find.widgetWithText(TextFormField, 'ana@empresa.com.br'), findsOneWidget);
  });

  testWidgets('aceita e-mail com final longo e com espaços nas pontas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final chamadas = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      chamadas.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({'message': 'erro'}), 401);
    });

    await http.runWithClient(() async {
      await _abrir(tester);
      await tester.enterText(find.byType(TextFormField).first, '  ana@empresa.engenharia  ');
      await tester.enterText(find.byType(TextFormField).last, 'segredo');
      await tester.tap(find.text('Entrar'));
      await tester.pump(const Duration(milliseconds: 300));
    }, () => client);

    expect(find.text('Insira um e-mail válido.'), findsNothing);
    expect(chamadas, isNotEmpty);
    expect(chamadas.first['email'], 'ana@empresa.engenharia');
  });

  testWidgets('e-mail sem arroba mostra uma mensagem que explica o que falta', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _abrir(tester);

    await tester.enterText(find.byType(TextFormField).first, 'ana.empresa.com');
    await tester.enterText(find.byType(TextFormField).last, 'segredo');
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.textContaining('falta algo'), findsOneWidget);
  });

  testWidgets('esqueci minha senha explica o que fazer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _abrir(tester);

    await tester.ensureVisible(find.text('Esqueci minha senha'));
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('responsável pela sua empreiteira'), findsOneWidget);
  });

  testWidgets('botão de acessibilidade abre a página antes do login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _abrir(tester);

    await tester.tap(find.byTooltip('Acessibilidade'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('pagina acessibilidade'), findsOneWidget);
  });
}

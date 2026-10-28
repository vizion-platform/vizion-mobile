// Gera capturas PNG das telas principais (tema claro e escuro) para revisão visual.
// Só roda quando SCREENSHOT_DIR é informado:
//   flutter test test/visual --dart-define=SCREENSHOT_DIR=/tmp/vizion-shots
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizion_mobile/core/network/auth_service.dart';
import 'package:vizion_mobile/core/theme/app_theme.dart';
import 'package:vizion_mobile/features/acessibilidade/presentation/acessibilidade_screen.dart';
import 'package:vizion_mobile/features/agenda/presentation/agenda_screen.dart';
import 'package:vizion_mobile/features/auth/presentation/change_password_screen.dart';
import 'package:vizion_mobile/features/auth/presentation/login_screen.dart';
import 'package:vizion_mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:vizion_mobile/features/ponto/presentation/ponto_screen.dart';

const _dir = String.fromEnvironment('SCREENSHOT_DIR');

/// Ícones do Material: o runner de testes não os carrega sozinho (apareceriam como quadrados).
Future<void> _loadMaterialIcons() async {
  const defineRoot = String.fromEnvironment('FLUTTER_ROOT');
  final root = defineRoot.isNotEmpty ? defineRoot : (Platform.environment['FLUTTER_ROOT'] ?? '');
  final file = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!file.existsSync()) return;
  final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
  await loader.load();
}

Future<void> _loadInter() async {
  final loader = FontLoader('Inter');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$f.ttf'));
  }
  await loader.load();
}

final _api = MockClient((req) async {
  const h = {'content-type': 'application/json'};
  final path = req.url.path;
  if (path.endsWith('/obra/minhas-obras')) {
    return http.Response(
        jsonEncode([
          {'id': 1, 'nome_projeto': 'Residencial Aurora', 'status': 'EM_ANDAMENTO', 'data_inicio': '2026-03-01', 'data_previsao_entrega': '2027-02-01', 'progresso': 68, 'localizacao': 'São Paulo - SP'},
          {'id': 2, 'nome_projeto': 'Galpão Logístico Norte', 'status': 'AGUARDANDO_ACEITE', 'data_inicio': '2026-06-10', 'data_previsao_entrega': '2027-05-01', 'progresso': 12, 'localizacao': 'Guarulhos - SP'},
        ]),
        200,
        headers: h);
  }
  if (path.endsWith('/ponto/meu-ponto')) return http.Response('[]', 200, headers: h);
  return http.Response('[]', 200, headers: h);
});

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await File('$_dir/$name.png').writeAsBytes(bytes.buffer.asUint8List());
  });
}

void main() {
  final enabled = _dir.isNotEmpty;

  Future<void> render(WidgetTester tester, String name, Widget screen, {required bool dark}) async {
    SharedPreferences.setMockInitialValues({});
    AuthService.definirPapelParaTeste('EMPREITEIRO', 'Ana Gestora', 'ana@vizion.app');
    AppTheme.mode.value = dark ? ThemeMode.dark : ThemeMode.light;
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await http.runWithClient(() async {
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.theme, home: screen),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await _shot(tester, key, '${dark ? 'dark' : 'light'}_$name');
      // Descarta a árvore para cancelar timers (polling) das telas.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    }, () => _api);
  }

  final screens = <String, Widget Function()>{
    'login': () => const LoginScreen(),
    'dashboard': () => const DashboardScreen(),
    'ponto': () => const PontoScreen(),
    'agenda': () => const AgendaScreen(),
    'trocar_senha': () => const ChangePasswordScreen(),
    'acessibilidade': () => const AcessibilidadeScreen(),
  };

  setUpAll(() async {
    if (enabled) {
      TestWidgetsFlutterBinding.ensureInitialized();
      await _loadInter();
      await _loadMaterialIcons();
      Directory(_dir).createSync(recursive: true);
    }
  });

  for (final dark in [false, true]) {
    for (final e in screens.entries) {
      testWidgets('captura ${e.key} (${dark ? 'escuro' : 'claro'})', (tester) async {
        await render(tester, e.key, e.value(), dark: dark);
      }, skip: !enabled);
    }
  }
}

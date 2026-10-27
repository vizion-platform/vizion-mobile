import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizion_mobile/core/network/auth_service.dart';
import 'package:vizion_mobile/features/dashboard/presentation/obra_details_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.definirPapelParaTeste('EMPREITEIRO', 'Empreiteiro Demo', 'empreiteiro@demo.com');
  });

  testWidgets('obra mostra o avanço, a observação enviada com a foto e campo de observação', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final api = MockClient((req) async {
      final json = {'content-type': 'application/json'};
      if (req.url.path.endsWith('/obra/10/detalhar')) {
        return http.Response(jsonEncode({
          'fases': [
            {'id_fase': 5, 'nome_fase': 'Fundação', 'status': 'EM_ANDAMENTO', 'ordem_exibicao': 1, 'descricao': ''},
            {'id_fase': 6, 'nome_fase': 'Alvenaria', 'status': 'FINALIZADA', 'ordem_exibicao': 2, 'descricao': ''},
          ],
        }), 200, headers: json);
      }
      if (req.url.path.endsWith('/obra-fotos/obra/10')) {
        return http.Response(jsonEncode([
          {
            'id': 1,
            'idObra': 10,
            'idFase': 5,
            'urlFoto': 'obras/10/fases/5/foto.jpg',
            'descricao': 'Concretagem da sapata concluída',
            'dataFoto': '2026-10-20T10:00:00',
          },
        ]), 200, headers: json);
      }
      return http.Response('[]', 200, headers: json);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        home: ObraDetailsScreen(obra: {'id': 10, 'nome_projeto': 'Casa Teste'}),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }, () => api);

    // Fase concluída (1) + fase em andamento com foto (0,5) de 2 fases = 75%, o mesmo valor da dashboard.
    expect(find.text('75% concluído'), findsOneWidget);
    // Observação enviada junto com a foto aparece para o cliente.
    expect(find.text('Concretagem da sapata concluída'), findsOneWidget);
    // Campo de observação disponível para quem registra fotos.
    expect(find.text('Observação do andamento'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

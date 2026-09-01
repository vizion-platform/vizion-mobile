import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vizion_mobile/core/network/auth_service.dart';
import 'package:vizion_mobile/features/dashboard/presentation/obra_details_screen.dart';

void main() {
  test('avanço considera somente fases efetivamente concluídas', () {
    final progress = calculatePhaseProgress([
      {'status': 'FINALIZADA'},
      {'status': 'EM_ANDAMENTO'},
      {'status': 'PLANEJADA'},
      {'status': 'CONCLUIDO'},
    ]);

    expect(progress, 0.5);
  });

  test('foto é enviada ao storage antes de ser registrada na fase', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/storage/upload')) {
        return http.Response(jsonEncode({'key': 'obras/10/fases/5/foto.jpg'}), 200);
      }
      final payload = jsonDecode(request.body);
      expect(payload['idObra'], 10);
      expect(payload['idFase'], 5);
      expect(payload['urlFoto'], 'obras/10/fases/5/foto.jpg');
      return http.Response(jsonEncode({
        'id': 88,
        'idObra': 10,
        'idFase': 5,
        'urlFoto': payload['urlFoto'],
      }), 201);
    });

    final photo = await http.runWithClient(
      () => AuthService.addPhasePhoto(10, 5, [1, 2, 3], 'foto.jpg'),
      () => client,
    );

    expect(calls, [
      'POST /api/storage/upload',
      'POST /api/obra-fotos',
    ]);
    expect(photo['id'], 88);
  });
}

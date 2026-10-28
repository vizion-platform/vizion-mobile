import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vizion_mobile/core/network/auth_service.dart';
import 'package:vizion_mobile/features/dashboard/domain/obra_progress.dart';

void main() {
  test('fase concluída vale 1 e fase iniciada vale 0,5', () {
    final progress = calculatePhaseProgress([
      {'status': 'FINALIZADA'},
      {'status': 'EM_ANDAMENTO'},
      {'status': 'PLANEJADA'},
      {'status': 'CONCLUIDO'},
    ]);

    expect(progress, 0.625);
  });

  test('iniciar a fase faz o avanço da obra subir', () {
    final antes = calculatePhaseProgress([
      {'status': 'PLANEJADA'},
      {'status': 'PLANEJADA'},
    ]);
    final depois = calculatePhaseProgress([
      {'status': 'EM_ANDAMENTO'},
      {'status': 'PLANEJADA'},
    ]);

    expect(antes, 0);
    expect(depois, 0.25);
  });

  test('foto e início da mesma fase não somam em dobro', () {
    final progress = calculatePhaseProgress(
      [
        {'id_fase': 1, 'status': 'EM_ANDAMENTO'},
        {'id_fase': 2, 'status': 'PLANEJADA'},
      ],
      photos: [
        {'idFase': 1},
      ],
    );

    expect(progress, 0.25);
  });

  test('fase cancelada não avança a obra', () {
    expect(calculatePhaseProgress([{'status': 'CANCELADA'}]), 0);
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

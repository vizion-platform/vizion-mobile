import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizion_mobile/core/network/auth_service.dart';
import 'package:vizion_mobile/features/dashboard/domain/fase_fluxo.dart';

/// Resposta JSON em UTF-8 (sem o charset, o MockClient codifica acentos em latin1).
http.Response _json(String body, int status) =>
    http.Response(body, status, headers: const {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.avatarKey.value = null;
  });

  test('o fluxo das fases vem da API e libera só as ações permitidas', () async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/fasesObra/obra/7/fluxo'));
      return _json(
        jsonEncode([
          {'id_fase': 1, 'status': 'EM_ANDAMENTO', 'acoes_permitidas': ['PAUSAR', 'FINALIZAR'], 'motivo_bloqueio': null},
          {
            'id_fase': 2,
            'status': 'PLANEJADA',
            'acoes_permitidas': ['CANCELAR'],
            'motivo_bloqueio': 'Finalize a fase "Fundação" antes de iniciar "Estrutura".',
          },
        ]),
        200,
      );
    });

    final fluxo = await http.runWithClient(() => AuthService.fetchPhaseFlow(7), () => client);

    expect(fluxo[1]!.permite('FINALIZAR'), isTrue);
    expect(fluxo[1]!.permite('INICIAR'), isFalse);
    expect(fluxo[2]!.permite('INICIAR'), isFalse);
    expect(fluxo[2]!.motivoBloqueio, contains('Fundação'));
  });

  test('a ordem e os rótulos das ações são os mesmos do desktop', () {
    expect(ordemAcoesFase, ['INICIAR', 'RETOMAR', 'PAUSAR', 'FINALIZAR']);
    expect(rotuloAcaoFase('INICIAR'), 'Iniciar');
    expect(rotuloAcaoFase('RETOMAR'), 'Retomar');
    expect(rotuloAcaoFase('PAUSAR'), 'Pausar');
    expect(rotuloAcaoFase('FINALIZAR'), 'Finalizar');
  });

  test('quando a API recusa a transição, o motivo chega ao usuário', () async {
    final client = MockClient((request) async {
      return _json(
        jsonEncode({'message': 'Finalize a fase "Fundação" antes de iniciar "Estrutura".'}),
        400,
      );
    });

    final resultado = await http.runWithClient(() => AuthService.transitionPhase(2, 'INICIAR'), () => client);

    expect(resultado.ok, isFalse);
    expect(resultado.mensagem, contains('Fundação'));
  });

  test('transição aceita pela API volta como sucesso', () async {
    final client = MockClient((request) async => http.Response(jsonEncode({'id_fase': 1}), 200));

    final resultado = await http.runWithClient(() => AuthService.transitionPhase(1, 'INICIAR'), () => client);

    expect(resultado.ok, isTrue);
    expect(resultado.mensagem, isNull);
  });

  test('enviar a foto de perfil guarda a chave e monta a URL do storage', () async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/auth/avatar'));
      expect(request.headers['content-type'], contains('multipart/form-data'));
      return http.Response(jsonEncode({'id': 3, 'avatarKey': 'usuarios/3/avatar/foto.jpg'}), 200);
    });

    final key = await http.runWithClient(() => AuthService.uploadAvatar([1, 2, 3], 'foto.jpg'), () => client);

    expect(key, 'usuarios/3/avatar/foto.jpg');
    expect(AuthService.avatarKey.value, 'usuarios/3/avatar/foto.jpg');
    expect(AuthService.avatarUrl, endsWith('/storage/local/usuarios/3/avatar/foto.jpg'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('avatarKey'), 'usuarios/3/avatar/foto.jpg');
  });

  test('falha no envio da foto de perfil mostra o motivo e não troca o avatar', () async {
    final client = MockClient((request) async => _json(jsonEncode({'message': 'O avatar deve ter no máximo 5 MB'}), 400));

    await expectLater(
      http.runWithClient(() => AuthService.uploadAvatar([1], 'grande.jpg'), () => client),
      throwsA(predicate((e) => e.toString().contains('máximo 5 MB'))),
    );
    expect(AuthService.avatarKey.value, isNull);
  });

  test('foto de perfil recusada pelo proxy por tamanho (413) vira mensagem clara', () async {
    final client = MockClient((request) async => http.Response('<html>413 Request Entity Too Large</html>', 413));

    await expectLater(
      http.runWithClient(() => AuthService.uploadAvatar(List.filled(10, 1), 'grande.jpg'), () => client),
      throwsA(predicate((e) => e.toString().contains('grande demais'))),
    );
    expect(AuthService.avatarKey.value, isNull);
  });
}

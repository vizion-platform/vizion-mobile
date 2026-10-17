import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizion_mobile/core/network/api_client.dart';
import 'package:vizion_mobile/core/network/auth_service.dart';

http.Response _json(int status, Object body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Future<void> _logar(MockClient client) async {
  await http.runWithClient(() async {
    expect(await AuthService.login('a@b.com', 'x'), isTrue);
  }, () => client);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final armazenamentoSeguro = <String, String>{};

  setUp(() async {
    armazenamentoSeguro.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final chave = call.arguments['key'] as String?;
        switch (call.method) {
          case 'write':
            armazenamentoSeguro[chave!] = call.arguments['value'] as String;
            return null;
          case 'read':
            return armazenamentoSeguro[chave];
          case 'delete':
            armazenamentoSeguro.remove(chave);
            return null;
          case 'readAll':
            return Map<String, String>.from(armazenamentoSeguro);
          case 'containsKey':
            return armazenamentoSeguro.containsKey(chave);
          default:
            return null;
        }
      },
    );
    SharedPreferences.setMockInitialValues({});
    AuthService.onSessionExpired = null;
    AuthService.onPasswordChangeRequired = null;
  });

  MockClient servidor(List<String> chamadas, {required bool refreshOk, int refreshStatus = 200}) {
    var token = 'at-1';
    return MockClient((req) async {
      chamadas.add('${req.method} ${req.url.path} ${req.headers['Authorization'] ?? '-'}');
      if (req.url.path.endsWith('/auth/login')) {
        return _json(200, {
          'accessToken': 'at-1',
          'refreshToken': 'rt-1',
          'nome': 'N',
          'role': 'EMPREITEIRO',
          'tenantId': 't',
          'trocaSenhaObrigatoria': false,
        });
      }
      if (req.url.path.endsWith('/auth/me')) return _json(200, {'id': 9});
      if (req.url.path.endsWith('/auth/refresh')) {
        if (!refreshOk) return _json(refreshStatus, {'message': 'Sessão expirada'});
        token = 'at-2';
        return _json(200, {'accessToken': 'at-2', 'refreshToken': 'rt-2'});
      }
      if (req.url.path.endsWith('/auth/logout')) return http.Response('', 204);
      // endpoint protegido: só aceita o token atual
      return req.headers['Authorization'] == 'Bearer $token'
          ? _json(200, {'ok': true})
          : _json(401, {'message': 'expirado'});
    });
  }

  test('renova o token em 401 e repete a requisição', () async {
    final chamadas = <String>[];
    final client = servidor(chamadas, refreshOk: true);
    await _logar(client);
    // invalida o token do servidor para forçar o 401 na primeira tentativa
    final mock = MockClient((req) async {
      chamadas.add('${req.method} ${req.url.path} ${req.headers['Authorization'] ?? '-'}');
      if (req.url.path.endsWith('/auth/refresh')) {
        return _json(200, {'accessToken': 'at-2', 'refreshToken': 'rt-2'});
      }
      return req.headers['Authorization'] == 'Bearer at-2'
          ? _json(200, {'ok': true})
          : _json(401, {'message': 'expirado'});
    });

    final resp = await http.runWithClient(
      () => ApiClient.get(Uri.parse('${AuthService.baseUrl}/obra/minhas-obras'), headers: AuthService.getHeaders()),
      () => mock,
    );

    expect(resp.statusCode, 200);
    expect(AuthService.accessToken, 'at-2');
    expect(chamadas.where((c) => c.contains('/auth/refresh')).length, 1);
    expect(chamadas.last, contains('Bearer at-2'));
  });

  test('requisições simultâneas em 401 compartilham uma única renovação', () async {
    await _logar(servidor([], refreshOk: true));
    var refreshes = 0;
    final mock = MockClient((req) async {
      if (req.url.path.endsWith('/auth/refresh')) {
        refreshes++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return _json(200, {'accessToken': 'at-2', 'refreshToken': 'rt-2'});
      }
      return req.headers['Authorization'] == 'Bearer at-2' ? _json(200, {}) : _json(401, {});
    });

    final respostas = await http.runWithClient(
      () => Future.wait([
        ApiClient.get(Uri.parse('${AuthService.baseUrl}/a'), headers: AuthService.getHeaders()),
        ApiClient.get(Uri.parse('${AuthService.baseUrl}/b'), headers: AuthService.getHeaders()),
        ApiClient.get(Uri.parse('${AuthService.baseUrl}/c'), headers: AuthService.getHeaders()),
      ]),
      () => mock,
    );

    expect(respostas.map((r) => r.statusCode), everyElement(200));
    expect(refreshes, 1);
  });

  test('refresh rejeitado encerra a sessão e avisa o app', () async {
    await _logar(servidor([], refreshOk: true));
    var expirou = false;
    AuthService.onSessionExpired = () async => expirou = true;
    final mock = MockClient((req) async {
      if (req.url.path.endsWith('/auth/refresh')) return _json(401, {});
      return _json(401, {});
    });

    final resp = await http.runWithClient(
      () => ApiClient.get(Uri.parse('${AuthService.baseUrl}/obra'), headers: AuthService.getHeaders()),
      () => mock,
    );

    expect(resp.statusCode, 401);
    expect(expirou, isTrue);
    expect(AuthService.accessToken, isNull);
  });

  test('sem rede para renovar a sessão é mantida', () async {
    await _logar(servidor([], refreshOk: true));
    var expirou = false;
    AuthService.onSessionExpired = () async => expirou = true;
    final mock = MockClient((req) async {
      if (req.url.path.endsWith('/auth/refresh')) throw http.ClientException('sem rede');
      return _json(401, {});
    });

    await http.runWithClient(
      () => ApiClient.get(Uri.parse('${AuthService.baseUrl}/obra'), headers: AuthService.getHeaders()),
      () => mock,
    );

    expect(expirou, isFalse);
    expect(AuthService.accessToken, 'at-1');
  });

  test('403 de senha temporária sinaliza a troca obrigatória', () async {
    await _logar(servidor([], refreshOk: true));
    var sinalizado = false;
    AuthService.onPasswordChangeRequired = () => sinalizado = true;
    final mock = MockClient((req) async => _json(403, {'code': 'PASSWORD_CHANGE_REQUIRED'}));

    await http.runWithClient(
      () => ApiClient.get(Uri.parse('${AuthService.baseUrl}/obra'), headers: AuthService.getHeaders()),
      () => mock,
    );

    expect(sinalizado, isTrue);
    expect(AuthService.mustChangePassword, isTrue);
  });

  test('não envia mais o X-Tenant-ID', () async {
    await _logar(servidor([], refreshOk: true));
    expect(AuthService.getHeaders().containsKey('X-Tenant-ID'), isFalse);
  });

  test('tokens ficam no armazenamento seguro e não em SharedPreferences', () async {
    await _logar(servidor([], refreshOk: true));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('accessToken'), isNull);
    expect(prefs.getString('refreshToken'), isNull);
    expect(armazenamentoSeguro['accessToken'], 'at-1');
    expect(armazenamentoSeguro['refreshToken'], 'rt-1');
  });

  test('migra tokens antigos de SharedPreferences para o armazenamento seguro', () async {
    SharedPreferences.setMockInitialValues({'accessToken': 'velho-a', 'refreshToken': 'velho-r', 'role': 'FUNCIONARIO'});
    expect(await AuthService.init(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('accessToken'), isNull);
    expect(armazenamentoSeguro['accessToken'], 'velho-a');
    expect(AuthService.accessToken, 'velho-a');
  });

  test('logout limpa tokens e caches vizion_*', () async {
    await _logar(servidor([], refreshOk: true));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vizion_agenda_tasks_v2', '[]');
    await http.runWithClient(() => AuthService.signOut(), () => servidor([], refreshOk: true));
    expect(armazenamentoSeguro, isEmpty);
    expect(prefs.getKeys().where((k) => k.startsWith('vizion_')), isEmpty);
    expect(AuthService.accessToken, isNull);
  });
}

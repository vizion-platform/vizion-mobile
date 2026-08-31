import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vizion_mobile/features/chat/data/chat_network_service.dart';

void main() {
  test('chat persiste mensagem via POST e retorna id do servidor', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'id': 99, 'chatId': 7, 'remetenteId': 42, 'conteudo': 'Olá desktop', 'dataCriacao': '2026-08-25T12:00:00Z'}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final response = await http.runWithClient(
      () => ChatNetworkService().sendMessage(7, 'Olá desktop'),
      () => client,
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/chats/7/mensagens');
    expect(jsonDecode(captured.body), 'Olá desktop');
    expect(response['id'], 99);
    expect(response['conteudo'], 'Olá desktop');
  });

  test('chat não cria mensagem local quando a API rejeita o POST', () async {
    final client = MockClient((_) async => http.Response('erro', 500));
    expect(
      () => http.runWithClient(
        () => ChatNetworkService().sendMessage(7, 'não persistir'),
        () => client,
      ),
      throwsException,
    );
  });
}

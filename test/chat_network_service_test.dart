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

  test('chat edita mensagem pela API e retorna o estado persistido', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'id': 99, 'chatId': 7, 'remetenteId': 42, 'conteudo': 'Texto novo', 'editada': true, 'excluida': false}),
        200,
      );
    });

    final response = await http.runWithClient(
      () => ChatNetworkService().editMessage(99, 'Texto novo'),
      () => client,
    );

    expect(captured.method, 'PUT');
    expect(captured.url.path, '/api/chats/mensagens/99');
    expect(response['conteudo'], 'Texto novo');
    expect(response['editada'], isTrue);
  });

  test('chat exclui mensagem e usa a resposta oficial da API', () async {
    final client = MockClient((request) async => http.Response(
      jsonEncode({'id': 99, 'chatId': 7, 'remetenteId': 42, 'conteudo': 'Mensagem apagada', 'editada': false, 'excluida': true}),
      200,
    ));

    final response = await http.runWithClient(
      () => ChatNetworkService().deleteMessage(99),
      () => client,
    );

    expect(response['conteudo'], 'Mensagem apagada');
    expect(response['excluida'], isTrue);
  });
}

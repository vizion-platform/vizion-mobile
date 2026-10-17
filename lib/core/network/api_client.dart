import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Cliente HTTP único do app: injeta o token atual, aplica timeout e, em 401,
/// renova a sessão uma vez e repete a requisição. Se o servidor rejeitar a
/// renovação, a sessão é encerrada e o usuário volta ao login.
class ApiClient {
  static const Duration timeout = Duration(seconds: 20);

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _send((h) => http.get(url, headers: h), headers);

  static Future<http.Response> post(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _send((h) => http.post(url, headers: h, body: body), headers);

  static Future<http.Response> put(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _send((h) => http.put(url, headers: h, body: body), headers);

  static Future<http.Response> patch(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _send((h) => http.patch(url, headers: h, body: body), headers);

  static Future<http.Response> delete(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _send((h) => http.delete(url, headers: h, body: body), headers);

  static Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
    Map<String, String>? headers,
  ) async {
    final comSessao = AuthService.accessToken != null &&
        (headers == null || headers.containsKey('Authorization'));

    Map<String, String> montar() => {
          ...?headers,
          if (comSessao && AuthService.accessToken != null)
            'Authorization': 'Bearer ${AuthService.accessToken}',
        };

    var resposta = await request(montar()).timeout(timeout);

    if (resposta.statusCode == 403 && _exigeTrocaDeSenha(resposta)) {
      AuthService.sinalizarTrocaDeSenhaObrigatoria();
      return resposta;
    }

    if (resposta.statusCode == 401 && comSessao) {
      final resultado = await AuthService.renovarSessao();
      switch (resultado) {
        case RenovacaoSessao.renovada:
          resposta = await request(montar()).timeout(timeout);
        case RenovacaoSessao.rejeitada:
          await AuthService.encerrarSessaoExpirada();
        case RenovacaoSessao.indisponivel:
          break; // sem rede para renovar: mantém a sessão e devolve o 401
      }
    }
    return resposta;
  }

  static bool _exigeTrocaDeSenha(http.Response r) {
    try {
      final corpo = jsonDecode(utf8.decode(r.bodyBytes));
      return corpo is Map && corpo['code'] == 'PASSWORD_CHANGE_REQUIRED';
    } catch (_) {
      return false;
    }
  }
}

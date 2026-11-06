import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/network/api_client.dart';
import '../../../core/network/auth_service.dart';
import 'package:vizion_mobile/core/log.dart';

/// Horário exibido na lista de conversas: hora de hoje, "Ontem" ou dia/mês.
/// [agora] existe para os testes.
String formatarHorarioConversa(String? iso, {DateTime? agora}) {
  if (iso == null || iso.isEmpty) return '';
  final data = DateTime.tryParse(iso);
  if (data == null) return '';
  final hoje = agora ?? DateTime.now();
  String dois(int n) => n.toString().padLeft(2, '0');
  final mesmoDia = data.year == hoje.year && data.month == hoje.month && data.day == hoje.day;
  if (mesmoDia) return '${dois(data.hour)}:${dois(data.minute)}';
  final ontem = DateTime(hoje.year, hoje.month, hoje.day).subtract(const Duration(days: 1));
  if (data.year == ontem.year && data.month == ontem.month && data.day == ontem.day) return 'Ontem';
  return '${dois(data.day)}/${dois(data.month)}';
}

class ChatNetworkService {
  static final ChatNetworkService _instance = ChatNetworkService._internal();
  factory ChatNetworkService() => _instance;
  ChatNetworkService._internal();

  /// Total de mensagens não lidas, mostrado na bolinha vermelha do ícone do Chat.
  static final ValueNotifier<int> unreadTotal = ValueNotifier<int>(0);

  io.Socket? _socket;
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  Function(Map<String, dynamic>)? _onNewMessageCallback;

  String messageFromError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    return raw.isEmpty ? 'Não foi possível concluir a operação.' : raw;
  }

  String _serverMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map) {
        final message = body['message'] ?? body['error'] ?? body['detail'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
      if (body is String && body.trim().isNotEmpty) return body;
    } catch (_) {
      final body = utf8.decode(response.bodyBytes).trim();
      if (body.isNotEmpty) return body;
    }
    return fallback;
  }

  // REST endpoints

  Future<List<Map<String, dynamic>>> fetchChats() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${AuthService.baseUrl}/chats'),
        headers: AuthService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        final chats = list
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        unreadTotal.value = chats.fold<int>(
          0,
          (soma, chat) => soma + ((chat['naoLidas'] as num?)?.toInt() ?? 0),
        );

        return chats;
      } else {
        throw Exception(_serverMessage(response, 'Não foi possível carregar as conversas.'));
      }
    } catch (e) {
      logDebug('Erro ao carregar chats: $e');
      rethrow;
    }
  }

  /// Atualiza o total de mensagens não lidas (todas as conversas).
  Future<void> refreshUnread() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${AuthService.baseUrl}/chats/nao-lidas'),
        headers: AuthService.getHeaders(),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final total = body is Map ? body['total'] : 0;
        unreadTotal.value = total is num ? total.toInt() : 0;
      }
    } catch (e) {
      logDebug('Erro ao carregar mensagens não lidas: $e');
    }
  }

  /// Marca a conversa como lida no servidor e atualiza o total.
  Future<void> markChatRead(int chatId) async {
    try {
      await ApiClient.post(
        Uri.parse('${AuthService.baseUrl}/chats/$chatId/lida'),
        headers: AuthService.getHeaders(),
      );
      await refreshUnread();
    } catch (e) {
      logDebug('Erro ao marcar conversa como lida: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchContacts() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${AuthService.baseUrl}/chats/contatos'),
        headers: AuthService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        throw Exception(_serverMessage(response, 'Não foi possível carregar os contatos.'));
      }
    } catch (e) {
      logDebug('Erro ao carregar contatos: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> startPrivateChat(int contactId) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('${AuthService.baseUrl}/chats/privado/$contactId'),
        headers: AuthService.getHeaders(),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );
      } else {
        throw Exception(_serverMessage(response, 'Não foi possível iniciar a conversa.'));
      }
    } catch (e) {
      logDebug('Erro ao iniciar chat: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMessages(int chatId) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${AuthService.baseUrl}/chats/$chatId/mensagens'),
        headers: AuthService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        throw Exception(_serverMessage(response, 'Não foi possível carregar as mensagens.'));
      }
    } catch (e) {
      logDebug('Erro ao carregar mensagens do chat: $e');
      rethrow;
    }
  }

  final List<Function(bool)> _connectionListeners = [];

  void addConnectionListener(Function(bool) listener) {
    _connectionListeners.add(listener);
    listener(_isConnected);
  }

  void removeConnectionListener(Function(bool) listener) {
    _connectionListeners.remove(listener);
  }

  void _updateConnectionStatus(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      for (final listener in _connectionListeners) {
        try {
          listener(connected);
        } catch (e) {
          logDebug('Erro no listener de conexao: $e');
        }
      }
    }
  }

  /// O servidor (Socket.IO) coloca o usuário na sala dele ao conectar e entrega
  /// `new_message`, `message_edited` e `message_deleted` de todas as conversas dele.
  static const String _socketUrl = 'https://vizion.felipedepaula.com.br';
  static const List<String> _messageEvents = [
    'new_message',
    'message_edited',
    'message_deleted',
  ];

  void connectSocket(Function(Map<String, dynamic>) onNewMessage) {
    _onNewMessageCallback = onNewMessage;
    final token = AuthService.accessToken;
    if (token == null || token.isEmpty) return;
    if (_socket != null) return;

    final socket = io.io(
      _socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setQuery({'token': token})
          .enableReconnection()
          .setReconnectionDelay(3000)
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      logDebug('Conectado ao servidor de chat (socket).');
      _updateConnectionStatus(true);
    });
    socket.onDisconnect((_) {
      logDebug('Desconectado do servidor de chat (socket).');
      _updateConnectionStatus(false);
    });
    socket.onConnectError((error) {
      logDebug('Erro ao conectar no socket: $error');
      _updateConnectionStatus(false);
    });

    for (final event in _messageEvents) {
      socket.on(event, (data) {
        try {
          if (_onNewMessageCallback != null && data is Map) {
            _onNewMessageCallback!(Map<String, dynamic>.from(data));
          }
        } catch (e) {
          logDebug('Erro ao tratar mensagem do socket: $e');
        }
      });
    }

    socket.connect();
  }

  void disconnectSocket() {
    _socket?.dispose();
    _socket = null;
    _updateConnectionStatus(false);
    _onNewMessageCallback = null;
    logDebug('Socket do chat desconectado e limpo.');
  }

  Future<Map<String, dynamic>> postMessage(int chatId, String content) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('${AuthService.baseUrl}/chats/$chatId/mensagens'),
        headers: {
          ...AuthService.getHeaders(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(content),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );
      } else {
        throw Exception(_serverMessage(response, 'Não foi possível enviar a mensagem.'));
      }
    } catch (e) {
      logDebug('Erro ao postar mensagem: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> editMessage(int messageId, String newContent) async {
    try {
      final response = await ApiClient.put(
        Uri.parse('${AuthService.baseUrl}/chats/mensagens/$messageId'),
        headers: {
          ...AuthService.getHeaders(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(newContent),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );
      } else {
        throw Exception(_serverMessage(response, 'Não foi possível editar a mensagem.'));
      }
    } catch (e) {
      logDebug('Erro ao editar mensagem: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteMessage(int messageId) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse('${AuthService.baseUrl}/chats/mensagens/$messageId'),
        headers: AuthService.getHeaders(),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)));
      }
      throw Exception(_serverMessage(response, 'Não foi possível excluir a mensagem.'));
    } catch (e) {
      logDebug('Erro ao excluir mensagem: $e');
      rethrow;
    }
  }

  /// Envia pela API REST (o servidor define o remetente a partir do token, então ninguém
  /// consegue falar em nome de outro usuário) e devolve a mensagem já persistida.
  Future<Map<String, dynamic>> sendMessage(int chatId, String content) {
    return postMessage(chatId, content);
  }
}

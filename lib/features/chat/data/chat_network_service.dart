import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_helper.dart';
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

  MqttClient? _client;
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

        // Auto-subscribe to all active chats in MQTT
        for (var chat in chats) {
          final id = chat['id'];
          if (id is int) {
            subscribeToChat(id);
          }
        }

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

  final Set<int> _subscribedChatIds = {};

  void subscribeToChat(int chatId) {
    _subscribedChatIds.add(chatId);
    _subscribeToTopic(chatId);
  }

  void unsubscribeFromChat(int chatId) {
    _subscribedChatIds.remove(chatId);
    if (_client != null &&
        _client!.connectionStatus!.state == MqttConnectionState.connected) {
      final topic = 'vizion/chats/$chatId';
      _client!.unsubscribe(topic);
    }
  }

  void _subscribeToTopic(int chatId) {
    if (_client != null &&
        _client!.connectionStatus!.state == MqttConnectionState.connected) {
      final topic = 'vizion/chats/$chatId';
      logDebug('Inscrevendo no topico MQTT: $topic');
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  Future<void> _connectMqtt() async {
    if (_client != null &&
        (_client!.connectionStatus!.state == MqttConnectionState.connected ||
            _client!.connectionStatus!.state ==
                MqttConnectionState.connecting)) {
      return;
    }

    final clientId =
        'vizion_mobile_${DateTime.now().millisecondsSinceEpoch}_${AuthService.userId}';
    _client = createMqttClient('rabbit.felipedepauladev.site', clientId, 443);
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 20;
    // Quando a internet cai e volta (ou o app sai do Wi-Fi), reconecta e reinscreve nos chats
    // sozinho; antes o tempo real parava até reabrir a tela.
    _client!.autoReconnect = true;
    _client!.resubscribeOnAutoReconnect = true;
    _client!.onAutoReconnect = () => _updateConnectionStatus(false);
    _client!.onAutoReconnected = () => _updateConnectionStatus(true);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs('${AuthService.userId}', AuthService.accessToken ?? '')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMessage;

    _client!.onConnected = () {
      logDebug('Conectado ao broker MQTT com sucesso!');
      _updateConnectionStatus(true);
      for (final chatId in _subscribedChatIds) {
        _subscribeToTopic(chatId);
      }
    };

    _client!.onDisconnected = () {
      logDebug('Desconectado do broker MQTT.');
      _updateConnectionStatus(false);
    };

    try {
      logDebug('Conectando ao broker MQTT: wss://rabbit.felipedepauladev.site/ws');
      await _client!.connect();
    } catch (e) {
      logDebug('Erro ao conectar ao broker MQTT: $e');
      _updateConnectionStatus(false);
    }

    _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );
      logDebug('Mensagem MQTT recebida no topico ${c[0].topic}');
      try {
        final decoded = jsonDecode(pt);
        final data = decoded is Map && decoded['message'] is Map
            ? decoded['message']
            : decoded;
        if (_onNewMessageCallback != null && data is Map) {
          _onNewMessageCallback!(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        logDebug('Erro ao decodificar mensagem MQTT: $e');
      }
    });
  }

  // Socket Connection wrapper for compatibility

  void connectSocket(Function(Map<String, dynamic>) onNewMessage) {
    _onNewMessageCallback = onNewMessage;
    _connectMqtt();
  }

  void disconnectSocket() {
    if (_client != null) {
      _client!.disconnect();
      _client = null;
    }
    _updateConnectionStatus(false);
    _onNewMessageCallback = null;
    logDebug('MQTT desconectado e limpo.');
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

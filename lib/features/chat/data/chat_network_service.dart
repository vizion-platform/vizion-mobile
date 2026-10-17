import 'dart:convert';
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_helper.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/auth_service.dart';
import 'package:vizion_mobile/core/log.dart';

class ChatNetworkService {
  static final ChatNetworkService _instance = ChatNetworkService._internal();
  factory ChatNetworkService() => _instance;
  ChatNetworkService._internal();

  MqttClient? _client;
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  Function(Map<String, dynamic>)? _onNewMessageCallback;

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

        // Auto-subscribe to all active chats in MQTT
        for (var chat in chats) {
          final id = chat['id'];
          if (id is int) {
            subscribeToChat(id);
          }
        }

        return chats;
      } else {
        throw Exception('Erro ao buscar conversas: ${response.statusCode}');
      }
    } catch (e) {
      logDebug('Erro ao carregar chats: $e');
      rethrow;
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
        throw Exception('Erro ao buscar contatos: ${response.statusCode}');
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
        throw Exception('Erro ao iniciar chat privado: ${response.statusCode}');
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
        throw Exception('Erro ao carregar mensagens: ${response.statusCode}');
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
      final topic = 'chat/$chatId';
      _client!.unsubscribe(topic);
    }
  }

  void _subscribeToTopic(int chatId) {
    if (_client != null &&
        _client!.connectionStatus!.state == MqttConnectionState.connected) {
      final topic = 'chat/$chatId';
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
        final data = jsonDecode(pt);
        if (_onNewMessageCallback != null && data != null) {
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
        throw Exception('Erro ao enviar mensagem via HTTP: ${response.statusCode}');
      }
    } catch (e) {
      logDebug('Erro ao postar mensagem: $e');
      rethrow;
    }
  }

  /// Envia pela API REST (o servidor define o remetente a partir do token, então ninguém
  /// consegue falar em nome de outro usuário) e devolve a mensagem já persistida.
  Future<Map<String, dynamic>> sendMessage(int chatId, String content) {
    return postMessage(chatId, content);
  }
}

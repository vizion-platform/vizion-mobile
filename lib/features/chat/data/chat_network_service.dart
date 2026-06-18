import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../../../core/network/auth_service.dart';

class ChatNetworkService {
  static final ChatNetworkService _instance = ChatNetworkService._internal();
  factory ChatNetworkService() => _instance;
  ChatNetworkService._internal();

  MqttServerClient? _client;
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  Function(Map<String, dynamic>)? _onNewMessageCallback;

  // REST endpoints

  Future<List<Map<String, dynamic>>> fetchChats() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/chats'),
        headers: AuthService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        final chats = list.map((item) => Map<String, dynamic>.from(item)).toList();
        
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
      print('Erro ao carregar chats: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchContacts() async {
    try {
      final response = await http.get(
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
      print('Erro ao carregar contatos: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> startPrivateChat(int contactId) async {
    try {
      final response = await http.post(
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
      print('Erro ao iniciar chat: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMessages(int chatId) async {
    try {
      final response = await http.get(
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
      print('Erro ao carregar mensagens do chat: $e');
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
          print('Erro no listener de conexao: $e');
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
    if (_client != null && _client!.connectionStatus!.state == MqttConnectionState.connected) {
      final topic = 'chat/$chatId';
      _client!.unsubscribe(topic);
    }
  }

  void _subscribeToTopic(int chatId) {
    if (_client != null && _client!.connectionStatus!.state == MqttConnectionState.connected) {
      final topic = 'chat/$chatId';
      print('Inscrevendo no topico MQTT: $topic');
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  Future<void> _connectMqtt() async {
    if (_client != null &&
        (_client!.connectionStatus!.state == MqttConnectionState.connected ||
            _client!.connectionStatus!.state == MqttConnectionState.connecting)) {
      return;
    }

    final clientId = 'vizion_mobile_${DateTime.now().millisecondsSinceEpoch}_${AuthService.userId}';
    _client = MqttServerClient(
      'wss://rabbit.felipedepauladev.site/ws',
      clientId,
    );
    _client!.port = 443;
    _client!.useWebSocket = true;
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 20;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs('felipe', 'FseHs3Wh;Ju+8N-')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMessage;

    _client!.onConnected = () {
      print('Conectado ao broker MQTT com sucesso!');
      _updateConnectionStatus(true);
      for (final chatId in _subscribedChatIds) {
        _subscribeToTopic(chatId);
      }
    };

    _client!.onDisconnected = () {
      print('Desconectado do broker MQTT.');
      _updateConnectionStatus(false);
    };

    try {
      print('Conectando ao broker MQTT: wss://rabbit.felipedepauladev.site/ws');
      await _client!.connect();
    } catch (e) {
      print('Erro ao conectar ao broker MQTT: $e');
      _updateConnectionStatus(false);
    }

    _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print('Mensagem MQTT recebida no topico ${c[0].topic}: $pt');
      try {
        final data = jsonDecode(pt);
        if (_onNewMessageCallback != null && data != null) {
          _onNewMessageCallback!(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        print('Erro ao decodificar mensagem MQTT: $e');
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
    print('MQTT desconectado e limpo.');
  }

  void sendMessage(int chatId, String content) {
    if (_client == null || _client!.connectionStatus!.state != MqttConnectionState.connected) {
      print(
        'Aviso: Emitindo mensagem com MQTT offline. Tentando reconectar...',
      );
      _connectMqtt();
    }

    try {
      final currentUserId = AuthService.userId;
      final payload = {
        'id': 'client_${DateTime.now().millisecondsSinceEpoch}_${chatId}',
        'chatId': chatId,
        'remetenteId': currentUserId,
        'conteudo': content,
        'dataCriacao': DateTime.now().toUtc().toIso8601String(),
      };

      final String topic = 'chat/$chatId';
      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(payload));

      _client?.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      print('Mensagem enviada via MQTT para o chat $chatId: $content');
    } catch (e) {
      print('Erro ao enviar mensagem via MQTT: $e');
    }
  }
}

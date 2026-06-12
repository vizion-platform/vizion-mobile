import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../core/network/auth_service.dart';

class ChatNetworkService {
  static final ChatNetworkService _instance = ChatNetworkService._internal();
  factory ChatNetworkService() => _instance;
  ChatNetworkService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  Function(Map<String, dynamic>)? _onNewMessageCallback;

  bool get isConnected => _isConnected;

  // REST endpoints

  Future<List<Map<String, dynamic>>> fetchChats() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/chats'),
        headers: AuthService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
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
        return Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)));
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

  // Socket Connection

  void connectSocket(Function(Map<String, dynamic>) onNewMessage) {
    final token = AuthService.accessToken;
    if (token == null) {
      print('Não foi possível conectar ao socket: Token de acesso nulo');
      return;
    }

    _onNewMessageCallback = onNewMessage;

    if (_socket != null && _socket!.connected) {
      return;
    }

    try {
      final apiUri = Uri.parse(AuthService.baseUrl);
      // Construct the socket URL using the same host, port 9092
      // e.g., if API is https://vizion.cognisgroup.cloud/api, socket is wss://vizion.cognisgroup.cloud:9092 or http
      // Let's use the ws/wss protocol depending on whether the API is secure.
      final isSecure = apiUri.scheme == 'https';
      final socketUrl = '${isSecure ? 'https' : 'http'}://${apiUri.host}:9092';

      print('Conectando ao Socket.io em: $socketUrl');

      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setQuery({'token': token})
            .enableAutoConnect()
            .enableReconnection()
            .build(),
      );

      _socket!.onConnect((_) {
        print('Conectado ao socket do chat com sucesso!');
        _isConnected = true;
      });

      _socket!.onDisconnect((_) {
        print('Desconectado do socket do chat.');
        _isConnected = false;
      });

      _socket!.onConnectError((err) {
        print('Erro de conexão do socket: $err');
        _isConnected = false;
      });

      _socket!.on('new_message', (data) {
        print('Nova mensagem recebida no socket: $data');
        if (_onNewMessageCallback != null && data != null) {
          if (data is Map) {
            _onNewMessageCallback!(Map<String, dynamic>.from(data));
          }
        }
      });

      _socket!.connect();
    } catch (e) {
      print('Erro ao inicializar conexão de socket: $e');
    }
  }

  void disconnectSocket() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
    _onNewMessageCallback = null;
    print('Socket desconectado e limpo.');
  }

  void sendMessage(int chatId, String content) {
    if (_socket == null || !_socket!.connected) {
      print('Aviso: Emitindo mensagem com socket offline. Tentando reconectar...');
      // Re-connect if disconnected
      connectSocket(_onNewMessageCallback ?? (_) {});
    }

    try {
      _socket?.emit('send_message', {
        'message': content,
        'chatId': chatId,
      });
      print('Mensagem enviada via socket para o chat $chatId: $content');
    } catch (e) {
      print('Erro ao enviar mensagem via socket: $e');
    }
  }
}

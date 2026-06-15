import 'dart:convert';
import 'dart:async';
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

  bool get _isMock => AuthService.accessToken?.startsWith('mock-token-') ?? false;

  // Local simulation databases for offline/simulation mode
  static final List<Map<String, dynamic>> _mockContacts = [
    {
      'id': 1001,
      'nome': 'Eng. Felipe (Empreiteiro)',
      'email': 'empreiteiro@vizion.com',
      'role': 'EMPREITEIRO'
    },
    {
      'id': 1002,
      'nome': 'Dr. Marcos (Cliente)',
      'email': 'cliente@vizion.com',
      'role': 'CLIENTE'
    },
    {
      'id': 1003,
      'nome': 'Carlos Silva (Funcionário)',
      'email': 'funcionario@vizion.com',
      'role': 'FUNCIONARIO'
    }
  ];

  static final List<Map<String, dynamic>> _mockChats = [
    {
      'id': 801,
      'chatType': 'PRIVADO',
      'tituloChat': 'Dr. Marcos (Cliente)',
      'nomeOutroParticipante': 'Dr. Marcos (Cliente)',
      'emailOutroParticipante': 'cliente@vizion.com',
      'idOutroParticipante': 1002,
    },
    {
      'id': 802,
      'chatType': 'PRIVADO',
      'tituloChat': 'Carlos Silva (Funcionário)',
      'nomeOutroParticipante': 'Carlos Silva (Funcionário)',
      'emailOutroParticipante': 'funcionario@vizion.com',
      'idOutroParticipante': 1003,
    }
  ];

  static final Map<int, List<Map<String, dynamic>>> _mockMessages = {
    801: [
      {
        'id': 1,
        'chatId': 801,
        'remetenteId': 1002,
        'conteudo': 'Olá Felipe! Como está o andamento da fundação da Bella Vista?',
        'dataCriacao': '2026-06-15T09:00:00Z',
      },
      {
        'id': 2,
        'chatId': 801,
        'remetenteId': 1001,
        'conteudo': 'Bom dia Marcos! Já finalizamos a concretagem e estamos iniciando a impermeabilização.',
        'dataCriacao': '2026-06-15T09:05:00Z',
      }
    ],
    802: [
      {
        'id': 1,
        'chatId': 802,
        'remetenteId': 1003,
        'conteudo': 'Felipe, terminamos o reboco da parede oeste. Vou precisar de mais cimento amanhã.',
        'dataCriacao': '2026-06-15T08:30:00Z',
      },
      {
        'id': 2,
        'chatId': 802,
        'remetenteId': 1001,
        'conteudo': 'Perfeito Carlos. O cimento novo já foi faturado e deve chegar logo cedo.',
        'dataCriacao': '2026-06-15T08:35:00Z',
      }
    ]
  };

  Map<String, dynamic> _enrichMockChat(Map<String, dynamic> chat) {
    final chatId = chat['id'] as int;
    final msgs = _mockMessages[chatId] ?? [];
    if (msgs.isNotEmpty) {
      final lastMsg = msgs.last;
      return {
        ...chat,
        'ultimaMensagem': lastMsg['conteudo'],
        'ultimaMensagemData': lastMsg['dataCriacao'],
      };
    }
    return chat;
  }

  // REST endpoints

  Future<List<Map<String, dynamic>>> fetchChats() async {
    if (_isMock) {
      final currentUserId = AuthService.userId ?? 1001;
      final list = <Map<String, dynamic>>[];
      for (var chat in _mockChats) {
        final chatId = chat['id'];
        
        if (currentUserId == 1001) {
          list.add(_enrichMockChat(chat));
        } else if (currentUserId == 1002 && chatId == 801) {
          list.add(_enrichMockChat({
            ...chat,
            'tituloChat': 'Eng. Felipe (Empreiteiro)',
            'nomeOutroParticipante': 'Eng. Felipe (Empreiteiro)',
            'emailOutroParticipante': 'empreiteiro@vizion.com',
            'idOutroParticipante': 1001,
          }));
        } else if (currentUserId == 1003 && chatId == 802) {
          list.add(_enrichMockChat({
            ...chat,
            'tituloChat': 'Eng. Felipe (Empreiteiro)',
            'nomeOutroParticipante': 'Eng. Felipe (Empreiteiro)',
            'emailOutroParticipante': 'empreiteiro@vizion.com',
            'idOutroParticipante': 1001,
          }));
        }
      }
      return list;
    }

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
    if (_isMock) {
      final currentUserId = AuthService.userId ?? 1001;
      // Return contacts other than the logged-in user
      return _mockContacts.where((c) => c['id'] != currentUserId).toList();
    }

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
    if (_isMock) {
      final currentUserId = AuthService.userId ?? 1001;
      // Search if a chat between currentUserId and contactId already exists
      for (var chat in _mockChats) {
        final idOutro = chat['idOutroParticipante'];
        if ((currentUserId == 1001 && idOutro == contactId) ||
            (currentUserId == contactId && idOutro == 1001)) {
          return chat;
        }
      }
      
      // If it doesn't exist, create a new mock chat
      final newChatId = 800 + _mockChats.length + 1;
      final contact = _mockContacts.firstWhere((c) => c['id'] == contactId, orElse: () => {'nome': 'Contato', 'email': 'user@vizion.com'});
      final newChat = {
        'id': newChatId,
        'chatType': 'PRIVADO',
        'tituloChat': contact['nome'],
        'nomeOutroParticipante': contact['nome'],
        'emailOutroParticipante': contact['email'],
        'idOutroParticipante': contactId,
      };
      
      _mockChats.add(newChat);
      _mockMessages[newChatId] = [];
      return newChat;
    }

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
    if (_isMock) {
      return _mockMessages[chatId] ?? [];
    }

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
    _onNewMessageCallback = onNewMessage;

    if (_isMock) {
      print('Chat em modo Simulação: conexões socket mockadas.');
      _isConnected = true;
      return;
    }

    final token = AuthService.accessToken;
    if (token == null) {
      print('Não foi possível conectar ao socket: Token de acesso nulo');
      return;
    }

    if (_socket != null && _socket!.connected) {
      return;
    }

    try {
      final apiUri = Uri.parse(AuthService.baseUrl);
      final isSecure = apiUri.scheme == 'https';
      
      // If secure (production), route socket.io through HTTPS port 443 so reverse proxy (e.g. Nginx) can forward it.
      // If insecure (local dev), connect directly to host port 9092.
      final socketUrl = isSecure ? 'https://${apiUri.host}' : 'http://${apiUri.host}:9092';

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
    if (_isMock) {
      _isConnected = false;
      _onNewMessageCallback = null;
      print('Socket de simulação desconectado.');
      return;
    }

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
    if (_isMock) {
      final currentUserId = AuthService.userId ?? 1001;
      
      // 1. Add user's message to local memory
      final userMessage = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'chatId': chatId,
        'remetenteId': currentUserId,
        'conteudo': content,
        'dataCriacao': DateTime.now().toUtc().toIso8601String(),
      };
      
      _mockMessages.putIfAbsent(chatId, () => []).add(userMessage);
      
      // 2. Trigger instant local refresh callback
      if (_onNewMessageCallback != null) {
        _onNewMessageCallback!(userMessage);
      }
      
      // 3. Find recipient properties to choose automated replies
      final otherId = currentUserId == 1001 
          ? (chatId == 801 ? 1002 : 1003) 
          : 1001;
      
      // Choose replies based on keywords or context
      String replyText = 'Entendido! Entrarei em contato para tratar disso.';
      final normContent = content.toLowerCase();
      
      if (otherId == 1001) { // Felipe (Empreiteiro) responding
        if (normContent.contains('cimento') || normContent.contains('material')) {
          replyText = 'Já realizei o pedido de insumos adicionais com a fornecedora. Chega no canteiro amanhã cedo.';
        } else if (normContent.contains('foto') || normContent.contains('galeria')) {
          replyText = 'Claro! Vou subir as novas fotos de progresso diretamente no timeline da obra.';
        } else if (normContent.contains('atraso') || normContent.contains('cronograma')) {
          replyText = 'Estamos redobrando os esforços e realocando a equipe para compensar qualquer variação no prazo.';
        } else if (normContent.contains('olá') || normContent.contains('oi') || normContent.contains('bom dia')) {
          replyText = 'Olá! Tudo bem? Como posso te ajudar com a obra hoje?';
        } else {
          replyText = 'Perfeito, recebido. Vou analisar as informações no canteiro e te dou um retorno em seguida.';
        }
      } else if (otherId == 1002) { // Marcos (Cliente) responding
        if (normContent.contains('fase') || normContent.contains('concluid') || normContent.contains('term')) {
          replyText = 'Excelente notícia! O progresso está ficando fantástico. Agradeço pelo empenho de toda a equipe.';
        } else if (normContent.contains('foto') || normContent.contains('imagens')) {
          replyText = 'Muito bom ver as atualizações visuais. Isso nos dá muita segurança sobre a execução.';
        } else if (normContent.contains('olá') || normContent.contains('oi')) {
          replyText = 'Olá Felipe! Obrigado pelo contato. Alguma atualização sobre a Bella Vista hoje?';
        } else {
          replyText = 'Entendido, Felipe. Obrigado pelo retorno rápido. Vou acompanhar por aqui.';
        }
      } else if (otherId == 1003) { // Carlos (Funcionário) responding
        if (normContent.contains('cimento') || normContent.contains('entrega')) {
          replyText = 'Perfeito chefe. Assim que descarregarem, eu confiro e te mando a confirmação.';
        } else if (normContent.contains('olá') || normContent.contains('oi')) {
          replyText = 'Fala Felipe! Concluímos as tarefas da tarde e já organizamos as ferramentas.';
        } else {
          replyText = 'Combinado, chefe! Vou repassar a instrução para o resto da equipe aqui no canteiro.';
        }
      }
      
      // 4. Simulate a delayed premium automatic response
      Timer(const Duration(milliseconds: 1200), () {
        final replyMessage = {
          'id': DateTime.now().millisecondsSinceEpoch + 1,
          'chatId': chatId,
          'remetenteId': otherId,
          'conteudo': replyText,
          'dataCriacao': DateTime.now().toUtc().toIso8601String(),
        };
        
        _mockMessages[chatId]?.add(replyMessage);
        
        if (_onNewMessageCallback != null) {
          _onNewMessageCallback!(replyMessage);
        }
      });
      return;
    }

    if (_socket == null || !_socket!.connected) {
      print('Aviso: Emitindo mensagem com socket offline. Tentando reconectar...');
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

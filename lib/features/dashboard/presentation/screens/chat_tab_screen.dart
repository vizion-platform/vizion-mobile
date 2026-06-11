import 'package:flutter/material.dart';
import '../controllers/user_controller.dart';
import '../../../../core/theme/app_theme.dart';

class ChatMessage {
  final String senderName;
  final String senderRole;
  final String content;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.timestamp,
    required this.isMe,
  });
}

class ChatTabScreen extends StatefulWidget {
  const ChatTabScreen({super.key});

  @override
  State<ChatTabScreen> createState() => _ChatTabScreenState();
}

class _ChatTabScreenState extends State<ChatTabScreen> {
  final List<ChatMessage> _messages = [
    ChatMessage(
      senderName: "Carlos Cliente",
      senderRole: "Cliente",
      content: "Olá pessoal! Como está o andamento da concretagem da laje?",
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      isMe: false,
    ),
    ChatMessage(
      senderName: "Marcos Empreiteiro",
      senderRole: "Empreiteiro",
      content: "Olá Carlos! A fundação e alvenaria estão prontas. O Fábio já está finalizando a marcação das fases hidráulicas.",
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isMe: false,
    ),
    ChatMessage(
      senderName: "Fabio Funcionário",
      senderRole: "Funcionário",
      content: "Instalações de tubulações concluídas! Acabei de marcar como concluída a fase de Instalações no app.",
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      isMe: false,
    ),
  ];

  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    final currentUser = UserController.instance.usuarioLogado.value;
    if (currentUser == null) return;

    setState(() {
      _messages.add(
        ChatMessage(
          senderName: currentUser.nome,
          senderRole: currentUser.role,
          content: text,
          timestamp: DateTime.now(),
          isMe: true,
        ),
      );
    });

    _messageCtrl.clear();
    
    // Auto scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Resposta automática simulada após 2 segundos
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      String responseText = "";
      String responderName = "";
      String responderRole = "";

      if (currentUser.role == "Cliente") {
        responderName = "Marcos Empreiteiro";
        responderRole = "Empreiteiro";
        responseText = "Entendido, Carlos! Já adicionei novas fotos no painel da obra para você conferir.";
      } else if (currentUser.role == "Empreiteiro") {
        responderName = "Carlos Cliente";
        responderRole = "Cliente";
        responseText = "Excelente atualização, Marcos! Obrigado por manter o controle atualizado.";
      } else {
        responderName = "Marcos Empreiteiro";
        responderRole = "Empreiteiro";
        responseText = "Bom trabalho, Fábio! Vou revisar a instalação hoje à tarde.";
      }

      setState(() {
        _messages.add(
          ChatMessage(
            senderName: responderName,
            senderRole: responderRole,
            content: responseText,
            timestamp: DateTime.now(),
            isMe: false,
          ),
        );
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = UserController.instance.usuarioLogado.value;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Column(
        children: [
          // Header do Chat Geral
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF141414),
              border: Border(bottom: BorderSide(color: Color(0xFF222222))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: const Icon(Icons.forum_outlined, color: Color(0xFFD4AF37), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Canal Geral da Obra",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Interações entre Cliente, Empreiteiro e Funcionários",
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista de Mensagens
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(24),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                
                // Determina as cores de acordo com o papel
                Color roleColor;
                switch (msg.senderRole) {
                  case 'Empreiteiro':
                    roleColor = const Color(0xFFD4AF37); // Gold
                    break;
                  case 'Funcionário':
                    roleColor = Colors.blueAccent;
                    break;
                  case 'Cliente':
                  default:
                    roleColor = Colors.greenAccent;
                    break;
                }

                return Align(
                  alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: msg.isMe ? const Color(0xFF1A1A1A) : const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: msg.isMe 
                            ? const Color(0xFFD4AF37).withOpacity(0.3) 
                            : const Color(0xFF222222),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg.senderName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(color: roleColor.withOpacity(0.3), width: 0.5),
                              ),
                              child: Text(
                                msg.senderRole.toUpperCase(),
                                style: TextStyle(color: roleColor, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          msg.content,
                          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Input de Mensagem
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF141414),
              border: Border(top: BorderSide(color: Color(0xFF222222))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Digite sua mensagem como ${currentUser?.nome ?? 'Usuário'}...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF0A0A0A),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF222222)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.send, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

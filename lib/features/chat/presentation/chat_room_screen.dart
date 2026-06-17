import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_service.dart';
import '../data/chat_network_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final int chatId;
  final String chatTitle;
  final String otherParticipantName;
  final String? otherParticipantRole;

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.otherParticipantName,
    this.otherParticipantRole,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ChatNetworkService _chatService = ChatNetworkService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupSocketListener();
  }

  @override
  void dispose() {
    // We don't disconnect the entire socket because we might still want to
    // listen in ChatListScreen, but we remove the callback for this room.
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _chatService.fetchMessages(widget.chatId);
      if (mounted) {
        setState(() {
          _messages = data;
          _isLoading = false;
          _errorMessage = '';
        });
        _scrollToBottom(delayed: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao carregar mensagens.';
        });
      }
    }
  }

  void _setupSocketListener() {
    // Connect socket and listen for new messages
    _chatService.connectSocket((newMessage) {
      if (mounted) {
        final incomingChatId = newMessage['chatId'];
        if (incomingChatId == widget.chatId) {
          setState(() {
            // Check if message is already added (to avoid duplicates from websocket broadcasts)
            final exists = _messages.any((m) => m['id'] == newMessage['id']);
            if (!exists) {
              _messages.add(newMessage);
            }
          });
          _scrollToBottom();
        }
      }
    });
  }

  void _scrollToBottom({bool delayed = false}) {
    if (delayed) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _chatService.sendMessage(widget.chatId, text);
    _messageController.clear();
    
    // Smooth scrolling to bottom after sending
    _scrollToBottom();
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(dateStr).toLocal();
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (e) {
      return '';
    }
  }

  Color _getRoleColor(String? role) {
    switch (role?.toUpperCase()) {
      case 'ADMIN':
        return Colors.redAccent;
      case 'EMPREITEIRO':
      case 'EMPREITEIRA':
        return AppColors.primaryGold;
      case 'CLIENTE':
        return Colors.blueAccent;
      case 'FUNCIONARIO':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherInitial = widget.otherParticipantName.isNotEmpty
        ? widget.otherParticipantName[0].toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        leadingWidth: 70,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(30),
          child: Row(
            children: [
              const SizedBox(width: 4),
              const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              const SizedBox(width: 4),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryGold.withOpacity(0.12),
                child: Text(
                  otherInitial,
                  style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherParticipantName,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            if (widget.otherParticipantRole != null)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  widget.otherParticipantRole!.toUpperCase(),
                  style: TextStyle(
                    color: _getRoleColor(widget.otherParticipantRole),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(_errorMessage, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _loadMessages();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
              child: const Text('Tentar Novamente', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, color: AppColors.textSecondary.withOpacity(0.3), size: 60),
            const SizedBox(height: 16),
            Text(
              'Nenhuma mensagem ainda.\nEnvie um "Olá" para iniciar a conversa!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 14),
            ),
          ],
        ),
      );
    }

    final currentUserId = AuthService.userId;

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final remetenteId = message['remetenteId'];
        final isMe = remetenteId == currentUserId;
        final String content = message['conteudo'] ?? '';
        final String time = _formatTime(message['dataCriacao']);

        return _buildMessageBubble(content, time, isMe);
      },
    );
  }

  Widget _buildMessageBubble(String content, String time, bool isMe) {
    final bubbleColor = isMe 
        ? const Color(0xFF2C261B) // Elegant dark Gold/Bronze for current user
        : AppColors.surface;       // Dark grey for other
    
    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    
    final borderRadius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.zero,
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.zero,
            bottomRight: Radius.circular(16),
          );

    final border = isMe
        ? Border.all(color: AppColors.primaryGold.withOpacity(0.2), width: 1)
        : Border.all(color: AppColors.gridLine, width: 1);

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
          border: border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              content,
              style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.3),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(color: AppColors.textSecondary.withOpacity(0.8), fontSize: 10),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all, color: AppColors.primaryGold, size: 12),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.gridLine, width: 1.5)),
      ),
      padding: EdgeInsets.only(
        left: 12.0,
        right: 12.0,
        top: 10.0,
        bottom: MediaQuery.of(context).padding.bottom + 10.0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.gridLine, width: 1.5),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Mensagem...',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryGold,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black, size: 18),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

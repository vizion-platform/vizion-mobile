import 'dart:async';
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
  bool _isSocketConnected = false;
  bool _isSending = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _isSocketConnected = _chatService.isConnected;
    _chatService.addConnectionListener(_onConnectionStatusChanged);
    _loadMessages();
    _setupSocketListener();
  }

  @override
  void dispose() {
    _chatService.removeConnectionListener(_onConnectionStatusChanged);
    _chatService.unsubscribeFromChat(widget.chatId);
    _stopFallbackTimer();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onConnectionStatusChanged(bool connected) {
    if (mounted) {
      setState(() {
        _isSocketConnected = connected;
      });
      _startFallbackTimer();
    }
  }

  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    final interval = _isSocketConnected
        ? const Duration(seconds: 15)
        : const Duration(seconds: 3);
    print('Iniciando sincronização HTTP de segurança a cada ${interval.inSeconds}s...');
    _fallbackTimer = Timer.periodic(interval, (timer) {
      _pollMessages();
    });
  }

  void _stopFallbackTimer() {
    if (_fallbackTimer != null) {
      print('Parando fallback de polling periodico HTTP.');
      _fallbackTimer!.cancel();
      _fallbackTimer = null;
    }
  }

  Future<void> _pollMessages() async {
    if (mounted) {
      try {
        final data = await _chatService.fetchMessages(widget.chatId);
        if (mounted) {
          if (!_sameMessages(data, _messages)) {
            setState(() {
              _messages = data;
            });
            _scrollToBottom();
          }
        }
      } catch (e) {
        print('Erro no fallback polling: $e');
      }
    }
  }

  bool _sameMessages(
    List<Map<String, dynamic>> incoming,
    List<Map<String, dynamic>> current,
  ) {
    if (incoming.length != current.length) return false;
    for (var index = 0; index < incoming.length; index++) {
      final left = incoming[index];
      final right = current[index];
      if (left['id'] != right['id'] ||
          left['conteudo'] != right['conteudo'] ||
          left['editada'] != right['editada'] ||
          left['excluida'] != right['excluida'] ||
          left['dataCriacao'] != right['dataCriacao']) {
        return false;
      }
    }
    return true;
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
            final index = _messages.indexWhere((m) => m['id'] == newMessage['id']);
            if (index >= 0) {
              _messages[index] = newMessage;
            } else {
              _messages.add(newMessage);
            }
          });
          _scrollToBottom();
        }
      }
    });
    _chatService.subscribeToChat(widget.chatId);
    _startFallbackTimer();
  }

  void _scrollToBottom({bool delayed = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      final persisted = await _chatService.sendMessage(widget.chatId, text);
      if (!mounted) return;
      setState(() {
        if (!_messages.any((m) => m['id'] == persisted['id'])) {
          _messages.add(persisted);
        }
        _messageController.clear();
        _errorMessage = '';
      });
      _scrollToBottom();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _chatService.messageFromError(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
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
                backgroundColor: AppColors.primaryGold.withValues(alpha: 0.12),
                child: Text(
                  otherInitial,
                  style: const TextStyle(
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
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
        actions: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSocketConnected
                      ? Colors.greenAccent
                      : Colors.amberAccent,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_isSocketConnected
                                  ? Colors.greenAccent
                                  : Colors.amberAccent)
                              .withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isSocketConnected ? 'Online' : 'Reconectando tempo real',
                style: TextStyle(
                  color: _isSocketConnected
                      ? Colors.greenAccent
                      : Colors.amberAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
              ),
              child: const Text(
                'Tentar Novamente',
                style: TextStyle(color: Colors.black),
              ),
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
            Icon(
              Icons.chat_bubble_outline,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma mensagem ainda.\nEnvie um "Olá" para iniciar a conversa!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final currentUserId = AuthService.userId;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];
        final remetenteId = message['remetenteId'];
        final isMe = remetenteId == currentUserId;
        final String content = message['conteudo'] ?? '';
        final String time = _formatTime(message['dataCriacao']);

        return _buildMessageBubble(message, content, time, isMe);
      },
    );
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.primaryGold),
              title: const Text('Editar Mensagem', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showEditDialog(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Excluir Mensagem', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirm(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> message) async {
    final editController = TextEditingController(text: message['conteudo'] ?? '');
    var saving = false;
    String? dialogError;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => PopScope(
          canPop: !saving,
          child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Editar mensagem', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: editController,
                enabled: !saving,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Digite o novo texto...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryGold)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryGold, width: 2)),
                ),
                autofocus: true,
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 10),
                Text(dialogError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
              onPressed: saving ? null : () async {
                final newText = editController.text.trim();
                if (newText.isEmpty) {
                  setDialogState(() => dialogError = 'A mensagem não pode ficar vazia.');
                  return;
                }
                setDialogState(() {
                  saving = true;
                  dialogError = null;
                });
                try {
                  final updated = await _chatService.editMessage(message['id'], newText);
                  if (!mounted) return;
                  setState(() {
                    final idx = _messages.indexWhere((m) => m['id'] == message['id']);
                    if (idx != -1) _messages[idx] = updated;
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (error) {
                  if (ctx.mounted) {
                    setDialogState(() {
                      saving = false;
                      dialogError = _chatService.messageFromError(error);
                    });
                  }
                }
              },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Salvar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
          ),
        ),
      ),
    );
    editController.dispose();
  }

  Future<void> _showDeleteConfirm(Map<String, dynamic> message) async {
    var deleting = false;
    String? dialogError;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => PopScope(
          canPop: !deleting,
          child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Excluir mensagem', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A mensagem será substituída por “Mensagem apagada” para todos os participantes.', style: TextStyle(color: AppColors.textSecondary)),
              if (dialogError != null) ...[
                const SizedBox(height: 10),
                Text(dialogError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: deleting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: deleting ? null : () async {
                setDialogState(() {
                  deleting = true;
                  dialogError = null;
                });
                try {
                  final deleted = await _chatService.deleteMessage(message['id']);
                  if (!mounted) return;
                  setState(() {
                    final idx = _messages.indexWhere((m) => m['id'] == message['id']);
                    if (idx != -1) _messages[idx] = deleted;
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (error) {
                  if (ctx.mounted) {
                    setDialogState(() {
                      deleting = false;
                      dialogError = _chatService.messageFromError(error);
                    });
                  }
                }
              },
              child: deleting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Excluir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, String content, String time, bool isMe) {
    final bubbleColor = isMe
        ? const Color(0xFF2C261B) // Elegant dark Gold/Bronze for current user
        : AppColors.surface; // Dark grey for other

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
        ? Border.all(
            color: AppColors.primaryGold.withValues(alpha: 0.2),
            width: 1,
          )
        : Border.all(color: AppColors.gridLine, width: 1);

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onLongPress: isMe && content != 'Mensagem apagada' ? () => _showMessageOptions(message) : null,
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
                style: TextStyle(
                  color: content == 'Mensagem apagada' ? AppColors.textSecondary : Colors.white,
                  fontStyle: content == 'Mensagem apagada' ? FontStyle.italic : FontStyle.normal,
                  fontSize: 14.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      fontSize: 10,
                    ),
                  ),
                  if (message['editada'] == true && content != 'Mensagem apagada') ...[
                    const SizedBox(width: 4),
                    Text(
                      'editada',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (isMe && content != 'Mensagem apagada') ...[
                    const SizedBox(width: 2),
                    SizedBox(
                      width: 28,
                      height: 24,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        tooltip: 'Ações da mensagem',
                        color: AppColors.surface,
                        icon: const Icon(Icons.more_horiz, color: Colors.black87),
                        onSelected: (value) {
                          if (value == 'edit') _showEditDialog(message);
                          if (value == 'delete') _showDeleteConfirm(message);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit_outlined, color: AppColors.primaryGold, size: 18),
                              SizedBox(width: 10),
                              Text('Editar', style: TextStyle(color: Colors.white)),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              SizedBox(width: 10),
                              Text('Excluir', style: TextStyle(color: Colors.redAccent)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.done_all,
                      color: AppColors.primaryGold,
                      size: 12,
                    ),
                  ],
                ],
              ),
            ],
          ),
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
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Mensagem...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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

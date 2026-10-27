import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/chat_network_service.dart';
import 'contacts_list_screen.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  final VoidCallback? onBackTap;

  const ChatListScreen({super.key, this.onBackTap});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatNetworkService _chatService = ChatNetworkService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _filteredChats = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadChats();
    _setupGlobalSocket();
    _searchController.addListener(_filterChats);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _chatService.disconnectSocket();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      final data = await _chatService.fetchChats();
      if (mounted) {
        setState(() {
          _chats = data;
          _filteredChats = data;
          _isLoading = false;
          _errorMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao carregar conversas.';
        });
      }
    }
  }

  void _setupGlobalSocket() {
    // When in list view, if we get a new message, we just reload the chats list to reflect updates
    _chatService.connectSocket((newMessage) {
      if (mounted) {
        _loadChats();
      }
    });
  }

  void _filterChats() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredChats = _chats;
      } else {
        _filteredChats = _chats.where((c) {
          final title = (c['tituloChat'] ?? '').toString().toLowerCase();
          final otherName = (c['nomeOutroParticipante'] ?? '')
              .toString()
              .toLowerCase();
          final otherEmail = (c['emailOutroParticipante'] ?? '')
              .toString()
              .toLowerCase();
          return title.contains(query) ||
              otherName.contains(query) ||
              otherEmail.contains(query);
        }).toList();
      }
    });
  }

  void _navigateToContacts() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ContactsListScreen()),
    );

    if (result == true) {
      _loadChats();
    }
  }

  void _openChatRoom(Map<String, dynamic> chat) {
    final chatId = chat['id'];
    final otherName =
        chat['nomeOutroParticipante'] ?? chat['tituloChat'] ?? 'Conversa';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          chatId: chatId,
          chatTitle: otherName,
          otherParticipantName: otherName,
        ),
      ),
    ).then((_) {
      // Re-setup our list view socket listener and refresh chat history upon return
      _setupGlobalSocket();
      _loadChats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: widget.onBackTap != null
            ? Padding(
                padding: const EdgeInsets.only(left: 12.0, top: 8.0, bottom: 8.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: AppRadius.control,
                    onTap: widget.onBackTap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.control,
                        border: Border.all(color: AppColors.gridLine),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.primaryGold,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              )
            : null,
        title: Text(
          'Mensagens',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.only(left: 0.0, right: 0.0, bottom: 12.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar conversas...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: AppColors.gridLine,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: AppColors.primaryGold,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadChats,
        color: AppColors.primaryGold,
        backgroundColor: AppColors.surface,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToContacts,
        backgroundColor: AppColors.goldFill,
        child: const Icon(Icons.chat_bubble_rounded, color: AppColors.onGold),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, color: AppColors.danger, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                    });
                    _loadChats();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldFill,
                  ),
                  child: const Text(
                    'Tentar Novamente',
                    style: TextStyle(color: AppColors.onGold),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_filteredChats.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Nenhuma conversa ativa',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque no botão flutuante para iniciar um chat com um contato disponível de sua organização.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _navigateToContacts,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGold,
                      side: BorderSide(color: AppColors.primaryGold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Buscar Contatos'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _filteredChats.length,
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemBuilder: (context, index) {
        final chat = _filteredChats[index];
        final String title =
            chat['nomeOutroParticipante'] ?? chat['tituloChat'] ?? 'Conversa';
        final String subtitle =
            chat['emailOutroParticipante'] ?? 'Chat privado';
        final String initial = title.isNotEmpty ? title[0].toUpperCase() : 'U';

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.gridLine, width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.goldFill.withValues(
                    alpha: 0.12,
                  ),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: AppColors.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textSecondary,
                  size: 14,
                ),
              ],
            ),
            onTap: () => _openChatRoom(chat),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_service.dart';
import '../data/chat_network_service.dart';
import 'chat_room_screen.dart';

class ContactsListScreen extends StatefulWidget {
  const ContactsListScreen({super.key});

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  final ChatNetworkService _chatService = ChatNetworkService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final data = await _chatService.fetchContacts();
      final currentRole = (AuthService.role ?? 'COLABORADOR').toUpperCase();
      if (mounted) {
        setState(() {
          _contacts = data.where((contact) {
            final contactRole = (contact['role'] ?? '').toString().toUpperCase();
            if (currentRole == 'FUNCIONARIO') {
              // Employees: can chat with colleagues, contractors/leaders, and company support
              return contactRole == 'FUNCIONARIO' || contactRole == 'EMPREITEIRO' || contactRole == 'ADMIN' || contactRole == 'EMPREITEIRA';
            } else if (currentRole == 'CLIENTE') {
              // Clients: can only chat with contractors and support
              return contactRole == 'EMPREITEIRO' || contactRole == 'ADMIN' || contactRole == 'EMPREITEIRA';
            } else if (currentRole == 'EMPREITEIRO') {
              // Contractors: can chat with everyone EXCEPT other contractors
              return contactRole != 'EMPREITEIRO';
            }
            return true;
          }).toList();
          _filteredContacts = _contacts;
          _isLoading = false;
          _errorMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao carregar contatos.';
        });
      }
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((c) {
          final nome = (c['nome'] ?? '').toString().toLowerCase();
          final email = (c['email'] ?? '').toString().toLowerCase();
          return nome.contains(query) || email.contains(query);
        }).toList();
      }
    });
  }

  Color _getRoleColor(String? role) {
    switch (role?.toUpperCase()) {
      case 'ADMIN':
        return Colors.redAccent;
      case 'EMPREITEIRO':
        return AppColors.primaryGold;
      case 'CLIENTE':
        return Colors.blueAccent;
      case 'FUNCIONARIO':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }

  Future<void> _startChat(Map<String, dynamic> contact) async {
    final contactId = contact['id'];
    final contactName = contact['nome'] ?? 'Contato';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      ),
    );

    try {
      final chatData = await _chatService.startPrivateChat(contactId);
      final chatId = chatData['id'];

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        // Navigate to ChatRoomScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              chatId: chatId,
              chatTitle: contactName,
              otherParticipantName: contactName,
              otherParticipantRole: contact['role'],
            ),
          ),
        ).then((_) {
          // If we return, pop this contacts list screen as well to return to chat tab
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível iniciar a conversa: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Contatos Disponíveis',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar contatos...',
                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.gridLine, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _loadContacts();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
              child: const Text('Tentar Novamente', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }

    if (_filteredContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_outlined, color: AppColors.textSecondary.withOpacity(0.5), size: 64),
            const SizedBox(height: 16),
            const Text(
              'Nenhum contato encontrado.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'Contatos devem pertencer ao mesmo Tenant e cumprir as regras.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredContacts.length,
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemBuilder: (context, index) {
        final contact = _filteredContacts[index];
        final String name = contact['nome'] ?? 'Sem Nome';
        final String email = contact['email'] ?? '';
        final String? role = contact['role'];
        final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gridLine, width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primaryGold.withOpacity(0.12),
              child: Text(
                initial,
                style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (role != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getRoleColor(role).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getRoleColor(role).withOpacity(0.3), width: 0.8),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: TextStyle(color: _getRoleColor(role), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                email,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
            onTap: () => _startChat(contact),
          ),
        );
      },
    );
  }
}

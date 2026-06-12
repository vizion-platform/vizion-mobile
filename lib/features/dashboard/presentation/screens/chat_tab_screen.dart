import 'package:flutter/material.dart';
import '../controllers/chat_controller.dart';

class ChatTabScreen extends StatefulWidget {
  const ChatTabScreen({super.key});

  @override
  State<ChatTabScreen> createState() => _ChatTabScreenState();
}

class _ChatTabScreenState extends State<ChatTabScreen> {
  @override
  void initState() {
    super.initState();
    ChatController.instance.fetchChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: ValueListenableBuilder<List<Chat>>(
        valueListenable: ChatController.instance.chatsNotifier,
        builder: (context, chats, _) {
          return Column(
            children: [
              _buildHeader("Conversas", "Gerencie seus contatos e grupos"),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: chats.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF222222)),
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    return ListTile(
                      onTap: () { /* TODO: Implement navigation to detail */ },
                      leading: CircleAvatar(backgroundColor: const Color(0xFF1A1A1A), child: Text(chat.name[0], style: const TextStyle(color: Color(0xFFD4AF37)))),
                      title: Text(chat.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(chat.lastMessage, style: const TextStyle(color: Colors.white54, fontSize: 13), overflow: TextOverflow.ellipsis),
                      trailing: chat.unreadCount > 0 
                        ? Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFFD4AF37), shape: BoxShape.circle), child: Text("${chat.unreadCount}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))
                        : Text(chat.time, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(color: Color(0xFF141414), border: Border(bottom: BorderSide(color: Color(0xFF222222)))),
      child: SafeArea(child: Row(children: [const Icon(Icons.chat_bubble_outline, color: Color(0xFFD4AF37)), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12))])])),
    );
  }
}


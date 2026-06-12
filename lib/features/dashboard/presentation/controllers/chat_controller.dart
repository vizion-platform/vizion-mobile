import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/network/api_client.dart';

class Chat {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;

  Chat(this.id, this.name, this.lastMessage, this.time, this.unreadCount);

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      json['id'].toString(),
      json['participantes'] != null && (json['participantes'] as List).isNotEmpty 
          ? json['participantes'][0]['nome'] : 'Chat',
      json['ultima_mensagem'] ?? '',
      json['data_ultima_mensagem'] ?? '',
      json['nao_lidas'] ?? 0,
    );
  }
}

class ChatController {
  static final ChatController instance = ChatController._internal();
  ChatController._internal();

  final ValueNotifier<List<Chat>> chatsNotifier = ValueNotifier<List<Chat>>([]);

  Future<void> fetchChats() async {
    try {
      final response = await VizionAPIClient.instance.get('/chats');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        chatsNotifier.value = data.map((item) => Chat.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error fetching chats: $e');
    }
  }
}

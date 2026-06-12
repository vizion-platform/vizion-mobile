import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/network/api_client.dart';

class Usuario {
  final String nome;
  final String email;
  final String cargo;
  final String fotoUrl;
  final String dataCadastro;
  final String role; // "Cliente", "Empreiteiro", "Funcionário"

  Usuario({
    required this.nome,
    required this.email,
    required this.cargo,
    required this.fotoUrl,
    required this.dataCadastro,
    required this.role,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      nome: json['nome'] ?? 'Usuário',
      email: json['email'] ?? '',
      cargo: json['role'] ?? '',
      fotoUrl: "https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=256&q=80",
      dataCadastro: json['data_criacao'] ?? '',
      role: json['role'] ?? 'Cliente',
    );
  }
}

class UserController {
  static final UserController instance = UserController._internal();
  UserController._internal();

  final ValueNotifier<Usuario?> usuarioLogado = ValueNotifier<Usuario?>(null);
  final ValueNotifier<bool> contaExcluida = ValueNotifier<bool>(false);

  Future<void> fetchUserData() async {
    try {
      final response = await VizionAPIClient.instance.get('/auth/me');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        usuarioLogado.value = Usuario.fromJson(data);
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  void logout() {
    usuarioLogado.value = null;
    contaExcluida.value = false;
  }

  void deletarContaDeVez() {
    usuarioLogado.value = null;
    contaExcluida.value = true;
  }
}
import 'package:flutter/material.dart';

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
}

class UserController {
  static final UserController instance = UserController._internal();
  UserController._internal();

  // ValueNotifier principal do usuário logado - inicializa com Engenheiro (Empreiteiro) por padrão
  final ValueNotifier<Usuario?> usuarioLogado = ValueNotifier<Usuario?>(
    Usuario(
      nome: "Eng. Carlos Moreira",
      email: "carlos.moreira@vizionup.com",
      cargo: "Engenheiro Chefe",
      fotoUrl: "https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=256&q=80",
      dataCadastro: "12/03/2026",
      role: "Empreiteiro",
    ),
  );

  // Monitora se o usuário acabou de excluir a conta de verdade
  final ValueNotifier<bool> contaExcluida = ValueNotifier<bool>(false);

  // 1. FUNÇÃO DE LOGOUT (Apenas sai da sessão)
  void logout() {
    usuarioLogado.value = null;
    contaExcluida.value = false; // Garante que não mostra tela de exclusão
  }

  // 2. FUNÇÃO DE DELETAR CONTA (Exclui os dados permanentemente da memória)
  void deletarContaDeVez() {
    usuarioLogado.value = null;
    contaExcluida.value = true; // Ativa o estado de conta deletada
  }

  // 3. FUNÇÃO DE CADASTRO / LOGIN (Para restaurar/criar um novo usuário)
  void recriarOuLogarUsuario(Usuario novoUsuario) {
    contaExcluida.value = false;
    usuarioLogado.value = novoUsuario;
  }
}
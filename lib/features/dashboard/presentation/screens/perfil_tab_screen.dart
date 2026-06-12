import 'package:flutter/material.dart';
import '../controllers/user_controller.dart';
import '../../../auth/presentation/login_screen.dart';
import '../../../../core/network/auth_service.dart';

class PerfilTabScreen extends StatelessWidget {
  const PerfilTabScreen({super.key});

  // Função centralizada para deslogar e redirecionar para o Login real
  void _navegarParaLogin(BuildContext context, {required bool esvaziarDados}) {
    if (esvaziarDados) {
      AuthService.deleteCurrentAccount(); // Apaga a conta totalmente do banco de dados/AuthService
      UserController.instance.deletarContaDeVez(); // Apaga dados localmente
    } else {
      AuthService.signOut(); // Limpa a sessão no AuthService
      UserController.instance.logout(); // Limpa a sessão localmente
    }

    // NAVEGAÇÃO REAL: Remove todas as telas anteriores e joga o usuário na Login/Cadastro
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()), 
      (route) => false, // Impede o usuário de voltar ao painel arrastando ou clicando em voltar
    );
  }

  // Janela de confirmação para exclusão de conta
  void _confirmarExclusao(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFE63946)),
              SizedBox(width: 10),
              Text("Excluir Conta?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            "Esta ação é irreversível. Todos os seus dados de cadastro, permissões e acessos serão apagados permanentemente.",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("CANCELAR", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx); // Fecha o modal de alerta
                final success = await AuthService.deleteCurrentAccount();
                if (success) {
                  UserController.instance.deletarContaDeVez();
                  _navegarParaLogin(context, esvaziarDados: true); // Deleta e vai pro Login
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao excluir conta.")));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE63946)),
              child: const Text("EXCLUIR DE VEZ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: ValueListenableBuilder<Usuario?>(
        valueListenable: UserController.instance.usuarioLogado,
        builder: (context, usuario, child) {
          // Fallback de segurança se o usuário sumir da memória antes do redirecionamento
          if (usuario == null) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Meu Perfil", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const Text("Gerenciamento de credenciais e acessos.", style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 32),

                // CARD DO USUÁRIO LOGADO
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF222222)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFF1A1A1A),
                          backgroundImage: NetworkImage(usuario.fotoUrl),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(usuario.nome, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(usuario.cargo, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Text(usuario.email, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                const Text("Configurações de Segurança", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // --- BOTÃO REAL: SAIR DA SESSÃO ---
                InkWell(
                  onTap: () => _navegarParaLogin(context, esvaziarDados: false), // Desloga e vai pro login
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF1C1C1C)),
                    ),
                    child: const Row(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.logout, color: Colors.white70, size: 20),
                            SizedBox(width: 12),
                            Text("Sair da Sessão", style: TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                        Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // --- BOTÃO REAL: EXCLUIR CONTA DE VERDADE ---
                InkWell(
                  onTap: () => _confirmarExclusao(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0B0B),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF3D1414)),
                    ),
                    child: const Row(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.delete_forever, color: Color(0xFFE63946), size: 20),
                            SizedBox(width: 12),
                            Text(
                              "Excluir Minha Conta", 
                              style: TextStyle(color: Color(0xFFE63946), fontSize: 14, fontWeight: FontWeight.bold)
                            ),
                          ],
                        ),
                        Icon(Icons.arrow_forward_ios, color: Color(0xFF5C2323), size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- FIM DA TELA DE PERFIL ---
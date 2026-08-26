import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_service.dart';
import '../../chat/presentation/chat_list_screen.dart';
import '../../agenda/presentation/agenda_screen.dart';
import '../../ponto/presentation/ponto_screen.dart';
import 'widgets/home_dashboard_widget.dart';
import 'widgets/obras_list_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedModuleIndex = 0;

  void _handleSignOut() {
    AuthService.signOut();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sessão encerrada com segurança.'),
        backgroundColor: AppColors.textSecondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.gridLine),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Excluir Conta?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'Esta ação é irreversível. Todos os seus acessos e dados na plataforma VIZION serão removidos permanentemente.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCELAR',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);
                bool success = await AuthService.deleteCurrentAccount();
                if (success) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Sua conta foi excluída permanentemente.',
                        ),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Erro ao excluir conta.'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'EXCLUIR DEFINITIVAMENTE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Modules without outer padding (fullscreen internal padding)
    final bool isFullScreenModule = _selectedModuleIndex == 1 || _selectedModuleIndex == 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: isFullScreenModule
              ? EdgeInsets.zero
              : const EdgeInsets.only(left: 20.0, right: 20.0, top: 24.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildModuleContent(_selectedModuleIndex),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.gridLine, width: 1.5),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppColors.surface,
          currentIndex: _selectedModuleIndex > 4 ? 0 : _selectedModuleIndex,
          onTap: (index) => setState(() => _selectedModuleIndex = index),
          selectedItemColor: AppColors.primaryGold,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 0.3,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics, color: AppColors.primaryGold),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fingerprint_outlined),
              activeIcon: Icon(Icons.fingerprint, color: AppColors.primaryGold),
              label: 'Ponto',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(
                Icons.calendar_month,
                color: AppColors.primaryGold,
              ),
              label: 'Agenda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.construction_outlined),
              activeIcon: Icon(
                Icons.construction,
                color: AppColors.primaryGold,
              ),
              label: 'Obras',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_outlined),
              activeIcon: Icon(Icons.chat, color: AppColors.primaryGold),
              label: 'Chat',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleContent(int index) {
    switch (index) {
      case 0:
        return HomeDashboardWidget(
          onProfileTap: () {
            setState(() {
              _selectedModuleIndex = 5;
            });
          },
        );
      case 1:
        return const PontoScreen();
      case 2:
        return const AgendaScreen();
      case 3:
        return const ObrasListWidget();
      case 4:
        return const ChatListScreen();
      case 5:
        return _buildProfileContent();
      default:
        return const Center(
          child: Text(
            'Módulo não encontrado',
            style: TextStyle(color: Colors.white),
          ),
        );
    }
  }

  Widget _buildProfileContent() {
    final String initial =
        AuthService.nome != null && AuthService.nome!.isNotEmpty
        ? AuthService.nome![0].toUpperCase()
        : 'U';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _selectedModuleIndex = 0;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gridLine),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.primaryGold,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meu Perfil',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Gerencie suas informações corporativas e sessão da conta.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Cartão do Perfil Corporativo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gridLine, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryGold.withValues(alpha: 0.1),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AuthService.nome ?? 'Usuário Vizion',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AuthService.currentUserEmail ?? 'sem-email@vizion.com',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        AuthService.role ?? 'COLABORADOR',
                        style: const TextStyle(
                          color: AppColors.primaryGold,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Seção Sessões Ativas
          const Text(
            'SESSÃO ATIVA',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gridLine),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.phone_android,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dispositivo Atual (Este Celular)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Online • São Paulo, Brasil',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Botões de Saída/Ações
          const Text(
            'CONTA',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.gridLine),
            ),
            leading: const Icon(Icons.logout, color: AppColors.primaryGold),
            title: const Text(
              'Encerrar Sessão',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Desconecta sua conta corporativa com segurança',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: AppColors.textSecondary,
            ),
            onTap: _handleSignOut,
          ),
          const SizedBox(height: 12),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.gridLine),
            ),
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text(
              'Excluir Conta Corporativa',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Remove permanentemente seu registro da plataforma',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: AppColors.textSecondary,
            ),
            onTap: _handleDeleteAccount,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

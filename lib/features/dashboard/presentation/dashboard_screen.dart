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
  bool _isFloatingBarVisible = true;

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
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
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
              onPressed: () => Navigator.pop(dialogContext),
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
                Navigator.pop(dialogContext);
                bool success = await AuthService.deleteCurrentAccount();
                if (success) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Sua conta foi excluída permanentemente.',
                      ),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  navigator.pushReplacementNamed('/login');
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Erro ao excluir conta.'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
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

  void _navigateToModule(int index) {
    setState(() {
      _selectedModuleIndex = index;
      if (index == 0) {
        _isFloatingBarVisible = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Modules without outer padding (fullscreen internal padding)
    final bool isFullScreenModule =
        _selectedModuleIndex == 1 || _selectedModuleIndex == 2 || _selectedModuleIndex == 4;

    return PopScope(
      canPop: _selectedModuleIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateToModule(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (_selectedModuleIndex == 0 && notification.metrics.axis == Axis.vertical) {
                if (notification.metrics.pixels <= 10) {
                  if (!_isFloatingBarVisible) {
                    setState(() {
                      _isFloatingBarVisible = true;
                    });
                  }
                } else if (notification is ScrollUpdateNotification) {
                  final double? delta = notification.scrollDelta;
                  if (delta != null) {
                    if (delta > 2.0 && _isFloatingBarVisible) {
                      setState(() {
                        _isFloatingBarVisible = false;
                      });
                    } else if (delta < -2.0 && !_isFloatingBarVisible) {
                      setState(() {
                        _isFloatingBarVisible = true;
                      });
                    }
                  }
                }
              }
              return false;
            },
            child: Stack(
              children: [
                Padding(
                  padding: isFullScreenModule
                      ? EdgeInsets.zero
                      : const EdgeInsets.only(left: 20.0, right: 20.0, top: 24.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildModuleContent(_selectedModuleIndex),
                  ),
                ),

                // Floating Bottom Bar locked on Home Dashboard only: Ponto Centered, Chat to the Right
                // Smoothly hides when scrolled and reappears on top/scroll up
                if (_selectedModuleIndex == 0)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 18,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      offset: _isFloatingBarVisible ? Offset.zero : const Offset(0, 1.8),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        opacity: _isFloatingBarVisible ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: !_isFloatingBarVisible,
                          child: Row(
                            children: [
                              // Counterweight matching chat button width to keep Ponto perfectly centered
                              const SizedBox(width: 48),
                              const Spacer(),
                              _buildFloatingPontoButton(),
                              const Spacer(),
                              _buildFloatingChatButton(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingPontoButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => _navigateToModule(1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.primaryGold,
                Color(0xFFE5C07B),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGold.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fingerprint_rounded,
                color: Colors.black,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'BATER PONTO',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingChatButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _navigateToModule(4),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryGold.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.primaryGold,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleContent(int index) {
    switch (index) {
      case 0:
        return HomeDashboardWidget(
          onProfileTap: () => _navigateToModule(5),
          onAgendaTap: () => _navigateToModule(2),
          onObrasTap: () => _navigateToModule(3),
          onPontoTap: () => _navigateToModule(1),
          onChatTap: () => _navigateToModule(4),
        );
      case 1:
        return PontoScreen(
          onBackTap: () => _navigateToModule(0),
        );
      case 2:
        return AgendaScreen(
          onBackTap: () => _navigateToModule(0),
        );
      case 3:
        return ObrasListWidget(
          onBackTap: () => _navigateToModule(0),
        );
      case 4:
        return ChatListScreen(
          onBackTap: () => _navigateToModule(0),
        );
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
                onTap: () => _navigateToModule(0),
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

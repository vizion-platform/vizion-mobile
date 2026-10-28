import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_service.dart';
import '../../chat/data/chat_network_service.dart';
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

  Future<void> _handleSignOut() async {
    // Desconecta o chat antes de limpar a sessão: o MQTT usa o token do usuário.
    ChatNetworkService().disconnectSocket();
    await AuthService.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: AppColors.gridLine),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.danger,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Excluir Conta?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Esta ação é irreversível. Todos os seus acessos e dados na plataforma VIZION serão removidos permanentemente.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
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
                              // Com a letra ampliada o botão de ponto encolhe em vez de estourar a barra
                              Expanded(
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: _buildFloatingPontoButton(),
                                  ),
                                ),
                              ),
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
        borderRadius: AppRadius.card,
        onTap: () => _navigateToModule(1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.goldFill,
            borderRadius: AppRadius.card,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fingerprint_rounded,
                color: AppColors.onGold,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Bater ponto',
                style: TextStyle(
                  color: AppColors.onGold,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
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
        borderRadius: AppRadius.card,
        onTap: () => _navigateToModule(4),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.gridLine),
          ),
          child: Center(
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
        return Center(
          child: Text(
            'Módulo não encontrado',
            style: TextStyle(color: AppColors.textPrimary),
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
                borderRadius: BorderRadius.circular(6),
                onTap: () => _navigateToModule(0),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.gridLine),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.primaryGold,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meu Perfil',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
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
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.gridLine, width: 1.5),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.goldFill.withValues(alpha: 0.1),
                  child: Text(
                    initial,
                    style: TextStyle(
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
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AuthService.currentUserEmail ?? 'sem-email@vizion.com',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primaryGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        AuthService.role ?? 'COLABORADOR',
                        style: TextStyle(
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
          Text(
            'SESSÃO ATIVA',
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.gridLine),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.phone_android,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dispositivo Atual (Este Celular)',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Online • São Paulo, Brasil',
                        style: TextStyle(
                          color: AppColors.success,
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
          Text(
            'CONTA',
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
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
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: AppColors.gridLine),
            ),
            leading: Icon(Icons.logout, color: AppColors.primaryGold),
            title: Text(
              'Encerrar Sessão',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Desconecta sua conta corporativa com segurança',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: AppColors.textSecondary,
            ),
            onTap: _handleSignOut,
          ),
          const SizedBox(height: 12),
          // Tema claro/escuro, como no desktop; a escolha fica salva no aparelho.
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: AppColors.gridLine),
            ),
            secondary: Icon(Icons.dark_mode_outlined, color: AppColors.primaryGold),
            title: Text(
              'Tema escuro',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Alterna entre o visual claro e o escuro',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            value: AppTheme.isDark,
            onChanged: (dark) => AppTheme.setDark(dark),
          ),
          const SizedBox(height: 12),

          // Acessibilidade: tamanho da letra do app; o layout se adapta ao tamanho escolhido.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.gridLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.text_fields_rounded, color: AppColors.primaryGold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Acessibilidade',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Tamanho da letra do aplicativo',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<double>(
                  valueListenable: AppTheme.fontScale,
                  builder: (context, escala, _) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final opcao in AppTheme.opcoesFonte)
                        ChoiceChip(
                          label: Text(opcao.rotulo),
                          selected: escala == opcao.escala,
                          onSelected: (_) => AppTheme.setFontScale(opcao.escala),
                          selectedColor: AppColors.primaryGold.withValues(alpha: 0.25),
                          backgroundColor: AppColors.surfaceAlt,
                          labelStyle: TextStyle(
                            color: escala == opcao.escala ? AppColors.primaryGold : AppColors.textSecondary,
                            fontWeight: escala == opcao.escala ? FontWeight.bold : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: escala == opcao.escala ? AppColors.primaryGold : AppColors.gridLine,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Exemplo: é assim que os textos do aplicativo vão aparecer.',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ],
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
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: AppColors.gridLine),
            ),
            leading: Icon(Icons.delete_forever, color: AppColors.danger),
            title: Text(
              'Excluir Conta Corporativa',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Remove permanentemente seu registro da plataforma',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Icon(
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

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_service.dart';
import '../../chat/data/chat_network_service.dart';
import '../../chat/presentation/chat_list_screen.dart';
import '../../agenda/presentation/agenda_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/widgets/user_avatar.dart';
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
        bottomNavigationBar: _buildBottomNav(),
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

                // Botão flutuante de ponto: só existe com o ponto habilitado (kPontoHabilitado).
                // A navegação principal fica na barra inferior.
                if (kPontoHabilitado && _selectedModuleIndex == 0)
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
                              // Com a letra ampliada o botão de ponto encolhe em vez de estourar a barra
                              Expanded(
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: _buildFloatingPontoButton(),
                                  ),
                                ),
                              ),
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

  /// Módulo exibido por destino da barra inferior (o ponto não tem destino próprio).
  static const _navModules = [0, 3, 2, 4, 5];

  Widget _buildBottomNav() {
    final selected = _navModules.indexOf(_selectedModuleIndex);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.gridLine)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          height: 68,
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.goldSoft,
          selectedIndex: selected < 0 ? 0 : selected,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => _navigateToModule(_navModules[i]),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.primaryGold),
              label: 'Início',
            ),
            NavigationDestination(
              icon: Icon(Icons.domain_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.domain_rounded, color: AppColors.primaryGold),
              label: 'Obras',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.calendar_month_rounded, color: AppColors.primaryGold),
              label: 'Agenda',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.chat_bubble_rounded, color: AppColors.primaryGold),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.person_rounded, color: AppColors.primaryGold),
              label: 'Perfil',
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

  /// Troca a foto de perfil: o usuário escolhe câmera ou galeria e a imagem vai para o MinIO pela API.
  Future<void> _alterarFotoPerfil() async {
    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: AppColors.primaryGold),
              title: Text('Tirar foto', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: AppColors.primaryGold),
              title: Text('Escolher da galeria', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origem == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final foto = await ImagePicker().pickImage(source: origem, maxWidth: 640, imageQuality: 80);
      if (foto == null) return;
      final bytes = await foto.readAsBytes();
      await AuthService.uploadAvatar(bytes, foto.name.isEmpty ? 'avatar.jpg' : foto.name);
      messenger.showSnackBar(SnackBar(
        content: const Text('Foto de perfil atualizada.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _buildProfileContent() {

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
                Stack(
                  children: [
                    const UserAvatar(radius: 40, fontSize: 32),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Semantics(
                        button: true,
                        label: 'Alterar foto de perfil',
                        child: Material(
                          color: AppColors.goldFill,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _alterarFotoPerfil,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.photo_camera_outlined, size: 18, color: AppColors.onGold),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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

          // Acessibilidade: tamanho da letra, tema, negrito e animações ficam em uma página própria.
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: AppColors.gridLine),
            ),
            leading: Icon(Icons.accessibility_new_rounded, color: AppColors.primaryGold),
            title: Text(
              'Acessibilidade',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Tamanho da letra, negrito e animações',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            onTap: () => Navigator.of(context).pushNamed('/acessibilidade'),
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

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_service.dart';
import 'widgets/home_dashboard_widget.dart';
import 'widgets/obras_list_widget.dart'; // <-- Certifique-se de que este import está aqui

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedModuleIndex = 0;

  final List<Map<String, dynamic>> _modules = [
    {'title': 'Dashboard', 'icon': Icons.analytics_outlined},
    {'title': 'Obras', 'icon': Icons.construction_outlined},
    {'title': 'Mensagens', 'icon': Icons.chat_bubble_outline},
    {'title': 'Admin', 'icon': Icons.admin_panel_settings_outlined},
  ];

  void _handleSignOut() {
    AuthService.signOut();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sessão encerrada.'), backgroundColor: AppColors.textSecondary),
    );
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Excluir Conta?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'Esta ação é irreversível. Todos os seus acessos à plataforma VIZION serão revogados imediatamente.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                AuthService.deleteCurrentAccount();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sua conta foi excluída permanentemente.'), backgroundColor: Colors.redAccent),
                );
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('EXCLUIR DEFINITIVAMENTE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              backgroundColor: AppColors.surface,
              selectedIndex: _selectedModuleIndex,
              onDestinationSelected: (index) => setState(() => _selectedModuleIndex = index),
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: AppColors.primaryGold),
              selectedLabelTextStyle: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
              unselectedLabelTextStyle: const TextStyle(color: AppColors.textSecondary),
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Text('VIZION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white)),
              ),
              trailing: Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                      tooltip: 'Sair da Conta',
                      onPressed: _handleSignOut,
                    ),
                    const SizedBox(height: 12),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      tooltip: 'Excluir minha Conta',
                      onPressed: _handleDeleteAccount,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              destinations: _modules.map((module) {
                return NavigationRailDestination(
                  icon: Icon(module['icon']),
                  label: Text(module['title'], style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1, color: AppColors.gridLine),
            
            Expanded(
              child: Container(
                color: AppColors.background,
                padding: const EdgeInsets.all(32.0),
                child: _buildModuleContent(_selectedModuleIndex), // <-- CHAMA O CONTEÚDO ATUALIZADO
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleContent(int index) {
    switch (index) {
      case 0: 
        return const HomeDashboardWidget();
      case 1: 
        return const ObrasListWidget(); // <-- ISSO AQUI DEVE CHAMAR O SEU COMPONENTE COMPLETO COM ESTADO
      case 2: 
        return const Center(child: Text('Módulo Chat', style: TextStyle(color: Colors.white)));
      case 3: 
        return const Center(child: Text('Módulo Admin', style: TextStyle(color: Colors.white)));
      default: 
        return const Center(child: Text('Módulo não encontrado', style: TextStyle(color: Colors.white)));
    }
  }
}

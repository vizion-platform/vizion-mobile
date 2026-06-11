import 'package:flutter/material.dart';
import 'screens/obras_list_screen.dart'; 
import 'screens/home_tab_screen.dart';// Importa a nova tela de listagem
import 'screens/perfil_tab_screen.dart';
import 'screens/chat_tab_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 1; // Focado na aba Obras por padrão

 final List<Widget> _screens = [
    const HomeTabScreen(),
    const ObrasListScreen(), 
    const Center(child: Text('Avanço', style: TextStyle(color: Colors.white))),
    const ChatTabScreen(),
    const PerfilTabScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Dark mode do AppTheme
      body: SafeArea(
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF141414),
        selectedItemColor: const Color(0xFFD4AF37), // Dourado
        unselectedItemColor: Colors.white38,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.business_center_outlined), label: 'Obras'),
          BottomNavigationBarItem(icon: Icon(Icons.build_circle_outlined), label: 'Obra'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}
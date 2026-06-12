import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/network/auth_service.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize auth session from local storage
  final bool isLoggedIn = await AuthService.init();
  
  runApp(VizionApp(isLoggedIn: isLoggedIn));
}

class VizionApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const VizionApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vizion - Gestão de Obras',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: isLoggedIn ? '/dashboard' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}

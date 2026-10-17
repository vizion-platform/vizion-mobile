import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/network/auth_service.dart';
import 'features/auth/presentation/change_password_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/ponto/presentation/ponto_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize auth session from local storage
  final bool isLoggedIn = await AuthService.init();

  // Sessão que não pode mais ser renovada: volta ao login limpando a pilha de telas.
  AuthService.onSessionExpired = () async {
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  };
  AuthService.onPasswordChangeRequired = () {
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/trocar-senha', (_) => false);
  };
  
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
      navigatorKey: navigatorKey,
      initialRoute: !isLoggedIn
          ? '/login'
          : (AuthService.mustChangePassword ? '/trocar-senha' : '/dashboard'),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/trocar-senha': (context) => const ChangePasswordScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/ponto': (context) => const PontoScreen(),
      },
    );
  }
}

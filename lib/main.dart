import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/network/auth_service.dart';
import 'features/acessibilidade/presentation/acessibilidade_screen.dart';
import 'features/auth/presentation/change_password_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/ponto/presentation/ponto_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.load();
  await AppTheme.loadFontScale();
  await AppTheme.loadAccessibility();

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
    // O tema (claro/escuro) e a opção de reduzir animações mudam em tempo de execução, como no desktop.
    return ListenableBuilder(
      listenable: Listenable.merge([AppTheme.mode, AppTheme.reduceMotion]),
      builder: (context, _) => MaterialApp(
      title: 'Vizion - Gestão de Obras',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.reduceMotion.value
          ? AppTheme.theme.copyWith(
              pageTransitionsTheme: const PageTransitionsTheme(builders: {
                TargetPlatform.android: _SemTransicao(),
                TargetPlatform.iOS: _SemTransicao(),
                TargetPlatform.windows: _SemTransicao(),
                TargetPlatform.macOS: _SemTransicao(),
                TargetPlatform.linux: _SemTransicao(),
              }),
            )
          : AppTheme.theme,
      navigatorKey: navigatorKey,
      // Acessibilidade (tamanho da letra, negrito e animações), somada às preferências do sistema.
      builder: (context, child) => ListenableBuilder(
        listenable: Listenable.merge([AppTheme.fontScale, AppTheme.boldText, AppTheme.reduceMotion]),
        builder: (context, _) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(mediaQuery.textScaler.scale(1) * AppTheme.fontScale.value),
              boldText: mediaQuery.boldText || AppTheme.boldText.value,
              disableAnimations: mediaQuery.disableAnimations || AppTheme.reduceMotion.value,
            ),
            child: child!,
          );
        },
      ),
      initialRoute: !isLoggedIn
          ? '/login'
          : (AuthService.mustChangePassword ? '/trocar-senha' : '/dashboard'),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/trocar-senha': (context) => const ChangePasswordScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/ponto': (context) => const PontoScreen(),
        '/acessibilidade': (context) => const AcessibilidadeScreen(),
      },
    ));
  }
}

/// Troca de tela sem animação (opção "Reduzir animações").
class _SemTransicao extends PageTransitionsBuilder {
  const _SemTransicao();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

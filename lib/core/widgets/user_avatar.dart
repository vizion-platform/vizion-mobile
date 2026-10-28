import 'package:flutter/material.dart';

import '../network/auth_service.dart';
import '../theme/app_theme.dart';

/// Foto de perfil do usuário logado; sem foto (ou se ela não carregar), mostra a inicial do nome.
class UserAvatar extends StatelessWidget {
  final double radius;
  final double fontSize;
  final Color? background;

  const UserAvatar({super.key, this.radius = 22, this.fontSize = 16, this.background});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: AuthService.avatarKey,
      builder: (context, _, __) {
        final url = AuthService.avatarUrl;
        final nome = AuthService.nome;
        final inicial = (nome != null && nome.isNotEmpty) ? nome[0].toUpperCase() : 'U';
        return CircleAvatar(
          radius: radius,
          backgroundColor: background ?? AppColors.goldFill.withValues(alpha: 0.1),
          foregroundImage: url != null ? NetworkImage(url) : null,
          onForegroundImageError: url != null ? (_, __) {} : null,
          child: Text(
            inicial,
            style: TextStyle(
              color: AppColors.primaryGold,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

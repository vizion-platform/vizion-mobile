import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Ações do fluxo único das fases, na ordem em que os botões aparecem.
/// Os mesmos nomes e a mesma ordem valem no desktop; quem libera cada ação é a API.
const List<String> ordemAcoesFase = ['INICIAR', 'RETOMAR', 'PAUSAR', 'FINALIZAR'];

String rotuloAcaoFase(String acao) {
  switch (acao) {
    case 'INICIAR':
      return 'Iniciar';
    case 'RETOMAR':
      return 'Retomar';
    case 'PAUSAR':
      return 'Pausar';
    case 'FINALIZAR':
      return 'Finalizar';
    case 'CANCELAR':
      return 'Cancelar';
    default:
      return acao;
  }
}

Color corAcaoFase(String acao) {
  switch (acao) {
    case 'PAUSAR':
      return AppColors.warning;
    case 'FINALIZAR':
      return AppColors.success;
    case 'CANCELAR':
      return AppColors.danger;
    default:
      return AppColors.primaryGold;
  }
}

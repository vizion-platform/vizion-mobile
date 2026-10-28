import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Página de acessibilidade: tamanho da letra, tema, negrito e animações.
/// Todas as escolhas valem para o app inteiro e ficam salvas no aparelho (também após sair da conta).
class AcessibilidadeScreen extends StatelessWidget {
  const AcessibilidadeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            AppTheme.fontScale,
            AppTheme.boldText,
            AppTheme.reduceMotion,
            AppTheme.mode,
          ]),
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              const SizedBox(height: 8),
              Text(
                'Deixe o aplicativo mais fácil de ler e de usar. As escolhas ficam salvas neste aparelho.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              _secao('Tamanho da letra'),
              for (final opcao in AppTheme.opcoesFonte) _opcaoDeFonte(opcao.escala, opcao.rotulo),
              const SizedBox(height: 4),
              _exemplo(),
              const SizedBox(height: 24),
              _secao('Leitura'),
              _interruptor(
                icone: Icons.dark_mode_outlined,
                titulo: 'Tema escuro',
                descricao: 'Fundo escuro, que cansa menos a vista à noite.',
                valor: AppTheme.isDark,
                aoMudar: AppTheme.setDark,
              ),
              _interruptor(
                icone: Icons.format_bold_rounded,
                titulo: 'Texto em negrito',
                descricao: 'Deixa todas as letras mais grossas e fáceis de ler.',
                valor: AppTheme.boldText.value,
                aoMudar: AppTheme.setBoldText,
              ),
              _interruptor(
                icone: Icons.motion_photos_off_outlined,
                titulo: 'Reduzir animações',
                descricao: 'As telas trocam sem movimento.',
                valor: AppTheme.reduceMotion.value,
                aoMudar: AppTheme.setReduceMotion,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: AppTheme.acessibilidadePadrao ? null : AppTheme.restaurarAcessibilidade,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Restaurar padrão'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.gridLine),
                    shape: const StadiumBorder(),
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

  Widget _header(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Acessibilidade',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _secao(String titulo) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Semantics(
          header: true,
          child: Text(
            titulo,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      );

  Widget _opcaoDeFonte(double escala, String rotulo) {
    final selecionada = AppTheme.fontScale.value == escala;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selecionada,
        inMutuallyExclusiveGroup: true,
        label: 'Tamanho da letra $rotulo',
        child: Material(
          color: selecionada ? AppColors.goldSoft : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selecionada ? AppColors.primaryGold : AppColors.gridLine,
              width: selecionada ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => AppTheme.setFontScale(escala),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      'Aa',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18 * escala,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        rotulo,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: selecionada ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (selecionada) Icon(Icons.check_circle_rounded, color: AppColors.primaryGold),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _exemplo() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gridLine),
        ),
        child: Text(
          'Exemplo: é assim que os textos do aplicativo vão aparecer.',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.4),
        ),
      );

  Widget _interruptor({
    required IconData icone,
    required String titulo,
    required String descricao,
    required bool valor,
    required Future<void> Function(bool) aoMudar,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        value: valor,
        onChanged: (v) => aoMudar(v),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        tileColor: AppColors.surface,
        activeThumbColor: AppColors.primaryGold,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.gridLine),
        ),
        secondary: Icon(icone, color: AppColors.primaryGold),
        title: Text(
          titulo,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          descricao,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class StepInvestimentoProjeto extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController investimentoController;
  final VoidCallback onBack;
  final VoidCallback onPublish;

  const StepInvestimentoProjeto({
    super.key,
    required this.formKey,
    required this.investimentoController,
    required this.onBack,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STEP 02 / 02',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Inicializar Projeto',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 32),

          // Investimento Estimado
          TextFormField(
            controller: investimentoController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'INVESTIMENTO ESTIMADO (R\$)',
              labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gridLine)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryGold, width: 2)),
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            validator: (value) => value == null || value.isEmpty ? 'Insira um valor estimado' : null,
          ),
          const SizedBox(height: 48),

          // Botões de Ação
          Row(
            children: [
              ElevatedButton(
                onPressed: onBack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gridLine, // Cinza escuro integrado
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  elevation: 0,
                ),
                child: const Text('VOLTAR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
              ),
              ElevatedButton(
                onPressed: onPublish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  elevation: 0,
                ),
                child: const Text('PUBLICAR OBRA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
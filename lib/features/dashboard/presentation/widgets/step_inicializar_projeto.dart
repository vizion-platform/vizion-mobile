import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class StepInicializarProjeto extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController logradouroController;
  final TextEditingController numeroController;
  final TextEditingController bairroController;
  final TextEditingController cepController;
  final TextEditingController cidadeController;
  final TextEditingController estadoController;
  final TextEditingController complementoController;
  final TextEditingController dataController;
  final VoidCallback onNext;
  final VoidCallback onBackToHome; // <-- Função para voltar para a tela inicial

  const StepInicializarProjeto({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.logradouroController,
    required this.numeroController,
    required this.bairroController,
    required this.cepController,
    required this.cidadeController,
    required this.estadoController,
    required this.complementoController,
    required this.dataController,
    required this.onNext,
    required this.onBackToHome, // <-- Requerido no construtor
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP 01 / 02',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 0.4, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Inicializar Projeto',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 24),
          
          // Nome do Projeto
          TextFormField(
            controller: nameController,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: _inputStyle('Nome do projeto', hint: 'Ex: Edifício Horizonte'),
            validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
          ),
          const SizedBox(height: 16),

          // Logradouro e Número
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: logradouroController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _inputStyle('Logradouro', hint: 'Rua, Avenida...'),
                  validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: numeroController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _inputStyle('Número', hint: '123'),
                  validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bairro e CEP
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: bairroController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _inputStyle('Bairro', hint: 'Centro'),
                  validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: cepController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _inputStyle('CEP', hint: '00000-000'),
                  validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cidade, Estado e Complemento
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: cidadeController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _inputStyle('Cidade', hint: 'Cidade'),
                  validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: estadoController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _inputStyle('Estado (UF)', hint: 'SP'),
                  validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: complementoController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _inputStyle('Complemento', hint: 'Apto, Bloco...'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Data de Início
          TextFormField(
            controller: dataController,
            style: TextStyle(color: AppColors.textPrimary),
            readOnly: true,
            decoration: _inputStyle('Data de início', hint: 'dd/mm/aaaa').copyWith(
              suffixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary, size: 18),
            ),
            onTap: () async {
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: AppColors.primaryGold,
                        onPrimary: AppColors.onGold,
                        surface: AppColors.surface,
                        onSurface: AppColors.textPrimary,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (pickedDate != null) {
                dataController.text = "${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}";
              }
            },
            validator: (value) => value == null || value.isEmpty ? 'Selecione uma data' : null,
          ),
          const SizedBox(height: 32),

          // Alinhamento dos Botões idêntico ao Step 2 original
          Row(
            children: [
              ElevatedButton(
                onPressed: onBackToHome, // <-- Fecha a modal e volta para o início
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldFill, // Cor bege idêntica à imagem
                  foregroundColor: AppColors.onGold,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                child: const Text('VOLTAR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.4, fontSize: 13)),
              ),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldFill,
                  foregroundColor: AppColors.onGold,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                child: const Text('Próximo', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.4, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputStyle(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 0.4, fontWeight: FontWeight.bold),
      hintStyle: TextStyle(color: AppColors.gridLine, fontSize: 14),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gridLine)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryGold, width: 2)),
      errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.danger)),
      focusedErrorBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.danger, width: 2)),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    );
  }
}

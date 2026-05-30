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
          const Text(
            'STEP 01 / 02',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Inicializar Projeto',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 24),
          
          // Nome do Projeto
          TextFormField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputStyle('NOME DO PROJETO', hint: 'Ex: Edifício Horizonte'),
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
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('LOGRADOURO', hint: 'Rua, Avenida...'),
                  validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: numeroController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('NÚMERO', hint: '123'),
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
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('BAIRRO', hint: 'Centro'),
                  validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: cepController,
                  style: const TextStyle(color: Colors.white),
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
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('CIDADE', hint: 'Cidade'),
                  validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: estadoController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('ESTADO (UF)', hint: 'SP'),
                  validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: complementoController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('COMPLEMENTO', hint: 'Apto, Bloco...'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Data de Início
          TextFormField(
            controller: dataController,
            style: const TextStyle(color: Colors.white),
            readOnly: true,
            decoration: _inputStyle('DATA DE INÍCIO', hint: 'dd/mm/aaaa').copyWith(
              suffixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary, size: 18),
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
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.primaryGold,
                        onPrimary: Colors.black,
                        surface: AppColors.surface,
                        onSurface: Colors.white,
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
                  backgroundColor: const Color(0xFFC4B89B), // Cor bege idêntica à imagem
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  elevation: 0,
                ),
                child: const Text('VOLTAR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
              ),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  elevation: 0,
                ),
                child: const Text('PRÓXIMO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
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
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold),
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gridLine)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryGold, width: 2)),
      errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 2)),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    );
  }
}

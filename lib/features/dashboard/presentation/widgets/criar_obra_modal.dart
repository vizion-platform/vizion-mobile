import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'step_inicializar_projeto.dart';
import 'step_investimento_projeto.dart';

class CriarObraModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onObraCriada;

  const CriarObraModal({super.key, required this.onObraCriada});

  @override
  State<CriarObraModal> createState() => _CriarObraModalState();
}

class _CriarObraModalState extends State<CriarObraModal> {
  int _currentStep = 1;

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cepController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _estadoController = TextEditingController();
  final _complementoController = TextEditingController();
  final _dataController = TextEditingController();
  final _investimentoController = TextEditingController(text: '0.00');

  @override
  void dispose() {
    _nameController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _bairroController.dispose();
    _cepController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    _complementoController.dispose();
    _dataController.dispose();
    _investimentoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.gridLine),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: _currentStep == 1
            ? StepInicializarProjeto(
                formKey: _step1FormKey,
                nameController: _nameController,
                logradouroController: _logradouroController,
                numeroController: _numeroController,
                bairroController: _bairroController,
                cepController: _cepController,
                cidadeController: _cidadeController,
                estadoController: _estadoController,
                complementoController: _complementoController,
                dataController: _dataController,
                onNext: () => setState(() => _currentStep = _step1FormKey.currentState!.validate() ? 2 : 1),
                onBackToHome: () => Navigator.pop(context),
              )
            : StepInvestimentoProjeto(
                formKey: _step2FormKey,
                investimentoController: _investimentoController,
                onBack: () => setState(() => _currentStep = 1),
                onPublish: () {
                  if (_step2FormKey.currentState!.validate()) {
                    DateTime start = DateTime.now();
                    try {
                      List<String> p = _dataController.text.split('/');
                      start = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
                    } catch (_) {}
                    DateTime end = start.add(const Duration(days: 90)); // Default forecast 90 days

                    String formatDate(DateTime dt) {
                      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
                    }

                    widget.onObraCriada({
                      'nome': _nameController.text,
                      'status': 'PLANEJAMENTO',
                      'data_inicio': formatDate(start),
                      'data_previsao_entrega': formatDate(end),
                      'valor_total_estimado': double.tryParse(_investimentoController.text.replaceAll(',', '.')) ?? 0.0,
                      'logradouro': _logradouroController.text,
                      'numero': _numeroController.text,
                      'complemento': _complementoController.text,
                      'bairro': _bairroController.text,
                      'cidade': _cidadeController.text,
                      'estado': _estadoController.text,
                      'cep': _cepController.text,
                    });
                    Navigator.pop(context);
                  }
                },
              ),
      ),
    );
  }
}

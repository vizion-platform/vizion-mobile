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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.gridLine),
      ),
      child: Container(
        width: 680,
        padding: const EdgeInsets.all(40.0),
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
                onBackToHome: () => Navigator.pop(context), // <-- Ação que fecha a janela na hora!
              )
            : StepInvestimentoProjeto(
                formKey: _step2FormKey,
                investimentoController: _investimentoController,
                onBack: () => setState(() => _currentStep = 1),
                onPublish: () {
                  if (_step2FormKey.currentState!.validate()) {
                    widget.onObraCriada({
                      'nome': _nameController.text,
                      'status': 'Fase de Fundação',
                      'progresso': 0.05,
                      'responsavel': 'A definir',
                    });
                    Navigator.pop(context);
                  }
                },
              ),
      ),
    );
  }
}

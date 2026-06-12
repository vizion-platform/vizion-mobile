import 'package:flutter/material.dart';
import '../../data/models/obra_model.dart';
import '../controllers/obras_controller.dart';
import 'package:flutter_application_1/core/network/api_client.dart';

class CadastroObraScreen extends StatefulWidget {
  const CadastroObraScreen({super.key});

  @override
  State<CadastroObraScreen> createState() => _CadastroObraScreenState();
}

class _CadastroObraScreenState extends State<CadastroObraScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController(); // Adicionado para descricao
  final _valorCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _cliCtrl = TextEditingController();
  final _dataInicioCtrl = TextEditingController(text: "2026-06-11");
  final _dataFimCtrl = TextEditingController(text: "2026-12-30");

  @override
  void dispose() {
    _tituloCtrl.dispose(); _descCtrl.dispose(); _valorCtrl.dispose();
    _endCtrl.dispose(); _cliCtrl.dispose(); _dataInicioCtrl.dispose(); _dataFimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: const Text("Cadastrar Nova Obra", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField("Nome da Obra *", _tituloCtrl),
              _buildTextField("Descrição", _descCtrl),
              _buildTextField("Valor Estimado (Ex: 50000.00)", _valorCtrl),
              _buildTextField("ID do Endereço", _endCtrl),
              _buildTextField("ID do Cliente", _cliCtrl),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final body = {
                        "nome": _tituloCtrl.text,
                        "descricao": _descCtrl.text,
                        "cliente_id": int.tryParse(_cliCtrl.text) ?? 1,
                        "endereco_id": int.tryParse(_endCtrl.text) ?? 1,
                        "data_inicio": _dataInicioCtrl.text,
                        "data_previsao_fim": _dataFimCtrl.text,
                        "valor_total": double.tryParse(_valorCtrl.text) ?? 0.0
                      };

                      try {
                        final response = await VizionAPIClient.instance.post('/obra', body);
                        if (response.statusCode == 201 || response.statusCode == 200) {
                          // ObrasController.instance.fetchObras(); // Refresh na lista
                          Navigator.pop(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao cadastrar: ${response.body}')));
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text("SALVAR CADASTRO", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
          filled: true,
          fillColor: const Color(0xFF141414),
          enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF222222)), borderRadius: BorderRadius.circular(4)),
          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFD4AF37)), borderRadius: BorderRadius.circular(4)),
        ),
        validator: (value) => value == null || value.isEmpty ? "Campo obrigatório" : null,
      ),
    );
  }
}
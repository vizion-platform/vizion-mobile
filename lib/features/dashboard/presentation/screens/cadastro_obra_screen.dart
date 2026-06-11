import 'package:flutter/material.dart';
import '../../data/models/obra_model.dart';
import '../controllers/obras_controller.dart';

class CadastroObraScreen extends StatefulWidget {
  const CadastroObraScreen({super.key});

  @override
  State<CadastroObraScreen> createState() => _CadastroObraScreenState();
}

class _CadastroObraScreenState extends State<CadastroObraScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores dos campos de texto
  final _tituloCtrl = TextEditingController();
  final _respCtrl = TextEditingController();
  final _statusCtrl = TextEditingController(text: "Em Execução");
  final _prazoCtrl = TextEditingController(text: "30/12/2026");
  final _progressoCtrl = TextEditingController(text: "0%");
  final _valorCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _cliCtrl = TextEditingController();
  final _empCtrl = TextEditingController();

  @override
  void dispose() {
    _tituloCtrl.dispose(); _respCtrl.dispose(); _valorCtrl.dispose();
    _endCtrl.dispose(); _cliCtrl.dispose(); _empCtrl.dispose();
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
              _buildTextField("Engenheiro / Mestre Responsável *", _respCtrl),
              _buildTextField("Valor Estimado (Ex: R\$ 5,0 mi)", _valorCtrl),
              _buildTextField("Endereço Completo", _endCtrl),
              _buildTextField("Cliente", _cliCtrl),
              _buildTextField("Empreiteiro / Construtora", _empCtrl),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      // Cria o objeto da nova obra
                      final novaObra = Obra(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        titulo: _tituloCtrl.text,
                        responsavel: _respCtrl.text,
                        status: _statusCtrl.text,
                        prazo: _prazoCtrl.text,
                        progresso: _progressoCtrl.text,
                        valorEstimado: _valorCtrl.text.isEmpty ? "Não informado" : _valorCtrl.text,
                        endereco: _endCtrl.text.isEmpty ? "Não informado" : _endCtrl.text,
                        cliente: _cliCtrl.text.isEmpty ? "Não informado" : _cliCtrl.text,
                        empreiteiro: _empCtrl.text.isEmpty ? "Não informado" : _empCtrl.text,
                      );

                      // Salva no controlador global
                      ObrasController.instance.adicionarObra(novaObra);

                      // Retorna para a listagem
                      Navigator.pop(context);
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
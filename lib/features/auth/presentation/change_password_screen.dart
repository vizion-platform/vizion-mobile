import 'package:flutter/material.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/theme/app_theme.dart';

/// Troca obrigatória da senha temporária: o servidor bloqueia o restante da API até que seja feita.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _loading = false;
  String? _erro;

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _erro = null;
    });
    final erro = await AuthService.trocarSenha(_atual.text, _nova.text);
    if (!mounted) return;
    if (erro == null) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      setState(() {
        _loading = false;
        _erro = erro;
      });
    }
  }

  Future<void> _sair() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Defina sua nova senha',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sua senha atual é temporária. Escolha uma nova senha para continuar.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _atual,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha atual (temporária)'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha atual' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nova,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nova senha (mínimo 8 caracteres)'),
                    validator: (v) => (v == null || v.length < 8) ? 'A nova senha deve ter ao menos 8 caracteres' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmacao,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirme a nova senha'),
                    validator: (v) => v != _nova.text ? 'As senhas não coincidem' : null,
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Text(_erro!, style: TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _enviar,
                    child: _loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Alterar senha'),
                  ),
                  TextButton(onPressed: _loading ? null : _sair, child: const Text('Sair')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

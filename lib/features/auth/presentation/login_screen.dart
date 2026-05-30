import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/grid_background.dart';
import '../../../core/network/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoginMode = true;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  
  // NOVOS CONTROLADORES
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text;
      final password = _passwordController.text;
      final name = _nameController.text;
      final phone = _phoneController.text;
      final cpf = _cpfController.text;

      if (_isLoginMode) {
        bool success = AuthService.login(email, password);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Autenticado com sucesso!'), backgroundColor: AppColors.primaryGold),
          );
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: Usuário não cadastrado ou senha incorreta!'), backgroundColor: Colors.redAccent),
          );
        }
      } else {
        // ENVIANDO OS NOVOS CAMPOS PARA O SERVIÇO
        bool success = AuthService.register(
          name: name,
          email: email,
          password: password,
          phone: phone,
          cpf: cpf,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conta criada! Faça o login para entrar.'), backgroundColor: Colors.green),
          );
          setState(() {
            _isLoginMode = true;
          });
          _formKey.currentState!.reset();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: Este e-mail já está cadastrado!'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridBackground(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(40.0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.gridLine),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'VIZION',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 6, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Center(child: Container(width: 40, height: 2, color: AppColors.primaryGold)),
                    const SizedBox(height: 16),
                    Text(
                      _isLoginMode ? 'Acesse sua conta corporativa' : 'Crie sua credencial de acesso',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 32),

                    // Campo Nome (Apenas no Cadastro)
                    if (!_isLoginMode) ...[
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputStyle('NOME COMPLETO'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Insira seu nome.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      // NOVO CAMPO: CPF
                      TextFormField(
                        controller: _cpfController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: _inputStyle('CPF (APENAS NÚMEROS)'),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'O CPF é obrigatório.';
                          if (value.length < 11) return 'O CPF deve conter 11 dígitos.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // NOVO CAMPO: TELEFONE
                      TextFormField(
                        controller: _phoneController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.phone,
                        decoration: _inputStyle('TELEFONE / WHATSAPP'),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'O telefone é obrigatório.';
                          if (value.length < 10) return 'Insira um telefone válido com DDD.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Campo de E-mail (Ambos os modos)
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputStyle('E-MAIL'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'O e-mail é obrigatório.';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Insira um e-mail válido.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Campo de Senha (Ambos os modos)
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle('SENHA'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'A senha é obrigatória.';
                        if (value.length < 6) return 'A senha deve conter pelo menos 6 caracteres.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Campo Confirmar Senha (Apenas no Cadastro)
                    if (!_isLoginMode) ...[
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputStyle('CONFIRMAR SENHA'),
                        validator: (value) {
                          if (value != _passwordController.text) return 'As senhas não coincidem.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      child: Text(_isLoginMode ? 'ENTRAR' : 'REGISTRAR CONTA', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_isLoginMode ? 'Não tem uma conta?' : 'Já possui cadastro?', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLoginMode = !_isLoginMode;
                            });
                            _formKey.currentState?.reset();
                          },
                          child: Text(_isLoginMode ? 'Criar Conta' : 'Fazer Login', style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 2),
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gridLine)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryGold)),
      errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 2)),
    );
  }
}

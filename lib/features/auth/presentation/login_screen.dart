import 'dart:async';
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
  bool _isLoading = false;
  bool _show2FA = false;
  int _timerSeconds = 30;
  Timer? _countdownTimer;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();
  
  // 2FA Controllers
  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    _countdownTimer?.cancel();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _start2FATimer() {
    setState(() {
      _timerSeconds = 30;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() {
          _timerSeconds--;
        });
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final email = _emailController.text;
      final password = _passwordController.text;
      final name = _nameController.text;
      final phone = _phoneController.text;
      final cpf = _cpfController.text;

      try {
        if (_isLoginMode) {
          bool success = await AuthService.login(email, password);

          if (success) {
            // Trigger 2FA step for corporate accounts
            setState(() {
              _isLoading = false;
              _show2FA = true;
            });
            _start2FATimer();
            // Clear code inputs
            for (var c in _codeControllers) {
              c.clear();
            }
            // Focus first digit
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                FocusScope.of(context).requestFocus(_focusNodes[0]);
              }
            });
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('E-mail ou senha incorretos.'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } else {
          bool success = await AuthService.register(
            name: name,
            email: email,
            password: password,
            phone: phone,
            cpf: cpf,
          );

          if (success) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conta criada! Faça o login para entrar.'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              setState(() {
                _isLoginMode = true;
              });
              _formKey.currentState!.reset();
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Erro: E-mail já cadastrado ou CPF inválido.'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro de rede: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted && !_show2FA) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _verify2FA() {
    String code = _codeControllers.map((c) => c.text).join();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira o código de 6 dígitos.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Accept any code for simulation (e.g. 123456 or other)
    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Autenticado com sucesso! Bem-vindo, ${AuthService.nome}!'),
            backgroundColor: AppColors.primaryGold,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    });
  }

  void _loginWithGoogle() {
    setState(() {
      _isLoading = true;
    });
    // Simulate google login -> redirects to 2FA for corporate profile
    Future.delayed(const Duration(milliseconds: 1000), () async {
      // Connect as the default test contractor
      bool success = await AuthService.login('f@g.com', '123456');
      if (success) {
        setState(() {
          _isLoading = false;
          _show2FA = true;
        });
        _start2FATimer();
        for (var c in _codeControllers) {
          c.clear();
        }
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            FocusScope.of(context).requestFocus(_focusNodes[0]);
          }
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _show2FA ? _build2FACard() : _buildLoginCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      key: const ValueKey('login_card'),
      constraints: const BoxConstraints(maxWidth: 400),
      width: double.infinity,
      padding: const EdgeInsets.all(36.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gridLine, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo Vizion
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.blur_on_outlined, color: AppColors.primaryGold, size: 36),
                const SizedBox(width: 8),
                const Text(
                  'VIZION',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 50,
                height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryGold, Colors.orangeAccent],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isLoginMode ? 'Acesse o portal corporativo' : 'Crie sua credencial de acesso',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 28),

            // Cadastro fields
            if (!_isLoginMode) ...[
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputStyle('NOME COMPLETO', Icons.person_outline),
                validator: (value) => value == null || value.trim().isEmpty ? 'Insira seu nome.' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _cpfController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: _inputStyle('CPF (APENAS NÚMEROS)', Icons.badge_outlined),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'O CPF é obrigatório.';
                  if (value.replaceAll(RegExp(r'\D'), '').length < 11) return 'CPF inválido.';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: _inputStyle('TELEFONE / WHATSAPP', Icons.phone_android_outlined),
                validator: (value) => value == null || value.isEmpty ? 'Telefone obrigatório.' : null,
              ),
              const SizedBox(height: 16),
            ],

            // E-mail
            TextFormField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: _inputStyle('E-MAIL CORPORATIVO', Icons.email_outlined),
              validator: (value) {
                if (value == null || value.isEmpty) return 'O e-mail é obrigatório.';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Insira um e-mail válido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Senha
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: _inputStyle('SENHA DE ACESSO', Icons.lock_outline),
              validator: (value) => value == null || value.isEmpty ? 'A senha é obrigatória.' : null,
            ),
            const SizedBox(height: 16),

            // Confirmar Senha (Apenas no Cadastro)
            if (!_isLoginMode) ...[
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputStyle('CONFIRMAR SENHA', Icons.lock_clock_outlined),
                validator: (value) {
                  if (value != _passwordController.text) return 'As senhas não coincidem.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 4,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                    )
                  : Text(
                      _isLoginMode ? 'ENTRAR COM CREDENCIAIS' : 'REGISTRAR CONTA',
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13),
                    ),
            ),
            
            if (_isLoginMode) ...[
              const SizedBox(height: 16),
              // Separador
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.gridLine, thickness: 1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('OU', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ),
                  Expanded(child: Divider(color: AppColors.gridLine, thickness: 1)),
                ],
              ),
              const SizedBox(height: 16),

              // Login Google
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _loginWithGoogle,
                icon: Image.network(
                  'https://img.icons8.com/color/48/google-logo.png',
                  height: 20,
                  width: 20,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.white),
                ),
                label: const Text(
                  'ENTRAR COM O GOOGLE',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.gridLine, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isLoginMode ? 'Não tem uma conta?' : 'Já possui cadastro?',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                          });
                          _formKey.currentState?.reset();
                        },
                  child: Text(
                    _isLoginMode ? 'Criar Conta' : 'Fazer Login',
                    style: const TextStyle(
                      color: AppColors.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _build2FACard() {
    return Container(
      key: const ValueKey('2fa_card'),
      constraints: const BoxConstraints(maxWidth: 400),
      width: double.infinity,
      padding: const EdgeInsets.all(36.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGold.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.security_outlined, color: AppColors.primaryGold, size: 54),
          const SizedBox(height: 16),
          const Text(
            'Verificação de Segurança',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Insira o código gerado pelo Google Authenticator no seu dispositivo móvel.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 32),

          // Digits Inputs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 44,
                child: TextFormField(
                  controller: _codeControllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.primaryGold, fontSize: 20, fontWeight: FontWeight.bold),
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  decoration: InputDecoration(
                    counterText: '',
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.gridLine),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.primaryGold, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 5) {
                      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
                    }
                    if (value.isEmpty && index > 0) {
                      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
                    }
                    if (value.isNotEmpty && index == 5) {
                      _verify2FA();
                    }
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.textSecondary, size: 16),
              const SizedBox(width: 6),
              Text(
                _timerSeconds > 0
                    ? 'O código expira em ${_timerSeconds}s'
                    : 'Código expirado. Reabra o app autenticador.',
                style: TextStyle(
                  color: _timerSeconds > 10 ? AppColors.textSecondary : Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _isLoading ? null : _verify2FA,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                  )
                : const Text(
                    'VERIFICAR E ENTRAR',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _show2FA = false;
                    });
                  },
            child: const Text('Voltar para o Login', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 2),
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gridLine)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryGold)),
      errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 2)),
    );
  }
}

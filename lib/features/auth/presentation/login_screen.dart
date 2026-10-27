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
  bool _obscurePassword = true;
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
  final List<TextEditingController> _codeControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
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
            setState(() {
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Autenticado com sucesso! Bem-vindo, ${AuthService.nome}!',
                  ),
                  backgroundColor: AppColors.goldFill,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.pushReplacementNamed(
                context,
                AuthService.mustChangePassword ? '/trocar-senha' : '/dashboard',
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('E-mail ou senha incorretos.'),
                  backgroundColor: AppColors.danger,
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
                SnackBar(
                  content: Text('Conta criada! Faça o login para entrar.'),
                  backgroundColor: AppColors.success,
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
                SnackBar(
                  content: Text('Erro: E-mail já cadastrado ou CPF inválido.'),
                  backgroundColor: AppColors.danger,
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
              backgroundColor: AppColors.danger,
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
        SnackBar(
          content: Text('Por favor, insira o código de 6 dígitos.'),
          backgroundColor: AppColors.danger,
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
            content: Text(
              'Autenticado com sucesso! Bem-vindo, ${AuthService.nome}!',
            ),
            backgroundColor: AppColors.goldFill,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 24.0,
            ),
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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gridLine, width: 1.5),
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
                Image.asset(
                  'assets/logo.png',
                  height: 38,
                  width: 38,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.blur_on_outlined,
                      color: AppColors.primaryGold,
                      size: 38,
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  'VIZION',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryGold, AppColors.warning],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Acesse o portal corporativo',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 28),

            // E-mail
            TextFormField(
              controller: _emailController,
              style: TextStyle(color: AppColors.textPrimary),
              keyboardType: TextInputType.emailAddress,
              decoration: _inputStyle(
                'E-mail corporativo',
                Icons.email_outlined,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'O e-mail é obrigatório.';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return 'Insira um e-mail válido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Senha
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: _inputStyle(
                'Senha de acesso',
                Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _obscurePassword
                        ? AppColors.textSecondary
                        : AppColors.primaryGold,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'A senha é obrigatória.'
                  : null,
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldFill,
                foregroundColor: AppColors.onGold,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.onGold,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Entrar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                        fontSize: 13,
                      ),
                    ),
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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.primaryGold.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.security_outlined,
            color: AppColors.primaryGold,
            size: 54,
          ),
          const SizedBox(height: 16),
          Text(
            'Verificação de Segurança',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
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
                  style: TextStyle(
                    color: AppColors.primaryGold,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  decoration: InputDecoration(
                    counterText: '',
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.gridLine),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.primaryGold,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 5) {
                      FocusScope.of(
                        context,
                      ).requestFocus(_focusNodes[index + 1]);
                    }
                    if (value.isEmpty && index > 0) {
                      FocusScope.of(
                        context,
                      ).requestFocus(_focusNodes[index - 1]);
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
              Icon(
                Icons.timer_outlined,
                color: AppColors.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _timerSeconds > 0
                    ? 'O código expira em ${_timerSeconds}s'
                    : 'Código expirado.',
                style: TextStyle(
                  color: _timerSeconds > 10
                      ? AppColors.textSecondary
                      : AppColors.danger,
                  fontSize: 12,
                ),
              ),
              if (_timerSeconds == 0) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _start2FATimer,
                  child: Text(
                    'Reenviar',
                    style: TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _isLoading ? null : _verify2FA,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldFill,
              foregroundColor: AppColors.onGold,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.onGold,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'VERIFICAR E ENTRAR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
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
            child: Text(
              'Voltar para o Login',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // Campos no padrão do design system (caixa de 4 px, foco dourado): o estilo vem do tema.
  InputDecoration _inputStyle(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      errorStyle: TextStyle(color: AppColors.danger, fontSize: 12),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
      suffixIcon: suffixIcon,
    );
  }
}

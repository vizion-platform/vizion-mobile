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
      backgroundColor: AppColors.surface,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _show2FA
            ? GridBackground(
                key: const ValueKey('2fa_bg'),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 24.0,
                    ),
                    child: _build2FACard(),
                  ),
                ),
              )
            : _buildLoginPage(),
      ),
    );
  }

  Widget _buildLoginPage() {
    final media = MediaQuery.of(context);
    final wide = media.size.width >= 780;
    final form = _buildLoginForm();

    return Stack(
      key: const ValueKey('login_page'),
      children: [
        Positioned.fill(
          child: wide
              ? Row(
                  children: [
                    Expanded(flex: 112, child: _buildHero(expanded: true)),
                    Expanded(
                      flex: 88,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: form,
                        ),
                      ),
                    ),
                  ],
                )
              : _buildMobileLogin(media, form),
        ),
        Positioned(
          top: media.padding.top + 12,
          right: 16,
          child: _buildThemeButton(),
        ),
      ],
    );
  }

  /// Celular: a obra ocupa a tela inteira e o formulário sobe como uma folha
  /// ancorada embaixo (alcance do polegar), sem espremer imagem e campos juntos.
  Widget _buildMobileLogin(MediaQueryData media, Widget form) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/obra_background.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFF15221E)),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xD1081410), Color(0x66081410), Color(0xB8040B09)],
              stops: [0, 0.5, 1],
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        media.padding.top + 20,
                        72,
                        0,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.blur_on_outlined,
                                color: AppColors.primaryGold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'VIZION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Controle total da sua obra, do canteiro ao escritório.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  height: 1.15,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: 52,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: AppColors.goldFill,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        28,
                        24,
                        24 + media.padding.bottom,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: form,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeButton() {
    final dark = AppTheme.isDark;
    return Material(
      color: AppColors.surface.withValues(alpha: 0.9),
      shape: CircleBorder(side: BorderSide(color: AppColors.gridLine)),
      child: IconButton(
        tooltip: dark ? 'Usar tema claro' : 'Usar tema escuro',
        icon: Icon(
          dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          color: AppColors.textPrimary,
          size: 20,
        ),
        onPressed: () => AppTheme.setDark(!dark),
      ),
    );
  }

  Widget _buildHero({required bool expanded}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/obra_background.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFF15221E)),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xD6081410), Color(0x73081410), Color(0xC2081410)],
              stops: [0, 0.58, 1],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.center,
              colors: [Color(0xC7040B09), Color(0x00040B09)],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            expanded ? 56 : 24,
            24,
            expanded ? 72 : 24,
            expanded ? 64 : 44,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: expanded ? 44 : 36,
                    height: expanded ? 44 : 36,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(expanded ? 14 : 11),
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.blur_on_outlined,
                        color: AppColors.primaryGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'VIZION',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: expanded ? 20 : 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
              SizedBox(height: expanded ? 24 : 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  'Controle total da sua obra, do canteiro ao escritório.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: expanded ? 40 : 24,
                    fontWeight: FontWeight.w600,
                    height: 1.13,
                    letterSpacing: -1,
                  ),
                ),
              ),
              SizedBox(height: expanded ? 28 : 16),
              Container(
                width: expanded ? 72 : 52,
                height: expanded ? 4 : 3,
                decoration: BoxDecoration(
                  color: AppColors.goldFill,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
        // Curva que "encaixa" o painel do formulário na imagem.
        Positioned(
          left: expanded ? null : -24,
          right: expanded ? -1 : -24,
          top: expanded ? -40 : null,
          bottom: expanded ? -40 : -1,
          width: expanded ? 90 : null,
          height: expanded ? null : 36,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: expanded
                  ? const BorderRadius.horizontal(left: Radius.circular(90))
                  : const BorderRadius.vertical(top: Radius.circular(36)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return ConstrainedBox(
      key: const ValueKey('login_card'),
      constraints: const BoxConstraints(maxWidth: 390),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bem-vindo de volta',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Entre para acompanhar cada detalhe da sua operação.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            _fieldLabel('E-mail'),
            TextFormField(
              controller: _emailController,
              style: TextStyle(color: AppColors.textPrimary),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: _inputStyle('voce@empresa.com'),
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
            const SizedBox(height: 20),
            _fieldLabel('Senha'),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: AppColors.textPrimary),
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) {
                if (!_isLoading) _submitForm();
              },
              decoration: _inputStyle(
                'Sua senha',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'A senha é obrigatória.'
                  : null,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldFill,
                  foregroundColor: AppColors.onGold,
                  disabledBackgroundColor:
                      AppColors.goldFill.withValues(alpha: 0.68),
                  shape: const StadiumBorder(),
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
                        'Entrar na plataforma',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

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

  // Campos no padrão do desktop: rótulo acima, caixa de 14 px, foco dourado.
  InputDecoration _inputStyle(String hint, {Widget? suffixIcon}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textSecondary),
      errorStyle: TextStyle(color: AppColors.danger, fontSize: 12),
      suffixIcon: suffixIcon,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: border(AppColors.gridLine),
      focusedBorder: border(AppColors.goldFill, 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.5),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tokens do design system VIZION, os mesmos do desktop (frontend/src/styles.scss):
/// dourado como único destaque, neutros zinc, raio de 4–6 px, sem sombras, Inter.
class AppPalette {
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color gold;
  final Color goldSoft;
  final Color success;
  final Color warning;
  final Color danger;

  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.gold,
    required this.goldSoft,
    required this.success,
    required this.warning,
    required this.danger,
  });

  /// Tema claro do desktop (padrão): --app-bg #fffdf6, superfícies brancas, borda #edebe3.
  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFFFFDF6),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFFF9E8),
    border: Color(0xFFEDEBE3),
    text: Color(0xFF18181B),
    textMuted: Color(0xFF71717A),
    // goldenrod escuro (#B8860B) mantém contraste em texto/ícones sobre fundo claro.
    gold: Color(0xFFB8860B),
    goldSoft: Color(0x24DAA520),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    danger: Color(0xFFB91C1C),
  );

  /// Tema escuro do desktop: --app-bg #09090b, superfície #18181b, borda #27272a.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF09090B),
    surface: Color(0xFF18181B),
    surfaceAlt: Color(0xFF27272A),
    border: Color(0xFF27272A),
    text: Color(0xFFF4F4F5),
    textMuted: Color(0xFFA1A1AA),
    gold: Color(0xFFDAA520),
    goldSoft: Color(0x24DAA520),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
  );
}

/// Cores do tema ativo. São getters (não `const`): mudam quando o usuário troca claro/escuro.
class AppColors {
  static AppPalette get _p => AppTheme.palette;

  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get surfaceAlt => _p.surfaceAlt;
  static Color get primaryGold => _p.gold;
  static Color get goldSoft => _p.goldSoft;
  static Color get textPrimary => _p.text;
  static Color get textSecondary => _p.textMuted;
  static Color get gridLine => _p.border;
  static Color get success => _p.success;
  static Color get warning => _p.warning;
  static Color get danger => _p.danger;

  /// Preenchimento dourado (botões primários) e o texto sobre ele: iguais nos dois temas.
  static const Color goldFill = Color(0xFFDAA520);
  static const Color onGold = Color(0xFF09090B);
}

/// Raios do design system: padrão 4 px, máximo 6 px (círculo só para avatar).
class AppRadius {
  static const double sm = 4;
  static const double lg = 6;
  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get control => BorderRadius.circular(sm);
}

class AppTheme {
  static const String _prefsKey = 'vizion_theme';

  /// Padrão claro, como no desktop; a escolha do usuário é lembrada no aparelho.
  static final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool get isDark => mode.value == ThemeMode.dark;
  static AppPalette get palette => isDark ? AppPalette.dark : AppPalette.light;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mode.value = prefs.getString(_prefsKey) == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      mode.value = ThemeMode.light;
    }
  }

  static Future<void> setDark(bool dark) async {
    mode.value = dark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, dark ? 'dark' : 'light');
    } catch (_) {}
    _rebuildAll();
  }

  static const String _fontScaleKey = 'vizion_font_scale';

  /// Opções de tamanho da letra da acessibilidade (perfil). 1.0 é o tamanho padrão.
  static const List<({double escala, String rotulo})> opcoesFonte = [
    (escala: 0.9, rotulo: 'Menor'),
    (escala: 1.0, rotulo: 'Padrão'),
    (escala: 1.15, rotulo: 'Maior'),
    (escala: 1.3, rotulo: 'Muito maior'),
  ];

  /// Multiplicador aplicado a todo texto do app (via MediaQuery em main.dart).
  static final ValueNotifier<double> fontScale = ValueNotifier<double>(1.0);

  static Future<void> loadFontScale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salvo = prefs.getDouble(_fontScaleKey) ?? 1.0;
      fontScale.value = opcoesFonte.any((o) => o.escala == salvo) ? salvo : 1.0;
    } catch (_) {
      fontScale.value = 1.0;
    }
  }

  static Future<void> setFontScale(double escala) async {
    fontScale.value = escala;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontScaleKey, escala);
    } catch (_) {}
  }

  static const String _boldTextKey = 'vizion_bold_text';
  static const String _reduceMotionKey = 'vizion_reduce_motion';

  /// Texto em negrito em todo o app (somado à preferência de negrito do sistema).
  static final ValueNotifier<bool> boldText = ValueNotifier<bool>(false);

  /// Remove animações e transições (somado à preferência "remover animações" do sistema).
  static final ValueNotifier<bool> reduceMotion = ValueNotifier<bool>(false);

  static Future<void> loadAccessibility() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      boldText.value = prefs.getBool(_boldTextKey) ?? false;
      reduceMotion.value = prefs.getBool(_reduceMotionKey) ?? false;
    } catch (_) {
      boldText.value = false;
      reduceMotion.value = false;
    }
  }

  static Future<void> setBoldText(bool ativo) async {
    boldText.value = ativo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_boldTextKey, ativo);
    } catch (_) {}
  }

  static Future<void> setReduceMotion(bool ativo) async {
    reduceMotion.value = ativo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_reduceMotionKey, ativo);
    } catch (_) {}
  }

  /// Volta tamanho da letra, negrito e animações ao padrão (o tema claro/escuro não muda).
  static Future<void> restaurarAcessibilidade() async {
    await setFontScale(1.0);
    await setBoldText(false);
    await setReduceMotion(false);
  }

  static bool get acessibilidadePadrao =>
      fontScale.value == 1.0 && !boldText.value && !reduceMotion.value;

  /// As telas leem AppColors diretamente (sem depender do Theme): força o rebuild da árvore inteira.
  static void _rebuildAll() {
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
  }

  static ThemeData get theme => _build(palette);

  // Compatibilidade com código antigo.
  static ThemeData get darkTheme => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    const family = 'Inter';
    final base = p.brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();

    TextStyle t(double size, FontWeight weight, {Color? color, double? height}) =>
        TextStyle(fontFamily: family, fontSize: size, fontWeight: weight, color: color ?? p.text, height: height);

    // Escala do guia: título 24–30, subtítulo 18, texto 14, auxiliar 12; peso em vez de tamanho.
    final textTheme = base.textTheme.copyWith(
      headlineLarge: t(30, FontWeight.w700, height: 1.2),
      headlineMedium: t(24, FontWeight.w700, height: 1.25),
      titleLarge: t(18, FontWeight.w600),
      titleMedium: t(16, FontWeight.w600),
      titleSmall: t(14, FontWeight.w600),
      bodyLarge: t(14, FontWeight.w400, height: 1.5),
      bodyMedium: t(14, FontWeight.w400, height: 1.5),
      bodySmall: t(12, FontWeight.w400, color: p.textMuted),
      labelLarge: t(14, FontWeight.w600),
      labelMedium: t(12, FontWeight.w500, color: p.textMuted),
      labelSmall: t(12, FontWeight.w500, color: p.textMuted),
    );

    OutlineInputBorder border(Color c, {double w = 1}) => OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      brightness: p.brightness,
      scaffoldBackgroundColor: p.background,
      primaryColor: p.gold,
      canvasColor: p.surface,
      dividerColor: p.border,
      splashFactory: InkRipple.splashFactory,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      colorScheme: ColorScheme(
        brightness: p.brightness,
        primary: p.gold,
        onPrimary: AppColors.onGold,
        secondary: p.gold,
        onSecondary: AppColors.onGold,
        error: p.danger,
        onError: Colors.white,
        surface: p.surface,
        onSurface: p.text,
        outline: p.border,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: p.border)),
        titleTextStyle: t(18, FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card, side: BorderSide(color: p.border)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card, side: BorderSide(color: p.border)),
        titleTextStyle: t(18, FontWeight.w600),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          side: BorderSide(color: p.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        hintStyle: t(14, FontWeight.w400, color: p.textMuted),
        labelStyle: t(14, FontWeight.w500, color: p.textMuted),
        floatingLabelStyle: t(12, FontWeight.w600, color: p.gold),
        border: border(p.border),
        enabledBorder: border(p.border),
        focusedBorder: border(AppColors.goldFill, w: 1.5),
        errorBorder: border(p.danger),
        focusedErrorBorder: border(p.danger, w: 1.5),
      ),
      // Botão primário: dourado com texto escuro (como o desktop); sem sombra.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.goldFill,
          foregroundColor: AppColors.onGold,
          disabledBackgroundColor: p.surfaceAlt,
          disabledForegroundColor: p.textMuted,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 44),
          textStyle: t(14, FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.goldFill,
          foregroundColor: AppColors.onGold,
          elevation: 0,
          minimumSize: const Size(0, 44),
          textStyle: t(14, FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          side: BorderSide(color: p.border),
          minimumSize: const Size(0, 44),
          textStyle: t(14, FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.gold,
          textStyle: t(14, FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      iconTheme: IconThemeData(color: p.text),
      listTileTheme: ListTileThemeData(
        iconColor: p.textMuted,
        textColor: p.text,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        selectedColor: p.goldSoft,
        side: BorderSide(color: p.border),
        labelStyle: t(12, FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.goldFill : p.textMuted),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.goldSoft : p.surfaceAlt),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.goldFill, linearTrackColor: p.surfaceAlt),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.brightness == Brightness.dark ? p.surfaceAlt : const Color(0xFF18181B),
        contentTextStyle: t(14, FontWeight.w500, color: const Color(0xFFF4F4F5)),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.gold,
        unselectedItemColor: p.textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: t(12, FontWeight.w600),
        unselectedLabelStyle: t(12, FontWeight.w500),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.goldFill,
        foregroundColor: AppColors.onGold,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
    );
  }
}

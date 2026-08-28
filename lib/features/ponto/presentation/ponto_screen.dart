import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/ponto_record_model.dart';
import '../data/ponto_service.dart';
import 'widgets/slide_to_punch_button.dart';
import 'widgets/ponto_timeline_widget.dart';
import 'widgets/ponto_punch_dialog.dart';
import 'widgets/espelho_ponto_tab.dart';

class PontoScreen extends StatefulWidget {
  final VoidCallback? onBackTap;

  const PontoScreen({super.key, this.onBackTap});

  @override
  State<PontoScreen> createState() => _PontoScreenState();
}

class _PontoScreenState extends State<PontoScreen> {
  int _activeTabIndex = 0; // 0 = Bater Ponto, 1 = Espelho de Ponto
  late DateTime _currentTime;
  Timer? _clockTimer;
  PontoDay? _todayPonto;
  bool _isLoading = true;
  bool _isPunching = false;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    // Live clock timer update with seconds every 1 second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
    _loadTodayPonto();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTodayPonto() async {
    final today = await PontoService.getTodayPonto();
    if (mounted) {
      setState(() {
        _todayPonto = today;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSlideToPunch() async {
    if (_todayPonto == null) return;
    final nextType = PontoService.getNextPunchType(_todayPonto!);
    if (nextType == null) return;

    setState(() => _isPunching = true);

    try {
      final result = await PontoService.registerPunch(
        type: nextType,
        location: 'Canteiro Res. Bella Vista • GPS Validado (-23.5505, -46.6333)',
      );

      if (mounted) {
        setState(() {
          _todayPonto = result.day;
          _isPunching = false;
        });

        // Show receipt confirmation dialog
        showDialog(
          context: context,
          builder: (context) => PontoPunchReceiptDialog(punch: result.punch),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPunching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao registrar ponto: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatTimeWithSeconds(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatFullDate(DateTime dt) {
    const weekdays = [
      'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira',
      'Sexta-feira', 'Sábado', 'Domingo'
    ];
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];

    final weekday = weekdays[dt.weekday - 1];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;

    return '$weekday, $day de $month de $year';
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 360;
    final double horizontalPadding = isSmallScreen ? 14.0 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Tab Navigation: [ Bater Ponto | Espelho de Ponto ]
            _buildTabHeader(horizontalPadding, isSmallScreen),

            // Body content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _activeTabIndex == 0
                    ? _buildBaterPontoTab(horizontalPadding, isSmallScreen)
                    : Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12.0),
                        child: const EspelhoPontoTab(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top Tab Switcher Segmented Control
  Widget _buildTabHeader(double horizontalPadding, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.gridLine, width: 1.2),
        ),
      ),
      child: Row(
        children: [
          if (widget.onBackTap != null) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: widget.onBackTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gridLine),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.primaryGold,
                    size: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gridLine),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      title: 'Bater Ponto',
                      icon: Icons.fingerprint_rounded,
                      index: 0,
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildTabButton(
                      title: 'Espelho de Ponto',
                      icon: Icons.receipt_long_rounded,
                      index: 1,
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required int index,
    required bool isSmallScreen,
  }) {
    final isSelected = _activeTabIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryGold.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isSmallScreen ? 14 : 16,
              color: isSelected ? Colors.black : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textSecondary,
                    fontSize: isSmallScreen ? 11 : 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Bater Ponto Tab Content
  Widget _buildBaterPontoTab(double horizontalPadding, bool isSmallScreen) {
    if (_isLoading || _todayPonto == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    final today = _todayPonto!;
    final nextPunchType = PontoService.getNextPunchType(today);
    final workedMin = today.workedMinutes;
    final double progress = (workedMin / 480.0).clamp(0.0, 1.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Live Clock with seconds on top-left
          _buildLiveClockHeader(isSmallScreen),
          const SizedBox(height: 18),

          // 2. Horas Trabalhadas
          _buildWorkedHoursCard(today, progress, isSmallScreen),
          const SizedBox(height: 18),

          // 3. Linha do Tempo
          PontoTimelineWidget(
            todayDay: today,
            nextPunchType: nextPunchType,
          ),
          const SizedBox(height: 20),

          // 4. Rodapé: Botão deslizante elegante padrão Vizion
          SlideToPunchButton(
            nextPunchType: nextPunchType,
            isLoading: _isPunching,
            onConfirmed: _handleSlideToPunch,
          ),
          const SizedBox(height: 12),

          // Footer Info & GPS status
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppColors.textSecondary,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Registro digital protegido • SHA-256',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// 1. Live Digital Clock with Seconds on Top-Left
  Widget _buildLiveClockHeader(bool isSmallScreen) {
    final String timeStr = _formatTimeWithSeconds(_currentTime);
    final String dateStr = _formatFullDate(_currentTime);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HORA ATUAL OFICIAL',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              // Digital Live Clock with Seconds
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  timeStr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 28 : 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateStr,
                style: TextStyle(
                  color: AppColors.primaryGold,
                  fontSize: isSmallScreen ? 11 : 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // GPS status chip (Vizion standard styling)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryGold.withValues(alpha: 0.4),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, color: AppColors.primaryGold, size: 11),
              SizedBox(width: 3),
              Text(
                'GPS Ativo',
                style: TextStyle(
                  color: AppColors.primaryGold,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 2. Horas Trabalhadas Card
  Widget _buildWorkedHoursCard(PontoDay today, double progress, bool isSmallScreen) {
    final int workedMin = today.workedMinutes;
    final int h = workedMin ~/ 60;
    final int m = workedMin % 60;
    final String workedFormatted = '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
    final int percent = (progress * 100).toInt();

    final String statusText;

    if (today.saida != null) {
      statusText = 'Jornada Finalizada';
    } else if (today.retornoAlmoco != null) {
      statusText = 'Turno Tarde';
    } else if (today.saidaAlmoco != null) {
      statusText = 'Intervalo Almoço';
    } else if (today.entrada != null) {
      statusText = 'Turno Manhã';
    } else {
      statusText = 'Aguardando Entrada';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gridLine, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.primaryGold, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Horas Trabalhadas Hoje',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Large Worked Hours value
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        workedFormatted,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 26 : 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '/ 08h 00m meta',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                style: TextStyle(
                  color: AppColors.primaryGold,
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF1E1E1E),
              color: AppColors.primaryGold,
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 10),

          // Bottom helper row
          Row(
            children: [
              Expanded(
                child: Text(
                  today.entrada != null
                      ? 'Início às ${today.entrada!.formattedTimeOnlyMin}'
                      : 'Entrada não registrada',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Previsão saída: 17h',
                style: TextStyle(
                  color: AppColors.primaryGold,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

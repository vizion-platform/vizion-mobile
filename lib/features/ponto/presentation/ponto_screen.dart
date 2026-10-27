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
      final result = await PontoService.registerPunch(type: nextType);

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
            content: Text(e is PontoException ? e.message : 'Erro ao registrar ponto. Tente novamente.'),
            backgroundColor: AppColors.danger,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Tab Navigation: [ Bater Ponto | Espelho de Ponto ]
            _buildTabHeader(),

            // Body content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _activeTabIndex == 0
                    ? _buildBaterPontoTab()
                    : const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                        child: EspelhoPontoTab(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top Tab Switcher Segmented Control
  Widget _buildTabHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
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
                borderRadius: AppRadius.control,
                onTap: widget.onBackTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.control,
                    border: Border.all(color: AppColors.gridLine),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.primaryGold,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.gridLine),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      title: 'Bater Ponto',
                      icon: Icons.fingerprint_rounded,
                      index: 0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildTabButton(
                      title: 'Espelho de Ponto',
                      icon: Icons.receipt_long_rounded,
                      index: 1,
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
  }) {
    final isSelected = _activeTabIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.goldFill : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.onGold : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.onGold : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Bater Ponto Tab Content
  Widget _buildBaterPontoTab() {
    if (_isLoading || _todayPonto == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    final today = _todayPonto!;
    final nextPunchType = PontoService.getNextPunchType(today);
    final workedMin = today.workedMinutes;
    final double progress = (workedMin / 480.0).clamp(0.0, 1.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Live Clock with seconds on top-left
          _buildLiveClockHeader(),
          const SizedBox(height: 20),

          // 2. Horas Trabalhadas
          _buildWorkedHoursCard(today, progress),
          const SizedBox(height: 20),

          // 3. Linha do Tempo
          PontoTimelineWidget(
            todayDay: today,
            nextPunchType: nextPunchType,
          ),
          const SizedBox(height: 24),

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
                Icon(
                  Icons.shield_outlined,
                  color: AppColors.textSecondary,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'Registro digital protegido • Criptografia SHA-256',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 1. Live Digital Clock with Seconds on Top-Left
  Widget _buildLiveClockHeader() {
    final String timeStr = _formatTimeWithSeconds(_currentTime);
    final String dateStr = _formatFullDate(_currentTime);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HORA ATUAL OFICIAL',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            // Digital Live Clock with Seconds
            Text(
              timeStr,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dateStr,
              style: TextStyle(
                color: AppColors.primaryGold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        // GPS status chip (Vizion standard styling)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.primaryGold.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_outlined, color: AppColors.primaryGold, size: 12),
              SizedBox(width: 4),
              Text(
                'Horário do servidor',
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
  Widget _buildWorkedHoursCard(PontoDay today, double progress) {
    final int workedMin = today.workedMinutes;
    final int h = workedMin ~/ 60;
    final int m = workedMin % 60;
    final String workedFormatted = '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
    final int percent = (progress * 100).toInt();

    final String statusText;

    if (today.saida != null) {
      statusText = 'Jornada Finalizada';
    } else if (today.retornoAlmoco != null) {
      statusText = 'Em Andamento (Turno Tarde)';
    } else if (today.saidaAlmoco != null) {
      statusText = 'Intervalo Almoço';
    } else if (today.entrada != null) {
      statusText = 'Em Andamento (Turno Manhã)';
    } else {
      statusText = 'Aguardando Entrada';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gridLine, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, color: AppColors.primaryGold, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Horas Trabalhadas Hoje',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: AppColors.primaryGold,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Large Worked Hours value
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                workedFormatted,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/ 08h 00m meta',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: TextStyle(
                  color: AppColors.primaryGold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceAlt,
              color: AppColors.primaryGold,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),

          // Bottom helper row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                today.entrada != null
                    ? 'Início às ${today.entrada!.formattedTimeOnlyMin}'
                    : 'Entrada ainda não registrada',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                'Previsão de saída: 17:00',
                style: TextStyle(
                  color: AppColors.primaryGold,
                  fontSize: 11,
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

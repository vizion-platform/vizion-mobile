import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/ponto_record_model.dart';
import '../../data/ponto_service.dart';
import 'ponto_punch_dialog.dart';

class EspelhoPontoTab extends StatefulWidget {
  const EspelhoPontoTab({super.key});

  @override
  State<EspelhoPontoTab> createState() => _EspelhoPontoTabState();
}

class _EspelhoPontoTabState extends State<EspelhoPontoTab> {
  late DateTime _selectedMonth;
  PontoMonthlySummary? _summary;
  bool _isLoading = true;
  String _activeFilter = 'Todos'; // 'Todos', 'Normais', 'Horas Extras', 'Incompletos', 'Folgas'

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _loadMonthSummary();
  }

  Future<void> _loadMonthSummary() async {
    setState(() => _isLoading = true);
    final summary = await PontoService.getMonthPonto(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    if (mounted) {
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _loadMonthSummary();
  }

  String _formatMonthYear(DateTime dt) {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  String _getWeekdayAbbr(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'Seg';
      case DateTime.tuesday: return 'Ter';
      case DateTime.wednesday: return 'Qua';
      case DateTime.thursday: return 'Qui';
      case DateTime.friday: return 'Sex';
      case DateTime.saturday: return 'Sáb';
      case DateTime.sunday: return 'Dom';
      default: return '';
    }
  }

  List<PontoDay> get _filteredDays {
    if (_summary == null) return [];
    return _summary!.days.where((day) {
      if (_activeFilter == 'Folgas') return day.isDayOff;
      if (day.isDayOff) return _activeFilter == 'Todos';

      if (_activeFilter == 'Horas Extras') return day.balanceMinutes > 15;
      if (_activeFilter == 'Incompletos') {
        return (day.punches.isEmpty && day.date.isBefore(DateTime.now())) ||
            (day.punches.isNotEmpty && day.saida == null);
      }
      if (_activeFilter == 'Normais') return day.statusLabel == 'Normal';
      return true;
    }).toList().reversed.toList(); // Newest first
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    if (_summary == null) {
      return const Center(
        child: Text(
          'Nenhum dado encontrado para o mês selecionado.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final summary = _summary!;
    final balanceMinutes = summary.totalBalanceMinutes;
    final isPositiveBalance = balanceMinutes >= 0;
    final balanceFormatted = summary.formatBalance(balanceMinutes);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Month Selector Navigation Bar
          _buildMonthNavigator(),
          const SizedBox(height: 18),

          // 2. Banco de Horas Metric Cards
          _buildBancoHorasCards(summary, isPositiveBalance, balanceFormatted),
          const SizedBox(height: 24),

          // 3. Filter Chips
          _buildFilterChips(),
          const SizedBox(height: 16),

          // 4. Days List Header & Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REGISTROS DIÁRIOS (${_filteredDays.length})',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Espelho de Ponto pronto para download / PDF gerado.'),
                      backgroundColor: AppColors.primaryGold,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.download_rounded, color: AppColors.primaryGold, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Exportar PDF',
                      style: TextStyle(
                        color: AppColors.primaryGold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. Daily cards
          if (_filteredDays.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gridLine),
              ),
              child: const Center(
                child: Text(
                  'Nenhum registro encontrado para este filtro.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            ..._filteredDays.map((day) => _buildDayCard(day)),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gridLine, width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
            onPressed: () => _changeMonth(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Row(
            children: [
              const Icon(Icons.calendar_month, color: AppColors.primaryGold, size: 18),
              const SizedBox(width: 8),
              Text(
                _formatMonthYear(_selectedMonth),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 24),
            onPressed: () => _changeMonth(1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildBancoHorasCards(
    PontoMonthlySummary summary,
    bool isPositiveBalance,
    String balanceFormatted,
  ) {
    final balanceColor = isPositiveBalance ? const Color(0xFF34C759) : const Color(0xFFFF3B30);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            balanceColor.withValues(alpha: 0.12),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: balanceColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SALDO DO BANCO DE HORAS',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        balanceFormatted,
                        style: TextStyle(
                          color: balanceColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isPositiveBalance ? Icons.trending_up : Icons.trending_down,
                        color: balanceColor,
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: balanceColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: balanceColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  isPositiveBalance ? 'Crédito' : 'Débito',
                  style: TextStyle(
                    color: balanceColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.gridLine, height: 1),
          const SizedBox(height: 16),

          // Sub-metrics 3 columns
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  'Trabalhadas',
                  summary.formatMinutes(summary.totalWorkedMinutes),
                  Icons.access_time_rounded,
                  AppColors.primaryGold,
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.gridLine),
              Expanded(
                child: _buildMiniMetric(
                  'Previstas',
                  summary.formatMinutes(summary.totalExpectedMinutes),
                  Icons.schedule_rounded,
                  Colors.white70,
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.gridLine),
              Expanded(
                child: _buildMiniMetric(
                  'Dias Úteis',
                  '${summary.completedDaysCount} dias',
                  Icons.event_available_rounded,
                  Colors.blueAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Todos', 'Normais', 'Horas Extras', 'Incompletos', 'Folgas'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _activeFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (val) => setState(() => _activeFilter = filter),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primaryGold.withValues(alpha: 0.25),
              checkmarkColor: AppColors.primaryGold,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primaryGold : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? AppColors.primaryGold : AppColors.gridLine,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayCard(PontoDay day) {
    final dayNum = day.date.day.toString().padLeft(2, '0');
    final monthNum = day.date.month.toString().padLeft(2, '0');
    final weekdayAbbr = _getWeekdayAbbr(day.date.weekday);
    final isWeekend = day.isDayOff;
    final isPositive = day.balanceMinutes >= 0;
    final balanceColor = isPositive ? const Color(0xFF34C759) : const Color(0xFFFF3B30);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gridLine),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: day.punches.isNotEmpty
              ? () {
                  showDialog(
                    context: context,
                    builder: (context) => PontoPunchReceiptDialog(punch: day.punches.first),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Top Row: Date, Status, and Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isWeekend ? Colors.white10 : AppColors.primaryGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$dayNum/$monthNum • $weekdayAbbr',
                            style: TextStyle(
                              color: isWeekend ? Colors.white70 : AppColors.primaryGold,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF222222),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.gridLine),
                          ),
                          child: Text(
                            day.statusLabel,
                            style: TextStyle(
                              color: isWeekend ? AppColors.textSecondary : Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (!isWeekend && day.punches.isNotEmpty)
                      Row(
                        children: [
                          Text(
                            day.formattedWorkedHours,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: balanceColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              day.formattedBalanceHours,
                              style: TextStyle(
                                color: balanceColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4 Time slots
                if (isWeekend)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      day.customNote ?? 'Descanso Semanal',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTimeSlot('Entrada', day.entrada?.formattedTimeOnlyMin ?? '--:--', day.entrada != null),
                      _buildTimeSlot('Saída Almoço', day.saidaAlmoco?.formattedTimeOnlyMin ?? '--:--', day.saidaAlmoco != null),
                      _buildTimeSlot('Volta Almoço', day.retornoAlmoco?.formattedTimeOnlyMin ?? '--:--', day.retornoAlmoco != null),
                      _buildTimeSlot('Saída', day.saida?.formattedTimeOnlyMin ?? '--:--', day.saida != null),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSlot(String label, String time, bool isRecorded) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: TextStyle(
            color: isRecorded ? Colors.white : Colors.white24,
            fontSize: 12,
            fontWeight: isRecorded ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

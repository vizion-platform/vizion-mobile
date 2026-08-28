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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 360;

    return RefreshIndicator(
      color: AppColors.primaryGold,
      backgroundColor: AppColors.surface,
      onRefresh: _loadMonthSummary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Month Selector Navigation Bar
            _buildMonthNavigator(isSmallScreen),
            const SizedBox(height: 16),

            // 2. Banco de Horas Metric Cards
            _buildBancoHorasCards(summary, isPositiveBalance, balanceFormatted, isSmallScreen),
            const SizedBox(height: 20),

            // 3. Filter Chips
            _buildFilterChips(),
            const SizedBox(height: 16),

            // 4. Days List Header & Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'REGISTROS DIÁRIOS (${_filteredDays.length})',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Espelho de Ponto pronto para exportação.'),
                        backgroundColor: AppColors.primaryGold,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.download_rounded, color: AppColors.primaryGold, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Exportar PDF',
                        style: TextStyle(
                          color: AppColors.primaryGold,
                          fontSize: isSmallScreen ? 10.5 : 11,
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
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gridLine),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.access_time_rounded, color: AppColors.textSecondary, size: 36),
                    SizedBox(height: 12),
                    Text(
                      'Nenhum registro de ponto neste mês',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Os registros serão armazenados no banco conforme os pontos forem batidos diariamente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ..._filteredDays.map((day) => _buildDayCard(day, isSmallScreen)),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthNavigator(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gridLine, width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 22),
            onPressed: () => _changeMonth(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: AppColors.primaryGold, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _formatMonthYear(_selectedMonth),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 22),
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
    bool isSmallScreen,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3), width: 1.5),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SALDO DO BANCO DE HORAS',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              balanceFormatted,
                              style: TextStyle(
                                color: AppColors.primaryGold,
                                fontSize: isSmallScreen ? 24 : 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isPositiveBalance ? Icons.trending_up : Icons.trending_down,
                          color: AppColors.primaryGold,
                          size: isSmallScreen ? 20 : 24,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35)),
                ),
                child: Text(
                  isPositiveBalance ? 'Crédito' : 'Débito',
                  style: const TextStyle(
                    color: AppColors.primaryGold,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.gridLine, height: 1),
          const SizedBox(height: 14),

          // Sub-metrics 3 columns
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  'Trabalhadas',
                  summary.formatMinutes(summary.totalWorkedMinutes),
                  Icons.access_time_rounded,
                  AppColors.primaryGold,
                  isSmallScreen,
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.gridLine),
              Expanded(
                child: _buildMiniMetric(
                  'Previstas',
                  summary.formatMinutes(summary.totalExpectedMinutes),
                  Icons.schedule_rounded,
                  Colors.white70,
                  isSmallScreen,
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.gridLine),
              Expanded(
                child: _buildMiniMetric(
                  'Dias Úteis',
                  '${summary.completedDaysCount} dias',
                  Icons.event_available_rounded,
                  AppColors.primaryGold,
                  isSmallScreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, IconData icon, Color color, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: isSmallScreen ? 8.5 : 9.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 10.5 : 12,
                fontWeight: FontWeight.bold,
              ),
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

  Widget _buildDayCard(PontoDay day, bool isSmallScreen) {
    final dayNum = day.date.day.toString().padLeft(2, '0');
    final monthNum = day.date.month.toString().padLeft(2, '0');
    final weekdayAbbr = _getWeekdayAbbr(day.date.weekday);
    final isWeekend = day.isDayOff;

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
            padding: EdgeInsets.all(isSmallScreen ? 11 : 14),
            child: Column(
              children: [
                // Top Row: Date, Status, and Total
                Row(
                  children: [
                    // Left side: Date & Status
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isWeekend ? Colors.white10 : AppColors.primaryGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$dayNum/$monthNum • $weekdayAbbr',
                              style: TextStyle(
                                color: isWeekend ? Colors.white70 : AppColors.primaryGold,
                                fontSize: isSmallScreen ? 10.5 : 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF222222),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: AppColors.gridLine),
                              ),
                              child: Text(
                                day.statusLabel,
                                style: TextStyle(
                                  color: isWeekend ? AppColors.textSecondary : Colors.white70,
                                  fontSize: isSmallScreen ? 9 : 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (!isWeekend && day.punches.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            day.formattedWorkedHours,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 11.5 : 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              day.formattedBalanceHours,
                              style: TextStyle(
                                color: AppColors.primaryGold,
                                fontSize: isSmallScreen ? 9 : 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

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
                    children: [
                      Expanded(child: _buildTimeSlot('Entrada', day.entrada?.formattedTimeOnlyMin ?? '--:--', day.entrada != null, isSmallScreen)),
                      Expanded(child: _buildTimeSlot(isSmallScreen ? 'Saída Alm.' : 'Saída Almoço', day.saidaAlmoco?.formattedTimeOnlyMin ?? '--:--', day.saidaAlmoco != null, isSmallScreen)),
                      Expanded(child: _buildTimeSlot(isSmallScreen ? 'Volta Alm.' : 'Volta Almoço', day.retornoAlmoco?.formattedTimeOnlyMin ?? '--:--', day.retornoAlmoco != null, isSmallScreen)),
                      Expanded(child: _buildTimeSlot('Saída', day.saida?.formattedTimeOnlyMin ?? '--:--', day.saida != null, isSmallScreen)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSlot(String label, String time, bool isRecorded, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: isSmallScreen ? 8.5 : 9,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            time,
            style: TextStyle(
              color: isRecorded ? Colors.white : Colors.white24,
              fontSize: isSmallScreen ? 11 : 12,
              fontWeight: isRecorded ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

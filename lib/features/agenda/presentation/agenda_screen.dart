import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_service.dart';
import '../data/agenda_service.dart';
import '../domain/agenda_task_model.dart';

class AgendaScreen extends StatefulWidget {
  final VoidCallback? onBackTap;

  const AgendaScreen({super.key, this.onBackTap});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  // Calendar Navigation State
  late DateTime _currentWeekStart; // Start date (Monday) of active week
  late DateTime _selectedDate; // Currently selected day
  DateTime? _selectedFilterDay; // Selected day filter for toggling
  String _selectedViewMode = 'Semana'; // 'Semana', 'Dia', 'Mês'
  String _activeFilter = 'Todas'; // 'Todas', 'Pendentes', 'Concluídas', 'Obra', 'Vistoria', 'Entrega', 'Segurança'

  // Task Data State
  List<AgendaTask> _allTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedFilterDay = null;
    _currentWeekStart = _getMonday(_selectedDate);
    _loadTasksData();
  }

  /// Finds Monday for the week containing the given date
  DateTime _getMonday(DateTime date) {
    final int weekday = date.weekday; // 1 = Mon, 7 = Sun
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: weekday - 1));
  }

  /// Loads tasks from storage/service
  Future<void> _loadTasksData() async {
    setState(() => _isLoading = true);
    final tasks = await AgendaService.loadTasks();
    if (mounted) {
      setState(() {
        _allTasks = tasks;
        _isLoading = false;
      });
    }
  }

  /// Saves updated tasks list to persistence
  Future<void> _saveTasksData() async {
    await AgendaService.saveTasks(_allTasks);
  }

  bool get _canModifyAgenda {
    final role = (AuthService.role ?? '').toUpperCase();
    return role == 'EMPREITEIRO' || role == 'ADMIN' || role == 'GESTOR';
  }

  /// Toggles completion status of a task
  Future<void> _toggleTaskCompletion(String id) async {
    if (!_canModifyAgenda) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apenas o Empreiteiro pode modificar status de tarefas no calendário.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final index = _allTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final task = _allTasks[index];
      setState(() {
        _allTasks[index] = task.copyWith(isCompleted: !task.isCompleted);
      });
      final updated = await AgendaService.toggleTaskCompletion(task);
      if (mounted) {
        setState(() {
          final idx = _allTasks.indexWhere((t) => t.id == id || t.id == updated.id);
          if (idx != -1) {
            _allTasks[idx] = updated;
          }
        });
      }
    }
  }

  /// Deletes a task
  Future<void> _deleteTask(String id) async {
    if (!_canModifyAgenda) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apenas o Empreiteiro pode excluir tarefas no calendário.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final index = _allTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final task = _allTasks[index];
      setState(() {
        _allTasks.removeAt(index);
      });
      await AgendaService.deleteTask(task);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarefa removida da agenda e do banco de dados.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Jumps to current week & today
  void _jumpToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _selectedDate = today;
      _currentWeekStart = _getMonday(today);
      _selectedFilterDay = null;
    });
  }

  /// Navigates week forward or backward
  void _navigateWeek(int weeksDelta) {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(Duration(days: weeksDelta * 7));
      _selectedDate = _currentWeekStart;
      _selectedFilterDay = null;
    });
  }

  /// Get 7 days for the current active week (Mon - Sun)
  List<DateTime> get _activeWeekDays {
    return List.generate(7, (i) => _currentWeekStart.add(Duration(days: i)));
  }

  /// Checks if two DateTimes fall on the exact same calendar day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Checks if a DateTime is Today
  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  /// Returns filtered list of tasks
  List<AgendaTask> get _filteredTasks {
    return _allTasks.where((task) {
      // View mode filtering
      if (_selectedViewMode == 'Dia') {
        if (!task.spansDay(_selectedDate)) return false;
      } else if (_selectedViewMode == 'Semana') {
        final weekEnd = _currentWeekStart.add(const Duration(days: 6, hours: 23, minutes: 59));
        if (task.startDate.isAfter(weekEnd) || task.endDate.isBefore(_currentWeekStart)) {
          return false;
        }
      }

      // Category / Status filter
      if (_activeFilter == 'Pendentes') return !task.isCompleted;
      if (_activeFilter == 'Concluídas') return task.isCompleted;
      if (_activeFilter != 'Todas') {
        return task.category.toLowerCase() == _activeFilter.toLowerCase();
      }

      return true;
    }).toList();
  }

  /// Gets tasks active on a specific date
  List<AgendaTask> _tasksForDate(DateTime date) {
    return _allTasks.where((t) => t.spansDay(date)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final String monthYearTitle = _formatMonthYear(_currentWeekStart);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _canModifyAgenda
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEditTaskModal(context),
              backgroundColor: const Color(0xFF4285F4),
              elevation: 6,
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              label: const Text(
                'Nova Tarefa',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Google Calendar Responsive Header
            _buildGoogleCalendarHeader(monthYearTitle),

            // 2. View Mode Switcher & Filter Chips
            _buildControlsAndFilters(),

            // 3. Dynamic Week Strip (Fully responsive on 360dp J8)
            _buildWeekStrip(),

            const SizedBox(height: 8),

            // 4. Main Calendar / Tasks Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
                  : _buildMainCalendarContent(),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Top Google Calendar Header Widget (Anti-Overflow for small screens)
  Widget _buildGoogleCalendarHeader(String monthYearTitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.gridLine, width: 1.0),
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
                    color: AppColors.surface,
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

          // Calendar Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calendar_month,
              color: Color(0xFF4285F4),
              size: 20,
            ),
          ),
          const SizedBox(width: 8),

          // Title & Month
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _canModifyAgenda ? 'Agenda Empreiteira' : 'Agenda da Obra',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  monthYearTitle,
                  style: const TextStyle(
                    color: AppColors.primaryGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // "Hoje" Button
          InkWell(
            onTap: _jumpToToday,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gridLine,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.today, size: 11, color: AppColors.primaryGold),
                  SizedBox(width: 3),
                  Text(
                    'Hoje',
                    style: TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),

          // Previous Week Arrow
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 22),
            onPressed: () => _navigateWeek(-1),
            tooltip: 'Semana Anterior',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          ),

          // Next Week Arrow
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 22),
            onPressed: () => _navigateWeek(1),
            tooltip: 'Próxima Semana',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          ),
        ],
      ),
    );
  }

  /// 2. View Mode Switcher ('Semana', 'Dia', 'Mês') & Filter Chips (Responsivo)
  Widget _buildControlsAndFilters() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 4),
      child: Column(
        children: [
          // View Switcher Bar + Counter usando Wrap para nunca quebrar no J8
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // Switcher (Semana, Dia, Mês)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gridLine),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['Semana', 'Dia', 'Mês'].map((mode) {
                    final isSelected = _selectedViewMode == mode;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedViewMode = mode),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF4285F4) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          mode,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Task summary count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.gridLine),
                ),
                child: Text(
                  '${_filteredTasks.where((t) => t.isCompleted).length}/${_filteredTasks.length} concluídas',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal Category Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                'Todas',
                'Pendentes',
                'Concluídas',
                'Obra',
                'Vistoria',
                'Entrega',
                'Segurança',
                'Manutenção',
                'Reunião',
              ].map((filter) {
                final isSelected = _activeFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _activeFilter = filter),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primaryGold.withValues(alpha: 0.25),
                    checkmarkColor: AppColors.primaryGold,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primaryGold : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryGold : AppColors.gridLine,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Dynamic Week Strip (7 Days Google Calendar Bar - Totalmente Responsivo)
  Widget _buildWeekStrip() {
    final days = _activeWeekDays;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gridLine, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: days.map((day) {
          final isSelected = _selectedFilterDay != null && _isSameDay(day, _selectedFilterDay!);
          final isTodayDate = _isToday(day);
          final dayTasks = _tasksForDate(day);
          final hasTasks = dayTasks.isNotEmpty;
          final dayAbbr = _getDayAbbreviation(day.weekday);

          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  if (_selectedFilterDay != null && _isSameDay(_selectedFilterDay!, day)) {
                    _selectedFilterDay = null;
                    _selectedDate = day;
                  } else {
                    _selectedFilterDay = day;
                    _selectedDate = day;
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4285F4).withValues(alpha: 0.2)
                      : (isTodayDate
                          ? AppColors.primaryGold.withValues(alpha: 0.12)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF4285F4)
                        : (isTodayDate ? AppColors.primaryGold : Colors.transparent),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Day abbreviation (SEG, TER...)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        dayAbbr,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF4285F4)
                              : (isTodayDate ? AppColors.primaryGold : AppColors.textSecondary),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Day Number Circle Badge
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0xFF4285F4)
                            : (isTodayDate ? AppColors.primaryGold : Colors.transparent),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: (isSelected || isTodayDate)
                                ? Colors.black
                                : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Task indicator dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: hasTasks
                          ? dayTasks.take(3).map((t) {
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: t.isCompleted ? Colors.grey : t.color,
                                ),
                              );
                            }).toList()
                          : [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.transparent,
                                ),
                              ),
                            ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 4. Main Calendar View Router
  Widget _buildMainCalendarContent() {
    if (_selectedViewMode == 'Dia') {
      return _buildDayViewContent();
    } else if (_selectedViewMode == 'Mês') {
      return _buildMonthViewContent();
    } else {
      return _buildWeekViewContent();
    }
  }

  /// 4A. Semana (Week View)
  Widget _buildWeekViewContent() {
    final tasks = _filteredTasks;

    if (tasks.isEmpty) {
      return _buildEmptyState();
    }

    final List<DateTime> days = _selectedFilterDay != null
        ? [_selectedFilterDay!]
        : _activeWeekDays;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 80),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final dayTasks = tasks.where((t) => t.spansDay(day)).toList();
        final isTodayDate = _isToday(day);

        dayTasks.sort((a, b) => a.startDate.compareTo(b.startDate));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day Section Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: isTodayDate
                    ? AppColors.primaryGold.withValues(alpha: 0.15)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isTodayDate ? AppColors.primaryGold.withValues(alpha: 0.4) : AppColors.gridLine,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 13,
                    color: isTodayDate ? AppColors.primaryGold : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatFullDayDate(day),
                      style: TextStyle(
                        color: isTodayDate ? AppColors.primaryGold : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isTodayDate) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'HOJE',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (_selectedFilterDay != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => setState(() => _selectedFilterDay = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4285F4).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF4285F4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Filtrado',
                              style: TextStyle(color: Color(0xFF4285F4), fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.close, size: 9, color: Color(0xFF4285F4)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Text(
                    '${dayTasks.length} ${dayTasks.length == 1 ? "tarefa" : "tarefas"}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            if (dayTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 6),
                child: Text(
                  'Nenhuma tarefa neste dia.',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ...dayTasks.map((task) => _buildTaskCard(task)),
          ],
        );
      },
    );
  }

  /// 4B. Dia (Day View)
  Widget _buildDayViewContent() {
    final dayTasks = _filteredTasks.where((t) => t.spansDay(_selectedDate)).toList();
    dayTasks.sort((a, b) => a.startDate.compareTo(b.startDate));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Day Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gridLine),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, color: Color(0xFF4285F4), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatFullDayDate(_selectedDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${dayTasks.length} tarefas',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (dayTasks.isEmpty)
            _buildEmptyState()
          else
            ...dayTasks.map((task) => _buildTaskCard(task)),
        ],
      ),
    );
  }

  /// 4C. Mês (Month View)
  Widget _buildMonthViewContent() {
    final DateTime firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final int daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final int startingWeekday = firstDayOfMonth.weekday; // 1 = Mon

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 80),
      child: Column(
        children: [
          // Days of week header (Seg, Ter, Qua...)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),

          // Month Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemCount: (startingWeekday - 1) + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startingWeekday - 1) {
                return const SizedBox.shrink();
              }

              final dayNum = index - (startingWeekday - 1) + 1;
              final dayDate = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
              final dayTasks = _tasksForDate(dayDate);
              final isSelected = _isSameDay(dayDate, _selectedDate);
              final isTodayDate = _isToday(dayDate);

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedDate = dayDate;
                    _selectedViewMode = 'Dia';
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4285F4).withValues(alpha: 0.2)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isTodayDate
                          ? AppColors.primaryGold
                          : (isSelected ? const Color(0xFF4285F4) : AppColors.gridLine),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          color: isTodayDate
                              ? AppColors.primaryGold
                              : (isSelected ? const Color(0xFF4285F4) : Colors.white),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      if (dayTasks.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: dayTasks.take(3).map((t) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 0.5),
                              width: 3.5,
                              height: 3.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: t.color,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Agenda list below month grid
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tarefas em ${_formatFullDayDate(_selectedDate)}:',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ..._tasksForDate(_selectedDate).map((t) => _buildTaskCard(t)),
        ],
      ),
    );
  }

  /// Task Card Widget com Auto-Ajuste de Texto (Nunca Estoura)
  Widget _buildTaskCard(AgendaTask task) {
    final String dateRangeString = _formatTaskDateRange(task.startDate, task.endDate);
    final int durationDays = task.durationInDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: task.isCompleted
              ? AppColors.gridLine
              : task.color.withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored vertical strip indicator
            Container(
              width: 4,
              constraints: const BoxConstraints(minHeight: 64),
              color: task.isCompleted ? Colors.grey : task.color,
            ),

            // Checkbox for completed status
            IconButton(
              padding: const EdgeInsets.only(left: 6, right: 4, top: 8),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: task.isCompleted ? AppColors.primaryGold : task.color,
                size: 20,
              ),
              onPressed: () => _toggleTaskCompletion(task.id),
              tooltip: task.isCompleted ? 'Marcar como pendente' : 'Marcar como concluída',
            ),

            // Task info body (Auto-Wrap em Qualquer Tamanho de Texto)
            Expanded(
              child: InkWell(
                onTap: () => _showTaskDetailsDialog(task),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8, right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badges: Data, Categoria, Prioridade
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Date Range Badge
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(
                                Icons.date_range,
                                size: 11,
                                color: task.isCompleted ? AppColors.textSecondary : AppColors.primaryGold,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                dateRangeString,
                                style: TextStyle(
                                  color: task.isCompleted
                                      ? AppColors.textSecondary
                                      : AppColors.primaryGold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (durationDays > 1) ...[
                                const SizedBox(width: 3),
                                Text(
                                  '($durationDays d)',
                                  style: TextStyle(
                                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: task.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              task.category.toUpperCase(),
                              style: TextStyle(
                                color: task.color,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          // Priority Pill
                          if (task.priority == 'Alta')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ALTA',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Title (Quebra de Linha Automática, Sem Limite Rígido)
                      Text(
                        task.title,
                        softWrap: true,
                        style: TextStyle(
                          color: task.isCompleted ? AppColors.textSecondary : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),

                      // Description (Quebra de Linha Automática)
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          softWrap: true,
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.85),
                            fontSize: 11,
                            height: 1.25,
                            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // More Options Icon
            IconButton(
              padding: const EdgeInsets.only(top: 6, right: 4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 16),
              onPressed: () => _showTaskDetailsDialog(task),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty state display
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            const Text(
              'Nenhuma tarefa agendada',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Clique em "+ Nova Tarefa" para cadastrar atividades da empreiteira.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  /// Show Task Details / Edit / Delete Modal (Totalmente Scrollável)
  void _showTaskDetailsDialog(AgendaTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: task.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.title,
                          softWrap: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.date_range, size: 14, color: AppColors.primaryGold),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Período: ${_formatShortDate(task.startDate)} até ${_formatShortDate(task.endDate)} (${task.durationInDays} ${task.durationInDays == 1 ? 'dia' : 'dias'})',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.category_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Categoria: ${task.category} • Prioridade ${task.priority}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Descrição:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      task.description,
                      softWrap: true,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                    ),
                  ],
                  if (!_canModifyAgenda)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(top: 14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.primaryGold, size: 16),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Visualização em modo de leitura. Apenas o Empreiteiro pode modificar tarefas.',
                              style: TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: task.isCompleted ? Colors.orangeAccent : const Color(0xFF34A853),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _toggleTaskCompletion(task.id);
                            },
                            icon: Icon(task.isCompleted ? Icons.undo : Icons.check, size: 16),
                            label: Text(
                              task.isCompleted ? 'Marcar Pendente' : 'Marcar Concluída',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                          ),
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteTask(task.id);
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Show Add/Edit Task Bottom Sheet Modal with Multi-Day Selection (Responsivo)
  void _showAddEditTaskModal(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    DateTime startDate = _selectedDate;
    DateTime endDate = _selectedDate;
    String selectedCategory = 'Obra';
    String selectedPriority = 'Alta';
    int colorHex = 0xFF4285F4;

    final categoriesWithColors = {
      'Obra': 0xFF4285F4,
      'Vistoria': 0xFF00ACC1,
      'Entrega': 0xFF34A853,
      'Segurança': 0xFFEA4335,
      'Manutenção': 0xFFFF9800,
      'Reunião': 0xFFFBBC05,
      'Geral': 0xFF607D8B,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Icon(Icons.add_task, color: Color(0xFF4285F4), size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Nova Tarefa da Empreiteira',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.gridLine),
                      const SizedBox(height: 8),

                      // Title Input
                      TextField(
                        controller: titleController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        maxLines: null,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'Nome da Tarefa / Serviço *',
                          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          hintText: 'Ex: Concretagem da Laje, Instalação Hidráulica',
                          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 11),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.gridLine),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Date Selection Section: Data de Início e Data de Término
                      const Text(
                        'Período de Execução:',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Data de Início Picker
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime(2025),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    startDate = picked;
                                    if (endDate.isBefore(startDate)) {
                                      endDate = startDate;
                                    }
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.gridLine),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.play_circle_outline, color: Color(0xFF4285F4), size: 14),
                                        SizedBox(width: 4),
                                        Text(
                                          'Início',
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _formatShortDate(startDate),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Data de Término Picker
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate.isBefore(startDate) ? startDate : endDate,
                                  firstDate: startDate,
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    endDate = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.gridLine),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.flag_outlined, color: Colors.orangeAccent, size: 14),
                                        SizedBox(width: 4),
                                        Text(
                                          'Término',
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _formatShortDate(endDate),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Category Selection Chips
                      const Text(
                        'Categoria:',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: categoriesWithColors.entries.map((entry) {
                          final cat = entry.key;
                          final color = entry.value;
                          final isSelected = selectedCategory == cat;

                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: Color(color).withValues(alpha: 0.3),
                            backgroundColor: AppColors.background,
                            labelStyle: TextStyle(
                              color: isSelected ? Color(color) : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isSelected ? Color(color) : AppColors.gridLine,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  selectedCategory = cat;
                                  colorHex = color;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Priority Selector
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'Prioridade: ',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          ...['Baixa', 'Média', 'Alta'].map((p) {
                            final isSelected = selectedPriority == p;
                            return ChoiceChip(
                              label: Text(p),
                              selected: isSelected,
                              selectedColor: AppColors.primaryGold.withValues(alpha: 0.3),
                              backgroundColor: AppColors.background,
                              labelStyle: TextStyle(
                                color: isSelected ? AppColors.primaryGold : AppColors.textSecondary,
                                fontSize: 10,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedPriority = p);
                              },
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Description Input
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Descrição / Detalhes da Tarefa',
                          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.gridLine),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4285F4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            if (titleController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Por favor, informe o nome da tarefa.'),
                                  backgroundColor: Colors.orangeAccent,
                                ),
                              );
                              return;
                            }

                            final initialTask = AgendaTask(
                              id: 'task_${DateTime.now().millisecondsSinceEpoch}',
                              title: titleController.text.trim(),
                              description: descController.text.trim(),
                              startDate: startDate,
                              endDate: endDate,
                              category: selectedCategory,
                              colorHex: colorHex,
                              priority: selectedPriority,
                            );

                            setState(() {
                              _allTasks.add(initialTask);
                            });

                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Salvando tarefa no banco de dados...'),
                                backgroundColor: Color(0xFF4285F4),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(milliseconds: 1200),
                              ),
                            );

                            final savedTask = await AgendaService.createTask(initialTask);
                            if (mounted) {
                              setState(() {
                                final idx = _allTasks.indexWhere((t) => t.id == initialTask.id);
                                if (idx != -1) {
                                  _allTasks[idx] = savedTask;
                                }
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tarefa registrada no banco de dados e adicionada à agenda!'),
                                  backgroundColor: Color(0xFF34A853),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: const Text(
                            'SALVAR TAREFA',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Helper Methods ---

  String _formatMonthYear(DateTime date) {
    const months = [
      'JANEIRO', 'FEVEREIRO', 'MARÇO', 'ABRIL', 'MAIO', 'JUNHO',
      'JULHO', 'AGOSTO', 'SETEMBRO', 'OUTUBRO', 'NOVEMBRO', 'DEZEMBRO'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _getDayAbbreviation(int weekday) {
    const days = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    return days[weekday - 1];
  }

  String _formatFullDayDate(DateTime date) {
    const days = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'];
    const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return '${days[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]}';
  }

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTaskDateRange(DateTime start, DateTime end) {
    if (_isSameDay(start, end)) {
      return _formatShortDate(start);
    }
    return '${_formatShortDate(start)} até ${_formatShortDate(end)}';
  }
}


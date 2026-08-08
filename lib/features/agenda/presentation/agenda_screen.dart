import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_service.dart';
import '../data/agenda_service.dart';
import '../domain/agenda_task_model.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  // Calendar Navigation State
  late DateTime _currentWeekStart; // Start date (Monday) of active week
  late DateTime _selectedDate; // Currently selected day
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
  void _toggleTaskCompletion(String id) {
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
    setState(() {
      final index = _allTasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        final task = _allTasks[index];
        _allTasks[index] = task.copyWith(isCompleted: !task.isCompleted);
      }
    });
    _saveTasksData();
  }

  /// Deletes a task
  void _deleteTask(String id) {
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
    setState(() {
      _allTasks.removeWhere((t) => t.id == id);
    });
    _saveTasksData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tarefa removida da agenda.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Jumps to current week & today
  void _jumpToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _selectedDate = today;
      _currentWeekStart = _getMonday(today);
    });
  }

  /// Navigates week forward or backward
  void _navigateWeek(int weeksDelta) {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(Duration(days: weeksDelta * 7));
      _selectedDate = _currentWeekStart;
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
        // Task overlaps the active week if task.startDate <= weekEnd AND task.endDate >= weekStart
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
              backgroundColor: const Color(0xFF4285F4), // Google Blue accent
              elevation: 6,
              icon: const Icon(Icons.add, color: Colors.white, size: 22),
              label: const Text(
                'Nova Tarefa',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          // 1. Google Calendar Header
          _buildGoogleCalendarHeader(monthYearTitle),

          // 2. View Mode Switcher & Filter Chips
          _buildControlsAndFilters(),

          // 3. Google Calendar Dynamic Week Strip
          _buildWeekStrip(),

          const SizedBox(height: 12),

          // 4. Main Calendar / Tasks Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
                : _buildMainCalendarContent(),
          ),
        ],
      ),
    );
  }

  /// 1. Top Google Calendar Header Widget
  Widget _buildGoogleCalendarHeader(String monthYearTitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.gridLine, width: 1.0),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Calendar Icon & Title "Agenda"
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Color(0xFF4285F4),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _canModifyAgenda ? 'Agenda Empreiteira' : 'Agenda da Obra',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (!_canModifyAgenda) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility, size: 11, color: AppColors.primaryGold),
                              SizedBox(width: 4),
                              Text(
                                'Somente Leitura',
                                style: TextStyle(color: AppColors.primaryGold, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    monthYearTitle,
                    style: const TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // "Hoje" Button
              InkWell(
                onTap: _jumpToToday,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gridLine,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.today, size: 14, color: AppColors.primaryGold),
                      SizedBox(width: 4),
                      Text(
                        'Hoje',
                        style: TextStyle(
                          color: AppColors.primaryGold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Previous Week Arrow
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                onPressed: () => _navigateWeek(-1),
                tooltip: 'Semana Anterior',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),

              // Next Week Arrow
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white, size: 24),
                onPressed: () => _navigateWeek(1),
                tooltip: 'Próxima Semana',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. View Mode Switcher ('Semana', 'Dia', 'Mês') & Filter Chips
  Widget _buildControlsAndFilters() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
      child: Column(
        children: [
          // View Switcher Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.gridLine),
                ),
                child: Row(
                  children: ['Semana', 'Dia', 'Mês'].map((mode) {
                    final isSelected = _selectedViewMode == mode;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedViewMode = mode),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF4285F4) : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          mode,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Spacer(),
              // Task summary count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gridLine),
                ),
                child: Text(
                  '${_filteredTasks.where((t) => t.isCompleted).length}/${_filteredTasks.length} concluídas',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

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
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryGold : AppColors.gridLine,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Dynamic Week Strip (7 Days Google Calendar Bar)
  Widget _buildWeekStrip() {
    final days = _activeWeekDays;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gridLine, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days.map((day) {
          final isSelected = _isSameDay(day, _selectedDate);
          final isTodayDate = _isToday(day);
          final dayTasks = _tasksForDate(day);
          final hasTasks = dayTasks.isNotEmpty;
          final dayAbbr = _getDayAbbreviation(day.weekday);

          return InkWell(
            onTap: () {
              setState(() {
                _selectedDate = day;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4285F4).withValues(alpha: 0.2)
                    : (isTodayDate
                        ? AppColors.primaryGold.withValues(alpha: 0.12)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF4285F4)
                      : (isTodayDate ? AppColors.primaryGold : Colors.transparent),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  // Day abbreviation (SEG, TER...)
                  Text(
                    dayAbbr,
                    style: TextStyle(
                      color: isTodayDate
                          ? AppColors.primaryGold
                          : (isSelected ? const Color(0xFF4285F4) : AppColors.textSecondary),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Day Number Circle Badge
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isTodayDate
                          ? AppColors.primaryGold
                          : (isSelected ? const Color(0xFF4285F4) : Colors.transparent),
                    ),
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: (isTodayDate || isSelected)
                            ? Colors.black
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Task indicator dots
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: hasTasks
                        ? dayTasks.take(3).map((t) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: t.isCompleted ? Colors.grey : t.color,
                              ),
                            );
                          }).toList()
                        : [
                            Container(
                              width: 5,
                              height: 5,
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
      return _buildWeekViewContent(); // Default Week View ("Semana")
    }
  }

  /// 4A. Semana (Week View) - Multi-Day Contractor Task Schedule
  Widget _buildWeekViewContent() {
    final tasks = _filteredTasks;

    if (tasks.isEmpty) {
      return _buildEmptyState();
    }

    final days = _activeWeekDays;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final dayTasks = tasks.where((t) => t.spansDay(day)).toList();
        final isTodayDate = _isToday(day);

        // Sort tasks by start date
        dayTasks.sort((a, b) => a.startDate.compareTo(b.startDate));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day Section Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              margin: const EdgeInsets.only(top: 12, bottom: 8),
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
                    size: 14,
                    color: isTodayDate ? AppColors.primaryGold : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatFullDayDate(day),
                    style: TextStyle(
                      color: isTodayDate ? AppColors.primaryGold : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (isTodayDate) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'HOJE',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${dayTasks.length} ${dayTasks.length == 1 ? "tarefa" : "tarefas"}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            if (dayTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Text(
                  'Nenhuma tarefa neste dia.',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 12,
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
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Day Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gridLine),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, color: Color(0xFF4285F4)),
                const SizedBox(width: 10),
                Text(
                  _formatFullDayDate(_selectedDate),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  '${dayTasks.length} tarefas',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (dayTasks.isEmpty)
            _buildEmptyState()
          else
            ...dayTasks.map((task) => _buildTaskCard(task)),
        ],
      ),
    );
  }

  /// 4C. Mês (Month View) - Grid Overview
  Widget _buildMonthViewContent() {
    final DateTime firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final int daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final int startingWeekday = firstDayOfMonth.weekday; // 1 = Mon

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
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
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Month Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.9,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
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
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4285F4).withValues(alpha: 0.2)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
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
                          fontSize: 12,
                        ),
                      ),
                      if (dayTasks.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: dayTasks.take(3).map((t) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              width: 4,
                              height: 4,
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
          const SizedBox(height: 20),

          // Agenda list below month grid for selected day
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tarefas em ${_formatFullDayDate(_selectedDate)}:',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ..._tasksForDate(_selectedDate).map((t) => _buildTaskCard(t)),
        ],
      ),
    );
  }

  /// Task Card Widget (Multi-Day Contractor Task Event)
  Widget _buildTaskCard(AgendaTask task) {
    final String dateRangeString = _formatTaskDateRange(task.startDate, task.endDate);
    final int durationDays = task.durationInDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.isCompleted
              ? AppColors.gridLine
              : task.color.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Colored vertical strip indicator
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: task.isCompleted ? Colors.grey : task.color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),

            // Checkbox for completed status
            IconButton(
              icon: Icon(
                task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: task.isCompleted ? AppColors.primaryGold : task.color,
                size: 22,
              ),
              onPressed: () => _toggleTaskCompletion(task.id),
              tooltip: task.isCompleted ? 'Marcar como pendente' : 'Marcar como concluída',
            ),

            // Task info body
            Expanded(
              child: InkWell(
                onTap: () => _showTaskDetailsDialog(task),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Date Range Badge (e.g. 10/08 a 14/08 • 5 dias)
                          Icon(Icons.date_range, size: 12, color: task.isCompleted ? AppColors.textSecondary : AppColors.primaryGold),
                          const SizedBox(width: 4),
                          Text(
                            dateRangeString,
                            style: TextStyle(
                              color: task.isCompleted
                                  ? AppColors.textSecondary
                                  : AppColors.primaryGold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (durationDays > 1) ...[
                            const SizedBox(width: 4),
                            Text(
                              '($durationDays dias)',
                              style: TextStyle(
                                color: AppColors.textSecondary.withValues(alpha: 0.8),
                                fontSize: 10,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),

                          // Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: task.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              task.category.toUpperCase(),
                              style: TextStyle(
                                color: task.color,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),

                          // Priority Pill
                          if (task.priority == 'Alta')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      const SizedBox(height: 4),

                      // Title
                      Text(
                        task.title,
                        style: TextStyle(
                          color: task.isCompleted ? AppColors.textSecondary : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),

                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                            fontSize: 11,
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
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 18),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 56,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nenhuma tarefa agendada',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Clique em "+ Nova Tarefa" para cadastrar atividades da empreiteira.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Show Task Details / Edit / Delete Modal
  void _showTaskDetailsDialog(AgendaTask task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.date_range, size: 16, color: AppColors.primaryGold),
                  const SizedBox(width: 6),
                  Text(
                    'Período: ${_formatShortDate(task.startDate)} até ${_formatShortDate(task.endDate)} (${task.durationInDays} ${task.durationInDays == 1 ? 'dia' : 'dias'})',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.category_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Categoria: ${task.category} • Prioridade ${task.priority}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Descrição:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  task.description,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
              if (!_canModifyAgenda)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primaryGold, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Visualização em modo de leitura. Apenas o Empreiteiro pode modificar eventos no calendário.',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: task.isCompleted ? Colors.orangeAccent : const Color(0xFF34A853),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _toggleTaskCompletion(task.id);
                        },
                        icon: Icon(task.isCompleted ? Icons.undo : Icons.check, size: 18),
                        label: Text(task.isCompleted ? 'Marcar Pendente' : 'Marcar Concluída'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                      ),
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
        );
      },
    );
  }

  /// Show Add/Edit Task Bottom Sheet Modal with Multi-Day Selection
  void _showAddEditTaskModal(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    DateTime startDate = _selectedDate;
    DateTime endDate = _selectedDate;
    String selectedCategory = 'Obra';
    String selectedPriority = 'Alta';
    int colorHex = 0xFF4285F4;

    final categoriesWithColors = {
      'Obra': 0xFF4285F4, // Google Blue
      'Vistoria': 0xFF00ACC1, // Cyan
      'Entrega': 0xFF34A853, // Google Green
      'Segurança': 0xFFEA4335, // Google Red
      'Manutenção': 0xFFFF9800, // Orange
      'Reunião': 0xFFFBBC05, // Google Yellow
      'Geral': 0xFF607D8B, // Grey
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.add_task, color: Color(0xFF4285F4)),
                        const SizedBox(width: 10),
                        const Text(
                          'Nova Tarefa da Empreiteira',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.gridLine),
                    const SizedBox(height: 10),

                    // Title Input
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nome da Tarefa / Serviço *',
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        hintText: 'Ex: Concretagem da Laje, Instalação Hidráulica',
                        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.gridLine),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date Selection Section: Data de Início e Data de Término
                    const Text(
                      'Período de Execução:',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
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
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.gridLine),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.play_circle_outline, color: Color(0xFF4285F4), size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Início (Dia)',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatShortDate(startDate),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

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
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.gridLine),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.flag_outlined, color: Colors.orangeAccent, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Término (Dia)',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatShortDate(endDate),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Category Selection Chips
                    const Text(
                      'Categoria:',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
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
                            fontSize: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? Color(color) : AppColors.gridLine,
                            ),
                          ),
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
                    const SizedBox(height: 14),

                    // Priority Selector
                    Row(
                      children: [
                        const Text(
                          'Prioridade: ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        ...['Baixa', 'Média', 'Alta'].map((p) {
                          final isSelected = selectedPriority == p;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(p),
                              selected: isSelected,
                              selectedColor: AppColors.primaryGold.withValues(alpha: 0.3),
                              backgroundColor: AppColors.background,
                              labelStyle: TextStyle(
                                color: isSelected ? AppColors.primaryGold : AppColors.textSecondary,
                                fontSize: 11,
                              ),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedPriority = p);
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Description Input
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Descrição / Detalhes da Empreitada',
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.gridLine),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4285F4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          if (titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Por favor, informe o nome da tarefa.'),
                                backgroundColor: Colors.orangeAccent,
                              ),
                            );
                            return;
                          }

                          final newTask = AgendaTask(
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
                            _allTasks.add(newTask);
                          });
                          _saveTasksData();

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tarefa da empreiteira adicionada à agenda com sucesso!'),
                              backgroundColor: Color(0xFF34A853),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Text(
                          'SALVAR TAREFA',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
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

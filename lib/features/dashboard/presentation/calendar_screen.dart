import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_service.dart';

class CalendarScreen extends StatefulWidget {
  final int? obraId;

  const CalendarScreen({super.key, this.obraId});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final events = await AuthService.fetchCalendarioEvents(obraId: widget.obraId);
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getEventsForSelectedDate() {
    return _events.where((event) {
      try {
        final inicio = DateTime.parse(event['dataInicio']);
        return inicio.year == _selectedDate.year &&
            inicio.month == _selectedDate.month &&
            inicio.day == _selectedDate.day;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Color _getEventTypeColor(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'FASE_OBRA':
        return Colors.blueAccent;
      case 'PREVISAO_MATERIAL':
        return AppColors.primaryGold;
      case 'SOLICITACAO_MATERIAL':
        return Colors.orangeAccent;
      case 'PONTO':
        return Colors.greenAccent;
      case 'FINANCEIRO':
        return Colors.purpleAccent;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getEventTypeIcon(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'FASE_OBRA':
        return Icons.construction;
      case 'PREVISAO_MATERIAL':
        return Icons.inventory_2;
      case 'SOLICITACAO_MATERIAL':
        return Icons.shopping_cart;
      case 'PONTO':
        return Icons.access_time;
      case 'FINANCEIRO':
        return Icons.attach_money;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsForDay = _getEventsForSelectedDate();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Calendário & Cronograma', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryGold),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : Column(
              children: [
                // Date Selector Header
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: AppColors.surface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                          });
                        },
                      ),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: Column(
                          children: [
                            Text(
                              "${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}",
                              style: const TextStyle(color: AppColors.primaryGold, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Text('Toque para escolher data', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _selectedDate = _selectedDate.add(const Duration(days: 1));
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.gridLine),

                // Events for the selected date
                Expanded(
                  child: eventsForDay.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_available, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              const Text('Nenhum evento registrado nesta data', style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: eventsForDay.length,
                          itemBuilder: (context, index) {
                            final event = eventsForDay[index];
                            final color = _getEventTypeColor(event['tipo'] ?? '');
                            final icon = _getEventTypeIcon(event['tipo'] ?? '');

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: color.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: color.withValues(alpha: 0.2),
                                    child: Icon(icon, color: color),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                event['titulo'] ?? 'Evento',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                event['status'] ?? 'OK',
                                                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          event['descricao'] ?? '',
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                        ),
                                        if (event['nomeObra'] != null) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_city, size: 12, color: AppColors.primaryGold),
                                              const SizedBox(width: 4),
                                              Text(
                                                event['nomeObra'],
                                                style: const TextStyle(color: AppColors.primaryGold, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/auth_service.dart';
import '../domain/agenda_task_model.dart';

class AgendaService {
  static const String _storageKey = 'vizion_agenda_tasks_v2';

  /// Loads tasks combining local storage with API obras/phases data (matching Desktop ApiService)
  static Future<List<AgendaTask>> loadTasks() async {
    List<AgendaTask> localTasks = await _loadLocalTasks();
    List<AgendaTask> apiEvents = await fetchApiCalendarEvents();

    // Merge: preserve local user-created tasks and combine with API events
    final Map<String, AgendaTask> mergedMap = {};
    for (var ev in apiEvents) {
      mergedMap[ev.id] = ev;
    }
    for (var task in localTasks) {
      mergedMap[task.id] = task;
    }

    return mergedMap.values.toList();
  }

  /// Fetches calendar events directly from API obras & phases (same as Desktop ApiService)
  static Future<List<AgendaTask>> fetchApiCalendarEvents() async {
    List<AgendaTask> events = [];

    try {
      final obras = await AuthService.fetchObras();

      for (var obra in obras) {
        final int obraId = obra['id'] ?? 0;
        final String obraNome = obra['nome_projeto'] ?? 'Obra #$obraId';
        final String? startStr = obra['data_inicio'];
        final String? deliveryStr = obra['data_previsao_entrega'] ?? obra['data_fim_previsto'];
        final String status = obra['status'] ?? 'EM_ANDAMENTO';

        // 1. Obra Start Date Event
        if (startStr != null && startStr.isNotEmpty) {
          try {
            final dt = DateTime.parse(startStr);
            events.add(
              AgendaTask(
                id: 'api_start_$obraId',
                title: 'Início: $obraNome',
                description: 'Data de início oficial da obra $obraNome.',
                startDate: dt,
                endDate: dt,
                category: 'Obra',
                colorHex: 0xFF4285F4, // Google Blue
                isCompleted: status == 'CONCLUIDO',
                priority: 'Alta',
              ),
            );
          } catch (e) {
            print('Erro ao parsear data inicio: $e');
          }
        }

        // 2. Obra Delivery Event
        if (deliveryStr != null && deliveryStr.isNotEmpty) {
          try {
            final dt = DateTime.parse(deliveryStr);
            events.add(
              AgendaTask(
                id: 'api_delivery_$obraId',
                title: 'Previsão Entrega: $obraNome',
                description: 'Data de entrega física e finalização da obra $obraNome.',
                startDate: dt,
                endDate: dt,
                category: 'Entrega',
                colorHex: 0xFF34A853, // Google Green
                isCompleted: status == 'CONCLUIDO',
                priority: 'Alta',
              ),
            );
          } catch (e) {
            print('Erro ao parsear data entrega: $e');
          }
        }

        // 3. Obra Phases & Deadlines Details
        if (obraId > 0) {
          try {
            final fases = await AuthService.fetchFases(obraId);
            for (var fase in fases) {
              final int faseId = fase['id'] ?? 0;
              final String faseNome = fase['nome_fase'] ?? fase['nome'] ?? 'Etapa da Obra';
              final String? faseStart = fase['data_inicio'];
              final String? faseEnd = fase['data_fim'] ?? fase['prazo'];
              final String faseStatus = fase['status'] ?? 'PENDENTE';

              if (faseStart != null || faseEnd != null) {
                final dtStart = faseStart != null ? DateTime.parse(faseStart) : DateTime.parse(faseEnd!);
                final dtEnd = faseEnd != null ? DateTime.parse(faseEnd) : dtStart;

                events.add(
                  AgendaTask(
                    id: 'api_fase_${obraId}_$faseId',
                    title: 'Prazo Etapa: $faseNome',
                    description: 'Etapa $faseNome para $obraNome.',
                    startDate: dtStart,
                    endDate: dtEnd,
                    category: 'Vistoria',
                    colorHex: 0xFF00ACC1, // Cyan
                    isCompleted: faseStatus == 'CONCLUIDO' || faseStatus == 'CONCLUIDA',
                    priority: 'Média',
                  ),
                );
              }
            }
          } catch (e) {
            print('Erro ao buscar fases para obra $obraId: $e');
          }
        }
      }
    } catch (e) {
      print('API offline ou sem resposta, carregando eventos padrão de canteiro: $e');
    }

    // If API returns no events (e.g. offline/mock), populate desktop standard events
    if (events.isEmpty) {
      final now = DateTime.now();
      events = [
        AgendaTask(
          id: 'demo_1',
          title: 'Início da Terraplenagem - Res. Bella Vista',
          description: 'Início oficial dos trabalhos em canteiro.',
          startDate: DateTime(now.year, now.month, 2),
          endDate: DateTime(now.year, now.month, 4),
          category: 'Obra',
          colorHex: 0xFF4285F4,
          isCompleted: true,
          priority: 'Alta',
        ),
        AgendaTask(
          id: 'demo_2',
          title: 'Medição da Fundação & Armação',
          description: 'Prazo limite para medição da etapa de fundações.',
          startDate: DateTime(now.year, now.month, 10),
          endDate: DateTime(now.year, now.month, 12),
          category: 'Vistoria',
          colorHex: 0xFF00ACC1,
          isCompleted: false,
          priority: 'Média',
        ),
        AgendaTask(
          id: 'demo_3',
          title: 'Prazo Concretagem Laje 1º Pavimento',
          description: 'Prazo limite de concretagem da primeira laje.',
          startDate: DateTime(now.year, now.month, 18),
          endDate: DateTime(now.year, now.month, 21),
          category: 'Obra',
          colorHex: 0xFFFF9800,
          isCompleted: false,
          priority: 'Alta',
        ),
        AgendaTask(
          id: 'demo_4',
          title: 'Entrega da Obra - Res. Bella Vista',
          description: 'Previsão de entrega da chave aos proprietários.',
          startDate: DateTime(now.year, now.month, 28),
          endDate: DateTime(now.year, now.month, 28),
          category: 'Entrega',
          colorHex: 0xFF34A853,
          isCompleted: false,
          priority: 'Alta',
        ),
      ];
    }

    return events;
  }

  static Future<List<AgendaTask>> _loadLocalTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);

    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        return jsonList.map((e) => AgendaTask.fromMap(Map<String, dynamic>.from(e))).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  /// Saves user created tasks to SharedPreferences
  static Future<void> saveTasks(List<AgendaTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(tasks.map((t) => t.toMap()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// Clears all tasks stored in SharedPreferences
  static Future<void> clearAllTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

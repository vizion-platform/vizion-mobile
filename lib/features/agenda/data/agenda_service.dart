import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/auth_service.dart';
import '../domain/agenda_task_model.dart';

class AgendaService {
  static const String _storageKey = 'vizion_agenda_tasks_v2';

  /// Loads tasks combining database records, local storage, and API obras/phases data
  static Future<List<AgendaTask>> loadTasks({int? obraId}) async {
    List<AgendaTask> localTasks = await _loadLocalTasks();
    List<AgendaTask> dbTasks = await fetchDatabaseTasks(obraId: obraId);
    List<AgendaTask> apiEvents = await fetchApiCalendarEvents();

    final Map<String, AgendaTask> mergedMap = {};

    // 1. Base events from obras / phases
    for (var ev in apiEvents) {
      mergedMap[ev.id] = ev;
    }

    // 2. Local tasks from previous sessions
    for (var task in localTasks) {
      mergedMap[task.id] = task;
    }

    // 3. Official tasks from PostgreSQL Database (highest precedence)
    for (var task in dbTasks) {
      mergedMap[task.id] = task;
    }

    final result = mergedMap.values.toList();
    // Cache current user-created / DB tasks locally for offline reliability
    await saveTasks(result.where((t) => !t.id.startsWith('api_') && !t.id.startsWith('demo_')).toList());

    return result;
  }

  /// Fetches tasks directly from PostgreSQL database via API
  static Future<List<AgendaTask>> fetchDatabaseTasks({int? obraId}) async {
    try {
      final rawList = await AuthService.fetchTarefas(obraId: obraId);
      return rawList.map((item) {
        final id = item['id']?.toString() ?? '';
        return AgendaTask.fromMap({
          ...item,
          'id': id.isNotEmpty ? 'db_$id' : id,
        });
      }).toList();
    } catch (e) {
      print('Erro ao carregar tarefas do banco: $e');
      return [];
    }
  }

  /// Creates a new task in the database and caches locally
  static Future<AgendaTask> createTask(AgendaTask task, {int? obraId}) async {
    AgendaTask finalTask = task;

    try {
      final payload = {
        'titulo': task.title,
        'descricao': task.description,
        'dataInicio': task.startDate.toIso8601String(),
        'dataFim': task.endDate.toIso8601String(),
        'categoria': task.category,
        'corHex': task.colorHex,
        'concluida': task.isCompleted,
        'prioridade': task.priority,
        'idObra': obraId,
      };

      final response = await AuthService.createTarefa(payload);
      if (response != null && response['id'] != null) {
        final dbId = response['id'].toString();
        finalTask = task.copyWith(id: 'db_$dbId');
      }
    } catch (e) {
      print('Erro ao persistir tarefa no banco de dados, mantendo local: $e');
    }

    // Update local cache
    List<AgendaTask> localTasks = await _loadLocalTasks();
    localTasks.removeWhere((t) => t.id == finalTask.id || t.id == task.id);
    localTasks.add(finalTask);
    await saveTasks(localTasks);

    return finalTask;
  }

  /// Toggles task completion status in database and locally
  static Future<AgendaTask> toggleTaskCompletion(AgendaTask task) async {
    final updated = task.copyWith(isCompleted: !task.isCompleted);

    final numId = _extractNumericId(task.id);
    if (numId != null) {
      try {
        await AuthService.toggleTarefaStatus(numId);
      } catch (e) {
        print('Erro ao atualizar status da tarefa no banco: $e');
      }
    }

    List<AgendaTask> localTasks = await _loadLocalTasks();
    final idx = localTasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      localTasks[idx] = updated;
    } else {
      localTasks.add(updated);
    }
    await saveTasks(localTasks);

    return updated;
  }

  /// Deletes task in database and locally
  static Future<void> deleteTask(AgendaTask task) async {
    final numId = _extractNumericId(task.id);
    if (numId != null) {
      try {
        await AuthService.deleteTarefa(numId);
      } catch (e) {
        print('Erro ao deletar tarefa no banco: $e');
      }
    }

    List<AgendaTask> localTasks = await _loadLocalTasks();
    localTasks.removeWhere((t) => t.id == task.id);
    await saveTasks(localTasks);
  }

  static int? _extractNumericId(String id) {
    if (id.startsWith('db_')) {
      return int.tryParse(id.substring(3));
    }
    return int.tryParse(id);
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

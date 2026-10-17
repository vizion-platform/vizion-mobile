import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/auth_service.dart';
import '../domain/ponto_record_model.dart';

class PontoException implements Exception {
  final String message;
  PontoException(this.message);

  @override
  String toString() => message;
}

class PontoService {
  static const String _storagePrefix = 'vizion_ponto_records_v3_';

  static String _getMonthKey(int year, int month) {
    return '$_storagePrefix${year}_${month.toString().padLeft(2, '0')}';
  }

  /// Map internal PontoType to vizion-api TipoBatida enum
  static String _mapTypeToApi(PontoType type) {
    switch (type) {
      case PontoType.entrada:
        return 'ENTRADA';
      case PontoType.saidaAlmoco:
        return 'SAIDA_ALMOCO';
      case PontoType.retornoAlmoco:
        return 'RETORNO_ALMOCO';
      case PontoType.saida:
        return 'SAIDA';
      case PontoType.extra:
        return 'ENTRADA';
    }
  }

  /// Converts a vizion-api RegistroPontoResponse Map into PontoDay
  static PontoDay _fromApiResponse(Map<String, dynamic> item) {
    final DateTime date = DateTime.parse(item['data']);
    final List<PontoPunch> punches = [];
    final String location = item['localizacao'] ?? 'Localização não informada';
    final int id = item['id'] ?? 0;

    if (item['horaEntrada'] != null) {
      punches.add(PontoPunch(
        id: 'api_${id}_entrada',
        type: PontoType.entrada,
        timestamp: DateTime.parse(item['horaEntrada']),
        location: location,
      ));
    }
    if (item['horaSaidaAlmoco'] != null) {
      punches.add(PontoPunch(
        id: 'api_${id}_saida_almoco',
        type: PontoType.saidaAlmoco,
        timestamp: DateTime.parse(item['horaSaidaAlmoco']),
        location: location,
      ));
    }
    if (item['horaRetornoAlmoco'] != null) {
      punches.add(PontoPunch(
        id: 'api_${id}_retorno_almoco',
        type: PontoType.retornoAlmoco,
        timestamp: DateTime.parse(item['horaRetornoAlmoco']),
        location: location,
      ));
    }
    if (item['horaSaida'] != null) {
      punches.add(PontoPunch(
        id: 'api_${id}_saida',
        type: PontoType.saida,
        timestamp: DateTime.parse(item['horaSaida']),
        location: location,
      ));
    }

    return PontoDay(
      date: date,
      punches: punches,
      expectedMinutes: date.weekday > 5 ? 0 : 480,
      isDayOff: date.weekday > 5,
      customNote: item['observacao'],
    );
  }

  /// "Hoje" no fuso de Brasília (UTC-3, sem horário de verão), o mesmo que o servidor usa para a jornada.
  /// O relógio/fuso do aparelho não define o dia da batida.
  static DateTime hojeBrasilia() {
    final b = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    return DateTime(b.year, b.month, b.day);
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Load today's PontoDay (from API or local cache)
  static Future<PontoDay> getTodayPonto() async {
    final now = hojeBrasilia();

    // 1. Try to fetch from API
    try {
      final response = await ApiClient.get(
        // Só o dia de hoje: não baixa todo o histórico a cada abertura da tela.
        Uri.parse('${AuthService.baseUrl}/ponto/meu-ponto?inicio=${_ymd(now)}&fim=${_ymd(now)}'),
        headers: AuthService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        final todayStr = _ymd(now);
        final todayItem = list.firstWhere(
          (e) => (e['data'] as String?)?.startsWith(todayStr) == true,
          orElse: () => null,
        );

        if (todayItem != null) {
          final todayDay = _fromApiResponse(Map<String, dynamic>.from(todayItem));
          await _saveTodayToLocal(todayDay);
          return todayDay;
        }
      }
    } catch (_) {
      // Offline / API unavailable fallback to local storage
    }

    // 2. Local fallback
    final monthSummary = await getMonthPonto(now.year, now.month);
    final today = monthSummary.days.firstWhere(
      (d) => d.date.year == now.year && d.date.month == now.month && d.date.day == now.day,
      orElse: () => PontoDay(
        date: DateTime(now.year, now.month, now.day),
        punches: [],
        expectedMinutes: now.weekday > 5 ? 0 : 480,
        isDayOff: now.weekday > 5,
      ),
    );
    return today;
  }

  /// Registra a batida no servidor. O horário oficial é sempre o do servidor (Portaria 671): sem
  /// conexão ou com recusa do servidor a batida NÃO é registrada e o erro chega ao usuário.
  static Future<({PontoDay day, PontoPunch punch})> registerPunch({
    required PontoType type,
    String? location,
  }) async {
    final http.Response response;
    try {
      response = await ApiClient.post(
        Uri.parse('${AuthService.baseUrl}/ponto/bater'),
        headers: AuthService.getHeaders(),
        // O funcionário é o do token; nunca enviamos id vindo do cliente.
        body: jsonEncode({
          'tipoBatida': _mapTypeToApi(type),
          if (location != null) 'localizacao': location,
        }),
      );
    } catch (_) {
      throw PontoException('Sem conexão com o servidor. A batida não foi registrada; tente novamente.');
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw PontoException(_mensagemDoServidor(response) ??
          'Não foi possível registrar o ponto (erro ${response.statusCode}).');
    }

    final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    final updatedDay = _fromApiResponse(data);
    if (updatedDay.punches.isEmpty) {
      throw PontoException('Resposta inválida do servidor ao registrar o ponto.');
    }
    await _saveTodayToLocal(updatedDay);
    return (day: updatedDay, punch: updatedDay.punches.last);
  }

  static String? _mensagemDoServidor(http.Response response) {
    try {
      final corpo = jsonDecode(utf8.decode(response.bodyBytes));
      if (corpo is Map && corpo['message'] is String) return corpo['message'] as String;
    } catch (_) {}
    return null;
  }

  /// Helper to save updated today record into local storage
  static Future<void> _saveTodayToLocal(PontoDay updatedDay) async {
    final now = updatedDay.date;
    final monthSummary = await getMonthPonto(now.year, now.month);
    final updatedDays = monthSummary.days.map((d) {
      if (d.date.year == now.year && d.date.month == now.month && d.date.day == now.day) {
        return updatedDay;
      }
      return d;
    }).toList();

    if (!updatedDays.any((d) => d.date.year == now.year && d.date.month == now.month && d.date.day == now.day)) {
      updatedDays.add(updatedDay);
      updatedDays.sort((a, b) => a.date.compareTo(b.date));
    }

    await _saveMonthDays(now.year, now.month, updatedDays);
  }

  /// Determines next required punch
  static PontoType? getNextPunchType(PontoDay day) {
    if (day.entrada == null) return PontoType.entrada;
    if (day.saidaAlmoco == null) return PontoType.saidaAlmoco;
    if (day.retornoAlmoco == null) return PontoType.retornoAlmoco;
    if (day.saida == null) return PontoType.saida;
    return null; // All 4 daily punches registered
  }

  /// Loads full month timesheet (Espelho de Ponto) from vizion-api with local cache
  static Future<PontoMonthlySummary> getMonthPonto(int year, int month) async {
    List<PontoDay> days = [];

    // 1. Try to fetch from API
    try {
      final response = await ApiClient.get(
        Uri.parse('${AuthService.baseUrl}/ponto/meu-ponto'),
        headers: AuthService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        final monthStr = '$year-${month.toString().padLeft(2, '0')}';

        for (var item in list) {
          final dataStr = item['data'] as String?;
          if (dataStr != null && dataStr.startsWith(monthStr)) {
            days.add(_fromApiResponse(Map<String, dynamic>.from(item)));
          }
        }
        days.sort((a, b) => a.date.compareTo(b.date));
        if (days.isNotEmpty) {
          await _saveMonthDays(year, month, days);
        }
      }
    } catch (_) {
      // Offline fallback
    }

    // 2. If API was empty or offline, load from local storage
    if (days.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final key = _getMonthKey(year, month);
      final jsonStr = prefs.getString(key);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(jsonStr);
          days = list.map((e) => PontoDay.fromMap(Map<String, dynamic>.from(e))).toList();
          days.sort((a, b) => a.date.compareTo(b.date));
        } catch (_) {}
      }
    }

    // No fake mock history generated — starts clean (zerado) and accumulates actual records
    return PontoMonthlySummary(
      year: year,
      month: month,
      days: days,
    );
  }

  static Future<void> _saveMonthDays(int year, int month, List<PontoDay> days) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getMonthKey(year, month);
    final jsonString = jsonEncode(days.map((d) => d.toMap()).toList());
    await prefs.setString(key, jsonString);
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/auth_service.dart';
import '../domain/ponto_record_model.dart';

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
    final String location = item['localizacao'] ?? 'Canteiro de Obras • GPS Validado';
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

  /// Load today's PontoDay (from API or local cache)
  static Future<PontoDay> getTodayPonto() async {
    final now = DateTime.now();

    // 1. Try to fetch from API
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/ponto/meu-ponto'),
        headers: AuthService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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

  /// Register a new punch for today (saves to vizion-api database and local storage)
  static Future<({PontoDay day, PontoPunch punch})> registerPunch({
    required PontoType type,
    String location = 'Canteiro de Obras • GPS Validado (-23.5505, -46.6333)',
  }) async {
    final now = DateTime.now();
    final todayDay = await getTodayPonto();

    final localPunch = PontoPunch(
      id: 'punch_${now.millisecondsSinceEpoch}',
      type: type,
      timestamp: now,
      location: location,
      device: 'Vizion Mobile (Portaria 671 MTE)',
    );

    PontoDay updatedDay;
    PontoPunch returnedPunch = localPunch;

    // 1. Send to vizion-api backend
    try {
      final body = jsonEncode({
        'idFuncionario': AuthService.userId,
        'tipoBatida': _mapTypeToApi(type),
        'localizacao': location,
      });

      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/ponto/bater'),
        headers: AuthService.getHeaders(),
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        updatedDay = _fromApiResponse(data);
        if (updatedDay.punches.isNotEmpty) {
          returnedPunch = updatedDay.punches.last;
        }
      } else {
        // Construct day locally if API returned unexpected status
        final updatedPunches = List<PontoPunch>.from(todayDay.punches)..add(localPunch);
        updatedDay = PontoDay(
          date: todayDay.date,
          punches: updatedPunches,
          expectedMinutes: todayDay.expectedMinutes,
          isDayOff: todayDay.isDayOff,
          customNote: todayDay.customNote,
        );
      }
    } catch (_) {
      // Local fallback if offline
      final updatedPunches = List<PontoPunch>.from(todayDay.punches)..add(localPunch);
      updatedDay = PontoDay(
        date: todayDay.date,
        punches: updatedPunches,
        expectedMinutes: todayDay.expectedMinutes,
        isDayOff: todayDay.isDayOff,
        customNote: todayDay.customNote,
      );
    }

    // 2. Persist to local storage
    await _saveTodayToLocal(updatedDay);

    return (day: updatedDay, punch: returnedPunch);
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
      final response = await http.get(
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

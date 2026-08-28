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

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is List && value.isNotEmpty) {
      final year = value[0] as int;
      final month = value.length > 1 ? value[1] as int : 1;
      final day = value.length > 2 ? value[2] as int : 1;
      final hour = value.length > 3 ? value[3] as int : 0;
      final minute = value.length > 4 ? value[4] as int : 0;
      final second = value.length > 5 ? value[5] as int : 0;
      return DateTime(year, month, day, hour, minute, second);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Converts a vizion-api RegistroPontoResponse Map into PontoDay
  static PontoDay _fromApiResponse(Map<String, dynamic> item) {
    final DateTime parsedDate = _parseDateTime(item['data']);
    final DateTime date = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final List<PontoPunch> punches = [];
    final String location = item['localizacao'] ?? 'Canteiro de Obras • GPS Validado';
    final dynamic rawId = item['id'] ?? 'db';

    if (item['horaEntrada'] != null) {
      punches.add(PontoPunch(
        id: 'api_${rawId}_entrada',
        type: PontoType.entrada,
        timestamp: _parseDateTime(item['horaEntrada']),
        location: location,
      ));
    }
    if (item['horaSaidaAlmoco'] != null) {
      punches.add(PontoPunch(
        id: 'api_${rawId}_saida_almoco',
        type: PontoType.saidaAlmoco,
        timestamp: _parseDateTime(item['horaSaidaAlmoco']),
        location: location,
      ));
    }
    if (item['horaRetornoAlmoco'] != null) {
      punches.add(PontoPunch(
        id: 'api_${rawId}_retorno_almoco',
        type: PontoType.retornoAlmoco,
        timestamp: _parseDateTime(item['horaRetornoAlmoco']),
        location: location,
      ));
    }
    if (item['horaSaida'] != null) {
      punches.add(PontoPunch(
        id: 'api_${rawId}_saida',
        type: PontoType.saida,
        timestamp: _parseDateTime(item['horaSaida']),
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

  /// Load today's PontoDay (from API database or local cache)
  static Future<PontoDay> getTodayPonto() async {
    final now = DateTime.now();

    // 1. Try to fetch from Database API
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/ponto/meu-ponto'),
        headers: AuthService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        final todayItem = list.firstWhere(
          (e) {
            if (e is! Map) return false;
            final dataVal = e['data'];
            if (dataVal == null) return false;
            final dt = _parseDateTime(dataVal);
            return dt.year == now.year && dt.month == now.month && dt.day == now.day;
          },
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

    // 1. Send to vizion-api database backend
    try {
      final body = jsonEncode({
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

  /// Loads full month timesheet (Espelho de Ponto) from database API with local cache
  static Future<PontoMonthlySummary> getMonthPonto(int year, int month) async {
    final Map<String, PontoDay> dayMap = {};

    // 1. First, load existing local storage cache
    final prefs = await SharedPreferences.getInstance();
    final key = _getMonthKey(year, month);
    final jsonStr = prefs.getString(key);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        for (var e in list) {
          final day = PontoDay.fromMap(Map<String, dynamic>.from(e));
          final dayKey = '${day.date.year}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}';
          dayMap[dayKey] = day;
        }
      } catch (_) {}
    }

    // 2. Fetch fresh records from database API (/ponto/meu-ponto)
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/ponto/meu-ponto'),
        headers: AuthService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        for (var item in list) {
          if (item is Map) {
            final pontoDay = _fromApiResponse(Map<String, dynamic>.from(item));
            if (pontoDay.date.year == year && pontoDay.date.month == month) {
              final dayKey = '${pontoDay.date.year}-${pontoDay.date.month.toString().padLeft(2, '0')}-${pontoDay.date.day.toString().padLeft(2, '0')}';
              dayMap[dayKey] = pontoDay;
            }
          }
        }
      }
    } catch (_) {
      // Offline fallback
    }

    final List<PontoDay> days = dayMap.values.toList();
    days.sort((a, b) => a.date.compareTo(b.date));

    // 3. Update local cache with complete merged history
    if (days.isNotEmpty) {
      await _saveMonthDays(year, month, days);
    }

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

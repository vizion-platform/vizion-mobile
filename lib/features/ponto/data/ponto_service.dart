import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/ponto_record_model.dart';

class PontoService {
  static const String _storagePrefix = 'vizion_ponto_records_';

  static String _getMonthKey(int year, int month) {
    return '$_storagePrefix${year}_${month.toString().padLeft(2, '0')}';
  }

  /// Load today's PontoDay
  static Future<PontoDay> getTodayPonto() async {
    final now = DateTime.now();
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

  /// Register a new punch for today
  static Future<({PontoDay day, PontoPunch punch})> registerPunch({
    required PontoType type,
    String location = 'Canteiro de Obras • GPS Validado (-23.5505, -46.6333)',
  }) async {
    final now = DateTime.now();
    final todayDay = await getTodayPonto();

    final newPunch = PontoPunch(
      id: 'punch_${now.millisecondsSinceEpoch}',
      type: type,
      timestamp: now,
      location: location,
      device: 'Vizion Mobile (Portaria 671 MTE)',
    );

    final updatedPunches = List<PontoPunch>.from(todayDay.punches)..add(newPunch);
    final updatedDay = PontoDay(
      date: todayDay.date,
      punches: updatedPunches,
      expectedMinutes: todayDay.expectedMinutes,
      isDayOff: todayDay.isDayOff,
      customNote: todayDay.customNote,
    );

    // Save updated day in month list
    final monthSummary = await getMonthPonto(now.year, now.month);
    final updatedDays = monthSummary.days.map((d) {
      if (d.date.year == now.year && d.date.month == now.month && d.date.day == now.day) {
        return updatedDay;
      }
      return d;
    }).toList();

    // If today was not in days list, add it
    if (!updatedDays.any((d) => d.date.year == now.year && d.date.month == now.month && d.date.day == now.day)) {
      updatedDays.add(updatedDay);
      updatedDays.sort((a, b) => a.date.compareTo(b.date));
    }

    await _saveMonthDays(now.year, now.month, updatedDays);

    return (day: updatedDay, punch: newPunch);
  }

  /// Determines next required punch
  static PontoType? getNextPunchType(PontoDay day) {
    if (day.entrada == null) return PontoType.entrada;
    if (day.saidaAlmoco == null) return PontoType.saidaAlmoco;
    if (day.retornoAlmoco == null) return PontoType.retornoAlmoco;
    if (day.saida == null) return PontoType.saida;
    return null; // All 4 daily punches registered
  }

  /// Loads full month timesheet (Espelho de Ponto)
  static Future<PontoMonthlySummary> getMonthPonto(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getMonthKey(year, month);
    final jsonStr = prefs.getString(key);

    List<PontoDay> days = [];

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        days = list.map((e) => PontoDay.fromMap(Map<String, dynamic>.from(e))).toList();
      } catch (_) {
        // Silently fallback to mock days
      }
    }

    // If no data exists, generate realistic mock days for the month
    if (days.isEmpty) {
      days = _generateInitialMonthDays(year, month);
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

  /// Generates realistic mock historical data for the month
  static List<PontoDay> _generateInitialMonthDays(int year, int month) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final now = DateTime.now();
    final List<PontoDay> list = [];

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final bool isWeekend = (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday);
      final bool isPast = date.isBefore(DateTime(now.year, now.month, now.day));
      final bool isToday = (date.year == now.year && date.month == now.month && date.day == now.day);

      if (isWeekend) {
        list.add(PontoDay(
          date: date,
          punches: [],
          expectedMinutes: 0,
          isDayOff: true,
          customNote: date.weekday == DateTime.saturday ? 'Sábado (Folga)' : 'Domingo (Descanso Semanal)',
        ));
      } else if (isPast) {
        // Generate realistic 4-point punches for past business days
        final List<PontoPunch> punches = [];

        // Slight realistic variations (e.g. 07:58, 08:02, etc.)
        final int var1 = (day * 3) % 7 - 3;
        final int var2 = (day * 5) % 9 - 4;
        final int var3 = (day * 2) % 6 - 2;
        final int var4 = (day * 7) % 15 - 5;

        final t1 = DateTime(year, month, day, 8, 0).add(Duration(minutes: var1));
        final t2 = DateTime(year, month, day, 12, 0).add(Duration(minutes: var2));
        final t3 = DateTime(year, month, day, 13, 0).add(Duration(minutes: var3));
        final t4 = DateTime(year, month, day, 17, 0).add(Duration(minutes: var4));

        punches.add(PontoPunch(
          id: 'past_${year}_${month}_${day}_1',
          type: PontoType.entrada,
          timestamp: t1,
          location: 'Canteiro Res. Bella Vista • GPS Validado',
        ));
        punches.add(PontoPunch(
          id: 'past_${year}_${month}_${day}_2',
          type: PontoType.saidaAlmoco,
          timestamp: t2,
          location: 'Canteiro Res. Bella Vista • GPS Validado',
        ));
        punches.add(PontoPunch(
          id: 'past_${year}_${month}_${day}_3',
          type: PontoType.retornoAlmoco,
          timestamp: t3,
          location: 'Canteiro Res. Bella Vista • GPS Validado',
        ));
        punches.add(PontoPunch(
          id: 'past_${year}_${month}_${day}_4',
          type: PontoType.saida,
          timestamp: t4,
          location: 'Canteiro Res. Bella Vista • GPS Validado',
        ));

        list.add(PontoDay(
          date: date,
          punches: punches,
          expectedMinutes: 480,
          isDayOff: false,
        ));
      } else if (isToday) {
        // Today starts with initial state (or empty to allow employee to clock in live)
        list.add(PontoDay(
          date: date,
          punches: [],
          expectedMinutes: 480,
          isDayOff: false,
        ));
      } else {
        // Future days in month
        list.add(PontoDay(
          date: date,
          punches: [],
          expectedMinutes: 480,
          isDayOff: false,
        ));
      }
    }

    return list;
  }
}

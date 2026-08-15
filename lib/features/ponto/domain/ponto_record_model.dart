enum PontoType {
  entrada,
  saidaAlmoco,
  retornoAlmoco,
  saida,
  extra;

  String get label {
    switch (this) {
      case PontoType.entrada:
        return 'Entrada';
      case PontoType.saidaAlmoco:
        return 'Saída Almoço';
      case PontoType.retornoAlmoco:
        return 'Volta Almoço';
      case PontoType.saida:
        return 'Saída';
      case PontoType.extra:
        return 'Ponto Extra';
    }
  }

  String get actionLabel {
    switch (this) {
      case PontoType.entrada:
        return 'deslize para registrar entrada';
      case PontoType.saidaAlmoco:
        return 'deslize para pausa almoço';
      case PontoType.retornoAlmoco:
        return 'deslize para volta almoço';
      case PontoType.saida:
        return 'deslize para registrar saída';
      case PontoType.extra:
        return 'deslize para registrar ponto';
    }
  }

  String get defaultExpectedTime {
    switch (this) {
      case PontoType.entrada:
        return '08:00';
      case PontoType.saidaAlmoco:
        return '12:00';
      case PontoType.retornoAlmoco:
        return '13:00';
      case PontoType.saida:
        return '17:00';
      case PontoType.extra:
        return '--:--';
    }
  }
}

class PontoPunch {
  final String id;
  final PontoType type;
  final DateTime timestamp;
  final String location;
  final String device;
  final String hashReceipt;

  PontoPunch({
    required this.id,
    required this.type,
    required this.timestamp,
    this.location = 'Canteiro de Obras • GPS Validado',
    this.device = 'Vizion Mobile App (Portaria 671)',
    String? hashReceipt,
  }) : hashReceipt = hashReceipt ?? _generateHash(id, timestamp);

  static String _generateHash(String id, DateTime time) {
    return 'VZN-${time.millisecondsSinceEpoch.toRadixString(16).toUpperCase()}-${id.hashCode.toRadixString(16).toUpperCase().padLeft(6, '0')}';
  }

  String get formattedTimeOnlyMin {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get formattedTimeWithSec {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'location': location,
      'device': device,
      'hashReceipt': hashReceipt,
    };
  }

  factory PontoPunch.fromMap(Map<String, dynamic> map) {
    return PontoPunch(
      id: map['id'] ?? '',
      type: PontoType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PontoType.entrada,
      ),
      timestamp: DateTime.parse(map['timestamp']),
      location: map['location'] ?? 'Canteiro de Obras • GPS Validado',
      device: map['device'] ?? 'Vizion Mobile App',
      hashReceipt: map['hashReceipt'],
    );
  }
}

class PontoDay {
  final DateTime date;
  final List<PontoPunch> punches;
  final int expectedMinutes;
  final bool isDayOff;
  final String? customNote;

  PontoDay({
    required this.date,
    required this.punches,
    this.expectedMinutes = 480, // 8h
    this.isDayOff = false,
    this.customNote,
  });

  PontoPunch? get entrada => punches.where((p) => p.type == PontoType.entrada).firstOrNull;
  PontoPunch? get saidaAlmoco => punches.where((p) => p.type == PontoType.saidaAlmoco).firstOrNull;
  PontoPunch? get retornoAlmoco => punches.where((p) => p.type == PontoType.retornoAlmoco).firstOrNull;
  PontoPunch? get saida => punches.where((p) => p.type == PontoType.saida).firstOrNull;

  /// Calculates total minutes worked on this day
  int get workedMinutes {
    if (isDayOff || punches.isEmpty) return 0;

    int minutes = 0;

    // Period 1: Entrada -> Saída Almoço (or now / next punch)
    if (entrada != null) {
      if (saidaAlmoco != null) {
        minutes += saidaAlmoco!.timestamp.difference(entrada!.timestamp).inMinutes;
      } else if (saida != null) {
        // Direct exit without lunch break punch
        minutes += saida!.timestamp.difference(entrada!.timestamp).inMinutes;
      } else {
        // Active shift 1
        final now = DateTime.now();
        if (_isToday(date)) {
          final diff = now.difference(entrada!.timestamp).inMinutes;
          minutes += diff > 0 ? diff : 0;
        }
      }
    }

    // Period 2: Retorno Almoço -> Saída (or now)
    if (retornoAlmoco != null) {
      if (saida != null) {
        minutes += saida!.timestamp.difference(retornoAlmoco!.timestamp).inMinutes;
      } else {
        // Active shift 2
        final now = DateTime.now();
        if (_isToday(date)) {
          final diff = now.difference(retornoAlmoco!.timestamp).inMinutes;
          minutes += diff > 0 ? diff : 0;
        }
      }
    }

    return minutes > 0 ? minutes : 0;
  }

  /// Balance in minutes (+ or - compared to 8h)
  int get balanceMinutes {
    if (isDayOff) {
      return workedMinutes; // all worked is extra
    }
    if (punches.isEmpty) {
      // If it's a weekday in past, it's missing hours
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      if (date.isBefore(todayDate) && date.weekday <= 5) {
        return -expectedMinutes;
      }
      return 0;
    }
    // Completed day or ended
    if (saida != null) {
      return workedMinutes - expectedMinutes;
    }
    // In progress today:
    return workedMinutes - expectedMinutes;
  }

  String get formattedWorkedHours {
    final int m = workedMinutes;
    final int hours = m ~/ 60;
    final int mins = m % 60;
    return '${hours.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m';
  }

  String get formattedBalanceHours {
    final int b = balanceMinutes;
    final String sign = b >= 0 ? '+' : '-';
    final int absMinutes = b.abs();
    final int hours = absMinutes ~/ 60;
    final int mins = absMinutes % 60;
    return '$sign${hours.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m';
  }

  String get statusLabel {
    if (isDayOff) return 'Folga / Fim de Semana';
    if (punches.isEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (date.isBefore(today)) return 'Falta / Sem Registro';
      if (_isToday(date)) return 'Não Iniciado';
      return 'Previsto';
    }
    if (saida != null) {
      if (balanceMinutes > 15) return 'Hora Extra';
      if (balanceMinutes < -15) return 'Jornada Parcial';
      return 'Normal';
    }
    if (retornoAlmoco != null) return 'Turno Tarde';
    if (saidaAlmoco != null) return 'Pausa Almoço';
    if (entrada != null) return 'Turno Manhã';
    return 'Incompleto';
  }

  static bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'punches': punches.map((p) => p.toMap()).toList(),
      'expectedMinutes': expectedMinutes,
      'isDayOff': isDayOff,
      'customNote': customNote,
    };
  }

  factory PontoDay.fromMap(Map<String, dynamic> map) {
    final punchesList = (map['punches'] as List<dynamic>?)
            ?.map((e) => PontoPunch.fromMap(Map<String, dynamic>.from(e)))
            .toList() ??
        [];

    return PontoDay(
      date: DateTime.parse(map['date']),
      punches: punchesList,
      expectedMinutes: map['expectedMinutes'] ?? 480,
      isDayOff: map['isDayOff'] ?? false,
      customNote: map['customNote'],
    );
  }
}

class PontoMonthlySummary {
  final int year;
  final int month;
  final List<PontoDay> days;

  PontoMonthlySummary({
    required this.year,
    required this.month,
    required this.days,
  });

  int get totalWorkedMinutes {
    return days.fold(0, (sum, day) => sum + day.workedMinutes);
  }

  int get totalExpectedMinutes {
    return days.fold(0, (sum, day) => sum + (day.isDayOff ? 0 : day.expectedMinutes));
  }

  int get totalBalanceMinutes {
    int balance = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var day in days) {
      if (day.date.isAfter(today)) continue;
      balance += day.balanceMinutes;
    }
    return balance;
  }

  int get completedDaysCount {
    return days.where((d) => d.punches.isNotEmpty && d.saida != null).length;
  }

  int get extraHoursMinutes {
    int extra = 0;
    for (var day in days) {
      if (day.balanceMinutes > 0) {
        extra += day.balanceMinutes;
      }
    }
    return extra;
  }

  int get delayMinutes {
    int delay = 0;
    for (var day in days) {
      if (day.balanceMinutes < 0) {
        delay += day.balanceMinutes.abs();
      }
    }
    return delay;
  }

  String formatMinutes(int minutes) {
    final int hours = minutes ~/ 60;
    final int mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m';
  }

  String formatBalance(int minutes) {
    final String sign = minutes >= 0 ? '+' : '-';
    final int absM = minutes.abs();
    final int hours = absM ~/ 60;
    final int mins = absM % 60;
    return '$sign${hours.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m';
  }
}

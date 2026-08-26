import 'package:flutter/material.dart';

class AgendaTask {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final String category;
  final int colorHex;
  final bool isCompleted;
  final String priority;

  const AgendaTask({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.category,
    required this.colorHex,
    this.isCompleted = false,
    this.priority = 'Média',
  });

  /// Checks if this task spans across the given target calendar day
  bool spansDay(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    return (target.isAfter(start) || target.isAtSameMomentAs(start)) &&
           (target.isBefore(end) || target.isAtSameMomentAs(end));
  }

  /// Calculates total duration of task in days
  int get durationInDays {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return end.difference(start).inDays + 1;
  }

  AgendaTask copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    int? colorHex,
    bool? isCompleted,
    String? priority,
  }) {
    return AgendaTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      category: category ?? this.category,
      colorHex: colorHex ?? this.colorHex,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'category': category,
      'colorHex': colorHex,
      'isCompleted': isCompleted,
      'priority': priority,
    };
  }

  factory AgendaTask.fromMap(Map<String, dynamic> map) {
    DateTime parsedStart;
    DateTime parsedEnd;

    final startRaw = map['startDate'] ?? map['dataInicio'] ?? map['data_inicio'] ?? map['date'];
    if (startRaw != null) {
      parsedStart = DateTime.parse(startRaw.toString());
    } else {
      parsedStart = DateTime.now();
    }

    final endRaw = map['endDate'] ?? map['dataFim'] ?? map['data_fim'];
    if (endRaw != null) {
      parsedEnd = DateTime.parse(endRaw.toString());
    } else {
      parsedEnd = parsedStart;
    }

    final dynamic rawColor = map['colorHex'] ?? map['corHex'] ?? map['cor_hex'];
    int parsedColorHex = 0xFF4285F4;
    if (rawColor is int) {
      parsedColorHex = rawColor;
    } else if (rawColor is num) {
      parsedColorHex = rawColor.toInt();
    } else if (rawColor is String) {
      parsedColorHex = int.tryParse(rawColor) ?? 0xFF4285F4;
    }

    return AgendaTask(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? map['titulo'] ?? '',
      description: map['description'] ?? map['descricao'] ?? '',
      startDate: parsedStart,
      endDate: parsedEnd,
      category: map['category'] ?? map['categoria'] ?? 'Geral',
      colorHex: parsedColorHex,
      isCompleted: map['isCompleted'] == true || map['concluida'] == true,
      priority: map['priority'] ?? map['prioridade'] ?? 'Média',
    );
  }

  Color get color => Color(colorHex);
}

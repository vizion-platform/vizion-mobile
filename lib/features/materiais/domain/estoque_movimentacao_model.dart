import 'package:flutter/material.dart';

class EstoqueMovimentacao {
  final String id;
  final String obraNome;
  final String materialNome;
  final String tipo; // 'ENTRADA', 'SAIDA', 'AJUSTE'
  final double quantidade;
  final String unidade;
  final String responsavel;
  final DateTime data;
  final String origemDestino;

  EstoqueMovimentacao({
    required this.id,
    required this.obraNome,
    required this.materialNome,
    required this.tipo,
    required this.quantidade,
    required this.unidade,
    required this.responsavel,
    required this.data,
    required this.origemDestino,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'obraNome': obraNome,
      'materialNome': materialNome,
      'tipo': tipo,
      'quantidade': quantidade,
      'unidade': unidade,
      'responsavel': responsavel,
      'data': data.toIso8601String(),
      'origemDestino': origemDestino,
    };
  }

  factory EstoqueMovimentacao.fromJson(Map<String, dynamic> json) {
    return EstoqueMovimentacao(
      id: json['id'] ?? '',
      obraNome: json['obraNome'] ?? 'Residencial Bella Vista',
      materialNome: json['materialNome'] ?? '',
      tipo: json['tipo'] ?? 'ENTRADA',
      quantidade: (json['quantidade'] as num?)?.toDouble() ?? 0.0,
      unidade: json['unidade'] ?? 'Unidades',
      responsavel: json['responsavel'] ?? 'Almoxarife',
      data: json['data'] != null ? DateTime.parse(json['data']) : DateTime.now(),
      origemDestino: json['origemDestino'] ?? '',
    );
  }

  Color get tipoColor {
    switch (tipo) {
      case 'ENTRADA':
        return Colors.greenAccent;
      case 'SAIDA':
        return Colors.orangeAccent;
      case 'AJUSTE':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  IconData get tipoIcon {
    switch (tipo) {
      case 'ENTRADA':
        return Icons.file_download_outlined;
      case 'SAIDA':
        return Icons.file_upload_outlined;
      case 'AJUSTE':
        return Icons.sync_alt;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}

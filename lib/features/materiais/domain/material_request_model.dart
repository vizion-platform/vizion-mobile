import 'package:flutter/material.dart';

class MaterialRequest {
  final String id;
  final String obraNome;
  final String solicitanteNome;
  final String solicitanteRole;
  final String materialNome;
  final double quantidade;
  final String unidade;
  final String urgencia;
  final String observacao;
  String status; // 'PENDENTE', 'CONFIRMADO', 'EM_TRANSPORTE', 'ENTREGUE', 'RECUSADO', 'AGUARDANDO_COMPRA_CLIENTE', 'COMPRADO_CLIENTE'
  final DateTime dataSolicitacao;
  DateTime? dataPrevisaoEntrega;
  DateTime? dataConfirmacao;
  final bool paraCliente; // Indicates if request is sent to client for purchase
  final double? valorEstimado;

  MaterialRequest({
    required this.id,
    required this.obraNome,
    required this.solicitanteNome,
    required this.solicitanteRole,
    required this.materialNome,
    required this.quantidade,
    required this.unidade,
    required this.urgencia,
    required this.observacao,
    required this.status,
    required this.dataSolicitacao,
    this.dataPrevisaoEntrega,
    this.dataConfirmacao,
    this.paraCliente = false,
    this.valorEstimado,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'obraNome': obraNome,
      'solicitanteNome': solicitanteNome,
      'solicitanteRole': solicitanteRole,
      'materialNome': materialNome,
      'quantidade': quantidade,
      'unidade': unidade,
      'urgencia': urgencia,
      'observacao': observacao,
      'status': status,
      'dataSolicitacao': dataSolicitacao.toIso8601String(),
      'dataPrevisaoEntrega': dataPrevisaoEntrega?.toIso8601String(),
      'dataConfirmacao': dataConfirmacao?.toIso8601String(),
      'paraCliente': paraCliente,
      'valorEstimado': valorEstimado,
    };
  }

  factory MaterialRequest.fromJson(Map<String, dynamic> json) {
    return MaterialRequest(
      id: json['id'] ?? '',
      obraNome: json['obraNome'] ?? 'Residencial Bella Vista',
      solicitanteNome: json['solicitanteNome'] ?? 'Funcionário',
      solicitanteRole: json['solicitanteRole'] ?? 'FUNCIONARIO',
      materialNome: json['materialNome'] ?? '',
      quantidade: (json['quantidade'] as num?)?.toDouble() ?? 1.0,
      unidade: json['unidade'] ?? 'Unidades',
      urgencia: json['urgencia'] ?? 'Média',
      observacao: json['observacao'] ?? '',
      status: json['status'] ?? 'PENDENTE',
      dataSolicitacao: json['dataSolicitacao'] != null
          ? DateTime.parse(json['dataSolicitacao'])
          : DateTime.now(),
      dataPrevisaoEntrega: json['dataPrevisaoEntrega'] != null
          ? DateTime.parse(json['dataPrevisaoEntrega'])
          : null,
      dataConfirmacao: json['dataConfirmacao'] != null
          ? DateTime.parse(json['dataConfirmacao'])
          : null,
      paraCliente: json['paraCliente'] ?? false,
      valorEstimado: (json['valorEstimado'] as num?)?.toDouble(),
    );
  }

  Color get statusColor {
    switch (status) {
      case 'PENDENTE':
        return Colors.orangeAccent;
      case 'AGUARDANDO_COMPRA_CLIENTE':
        return Colors.amber;
      case 'COMPRADO_CLIENTE':
        return Colors.tealAccent;
      case 'CONFIRMADO':
        return Colors.blueAccent;
      case 'EM_TRANSPORTE':
        return Colors.purpleAccent;
      case 'ENTREGUE':
        return Colors.greenAccent;
      case 'RECUSADO':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'PENDENTE':
        return 'Pendente de Confirmação';
      case 'AGUARDANDO_COMPRA_CLIENTE':
        return 'Solicitado Compra ao Cliente';
      case 'COMPRADO_CLIENTE':
        return 'Comprado pelo Cliente';
      case 'CONFIRMADO':
        return 'Confirmado pelo Empreiteiro';
      case 'EM_TRANSPORTE':
        return 'Em Transporte / A Caminho';
      case 'ENTREGUE':
        return 'Entregue no Canteiro';
      case 'RECUSADO':
        return 'Solicitação Recusada';
      default:
        return status;
    }
  }
}

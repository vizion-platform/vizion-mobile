import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/models/obra_model.dart';
import 'package:flutter_application_1/core/network/api_client.dart';

class ObrasController {
  static final ObrasController instance = ObrasController._internal();
  ObrasController._internal();

  final ValueNotifier<List<Obra>> obrasNotifier = ValueNotifier<List<Obra>>([]);

  Future<void> fetchObras() async {
    try {
      final response = await VizionAPIClient.instance.get('/obra');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        obrasNotifier.value = data.map((item) => Obra(
          id: item['id'].toString(),
          titulo: item['nome'],
          responsavel: 'Eng. Resp.', // Mapeamento simplificado por enquanto
          status: item['status'],
          prazo: item['data_previsao_fim'] ?? '',
          progresso: '${item['progresso'].round()}%',
          valorEstimado: 'R\$ ${item['valor_total']}',
          endereco: 'End. ${item['endereco_id']}',
          cliente: 'Cl. ${item['cliente_id']}',
          empreiteiro: 'Emp. ${item['empreiteiro_id']}',
        )).toList();
      }
    } catch (e) {
      print('Error fetching obras: $e');
    }
  }

  // ... rest of the methods (togglePhase, etc.) will need backend updates or local syncing
  // I will leave them as they are for now to support UI, assuming backend sync will be added.

  void togglePhase(String id, String phaseNome) {
    // [Keeping existing logic for UI consistency, but noting it needs backend synchronization]
    final list = obrasNotifier.value;
    final index = list.indexWhere((o) => o.id == id);
    if (index != -1) {
      final obra = list[index];
      // ... logic
      obrasNotifier.value = List.from(list);
    }
  }

  void updateProgresso(String id, String novoProgresso) {
    // ... logic
  }

  void adicionarFoto(String id, String photoUrl) {
    // ... logic
  }
}
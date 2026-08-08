import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/material_request_model.dart';
import '../domain/estoque_movimentacao_model.dart';

class MaterialService {
  static const String _requestsKey = 'vizion_material_requests_v1';
  static const String _estoqueKey = 'vizion_estoque_history_v1';

  /// Initial Seed Requests for realistic showcase
  static List<MaterialRequest> get _initialRequests => [
    MaterialRequest(
      id: 'req_105',
      obraNome: 'Residencial Bella Vista',
      solicitanteNome: 'Eng. Felipe (Empreiteiro)',
      solicitanteRole: 'EMPREITEIRO',
      materialNome: 'Porcelanato Polido 80x80cm (Caixas)',
      quantidade: 45,
      unidade: 'Caixas',
      urgencia: 'Alta',
      observacao: 'Material em falta no estoque! Solicitação enviada ao cliente para compra do acabamento da Suíte Máster.',
      status: 'AGUARDANDO_COMPRA_CLIENTE',
      dataSolicitacao: DateTime.now().subtract(const Duration(hours: 2)),
      paraCliente: true,
      valorEstimado: 3850.00,
    ),
    MaterialRequest(
      id: 'req_101',
      obraNome: 'Residencial Bella Vista',
      solicitanteNome: 'Carlos Silva (Encarregado)',
      solicitanteRole: 'FUNCIONARIO',
      materialNome: 'Cimento CP II-Z-32 (Sacos 50kg)',
      quantidade: 50,
      unidade: 'Sacos',
      urgencia: 'Alta',
      observacao: 'Urgente para a concretagem das sapatas da Fase 2',
      status: 'PENDENTE',
      dataSolicitacao: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    MaterialRequest(
      id: 'req_102',
      obraNome: 'Residencial Bella Vista',
      solicitanteNome: 'Marcos Souza (Pedreiro)',
      solicitanteRole: 'FUNCIONARIO',
      materialNome: 'Areia Média Lavada',
      quantidade: 12,
      unidade: 'm³',
      urgencia: 'Média',
      observacao: 'Para alvenaria de vedação do 1º pavimento',
      status: 'CONFIRMADO',
      dataSolicitacao: DateTime.now().subtract(const Duration(days: 1)),
      dataConfirmacao: DateTime.now().subtract(const Duration(hours: 12)),
      dataPrevisaoEntrega: DateTime.now().add(const Duration(days: 1)),
    ),
    MaterialRequest(
      id: 'req_103',
      obraNome: 'Residencial Bella Vista',
      solicitanteNome: 'João Oliveira (Eletricista)',
      solicitanteRole: 'FUNCIONARIO',
      materialNome: 'Eletroduto Flexível Corrugado 3/4"',
      quantidade: 200,
      unidade: 'Metros',
      urgencia: 'Média',
      observacao: 'Passagem de cabos da prumada principal',
      status: 'EM_TRANSPORTE',
      dataSolicitacao: DateTime.now().subtract(const Duration(days: 2)),
      dataConfirmacao: DateTime.now().subtract(const Duration(days: 1)),
      dataPrevisaoEntrega: DateTime.now().add(const Duration(hours: 5)),
    ),
    MaterialRequest(
      id: 'req_104',
      obraNome: 'Residencial Bella Vista',
      solicitanteNome: 'Carlos Silva (Encarregado)',
      solicitanteRole: 'FUNCIONARIO',
      materialNome: 'Aço CA-50 10mm (Barra 12m)',
      quantidade: 80,
      unidade: 'Barras',
      urgencia: 'Baixa',
      observacao: 'Estoque de reserva para armação das vigas',
      status: 'ENTREGUE',
      dataSolicitacao: DateTime.now().subtract(const Duration(days: 4)),
      dataConfirmacao: DateTime.now().subtract(const Duration(days: 3)),
      dataPrevisaoEntrega: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  /// Initial Seed Stock Movements History
  static List<EstoqueMovimentacao> get _initialEstoque => [
    EstoqueMovimentacao(
      id: 'est_201',
      obraNome: 'Residencial Bella Vista',
      materialNome: 'Aço CA-50 10mm (Barra 12m)',
      tipo: 'ENTRADA',
      quantidade: 80,
      unidade: 'Barras',
      responsavel: 'Almoxarifado Central',
      data: DateTime.now().subtract(const Duration(days: 1)),
      origemDestino: 'Fornecedor ArcelorMittal - NF #48192',
    ),
    EstoqueMovimentacao(
      id: 'est_202',
      obraNome: 'Residencial Bella Vista',
      materialNome: 'Cimento CP II-Z-32 (50kg)',
      tipo: 'SAIDA',
      quantidade: 30,
      unidade: 'Sacos',
      responsavel: 'Carlos Silva (Encarregado)',
      data: DateTime.now().subtract(const Duration(hours: 18)),
      origemDestino: 'Aplicação na Fundação e Sapatas',
    ),
    EstoqueMovimentacao(
      id: 'est_203',
      obraNome: 'Residencial Bella Vista',
      materialNome: 'Tijolo Cerâmico 9x19x19cm',
      tipo: 'ENTRADA',
      quantidade: 5000,
      unidade: 'Unidades',
      responsavel: 'Eng. Felipe (Empreiteiro)',
      data: DateTime.now().subtract(const Duration(days: 3)),
      origemDestino: 'Cerealista & Cerâmica Paulista - NF #1920',
    ),
    EstoqueMovimentacao(
      id: 'est_204',
      obraNome: 'Residencial Bella Vista',
      materialNome: 'Argamassa AC-III 20kg',
      tipo: 'AJUSTE',
      quantidade: 5,
      unidade: 'Sacos',
      responsavel: 'Conferência de Inventário',
      data: DateTime.now().subtract(const Duration(days: 5)),
      origemDestino: 'Ajuste de avaria na descarga',
    ),
  ];

  /// Load all material requests
  static Future<List<MaterialRequest>> loadRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_requestsKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonString);
        return list.map((e) => MaterialRequest.fromJson(e)).toList();
      }
    } catch (e) {
      print('Erro ao carregar solicitações de materiais: $e');
    }
    // Return seed if empty
    final seed = _initialRequests;
    await saveRequests(seed);
    return seed;
  }

  /// Save material requests to local storage
  static Future<void> saveRequests(List<MaterialRequest> requests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = jsonEncode(requests.map((r) => r.toJson()).toList());
      await prefs.setString(_requestsKey, jsonString);
    } catch (e) {
      print('Erro ao salvar solicitações de materiais: $e');
    }
  }

  /// Add a new material request (Used by funcionario)
  static Future<MaterialRequest> createRequest(MaterialRequest req) async {
    final list = await loadRequests();
    list.insert(0, req);
    await saveRequests(list);
    return req;
  }

  /// Create a purchase request specifically sent to the Client
  static Future<MaterialRequest> createClientPurchaseRequest({
    required String obraNome,
    required String solicitanteNome,
    required String solicitanteRole,
    required String materialNome,
    required double quantidade,
    required String unidade,
    required String urgencia,
    required String observacao,
    double? valorEstimado,
  }) async {
    final req = MaterialRequest(
      id: 'req_cli_${DateTime.now().millisecondsSinceEpoch}',
      obraNome: obraNome,
      solicitanteNome: solicitanteNome,
      solicitanteRole: solicitanteRole,
      materialNome: materialNome,
      quantidade: quantidade,
      unidade: unidade,
      urgencia: urgencia,
      observacao: observacao,
      status: 'AGUARDANDO_COMPRA_CLIENTE',
      dataSolicitacao: DateTime.now(),
      paraCliente: true,
      valorEstimado: valorEstimado,
    );
    final list = await loadRequests();
    list.insert(0, req);
    await saveRequests(list);
    return req;
  }

  /// Update request status (Used by empreiteiro or cliente)
  static Future<bool> updateRequestStatus(
    String requestId,
    String newStatus, {
    DateTime? previsaoEntrega,
  }) async {
    final list = await loadRequests();
    final index = list.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      list[index].status = newStatus;
      if (newStatus == 'CONFIRMADO' || newStatus == 'COMPRADO_CLIENTE') {
        list[index].dataConfirmacao = DateTime.now();
        list[index].dataPrevisaoEntrega = previsaoEntrega ?? DateTime.now().add(const Duration(days: 2));
      }
      await saveRequests(list);

      // If delivered or confirmed or purchased by client, also register in inventory history
      if (newStatus == 'CONFIRMADO' || newStatus == 'ENTREGUE' || newStatus == 'COMPRADO_CLIENTE') {
        await addEstoqueMovimentacao(
          EstoqueMovimentacao(
            id: 'est_${DateTime.now().millisecondsSinceEpoch}',
            obraNome: list[index].obraNome,
            materialNome: list[index].materialNome,
            tipo: 'ENTRADA',
            quantidade: list[index].quantidade,
            unidade: list[index].unidade,
            responsavel: list[index].solicitanteNome,
            data: DateTime.now(),
            origemDestino: newStatus == 'COMPRADO_CLIENTE'
                ? 'Material comprado diretamente pelo Cliente'
                : 'Pedido confirmado pelo Empreiteiro',
          ),
        );
      }
      return true;
    }
    return false;
  }

  /// Load stock movement history (Used by cliente, empreiteiro, etc.)
  static Future<List<EstoqueMovimentacao>> loadEstoqueHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_estoqueKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonString);
        return list.map((e) => EstoqueMovimentacao.fromJson(e)).toList();
      }
    } catch (e) {
      print('Erro ao carregar histórico de estoque: $e');
    }
    final seed = _initialEstoque;
    await saveEstoqueHistory(seed);
    return seed;
  }

  /// Save stock history
  static Future<void> saveEstoqueHistory(List<EstoqueMovimentacao> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = jsonEncode(history.map((e) => e.toJson()).toList());
      await prefs.setString(_estoqueKey, jsonString);
    } catch (e) {
      print('Erro ao salvar histórico de estoque: $e');
    }
  }

  /// Add stock movement log
  static Future<void> addEstoqueMovimentacao(EstoqueMovimentacao mov) async {
    final list = await loadEstoqueHistory();
    list.insert(0, mov);
    await saveEstoqueHistory(list);
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_service.dart';

class MaterialRequestScreen extends StatefulWidget {
  final int? obraId;

  const MaterialRequestScreen({super.key, this.obraId});

  @override
  State<MaterialRequestScreen> createState() => _MaterialRequestScreenState();
}

class _MaterialRequestScreenState extends State<MaterialRequestScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _solicitacoes = [];
  final String _userRole = AuthService.role ?? 'FUNCIONARIO';

  @override
  void initState() {
    super.initState();
    _loadSolicitacoes();
  }

  Future<void> _loadSolicitacoes() async {
    setState(() => _isLoading = true);
    final data = await AuthService.fetchSolicitacoesMaterial(obraId: widget.obraId);
    if (mounted) {
      setState(() {
        _solicitacoes = data;
        _isLoading = false;
      });
    }
  }

  bool get _canApprove =>
      _userRole == 'SUPERVISOR' || _userRole == 'ADMIN' || _userRole == 'ALMOXARIFE';

  Future<void> _showNovaSolicitacaoDialog() async {
    final justificativaCtrl = TextEditingController();
    final qtdCtrl = TextEditingController(text: '10');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.gridLine),
          ),
          title: const Text('Nova Solicitação de Material', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: justificativaCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Justificativa / Motivo',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.gridLine),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.primaryGold),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtdCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Quantidade Estimada',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.gridLine),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.primaryGold),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
              onPressed: () async {
                if (justificativaCtrl.text.trim().isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);

                final body = {
                  'idObra': widget.obraId ?? 1,
                  'idSolicitante': AuthService.userId ?? 1,
                  'justificativa': justificativaCtrl.text.trim(),
                  'itens': [
                    {
                      'idMaterial': 1,
                      'quantidade': double.tryParse(qtdCtrl.text) ?? 10.0,
                      'unidade': 'UN',
                      'observacao': 'Solicitado via App Mobile',
                    }
                  ]
                };

                final success = await AuthService.createSolicitacaoMaterial(body);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Solicitação criada com sucesso!' : 'Erro ao criar solicitação.'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                  if (success) _loadSolicitacoes();
                }
              },
              child: const Text('SOLICITAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAprovar(int id) async {
    final success = await AuthService.aprovarSolicitacaoMaterial(id, 'Aprovado via Mobile por $_userRole');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Solicitação aprovada com sucesso!' : 'Erro ao aprovar.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) _loadSolicitacoes();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APROVADO':
        return Colors.greenAccent;
      case 'REJEITADO':
        return Colors.redAccent;
      case 'PENDENTE':
        return Colors.orangeAccent;
      case 'ENTREGUE':
        return Colors.blueAccent;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Solicitações de Material', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryGold),
            onPressed: _loadSolicitacoes,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGold,
        onPressed: _showNovaSolicitacaoDialog,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('SOLICITAR MATERIAL', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : _solicitacoes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text('Nenhuma solicitação registrada', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _solicitacoes.length,
                  itemBuilder: (context, index) {
                    final sol = _solicitacoes[index];
                    final status = sol['status'] ?? 'PENDENTE';
                    final color = _getStatusColor(status);
                    final itens = (sol['itens'] as List?) ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Solicitação #${sol['id']}",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  AuthService.formatStatus(status),
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (sol['nomeSolicitante'] != null)
                            Text(
                              "Solicitado por: ${sol['nomeSolicitante']}",
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          if (sol['justificativa'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                "Motivo: ${sol['justificativa']}",
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ),
                          const SizedBox(height: 10),
                          const Text('Itens da solicitação:', style: TextStyle(color: AppColors.primaryGold, fontSize: 12, fontWeight: FontWeight.bold)),
                          ...itens.map((item) => Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  "• ${item['nomeMaterial'] ?? 'Material'}: ${item['quantidade']} ${item['unidade'] ?? ''}",
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              )),
                          if (_canApprove && status == 'PENDENTE') ...[
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _handleAprovar(sol['id']),
                                icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                                label: const Text('APROVAR SOLICITAÇÃO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

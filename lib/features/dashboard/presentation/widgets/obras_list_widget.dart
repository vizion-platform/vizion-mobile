import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/auth_service.dart';
import 'criar_obra_modal.dart';
import '../obra_details_screen.dart';

class ObrasListWidget extends StatefulWidget {
  const ObrasListWidget({super.key});

  @override
  State<ObrasListWidget> createState() => _ObrasListWidgetState();
}

class _ObrasListWidgetState extends State<ObrasListWidget> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _obras = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _refreshObras();
  }

  Future<void> _refreshObras() async {
    try {
      final list = await AuthService.fetchObras();
      if (mounted) {
        setState(() {
          _obras = list;
          _isLoading = false;
          _errorMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao carregar lista de obras do servidor.';
        });
      }
    }
  }

  String _formatCurrency(double value) {
    String valueStr = value.toStringAsFixed(2);
    List<String> parts = valueStr.split('.');
    String whole = parts[0];
    String decimal = parts[1];
    
    String wholeFormatted = '';
    int count = 0;
    for (int i = whole.length - 1; i >= 0; i--) {
      wholeFormatted = whole[i] + wholeFormatted;
      count++;
      if (count == 3 && i > 0) {
        wholeFormatted = '.$wholeFormatted';
        count = 0;
      }
    }
    return 'R\$ $wholeFormatted,$decimal';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      DateTime dt = DateTime.parse(dateStr);
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PLANEJADO':
      case 'PLANEJAMENTO':
        return AppColors.primaryGold;
      case 'EM_EXECUCAO':
      case 'EXECUCAO':
      case 'EM ANDAMENTO':
        return Colors.blueAccent;
      case 'FINALIZADO':
      case 'CONCLUIDO':
        return Colors.greenAccent;
      default:
        return Colors.orangeAccent;
    }
  }

  void _showObraDetails(Map<String, dynamic> obra) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final val = (obra['valor_total_estimado'] as num?)?.toDouble() ?? 0.0;
        final statusColor = _getStatusColor(obra['status'] ?? '');
        return Padding(
          padding: EdgeInsets.only(
            left: 24.0, 
            right: 24.0, 
            top: 16.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32.0
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gridLine,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.apartment, color: AppColors.primaryGold, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          obra['nome_projeto'] ?? 'Sem Nome',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID do Registro: #${obra['id'] ?? 'N/A'}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              
              // Informações estruturadas
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gridLine, width: 1.5),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Orçamento Estimado', _formatCurrency(val), Icons.monetization_on_outlined, AppColors.primaryGold),
                    const Divider(color: AppColors.gridLine, height: 24),
                    _buildDetailRow('Status do Canteiro', obra['status'] ?? 'PLANEJAMENTO', Icons.info_outline, statusColor),
                    const Divider(color: AppColors.gridLine, height: 24),
                    _buildDetailRow('Data de Início', _formatDate(obra['data_inicio']), Icons.calendar_today_outlined, Colors.white70),
                    const Divider(color: AppColors.gridLine, height: 24),
                    _buildDetailRow('Previsão de Conclusão', _formatDate(obra['data_previsao_entrega']), Icons.date_range_outlined, Colors.white70),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gridLine,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('RETORNAR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _abrirModalCriarObra() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CriarObraModal(
        onObraCriada: (novaObraData) async {
          setState(() {
            _isLoading = true;
          });
          try {
            bool success = await AuthService.createObra(novaObraData);
            if (success) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Obra cadastrada com sucesso!'), backgroundColor: Colors.green),
                );
              }
              _refreshObras();
            } else {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao cadastrar obra no servidor.'), backgroundColor: Colors.redAccent),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro de conexão: $e'), backgroundColor: Colors.redAccent),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho com o Título e o Botão Nova Obra
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestão de Obras', 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Central de controle dos canteiros.', 
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            
            // Botão Nova Obra
            if (AuthService.role == 'EMPREITEIRO' || AuthService.role == null)
              ElevatedButton.icon(
                onPressed: _abrirModalCriarObra,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('NOVA OBRA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  elevation: 4,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Listagem Dinâmica das Obras
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
              : _errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off_outlined, color: AppColors.textSecondary, size: 40),
                          const SizedBox(height: 12),
                          Text(_errorMessage, style: const TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshObras,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
                            child: const Text('Recarregar', style: TextStyle(color: Colors.black)),
                          )
                        ],
                      ),
                    )
                  : _obras.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.construction_outlined, color: AppColors.textSecondary, size: 48),
                              SizedBox(height: 12),
                              Text('Nenhuma obra cadastrada no tenant ativo.', style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primaryGold,
                          backgroundColor: AppColors.surface,
                          onRefresh: _refreshObras,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _obras.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final obra = _obras[index];
                              final val = (obra['valor_total_estimado'] as num?)?.toDouble() ?? 0.0;
                              final statusColor = _getStatusColor(obra['status'] ?? '');
                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ObraDetailsScreen(obra: obra),
                                    ),
                                  ).then((_) => _refreshObras());
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.gridLine, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      )
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.gridLine),
                                        ),
                                        child: const Icon(Icons.apartment_outlined, color: AppColors.primaryGold, size: 20),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              obra['nome_projeto'] ?? 'Sem Nome', 
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Orçamento: ${_formatCurrency(val)}', 
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: statusColor.withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              obra['status'] ?? 'N/A', 
                                              style: TextStyle(
                                                color: statusColor, 
                                                fontWeight: FontWeight.bold,
                                                fontSize: 9,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Início: ${_formatDate(obra['data_inicio'])}',
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

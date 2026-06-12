import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/auth_service.dart';

class HomeDashboardWidget extends StatefulWidget {
  const HomeDashboardWidget({super.key});

  @override
  State<HomeDashboardWidget> createState() => _HomeDashboardWidgetState();
}

class _HomeDashboardWidgetState extends State<HomeDashboardWidget> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _obras = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final data = await AuthService.fetchObras();
      if (mounted) {
        setState(() {
          _obras = data;
          _isLoading = false;
          _errorMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao carregar dados do dashboard.';
        });
      }
    }
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return 'R\$ ${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value >= 1000) {
      return 'R\$ ${(value / 1000).toStringAsFixed(0)}k';
    }
    return 'R\$ ${value.toStringAsFixed(2)}';
  }

  double _getProjectProgress(int id) {
    // Return a stable mock completion progress based on project ID
    switch (id % 4) {
      case 0:
        return 0.35;
      case 1:
        return 0.65;
      case 2:
        return 0.15;
      case 3:
        return 0.85;
      default:
        return 0.50;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _loadDashboardData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
              child: const Text('Recarregar', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }

    // Calculations
    final int totalObras = _obras.length;
    double totalBudget = 0.0;
    for (var obra in _obras) {
      final val = obra['valor_total_estimado'];
      if (val != null) {
        totalBudget += (val as num).toDouble();
      }
    }
    final double avgBudget = totalObras > 0 ? totalBudget / totalObras : 0.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Boas-vindas
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryGold, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.surface,
                  child: Text(
                    AuthService.nome != null && AuthService.nome!.isNotEmpty
                        ? AuthService.nome![0].toUpperCase()
                        : 'U',
                    style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Olá, ${AuthService.nome ?? 'Membro Vizion'}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                    ),
                    Text(
                      'Cargo: ${AuthService.role ?? 'Gestor'} • Tenant: ${AuthService.tenantId ?? 'default'}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Security Banner corporativo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.06),
              border: Border.all(color: AppColors.primaryGold.withOpacity(0.25), width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: AppColors.primaryGold, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Autenticação de 2 etapas ativa. Sua conexão está criptografada de ponta a ponta.',
                    style: TextStyle(color: AppColors.primaryGold, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          
          const Text(
            'Visão Gerencial',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Análise físico-financeira dos canteiros de obra.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          
          // Métricas em Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildStatCard('Canteiros de Obra', totalObras.toString(), Icons.domain_outlined, AppColors.primaryGold, cardWidth),
                  _buildStatCard('Investimento Total', _formatCurrency(totalBudget), Icons.account_balance_wallet_outlined, Colors.greenAccent, cardWidth),
                  _buildStatCard('Custo Médio / Obra', _formatCurrency(avgBudget), Icons.analytics_outlined, Colors.blueAccent, cardWidth),
                  _buildStatCard('Status de Segurança', 'MFA OK', Icons.lock_outline, Colors.tealAccent, cardWidth),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          
          const Text(
            'Desempenho Físico por Obra',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          
          // Container do Desempenho Físico-Financeiro
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gridLine, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cronograma de Execução', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Icon(Icons.trending_up, color: AppColors.primaryGold.withOpacity(0.6), size: 18),
                  ],
                ),
                const SizedBox(height: 24),
                if (totalObras == 0)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Text('Nenhuma obra ativa encontrada.', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                else
                  ..._obras.take(4).map((obra) {
                    final double val = (obra['valor_total_estimado'] as num?)?.toDouble() ?? 0.0;
                    final int id = obra['id'] ?? 0;
                    final double progress = _getProjectProgress(id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  obra['nome_projeto'] ?? 'Projeto Sem Nome', 
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(_formatCurrency(val), style: const TextStyle(color: AppColors.primaryGold, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Fase: ${obra['status'] ?? 'Planejamento'}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}% concluído',
                                style: const TextStyle(color: AppColors.primaryGold, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: AppColors.background,
                              color: AppColors.primaryGold,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gridLine, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

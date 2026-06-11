import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class HomeDashboardWidget extends StatelessWidget {
  const HomeDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView( // Protege contra quebras em telas menores
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard Gerencial',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text('Acompanhamento físico-financeiro e alertas críticos.', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          
          // Cards Informativos lado a lado
          Row(
            children: [
              _buildStatCard('Obras Ativas', '12', Icons.construction, AppColors.primaryGold),
              const SizedBox(width: 16),
              _buildStatCard('Pendências', '05', Icons.hourglass_empty, Colors.orange),
              const SizedBox(width: 16),
              _buildStatCard('Ocorrências', '02', Icons.warning_amber_rounded, Colors.redAccent),
            ],
          ),
          const SizedBox(height: 40),
          
          const Text('Progresso da Curva S (Físico x Financeiro)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          
          // ALTURA FIXADA PARA EVITAR TELA PRETA:
          Container(
            height: 300, 
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.gridLine),
            ),
            child: Center(
              child: Icon(Icons.analytics_outlined, size: 80, color: AppColors.primaryGold.withOpacity(0.3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.gridLine),
        ),
        child: Row(
          
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
            Icon(icon, size: 30, color: iconColor),
          ],
        ),
      ),
    );
  }
}
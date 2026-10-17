import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/auth_service.dart';
import '../../domain/ponto_record_model.dart';

class PontoPunchReceiptDialog extends StatelessWidget {
  final PontoPunch punch;

  const PontoPunchReceiptDialog({super.key, required this.punch});

  @override
  Widget build(BuildContext context) {
    final employeeName = AuthService.nome ?? 'Colaborador Vizion';
    final formattedDate = _formatReceiptDate(punch.timestamp);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Icon (Vizion Gold)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryGold.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.primaryGold, width: 2),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryGold,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Ponto Registrado!',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Comprovante Eletrônico • Portaria 671 MTE',
              style: TextStyle(
                color: AppColors.primaryGold.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            // Receipt Paper simulation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.gridLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReceiptRow('Tipo de Batida:', punch.type.label, isHighlighted: true),
                  Divider(color: AppColors.gridLine, height: 16),
                  _buildReceiptRow('Horário Oficial:', punch.formattedTimeWithSec),
                  const SizedBox(height: 8),
                  _buildReceiptRow('Data:', formattedDate),
                  const SizedBox(height: 8),
                  _buildReceiptRow('Colaborador:', employeeName),
                  const SizedBox(height: 8),
                  _buildReceiptRow('Localização:', punch.location),
                  const SizedBox(height: 8),
                  _buildReceiptRow('Hash de Segurança:', punch.hashReceipt, isMono: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldFill,
                  foregroundColor: AppColors.onGold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK, ENTENDIDO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isHighlighted = false, bool isMono = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isHighlighted ? AppColors.primaryGold : AppColors.textPrimary,
              fontSize: 11,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
              fontFamily: isMono ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }

  String _formatReceiptDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    return '$d/$m/$y';
  }
}

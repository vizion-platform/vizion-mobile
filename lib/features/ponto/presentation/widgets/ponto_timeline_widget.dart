import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/ponto_record_model.dart';

class PontoTimelineWidget extends StatelessWidget {
  final PontoDay todayDay;
  final PontoType? nextPunchType;

  const PontoTimelineWidget({
    super.key,
    required this.todayDay,
    required this.nextPunchType,
  });

  @override
  Widget build(BuildContext context) {
    final stages = [
      _TimelineStage(
        type: PontoType.entrada,
        title: 'Entrada',
        subtitle: 'Início da jornada diária',
        icon: Icons.login_rounded,
        punch: todayDay.entrada,
        expectedTime: '08:00',
      ),
      _TimelineStage(
        type: PontoType.saidaAlmoco,
        title: 'Saída Almoço',
        subtitle: 'Intervalo intrajornada',
        icon: Icons.restaurant_rounded,
        punch: todayDay.saidaAlmoco,
        expectedTime: '12:00',
      ),
      _TimelineStage(
        type: PontoType.retornoAlmoco,
        title: 'Volta Almoço',
        subtitle: 'Retorno do intervalo',
        icon: Icons.work_history_rounded,
        punch: todayDay.retornoAlmoco,
        expectedTime: '13:00',
      ),
      _TimelineStage(
        type: PontoType.saida,
        title: 'Saída',
        subtitle: 'Fim do expediente',
        icon: Icons.logout_rounded,
        punch: todayDay.saida,
        expectedTime: '17:00',
      ),
    ];

    final bool isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gridLine, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.timeline_rounded, color: AppColors.primaryGold, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Linha do Tempo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 13.5 : 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  '/4 Batidas',
                  style: TextStyle(
                    color: AppColors.primaryGold,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vertical Connected Timeline Items
          ...List.generate(stages.length, (index) {
            final stage = stages[index];
            final isLast = index == stages.length - 1;
            final isCompleted = stage.punch != null;
            final isCurrent = stage.type == nextPunchType;

            return _buildTimelineItem(
              context: context,
              stage: stage,
              isCompleted: isCompleted,
              isCurrent: isCurrent,
              isLast: isLast,
              isSmallScreen: isSmallScreen,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required BuildContext context,
    required _TimelineStage stage,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
    required bool isSmallScreen,
  }) {
    final String timeDisplay = isCompleted
        ? stage.punch!.formattedTimeOnlyMin
        : stage.expectedTime;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Indicator Icon & Connecting Line
          Column(
            children: [
              // Circle Node
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isSmallScreen ? 30 : 34,
                height: isSmallScreen ? 30 : 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppColors.primaryGold.withValues(alpha: 0.2)
                      : isCurrent
                          ? AppColors.primaryGold.withValues(alpha: 0.15)
                          : const Color(0xFF1E1E1E),
                  border: Border.all(
                    color: (isCompleted || isCurrent)
                        ? AppColors.primaryGold
                        : AppColors.gridLine,
                    width: isCurrent ? 2.0 : 1.5,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.primaryGold.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check_rounded, color: AppColors.primaryGold, size: isSmallScreen ? 16 : 18)
                      : Icon(
                          stage.icon,
                          color: isCurrent ? AppColors.primaryGold : Colors.white38,
                          size: isSmallScreen ? 14 : 16,
                        ),
                ),
              ),

              // Connecting Line
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.primaryGold.withValues(alpha: 0.4)
                          : AppColors.gridLine,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(width: isSmallScreen ? 10 : 14),

          // Right: Content Details
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16.0),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 10 : 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.primaryGold.withValues(alpha: 0.06)
                      : isCompleted
                          ? const Color(0xFF1B1B1B)
                          : const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.primaryGold.withValues(alpha: 0.35)
                        : isCompleted
                            ? AppColors.gridLine
                            : Colors.white10,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  stage.title,
                                  style: TextStyle(
                                    color: isCompleted || isCurrent
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontSize: isSmallScreen ? 12.5 : 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCompleted) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'OK',
                                    style: TextStyle(
                                      color: AppColors.primaryGold,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ] else if (isCurrent) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGold.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.primaryGold.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: const Text(
                                    'PRÓXIMO',
                                    style: TextStyle(
                                      color: AppColors.primaryGold,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isCompleted
                                ? (stage.punch?.location ?? 'GPS Validado')
                                : stage.subtitle,
                            style: TextStyle(
                              color: isCompleted
                                  ? AppColors.textSecondary
                                  : Colors.white38,
                              fontSize: isSmallScreen ? 10 : 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Time badge (HH:mm format without seconds)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          timeDisplay,
                          style: TextStyle(
                            color: isCompleted
                                ? Colors.white
                                : isCurrent
                                    ? AppColors.primaryGold
                                    : AppColors.textSecondary,
                            fontSize: isSmallScreen ? 15 : 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          isCompleted ? 'registrado' : 'previsto',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: isSmallScreen ? 8.5 : 9.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStage {
  final PontoType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final PontoPunch? punch;
  final String expectedTime;

  _TimelineStage({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.punch,
    required this.expectedTime,
  });
}

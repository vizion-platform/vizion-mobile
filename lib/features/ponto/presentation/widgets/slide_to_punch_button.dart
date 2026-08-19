import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/ponto_record_model.dart';

class SlideToPunchButton extends StatefulWidget {
  final PontoType? nextPunchType;
  final VoidCallback onConfirmed;
  final bool isLoading;

  const SlideToPunchButton({
    super.key,
    required this.nextPunchType,
    required this.onConfirmed,
    this.isLoading = false,
  });

  @override
  State<SlideToPunchButton> createState() => _SlideToPunchButtonState();
}

class _SlideToPunchButtonState extends State<SlideToPunchButton>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _snapController;
  late AnimationController _pulseController;
  late Animation<double> _snapAnimation;

  double _dragPosition = 0.0;
  bool _isDragging = false;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();

    // Shimmer text animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Pulse effect on the slider knob
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Smooth snap animation (snaps forward to 100% or resets back to 0%)
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _snapAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragPosition = _snapAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    _snapController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (widget.isLoading || widget.nextPunchType == null || _hasTriggered) return;
    _snapController.stop();
    setState(() {
      _isDragging = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (widget.isLoading || widget.nextPunchType == null || _hasTriggered) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details, double maxDrag) {
    if (widget.isLoading || widget.nextPunchType == null || _hasTriggered) return;

    setState(() {
      _isDragging = false;
    });

    final double threshold = maxDrag * 0.5;

    if (_dragPosition >= threshold) {
      // Dragged past halfway: animate smoothly to end and confirm
      _hasTriggered = true;
      _snapAnimation = Tween<double>(begin: _dragPosition, end: maxDrag).animate(
        CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
      );
      _snapController.forward(from: 0.0).then((_) {
        HapticFeedback.mediumImpact();
        widget.onConfirmed();

        // Smoothly return knob to start after punch action
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            _snapAnimation = Tween<double>(begin: maxDrag, end: 0.0).animate(
              CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
            );
            _snapController.forward(from: 0.0).then((_) {
              if (mounted) {
                setState(() {
                  _hasTriggered = false;
                  _dragPosition = 0.0;
                });
              }
            });
          }
        });
      });
    } else {
      // Released before halfway: animate smoothly back to 0.0
      _snapAnimation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
        CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
      );
      _snapController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            _dragPosition = 0.0;
          });
        }
      });
    }
  }

  void _onDragCancel(double maxDrag) {
    if (_hasTriggered) return;
    setState(() {
      _isDragging = false;
    });
    _snapAnimation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );
    _snapController.forward(from: 0.0);
  }

  IconData _getKnobIcon(PontoType? type) {
    if (type == null) return Icons.check_rounded;
    switch (type) {
      case PontoType.entrada:
        return Icons.login_rounded;
      case PontoType.saidaAlmoco:
        return Icons.restaurant_rounded;
      case PontoType.retornoAlmoco:
        return Icons.work_history_rounded;
      case PontoType.saida:
        return Icons.logout_rounded;
      case PontoType.extra:
        return Icons.fingerprint_rounded;
    }
  }

  String _getSlideText(PontoType? type) {
    if (type == null) return 'jornada concluída hoje';
    return type.actionLabel;
  }

  @override
  Widget build(BuildContext context) {
    final nextType = widget.nextPunchType;
    final isCompleted = nextType == null;
    const double buttonHeight = 64.0;
    const double knobSize = 54.0;
    const double horizontalPadding = 5.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackWidth = constraints.maxWidth;
        final double maxDrag = trackWidth - knobSize - (horizontalPadding * 2);
        final double dragProgress = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

        if (isCompleted) {
          return Container(
            height: buttonHeight,
            width: trackWidth,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: AppColors.primaryGold.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.primaryGold, size: 22),
                SizedBox(width: 10),
                Text(
                  'Todos os pontos de hoje registrados!',
                  style: TextStyle(
                    color: AppColors.primaryGold,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          height: buttonHeight,
          width: trackWidth,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: AppColors.primaryGold.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // 1. Gold trail fill behind the knob
              if (_dragPosition > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _dragPosition + knobSize + horizontalPadding,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryGold.withValues(alpha: 0.3),
                          AppColors.primaryGold.withValues(alpha: 0.08),
                        ],
                      ),
                    ),
                  ),
                ),

              // 2. Shimmering text in center
              Positioned.fill(
                child: Opacity(
                  opacity: (1.0 - (dragProgress * 1.4)).clamp(0.0, 1.0),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 48, right: 16),
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return ShaderMask(
                            shaderCallback: (bounds) {
                              final double shimmerPos = _shimmerController.value;
                              return LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                stops: [
                                  (shimmerPos - 0.3).clamp(0.0, 1.0),
                                  shimmerPos.clamp(0.0, 1.0),
                                  (shimmerPos + 0.3).clamp(0.0, 1.0),
                                ],
                                colors: const [
                                  Color(0xFF7A7A7A),
                                  Color(0xFFFFFFFF),
                                  Color(0xFF7A7A7A),
                                ],
                              ).createShader(bounds);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _getSlideText(nextType),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.keyboard_double_arrow_right_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Sliding Knob (Gold circular handle matching Vizion theme)
              Positioned(
                left: horizontalPadding + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: (details) => _onDragUpdate(details, maxDrag),
                  onHorizontalDragEnd: (details) => _onDragEnd(details, maxDrag),
                  onHorizontalDragCancel: () => _onDragCancel(maxDrag),
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final double pulseScale = _isDragging ? 1.04 : 1.0 + (_pulseController.value * 0.03);
                      return Transform.scale(
                        scale: pulseScale,
                        child: Container(
                          width: knobSize,
                          height: knobSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                AppColors.primaryGold,
                                Color(0xFFB8A684),
                              ],
                              center: Alignment(-0.2, -0.2),
                              radius: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGold.withValues(alpha: 0.35),
                                blurRadius: 10 + (_pulseController.value * 5),
                                spreadRadius: _isDragging ? 2 : 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: widget.isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Icon(
                                    _getKnobIcon(nextType),
                                    color: Colors.black,
                                    size: 22,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

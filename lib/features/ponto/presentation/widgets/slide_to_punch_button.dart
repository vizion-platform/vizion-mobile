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
  late AnimationController _resetController;
  late AnimationController _pulseController;
  late Animation<double> _resetAnimation;

  double _dragPosition = 0.0;
  bool _isDragging = false;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();

    // Shimmer text animation (sweeping light)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Pulse effect on the slider knob
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Spring reset animation
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _resetAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragPosition = _resetAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    _resetController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (widget.isLoading || widget.nextPunchType == null || _hasTriggered) return;
    _resetController.stop();
    setState(() {
      _isDragging = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (widget.isLoading || widget.nextPunchType == null || _hasTriggered) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });

    // Check if reached threshold (85% of track)
    if (_dragPosition >= maxDrag * 0.85 && !_hasTriggered) {
      _hasTriggered = true;
      HapticFeedback.heavyImpact();
      widget.onConfirmed();
      // Snap to end
      setState(() {
        _dragPosition = maxDrag;
      });
      // Reset after a brief delay
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() {
            _hasTriggered = false;
            _dragPosition = 0.0;
            _isDragging = false;
          });
        }
      });
    }
  }

  void _onDragEnd(DragEndDetails details, double maxDrag) {
    if (_hasTriggered) return;
    setState(() {
      _isDragging = false;
    });
    // Snap back with smooth spring animation
    _resetAnimation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutBack),
    );
    _resetController.forward(from: 0.0);
  }

  Color _getKnobColor(PontoType? type) {
    if (type == null) return Colors.grey.shade700;
    switch (type) {
      case PontoType.entrada:
        return const Color(0xFF34C759); // iOS Call Green
      case PontoType.saidaAlmoco:
        return const Color(0xFFFF9500); // iOS Orange
      case PontoType.retornoAlmoco:
        return const Color(0xFF007AFF); // iOS Blue
      case PontoType.saida:
        return const Color(0xFFFF3B30); // iOS Red / Exit
      case PontoType.extra:
        return AppColors.primaryGold;
    }
  }

  IconData _getKnobIcon(PontoType? type) {
    if (type == null) return Icons.check_circle_outline;
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
        final knobColor = _getKnobColor(nextType);

        if (isCompleted) {
          return Container(
            height: buttonHeight,
            width: trackWidth,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4), width: 1.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 22),
                SizedBox(width: 10),
                Text(
                  'Todos os pontos de hoje registrados!',
                  style: TextStyle(
                    color: Colors.greenAccent,
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
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: knobColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: knobColor.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // 1. Trail fill behind the knob
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
                          knobColor.withValues(alpha: 0.35),
                          knobColor.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                  ),
                ),

              // 2. Shimmering "Slide to Answer" text in center
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

              // 3. Sliding Knob (iPhone Circular Answer Handle)
              Positioned(
                left: horizontalPadding + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: (details) => _onDragUpdate(details, maxDrag),
                  onHorizontalDragEnd: (details) => _onDragEnd(details, maxDrag),
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final double pulseScale = _isDragging ? 1.05 : 1.0 + (_pulseController.value * 0.04);
                      return Transform.scale(
                        scale: pulseScale,
                        child: Container(
                          width: knobSize,
                          height: knobSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                knobColor,
                                knobColor.withValues(alpha: 0.85),
                              ],
                              center: const Alignment(-0.2, -0.2),
                              radius: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: knobColor.withValues(alpha: 0.5),
                                blurRadius: 10 + (_pulseController.value * 6),
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
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _getKnobIcon(nextType),
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ],
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

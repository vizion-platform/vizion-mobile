import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class CameraSimulatorScreen extends StatefulWidget {
  final String phaseName;

  const CameraSimulatorScreen({super.key, required this.phaseName});

  @override
  State<CameraSimulatorScreen> createState() => _CameraSimulatorScreenState();
}

class _CameraSimulatorScreenState extends State<CameraSimulatorScreen> with SingleTickerProviderStateMixin {
  bool _flashOn = false;
  bool _isFrontCamera = false;
  bool _shutterActive = false;
  double _zoomLevel = 1.0;
  
  // Animation controller for the focus box pulsing effect
  late AnimationController _focusController;
  late Animation<double> _focusScale;
  Offset _focusPoint = const Offset(200, 300); // Initial position

  @override
  void initState() {
    super.initState();
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _focusScale = Tween<double>(begin: 1.4, end: 1.0).animate(
      CurvedAnimation(parent: _focusController, curve: Curves.easeInOut),
    );
    
    // Trigger focus box animation on load
    _focusController.forward();
  }

  @override
  void dispose() {
    _focusController.dispose();
    super.dispose();
  }

  void _triggerFocus(TapDownDetails details) {
    setState(() {
      _focusPoint = details.localPosition;
    });
    _focusController.reset();
    _focusController.forward();
  }

  void _capturePhoto() {
    if (_shutterActive) return;

    setState(() {
      _shutterActive = true;
    });

    // Simulated shutter flash (150ms)
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _shutterActive = false;
        });
        
        // Pass mock photo identifier representing this phase back
        final String photoIdentifier = 'mock-camera-${widget.phaseName}';
        Navigator.pop(context, photoIdentifier);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    widget.phaseName.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _flashOn ? Icons.flash_on : Icons.flash_off,
                      color: _flashOn ? AppColors.primaryGold : Colors.white70,
                      size: 22,
                    ),
                    onPressed: () => setState(() => _flashOn = !_flashOn),
                  ),
                ],
              ),
            ),

            // Viewfinder
            Expanded(
              child: GestureDetector(
                onTapDown: _triggerFocus,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Simulated construction environment graphic
                    _buildSimulatedEnvironment(),

                    // Grid Overlay (Rule of Thirds)
                    _buildCameraGrid(),

                    // Pulse Focus Indicator
                    AnimatedBuilder(
                      animation: _focusController,
                      builder: (context, child) {
                        return Positioned(
                          left: _focusPoint.dx - 32,
                          top: _focusPoint.dy - 32,
                          child: Opacity(
                            opacity: (1.0 - _focusController.value).clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: _focusScale.value,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.primaryGold, width: 1.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Center(
                                  child: Icon(Icons.filter_center_focus, color: AppColors.primaryGold, size: 14),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Zoom level indicator
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildZoomButton('0.5x', 0.5),
                          const SizedBox(width: 8),
                          _buildZoomButton('1.0x', 1.0),
                          const SizedBox(width: 8),
                          _buildZoomButton('2.0x', 2.0),
                        ],
                      ),
                    ),

                    // Shutter Flash animation overlay
                    if (_shutterActive)
                      Container(
                        color: Colors.white,
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Bar: Shutter controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Photo Library Thumbnail mockup
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: Colors.white70, size: 20),
                  ),

                  // Shutter capture button
                  GestureDetector(
                    onTap: _capturePhoto,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          margin: EdgeInsets.all(_shutterActive ? 8 : 4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Lens switcher toggle mockup
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.white70, size: 24),
                    onPressed: () => setState(() => _isFrontCamera = !_isFrontCamera),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomButton(String label, double val) {
    final active = _zoomLevel == val;
    return GestureDetector(
      onTap: () => setState(() => _zoomLevel = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryGold : Colors.black54,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? Colors.transparent : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            // Vertical lines
            Positioned(
              left: w / 3,
              top: 0,
              bottom: 0,
              child: Container(width: 0.5, color: Colors.white24),
            ),
            Positioned(
              left: (w / 3) * 2,
              top: 0,
              bottom: 0,
              child: Container(width: 0.5, color: Colors.white24),
            ),
            // Horizontal lines
            Positioned(
              left: 0,
              right: 0,
              top: h / 3,
              child: Container(height: 0.5, color: Colors.white24),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: (h / 3) * 2,
              child: Container(height: 0.5, color: Colors.white24),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSimulatedEnvironment() {
    if (_isFrontCamera) {
      return Container(
        color: AppColors.surface,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.face_retouching_natural, color: AppColors.primaryGold, size: 64),
              SizedBox(height: 12),
              Text('Visualização Selfie (Mestre de Obras)', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    Color skyColor = Colors.lightBlueAccent.shade100;
    Color groundColor = Colors.brown.shade300;
    IconData buildIcon = Icons.home;
    String label = 'Fase em Andamento';

    if (widget.phaseName.contains('Projetos')) {
      skyColor = Colors.grey.shade800;
      groundColor = Colors.blueGrey.shade900;
      buildIcon = Icons.draw_outlined;
      label = 'Projeto Arquitetônico';
    } else if (widget.phaseName.contains('Fundação')) {
      skyColor = Colors.blue.shade200;
      groundColor = Colors.brown.shade600;
      buildIcon = Icons.foundation;
      label = 'Fundação de Concreto';
    } else if (widget.phaseName.contains('Superestrutura')) {
      skyColor = Colors.blue.shade300;
      groundColor = Colors.grey.shade400;
      buildIcon = Icons.domain;
      label = 'Lajes e Vigas Concretadas';
    } else if (widget.phaseName.contains('Alvenaria')) {
      skyColor = Colors.amber.shade200;
      groundColor = Colors.brown.shade400;
      buildIcon = Icons.grid_view_outlined;
      label = 'Alvenaria de Vedação';
    } else if (widget.phaseName.contains('Acabamento')) {
      skyColor = Colors.blueGrey.shade100;
      groundColor = Colors.teal.shade300;
      buildIcon = Icons.format_paint_outlined;
      label = 'Pintura e Revestimento';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skyColor, groundColor],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(buildIcon, size: 54, color: AppColors.primaryGold),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Visão do Canteiro [Simulada]',
                style: TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

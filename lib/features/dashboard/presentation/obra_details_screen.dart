import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_service.dart';
import '../../chat/presentation/chat_room_screen.dart';
import '../../chat/data/chat_network_service.dart';

double calculatePhaseProgress(List<Map<String, dynamic>> phases) {
  if (phases.isEmpty) return 0;
  const completedStatuses = {'FINALIZADA', 'CONCLUIDA', 'CONCLUIDO'};
  final completed = phases.where((phase) => completedStatuses.contains(
    (phase['status'] ?? '').toString().trim().toUpperCase(),
  )).length;
  return completed / phases.length;
}

class ObraDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> obra;

  const ObraDetailsScreen({super.key, required this.obra});

  @override
  State<ObraDetailsScreen> createState() => _ObraDetailsScreenState();
}

class _ObraDetailsScreenState extends State<ObraDetailsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _fases = [];
  Map<int, List<Map<String, dynamic>>> _photosByPhase = {};
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadFases();
  }

  Future<void> _loadFases() async {
    try {
      final result = await Future.wait([
        AuthService.fetchFases(widget.obra['id']),
        AuthService.fetchObraPhotos(widget.obra['id']),
      ]);
      final data = result[0];
      final photos = result[1];
      final groupedPhotos = <int, List<Map<String, dynamic>>>{};
      for (final photo in photos) {
        final rawPhaseId = photo['idFase'];
        if (rawPhaseId is! num) continue;
        groupedPhotos.putIfAbsent(rawPhaseId.toInt(), () => []).add(photo);
      }
      if (mounted) {
        setState(() {
          // Sort by display order (ordem_exibicao)
          _fases = List<Map<String, dynamic>>.from(data)
            ..sort((a, b) => (a['ordem_exibicao'] ?? 0).compareTo(b['ordem_exibicao'] ?? 0));
          _photosByPhase = groupedPhotos;
          _isLoading = false;
          _errorMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao carregar as fases da obra.';
        });
      }
    }
  }

  double _calculateProgress() {
    return calculatePhaseProgress(_fases);
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
      case 'FINALIZADA':
        return Colors.greenAccent;
      case 'EM_ANDAMENTO':
        return Colors.blueAccent;
      case 'PAUSADA':
        return Colors.orangeAccent;
      case 'CANCELADA':
        return Colors.redAccent;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _handleStatusTransition(int faseId, String acao) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.transitionPhaseStatus(widget.obra['id'], faseId, acao);
      await _loadFases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fase atualizada com sucesso para a ação: $acao.'),
            backgroundColor: AppColors.primaryGold,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar status da fase: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openPhotoForPhase(Map<String, dynamic> fase) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('Registrar foto da fase', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryGold),
              title: const Text('Tirar foto', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primaryGold),
              title: const Text('Escolher da galeria', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1920,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _isLoading = true;
        });
        await AuthService.addPhasePhoto(
          widget.obra['id'],
          fase['id_fase'],
          bytes,
          image.name,
        );
        await _loadFases();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto enviada e registrada na fase com sucesso!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao registrar foto da fase: $e');
      if (mounted) setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível registrar a foto: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _startChatWithContractor() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      ),
    );

    try {
      int contractorId = 1001;
      String contractorName = 'Eng. Felipe (Empreiteiro)';
      
      try {
        final contacts = await ChatNetworkService().fetchContacts();
        final realContractor = contacts.firstWhere(
          (c) => (c['role'] ?? '').toString().toUpperCase() == 'EMPREITEIRO',
          orElse: () => <String, dynamic>{},
        );
        if (realContractor.isNotEmpty) {
          contractorId = realContractor['id'] ?? 1001;
          contractorName = realContractor['nome'] ?? contractorName;
        }
      } catch (e) {
        debugPrint('Erro ao buscar contatos, usando padrão: $e');
      }

      final chatData = await ChatNetworkService().startPrivateChat(contractorId);
      final chatId = chatData['id'];

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              chatId: chatId,
              chatTitle: contractorName,
              otherParticipantName: contractorName,
              otherParticipantRole: 'EMPREITEIRO',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível iniciar chat com o empreiteiro: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _calculateProgress();
    final role = AuthService.role ?? 'GESTOR';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.obra['nome_projeto'] ?? 'Detalhes da Obra',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)))
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card Geral da Obra
                      Container(
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
                                const Text('Evolução Físico-Temporal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGold.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${(progress * 100).toStringAsFixed(0)}% OK',
                                    style: const TextStyle(color: AppColors.primaryGold, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: AppColors.background,
                                color: AppColors.primaryGold,
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('PREVISÃO DE ENTREGA', style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                    const SizedBox(height: 4),
                                    Text(_formatDate(widget.obra['data_previsao_entrega']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                if (role != 'FUNCIONARIO')
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('INVESTIMENTO TOTAL', style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatCurrency((widget.obra['valor_total_estimado'] as num?)?.toDouble() ?? 0.0),
                                        style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            if (widget.obra['logradouro'] != null) ...[
                              const Divider(color: AppColors.gridLine, height: 24),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${widget.obra['logradouro']}, ${widget.obra['numero']} - ${widget.obra['cidade']}/${widget.obra['estado']}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),
                      
                      if (role == 'CLIENTE' || role == 'FUNCIONARIO') ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.08),
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.forum_outlined, color: Colors.blueAccent, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  role == 'CLIENTE' 
                                      ? 'Acompanhe as fotos e status das fases abaixo. Dúvidas? Fale com o empreiteiro.' 
                                      : 'Consulte os prazos das fases e tire dúvidas com o mestre de obras.',
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _startChatWithContractor,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('CHAT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                      const Text(
                        'Cronograma de Fases',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 20),

                      // Listagem da Timeline
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _fases.length,
                        itemBuilder: (context, index) {
                          final fase = _fases[index];
                          final isLast = index == _fases.length - 1;
                          final status = (fase['status'] ?? 'PLANEJADA').toString().toUpperCase();
                          final color = _getStatusColor(status);
                          final List<Map<String, dynamic>> photos = _photosByPhase[fase['id_fase']] ?? const [];

                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Linha lateral da timeline
                                Column(
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1),
                                        ],
                                      ),
                                    ),
                                    if (!isLast)
                                      Expanded(
                                        child: Container(
                                          width: 2,
                                          color: AppColors.gridLine,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                // Card da Fase
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 24.0),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.gridLine, width: 1),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  fase['nome_fase'] ?? 'Sem Nome',
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
                                                ),
                                                child: Text(
                                                  AuthService.formatStatus(status),
                                                  style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            fase['descricao'] ?? '',
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              _buildDateText('INÍCIO', _formatDate(fase['data_iniciada'] ?? fase['data_inicio_estimada'])),
                                              _buildDateText('TÉRMINO', _formatDate(fase['data_finalizada'] ?? fase['data_fim_estimada'])),
                                              if (role != 'FUNCIONARIO')
                                                _buildDateText('ORÇADO', _formatCurrency((fase['valor_estimado'] as num?)?.toDouble() ?? 0.0)),
                                            ],
                                          ),
                                          
                                          // Seção de Fotos Anexadas
                                          if (photos.isNotEmpty) ...[
                                            const SizedBox(height: 16),
                                            const Text('FOTOS DE PROGRESSO', style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              height: 70,
                                              child: ListView.separated(
                                                scrollDirection: Axis.horizontal,
                                                itemCount: photos.length,
                                                separatorBuilder: (context, idx) => const SizedBox(width: 8),
                                                itemBuilder: (context, idx) {
                                                  final photo = photos[idx];
                                                  final photoStr = (photo['urlFoto'] ?? '').toString();
                                                  return ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Container(
                                                      width: 70,
                                                      height: 70,
                                                      color: AppColors.background,
                                                      child: photoStr.startsWith('data:image/')
                                                          ? Image.memory(base64Decode(photoStr.split(',')[1]), fit: BoxFit.cover)
                                                          : Image.network(
                                                              AuthService.mediaUrl(photoStr),
                                                              headers: AuthService.getHeaders(),
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
                                                            ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],

                                          // Controles de Ação do Empreiteiro
                                          if (role == 'EMPREITEIRO' || role == 'EMPREITEIRA' || role == 'ADMIN' || role == 'FUNCIONARIO' || role == 'SUPERVISOR' || role == 'PINTOR' || role == 'ALMOXARIFE') ...[
                                            const Divider(color: AppColors.gridLine, height: 24),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                // Photo Taking Button
                                                ElevatedButton.icon(
                                                  onPressed: () => _openPhotoForPhase(fase),
                                                  icon: const Icon(Icons.camera_alt_outlined, size: 14),
                                                  label: const Text('FOTO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors.gridLine,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Transition Status buttons
                                                Row(
                                                  children: _buildTransitionActions(fase),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDateText(String label, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(date, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  List<Widget> _buildTransitionActions(Map<String, dynamic> fase) {
    final status = (fase['status'] ?? 'PLANEJADA').toString().toUpperCase();
    final id = fase['id_fase'];
    
    if (status == 'PLANEJADA') {
      return [
        _buildTransitionButton('INICIAR', () => _handleStatusTransition(id, 'INICIAR'), Colors.blueAccent),
      ];
    } else if (status == 'EM_ANDAMENTO') {
      return [
        _buildTransitionButton('PAUSAR', () => _handleStatusTransition(id, 'PAUSAR'), Colors.orangeAccent),
        const SizedBox(width: 8),
        _buildTransitionButton('FINALIZAR', () => _handleStatusTransition(id, 'FINALIZAR'), Colors.greenAccent),
      ];
    } else if (status == 'PAUSADA') {
      return [
        _buildTransitionButton('RETOMAR', () => _handleStatusTransition(id, 'RETOMAR'), Colors.blueAccent),
        const SizedBox(width: 8),
        _buildTransitionButton('FINALIZAR', () => _handleStatusTransition(id, 'FINALIZAR'), Colors.greenAccent),
      ];
    }
    
    return []; // Cancelled or Completed phases have no actions
  }

  Widget _buildTransitionButton(String text, VoidCallback onPressed, Color color) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4), width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 0,
      ),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

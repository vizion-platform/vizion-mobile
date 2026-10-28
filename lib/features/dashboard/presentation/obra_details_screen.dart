import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/fase_fluxo.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_service.dart';
import '../../chat/presentation/chat_room_screen.dart';
import '../../chat/data/chat_network_service.dart';
import '../domain/obra_progress.dart';

class ObraDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> obra;

  const ObraDetailsScreen({super.key, required this.obra});

  @override
  State<ObraDetailsScreen> createState() => _ObraDetailsScreenState();
}

class _ObraDetailsScreenState extends State<ObraDetailsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _fases = [];
  List<Map<String, dynamic>> _photos = [];
  Map<int, List<Map<String, dynamic>>> _photosByPhase = {};
  // Observação digitada por fase; vai junto com a próxima foto enviada para ela.
  final Map<int, TextEditingController> _observacoes = {};
  String _errorMessage = '';
  // O que cada fase pode fazer agora, definido pela API (mesmo fluxo do desktop).
  Map<int, FaseFluxo> _fluxo = {};

  @override
  void initState() {
    super.initState();
    _loadFases();
  }

  @override
  void dispose() {
    for (final controller in _observacoes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _observacaoDaFase(int faseId) =>
      _observacoes.putIfAbsent(faseId, TextEditingController.new);

  Future<void> _loadFases() async {
    try {
      final result = await Future.wait([
        AuthService.fetchFases(widget.obra['id']),
        AuthService.fetchObraPhotos(widget.obra['id']),
      ]);
      final data = result[0];
      final photos = result[1];
      // Sem o fluxo (ex.: falha de rede) nenhum botão de ação aparece: melhor não agir do que agir fora da regra.
      final fluxo = await AuthService.fetchPhaseFlow(widget.obra['id'])
          .catchError((_) => <int, FaseFluxo>{});
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
          _photos = photos;
          _photosByPhase = groupedPhotos;
          _fluxo = fluxo;
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
    return calculatePhaseProgress(_fases, photos: _photos);
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
        return AppColors.success;
      case 'EM_ANDAMENTO':
        return AppColors.primaryGold;
      case 'PAUSADA':
        return AppColors.warning;
      case 'CANCELADA':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _handleStatusTransition(int faseId, String acao) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final resultado = await AuthService.transitionPhase(faseId, acao);
      final ok = resultado.ok;
      await _loadFases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Fase atualizada: ${rotuloAcaoFase(acao).toLowerCase()}.'
                : (resultado.mensagem ?? 'Não foi possível atualizar a fase. Verifique sua conexão e permissões.')),
            backgroundColor: ok ? AppColors.primaryGold : AppColors.danger,
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
            backgroundColor: AppColors.danger,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
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
              leading: Icon(Icons.camera_alt_outlined, color: AppColors.primaryGold),
              title: const Text('Tirar foto', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: AppColors.primaryGold),
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
        // O proxy recusa corpo acima de ~1 MB (erro 413): 1600 px a 65% ficam bem abaixo disso.
        imageQuality: 65,
        maxWidth: 1600,
      );

      if (image != null) {
        final faseId = (fase['id_fase'] as num).toInt();
        final observacao = _observacaoDaFase(faseId).text.trim();
        final bytes = await image.readAsBytes();
        setState(() {
          _isLoading = true;
        });
        await AuthService.addPhasePhoto(
          widget.obra['id'],
          faseId,
          bytes,
          image.name,
          descricao: observacao.isEmpty ? null : observacao,
        );
        _observacaoDaFase(faseId).clear();
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
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      ),
    );

    try {
      // Sem contato real do empreiteiro não há conversa: nada de id ou nome fixos.
      final contacts = await ChatNetworkService().fetchContacts();
      final realContractor = contacts.firstWhere(
        (c) {
          final role = (c['role'] ?? '').toString().toUpperCase();
          return role == 'EMPREITEIRO' || role == 'EMPREITEIRA';
        },
        orElse: () => <String, dynamic>{},
      );
      if (realContractor.isEmpty || realContractor['id'] == null) {
        throw Exception('Nenhum empreiteiro disponível para conversar nesta obra.');
      }
      final int contractorId = realContractor['id'] as int;
      final String contractorName = (realContractor['nome'] ?? 'Empreiteiro').toString();

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
            backgroundColor: AppColors.danger,
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
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.obra['nome_projeto'] ?? 'Detalhes da Obra',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: TextStyle(color: AppColors.danger)))
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
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.gridLine, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Evolução Físico-Temporal', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
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
                            const SizedBox(height: 8),
                            // Mesma porcentagem mostrada na dashboard
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('Avanço físico', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                ),
                                Text(
                                  '${formatarPercentualAvanco(progress)} concluído',
                                  style: TextStyle(color: AppColors.primaryGold, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('PREVISÃO DE ENTREGA', style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
                                    const SizedBox(height: 4),
                                    Text(_formatDate(widget.obra['data_previsao_entrega']), style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                  ),
                              ],
                            ),
                            if (widget.obra['logradouro'] != null) ...[
                              Divider(color: AppColors.gridLine, height: 24),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${widget.obra['logradouro']}, ${widget.obra['numero']} - ${widget.obra['cidade']}/${widget.obra['estado']}',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                            color: AppColors.primaryGold.withValues(alpha: 0.08),
                            border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.forum_outlined, color: AppColors.primaryGold, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  role == 'CLIENTE' 
                                      ? 'Acompanhe as fotos e status das fases abaixo. Dúvidas? Fale com o empreiteiro.' 
                                      : 'Consulte os prazos das fases e tire dúvidas com o mestre de obras.',
                                  style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _startChatWithContractor,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.goldFill,
                                  foregroundColor: AppColors.textPrimary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('CHAT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                      Text(
                        'Cronograma de Fases',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                                        borderRadius: BorderRadius.circular(6),
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
                                                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14.5),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
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
                                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                                            Text('FOTOS DE PROGRESSO', style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
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
                                                              errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
                                                            ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],

                                          // Observações do andamento enviadas junto com as fotos (visíveis ao cliente)
                                          ..._observacoesDaFase(photos).map(_buildObservacao),

                                          // Controles de Ação do Empreiteiro
                                          if (_podeRegistrarFoto(role)) ...[
                                            const SizedBox(height: 12),
                                            _buildBloqueioFase(fase),
                                            _buildCampoObservacao(fase),
                                            Divider(color: AppColors.gridLine, height: 24),
                                            Wrap(
                                              alignment: WrapAlignment.spaceBetween,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                // Photo Taking Button
                                                ElevatedButton.icon(
                                                  onPressed: () => _openPhotoForPhase(fase),
                                                  icon: const Icon(Icons.camera_alt_outlined, size: 14),
                                                  label: const Text('FOTO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors.gridLine,
                                                    foregroundColor: AppColors.textPrimary,
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

  bool _podeRegistrarFoto(String role) => const {
        'EMPREITEIRO',
        'EMPREITEIRA',
        'ADMIN',
        'FUNCIONARIO',
        'SUPERVISOR',
        'PINTOR',
        'ALMOXARIFE',
      }.contains(role);

  /// Fotos com observação própria. A descrição padrão gerada pelo app ("Foto de progresso…") não é exibida.
  List<Map<String, dynamic>> _observacoesDaFase(List<Map<String, dynamic>> photos) {
    return photos.where((foto) {
      final texto = (foto['descricao'] ?? '').toString().trim();
      return texto.isNotEmpty && !texto.startsWith('Foto de progresso da fase');
    }).toList();
  }

  Widget _buildObservacao(Map<String, dynamic> foto) {
    final data = _formatDataFoto(foto['dataFoto']);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryGold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 14, color: AppColors.primaryGold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'OBSERVAÇÃO DO ANDAMENTO',
                  style: TextStyle(color: AppColors.primaryGold, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.4),
                ),
              ),
              if (data.isNotEmpty)
                Text(data, style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            (foto['descricao'] ?? '').toString(),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5, height: 1.35),
          ),
        ],
      ),
    );
  }

  /// Campo de observação da fase: o texto segue junto com a próxima foto enviada.
  Widget _buildCampoObservacao(Map<String, dynamic> fase) {
    final faseId = (fase['id_fase'] as num).toInt();
    return TextField(
      controller: _observacaoDaFase(faseId),
      maxLength: 500,
      minLines: 1,
      maxLines: 4,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Observação do andamento',
        hintText: 'Ex.: concretagem da laje concluída, falta acabamento',
        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        helperText: 'Enviada junto com a próxima foto desta fase.',
        helperStyle: TextStyle(color: AppColors.textSecondary, fontSize: 10),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.gridLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.primaryGold),
        ),
      ),
    );
  }

  /// Aceita a data como texto ISO ou como o array [ano, mês, dia, h, min, s] do Java.
  String _formatDataFoto(dynamic raw) {
    DateTime? data;
    if (raw is String) {
      data = DateTime.tryParse(raw);
    } else if (raw is List && raw.length >= 3) {
      data = DateTime(
        (raw[0] as num).toInt(),
        (raw[1] as num).toInt(),
        (raw[2] as num).toInt(),
        raw.length > 3 ? (raw[3] as num).toInt() : 0,
        raw.length > 4 ? (raw[4] as num).toInt() : 0,
      );
    }
    if (data == null) return '';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Widget _buildDateText(String label, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(date, style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// Botões do fluxo único das fases: só aparecem as ações que a API libera agora.
  List<Widget> _buildTransitionActions(Map<String, dynamic> fase) {
    final id = fase['id_fase'];
    final fluxo = id is num ? _fluxo[id.toInt()] : null;
    if (fluxo == null) return [];

    final botoes = <Widget>[];
    for (final acao in ordemAcoesFase) {
      if (!fluxo.permite(acao)) continue;
      if (botoes.isNotEmpty) botoes.add(const SizedBox(width: 8));
      botoes.add(_buildTransitionButton(
        rotuloAcaoFase(acao),
        () => _handleStatusTransition(id, acao),
        corAcaoFase(acao),
      ));
    }
    return botoes;
  }

  /// Aviso de por que a fase ainda não pode andar (ex.: a anterior não foi finalizada).
  Widget _buildBloqueioFase(Map<String, dynamic> fase) {
    final id = fase['id_fase'];
    final motivo = id is num ? _fluxo[id.toInt()]?.motivoBloqueio : null;
    if (motivo == null || motivo.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              motivo,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
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

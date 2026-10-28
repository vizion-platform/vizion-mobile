import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/auth_service.dart';
import '../../../chat/presentation/chat_room_screen.dart';
import '../../../chat/data/chat_network_service.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../ponto/presentation/ponto_screen.dart';
import '../../domain/obra_progress.dart';

class HomeDashboardWidget extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onAgendaTap;
  final VoidCallback? onObrasTap;
  final VoidCallback? onPontoTap;
  final VoidCallback? onChatTap;

  const HomeDashboardWidget({
    super.key,
    this.onProfileTap,
    this.onAgendaTap,
    this.onObrasTap,
    this.onPontoTap,
    this.onChatTap,
  });

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
        _loadProgress();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _obras = [];
          _isLoading = false;
          _errorMessage = '';
        });
      }
    }
  }

  /// Progresso real de cada obra, calculado com as mesmas fases e fotos usadas na tela da obra.
  final Map<int, double> _progress = {};

  Future<void> _loadProgress() async {
    await Future.wait(_obras.map((obra) async {
      final id = obra['id'];
      if (id is! int) return;
      try {
        final fases = await AuthService.fetchFases(id);
        if (fases.isEmpty) return;
        final fotos = await AuthService.fetchObraPhotos(id)
            .catchError((_) => <Map<String, dynamic>>[]);
        if (!mounted) return;
        setState(() => _progress[id] = calculatePhaseProgress(fases, photos: fotos));
      } catch (_) {
        // sem fases/offline: a obra fica sem barra de progresso
      }
    }));
  }

  double? _getProjectProgress(int id) => _progress[id];

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

      final chatData = await ChatNetworkService().startPrivateChat(
        contractorId,
      );
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
            content: Text('Não foi possível iniciar chat: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: AppColors.danger,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(_errorMessage, style: TextStyle(color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _loadDashboardData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldFill,
              ),
              child: const Text(
                'Recarregar',
                style: TextStyle(color: AppColors.onGold),
              ),
            ),
          ],
        ),
      );
    }

    // Calculations
    final int totalObras = _obras.length;

    final role = AuthService.role ?? 'GESTOR';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Boas-vindas
          GestureDetector(
            onTap: widget.onProfileTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
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
                      style: TextStyle(
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Perfil: ${role.toUpperCase()}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onProfileTap != null)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            role == 'CLIENTE'
                ? 'Acompanhamento do Cliente'
                : role == 'FUNCIONARIO'
                ? 'Atribuição de Trabalho'
                : 'Visão Gerencial',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            role == 'CLIENTE'
                ? 'Evolução física de sua residência.'
                : role == 'FUNCIONARIO'
                ? 'Canteiro de obras e atividades atreladas ao seu cargo.'
                : 'Análise física dos canteiros de obra.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),

          // Métricas em Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 560;
              final halfWidth = (constraints.maxWidth - 16) / 2;
              final cardWidth = halfWidth;

              // Somente valores reais das obras carregadas (nada de números de exemplo).
              final progressoMedio = _progress.isEmpty
                  ? '—'
                  : formatarPercentualAvanco(_progress.values.reduce((x, y) => x + y) / _progress.length);
              final primeiraObra = _obras.isNotEmpty ? _obras.first : null;

              if (role == 'CLIENTE') {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildStatCard('Progresso Físico', progressoMedio, Icons.trending_up, AppColors.primaryGold, cardWidth),
                    _buildStatCard(
                      'Status do Projeto',
                      primeiraObra == null ? '—' : '${primeiraObra['status'] ?? '—'}'.replaceAll('_', ' '),
                      Icons.info_outline,
                      AppColors.primaryGold,
                      cardWidth,
                    ),
                  ],
                );
              } else if (role == 'FUNCIONARIO') {
                if (isWide) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Meu Canteiro',
                          'Bella Vista',
                          Icons.apartment_outlined,
                          Colors.blueAccent,
                          double.infinity,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Atividade Atual',
                          'Fundação',
                          Icons.construction_outlined,
                          AppColors.primaryGold,
                          double.infinity,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Status de Presença',
                          'Registrada',
                          Icons.verified_user_outlined,
                          Colors.greenAccent,
                          double.infinity,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Meu Canteiro',
                        primeiraObra == null ? '—' : '${primeiraObra['nome_projeto'] ?? '—'}',
                        Icons.apartment_outlined,
                        AppColors.primaryGold,
                        double.infinity,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard('Obras alocadas', totalObras.toString(), Icons.construction_outlined,
                          AppColors.primaryGold, double.infinity),
                    ),
                  ],
                );
              } else {
                if (isWide) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Canteiros de Obra',
                          totalObras.toString(),
                          Icons.domain_outlined,
                          AppColors.primaryGold,
                          double.infinity,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Progresso Físico',
                          progressoMedio,
                          Icons.trending_up,
                          Colors.greenAccent,
                          double.infinity,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatCard('Canteiros de Obra', totalObras.toString(), Icons.domain_outlined,
                          AppColors.primaryGold, double.infinity),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard('Progresso Físico', progressoMedio, Icons.trending_up,
                          AppColors.primaryGold, double.infinity),
                    ),
                  ],
                );
              }
            },
          ),

          // Atalhos para as telas de Agenda e Obras
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildAtalho('AGENDA', Icons.calendar_month_outlined, widget.onAgendaTap)),
              const SizedBox(width: 12),
              Expanded(child: _buildAtalho('OBRAS', Icons.domain_outlined, widget.onObrasTap)),
            ],
          ),

          if (kPontoHabilitado && role == 'FUNCIONARIO') ...[
            const SizedBox(height: 28),
            Text(
              'CONTROLE DE PONTO',
              style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.goldSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      color: AppColors.primaryGold,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ponto Eletrônico',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Bater ponto em tempo real ou consultar espelho.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (widget.onPontoTap != null) {
                        widget.onPontoTap!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PontoScreen()),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.goldFill,
                      foregroundColor: AppColors.onGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'Acessar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (role == 'CLIENTE' || role == 'FUNCIONARIO') ...[
            const SizedBox(height: 28),
            Text(
              'Contato direto',
              style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.gridLine, width: 1.5),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.goldFill.withValues(
                      alpha: 0.12,
                    ),
                    child: Icon(
                      Icons.engineering_outlined,
                      color: AppColors.primaryGold,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role == 'CLIENTE'
                              ? 'Falar com o Empreiteiro'
                              : 'Contatar Encarregado',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          role == 'CLIENTE'
                              ? 'Dúvidas sobre prazos ou andamento do projeto?'
                              : 'Reporte incidentes ou andamento do serviço.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (widget.onChatTap != null) {
                        widget.onChatTap!();
                      } else {
                        _startChatWithContractor();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.goldFill,
                      foregroundColor: AppColors.onGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'CHAT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          Text(
            role == 'CLIENTE'
                ? 'Evolução Física do Imóvel'
                : role == 'FUNCIONARIO'
                ? 'Status da Obra Associada'
                : 'Desempenho Físico por Obra',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary.withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Container do Desempenho Físico-Financeiro
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.gridLine, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Cronograma de Execução',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.trending_up,
                      color: AppColors.primaryGold.withValues(alpha: 0.6),
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (totalObras == 0)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Text(
                        'Nenhuma obra ativa encontrada.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ..._obras.take(4).map((obra) {
                    final int id = obra['id'] ?? 0;
                    final double? progress = _getProjectProgress(id);
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
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Status: ${('${obra['status'] ?? 'PLANEJAMENTO'}').replaceAll('_', ' ').toLowerCase()}',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                progress == null ? 'Progresso indisponível' : '${formatarPercentualAvanco(progress)} concluído',
                                style: TextStyle(
                                  color: AppColors.primaryGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress ?? 0,
                              backgroundColor: AppColors.surfaceAlt,
                              color: AppColors.primaryGold,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _buildAtalho(String rotulo, IconData icone, VoidCallback? onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icone, size: 16),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(rotulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryGold,
        side: BorderSide(color: AppColors.primaryGold.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gridLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

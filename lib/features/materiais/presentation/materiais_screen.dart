import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_service.dart';
import '../data/material_service.dart';
import '../domain/material_request_model.dart';
import '../domain/estoque_movimentacao_model.dart';

class MateriaisScreen extends StatefulWidget {
  const MateriaisScreen({super.key});

  @override
  State<MateriaisScreen> createState() => _MateriaisScreenState();
}

class _MateriaisScreenState extends State<MateriaisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MaterialRequest> _requests = [];
  List<EstoqueMovimentacao> _estoqueHistory = [];
  bool _isLoading = true;
  String _activeStatusFilter = 'TODOS'; // 'TODOS', 'PENDENTES', 'CONFIRMADOS', 'ENTREGUES'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final role = (AuthService.role ?? 'EMPREITEIRO').toUpperCase();
    int tabCount = 2;
    if (role == 'CLIENTE') {
      tabCount = 2; // "Materiais a Chegar" & "Histórico do Estoque"
    } else if (role == 'FUNCIONARIO' || role == 'COLABORADOR') {
      tabCount = 2; // "Solicitar Material" & "Minhas Solicitações"
    } else {
      tabCount = 2; // "Solicitações Pendentes/Todas" & "Movimentações de Estoque"
    }
    _tabController = TabController(length: tabCount, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final reqs = await MaterialService.loadRequests();
    final estoque = await MaterialService.loadEstoqueHistory();
    if (mounted) {
      setState(() {
        _requests = reqs;
        _estoqueHistory = estoque;
        _isLoading = false;
      });
    }
  }

  bool get _isEmpreiteiro {
    final r = (AuthService.role ?? '').toUpperCase();
    return r == 'EMPREITEIRO' || r == 'ADMIN' || r == 'GESTOR';
  }

  bool get _isFuncionario {
    final r = (AuthService.role ?? '').toUpperCase();
    return r == 'FUNCIONARIO' || r == 'COLABORADOR' || r == 'MOBILE-FUNCIONARIO';
  }

  bool get _isCliente {
    final r = (AuthService.role ?? '').toUpperCase();
    return r == 'CLIENTE';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar & Role Header Badge
            _buildHeaderBar(),

            // Role-specific Tab Navigation
            _buildRoleTabBar(),

            // Main Content Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
                  : TabBarView(
                      controller: _tabController,
                      children: _buildTabViews(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: (_isEmpreiteiro || _isFuncionario)
          ? FloatingActionButton.extended(
              onPressed: _showSolicitarCompraClienteModal,
              backgroundColor: AppColors.primaryGold,
              elevation: 6,
              icon: const Icon(Icons.add_shopping_cart, color: Colors.black),
              label: const Text(
                'Pedir Compra ao Cliente',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  fontSize: 12,
                ),
              ),
            )
          : null,
    );
  }

  /// Top Header Bar with title and user role badge
  Widget _buildHeaderBar() {
    String title = 'Gestão de Materiais';
    String subtitle = 'Solicitações e controle de suprimentos';

    if (_isFuncionario) {
      title = 'Solicitação de Materiais';
      subtitle = 'Peça suprimentos para o canteiro de obras';
    } else if (_isEmpreiteiro) {
      title = 'Aprovação de Materiais';
      subtitle = 'Confirme pedidos e solicite compras ao cliente';
    } else if (_isCliente) {
      title = 'Materiais & Estoque';
      subtitle = 'Acompanhe as entregas e pedidos de compra da obra';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.gridLine, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2,
              color: AppColors.primaryGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Role Badge Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isEmpreiteiro
                  ? Colors.blueAccent.withValues(alpha: 0.15)
                  : (_isFuncionario
                      ? Colors.amber.withValues(alpha: 0.15)
                      : Colors.greenAccent.withValues(alpha: 0.15)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isEmpreiteiro
                    ? Colors.blueAccent.withValues(alpha: 0.4)
                    : (_isFuncionario
                        ? Colors.amber.withValues(alpha: 0.4)
                        : Colors.greenAccent.withValues(alpha: 0.4)),
              ),
            ),
            child: Text(
              _isEmpreiteiro
                  ? 'EMPREITEIRO'
                  : (_isFuncionario ? 'FUNCIONÁRIO' : 'CLIENTE'),
              style: TextStyle(
                color: _isEmpreiteiro
                    ? Colors.blueAccent
                    : (_isFuncionario ? AppColors.primaryGold : Colors.greenAccent),
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dynamic Tab Bar based on User Role
  Widget _buildRoleTabBar() {
    List<Widget> tabs = [];

    if (_isCliente) {
      tabs = const [
        Tab(
          icon: Icon(Icons.local_shipping_outlined, size: 18),
          text: 'Materiais a Chegar',
        ),
        Tab(
          icon: Icon(Icons.history_edu_outlined, size: 18),
          text: 'Histórico de Estoque',
        ),
      ];
    } else if (_isFuncionario) {
      tabs = const [
        Tab(
          icon: Icon(Icons.playlist_add_check, size: 18),
          text: 'Minhas Solicitações',
        ),
        Tab(
          icon: Icon(Icons.add_shopping_cart, size: 18),
          text: 'Nova Solicitação',
        ),
      ];
    } else {
      // Empreiteiro / Gestor
      tabs = const [
        Tab(
          icon: Icon(Icons.fact_check_outlined, size: 18),
          text: 'Solicitações Recebidas',
        ),
        Tab(
          icon: Icon(Icons.warehouse_outlined, size: 18),
          text: 'Histórico do Estoque',
        ),
      ];
    }

    return Container(
      color: AppColors.surface,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primaryGold,
        indicatorWeight: 3,
        labelColor: AppColors.primaryGold,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: tabs,
      ),
    );
  }

  /// Return views for tabs
  List<Widget> _buildTabViews() {
    if (_isCliente) {
      return [
        _buildMateriaisQueVaoChegarView(),
        _buildHistoricoEstoqueView(),
      ];
    } else if (_isFuncionario) {
      return [
        _buildSolicitacoesListaView(isFuncionarioView: true),
        _buildNovaSolicitacaoFormView(),
      ];
    } else {
      // Empreiteiro
      return [
        _buildSolicitacoesListaView(isEmpreiteiroView: true),
        _buildHistoricoEstoqueView(),
      ];
    }
  }

  // --- CLIENTE VIEW 1: Materiais que vão chegar ---
  Widget _buildMateriaisQueVaoChegarView() {
    final clientPurchaseRequests = _requests.where((r) => r.status == 'AGUARDANDO_COMPRA_CLIENTE').toList();
    final incomingList = _requests.where((r) =>
      r.status == 'CONFIRMADO' || r.status == 'EM_TRANSPORTE' || r.status == 'ENTREGUE' || r.status == 'COMPRADO_CLIENTE'
    ).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Purchase Requests from Empreiteiro to Client
          if (clientPurchaseRequests.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_shopping_cart, color: AppColors.primaryGold, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Solicitações de Compra para Você',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.primaryGold, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          '${clientPurchaseRequests.length}',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'O empreiteiro sinalizou materiais em falta necessários para o canteiro:',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ...clientPurchaseRequests.map((req) => _buildClientPurchaseRequestCard(req)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Informational Banner for Client
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Previsão e acompanhamento em tempo real dos materiais em transporte para a sua obra.',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Entregas Agendadas & Em Trânsito',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),

          incomingList.isEmpty
              ? _buildEmptyView(
                  icon: Icons.local_shipping_outlined,
                  title: 'Nenhum material a caminho no momento',
                  subtitle: 'Quando o empreiteiro confirmar novas compras, a previsão aparecerá aqui.',
                )
              : Column(
                  children: incomingList.map((req) => _buildIncomingMaterialCard(req)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildClientPurchaseRequestCard(MaterialRequest req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gridLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  req.materialNome,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              if (req.valorEstimado != null)
                Text(
                  'Est.: R\$ ${req.valorEstimado!.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Qtd: ${req.quantidade.toStringAsFixed(req.quantidade % 1 == 0 ? 0 : 1)} ${req.unidade} • Solicitado por ${req.solicitanteNome}',
            style: const TextStyle(color: AppColors.primaryGold, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (req.observacao.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Motivo: ${req.observacao}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _aprovarCompraClienteModal(req),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('AUTORIZAR & MARCAR COMO COMPRADO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingMaterialCard(MaterialRequest req) {
    String deliveryText = req.dataPrevisaoEntrega != null
        ? '${req.dataPrevisaoEntrega!.day.toString().padLeft(2, '0')}/${req.dataPrevisaoEntrega!.month.toString().padLeft(2, '0')}/${req.dataPrevisaoEntrega!.year}'
        : 'A confirmar';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: req.statusColor.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: req.statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_shipping, color: req.statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.materialNome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quantidade: ${req.quantidade.toStringAsFixed(req.quantidade % 1 == 0 ? 0 : 1)} ${req.unidade}',
                      style: const TextStyle(
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: req.statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: req.statusColor),
                ),
                child: Text(
                  req.statusLabel,
                  style: TextStyle(
                    color: req.statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.gridLine, height: 1),
          const SizedBox(height: 12),

          // Stepper / Progress Timeline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimelineStep(
                label: 'Confirmado',
                isDone: true,
                color: Colors.blueAccent,
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: req.status == 'EM_TRANSPORTE' || req.status == 'ENTREGUE'
                      ? Colors.purpleAccent
                      : AppColors.gridLine,
                ),
              ),
              _buildTimelineStep(
                label: 'Em Trânsito',
                isDone: req.status == 'EM_TRANSPORTE' || req.status == 'ENTREGUE',
                color: Colors.purpleAccent,
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: req.status == 'ENTREGUE' ? Colors.greenAccent : AppColors.gridLine,
                ),
              ),
              _buildTimelineStep(
                label: 'Entregue',
                isDone: req.status == 'ENTREGUE',
                color: Colors.greenAccent,
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.event_available, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Previsão de Chegada: $deliveryText',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({required String label, required bool isDone, required Color color}) {
    return Column(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? color : AppColors.background,
            border: Border.all(color: isDone ? color : AppColors.gridLine, width: 2),
          ),
          child: isDone
              ? const Icon(Icons.check, size: 12, color: Colors.black)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isDone ? Colors.white : AppColors.textSecondary,
            fontSize: 10,
            fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // --- CLIENTE & EMPREITEIRO VIEW 2: Histórico de Estoque ---
  Widget _buildHistoricoEstoqueView() {
    final filteredHistory = _estoqueHistory.where((mov) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return mov.materialNome.toLowerCase().contains(q) ||
               mov.responsavel.toLowerCase().contains(q) ||
               mov.origemDestino.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Buscar no histórico do estoque...',
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.gridLine),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.gridLine),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryGold),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Movimentações de Estoque',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                '${filteredHistory.length} registros',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: filteredHistory.isEmpty
                ? _buildEmptyView(
                    icon: Icons.history_toggle_off,
                    title: 'Nenhum registro de estoque encontrado',
                    subtitle: 'Movimentações de entrada e saída aparecerão aqui.',
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final mov = filteredHistory[index];
                      return _buildEstoqueCard(mov);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstoqueCard(EstoqueMovimentacao mov) {
    final String dateStr =
        '${mov.data.day.toString().padLeft(2, '0')}/${mov.data.month.toString().padLeft(2, '0')}/${mov.data.year} às ${mov.data.hour.toString().padLeft(2, '0')}:${mov.data.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gridLine),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: mov.tipoColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(mov.tipoIcon, color: mov.tipoColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mov.materialNome,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '${mov.tipo == 'SAIDA' ? '-' : '+'}${mov.quantidade.toStringAsFixed(mov.quantidade % 1 == 0 ? 0 : 1)} ${mov.unidade}',
                      style: TextStyle(
                        color: mov.tipoColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Responsável: ${mov.responsavel}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                if (mov.origemDestino.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    mov.origemDestino,
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: AppColors.primaryGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- EMPREITEIRO & FUNCIONARIO VIEW: Lista de Solicitações ---
  Widget _buildSolicitacoesListaView({
    bool isFuncionarioView = false,
    bool isEmpreiteiroView = false,
  }) {
    List<MaterialRequest> list = _requests;

    if (isFuncionarioView) {
      // Funcionário sees their own requests
      final currentEmail = AuthService.currentUserEmail ?? '';
      if (currentEmail.isNotEmpty) {
        list = _requests.where((r) => r.solicitanteNome.toLowerCase().contains(currentEmail.toLowerCase().split('@')[0])).toList();
        if (list.isEmpty) list = _requests; // Fallback to all if name match empty
      }
    }

    if (_activeStatusFilter != 'TODOS') {
      list = list.where((r) => r.status == _activeStatusFilter).toList();
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Filter Chips (TODOS, PENDENTE, CONFIRMADO, ENTREGUE)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'TODOS',
                'PENDENTE',
                'AGUARDANDO_COMPRA_CLIENTE',
                'CONFIRMADO',
                'EM_TRANSPORTE',
                'ENTREGUE',
                'RECUSADO',
              ].map((st) {
                final isSelected = _activeStatusFilter == st;
                String label = st == 'TODOS' ? 'Todas' : st;
                if (st == 'AGUARDANDO_COMPRA_CLIENTE') label = 'Ped. Cliente';

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _activeStatusFilter = st),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primaryGold.withValues(alpha: 0.25),
                    checkmarkColor: AppColors.primaryGold,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primaryGold : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryGold : AppColors.gridLine,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: list.isEmpty
                ? _buildEmptyView(
                    icon: Icons.inventory,
                    title: 'Nenhuma solicitação encontrada',
                    subtitle: isFuncionarioView
                        ? 'Clique em "Solicitar Material" para pedir suprimentos.'
                        : 'Nenhuma solicitação no filtro selecionado.',
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final req = list[index];
                      return _buildSolicitacaoCard(req, isEmpreiteiroView: isEmpreiteiroView);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitacaoCard(MaterialRequest req, {bool isEmpreiteiroView = false}) {
    final String dateStr =
        '${req.dataSolicitacao.day.toString().padLeft(2, '0')}/${req.dataSolicitacao.month.toString().padLeft(2, '0')}/${req.dataSolicitacao.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: req.status == 'PENDENTE' || req.status == 'AGUARDANDO_COMPRA_CLIENTE'
              ? Colors.orangeAccent.withValues(alpha: 0.6)
              : AppColors.gridLine,
          width: req.status == 'PENDENTE' || req.status == 'AGUARDANDO_COMPRA_CLIENTE' ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  req.materialNome,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: req.statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: req.statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  req.statusLabel,
                  style: TextStyle(
                    color: req.statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Text(
                'Quantidade: ${req.quantidade.toStringAsFixed(req.quantidade % 1 == 0 ? 0 : 1)} ${req.unidade}',
                style: const TextStyle(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (req.valorEstimado != null) ...[
                const SizedBox(width: 8),
                Text(
                  '(R\$ ${req.valorEstimado!.toStringAsFixed(2)})',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Urgência: ${req.urgencia}',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            'Solicitante: ${req.solicitanteNome} • Data: $dateStr',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),

          if (req.observacao.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Obs: ${req.observacao}',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // Actions for EMPREITEIRO to confirm/approve or update status
          if (isEmpreiteiroView && req.status == 'PENDENTE') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34A853), // Green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _confirmarSolicitacaoModal(req),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text(
                      'CONFIRMAR SOLICITAÇÃO',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                  ),
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                  tooltip: 'Recusar',
                  onPressed: () => _recusarSolicitacao(req),
                ),
              ],
            ),
          ] else if (isEmpreiteiroView && req.status == 'CONFIRMADO') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purpleAccent,
                      side: const BorderSide(color: Colors.purpleAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      await MaterialService.updateRequestStatus(req.id, 'EM_TRANSPORTE');
                      _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Status atualizado para: Em Transporte'),
                            backgroundColor: Colors.purpleAccent,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.local_shipping, size: 16),
                    label: const Text('Marcar Em Transporte', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- FUNCIONARIO VIEW: Form de Nova Solicitação ---
  Widget _buildNovaSolicitacaoFormView() {
    final materialController = TextEditingController();
    final quantidadeController = TextEditingController();
    final obsController = TextEditingController();

    String selectedUnidade = 'Sacos';
    String selectedUrgencia = 'Alta';
    String selectedObra = 'Residencial Bella Vista';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gridLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.add_shopping_cart, color: AppColors.primaryGold),
                SizedBox(width: 10),
                Text(
                  'Solicitar Material para a Obra',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Preencha as informações do suprimento necessário no canteiro.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const Divider(color: AppColors.gridLine, height: 24),

            // Material Name
            TextField(
              controller: materialController,
              style: const TextStyle(color: Colors.white),
              decoration: _formInputStyle(
                'NOME DO MATERIAL *',
                'Ex: Cimento CP II, Areia Lavada, Tijolos',
                Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(height: 16),

            // Quantidade e Unidade
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantidadeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _formInputStyle(
                      'QUANTIDADE *',
                      'Ex: 50',
                      Icons.numbers,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                StatefulBuilder(
                  builder: (context, setSubState) {
                    return Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedUnidade,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _formInputStyle('UNIDADE', '', Icons.straighten),
                        items: ['Sacos', 'm³', 'kg', 'Unidades', 'Barras', 'Metros', 'Caixas'].map((u) {
                          return DropdownMenuItem(value: u, child: Text(u));
                        }).toList(),
                        onChanged: (val) => setSubState(() => selectedUnidade = val!),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Urgência Dropdown
            StatefulBuilder(
              builder: (context, setSubState) {
                return DropdownButtonFormField<String>(
                  value: selectedUrgencia,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _formInputStyle('NÍVEL DE URGÊNCIA', '', Icons.warning_amber),
                  items: ['Baixa', 'Média', 'Alta', 'Urgente'].map((urg) {
                    return DropdownMenuItem(value: urg, child: Text(urg));
                  }).toList(),
                  onChanged: (val) => setSubState(() => selectedUrgencia = val!),
                );
              },
            ),
            const SizedBox(height: 16),

            // Observações / Justificativa
            TextField(
              controller: obsController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: _formInputStyle(
                'OBSERVAÇÕES / JUSTIFICATIVA',
                'Informe o local da aplicação na obra...',
                Icons.comment_bank_outlined,
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (materialController.text.trim().isEmpty || quantidadeController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor, informe o nome do material e a quantidade.'),
                        backgroundColor: Colors.orangeAccent,
                      ),
                    );
                    return;
                  }

                  final newReq = MaterialRequest(
                    id: 'req_${DateTime.now().millisecondsSinceEpoch}',
                    obraNome: selectedObra,
                    solicitanteNome: AuthService.nome ?? 'Funcionário da Obra',
                    solicitanteRole: 'FUNCIONARIO',
                    materialNome: materialController.text.trim(),
                    quantidade: double.tryParse(quantidadeController.text) ?? 1.0,
                    unidade: selectedUnidade,
                    urgencia: selectedUrgencia,
                    observacao: obsController.text.trim(),
                    status: 'PENDENTE',
                    dataSolicitacao: DateTime.now(),
                  );

                  await MaterialService.createRequest(newReq);
                  await _loadData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Solicitação de material enviada ao Empreiteiro!'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    _tabController.animateTo(0);
                  }
                },
                icon: const Icon(Icons.send),
                label: const Text(
                  'ENVIAR SOLICITAÇÃO',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODAL: Pedir Compra de Material ao Cliente ---
  void _showSolicitarCompraClienteModal() {
    final materialController = TextEditingController();
    final quantidadeController = TextEditingController();
    final valorController = TextEditingController();
    final obsController = TextEditingController();

    String selectedUnidade = 'Caixas';
    String selectedUrgencia = 'Alta';
    String selectedObra = 'Residencial Bella Vista';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_shopping_cart, color: AppColors.primaryGold, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pedir Compra ao Cliente',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Solicitar compra de materiais em falta na obra',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.gridLine, height: 20),

                    // Material Name
                    TextField(
                      controller: materialController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _formInputStyle(
                        'MATERIAL EM FALTA *',
                        'Ex: Porcelanato Polido 80x80cm, Cabo Elétrico',
                        Icons.inventory_2_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Quantidade e Unidade
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: quantidadeController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: _formInputStyle(
                              'QUANTIDADE *',
                              'Ex: 45',
                              Icons.numbers,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedUnidade,
                            dropdownColor: AppColors.surface,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _formInputStyle('UNIDADE', '', Icons.straighten),
                            items: ['Caixas', 'Sacos', 'm²', 'kg', 'Unidades', 'Barras', 'Metros'].map((u) {
                              return DropdownMenuItem(value: u, child: Text(u));
                            }).toList(),
                            onChanged: (val) => setModalState(() => selectedUnidade = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: valorController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                            decoration: _formInputStyle(
                              'VALOR ESTIMADO (R\$)',
                              'Ex: 3850.00',
                              Icons.attach_money,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedUrgencia,
                            dropdownColor: AppColors.surface,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _formInputStyle('URGÊNCIA', '', Icons.warning_amber),
                            items: ['Baixa', 'Média', 'Alta', 'Crítica'].map((urg) {
                              return DropdownMenuItem(value: urg, child: Text(urg));
                            }).toList(),
                            onChanged: (val) => setModalState(() => selectedUrgencia = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Observações
                    TextField(
                      controller: obsController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: _formInputStyle(
                        'JUSTIFICATIVA PARA O CLIENTE *',
                        'Ex: Estoque esgotado. Necessário para conclusão da fase de revestimento.',
                        Icons.comment_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          if (materialController.text.trim().isEmpty || quantidadeController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Informe o nome do material e a quantidade.'),
                                backgroundColor: Colors.orangeAccent,
                              ),
                            );
                            return;
                          }

                          final double? valor = double.tryParse(valorController.text.replaceAll(',', '.'));

                          await MaterialService.createClientPurchaseRequest(
                            obraNome: selectedObra,
                            solicitanteNome: AuthService.nome ?? 'Empreiteiro da Obra',
                            solicitanteRole: AuthService.role ?? 'EMPREITEIRO',
                            materialNome: materialController.text.trim(),
                            quantidade: double.tryParse(quantidadeController.text) ?? 1.0,
                            unidade: selectedUnidade,
                            urgencia: selectedUrgencia,
                            observacao: obsController.text.trim(),
                            valorEstimado: valor,
                          );

                          await _loadData();

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Solicitação de compra enviada para o Cliente!'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.send),
                        label: const Text(
                          'ENVIAR SOLICITAÇÃO AO CLIENTE',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAL: Cliente Aprova/Efetiva Compra ---
  void _aprovarCompraClienteModal(MaterialRequest req) {
    DateTime previsao = DateTime.now().add(const Duration(days: 3));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.gridLine),
              ),
              title: const Row(
                children: [
                  Icon(Icons.shopping_cart_checkout, color: Colors.greenAccent),
                  SizedBox(width: 10),
                  Text('Confirmar Compra Efetivada', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Material: ${req.materialNome}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Quantidade: ${req.quantidade} ${req.unidade}', style: const TextStyle(color: AppColors.primaryGold)),
                  if (req.valorEstimado != null) ...[
                    const SizedBox(height: 4),
                    Text('Valor Estimado: R\$ ${req.valorEstimado!.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent)),
                  ],
                  const SizedBox(height: 16),
                  const Text('Previsão de Entrega no Canteiro:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: previsao,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        setModalState(() => previsao = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.gridLine),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AppColors.primaryGold, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${previsao.day.toString().padLeft(2, '0')}/${previsao.month.toString().padLeft(2, '0')}/${previsao.year}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                  onPressed: () async {
                    Navigator.pop(context);
                    await MaterialService.updateRequestStatus(req.id, 'COMPRADO_CLIENTE', previsaoEntrega: previsao);
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Compra autorizada! O empreiteiro foi notificado.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('CONFIRMAR COMPRA', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- EMPREITEIRO: Modal de Confirmação ---
  void _confirmarSolicitacaoModal(MaterialRequest req) {
    DateTime previsao = DateTime.now().add(const Duration(days: 2));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.gridLine),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF34A853)),
                  SizedBox(width: 10),
                  Text('Confirmar Solicitação', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Material: ${req.materialNome}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quantidade: ${req.quantidade} ${req.unidade}',
                    style: const TextStyle(color: AppColors.primaryGold),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Data Prevista de Entrega no Canteiro:',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: previsao,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        setModalState(() => previsao = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.gridLine),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AppColors.primaryGold, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${previsao.day.toString().padLeft(2, '0')}/${previsao.month.toString().padLeft(2, '0')}/${previsao.year}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF34A853)),
                  onPressed: () async {
                    Navigator.pop(context);
                    await MaterialService.updateRequestStatus(req.id, 'CONFIRMADO', previsaoEntrega: previsao);
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Solicitação CONFIRMADA com sucesso!'),
                          backgroundColor: Color(0xFF34A853),
                        ),
                      );
                    }
                  },
                  child: const Text('CONFIRMAR PEDIDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _recusarSolicitacao(MaterialRequest req) async {
    await MaterialService.updateRequestStatus(req.id, 'RECUSADO');
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitação RECUSADA.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildEmptyView({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 54, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _formInputStyle(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1),
      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 12),
      prefixIcon: Icon(icon, color: AppColors.primaryGold, size: 18),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.gridLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.gridLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryGold),
      ),
    );
  }
}

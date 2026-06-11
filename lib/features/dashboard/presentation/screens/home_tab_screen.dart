import 'package:flutter/material.dart';
import '../controllers/user_controller.dart';

class HomeTabScreen extends StatelessWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Fundo dark principal
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER COM SAUDAÇÃO E LOGO ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ValueListenableBuilder<Usuario?>(
                    valueListenable: UserController.instance.usuarioLogado,
                    builder: (context, user, child) {
                      final String userName = user != null ? user.nome.split(' ').first : "Visitante";
                      final String userRole = user?.role ?? "Convidado";
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "VIZION UP BUILD • $userRole",
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFD4AF37), // Dourado corporativo
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Olá, $userName",
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // Badge de Conexão da IA
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF222222)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF52B788), // Verde ativo
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "IA OTIMIZADA",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // --- CARD DE INTRODUÇÃO DA IA (BANNER PRINCIPAL) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1A1A), Color(0xFF111111)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology, color: Color(0xFFD4AF37), size: 28),
                      const SizedBox(width: 12),
                      Text(
                        "Construção Inteligente",
                        style: TextStyle(
                          color: const Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Bem-vindo à engenharia do futuro. A IA da Vizion analisa cronogramas, prevê gargalos de suprimentos e otimiza a alocação de equipes nos canteiros de obras de forma autônoma.",
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text(
                        "Conhecer Ecossistema AI",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: const Color(0xFFD4AF37), size: 16),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- MÉTRICAS DE PERFORMANCE EM TEMPO REAL ---
            const Text(
              "Insights da Operação",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMetricCard("Eficiência Global", "94.2%", Icons.speed, Colors.blueAccent),
                _buildMetricCard("Previsão de Entrega", "No Prazo", Icons.event_available, const Color(0xFF52B788)),
                _buildMetricCard("Canteiros Monitorados", "03 Ativos", Icons.domain, const Color(0xFFD4AF37)),
                _buildMetricCard("Risco de Atraso", "Baixo (2%)", Icons.verified_user, Colors.orangeAccent),
              ],
            ),
            const SizedBox(height: 32),

            // --- SEÇÃO DE ATIVIDADES RECENTES DA IA ---
            const Text(
              "Ações Recentes da IA",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            _buildActivityItem(
              "Otimização de Cronograma",
              "Alocação de mão de obra recalibrada no Residencial Alphaville para adiantar a concretagem.",
              "Há 5 min",
            ),
            _buildActivityItem(
              "Alerta de Insumos",
              "Pedido automático de aço sugerido para o Edifício VIZION Corporate evitar paralisações.",
              "Há 1 hora",
            ),
            _buildActivityItem(
              "Relatório Semanal Gerado",
              "A análise estatística de avanço físico e financeiro consolidada com sucesso.",
              "Ontem",
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para os Cards de Métricas
  Widget _buildMetricCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold),
              ),
              Icon(icon, color: iconColor, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para as linhas de log de atividades da IA
  Widget _buildActivityItem(String title, String description, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF1C1C1C)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(time, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'criar_obra_modal.dart';

class ObrasListWidget extends StatefulWidget {
  const ObrasListWidget({super.key});

  @override
  State<ObrasListWidget> createState() => _ObrasListWidgetState();
}

class _ObrasListWidgetState extends State<ObrasListWidget> {
  // Lista mutável para armazenamento local em memória
  final List<Map<String, dynamic>> _listagemDeObras = [
    {'nome': 'Residencial Alphaville', 'status': 'Em Execução', 'progresso': 0.65, 'responsavel': 'Eng. Carlos M.'},
    {'nome': 'Edifício VIZION Corporate', 'status': 'Fase de Fundação', 'progresso': 0.15, 'responsavel': 'Mestre Almir'},
    {'nome': 'Galpão Logístico Limeira', 'status': 'Finalizado', 'progresso': 1.0, 'responsavel': 'Eng. Carlos M.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho com o Título e o Botão Nova Obra
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gestão de Obras', 
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Listagem e central de controle dos canteiros.', 
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            
            // Botão Nova Obra que chama a Modal Dark
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false, // Força preenchimento das etapas
                  builder: (context) => CriarObraModal(
                    onObraCriada: (novaObra) {
                      setState(() {
                        _listagemDeObras.add(novaObra); // Atualiza o estado da lista na hora
                      });
                    },
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('NOVA OBRA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.black,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        
        // Listagem Dinâmica das Obras
        Expanded(
          child: ListView.separated(
            itemCount: _listagemDeObras.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final obra = _listagemDeObras[index];
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.gridLine),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      color: AppColors.background,
                      child: const Icon(Icons.apartment, color: AppColors.primaryGold),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            obra['nome'] as String, 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Responsável: ${obra['responsavel']}', 
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            obra['status'] as String, 
                            style: TextStyle(
                              color: obra['status'] == 'Finalizado' ? Colors.green : AppColors.primaryGold, 
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: obra['progresso'] as double,
                            backgroundColor: AppColors.background,
                            color: AppColors.primaryGold,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

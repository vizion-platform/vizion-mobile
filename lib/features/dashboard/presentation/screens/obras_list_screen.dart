import 'package:flutter/material.dart';
import '../controllers/obras_controller.dart';
import '../../data/models/obra_model.dart';
import 'detalhe_obra_screen.dart';
import 'cadastro_obra_screen.dart';
import '../controllers/user_controller.dart';

class ObrasListScreen extends StatelessWidget {
  const ObrasListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TOPO IDÊNTICO AO SEU MOCKUP ESCURO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Gestão de Obras", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("Listagem e central de controle dos canteiros.", style: TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
              ValueListenableBuilder<Usuario?>(
                valueListenable: UserController.instance.usuarioLogado,
                builder: (context, user, child) {
                  if (user?.role != 'Empreiteiro') return const SizedBox.shrink();
                  
                  return ElevatedButton.icon(
                    onPressed: () {
                      // BOTÃO FUNCIONAL: Abre o formulário de cadastro
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CadastroFormScreen()), // Nome mapeado de cadastro_obra_screen.dart
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37), // Amarelo/Dourado do seu print
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    icon: const Icon(Icons.add, size: 16, color: Colors.black),
                    label: const Text("NOVA OBRA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // LISTA DINÂMICA COMPORTAMENTAL
          Expanded(
            child: ValueListenableBuilder<List<Obra>>(
              valueListenable: ObrasController.instance.obrasNotifier,
              builder: (context, listaDeObras, child) {
                return ListView.builder(
                  itemCount: listaDeObras.length,
                  itemBuilder: (context, index) {
                    final obra = listaDeObras[index];
                    
                    // Tratamento do progresso seguro
                    double progressoVal = 0.0;
                    try {
                      progressoVal = double.parse(obra.progresso.replaceAll('%', '')) / 100;
                    } catch (_) {}

                    return GestureDetector(
                      onTap: () {
                        // ABRE DETALHES DA OBRA CLICADA
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => DetalheObraScreen(obra: obra)),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF222222)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1A1A),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.business, color: Color(0xFFD4AF37)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(obra.titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text("Responsável: ${obra.responsavel}", style: const TextStyle(color: Colors.white54, fontSize: 13), overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(obra.status, style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 12),
                                Stack(
                                  children: [
                                    Container(width: 100, height: 4, color: Colors.white10),
                                    Container(
                                      width: 100 * progressoVal,
                                      height: 4,
                                      color: const Color(0xFFD4AF37),
                                      ),
                                  ],
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

// Aliasing para compatibilidade com o arquivo de cima
class CadastroFormScreen extends CadastroObraScreen {
  const CadastroFormScreen({super.key});
}
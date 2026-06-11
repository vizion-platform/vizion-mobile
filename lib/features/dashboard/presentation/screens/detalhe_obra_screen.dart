import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/obra_model.dart';
import '../controllers/user_controller.dart';
import '../controllers/obras_controller.dart';

class DetalheObraScreen extends StatefulWidget {
  final Obra obra;

  const DetalheObraScreen({super.key, required this.obra});

  @override
  State<DetalheObraScreen> createState() => _DetalheObraScreenState();
}

class _DetalheObraScreenState extends State<DetalheObraScreen> {
  double _currentProgress = 0.0;

  final List<String> _mockConstructionPhotos = [
    "https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1541888946425-d81bb19240f5?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1581094288338-2314dddb7ecc?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1590069261209-f8e9b8642343?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1531834685032-c34bf0d8b939?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1508450859948-4e04fabaa4ea?auto=format&fit=crop&w=600&q=80",
  ];

  @override
  void initState() {
    super.initState();
    _currentProgress = _parseProgress(widget.obra.progresso);
  }

  double _parseProgress(String prog) {
    try {
      return double.parse(prog.replaceAll('%', ''));
    } catch (_) {
      return 0.0;
    }
  }

  void _simularCapturaFoto() {
    final randomUrl = _mockConstructionPhotos[Random().nextInt(_mockConstructionPhotos.length)];
    ObrasController.instance.adicionarFoto(widget.obra.id, randomUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto registrada e enviada para a galeria com sucesso!'), backgroundColor: Colors.green),
    );
    setState(() {}); // Recarrega para obter nova foto
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: Text(widget.obra.titulo, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        elevation: 0,
      ),
      body: ValueListenableBuilder<List<Obra>>(
        valueListenable: ObrasController.instance.obrasNotifier,
        builder: (context, obrasList, child) {
          // Busca a versão mais atualizada da obra na lista do controller
          final Obra obraAtualizada = obrasList.firstWhere(
            (o) => o.id == widget.obra.id,
            orElse: () => widget.obra,
          );

          _currentProgress = _parseProgress(obraAtualizada.progresso);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Identificador do Perfil Ativo
                ValueListenableBuilder<Usuario?>(
                  valueListenable: UserController.instance.usuarioLogado,
                  builder: (context, user, child) {
                    final String userRole = user?.role ?? "Cliente";
                    Color roleColor = const Color(0xFFD4AF37);
                    if (userRole == "Funcionário") roleColor = Colors.blueAccent;
                    if (userRole == "Cliente") roleColor = Colors.greenAccent;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: roleColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        "PERFIL ATIVO: $userRole",
                        style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    );
                  },
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("OBRA", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(obraAtualizada.titulo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text("Status: ${obraAtualizada.status} • Prazo: ${obraAtualizada.prazo}", style: const TextStyle(fontSize: 13, color: Colors.white54)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFD4AF37), width: 4)),
                      child: Center(
                        child: Text(obraAtualizada.progresso, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // --- CONTEÚDO CONDICIONAL POR PERFIL ---
                ValueListenableBuilder<Usuario?>(
                  valueListenable: UserController.instance.usuarioLogado,
                  builder: (context, user, child) {
                    final String userRole = user?.role ?? "Cliente";

                    if (userRole == "Empreiteiro") {
                      return _buildEmpreiteiroControls(obraAtualizada);
                    } else if (userRole == "Funcionário") {
                      return _buildFuncionarioControls(obraAtualizada);
                    } else {
                      return _buildClienteControls();
                    }
                  },
                ),

                const SizedBox(height: 32),
                const Text("Galeria de Fotos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                
                // Galeria de Fotos horizontal
                obraAtualizada.photos.isEmpty
                    ? Container(
                        height: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF222222)),
                        ),
                        child: const Text("Nenhuma foto registrada para esta obra.", style: TextStyle(color: Colors.white38, fontSize: 13)),
                      )
                    : SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: obraAtualizada.photos.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF222222)),
                                image: DecorationImage(
                                  image: NetworkImage(obraAtualizada.photos[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                const SizedBox(height: 32),
                const Text("Resumo da obra", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildDarkInfoBox("Valor estimado", obraAtualizada.valorEstimated),
                    _buildDarkInfoBox("Endereço", obraAtualizada.endereco),
                    _buildDarkInfoBox("Cliente", obraAtualizada.cliente),
                    _buildDarkInfoBox("Empreiteiro", obraAtualizada.empreiteiro),
                  ],
                ),
                const SizedBox(height: 32),
                const Text("Equipe e vínculos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildDarkChip("Responsável: ${obraAtualizada.responsavel}"),
                    _buildDarkChip("Clientes vinculados"),
                    _buildDarkChip("Funcionários Alocados"),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // --- CONTROLES DE EMPREITEIRO ---
  Widget _buildEmpreiteiroControls(Obra obra) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Controles do Empreiteiro", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Ajustar Progresso da Obra", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("${_currentProgress.round()}%", style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _currentProgress,
                min: 0,
                max: 100,
                activeColor: const Color(0xFFD4AF37),
                inactiveColor: Colors.white10,
                onChanged: (val) {
                  setState(() {
                    _currentProgress = val;
                  });
                },
                onChangeEnd: (val) {
                  ObrasController.instance.updateProgresso(obra.id, "${val.round()}%");
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _simularCapturaFoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("REGISTRAR & UPLOADEAR FOTO", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- CONTROLES DE FUNCIONÁRIO ---
  Widget _buildFuncionarioControls(Obra obra) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Fases do Projeto (Checklist do Funcionário)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: obra.phases.length,
            itemBuilder: (context, index) {
              final phase = obra.phases[index];
              return CheckboxListTile(
                value: phase.concluido,
                title: Text(phase.nome, style: TextStyle(color: phase.concluido ? Colors.white54 : Colors.white, decoration: phase.concluido ? TextDecoration.lineThrough : null)),
                activeColor: Colors.blueAccent,
                checkColor: Colors.black,
                onChanged: (bool? checked) {
                  ObrasController.instance.togglePhase(obra.id, phase.nome);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- CONTROLES DE CLIENTE ---
  Widget _buildClienteControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3D22).withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility, color: Colors.greenAccent),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Você está visualizando esta obra como Cliente. O andamento e as fases são geridos pela equipe responsável.",
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDarkInfoBox(String label, String? value) {
    final display = value ?? '-';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(display, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildDarkChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
    );
  }
}
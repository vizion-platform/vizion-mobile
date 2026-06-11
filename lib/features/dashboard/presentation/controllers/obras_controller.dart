import 'package:flutter/material.dart';
import '../../data/models/obra_model.dart';

class ObrasController {
  // Instância única (Singleton) para compartilhar a mesma lista entre as telas
  static final ObrasController instance = ObrasController._internal();
  ObrasController._internal();

  // ValueNotifier que guarda a lista e avisa quando ela muda
  final ValueNotifier<List<Obra>> obrasNotifier = ValueNotifier<List<Obra>>([
    Obra(
      id: "1",
      titulo: "Residencial Alphaville",
      responsavel: "Eng. Carlos M.",
      status: "Em Execução",
      prazo: "24/08/2026",
      progresso: "60%",
      valorEstimado: "R\$ 7,8 mi",
      endereco: "Av. Alphaville, 450",
      cliente: "Grupo Alfa",
      empreiteiro: "Construtora Norte",
      phases: [
        ObraPhase(nome: "Fundação", concluido: true),
        ObraPhase(nome: "Estrutura", concluido: true),
        ObraPhase(nome: "Alvenaria", concluido: true),
        ObraPhase(nome: "Instalações", concluido: false),
        ObraPhase(nome: "Acabamento", concluido: false),
      ],
      photos: [
        "https://images.unsplash.com/photo-1541888946425-d81bb19240f5?auto=format&fit=crop&w=400&q=80",
        "https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=400&q=80",
      ],
    ),
    Obra(
      id: "2",
      titulo: "Edifício VIZION Corporate",
      responsavel: "Mestre Almir",
      status: "Fase de Fundação",
      prazo: "12/12/2027",
      progresso: "20%",
      valorEstimado: "R\$ 22,0 mi",
      endereco: "Rua das Flores, 100",
      cliente: "Vizion S.A.",
      empreiteiro: "Mudar Engenharia",
      phases: [
        ObraPhase(nome: "Fundação", concluido: true),
        ObraPhase(nome: "Estrutura", concluido: false),
        ObraPhase(nome: "Alvenaria", concluido: false),
        ObraPhase(nome: "Instalações", concluido: false),
        ObraPhase(nome: "Acabamento", concluido: false),
      ],
      photos: [
        "https://images.unsplash.com/photo-1581094288338-2314dddb7ecc?auto=format&fit=crop&w=400&q=80",
      ],
    ),
    Obra(
      id: "3",
      titulo: "Galpão Logístico Limeira",
      responsavel: "Eng. Carlos M.",
      status: "Finalizado",
      prazo: "10/01/2026",
      progresso: "100%",
      valorEstimado: "R\$ 4,5 mi",
      endereco: "Rodovia Anhanguera, Km 140",
      cliente: "LogiCorp",
      empreiteiro: "Construtora Norte",
      phases: [
        ObraPhase(nome: "Fundação", concluido: true),
        ObraPhase(nome: "Estrutura", concluido: true),
        ObraPhase(nome: "Alvenaria", concluido: true),
        ObraPhase(nome: "Instalações", concluido: true),
        ObraPhase(nome: "Acabamento", concluido: true),
      ],
      photos: [
        "https://images.unsplash.com/photo-1590069261209-f8e9b8642343?auto=format&fit=crop&w=400&q=80",
      ],
    ),
  ]);

  // Função para cadastrar uma nova obra de forma dinâmica
  void adicionarObra(Obra novaObra) {
    if (novaObra.phases.isEmpty) {
      novaObra.phases.addAll([
        ObraPhase(nome: "Fundação", concluido: false),
        ObraPhase(nome: "Estrutura", concluido: false),
        ObraPhase(nome: "Alvenaria", concluido: false),
        ObraPhase(nome: "Instalações", concluido: false),
        ObraPhase(nome: "Acabamento", concluido: false),
      ]);
    }
    obrasNotifier.value = [...obrasNotifier.value, novaObra];
  }

  // Alterna a conclusão de uma fase e atualiza o progresso baseado na proporção de fases concluídas
  void togglePhase(String id, String phaseNome) {
    final list = obrasNotifier.value;
    final index = list.indexWhere((o) => o.id == id);
    if (index != -1) {
      final obra = list[index];
      final phaseIndex = obra.phases.indexWhere((p) => p.nome == phaseNome);
      if (phaseIndex != -1) {
        obra.phases[phaseIndex].concluido = !obra.phases[phaseIndex].concluido;
        
        // Recalcular o progresso
        final total = obra.phases.length;
        final concluido = obra.phases.where((p) => p.concluido).length;
        final novoPercentual = ((concluido / total) * 100).round();
        obra.progresso = "$novoPercentual%";
        
        if (novoPercentual == 100) {
          obra.status = "Finalizado";
        } else if (novoPercentual > 0) {
          obra.status = "Em Execução";
        } else {
          obra.status = "Fase de Fundação";
        }

        // Força a atualização do ValueNotifier
        obrasNotifier.value = List.from(list);
      }
    }
  }

  // Atualiza o progresso diretamente (Para Empreiteiro)
  void updateProgresso(String id, String novoProgresso) {
    final list = obrasNotifier.value;
    final index = list.indexWhere((o) => o.id == id);
    if (index != -1) {
      list[index].progresso = novoProgresso;
      // Ajustar status com base no progresso de forma inteligente
      double val = 0.0;
      try {
        val = double.parse(novoProgresso.replaceAll('%', ''));
      } catch (_) {}
      
      if (val >= 100) {
        list[index].status = "Finalizado";
      } else if (val > 0) {
        list[index].status = "Em Execução";
      } else {
        list[index].status = "Fase de Fundação";
      }

      obrasNotifier.value = List.from(list);
    }
  }

  // Adiciona foto registrada (Simulada)
  void adicionarFoto(String id, String photoUrl) {
    final list = obrasNotifier.value;
    final index = list.indexWhere((o) => o.id == id);
    if (index != -1) {
      list[index].photos.add(photoUrl);
      obrasNotifier.value = List.from(list);
    }
  }
}
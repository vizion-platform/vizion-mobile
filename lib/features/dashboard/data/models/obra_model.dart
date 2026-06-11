class ObraPhase {
  final String nome;
  bool concluido;

  ObraPhase({
    required this.nome,
    this.concluido = false,
  });
}

class Obra {
  final String id;
  final String titulo;
  final String responsavel;
  String status;
  final String prazo;
  String progresso; // Ex: "68%"
  final String valorEstimado;
  final String endereco;
  final String cliente;
  final String empreiteiro;
  final List<ObraPhase> phases;
  final List<String> photos;

  Obra({
    required this.id,
    required this.titulo,
    required this.responsavel,
    required this.status,
    required this.prazo,
    required this.progresso,
    required this.valorEstimado,
    required this.endereco,
    required this.cliente,
    required this.empreiteiro,
    List<ObraPhase>? phases,
    List<String>? photos,
  }) : this.phases = phases ?? [],
       this.photos = photos ?? [];

  String get valorEstimated => valorEstimado;
}


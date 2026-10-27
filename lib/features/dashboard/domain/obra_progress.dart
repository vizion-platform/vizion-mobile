/// Avanço físico de uma obra. É a única regra usada pela dashboard e pela tela da obra,
/// assim as duas porcentagens são sempre iguais.
///
/// - Fase concluída vale 1.
/// - Fase ainda não concluída, mas com foto de andamento registrada, vale 0,5.
/// - Demais fases valem 0.
double calculatePhaseProgress(
  List<Map<String, dynamic>> phases, {
  List<Map<String, dynamic>> photos = const [],
}) {
  if (phases.isEmpty) return 0;

  final fasesComFoto = <int>{};
  for (final photo in photos) {
    final idFase = photo['idFase'];
    if (idFase is num) fasesComFoto.add(idFase.toInt());
  }

  var avanco = 0.0;
  for (final phase in phases) {
    if (_faseConcluida(phase)) {
      avanco += 1;
    } else {
      final id = phase['id_fase'];
      if (id is num && fasesComFoto.contains(id.toInt())) avanco += 0.5;
    }
  }
  return avanco / phases.length;
}

const _statusConcluida = {'FINALIZADA', 'CONCLUIDA', 'CONCLUIDO'};

bool _faseConcluida(Map<String, dynamic> phase) {
  final status = (phase['status'] ?? '').toString().trim().toUpperCase();
  return _statusConcluida.contains(status);
}

/// Porcentagem exibida para o avanço, igual em todas as telas (dashboard e obra).
String formatarPercentualAvanco(double progress) => '${(progress * 100).round()}%';

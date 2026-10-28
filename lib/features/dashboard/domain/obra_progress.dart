/// Avanço físico de uma obra. É a única regra usada pela dashboard e pela tela da obra,
/// assim as duas porcentagens são sempre iguais.
///
/// - Fase concluída vale 1.
/// - Fase iniciada (em andamento ou pausada) vale 0,5, assim o avanço sobe assim que
///   o funcionário inicia a fase.
/// - Fase ainda não concluída, mas com foto de andamento registrada, também vale 0,5
///   (não soma com o início da fase).
/// - Demais fases valem 0.
///
/// É o mesmo critério usado pela API (`ProgressoObra`).
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
    } else if (_faseIniciada(phase)) {
      avanco += 0.5;
    } else {
      final id = phase['id_fase'];
      if (id is num && fasesComFoto.contains(id.toInt())) avanco += 0.5;
    }
  }
  return avanco / phases.length;
}

const _statusConcluida = {'FINALIZADA', 'CONCLUIDA', 'CONCLUIDO'};
const _statusIniciada = {'EM_ANDAMENTO', 'PAUSADA'};

String _statusDaFase(Map<String, dynamic> phase) =>
    (phase['status'] ?? '').toString().trim().toUpperCase();

bool _faseConcluida(Map<String, dynamic> phase) => _statusConcluida.contains(_statusDaFase(phase));

bool _faseIniciada(Map<String, dynamic> phase) => _statusIniciada.contains(_statusDaFase(phase));

/// Porcentagem exibida para o avanço, igual em todas as telas (dashboard e obra).
String formatarPercentualAvanco(double progress) => '${(progress * 100).round()}%';

import 'package:flutter_test/flutter_test.dart';
import 'package:vizion_mobile/features/chat/data/chat_network_service.dart';

void main() {
  final agora = DateTime(2026, 10, 28, 15, 30);

  test('mensagem de hoje mostra só a hora', () {
    expect(formatarHorarioConversa('2026-10-28T09:05:00', agora: agora), '09:05');
  });

  test('mensagem de ontem mostra "Ontem"', () {
    expect(formatarHorarioConversa('2026-10-27T23:59:00', agora: agora), 'Ontem');
  });

  test('mensagem mais antiga mostra dia e mês', () {
    expect(formatarHorarioConversa('2026-10-05T10:00:00', agora: agora), '05/10');
  });

  test('conversa sem mensagem ou data inválida não mostra horário', () {
    expect(formatarHorarioConversa(null, agora: agora), '');
    expect(formatarHorarioConversa('', agora: agora), '');
    expect(formatarHorarioConversa('não é data', agora: agora), '');
  });
}

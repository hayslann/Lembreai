import 'package:flutter_test/flutter_test.dart';
import 'package:lembreai/reminder_parser.dart';

void main() {
  final now = DateTime(2026, 11, 17, 12);
  test('1 - amanhã 14:30', () {
    final r = parseReminder('Me lembra amanhã às 14:30 de pagar boleto', now)!;
    expect(r.when, DateTime(2026,11,18,14,30));
    expect(r.title.toLowerCase(), contains('pagar boleto'));
  });
  test('2 - hoje 18h', () {
    expect(parseReminder('Hoje 18h comprar pão', now)!.when, DateTime(2026,11,17,18));
  });
  test('3 - data sem ano', () {
    expect(parseReminder('25/12 às 09:00 consulta', now)!.when, DateTime(2026,12,25,9));
  });
  test('4 - hora inválida', () {
    expect(parseReminder('amanhã às 29:30 pagar', now), isNull);
  });
  test('5 - mensagem sem data explícita', () {
    expect(parseReminder('me lembra de pagar amanhã', now), isNull);
  });
  test('usa o instante da mensagem nos pedidos relativos', () {
    final start = DateTime(2026, 11, 23, 23, 59, 42);
    for (final entry in {
      'me lembra de tomar água daqui um segundo': 1,
      'me lembra de tomar água daqui a um minuto': 60,
      'me avisa em meia hora de tomar água': 1800,
      'me lembre de tomar água em 2 horas': 7200,
    }.entries) {
      final reminder = parseRelativeRequest(entry.key, start)!;
      expect(reminder.when, start.add(Duration(seconds: entry.value)));
      expect(reminder.title, 'tomar água');
    }
    expect(parseRelativeRequest('cancela o alarme em dois minutos', start), isNull);
    expect(parseRelativeRequest('me lembra em dois dias e em três dias', start), isNull);
  });
}

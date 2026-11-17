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
}

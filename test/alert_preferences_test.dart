import 'package:flutter_test/flutter_test.dart';
import 'package:lembreai/alert_preferences.dart';

void main() {
  final now = DateTime(2026, 11, 17, 10);
  final appointment = DateTime(2026, 11, 17, 15);
  test('padrão do aplicativo é 30 minutos antes', () {
    expect(defaultAdvanceMinutes, 30);
    expect(normalizedAdvanceMinutes(null), 30);
    expect(normalizedAdvanceMinutes(40), 30);
  });
  test('aviso anterior acontece exatamente 30 minutos antes', () {
    final alerts = calculateAlertMoments(appointment, 30, now);
    expect(alerts.length, 2);
    expect(alerts[0].when, DateTime(2026, 11, 17, 14, 30));
    expect(alerts[0].slot, 0);
    expect(alerts[1].when, appointment);
    expect(alerts[1].slot, 2);
  });
  test('cada pessoa pode escolher duas horas antes', () {
    final alerts = calculateAlertMoments(appointment, 120, now);
    expect(alerts[0].when, DateTime(2026, 11, 17, 13));
  });
  test('pode optar por receber somente no horário', () {
    final alerts = calculateAlertMoments(appointment, 0, now);
    expect(alerts.length, 1);
    expect(alerts.single.when, appointment);
  });
  test('caso a antecedência tenha passado, avisa no horário', () {
    final alerts = calculateAlertMoments(
      DateTime(2026, 11, 17, 10, 10), 30, now);
    expect(alerts.length, 1);
    expect(alerts.single.when, DateTime(2026, 11, 17, 10, 10));
  });
  test('não agenda compromissos no passado', () {
    expect(calculateAlertMoments(now.subtract(const Duration(minutes: 1)),
      30, now), isEmpty);
  });
  test('opções permitem 1 dia e 7 dias antes', () {
    expect(availableAdvanceMinutes, contains(1440));
    expect(availableAdvanceMinutes, contains(10080));
  });
}

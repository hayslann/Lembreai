/// Regras de antecedência do LembreAI.
const int defaultAdvanceMinutes = 30;
const List<int> availableAdvanceMinutes = [
  0, 5, 10, 15, 30, 60, 120, 360, 720, 1440, 2880, 10080,
];

int normalizedAdvanceMinutes(Object? value) {
  if (value is int && availableAdvanceMinutes.contains(value)) return value;
  return defaultAdvanceMinutes;
}

String advanceLabel(int value) {
  switch (value) {
    case 0: return 'Somente no horário';
    case 60: return '1 hora antes';
    case 120: return '2 horas antes';
    case 360: return '6 horas antes';
    case 720: return '12 horas antes';
    case 1440: return '1 dia antes';
    case 2880: return '2 dias antes';
    case 10080: return '7 dias antes';
    default: return '$value minutos antes';
  }
}

class AlertMoment {
  final int slot;
  final DateTime when;
  final String body;
  const AlertMoment(this.slot, this.when, this.body);
}

/// Dois avisos possíveis: antecedência selecionada e horário do compromisso.
/// O Android pode atrasar notificações se permissões ou bateria limitarem.
List<AlertMoment> calculateAlertMoments(
  DateTime appointment, int advanceMinutes, DateTime now,
) {
  final alerts = <AlertMoment>[];
  if (!appointment.isAfter(now)) return alerts;
  final minutes = normalizedAdvanceMinutes(advanceMinutes);
  if (minutes > 0) {
    final before = appointment.subtract(Duration(minutes: minutes));
    if (before.isAfter(now)) {
      alerts.add(AlertMoment(0, before,
        'Seu compromisso começa em ' +
        advanceLabel(minutes).replaceFirst(' antes', '') + '.'));
    }
  }
  alerts.add(AlertMoment(2, appointment, 'Chegou a hora do compromisso!'));
  return alerts;
}

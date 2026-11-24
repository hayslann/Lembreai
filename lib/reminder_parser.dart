class ParsedReminder {
  final String title;
  final DateTime when;
  const ParsedReminder(this.title, this.when);
}

// Resolve pedidos simples imediatamente, preservando o relógio da mensagem.
ParsedReminder? parseRelativeRequest(String input, DateTime now) {
  final command = RegExp(
    r'^(?:me (?:lembra|lembre|avisa|avise)|lembre-me|crie (?:um )?lembrete)\s+(?:(?:de|para|pra)\s+)?(.+)$',
    caseSensitive: false,
  ).firstMatch(input.trim());
  if (command == null) return null;
  final body = command.group(1)!.replaceFirst(RegExp(r'[.!]+$'), '').trim();
  final interval = RegExp(
    r'\b(?:daqui\s+(?:a\s+)?|em\s+)(?:(meia\s+hora)|([1-9]\d{0,4}|um|uma|dois|duas|três|tres|cinco|dez|quinze|vinte|trinta)\s+(segundos?|minutos?|horas?|dias?))\b',
    caseSensitive: false,
  );
  final matches = interval.allMatches(body).toList();
  if (matches.length != 1) return null;
  final match = matches.single;
  if (match.start != 0 && match.end != body.length) return null;
  final title = body.replaceRange(match.start, match.end, '').trim()
      .replaceFirst(RegExp(r'^[,\s]*(?:(?:de|para|pra)\s+)?', caseSensitive: false), '')
      .replaceFirst(RegExp(r'[,\s]+$'), '');
  if (title.isEmpty || RegExp(r'[?;\n]|\b(?:amanhã|hoje|antes|depois|todo|toda|cada|horas?|minutos?|segundos?|dias?|cancelar|alterar|adiar)\b', caseSensitive: false).hasMatch(title)) return null;
  const numbers = {'um':1, 'uma':1, 'dois':2, 'duas':2, 'três':3, 'tres':3,
    'cinco':5, 'dez':10, 'quinze':15, 'vinte':20, 'trinta':30};
  final amount = match.group(2)?.toLowerCase();
  final n = amount == null ? 30 : int.tryParse(amount) ?? numbers[amount]!;
  final unit = match.group(3)?.toLowerCase() ?? 'minutos';
  final duration = unit.startsWith('segundo') ? Duration(seconds:n)
      : unit.startsWith('minuto') ? Duration(minutes:n)
      : unit.startsWith('hora') ? Duration(hours:n) : Duration(days:n);
  if (duration > const Duration(days:3650)) return null;
  return ParsedReminder(title, now.add(duration));
}

/// Interpretação determinística para lembretes simples em português.
/// Não é uma IA generativa.
ParsedReminder? parseReminder(String input, DateTime now) {
  final lower = input.toLowerCase();
  final normalized = lower
      .replaceAll('ã', 'a')
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a');
  // Aceita "14:30", "09:00", "18h", "18h30" e "às 14".
  final t = RegExp(r'\b(?:as\s+)?(\d{1,2})(?::(\d{2})|h(\d{2})?|(?=\s|$))')
      .allMatches(normalized)
      .where((m) => m.group(0)!.contains(':') ||
          m.group(0)!.contains('h') ||
          m.group(0)!.trimLeft().startsWith('as '))
      .firstOrNull;
  if (t == null) return null;
  final hour = int.parse(t.group(1)!);
  final minute = int.tryParse(t.group(2) ?? t.group(3) ?? '0') ?? 0;
  if (hour > 23 || minute > 59) return null;

  DateTime? date;
  if (normalized.contains('amanha')) {
    date = DateTime(now.year, now.month, now.day + 1, hour, minute);
  } else if (normalized.contains('hoje')) {
    date = DateTime(now.year, now.month, now.day, hour, minute);
  } else {
    final match = RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{4}))?\b')
        .firstMatch(normalized);
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.tryParse(match.group(3) ?? '') ?? now.year;
    date = DateTime(year, month, day, hour, minute);
    if (date.day != day || date.month != month || date.year != year) return null;
    if (match.group(3) == null && !date.isAfter(now)) {
      date = DateTime(year + 1, month, day, hour, minute);
    }
  }
  if (!date.isAfter(now)) return null;

  var title = input
      .replaceFirst(RegExp(r'^\s*me\s+lembra(?:r)?\s+(?:de\s+)?', caseSensitive: false), '')
      .replaceFirst(RegExp(r'\b(?:amanhã|amanha|hoje)\b', caseSensitive: false), '')
      .replaceFirst(RegExp(r'\b\d{1,2}/\d{1,2}(?:/\d{4})?\b'), '')
      .replaceFirst(RegExp(r'(?:às|as)\s*\d{1,2}(?::\d{2}|h\d{0,2})?', caseSensitive: false), '')
      .replaceFirst(RegExp(r'\b\d{1,2}(?::\d{2}|h\d{0,2})\b'), '')
      .trim()
      .replaceFirst(RegExp(r'^horas\s+', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^de\s+', caseSensitive: false), '')
      .trim();
  if (title.isEmpty) title = 'Seu compromisso';
  return ParsedReminder(title, date);
}

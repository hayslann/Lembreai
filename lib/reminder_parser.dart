class ParsedReminder {
  final String title;
  final DateTime when;
  const ParsedReminder(this.title, this.when);
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
          normalized.substring(0, m.start).endsWith('as '))
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
      .replaceFirst(RegExp(r'(?i)^\s*me\s+lembra(?:r)?\s+(?:de\s+)?'), '')
      .replaceFirst(RegExp(r'(?i)\b(?:amanhã|amanha|hoje)\b'), '')
      .replaceFirst(RegExp(r'\b\d{1,2}/\d{1,2}(?:/\d{4})?\b'), '')
      .replaceFirst(RegExp(r'(?i)(?:às|as)\s*\d{1,2}(?::\d{2}|h\d{0,2})?'), '')
      .replaceFirst(RegExp(r'\b\d{1,2}(?::\d{2}|h\d{0,2})\b'), '')
      .trim()
      .replaceFirst(RegExp(r'(?i)^de\s+'), '')
      .trim();
  if (title.isEmpty) title = 'Seu compromisso';
  return ParsedReminder(title, date);
}

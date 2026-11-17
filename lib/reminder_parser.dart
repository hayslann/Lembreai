class ParsedReminder {
  final String title;
  final DateTime when;
  const ParsedReminder(this.title, this.when);
}

/// Interpretação local e restrita: sem API e sem prometer IA generativa.
/// Formatos: "amanhã às 14:30 de pagar boleto", "hoje 18h comprar pão",
/// "25/12 às 09:00 consulta".
ParsedReminder? parseReminder(String input, DateTime now) {
  final normalized = input.toLowerCase().replaceAll('ã', 'a').replaceAll('à', 'a');
  final timeMatch = RegExp(r'(?:as\s*)?(\d{1,2})(?:[:h](\d{2})|h)(?!\d)').firstMatch(normalized);
  if (timeMatch == null) return null;
  final hour = int.parse(timeMatch.group(1)!);
  final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
  if (hour > 23 || minute > 59) return null;
  DateTime? date;
  if (normalized.contains('amanha')) {
    date = DateTime(now.year, now.month, now.day + 1, hour, minute);
  } else if (normalized.contains('hoje')) {
    date = DateTime(now.year, now.month, now.day, hour, minute);
  } else {
    final m = RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{4}))?\b').firstMatch(normalized);
    if (m == null) return null;
    final day = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final year = int.tryParse(m.group(3) ?? '') ?? now.year;
    date = DateTime(year, month, day, hour, minute);
    if (date.day != day || date.month != month || date.year != year) return null;
    if (m.group(3) == null && !date.isAfter(now)) date = DateTime(year+1, month, day, hour, minute);
  }
  if (!date.isAfter(now)) return null;
  var title = input
      .replaceFirst(RegExp(r'(?i)^\s*me\s+lembra(?:r)?\s+(?:de\s+)?'), '')
      .replaceFirst(RegExp(r'(?i)\b(?:amanhã|amanha|hoje)\b'), '')
      .replaceFirst(RegExp(r'\b\d{1,2}/\d{1,2}(?:/\d{4})?\b'), '')
      .replaceFirst(RegExp(r'(?i)\b(?:às|as)?\s*\d{1,2}(?::\d{2}|h\d{0,2})\b'), '')
      .replaceFirst(RegExp(r'(?i)^\s*de\s+'), '')
      .trim();
  title = title.replaceFirst(RegExp(r'(?i)^de\s+'), '').trim();
  if (title.isEmpty) title = 'Seu compromisso';
  return ParsedReminder(title, date);
}

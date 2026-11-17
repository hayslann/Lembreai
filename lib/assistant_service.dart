import 'dart:convert';
import 'package:http/http.dart' as http;

class SuggestedReminder {
  final String title;
  final DateTime when;
  const SuggestedReminder(this.title, this.when);
}

class AssistantResponse {
  final String reply;
  final SuggestedReminder? reminder;
  const AssistantResponse(this.reply, this.reminder);
}

/// A chave de API fica exclusivamente no servidor, nunca no aplicativo.
class AssistantService {
  static const baseUrl = String.fromEnvironment('AI_SERVER_URL');
  // Somente desenvolvimento: token incluído no aplicativo pode ser extraído.
  static const devToken = String.fromEnvironment('LEMBREAI_DEV_TOKEN');

  static Future<AssistantResponse?> ask(String message, DateTime now) async {
    if (baseUrl.isEmpty) return null;
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http')) return null;
    final basePath = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1) : uri.path;
    final endpoint = uri.replace(path: basePath + '/chat');
    try {
      final response = await http.post(endpoint,
          headers:{
            'Content-Type':'application/json',
            if (devToken.isNotEmpty) 'Authorization':'Bearer ' + devToken,
          },
          body:jsonEncode({'message':message, 'now':now.toIso8601String()}))
          .timeout(const Duration(seconds: 24));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map) return null;
      final reply = data['reply'] is String ? (data['reply'] as String) : '';
      SuggestedReminder? reminder;
      final raw = data['reminder'];
      if (raw is Map && raw['title'] is String && raw['when'] is String) {
        final when = DateTime.tryParse(raw['when'] as String);
        final title = (raw['title'] as String).trim();
        if (when != null && when.isAfter(now) && title.isNotEmpty &&
            when.isBefore(now.add(const Duration(days: 3650)))) {
          reminder = SuggestedReminder(title, when);
        }
      }
      return AssistantResponse(reply,reminder);
    } catch (_) {
      return null;
    }
  }
}

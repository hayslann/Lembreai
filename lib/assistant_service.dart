import 'dart:convert';
import 'package:http/http.dart' as http;

class SuggestedReminder {
  final String title;
  final DateTime when;
  const SuggestedReminder(this.title, this.when);
}

class AssistantResponse {
  final String intent;
  final String reply;
  final SuggestedReminder? reminder;
  final int? targetId;
  const AssistantResponse(this.intent, this.reply, this.reminder, this.targetId);
}

class AssistantService {
  // Nunca coloque GEMINI_API_KEY nem OPENAI_API_KEY no APK.
  static const compiledUrl = String.fromEnvironment('AI_SERVER_URL');
  static String _customUrl = '';
  static String get baseUrl => _customUrl.isNotEmpty ? _customUrl : compiledUrl;
  static const devToken = String.fromEnvironment('LEMBREAI_DEV_TOKEN');
  static bool get isAvailable => baseUrl.isNotEmpty;

  static void setServerUrl(String url) {
    final candidate = url.trim();
    if (candidate.isEmpty) {
      _customUrl = '';
      return;
    }
    final uri = Uri.tryParse(candidate);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      _customUrl = candidate.replaceFirst(RegExp(r'/$'), '');
    }
  }

  static Future<bool> checkConnection() async {
    if (!isAvailable) return false;
    try {
      final uri = Uri.parse(baseUrl);
      final basePath = uri.path.endsWith('/')
          ? uri.path.substring(0, uri.path.length - 1) : uri.path;
      final res = await http.get(uri.replace(path: '$basePath/health'))
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<AssistantResponse?> ask(
    String message,
    DateTime now, {
    List<Map<String, dynamic>> history = const [],
    List<Map<String, dynamic>> reminders = const [],
  }) async {
    if (!isAvailable) return null;
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    final basePath = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1) : uri.path;
    final endpoint = uri.replace(path: '$basePath/chat');
    try {
      final response = await http.post(endpoint,
        headers: {
          'Content-Type': 'application/json',
          if (devToken.isNotEmpty) 'Authorization': 'Bearer $devToken',
        },
        body: jsonEncode({
          'message': message,
          'now': now.toIso8601String(),
          'history': history.length > 8
              ? history.sublist(history.length - 8) : history,
          'reminders': reminders.take(100).toList(),
        }),
      ).timeout(const Duration(seconds: 24));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map) return null;
      final intent = data['intent'] is String ? data['intent'] as String : 'chat';
      final reply = data['reply'] is String ? data['reply'] as String : '';
      final id = data['targetId'] is int ? data['targetId'] as int : null;
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
      return AssistantResponse(intent, reply, reminder, id);
    } catch (_) {
      return null;
    }
  }
}

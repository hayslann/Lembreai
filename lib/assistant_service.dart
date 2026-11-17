import 'dart:convert';
import 'package:http/http.dart' as http;

class SuggestedReminder {
  final String title;
  final DateTime when;
  final String location;
  final int? advanceMinutes;
  const SuggestedReminder(this.title, this.when, {this.location = '', this.advanceMinutes});
}

class AssistantResponse {
  final String intent;
  final String reply;
  final SuggestedReminder? reminder;
  final List<SuggestedReminder> reminders;
  final int? targetId;
  const AssistantResponse(this.intent, this.reply, this.reminder, this.targetId,
      {this.reminders = const []});
}

class AssistantService {
  // Nunca inclua chaves do Gemini/OpenAI no aplicativo.
  static const compiledUrl = String.fromEnvironment(
    'AI_SERVER_URL',
    defaultValue: 'https://lembreai-ia.hayslan08.workers.dev',
  );
  static const devToken = String.fromEnvironment('LEMBREAI_DEV_TOKEN');
  static String _customUrl = '';
  static String get baseUrl => _customUrl.isNotEmpty ? _customUrl : compiledUrl;
  static bool get isAvailable => baseUrl.isNotEmpty;

  static void setServerUrl(String url) {
    final candidate = url.trim();
    if (candidate.isEmpty) { _customUrl = ''; return; }
    final uri = Uri.tryParse(candidate);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      _customUrl = candidate.replaceFirst(RegExp(r'/$'), '');
    }
  }

  static Uri? _endpoint(String path) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    final base = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1) : uri.path;
    return uri.replace(path: '$base/$path');
  }

  static Future<bool> checkConnection() async {
    final url = _endpoint('health');
    if (url == null) return false;
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) { return false; }
  }

  static SuggestedReminder? _parseReminder(dynamic raw, DateTime now) {
    if (raw is! Map || raw['title'] is! String || raw['when'] is! String) return null;
    final when = DateTime.tryParse(raw['when'] as String);
    final title = (raw['title'] as String).trim();
    if (when == null || !when.isAfter(now) || title.isEmpty ||
        when.isAfter(now.add(const Duration(days: 3650)))) return null;
    final location = raw['location'] is String ? (raw['location'] as String).trim() : '';
    final advance = raw['advanceMinutes'];
    const allowed = [0,5,10,15,30,60,120,360,720,1440,2880,10080];
    return SuggestedReminder(title, when,
      location: location, advanceMinutes: advance is int && allowed.contains(advance) ? advance : null);
  }

  static Future<AssistantResponse?> ask(
    String message, DateTime now, {
    List<Map<String,dynamic>> history = const [],
    List<Map<String,dynamic>> reminders = const [],
    String? imageBase64,
    String? imageMimeType,
  }) async {
    final endpoint = _endpoint('chat');
    if (endpoint == null) return null;
    try {
      final response = await http.post(endpoint,
        headers: {
          'Content-Type':'application/json',
          if (devToken.isNotEmpty) 'Authorization':'Bearer $devToken',
        },
        body:jsonEncode({
          'message':message,
          'now':now.toIso8601String(),
          'history':history.length > 8 ? history.sublist(history.length - 8) : history,
          'reminders':reminders.take(100).toList(),
          if (imageBase64 != null && imageMimeType != null)
            'image':{'mimeType':imageMimeType,'data':imageBase64},
        }),
      ).timeout(const Duration(seconds: 55));
      if (response.statusCode != 200) return null;
      final data=jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map) return null;
      final intent=data['intent'] is String ? data['intent'] as String : 'chat';
      final reply=data['reply'] is String ? data['reply'] as String : '';
      final targetId=data['targetId'] is int ? data['targetId'] as int : null;
      final first=_parseReminder(data['reminder'], now);
      final suggestions=<SuggestedReminder>[];
      if (data['reminders'] is List) {
        for (final entry in (data['reminders'] as List).take(10)) {
          final candidate=_parseReminder(entry,now);
          if (candidate != null && !suggestions.any((r)=>r.title==candidate.title && r.when==candidate.when)) {
            suggestions.add(candidate);
          }
        }
      }
      if (intent=='create' && suggestions.isEmpty && first!=null) suggestions.add(first);
      return AssistantResponse(intent,reply,first??(suggestions.isEmpty?null:suggestions.first),
        targetId,reminders:suggestions);
    } catch (_) {
      return null;
    }
  }
}

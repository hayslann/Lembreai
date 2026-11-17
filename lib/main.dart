import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'reminder_parser.dart';
import 'assistant_service.dart';
import 'alert_preferences.dart';

final alarms = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
  } catch (_) {}
  await alarms.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));
  runApp(const LembreAI());
}

class Reminder {
  final int id;
  final String title;
  final DateTime when;
  bool done;
  int advanceMinutes;

  Reminder(this.id, this.title, this.when, {
    this.done = false,
    this.advanceMinutes = defaultAdvanceMinutes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'when': when.toIso8601String(),
    'done': done,
    'advanceMinutes': advanceMinutes,
  };

  factory Reminder.fromJson(Map<String, dynamic> v) =>
      Reminder(v['id'] as int, v['title'] as String,
        DateTime.parse(v['when'] as String),
        done: v['done'] == true,
        advanceMinutes: normalizedAdvanceMinutes(v['advanceMinutes']));
}

/// Agenda avisos sonoros usando o canal específico da nova versão.
/// O som depende de permissão, volume, modo silencioso e economia de bateria.
Future<bool> scheduleReminder(Reminder r, {bool requestPermissions = false}) async {
  final android = alarms.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (requestPermissions) {
    final notificationsGranted = await android?.requestNotificationsPermission();
    if (notificationsGranted == false) {
      throw StateError('Permissão de notificações não concedida.');
    }
    // No Android 12+, o usuário precisa autorizar alarmes precisos.
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {
      // Alguns Androids não permitem abrir essa tela; agenda com
      // horário aproximado no lugar de abandonar o lembrete.
    }
  }
  final exact = await android?.canScheduleExactNotifications() == true;
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'lembreai_lembretes_sonoros_v2', 'LembreAI — avisos sonoros',
      channelDescription: 'Lembretes antes e no horário de cada compromisso',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
    ),
  );
  // Limpa os 3 slots usados na versão antiga (incluindo aviso de 1 dia).
  await cancelReminder(r);
  final moments = calculateAlertMoments(
      r.when, r.advanceMinutes, DateTime.now());
  for (final moment in moments) {
    await alarms.zonedSchedule(
      r.id * 3 + moment.slot, '🔔 ' + r.title, moment.body,
      tz.TZDateTime.from(moment.when, tz.local),
      details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
  // false significa que o Android pode atrasar o toque.
  return exact;
}

Future<void> cancelReminder(Reminder r) async {
  for (var i = 0; i < 3; i++) {
    await alarms.cancel(r.id * 3 + i);
  }
}

class LembreAI extends StatelessWidget {
  const LembreAI({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LembreAI', debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff7844ed), brightness: Brightness.dark),
      useMaterial3: true,
    ),
    home: const MainScreen(),
  );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final input = TextEditingController();
  final nameInput = TextEditingController();
  final messages = <(bool, String)>[
    (false, 'Olá! 🤖 Sou o LembreAI. Digite: Me lembra amanhã às 14:30 de pagar o boleto.')
  ];
  final reminders = <Reminder>[];
  String name = '';
  bool loaded = false;
  bool sending = false;
  int selectedAdvanceMinutes = defaultAdvanceMinutes;
  int page = 0;
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { input.dispose(); nameInput.dispose(); super.dispose(); }
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('reminders');
    try {
      if (raw != null) {
        reminders.addAll((jsonDecode(raw) as List)
            .map((e) => Reminder.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}
    // Migra os alertas antigos (1 dia/40 minutos) para a nova regra.
    for (final r in reminders) {
      try {
        if (r.done || !r.when.isAfter(DateTime.now())) {
          await cancelReminder(r);
        } else {
          await scheduleReminder(r);
        }
      } catch (_) {
        // O aplicativo continua abrindo, mesmo que Android negue alarmes.
      }
    }
    AssistantService.setServerUrl(prefs.getString('ai_server_url') ?? '');
    if (!mounted) return;
    setState(() { name = prefs.getString('name') ?? ''; loaded = true; });
  }
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reminders', jsonEncode(reminders.map((e)=>e.toJson()).toList()));
  }
  String upcomingSummary() {
    final upcoming = reminders.where((r) => !r.done)
        .toList()..sort((a, b) => a.when.compareTo(b.when));
    if (upcoming.isEmpty) {
      return 'Você não tem lembretes ativos cadastrados neste aparelho.';
    }
    final rows = upcoming.take(10).map((r) =>
        '• ' + r.title + ' — ' + formatted(r.when)).join('\n');
    return 'Estes são seus lembretes ativos neste aparelho:\n' + rows;
  }

  bool isListing(String text) {
    final t = text.toLowerCase();
    return t.contains('meus lembretes') ||
        t.contains('minha agenda') ||
        t.contains('meus compromissos') ||
        t.contains('o que tenho marcado') ||
        t.contains('o que tenho agendado') ||
        t.contains('quais lembretes');
  }

  Future<bool> askConfirmation(String title, String detail) async {
    if (!mounted) return false;
    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar')),
        ],
      ),
    ) ?? false;
  }

  void bot(String text) {
    if (mounted) setState(() => messages.add((false, text)));
  }

  Future<bool> authorizeOnlineAI() async {
    if (!AssistantService.isAvailable) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('online_ai_consent') == true) return true;
    if (!mounted) return false;
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Usar inteligência artificial online?'),
        content: const Text(
          'Para compreender mensagens e compromissos, o aplicativo enviará '
          'sua mensagem, parte da conversa e os lembretes cadastrados para '
          'o servidor e o provedor de inteligência artificial configurado. '
          'Você pode continuar usando lembretes básicos sem ativar isso.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Agora não')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Aceitar e continuar')),
        ],
      ),
    ) ?? false;
    if (answer) await prefs.setBool('online_ai_consent', true);
    return answer;
  }

  Future<void> handleExistingReminder(AssistantResponse result) async {
    final id = result.targetId;
    if (id == null) {
      bot('Qual compromisso você deseja alterar? Veja os detalhes na Agenda.');
      return;
    }
    final index = reminders.indexWhere((r) => r.id == id);
    if (index < 0) {
      bot('Não encontrei esse compromisso no seu aparelho.');
      return;
    }
    final original = reminders[index];
    if (result.intent == 'cancel' || result.intent == 'complete') {
      final verb = result.intent == 'cancel' ? 'Cancelar' : 'Concluir';
      final confirmed = await askConfirmation(
        verb + ' lembrete?',
        original.title + '\n' + formatted(original.when),
      );
      if (!confirmed) { bot('Entendido, não alterei o lembrete.'); return; }
      await cancelReminder(original);
      setState(() {
        if (result.intent == 'cancel') {
          reminders.removeAt(index);
        } else {
          original.done = true;
        }
      });
      await save();
      bot('Pronto! O compromisso foi ' +
          (result.intent == 'cancel' ? 'cancelado.' : 'marcado como concluído.'));
      return;
    }
    if (result.intent == 'update') {
      final suggestion = result.reminder;
      if (suggestion == null) {
        bot('Diga a nova data e o horário desejados.');
        return;
      }
      final confirmed = await askConfirmation(
        'Alterar compromisso?',
        original.title + '\nDe: ' + formatted(original.when) +
        '\nPara: ' + suggestion.title + '\n' + formatted(suggestion.when),
      );
      if (!confirmed) { bot('Tudo bem, mantive o compromisso anterior.'); return; }
      await cancelReminder(original);
      final updated = Reminder(original.id, suggestion.title, suggestion.when,
        advanceMinutes: original.advanceMinutes);
      setState(() => reminders[index] = updated);
      await save();
      try {
        final exact = await scheduleReminder(updated, requestPermissions: true);
        bot('Compromisso atualizado para ' + formatted(updated.when) +
          '. Aviso: ' + advanceLabel(updated.advanceMinutes).toLowerCase() +
          ' e no horário.' + (exact ? '' :
            ' O Android pode atrasar os alertas sem permissão de alarme preciso.'));
      } catch (_) {
        bot('Compromisso alterado, mas não consegui programar os avisos. '
            'Confira as permissões de notificação.');
      }
    }
  }

  Future<void> send() async {
    final message = input.text.trim();
    if (message.isEmpty || sending) return;
    input.clear();
    setState(() {
      sending = true;
      messages.add((true, message));
    });
    try {
      final now = DateTime.now();
      AssistantResponse? online;
      if (await authorizeOnlineAI()) {
        online = await AssistantService.ask(
          message, now,
          history: messages.skip(messages.length > 8 ? messages.length - 8 : 0).map((m) =>
            {'role':m.$1 ? 'user' : 'assistant', 'text':m.$2}).toList(),
          reminders: reminders.map((r)=>r.toJson()).toList(),
        );
      }
      if (!mounted) return;
      if (online != null) {
        if (online.intent == 'list') { bot(upcomingSummary()); return; }
        if (['update','cancel','complete'].contains(online.intent)) {
          await handleExistingReminder(online);
          return;
        }
        if (online.intent == 'chat' || online.intent == 'clarify') {
          bot(online.reply.isNotEmpty ? online.reply :
            'Você poderia explicar melhor o que deseja?');
          return;
        }
      }
      if (online == null && isListing(message)) {
        bot(upcomingSummary());
        return;
      }
      final local = online == null ? parseReminder(message, now) : null;
      final suggested = online?.reminder;
      final title = suggested?.title ?? local?.title;
      final when = suggested?.when ?? local?.when;
      if (title == null || when == null) {
        bot(online?.reply.isNotEmpty == true ? online!.reply :
          'Posso ajudar a organizar compromissos. Por exemplo: '
          '"Me lembre amanhã às 14 horas de pagar a conta". '
          'Preciso de data, horário e assunto para criar um lembrete.');
        return;
      }
      if (reminders.where((r) => !r.done).length >= 10) {
        bot('Você chegou ao limite gratuito de dez lembretes ativos. '
            'Conclua um compromisso para cadastrar outro.');
        return;
      }
      final reminder = Reminder(
        DateTime.now().millisecondsSinceEpoch % 100000000, title, when,
        advanceMinutes: selectedAdvanceMinutes);
      setState(() => reminders.add(reminder));
      await save();
      try {
        final exact = await scheduleReminder(reminder, requestPermissions: true);
        bot('Lembrete salvo: "' + title + '" para ' + formatted(when) +
          '. O celular foi configurado para avisar ' +
          advanceLabel(reminder.advanceMinutes).toLowerCase() +
          (reminder.advanceMinutes == 0
            ? '.' : ' e no horário marcado.') +
          (exact ? '' : ' Atenção: sem a permissão de alarmes precisos, '
          'o Android pode atrasar o toque.'));
      } catch (_) {
        bot('Salvei o lembrete para ' + formatted(when) +
          ', mas não consegui programar os avisos. '
          'Confira as permissões de notificação.');
      }
    } catch (_) {
      bot('Não consegui completar seu pedido agora. '
        'Seus lembretes já cadastrados permanecem salvos.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
  String formatted(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')} '
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

  Future<void> register() async {
    final entered = nameInput.text.trim();
    if (entered.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', entered);
    if (mounted) setState(() => name = entered);
  }

  Future<void> testNotificationSound() async {
    final android = alarms.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final allowed = await android?.requestNotificationsPermission();
    if (allowed == false) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Autorize as notificações do LembreAI no Android '
          'para ouvir os alertas sonoros.')));
      return;
    }
    try {
      await alarms.show(
        999000001,
        '🔔 Teste de som do LembreAI',
        'Se ouviu este aviso, o som das notificações está habilitado.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'lembreai_lembretes_sonoros_v2', 'LembreAI — avisos sonoros',
            channelDescription: 'Lembretes antes e no horário de cada compromisso',
            importance: Importance.max, priority: Priority.max,
            playSound: true, enableVibration: true,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Não foi possível tocar a notificação. '
          'Verifique o volume, o modo silencioso e as permissões.')));
    }
  }

  Future<void> configureAi() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('ai_server_url') ?? '';
    final controller = TextEditingController(text: current);
    if (!mounted) return;
    final answer = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Conectar inteligência artificial'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'Cole o endereço HTTPS fornecido pela Cloudflare Workers. '
              'A chave secreta do Gemini fica somente no servidor, '
              'nunca neste aplicativo.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Endereço HTTPS do servidor',
                hintText: 'https://lembreai-ia.exemplo.workers.dev',
                border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Text('Para desativar a conexão online, apague o endereço '
              'e toque em Salvar.'),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Voltar')),
          FilledButton(onPressed: () =>
            Navigator.pop(dialogContext,controller.text.trim()),
            child: const Text('Salvar')),
        ],
      ),
    );
    controller.dispose();
    if (answer == null || !mounted) return;
    final uri = Uri.tryParse(answer);
    if (answer.isNotEmpty && (uri?.scheme != 'https' || uri?.host.isEmpty == true)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Informe um endereço HTTPS válido.')));
      return;
    }
    if (answer != current) await prefs.setBool('online_ai_consent', false);
    await prefs.setString('ai_server_url', answer);
    AssistantService.setServerUrl(answer);
    final connected = answer.isNotEmpty &&
      await AssistantService.checkConnection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(answer.isEmpty
        ? 'Inteligência artificial online desativada.'
        : connected
          ? 'Servidor encontrado. Faça uma pergunta para testar o Gemini.'
          : 'Endereço salvo, mas o servidor ainda não respondeu. '
            'Confira a publicação na Cloudflare.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (name.isEmpty) {
      return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: Text('🤖', style: TextStyle(fontSize: 76))),
                const SizedBox(height: 12),
                Text('Bem-vindo ao LembreAI',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 14),
                const Text(
                  'Sua assistente pessoal para organizar compromissos e '
                  'lembrar do que é importante.',
                  textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: nameInput,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Seu nome completo',
                    border: OutlineInputBorder()),
                  onSubmitted: (_) => register(),
                ),
                const SizedBox(height: 16),
                const Text('Seus compromissos são salvos neste celular. '
                  'A conversa com inteligência artificial online será '
                  'ativada quando o servidor estiver configurado.'),
                const SizedBox(height: 20),
                FilledButton(onPressed: register, child: const Text('Começar')),
              ],
            ),
          ),
        ),
      ))));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('🤖 LembreAI'),
        actions: [
          IconButton(onPressed: configureAi,
            tooltip: 'Conectar inteligência artificial',
            icon: const Icon(Icons.settings)),
          Padding(padding: const EdgeInsets.all(12),
            child: Center(child: Text(name))),
        ]),
      body: page == 0 ? Column(children: [
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(16), itemCount: messages.length,
          itemBuilder: (context, i) {
            final msg = messages[i];
            return Align(
              alignment: msg.$1 ? Alignment.centerRight : Alignment.centerLeft,
              child: Card(color: msg.$1 ? const Color(0xff5731a8) : null,
                child: Padding(padding: const EdgeInsets.all(14),
                  child: Text(msg.$2))),
            );
          },
        )),
        SafeArea(child: Padding(padding: const EdgeInsets.all(8),
          child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.notifications_active_outlined, size: 18),
              const SizedBox(width: 8),
              const Text('Aviso sonoro: '),
              Expanded(child: DropdownButton<int>(
                isExpanded: true,
                value: selectedAdvanceMinutes,
                items: [
                  for (final minutes in availableAdvanceMinutes)
                    DropdownMenuItem<int>(
                      value: minutes, child: Text(advanceLabel(minutes),
                      overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => selectedAdvanceMinutes = value);
                },
              )),
            ]),
            Row(children: [
              Expanded(child: TextField(controller: input,
                onSubmitted: (_) => send(),
                decoration: const InputDecoration(
                  hintText: 'Descreva seu compromisso...',
                  border: OutlineInputBorder()))),
              IconButton(onPressed: sending ? null : send,
                icon: const Icon(Icons.send)),
            ]),
          ]))),
      ]) : ListView(children: [
        ListTile(title: const Text('Meus lembretes'),
          subtitle: const Text('Os avisos tocam no horário e, por padrão, '
            '30 minutos antes. Ajuste cada compromisso se desejar.'),
          trailing: IconButton(
            tooltip: 'Testar som do alerta',
            icon: const Icon(Icons.volume_up_outlined),
            onPressed: testNotificationSound,
          ),
        ),
        for (final r in reminders)
          CheckboxListTile(
            value: r.done,
            title: Text(r.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatted(r.when)),
                DropdownButton<int>(
                  value: r.advanceMinutes,
                  isExpanded: true,
                  items: [
                    for (final minutes in availableAdvanceMinutes)
                      DropdownMenuItem<int>(
                        value: minutes, child: Text(
                          advanceLabel(minutes), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: r.done ? null : (value) async {
                    if (value == null || value == r.advanceMinutes) return;
                    setState(() => r.advanceMinutes = value);
                    await save();
                    try {
                      await scheduleReminder(r, requestPermissions: true);
                    } catch (_) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(
                          'Ajuste salvo, mas não foi possível programar o som. '
                          'Verifique as permissões do celular.')));
                    }
                  },
                ),
              ],
            ),
            onChanged: (value) async {
              setState(() => r.done = value ?? false);
              await save();
              if (r.done) {
                await cancelReminder(r);
              } else {
                try { await scheduleReminder(r, requestPermissions: true); }
                catch (_) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Habilite as notificações e '
                    'os alarmes para receber avisos sonoros.')));
                }
              }
            },
          ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page, onDestinationSelected: (v) => setState(() => page = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.event_note), label: 'Agenda'),
        ],
      ),
    );
  }
}

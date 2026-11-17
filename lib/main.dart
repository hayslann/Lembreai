import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'reminder_parser.dart';
import 'assistant_service.dart';

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
  Reminder(this.id, this.title, this.when, {this.done = false});
  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'when': when.toIso8601String(), 'done': done};
  factory Reminder.fromJson(Map<String, dynamic> v) =>
      Reminder(v['id'] as int, v['title'] as String, DateTime.parse(v['when'] as String),
          done: v['done'] == true);
}

Future<void> scheduleReminder(Reminder r) async {
  final android = alarms.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await android?.requestNotificationsPermission();
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'lembreai_alertas', 'Lembretes',
      channelDescription: 'Avisos antecipados e compromissos',
      importance: Importance.max, priority: Priority.high,
      playSound: true, enableVibration: true,
    ),
  );
  final offsets = [const Duration(days: 1), const Duration(minutes: 40), Duration.zero];
  for (var i = 0; i < offsets.length; i++) {
    final when = r.when.subtract(offsets[i]);
    if (when.isAfter(DateTime.now())) {
      await alarms.zonedSchedule(
        r.id * 3 + i, '🔔 ${r.title}',
        i == 2 ? 'Chegou a hora!' : 'Compromisso em ${offsets[i].inMinutes} minutos',
        tz.TZDateTime.from(when, tz.local), details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
Future<void> cancelReminder(Reminder r) async {
  for (var i = 0; i < 3; i++) { await alarms.cancel(r.id * 3 + i); }
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
  final messages = <(bool, String)>[
    (false, 'Olá! 🤖 Sou o LembreAI. Digite: Me lembra amanhã às 14:30 de pagar o boleto.')
  ];
  final reminders = <Reminder>[];
  String name = '';
  bool loaded = false;
  bool registrationOpen = false;
  bool sending = false;
  int page = 0;
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { input.dispose(); super.dispose(); }
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('reminders');
    try {
      if (raw != null) {
        reminders.addAll((jsonDecode(raw) as List)
            .map((e) => Reminder.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() { name = prefs.getString('name') ?? ''; loaded = true; });
  }
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reminders', jsonEncode(reminders.map((e)=>e.toJson()).toList()));
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
      final local = parseReminder(message, now);
      final online = await AssistantService.ask(message, now);
      if (!mounted) return;
      DateTime? when = online?.reminder?.when ?? local?.when;
      String? title = online?.reminder?.title ?? local?.title;
      if (when == null || title == null) {
        setState(() => messages.add((false,
          online?.reply.isNotEmpty == true
            ? online!.reply
            : 'Posso ajudar a organizar seus compromissos. Escreva, por exemplo: '
              '"Lembre-me amanhã às 14 horas de pagar a conta". '
              'Para criar um lembrete, preciso saber a data, o horário e o assunto.')));
        return;
      }
      if (reminders.where((r) => !r.done).length >= 10) {
        setState(() => messages.add((false,
          'Você atingiu o limite de dez lembretes ativos. '
          'Marque um compromisso como concluído para cadastrar outro.')));
        return;
      }
      final reminder = Reminder(
        DateTime.now().millisecondsSinceEpoch % 100000000, title, when);
      setState(() => reminders.add(reminder));
      await save();
      bool notified = true;
      try { await scheduleReminder(reminder); }
      catch (_) { notified = false; }
      if (!mounted) return;
      setState(() => messages.add((false,
        notified
          ? 'Pronto! Seu lembrete "' + title! + '" foi salvo para '
            + formatted(when) + '. O aplicativo programou avisos para '
              'um dia antes, quarenta minutos antes e no horário, '
              'quando esses horários ainda estiverem no futuro.'
          : 'Salvei "' + title! + '" para ' + formatted(when)
            + ', mas não consegui ativar as notificações. '
              'Verifique as permissões do aplicativo no celular.')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
  String formatted(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')} '
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

  Future<void> register() async {
    if (registrationOpen || !mounted || name.isNotEmpty) return;
    registrationOpen = true;
    final controller = TextEditingController();
    final answer = await showDialog<String>(
      context: context, barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Bem-vindo ao LembreAI 🤖'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Seus lembretes ficam neste aparelho. A conexão com uma assistente online será ativada quando o servidor estiver configurado.'),
          TextField(controller: controller,
            decoration: const InputDecoration(labelText: 'Seu nome')),
          const SizedBox(height: 12),
          const Text('Este aplicativo armazena seus lembretes neste aparelho. Você pode criar até dez compromissos ativos.'),
        ]),
        actions: [FilledButton(onPressed: () {
          if (controller.text.trim().isNotEmpty) Navigator.pop(c, controller.text.trim());
        }, child: const Text('Começar'))],
      ),
    );
    controller.dispose();
    registrationOpen = false;
    if (!mounted || answer == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('name', answer);
    if (mounted) setState(() => name = answer);
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (name.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && name.isEmpty) register();
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('🤖 LembreAI'),
        actions: [Padding(padding: const EdgeInsets.all(12),
          child: Center(child: Text(name))) ]),
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
        SafeArea(child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          Expanded(child: TextField(controller: input,
            onSubmitted: (_) => send(),
            decoration: const InputDecoration(
              hintText: 'Digite seu lembrete...', border: OutlineInputBorder()))),
          IconButton(onPressed: sending ? null : send, icon: const Icon(Icons.send)),
        ]))),
      ]) : ListView(children: [
        const ListTile(title: Text('Meus lembretes'),
          subtitle: Text('Você pode concluir um lembrete para liberar espaço.')),
        for (final r in reminders)
          CheckboxListTile(
            value: r.done,
            title: Text(r.title),
            subtitle: Text(formatted(r.when)),
            onChanged: (value) async {
              setState(() => r.done = value ?? false);
              await save();
              if (r.done) { await cancelReminder(r); }
              else { await scheduleReminder(r); }
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

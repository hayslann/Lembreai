import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'brand_logo.dart';
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
  final String location;
  bool done;
  int advanceMinutes;

  Reminder(this.id, this.title, this.when, {
    this.done = false,
    this.location = '',
    this.advanceMinutes = defaultAdvanceMinutes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'when': when.toIso8601String(),
    'location': location,
    'done': done,
    'advanceMinutes': advanceMinutes,
  };

  factory Reminder.fromJson(Map<String, dynamic> v) =>
      Reminder(v['id'] as int, v['title'] as String,
        DateTime.parse(v['when'] as String),
        done: v['done'] == true,
        location: v['location'] is String ? v['location'] as String : '',
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
      r.id * 3 + moment.slot, '🔔 ' + r.title,
      moment.body + (r.location.isEmpty ? '' : '\nLocal: ' + r.location),
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
    home: const SplashScreen(),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;
  @override
  void initState() {
    super.initState();
    animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()));
    });
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfffaf7ff),
    body: SafeArea(
      child: Center(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Opacity(
            opacity: Curves.easeOut.transform(animation.value),
            child: Transform.scale(
              scale: 0.91 + 0.09 * Curves.easeOut.transform(animation.value),
              child: child,
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BrandLogo(size: 280),
              SizedBox(height: 16),
              Text(
                'Sua IA para lembrar do que importa.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xff431263),
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(color: Color(0xff7915d6)),
            ],
          ),
        ),
      ),
    ),
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
  Uint8List? attachedPhoto;
  String? attachedMime;
  String? attachedName;
  final picker = ImagePicker();
  final messages = <(bool, String)>[
    (false, 'Oi! Sou o LembreAI 💜 Converse comigo ou me mande uma foto da agenda e até o texto de um e-mail para organizar os compromissos.')
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
    // Servidor Gemini definido no aplicativo. O cliente não digita nenhuma URL.
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
        '• ' + r.title + ' — ' + formatted(r.when) +
        (r.location.isEmpty ? '' : ' — ' + r.location)).join('\n');
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
          'sua mensagem, fotos anexadas, parte da conversa e os lembretes cadastrados para '
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
        location: suggestion.location.isEmpty ? original.location : suggestion.location,
        advanceMinutes: suggestion.advanceMinutes ?? original.advanceMinutes);
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


  Future<void> addPhoto(ImageSource source) async {
    if (sending) return;
    try {
      final file=await picker.pickImage(
        source:source,maxWidth:1600,imageQuality:72,requestFullMetadata:false);
      if (file==null) return;
      final bytes=await file.readAsBytes();
      if (bytes.length>3*1024*1024) {
        bot('Essa imagem é grande demais. Tente uma foto menor.');
        return;
      }
      String? mime;
      if (bytes.length>3 && bytes[0]==0xff && bytes[1]==0xd8) {
        mime='image/jpeg';
      } else if (bytes.length>4 && bytes[0]==137 &&
          bytes[1]==80 && bytes[2]==78 && bytes[3]==71) {
        mime='image/png';
      } else if (bytes.length>12 &&
          String.fromCharCodes(bytes.sublist(0,4))=='RIFF' &&
          String.fromCharCodes(bytes.sublist(8,12))=='WEBP') {
        mime='image/webp';
      }
      if (mime==null) {
        bot('Envie uma imagem JPEG, PNG ou WebP.');
        return;
      }
      if (mounted) setState(() {
        attachedPhoto=bytes;attachedMime=mime;attachedName=file.name;
      });
    } catch (_) {
      bot('Não consegui abrir a imagem. Verifique as permissões do celular.');
    }
  }

  Future<void> send() async {
    final typed=input.text.trim();
    final photo=attachedPhoto;
    final mime=attachedMime;
    if ((typed.isEmpty && photo==null) || sending) return;
    final message=typed.isEmpty
      ? 'Analise esta imagem e extraia todos os eventos com assunto, data, hora e endereço.'
      : typed;
    input.clear();
    setState(() {
      sending=true;
      messages.add((true,message+(photo==null ? '' : '\n📷 Foto anexada')));
      attachedPhoto=null;attachedMime=null;attachedName=null;
    });
    try {
      final now=DateTime.now();
      AssistantResponse? online;
      if (await authorizeOnlineAI()) {
        online=await AssistantService.ask(message,now,
          imageBase64:photo==null ? null : base64Encode(photo),
          imageMimeType:mime,
          history:messages.skip(messages.length>8 ? messages.length-8 : 0)
            .map((m)=>{'role':m.$1 ? 'user' : 'assistant','text':m.$2}).toList(),
          reminders:reminders.map((r)=>r.toJson()).toList());
      }
      if (!mounted) return;
      if (online!=null) {
        if (online.intent=='list') {bot(upcomingSummary());return;}
        if (['update','cancel','complete'].contains(online.intent)) {
          await handleExistingReminder(online);return;
        }
        if (online.intent=='chat' || online.intent=='clarify') {
          bot(online.reply.isNotEmpty ? online.reply : 'Me conta um pouco mais?');
          return;
        }
      } else if (photo!=null) {
        bot('Recebi a foto, mas a inteligência artificial online ainda não respondeu. '
          'Verifique sua internet e tente novamente. O servidor já vem configurado no aplicativo.');
        return;
      } else if (isListing(message)) {
        bot(upcomingSummary());return;
      } else if (RegExp(r'^(oi|olá|ola|bom dia|boa tarde|boa noite|e aí|eai|tudo bem)[!?.\s]*$')
          .hasMatch(message.toLowerCase().trim())) {
        bot('Oi! 💜 Podemos conversar normalmente. Também posso te ajudar '
          'com agenda, provas e compromissos.');
        return;
      }
      final local=online==null ? parseReminder(message,now) : null;
      final suggestions=<SuggestedReminder>[
        if (online!=null && online.reminders.isNotEmpty) ...online.reminders,
        if (online!=null && online.reminders.isEmpty && online.reminder!=null) online.reminder!,
        if (online==null && local!=null) SuggestedReminder(local.title,local.when),
      ];
      if (suggestions.isEmpty) {
        bot(online?.reply.isNotEmpty==true ? online!.reply :
          AssistantService.isAvailable
            ? 'O Gemini não respondeu agora. Tente novamente ou use um lembrete simples com data e horário.'
            : 'Posso organizar sua agenda. Para conversa livre e interpretação de fotos '
              'ou e-mails, é necessária uma conexão com a internet.');
        return;
      }
      final unique=<SuggestedReminder>[];
      for (final r in suggestions) {
        if (r.when.isAfter(now) &&
          !unique.any((x)=>x.title.toLowerCase()==r.title.toLowerCase() && x.when==r.when) &&
          !reminders.any((x)=>!x.done && x.title.toLowerCase()==r.title.toLowerCase() && x.when==r.when)) {
          unique.add(r);
        }
      }
      if (unique.isEmpty) {
        bot('Esses compromissos já estão cadastrados ou não têm data futura válida.');
        return;
      }
      final slots=10-reminders.where((r)=>!r.done).length;
      if (unique.length>slots) {
        bot('Encontrei '+unique.length.toString()+' compromissos, mas restam apenas '
          +slots.toString()+' vagas no plano gratuito. Conclua lembretes antigos antes de importar.');
        return;
      }
      if (photo!=null || unique.length>1) {
        final details=unique.map((r)=>'• '+r.title+'\n  '+formatted(r.when)+
          (r.location.isEmpty ? '' : '\n  Local: '+r.location)).join('\n\n');
        final ok=await askConfirmation(
          'Agendar '+unique.length.toString()+' compromisso(s)?',
          details+'\n\nOs avisos serão emitidos 30 minutos antes e no horário, por padrão.');
        if (!ok) {bot('Tudo bem. Não criei nenhum compromisso.');return;}
      }
      final added=<Reminder>[];
      final base=DateTime.now().microsecondsSinceEpoch.remainder(200000000);
      for (var i=0;i<unique.length;i++) {
        final r=unique[i];
        added.add(Reminder(base+i,r.title,r.when,
          location:r.location,
          advanceMinutes:r.advanceMinutes ?? selectedAdvanceMinutes));
      }
      setState(()=>reminders.addAll(added));
      await save();
      final failures=<String>[];
      for (final r in added) {
        try {
          await scheduleReminder(r,requestPermissions:true);
        } catch (_) {failures.add(r.title);}
      }
      final report=added.map((r)=>'• '+r.title+'\n  '+formatted(r.when)+
        (r.location.isEmpty ? '' : '\n  Local: '+r.location)+
        '\n  Aviso: '+advanceLabel(r.advanceMinutes).toLowerCase()+
        (r.advanceMinutes==0 ? '' : ' e no horário')).join('\n\n');
      bot('✅ '+added.length.toString()+' compromisso(s) salvos na Agenda:\n\n'+report+
        (failures.isNotEmpty
          ? '\n\n⚠️ Falha ao programar os alarmes de: '+failures.join(', ')+
            '. Confira as permissões do Android.'
          : '\n\nPara os toques funcionarem, habilite notificações e alarmes precisos no Android.')+
        (online?.reply.isNotEmpty==true ? '\n\n'+online!.reply : ''));
    } catch (_) {
      bot('Não consegui concluir a solicitação. Confira a Agenda antes de tentar novamente.');
    } finally {
      if (mounted) setState(()=>sending=false);
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

  /// Diagnóstico rápido para o cliente, sem URLs e sem expor credenciais.
  Future<void> checkAiStatus() async {
    if (sending) return;
    if (!await authorizeOnlineAI()) return;
    if (!mounted) return;
    setState(() => sending = true);
    final health = await AssistantService.checkConnection();
    final response = health
        ? await AssistantService.ask('Oi, tudo bem? Responda brevemente em português.',
            DateTime.now())
        : null;
    if (!mounted) return;
    setState(() => sending = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(response != null ? 'Inteligência artificial ativa' :
            'Conexão indisponível'),
        content: Text(response != null
            ? 'O LembreAI conversou com o Gemini com sucesso.\n\n'
                '${response.reply.isEmpty ? 'Oi! Estou pronta para ajudar.' : response.reply}'
            : health
                ? 'O servidor respondeu, mas o Gemini não concluiu o teste. '
                  'Tente novamente mais tarde.'
                : 'Não conseguimos acessar o servidor agora. Confira sua internet e tente novamente.'),
        actions: [TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Entendi'))],
      ),
    );
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
                const Center(child: BrandLogo(size: 180)),
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
                  'O Gemini já vem integrado ao aplicativo. '
                  'Na primeira conversa, você poderá autorizar o uso da IA online.'),
                const SizedBox(height: 20),
                FilledButton(onPressed: register, child: const Text('Começar')),
              ],
            ),
          ),
        ),
      ))));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('LembreAI'),
        actions: [
          IconButton(onPressed: checkAiStatus,
            tooltip: 'Testar conversa com IA',
            icon: const Icon(Icons.health_and_safety_outlined)),
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
            if (attachedPhoto!=null) Padding(
              padding: const EdgeInsets.only(bottom:8),
              child: Row(children: [
                ClipRRect(borderRadius:BorderRadius.circular(8),
                  child: Image.memory(attachedPhoto!,height:54,width:54,fit:BoxFit.cover)),
                const SizedBox(width:10),
                Expanded(child:Text(attachedName??'Foto anexada',
                  maxLines:1,overflow:TextOverflow.ellipsis)),
                IconButton(tooltip:'Remover foto',icon:const Icon(Icons.close),
                  onPressed:()=>setState(() {
                    attachedPhoto=null;attachedMime=null;attachedName=null;
                  })),
              ]),
            ),
            Row(children: [
              IconButton(tooltip:'Selecionar foto ou captura de tela',
                icon:const Icon(Icons.add_photo_alternate_outlined),
                onPressed:sending ? null : ()=>addPhoto(ImageSource.gallery)),
              IconButton(tooltip:'Fotografar agenda ou documento',
                icon:const Icon(Icons.photo_camera_outlined),
                onPressed:sending ? null : ()=>addPhoto(ImageSource.camera)),
              Expanded(child: TextField(controller: input,
                onSubmitted: (_) => send(),
                decoration: const InputDecoration(
                  hintText: 'Converse, cole um e-mail ou envie uma foto...',
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
                if (r.location.isNotEmpty) Text('Local: '+r.location),
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

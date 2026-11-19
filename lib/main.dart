import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'reminder_parser.dart';
import 'assistant_service.dart';
import 'alert_preferences.dart';
import 'plan_catalog.dart';
import 'legal_text.dart';
import 'account_screen.dart';
import 'account_service.dart';
import 'test_ad_banner.dart';
import 'rewarded_ad_demo.dart';
import 'app_update_service.dart';

final alarms = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
  } catch (_) {}
  try {
    await alarms.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
  } catch (_) {
    // Falha de inicialização do plugin de notificações não pode impedir
    // a abertura do app; os lembretes continuam acessíveis.
  }
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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late final Future<PackageInfo> appPackageInfo = PackageInfo.fromPlatform();
  final input = TextEditingController();
  final nameInput = TextEditingController();
  final chatScroll = ScrollController();
  bool termsAccepted = false;
  bool termsChecked = false;
  bool consentTestAds = false;
  AppUpdate? availableUpdate;
  bool updateBusy = false;
  double downloadProgress = 0;
  Uint8List? attachedPhoto;
  String? attachedMime;
  String? attachedName;
  final picker = ImagePicker();
  final messages = <(bool, String)>[
    (false, 'Oi! Sou o LembreAI 💜 Organizo sua agenda e seus lembretes. Pode escrever naturalmente, colar um convite ou enviar uma foto com datas e horários.')
  ];
  final reminders = <Reminder>[];
  String name = '';
  bool loaded = false;
  bool sending = false;
  int selectedAdvanceMinutes = defaultAdvanceMinutes;
  int page = 0;
  Timer? presenceTimer;
  bool appIsVisible=true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    recordOnlinePresence();
    presenceTimer=Timer.periodic(const Duration(minutes:1),(_){
      if(appIsVisible)recordOnlinePresence();
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appIsVisible=state==AppLifecycleState.resumed;
    if(appIsVisible)recordOnlinePresence();
  }
  Future<void> recordOnlinePresence() async {
    try {await AccountService.recordActivity();} catch (_) {}
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    presenceTimer?.cancel();
    input.dispose();nameInput.dispose();chatScroll.dispose();super.dispose();
  }
  Future<void> load() async {
    late final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Falha na leitura local não deve deixar a tela presa no carregamento.
      if (!mounted) return;
      setState(() => loaded = true);
      return;
    }
    final raw = prefs.getString('reminders');
    try {
      if (raw != null) {
        reminders.addAll((jsonDecode(raw) as List)
            .map((e) => Reminder.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}
    // Conversas ficam apenas no aparelho; imagens nunca são persistidas no chat.
    try {
      final stored = prefs.getString('chat_history');
      if (stored != null) {
        final items = jsonDecode(stored) as List;
        final restored = <(bool,String)>[];
        for (final item in items.take(120)) {
          if (item is! Map) continue;
          if (item['text'] is! String || item['mine'] is! bool) continue;
          restored.add((item['mine'] as bool, (item['text'] as String).substring(
            0, (item['text'] as String).length.clamp(0, 2500).toInt())));
        }
        if (restored.isNotEmpty) {
          messages..clear()..addAll(restored);
        }
      }
    } catch (_) { /* Histórico corrompido não impede a abertura. */ }
    if (!mounted) return;
    setState(() {
      name = prefs.getString('name') ?? '';
      nameInput.text = name;
      termsAccepted = prefs.getString('terms_accepted_version') == termsVersion;
      consentTestAds = prefs.getBool('show_test_ads') == true;
      loaded = true;
    });
    scrollToLatest();
    // Abre primeiro a agenda e restaura alarmes em segundo plano para evitar
    // que muitos lembretes façam a tela inicial parecer travada.
    unawaited(_restoreReminderAlarms());
    checkUpdates(silent: true);
  }

  Future<void> _restoreReminderAlarms() async {
    for (final reminder in reminders) {
      try {
        if (reminder.done || !reminder.when.isAfter(DateTime.now())) {
          await cancelReminder(reminder);
        } else {
          await scheduleReminder(reminder);
        }
      } catch (_) {
        // Permissões/serviços de notificação não podem bloquear o aplicativo.
      }
    }
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

  void scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !chatScroll.hasClients) return;
      chatScroll.animateTo(
        chatScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> persistMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = messages.length > 120
          ? messages.sublist(messages.length - 120) : messages;
      await prefs.setString('chat_history', jsonEncode([
        for (final msg in entries)
          {'mine': msg.$1, 'text': msg.$2.length > 2500
              ? msg.$2.substring(0, 2500) : msg.$2}
      ]));
    } catch (_) { /* Salvar chat é opcional; lembretes continuam funcionando. */ }
  }

  void bot(String text) {
    if (mounted) {
      setState(() => messages.add((false, text)));
      scrollToLatest();
      persistMessages();
    }
  }

  Future<void> showDocument(String title, String body) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 540, child: SingleChildScrollView(
          child: SelectableText(body))),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(dialogContext),
            child: const Text('Fechar')),
        ],
      ),
    );
  }

  void showPlans() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16,8,16,18),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text('Planos LembreAI',style:TextStyle(
                fontSize:22,fontWeight:FontWeight.bold)),
              const SizedBox(height:8),
              const Text('Você usa o plano gratuito. Os valores abaixo são '
                'propostas; assinaturas e cobranças ainda não estão ativas.'),
              const SizedBox(height:12),
              for (final plan in plans)
                Card(child: ListTile(
                  leading: Icon(plan.available
                    ? Icons.check_circle_outline : Icons.lock_outline),
                  title: Text(plan.name+' — '+plan.monthlyPrice),
                  subtitle: Text(plan.activeLimit.toString()+
                    ' lembretes ativos'+
                    (plan.available?' • disponível':' • em preparação')),
                )),
              const RewardedAdDemo(),
              const SizedBox(height:8),
              const Text('Os avisos não são garantidos em situações de '
                'bateria descarregada, falta de permissão ou restrições do Android.'),
              const SizedBox(height:8),
              TextButton(onPressed:()=>Navigator.pop(sheetContext),
                child:const Text('Voltar')),
            ],
          ),
        ),
      ),
    );
  }

  /// Verifica novas versoes sem interromper o cliente.
  Future<void> checkUpdates({bool silent=false}) async {
    if (!mounted || updateBusy) return;
    setState(() => updateBusy=true);
    try {
      final latest=await AppUpdateService.check();
      if (!mounted) return;
      setState(() => availableUpdate=latest);
      if (!silent && latest == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Você já está com a versão mais recente do LembreAI.')));
      }
    } catch (_) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Não consegui conferir atualizações agora. '
          'Verifique a internet e tente novamente.')));
    } finally {
      if (mounted) setState(() => updateBusy=false);
    }
  }

  Future<void> installAvailableUpdate() async {
    final update=availableUpdate;
    if (update==null || updateBusy) return;
    final approved=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:Text('Atualizar para LembreAI ${update.version}?'),
        content:const Text('O LembreAI vai baixar a atualização diretamente '
          'do GitHub e verificar a integridade do APK. '
          'Depois, o Android pedirá sua confirmação para instalar. '
          '\\n\\nIMPORTANTE: as versões de teste anteriores podem ter '
          'assinaturas diferentes. Se o Android rejeitar a atualização, '
          'não desinstale sem salvar seus lembretes.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Agora não')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Baixar e atualizar')),
        ],
      ),
    ) ?? false;
    if (!approved || !mounted) return;
    setState(() { updateBusy=true; downloadProgress=0; });
    try {
      await AppUpdateService.downloadAndInstall(update,onProgress:(value){
        if(mounted && (value>=1 || value-downloadProgress>=0.025)) {
          setState(()=>downloadProgress=value);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          duration: Duration(seconds: 8),
          content: Text('O instalador do Android foi aberto. Confirme em '
            '“Instalar” para concluir. Se aparecer “App não instalado”, '
            'não desinstale antes de salvar seus lembretes.'),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text(e.toString().replaceFirst('Bad state: ',''))));
    } finally {
      if (mounted) setState(() => updateBusy=false);
    }
  }

  Future<void> showPreferences() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('Privacidade e dados',style:TextStyle(
            fontSize:20,fontWeight:FontWeight.bold)),
          ListTile(leading:const Icon(Icons.description_outlined),
            title:const Text('Termos de uso'),
            onTap:()=>showDocument('Termos de uso',appTerms)),
          ListTile(leading:const Icon(Icons.privacy_tip_outlined),
            title:const Text('Como seus dados são tratados'),
            onTap:()=>showDocument('Privacidade',privacySummary)),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: consentTestAds,
            title: const Text('Mostrar anúncios de teste'),
            subtitle: const Text('Demonstrações do Google, sem pagamento. '
              'Anúncios reais dependem da aprovação da conta AdMob.'),
            onChanged: (value) async {
              final enabled = value == true;
              setState(() => consentTestAds = enabled);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('show_test_ads', enabled);
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
          FutureBuilder<PackageInfo>(
            future: appPackageInfo,
            builder: (context, snapshot) {
              final info = snapshot.data;
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Versão do aplicativo'),
                subtitle: Text(info == null
                  ? 'Consultando…'
                  : '${info.version} (${info.buildNumber})'),
              );
            },
          ),
          ListTile(leading:const Icon(Icons.delete_outline),
            title:const Text('Apagar histórico de conversa'),
            subtitle:const Text('Apaga apenas mensagens deste aparelho.'),
            onTap:() async {
              final ok=await askConfirmation('Limpar conversa?',
                'O histórico salvo no aparelho será apagado. Os lembretes '
                'cadastrados continuarão na Agenda.');
              if (!ok) return;
              final prefs=await SharedPreferences.getInstance();
              await prefs.remove('chat_history');
              if (mounted) setState(() {
                messages..clear()..add((false,'Oi! Sou o LembreAI 💜'));
              });
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            }),
          const SizedBox(height:8),
        ]),
      )));
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
    scrollToLatest();
    persistMessages();
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
        bot('Oi! 💜 Sou sua assistente de agendamentos. Posso ajudar a criar, '
          'consultar, alterar ou cancelar lembretes.');
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
      final slots=freeActiveReminderLimit-reminders.where((r)=>!r.done).length;
      final freeSlots=slots>0 ? slots : 0;
      final creditsNeeded=unique.length>freeSlots ? unique.length-freeSlots : 0;
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
      if (creditsNeeded>0 && !await AccountService.consumeCredits(creditsNeeded)) {
        setState(()=>reminders.removeWhere((r)=>added.any((a)=>a.id==r.id)));
        await save();
        bot('Encontrei '+unique.length.toString()+' compromissos, mas faltam créditos para '
          'ultrapassar o limite de 10 lembretes ativos. Conclua lembretes antigos ou assista '
          'a um anúncio premiado depois que a conta estiver configurada.');
        return;
      }
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
    if (entered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Digite seu nome para continuar.')));
      return;
    }
    if (!termsChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Leia e aceite os Termos de uso.')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', entered);
    await prefs.setString('terms_accepted_version', termsVersion);
    await prefs.setBool('show_test_ads', consentTestAds);
    await prefs.setString('terms_accepted_at',
        DateTime.now().toUtc().toIso8601String());
    if (mounted) setState(() {name = entered; termsAccepted=true;});
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
    if (name.isEmpty || !termsAccepted) {
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
                const SizedBox(height: 16),
                Wrap(spacing:8,children:[
                  TextButton(onPressed:()=>showDocument(
                    'Termos de uso',appTerms),
                    child:const Text('Ler termos')),
                  TextButton(onPressed:()=>showDocument(
                    'Privacidade',privacySummary),
                    child:const Text('Privacidade')),
                ]),
                CheckboxListTile(
                  contentPadding:EdgeInsets.zero,
                  value:termsChecked,
                  title:const Text('Li e aceito os Termos de uso da versão beta.'),
                  subtitle:const Text('O uso da IA online será autorizado '
                    'separadamente, quando necessário.'),
                  onChanged:(v)=>setState(()=>termsChecked=v==true),
                  controlAffinity:ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  contentPadding:EdgeInsets.zero,
                  value:consentTestAds,
                  title:const Text('Ver anúncios de teste na versão beta'),
                  subtitle:const Text('Opcional. São anúncios de demonstração do Google, '
                    'não remunerados e não personalizados.'),
                  onChanged:(v)=>setState(()=>consentTestAds=v==true),
                  controlAffinity:ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: register, child: const Text('Começar')),
              ],
            ),
          ),
        ),
      ))));
    }
    return Scaffold(
      appBar: AppBar(title: FutureBuilder<PackageInfo>(
        future: appPackageInfo,
        builder: (context, snapshot) {
          final info = snapshot.data;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LembreAI'),
              Text(info == null
                ? 'beta'
                : 'v${info.version} • build ${info.buildNumber}',
                style: Theme.of(context).textTheme.labelSmall),
            ],
          );
        },
      ),
        actions: [
          IconButton(onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AccountScreen())),
            tooltip: 'Minha conta',
            icon: const Icon(Icons.person_outline)),
          IconButton(
            onPressed:updateBusy?null:()=>checkUpdates(),
            tooltip:'Verificar atualizações do LembreAI',
            icon:Icon(availableUpdate==null
              ? Icons.system_update_alt
              : Icons.notification_important_outlined),
          ),
          IconButton(onPressed: showPlans,
            tooltip: 'Planos e limites',
            icon: const Icon(Icons.workspace_premium_outlined)),
          IconButton(onPressed: showPreferences,
            tooltip: 'Privacidade e preferências',
            icon: const Icon(Icons.settings_outlined)),
          IconButton(onPressed: checkAiStatus,
            tooltip: 'Testar conversa com IA',
            icon: const Icon(Icons.health_and_safety_outlined)),
          Padding(padding: const EdgeInsets.all(12),
            child: Center(child: Text(name))),
        ]),
      body: page == 0 ? Column(children: [
        if(availableUpdate != null)
          MaterialBanner(
            leading:const Icon(Icons.system_update_alt),
            content:Text('Versão ${availableUpdate!.version} disponível!'),
            actions:[
              TextButton(
                onPressed:updateBusy?null:installAvailableUpdate,
                child:const Text('ATUALIZAR AGORA'),
              ),
              TextButton(
                onPressed:()=>setState(()=>availableUpdate=null),
                child:const Text('Depois'),
              ),
            ],
          ),
        if(updateBusy && downloadProgress>0)
          LinearProgressIndicator(value:downloadProgress),

        Expanded(child: ListView.builder(
          controller:chatScroll,
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
        if(consentTestAds) const TestAdBanner(),
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
                  hintText: 'Agende por texto, e-mail ou foto...',
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

import 'package:flutter/material.dart';

void main() => runApp(const LembreAI());

class LembreAI extends StatelessWidget {
  const LembreAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LembreAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7537E8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final input = TextEditingController();
  final messages = <String>[];
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }
  void send() {
    final text = input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add(text);
      input.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Protótipo: IA e alarmes ainda não ativados.')),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🤖 LembreAI')),
      body: Column(children: [
        Expanded(child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Olá! Sou o LembreAI. Em breve vou organizar seus lembretes.'),
            )),
            for (final message in messages)
              Align(
                alignment: Alignment.centerRight,
                child: Card(child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(message),
                )),
              ),
          ],
        )),
        SafeArea(child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(child: TextField(
              controller: input,
              onSubmitted: (_) => send(),
              decoration: const InputDecoration(
                hintText: 'Digite uma mensagem...',
                border: OutlineInputBorder(),
              ),
            )),
            IconButton(onPressed: send, icon: const Icon(Icons.send)),
          ]),
        )),
      ]),
    );
  }
}  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty) return;
    input.clear();
    setState(() => messages.add({'who':'me','text':text}));
    final parsed = parseReminder(text, DateTime.now());
    if (parsed == null) {
      setState(() => messages.add({'who':'bot','text':
        'Posso criar lembretes! 💜 Experimente: "Me lembra amanhã às 14:30 de pagar o boleto". Você também pode tocar no botão +.'}));
      return;
    }
    if (reminders.where((r) => !r.done).length >= 10) {
      setState(() => messages.add({'who':'bot','text':'Você chegou ao limite gratuito de 10 lembretes ativos. Conclua um lembrete para criar outro.'}));
      return;
    }
    final reminder = Reminder(DateTime.now().microsecondsSinceEpoch.toString(), parsed.title, parsed.when);
    setState(() { reminders.add(reminder); messages.add({'who':'bot','text':
      'Combinado! 🔔 "${reminder.title}" em ${DateFormat('dd/MM/yyyy HH:mm').format(reminder.when)}. Vou tentar avisar 1 dia e 40 minutos antes, e na hora.'}); });
    await _save();
    try { await scheduleReminder(reminder); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confira as permissões de notificação do Android.'))); }
  }


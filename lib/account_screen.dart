import 'package:flutter/material.dart';
import 'account_service.dart';
import 'plan_catalog.dart';
import 'legal_text.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState()=>_AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final email=TextEditingController();
  final password=TextEditingController();
  String? signedIn;
  int? creditBalance;
  bool busy=false;
  bool accepted=false;
  bool create=false;
  @override
  void initState(){super.initState();AccountService.savedEmail().then((value) async {
    final balance=value==null?null:await AccountService.availableCredits();
    if(mounted) setState(() {signedIn=value;creditBalance=balance;});
  });}
  @override
  void dispose(){email.dispose();password.dispose();super.dispose();}

  Future<void> _send({bool google=false}) async {
    if(busy || !accepted) return;
    setState(()=>busy=true);
    try {
      final address=google
        ? await AccountService.signInGoogle()
        : await AccountService.signInEmail(email.text,password.text,create:create);
      final balance=await AccountService.availableCredits();
      if(mounted) setState(() {signedIn=address;creditBalance=balance;});
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(AccountService.explain(e))));
    } finally {if(mounted)setState(()=>busy=false);}
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Minha conta LembreAI')),
    body:SafeArea(child:ListView(
      padding:const EdgeInsets.all(20),
      children:[
        const Icon(Icons.account_circle_outlined,size:60,color:Color(0xffa46bff)),
        const SizedBox(height:10),
        if(signedIn!=null) ...[
          Text('Conectado como $signedIn',textAlign:TextAlign.center),
          const SizedBox(height:8),
          Text(personalBetaUnlimited ? 'Beta gratuita: lembretes ilimitados.' : creditBalance==null
            ? 'Créditos extras: não foi possível consultar agora.'
            : 'Créditos para lembretes extras: $creditBalance',
            textAlign:TextAlign.center),
          const SizedBox(height:16),
          FilledButton.tonal(onPressed:busy?null:() async {
            await AccountService.signOut();
            if(mounted)setState(() {signedIn=null;creditBalance=null;});
          },child:const Text('Sair da conta')),
        ] else if(!AccountService.enabled) ...[
          const Text('O login ainda não está configurado para esta versão. '
            'Por enquanto, os dados ficam somente '
            'neste celular, sem conta online ou sincronização.',
            textAlign:TextAlign.center),
          const SizedBox(height:16),
          const Text('A ativação depende da configuração do Firebase '
            'Authentication e das credenciais de OAuth do Google.'),
        ] else ...[
          Text(create?'Criar conta':'Entrar',style:Theme.of(context)
            .textTheme.headlineSmall,textAlign:TextAlign.center),
          TextField(controller:email,keyboardType:TextInputType.emailAddress,
            autofillHints:const [AutofillHints.email],
            decoration:const InputDecoration(labelText:'E-mail')),
          TextField(controller:password,obscureText:true,
            autofillHints:const [AutofillHints.password],
            decoration:const InputDecoration(labelText:'Senha (mínimo 8 caracteres)')),
          const SizedBox(height:12),
          CheckboxListTile(
            value:accepted,
            onChanged:(value)=>setState(()=>accepted=value==true),
            title:const Text('Li e aceito os Termos de uso beta'),
            controlAffinity:ListTileControlAffinity.leading,
          ),
          TextButton(onPressed:()=>showDialog<void>(
            context:context,
            builder:(ctx)=>AlertDialog(
              title:const Text('Termos e privacidade'),
              content:const SizedBox(width:520,child:SingleChildScrollView(
                child:SelectableText(appTerms+'\\n\\n'+privacySummary))),
              actions:[TextButton(onPressed:()=>Navigator.pop(ctx),
                child:const Text('Fechar'))],
            )),child:const Text('Ler os termos e a privacidade')),
          FilledButton(onPressed:busy||!accepted?null:()=>_send(),
            child:Text(create?'Criar conta':'Entrar com e-mail')),
          TextButton(onPressed:busy?null:()=>setState(()=>create=!create),
            child:Text(create?'Já tenho conta':'Criar conta com e-mail')),
          if(AccountService.googleEnabled)
            OutlinedButton.icon(
              onPressed:busy||!accepted?null:()=>_send(google:true),
              icon:const Icon(Icons.account_circle),
              label:const Text('Continuar com Google'),
            ),
        ],
        const SizedBox(height:16),
        const Text('A conta online não faz backup dos lembretes nesta '
          'versão. Compras e limites pagos não são ativados pelo login.',
          textAlign:TextAlign.center),
      ],
    )),
  );
}

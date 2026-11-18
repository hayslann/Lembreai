import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Demonstra o fluxo com anúncios de teste oficiais.
//// Sem usuário autenticado + assinatura AdMob SSV validada no servidor,
/// assistir ao anúncio NÃO gera crédito resgatável.
class RewardedAdDemo extends StatefulWidget {
  const RewardedAdDemo({super.key});
  @override
  State<RewardedAdDemo> createState()=>_RewardedAdDemoState();
}
class _RewardedAdDemoState extends State<RewardedAdDemo>{
  RewardedAd? ad;
  bool loading=false;
  bool earned=false;
  @override void dispose(){ad?.dispose();super.dispose();}
  Future<void> watch()async{
    if(loading)return;
    setState((){loading=true;earned=false;});
    try {
      await MobileAds.instance.initialize();
      RewardedAd.load(
        adUnitId:'ca-app-pub-3940256099942544/5224354917',
        request:const AdRequest(nonPersonalizedAds:true),
        rewardedAdLoadCallback:RewardedAdLoadCallback(
          onAdLoaded:(loaded){
            if(!mounted){loaded.dispose();return;}
            ad=loaded;
            loaded.fullScreenContentCallback=FullScreenContentCallback<RewardedAd>(
              onAdDismissedFullScreenContent:(a){
                a.dispose();ad=null;
                if(!mounted)return;
                setState(()=>loading=false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:Text(earned
                    ? 'Vídeo de TESTE concluído! Nenhum crédito real foi liberado. '
                      'Créditos dependem de conta e validação no servidor.'
                    : 'Publicidade de teste encerrada sem recompensa.')));
              },
              onAdFailedToShowFullScreenContent:(a,error){
                a.dispose();ad=null;if(mounted)setState(()=>loading=false);
              },
            );
            loaded.show(onUserEarnedReward:(a,reward){
              // NÃO creditar no aparelho; apenas mostrar o teste.
              earned=true;
            });
          },
          onAdFailedToLoad:(error){
            if(!mounted)return;
            setState(()=>loading=false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content:Text('Anúncio de teste indisponível. '
                'Tente novamente mais tarde.')));
          },
        ),
      );
    } catch(_){
      if(mounted)setState(()=>loading=false);
    }
  }
  @override Widget build(BuildContext context)=>Card(
    child:Padding(padding:const EdgeInsets.all(12),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        const Text('🎁 Benefícios por assistir propaganda',
          style:TextStyle(fontWeight:FontWeight.bold)),
        const SizedBox(height:6),
        const Text('Proposta: 1 anúncio verificado = 1 lembrete extra por 24 horas, '
          'com limite de 3 por dia. Beta: somente anúncio de teste, '
          'sem créditos reais.'),
        const SizedBox(height:8),
        FilledButton.tonal(
          onPressed:loading?null:watch,
          child:Text(loading?'Carregando anúncio...':'Assistir anúncio de teste'),
        ),
      ],
    )),
  );
}

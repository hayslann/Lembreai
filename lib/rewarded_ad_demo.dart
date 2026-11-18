import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'account_service.dart';

class RewardedAdDemo extends StatefulWidget {
  const RewardedAdDemo({super.key});
  @override
  State<RewardedAdDemo> createState()=>_RewardedAdDemoState();
}

class _RewardedAdDemoState extends State<RewardedAdDemo>{
  static const testUnitId='ca-app-pub-3940256099942544/5224354917';
  static const adUnitId=String.fromEnvironment('ADMOB_REWARDED_AD_UNIT_ID',
    defaultValue:testUnitId);
  static const testOnly=adUnitId==testUnitId;
  RewardedAd? ad;
  bool loading=false;
  bool earned=false;
  @override void dispose(){ad?.dispose();super.dispose();}

  void message(String text){
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text(text)));
  }

  Future<void> watch()async{
    if(loading)return;
    setState(()=>loading=true);
    earned=false;
    Map<String,dynamic>? session;
    if(!testOnly){
      session=await AccountService.startRewardSession();
      if(session==null){
        if(mounted)setState(()=>loading=false);
        message('Entre na sua conta para assistir e receber o benefício.');
        return;
      }
    }
    try {
      await MobileAds.instance.initialize();
      RewardedAd.load(
        adUnitId:adUnitId,
        request:const AdRequest(nonPersonalizedAds:true),
        rewardedAdLoadCallback:RewardedAdLoadCallback(
          onAdLoaded:(loaded)async{
            if(!mounted){loaded.dispose();return;}
            if(session!=null){
              await loaded.setServerSideOptions(ServerSideVerificationOptions(
                userId:session!['userId'] as String,
                customData:session['customData'] as String,
              ));
            }
            ad=loaded;
            loaded.fullScreenContentCallback=FullScreenContentCallback<RewardedAd>(
              onAdDismissedFullScreenContent:(value)async{
                value.dispose();ad=null;
                if(mounted)setState(()=>loading=false);
                if(!earned){
                  message('Anúncio encerrado sem recompensa.');
                  return;
                }
                if(session==null){
                  message('Anúncio de teste concluído. Nenhum crédito real foi liberado.');
                  return;
                }
                message(await _waitForVerifiedReward(session!));
              },
              onAdFailedToShowFullScreenContent:(value,error){
                value.dispose();ad=null;
                if(mounted)setState(()=>loading=false);
                message('Não foi possível exibir o anúncio. Tente novamente.');
              },
            );
            loaded.show(onUserEarnedReward:(value,reward){
              // O callback do aparelho é apenas visual. Créditos vêm do SSV.
              earned=true;
            });
          },
          onAdFailedToLoad:(error){
            if(mounted)setState(()=>loading=false);
            message('Anúncio indisponível agora. Tente novamente mais tarde.');
          },
        ),
      );
    } catch(_){
      if(mounted)setState(()=>loading=false);
      message('Não foi possível carregar o anúncio.');
    }
  }

  Future<String> _waitForVerifiedReward(String customData)async{
    for(var attempt=0;attempt<6;attempt++){
      if(attempt>0)await Future<void>.delayed(const Duration(seconds:2));
      final status=await AccountService.rewardStatus(customData);
      if(status?['status']=='credited'){
        final credits=status?['availableCredits']??0;
        return 'Benefício confirmado pelo Google! Você tem $credits crédito(s) para lembretes extras.';
      }
    }
    return 'Assistiu ao anúncio. A confirmação do Google ainda está pendente; '
      'os créditos aparecem assim que o servidor validar o retorno.';
  }

  @override Widget build(BuildContext context)=>Card(
    child:Padding(padding:const EdgeInsets.all(12),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        const Text('🎁 Ganhe um lembrete extra',
          style:TextStyle(fontWeight:FontWeight.bold)),
        const SizedBox(height:6),
        Text(testOnly
          ? 'Beta: anúncio oficial de teste. Ele não gera créditos reais.'
          : 'Um anúncio validado pelo Google libera 1 crédito para criar um lembrete '
            'extra. O crédito expira após 24 horas; limite de 3 por dia.'),
        const SizedBox(height:8),
        FilledButton.tonal(
          onPressed:loading?null:watch,
          child:Text(loading?'Carregando anúncio...':
            testOnly?'Assistir anúncio de teste':'Assistir e ganhar crédito'),
        ),
      ],
    )),
  );
}

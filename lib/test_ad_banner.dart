import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Usar apenas IDs oficiais de teste na beta. Não gera receita.
class TestAdBanner extends StatefulWidget {
  const TestAdBanner({super.key});
  @override
  State<TestAdBanner> createState()=>_TestAdBannerState();
}

class _TestAdBannerState extends State<TestAdBanner> {
  BannerAd? ad;
  bool loaded=false;
  @override
  void initState(){
    super.initState();
    final banner=BannerAd(
      size:AdSize.banner,
      adUnitId:'ca-app-pub-3940256099942544/6300978111',
      request:const AdRequest(nonPersonalizedAds:true),
      listener:BannerAdListener(
        onAdLoaded:(value){
          if(!mounted){value.dispose();return;}
          setState(()=>loaded=true);
        },
        onAdFailedToLoad:(value,error){
          value.dispose();
          if(mounted)setState((){ad=null;loaded=false;});
        },
      ),
    );
    ad=banner;
    MobileAds.instance.initialize().then((_) {
      if(mounted && ad == banner) banner.load();
    }).catchError((Object _) {});
  }
  @override
  void dispose(){ad?.dispose();super.dispose();}
  @override
  Widget build(BuildContext context){
    if(!loaded||ad==null)return const SizedBox.shrink();
    return SafeArea(top:false,child:Column(
      mainAxisSize:MainAxisSize.min,
      children:[
        const Text('PUBLICIDADE DE TESTE — SEM RECEITA',
          style:TextStyle(fontSize:9,color:Colors.white54)),
        SizedBox(width:ad!.size.width.toDouble(),height:ad!.size.height.toDouble(),
          child:AdWidget(ad:ad!)),
      ],
    ));
  }
}

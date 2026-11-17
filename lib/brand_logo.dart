import 'package:flutter/material.dart';

/// Marca LembreAI com profundidade e luz roxa, sem trocar o desenho original.
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size=250});

  @override
  Widget build(BuildContext context) => SizedBox(
    height:size,
    width:size,
    child:Stack(fit:StackFit.expand,children:[
      Align(
        alignment:Alignment.center,
        child:Container(
          width:size*0.73,
          height:size*0.72,
          decoration:BoxDecoration(
            shape:BoxShape.circle,
            gradient:const RadialGradient(colors:[
              Color(0x559e40ff),
              Color(0x116721af),
              Colors.transparent,
            ]),
            boxShadow:[
              BoxShadow(color:const Color(0x805610d5),
                blurRadius:size*0.11,offset:Offset(0,size*0.025)),
              BoxShadow(color:const Color(0x444705ac),
                blurRadius:size*0.17,offset:Offset(0,size*0.055)),
            ],
          ),
        ),
      ),
      Image.asset(
        'assets/branding/lembreai_logo.png',
        width:size,
        height:size,
        fit:BoxFit.contain,
        filterQuality:FilterQuality.high,
        semanticLabel:'LembreAI: sino e balão de conversa roxo',
      ),
    ]),
  );
}

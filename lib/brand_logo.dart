import 'package:flutter/material.dart';

/// Marca exibida somente na abertura e nas boas-vindas.
/// O ícone instalado anteriormente não é alterado.
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size=250});

  @override
  Widget build(BuildContext context) => SizedBox(
    height:size,width:size,
    child:CustomPaint(painter:_BrandPainter()),
  );
}

class _BrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas,Size size) {
    canvas.save();
    canvas.scale(size.width/300,size.height/300);
    final bubble=Path()
      ..addOval(Rect.fromLTWH(38,18,224,203))
      ..moveTo(69,185)
      ..quadraticBezierTo(55,220,54,242)
      ..quadraticBezierTo(49,253,63,248)
      ..lineTo(108,213)
      ..close();
    final purple=Paint()..shader=const LinearGradient(
      begin:Alignment.topRight,end:Alignment.bottomLeft,
      colors:[Color(0xffbd22ff),Color(0xff7700f4),Color(0xff3b087c)],
    ).createShader(const Rect.fromLTWH(25,18,240,240));
    canvas.drawPath(bubble,purple);
    final bell=Path()
      ..moveTo(105,155)
      ..quadraticBezierTo(113,111,133,86)
      ..quadraticBezierTo(151,60,174,76)
      ..quadraticBezierTo(200,87,206,156)
      ..quadraticBezierTo(209,172,216,184)
      ..quadraticBezierTo(218,195,201,193)
      ..lineTo(104,192)
      ..quadraticBezierTo(87,193,95,178)
      ..close();
    canvas.drawPath(bell,Paint()..color=Colors.white);
    canvas.drawOval(const Rect.fromLTWH(144,62,34,33),Paint()..color=Colors.white);
    canvas.drawArc(const Rect.fromLTWH(139,184,41,23),0,3.14,false,
      Paint()..color=Colors.white);
    for(final x in [138.0,170.0]){
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x,126,10,23),const Radius.circular(8)),
        Paint()..color=const Color(0xff3d087f));
    }
    final orbit=Path()
      ..moveTo(91,178)
      ..cubicTo(35,204,86,223,159,207)
      ..cubicTo(235,190,267,150,227,141)
      ..cubicTo(257,158,222,193,153,204)
      ..cubicTo(92,218,64,199,91,178);
    canvas.drawPath(orbit,Paint()..color=const Color(0xffd78af9));
    final star=Path()
      ..moveTo(225,65)
      ..quadraticBezierTo(232,89,247,94)
      ..quadraticBezierTo(233,98,225,117)
      ..quadraticBezierTo(221,96,207,94)
      ..quadraticBezierTo(221,87,225,65)
      ..close();
    canvas.drawPath(star,Paint()..color=Colors.white);
    final leftMarks=Paint()..color=Colors.white..strokeWidth=10..strokeCap=StrokeCap.round;
    canvas.drawLine(const Offset(83,106),const Offset(94,114),leftMarks);
    canvas.drawLine(const Offset(78,139),const Offset(93,142),leftMarks);
    canvas.drawLine(const Offset(111,80),const Offset(118,93),leftMarks);

    final painter=TextPainter(
      text:const TextSpan(text:'LembreAI',style:TextStyle(
        fontSize:48,fontWeight:FontWeight.w900,letterSpacing:-2.6,
        color:Color(0xff8c31ec))),
      textDirection:TextDirection.ltr,
    )..layout();
    painter.paint(canvas,Offset((300-painter.width)/2,242));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

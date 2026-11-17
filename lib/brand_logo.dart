import 'package:flutter/material.dart';

/// A imagem original escolhida para representar a marca LembreAI.
/// Não altera o desenho, as cores ou a tipografia do logo.
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size=250});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.12),
    child: Image.asset(
      'assets/branding/lembreai_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'LembreAI: sino e balão de conversa roxo',
    ),
  );
}

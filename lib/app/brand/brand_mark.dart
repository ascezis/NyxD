import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 112});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'LOGO_BRAND/brand-mark-metallic-1024.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      semanticLabel: 'NyxD',
    );
  }
}

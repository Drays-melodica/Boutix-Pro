import 'package:flutter/material.dart';

import '../theme/boutix_brand.dart';
import '../theme/dos_theme.dart';

/// Logo BOUTIX intégré (écrans, tickets si aucun logo personnalisé).
class BoutixLogo extends StatelessWidget {
  const BoutixLogo({
    super.key,
    this.height = 72,
    this.width,
    this.alignment = Alignment.center,
  });

  final double height;
  final double? width;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Image.asset(
        BoutixBrand.logoAsset,
        height: height,
        width: width,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => Text(
          BoutixBrand.name,
          style: DosTheme.title(size: height * 0.35),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Palette BIOS/DOS — fond bleu nuit, texte blanc.
class DosColors {
  DosColors._();

  static const Color background = Color(0xFF000033);
  static const Color backgroundAlt = Color(0xFF000066);
  static const Color border = Color(0xFFFFFFFF);
  static const Color text = Color(0xFFFFFFFF);
  static const Color textDim = Color(0xFFCCCCCC);
  static const Color highlight = Color(0xFF0000AA);
  static const Color highlightText = Color(0xFFFFFFFF);
  static const Color statusBar = Color(0xFF000055);
  static const Color error = Color(0xFFFF6666);
  static const Color success = Color(0xFF66FF66);
  static const Color warning = Color(0xFFFFFF66);
}

class DosTheme {
  static const String fontFamily = 'Courier New';

  static TextStyle text({double size = 16, Color? color, FontWeight? weight}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      color: color ?? DosColors.text,
      fontWeight: weight,
      height: 1.2,
    );
  }

  static TextStyle title({double size = 20}) =>
      text(size: size, weight: FontWeight.bold);

  static TextStyle dim({double size = 14}) =>
      text(size: size, color: DosColors.textDim);
}

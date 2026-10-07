import 'package:flutter/material.dart';

import '../theme/dos_theme.dart';

class DosStatusBar extends StatelessWidget {
  const DosStatusBar({super.key, required this.helpLines});

  final List<String> helpLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: DosColors.statusBar,
        border: Border(
          top: BorderSide(color: DosColors.border, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '╚════════════════════════════════════════════════════════════════════════╝',
            style: DosTheme.dim(size: 11),
          ),
          ...helpLines.map(
            (line) => Text(line, style: DosTheme.dim(size: 13)),
          ),
        ],
      ),
    );
  }
}

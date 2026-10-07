import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/boot_screen.dart';
import 'theme/dos_theme.dart';

class BoutixApp extends StatelessWidget {
  const BoutixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOUTIX PRO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: DosColors.background,
        fontFamily: DosTheme.fontFamily,
        colorScheme: const ColorScheme.dark(
          primary: DosColors.text,
          surface: DosColors.background,
        ),
      ),
      home: const BootScreen(),
      builder: (context, child) {
        return Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyQ):
                const ActivateIntent(),
          },
          child: Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) => null,
              ),
            },
            child: child ?? const SizedBox(),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boutix/widgets/dos_table.dart';

/// Reproduces the freeze: parent rebuilds a new rows List each time, and
/// onSelectionChanged used to call setState even when the index was unchanged.
class _LoopHost extends StatefulWidget {
  const _LoopHost();

  @override
  State<_LoopHost> createState() => _LoopHostState();
}

class _LoopHostState extends State<_LoopHost> {
  int selected = 0;
  int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 400,
          child: DosTable(
            headers: const ['NOM'],
            rows: [
              ['Article A'],
              ['Article B'],
            ],
            onSelectionChanged: (i) => setState(() => selected = i),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('DosTable does not freeze when parent rebuilds rows',
      (tester) async {
    await tester.pumpWidget(const _LoopHost());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final host = tester.state<_LoopHostState>(find.byType(_LoopHost));
    expect(host.builds, lessThan(10),
        reason: 'Infinite rebuild loop would freeze Articles / Catalogue');
    expect(find.text('Article A'), findsOneWidget);
  });
}

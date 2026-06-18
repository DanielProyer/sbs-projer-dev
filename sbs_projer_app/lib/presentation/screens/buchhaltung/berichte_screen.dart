// lib/presentation/screens/buchhaltung/berichte_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/bericht_datum_picker.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/bilanz_view.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/erfolgsrechnung_view.dart';

class BerichteScreen extends ConsumerStatefulWidget {
  const BerichteScreen({super.key});
  @override
  ConsumerState<BerichteScreen> createState() => _BerichteScreenState();
}

class _BerichteScreenState extends ConsumerState<BerichteScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  DateTime _stichtag = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  Zeitraum _zeitraum = (von: DateTime(DateTime.now().year, 1, 1), bis: DateTime(DateTime.now().year, 12, 31));

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilanz & Erfolgsrechnung'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Bilanz'), Tab(text: 'Erfolgsrechnung')],
        ),
      ),
      body: Column(
        children: [
          AnimatedBuilder(
            animation: _tab,
            builder: (context, _) => _tab.index == 0
                ? StichtagPicker(
                    stichtag: _stichtag,
                    onChanged: (d) => setState(() => _stichtag = d),
                  )
                : ZeitraumPicker(
                    zeitraum: _zeitraum,
                    onChanged: (z) => setState(() => _zeitraum = z),
                  ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                BilanzView(stichtag: _stichtag),
                ErfolgsrechnungView(zeitraum: _zeitraum),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

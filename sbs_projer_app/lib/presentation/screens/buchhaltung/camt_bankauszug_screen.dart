import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt/camt_import_tab.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt/camt_pruefliste_tab.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt/camt_regeln_tab.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt/camt_dateien_tab.dart';

/// Vereint Bankauszug-Import, Prüfliste, Regeln und Dateien in einem Screen
/// mit vier Tabs. Der „Neue Regel"-FAB erscheint nur im Regeln-Tab.
class CamtBankauszugScreen extends ConsumerStatefulWidget {
  /// Start-Tab: 0=Import, 1=Prüfliste, 2=Regeln, 3=Dateien.
  final int initialTab;
  const CamtBankauszugScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<CamtBankauszugScreen> createState() =>
      _CamtBankauszugScreenState();
}

class _CamtBankauszugScreenState extends ConsumerState<CamtBankauszugScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final istRegelnTab = _tab.index == 2;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bankauszug Import'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.upload_file), text: 'Import'),
            Tab(icon: Icon(Icons.fact_check), text: 'Prüfliste'),
            Tab(icon: Icon(Icons.rule), text: 'Regeln'),
            Tab(icon: Icon(Icons.folder_open), text: 'Dateien'),
          ],
        ),
      ),
      floatingActionButton: istRegelnTab
          ? FloatingActionButton(
              onPressed: () => showRegelDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: TabBarView(
        controller: _tab,
        children: [
          CamtImportTab(onZurPruefliste: () => _tab.animateTo(1)),
          const CamtPrueflisteTab(),
          const CamtRegelnTab(),
          const CamtDateienTab(),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/presentation/providers/dokument_providers.dart';
import 'package:sbs_projer_app/presentation/providers/steuern_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/dokumente/dokument_liste.dart';
import 'package:sbs_projer_app/presentation/widgets/dokumente/dokument_upload_dialog.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

/// Ablage aller Geschäftsdokumente, gefiltert nach Bereich und Jahr.
class DokumenteScreen extends ConsumerStatefulWidget {
  const DokumenteScreen({super.key});

  @override
  ConsumerState<DokumenteScreen> createState() => _DokumenteScreenState();
}

class _DokumenteScreenState extends ConsumerState<DokumenteScreen> {
  String? _bereich = 'steuern';
  int? _jahr;

  void _reload() {
    if (!mounted) return;
    ref.invalidate(dokumenteProvider);
    ref.invalidate(dokumentJahreProvider);
  }

  Future<void> _loeschen(Dokument d) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DokumentRepository.delete(d);
      if (!mounted) return;
      invalidateSteuern(ref);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(dokumenteProvider((bereich: _bereich, jahr: _jahr)));
    final jahre = ref.watch(dokumentJahreProvider(_bereich)).value ?? const [];
    // Das gewählte Jahr muss als Option bestehen bleiben, auch wenn das
    // letzte Dokument dieses Jahres gerade gelöscht wurde — sonst zeigt der
    // DropdownButton auf einen Wert, den es nicht mehr gibt (Assertion).
    final jahrOptionen = <int>{if (_jahr != null) _jahr!, ...jahre}.toList()
      ..sort((a, b) => b.compareTo(a));
    return Scaffold(
      appBar: AppBar(title: const Text('Dokumente')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: AppFilterDropdown<String>(
                    hint: 'Alle Bereiche',
                    isExpanded: true,
                    value: _bereich,
                    options: [
                      for (final e in dokumentBereiche.entries)
                        (e.key, e.value),
                    ],
                    // Jahr zurücksetzen: der bisherige Wert kommt im neuen
                    // Bereich womöglich gar nicht vor.
                    onChanged: (v) => setState(() {
                      _bereich = v;
                      _jahr = null;
                    }),
                  ).build(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppFilterDropdown<int>(
                    hint: 'Alle Jahre',
                    isExpanded: true,
                    value: _jahr,
                    options: [for (final j in jahrOptionen) (j, '$j')],
                    onChanged: (v) => setState(() => _jahr = v),
                  ).build(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: docs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Fehler: $e', textAlign: TextAlign.center),
                    ),
                    TapKnopf(
                      text: 'Erneut laden',
                      primaer: false,
                      onTap: _reload,
                    ),
                  ],
                ),
              ),
              data: (list) => ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  DokumentListe(dokumente: list, onLoeschen: _loeschen),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TapKnopf(
                text: 'Dokument hochladen',
                icon: Icons.upload_file,
                onTap: () async {
                  final d = await showDokumentUploadDialog(
                    context,
                    bereich: _bereich ?? 'sonstiges',
                    bereichFix: false,
                    jahr: _jahr,
                  );
                  if (d == null) return;
                  if (!mounted) return;
                  // Filter auf das frisch hochgeladene Dokument ausrichten,
                  // sonst landet es unsichtbar hinter dem alten Filter.
                  setState(() {
                    _bereich = d.bereich;
                    if (_jahr != null && d.jahr != _jahr) _jahr = null;
                  });
                  invalidateSteuern(ref);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

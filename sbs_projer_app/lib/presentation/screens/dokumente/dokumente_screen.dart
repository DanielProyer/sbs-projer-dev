import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/presentation/providers/dokument_providers.dart';
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
    ref.invalidate(dokumenteProvider);
    ref.invalidate(dokumentJahreProvider);
  }

  Future<void> _loeschen(Dokument d) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DokumentRepository.delete(d);
      _reload();
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
                    options: [for (final j in jahre) (j, '$j')],
                    onChanged: (v) => setState(() => _jahr = v),
                  ).build(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: docs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (list) => ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  DokumentListe(dokumente: list, onLoeschen: _loeschen),
                ],
              ),
            ),
          ),
          Padding(
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
                if (d != null) _reload();
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/services/pdf/pdf_tab_oeffner_export.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

/// Dokumentliste, nach Typ gruppiert. Zeilen aus InkWell + Container statt
/// ListTile/ExpansionTile (CanvasKit-Regel, CLAUDE.md).
class DokumentListe extends StatelessWidget {
  final List<Dokument> dokumente;
  final void Function(Dokument)? onLoeschen;

  const DokumentListe({super.key, required this.dokumente, this.onLoeschen});

  static final _df = DateFormat('dd.MM.yyyy');
  static final _chf = NumberFormat('#,##0.00', 'de_CH');

  @override
  Widget build(BuildContext context) {
    if (dokumente.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Keine Dokumente.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final gruppen = <String, List<Dokument>>{};
    for (final d in dokumente) {
      gruppen.putIfAbsent(d.typ, () => []).add(d);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in gruppen.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
            child: Text(
              '${dokumentTypLabel(g.key)} (${g.value.length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final d in g.value) _zeile(context, d),
        ],
      ],
    );
  }

  Widget _zeile(BuildContext context, Dokument d) => InkWell(
    onTap: () => oeffnen(context, d),
    onLongPress: onLoeschen == null ? null : () => _loeschenFragen(context, d),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Icon(
            d.istPdf ? Icons.picture_as_pdf : Icons.image,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.titel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    if (d.dokumentDatum != null) _df.format(d.dokumentDatum!),
                    if (d.kategorie != null)
                      steuerarten[d.kategorie] ?? d.kategorie!,
                    if (d.referenz != null) d.referenz!,
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (d.betrag != null)
            Text(
              '${_chf.format(d.betrag)} CHF',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: d.betrag! < 0 ? AppColors.info : AppColors.textPrimary,
              ),
            ),
          if (d.buchungId != null)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.link, size: 16),
            ),
        ],
      ),
    ),
  );

  /// PDF im neuen Browser-Tab, Bild im Dialog.
  static Future<void> oeffnen(BuildContext context, Dokument d) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (d.istPdf) {
        final bytes = await DokumentRepository.download(d.storagePfad);
        await oeffnePdfImNeuenTab(bytes, d.dateiname);
      } else {
        final url = await DokumentRepository.signedUrl(d.storagePfad);
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) =>
              Dialog(child: InteractiveViewer(child: Image.network(url))),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Öffnen fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _loeschenFragen(BuildContext context, Dokument d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dokument löschen?'),
        content: Text(d.titel),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true) onLoeschen!(d);
  }
}

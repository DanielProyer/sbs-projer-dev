import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/war_geschlossen.dart';
import 'package:sbs_projer_app/data/local/betrieb_ferien_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_ferien_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/gefahr_rueckfrage.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

// Pflege und Anzeige der Betriebsferien aus der Tabelle `betrieb_ferien`.
//
// WARUM (Analyse R7, 25.09.2026): Das Betriebsformular schrieb bis v0.140.0
// die fünf alten Spaltenpaare `ferien*_start/ende`, Tourenplan und
// Vorjahreshinweis lesen aber seit Migration 160 nur die Tabelle. Detail und
// Heineken-Raster lasen faktisch die Altspalten — drei Perioden fehlten in der
// Planung. Seit v0.141.0 ist die Tabelle die einzige gepflegte Quelle; dieses
// Widget ist der einzige Ort, an dem man sie von Hand pflegt (neben
// «War geschlossen» aus dem Reinigungsweg).
//
// Das Widget speichert SOFORT in die Tabelle — es gehört deshalb nicht zum
// Ungespeichert-Schutz des Formulars.

/// Anzeigename einer Ferien-Quelle.
String quelleLabel(String quelle) => switch (quelle) {
  'kunde' => 'Kunde',
  'vor_ort' => 'vor Ort',
  'website' => 'Website',
  'google' => 'Google',
  'import' => 'Altbestand',
  _ => quelle,
};

String _zwei(int n) => n.toString().padLeft(2, '0');
String _kurz(DateTime d) => '${_zwei(d.day)}.${_zwei(d.month)}.';
String _lang(DateTime d) => '${_kurz(d)}${d.year}';

/// «11.10. – 04.11.2026» im selben Jahr, sonst beide Daten mit Jahr.
String periodeText(DateTime von, DateTime bis) => von.year == bis.year
    ? '${_kurz(von)} – ${_lang(bis)}'
    : '${_lang(von)} – ${_lang(bis)}';

/// Sortiert beliebige Einträge nach Ferienlogik: künftige und laufende
/// (bis ≥ heute) zuerst, aufsteigend nach Beginn — vergangene danach,
/// die jüngste zuerst.
List<T> periodenSortiertNach<T>(
  List<T> liste, {
  required DateTime heute,
  required DateTime Function(T) von,
  required DateTime Function(T) bis,
}) {
  final tag = DateTime(heute.year, heute.month, heute.day);
  final kommend = <T>[];
  final vorbei = <T>[];
  for (final e in liste) {
    (bis(e).isBefore(tag) ? vorbei : kommend).add(e);
  }
  kommend.sort((a, b) => von(a).compareTo(von(b)));
  vorbei.sort((a, b) => von(b).compareTo(von(a)));
  return [...kommend, ...vorbei];
}

/// [periodenSortiertNach] für einfache Von/Bis-Records.
List<({DateTime von, DateTime bis})> periodenSortiert(
  List<({DateTime von, DateTime bis})> liste, {
  required DateTime heute,
}) => periodenSortiertNach(
  liste,
  heute: heute,
  von: (e) => e.von,
  bis: (e) => e.bis,
);

/// Liste der Ferien-Perioden eines Betriebs mit «+ Ferien» und Löschen.
class BetriebFerienListe extends ConsumerStatefulWidget {
  /// Server-UUID des Betriebs (`betriebe.id`).
  final String betriebId;
  final bool bearbeitbar;

  const BetriebFerienListe({
    super.key,
    required this.betriebId,
    this.bearbeitbar = true,
  });

  @override
  ConsumerState<BetriebFerienListe> createState() =>
      _BetriebFerienListeState();
}

class _BetriebFerienListeState extends ConsumerState<BetriebFerienListe> {
  List<BetriebFerienLocal>? _ferien;
  Object? _fehler;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  @override
  void didUpdateWidget(BetriebFerienListe old) {
    super.didUpdateWidget(old);
    if (old.betriebId != widget.betriebId) _laden();
  }

  Future<void> _laden() async {
    try {
      final liste = await BetriebFerienRepository.getFuerBetrieb(
        widget.betriebId,
      );
      if (!mounted) return;
      setState(() {
        _ferien = periodenSortiertNach<BetriebFerienLocal>(
          liste,
          heute: DateTime.now(),
          von: (f) => f.von,
          bis: (f) => f.bis,
        );
        _fehler = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _fehler = e);
    }
  }

  void _nachAenderung() {
    ref.invalidate(ferienPeriodenProvider);
    ref.invalidate(betriebeStreamProvider);
    _laden();
  }

  Future<void> _neu() async {
    final ergebnis = await showDialog<({DateTime von, DateTime bis})>(
      context: context,
      builder: (_) => const _FerienDialog(),
    );
    if (ergebnis == null || !mounted) return;
    try {
      await BetriebFerienRepository.periodeErfassen(
        betriebId: widget.betriebId,
        von: ergebnis.von,
        bis: ergebnis.bis,
        quelle: 'kunde',
      );
      _nachAenderung();
    } catch (e) {
      _meldeFehler('Ferien nicht gespeichert: $e');
    }
  }

  Future<void> _loeschen(BetriebFerienLocal f) async {
    final text = periodeText(f.von, f.bis);
    final ok = await gefahrRueckfrage(
      context,
      titel: 'Ferien löschen?',
      text:
          '$text wird entfernt. Der Tourenplan zeigt den Betrieb dann wieder '
          'als offen.',
      bestaetigen: 'Löschen',
    );
    if (!ok || !mounted) return;
    try {
      await BetriebFerienRepository.loeschen(
        kIsWeb ? f.serverId! : f.id.toString(),
      );
      _nachAenderung();
    } catch (e) {
      _meldeFehler('Ferien nicht gelöscht: $e');
    }
  }

  void _meldeFehler(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final ferien = _ferien;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_fehler != null)
          Text(
            'Ferien konnten nicht geladen werden: $_fehler',
            style: const TextStyle(color: AppColors.error),
          )
        else if (ferien == null)
          const LinearProgressIndicator()
        else if (ferien.isEmpty)
          const Text(
            'Keine Ferien erfasst',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          for (final f in ferien) _zeile(f),
        if (widget.bearbeitbar) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TapKnopf(text: '+ Ferien', primaer: false, onTap: _neu),
          ),
        ],
      ],
    );
  }

  Widget _zeile(BetriebFerienLocal f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  periodeText(f.von, f.bis),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  quelleLabel(f.quelle),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (widget.bearbeitbar)
            InkWell(
              onTap: () => _loeschen(f),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.delete_outline, color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// Von/Bis-Auswahl für eine neue Ferienperiode.
class _FerienDialog extends StatefulWidget {
  const _FerienDialog();

  @override
  State<_FerienDialog> createState() => _FerienDialogState();
}

class _FerienDialogState extends State<_FerienDialog> {
  late DateTime _von;
  late DateTime _bis;

  @override
  void initState() {
    super.initState();
    final f = standardFerienfenster();
    _von = f.von;
    _bis = f.bis;
  }

  Future<DateTime?> _waehle(DateTime initial) {
    final jetzt = DateTime.now();
    final heute = DateTime(jetzt.year, jetzt.month, jetzt.day);
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2019),
      lastDate: heute.add(const Duration(days: 730)),
    );
  }

  Widget _feld(String label, DateTime wert, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(_lang(wert)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gueltig = !_bis.isBefore(_von);
    return AlertDialog(
      title: const Text('Betriebsferien'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _feld('Von', _von, () async {
            final d = await _waehle(_von);
            if (d == null || !mounted) return;
            setState(() {
              _von = d;
              if (_bis.isBefore(_von)) _bis = _von;
            });
          }),
          const SizedBox(height: 12),
          _feld('Bis', _bis, () async {
            final d = await _waehle(_bis);
            if (d == null || !mounted) return;
            setState(() => _bis = d);
          }),
        ],
      ),
      actions: [
        TapKnopf(
          text: 'Abbrechen',
          primaer: false,
          onTap: () => Navigator.pop(context),
        ),
        TapKnopf(
          text: 'Speichern',
          onTap: gueltig
              ? () => Navigator.pop(context, (von: _von, bis: _bis))
              : null,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/saison_historie.dart';
import 'package:sbs_projer_app/core/util/saison_luecke.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_saison_historie_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/datum_auswahl.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

final _ddMMyyyy = DateFormat('dd.MM.yyyy');

/// Saisondaten der gemeldeten Betriebe nachtragen — einer nach dem anderen.
///
/// **Warum (Daniel, 20.09.2026):** Beide Saison-Warnungen im Tourenplan
/// nannten nur Namen. Danach musste er jeden Betrieb einzeln suchen, das
/// Formular öffnen, zwei Daten setzen, speichern, zurück — 26-mal. Hier steht
/// alles auf einer Karte, mit dem Grund daneben.
///
/// **Der Vorschlag** schiebt vorhandene Daten aufs nächste Jahr vor
/// ([saisonVorschlag]). Für ein Fenster ohne Startdatum gibt es keinen — dort
/// weiss nur der Betrieb, wann er aufmacht. Als Anhalt stehen die publizierten
/// Bahn-Saisonstarts im Kopf der Liste.
class SaisonNachtragScreen extends ConsumerStatefulWidget {
  const SaisonNachtragScreen({super.key});

  @override
  ConsumerState<SaisonNachtragScreen> createState() =>
      _SaisonNachtragScreenState();
}

class _SaisonNachtragScreenState extends ConsumerState<SaisonNachtragScreen> {
  int _index = 0;
  int _erledigt = 0;
  bool _speichert = false;
  String? _zuletztGespeichert;

  // Felder des aktuellen Betriebs
  bool _winterAktiv = false;
  DateTime? _winterStart;
  DateTime? _winterEnde;
  bool _sommerAktiv = false;
  DateTime? _sommerStart;
  DateTime? _sommerEnde;
  bool _keineHerbstpause = false;
  String? _geladenFuer;

  void _felderLaden(BetriebLocal b) {
    _geladenFuer = b.routeId;
    _winterAktiv = b.winterSaisonAktiv;
    _winterStart = b.winterStartDatum;
    _winterEnde = b.winterEndeDatum;
    _sommerAktiv = b.sommerSaisonAktiv;
    _sommerStart = b.sommerStartDatum;
    _sommerEnde = b.sommerEndeDatum;
    _keineHerbstpause = b.keineHerbstpause;
  }

  @override
  Widget build(BuildContext context) {
    final liste = ref.watch(saisonNachtragProvider);
    // Nach dem Speichern verschwindet der Betrieb aus der Liste; der Index
    // zeigt dann schon auf den nächsten.
    if (_index >= liste.length) return _fertigScaffold(liste.isEmpty);
    final k = liste[_index];
    if (_geladenFuer != k.betrieb.routeId) _felderLaden(k.betrieb);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saisondaten nachtragen'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Betrieb ${_index + 1} von ${liste.length}'
              '${_erledigt == 0 ? '' : ' · $_erledigt nachgetragen'}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_zuletztGespeichert != null) _gespeichertBand(),
          _kopf(k),
          const SizedBox(height: 12),
          _bahnHinweis(),
          const SizedBox(height: 12),
          _saisonBlock(
            titel: 'Wintersaison',
            aktiv: _winterAktiv,
            start: _winterStart,
            ende: _winterEnde,
            onAktiv: (v) => setState(() => _winterAktiv = v),
            onStart: (d) => setState(() => _winterStart = d),
            onEnde: (d) => setState(() => _winterEnde = d),
          ),
          if (_winterAktiv && _sommerAktiv) ...[
            const SizedBox(height: 12),
            _herbstSchalter(),
          ],
          const SizedBox(height: 12),
          _saisonBlock(
            titel: 'Sommersaison',
            aktiv: _sommerAktiv,
            start: _sommerStart,
            ende: _sommerEnde,
            onAktiv: (v) => setState(() => _sommerAktiv = v),
            onStart: (d) => setState(() => _sommerStart = d),
            onEnde: (d) => setState(() => _sommerEnde = d),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TapKnopf(
                  text: 'Speichern und weiter',
                  icon: Icons.check,
                  laeuft: _speichert,
                  onTap: _speichern,
                ),
              ),
              const SizedBox(width: 8),
              TapKnopf(
                text: 'Überspringen',
                primaer: false,
                onTap: _speichert ? null : _weiter,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Überspringen ändert nichts — der Betrieb bleibt in der Warnung.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// «Keine Herbstpause» — der Sommerbetrieb geht direkt in den Winter über
  /// (Alpenblick und Hörnlihütte Arosa, Daniel 20.09.2026). Nur sichtbar,
  /// wenn beide Saisons angehakt sind; sonst gibt es keinen Übergang.
  Widget _herbstSchalter() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.divider),
    ),
    child: SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text(
        'Keine Herbstpause',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        _keineHerbstpause
            ? 'Vom Sommerende bis zum Winterstart durchgehend offen. '
                  'Die Frühlingspause bleibt.'
            : 'Zwischen Sommerende und Winterstart gilt der Betrieb als '
                  'geschlossen.',
        style: const TextStyle(fontSize: 12),
      ),
      value: _keineHerbstpause,
      onChanged: (v) => setState(() => _keineHerbstpause = v),
    ),
  );

  Widget _gespeichertBand() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border.all(color: AppColors.success),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_zuletztGespeichert gespeichert.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _kopf(SaisonNachtragKandidat k) {
    final b = k.betrieb;
    final ort = b.ort;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ort == null || ort.isEmpty ? b.name : '${b.name}, $ort',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          for (final g in k.gruende)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 14,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(switch (g) {
                      SaisonNachtragGrund.luecke => saisonLuecken(
                        b,
                      ).map((l) => l.erklaerung).join(' '),
                      SaisonNachtragGrund.ankerFehlt =>
                        'Endreinigung erledigt, aber kein künftiger '
                            'Saisonstart — die Fälligkeits-Uhr kann nicht '
                            'starten.',
                    }, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Publizierte Bahn-Saisonstarts als Anhalt. Bewusst als Text und nicht als
  /// Vorbelegung: Die Bahn sagt, wann der Berg aufmacht — ein Restaurant im
  /// Dorf richtet sich nicht zwingend danach.
  Widget _bahnHinweis() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FA),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.divider),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bahnen Winter 2026/27 (Stand 20.09.2026)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 4),
        Text(
          'Davos Parsenn ab 20.11.2026 (Wochenenden ab 13.11.), bis '
          '04.04.2027 · Klosters Parsenn ab 04.12.2026 · Arosa Lenzerheide '
          'Vorsaison ab 28.11.2026, Hauptsaison ab 19.12.2026, Bahnbetrieb '
          'bis 11.04.2027 · Laax noch nicht angesagt (Vorjahr 29.11.).',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _saisonBlock({
    required String titel,
    required bool aktiv,
    required DateTime? start,
    required DateTime? ende,
    required ValueChanged<bool> onAktiv,
    required ValueChanged<DateTime?> onStart,
    required ValueChanged<DateTime?> onEnde,
  }) {
    final heute = DateTime.now();
    final vStart = saisonVorschlag(start, heute);
    final vEnde = saisonVorschlag(ende, heute);
    // Nur anbieten, wenn es einen START zu verschieben gibt. Ein Fenster ohne
    // Start bliebe sonst auch nach dem Klick lückenhaft — der Knopf verspräche
    // eine Lösung, die er nicht liefert.
    final hatVorschlag = vStart != null && vStart != start;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: false,
            title: Text(
              titel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            value: aktiv,
            onChanged: onAktiv,
          ),
          if (aktiv) ...[
            _DatumFeld(label: 'Start', value: start, onChanged: onStart),
            const SizedBox(height: 8),
            _DatumFeld(label: 'Ende', value: ende, onChanged: onEnde),
            // Nur wenn ein Ende ohne Start dasteht. Sind beide leer, heisst
            // das «unbefristet offen» — der Betrieb bleibt sichtbar, es gibt
            // nichts zu warnen.
            if (start == null && ende != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Ohne Start gilt das Fenster nur «bis zum Ende» — danach '
                  'verschwindet der Betrieb dauerhaft aus dem Tourenplan.',
                  style: TextStyle(fontSize: 11, color: AppColors.error),
                ),
              ),
            if (hatVorschlag) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TapKnopf(
                  text:
                      'Ein Jahr weiter: ${_ddMMyyyy.format(vStart)}'
                      '${vEnde == null ? '' : ' – ${_ddMMyyyy.format(vEnde)}'}',
                  primaer: false,
                  icon: Icons.update,
                  onTap: () {
                    // vStart ist hier nie null — `hatVorschlag` hängt daran.
                    onStart(vStart);
                    if (vEnde != null) onEnde(vEnde);
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _weiter() {
    setState(() {
      _index++;
      _geladenFuer = null;
    });
  }

  Future<void> _speichern() async {
    final liste = ref.read(saisonNachtragProvider);
    if (_index >= liste.length) return;
    final b = liste[_index].betrieb;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _speichert = true);
    // Werte VOR der Änderung — Grundlage fürs Saison-Archiv.
    final altWinterStart = b.winterStartDatum;
    final altWinterEnde = b.winterEndeDatum;
    final altSommerStart = b.sommerStartDatum;
    final altSommerEnde = b.sommerEndeDatum;
    try {
      b.winterSaisonAktiv = _winterAktiv;
      b.winterStartDatum = _winterAktiv ? _winterStart : null;
      b.winterEndeDatum = _winterAktiv ? _winterEnde : null;
      b.sommerSaisonAktiv = _sommerAktiv;
      b.sommerStartDatum = _sommerAktiv ? _sommerStart : null;
      b.sommerEndeDatum = _sommerAktiv ? _sommerEnde : null;
      b.keineHerbstpause = _winterAktiv && _sommerAktiv && _keineHerbstpause;
      await BetriebRepository.save(b);

      // Gleiche Archiv-Regel wie im Betriebs-Formular: Ein neuer Start heisst
      // «neue Saison», das bisherige Fenster ist Geschichte.
      final sid = b.serverId;
      if (sid != null && sid.isNotEmpty) {
        final eintraege = [
          saisonArchivEintrag(
            saison: 'winter',
            altStart: altWinterStart,
            altEnde: altWinterEnde,
            neuStart: b.winterStartDatum,
          ),
          saisonArchivEintrag(
            saison: 'sommer',
            altStart: altSommerStart,
            altEnde: altSommerEnde,
            neuStart: b.sommerStartDatum,
          ),
        ].whereType<SaisonArchivEintrag>().toList();
        if (eintraege.isNotEmpty) {
          try {
            await BetriebSaisonHistorieRepository.archiviere(sid, eintraege);
          } catch (e) {
            // Das Archiv ist Beiwerk; die Saisondaten sind gespeichert.
            debugPrint('[Saison] Archiv nicht geschrieben: $e');
          }
        }
      }

      ref.invalidate(betriebeStreamProvider);
      if (!mounted) return;
      setState(() {
        _erledigt++;
        _zuletztGespeichert = b.name;
        _geladenFuer = null;
        // Index NICHT erhöhen: Der Betrieb fällt aus der Liste, damit rückt
        // der nächste von selbst nach. Sonst würde einer übersprungen.
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Nicht gespeichert: ${kurzeFehlermeldung(e)}')),
      );
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }

  Widget _fertigScaffold(bool leer) => Scaffold(
    appBar: AppBar(title: const Text('Saisondaten nachtragen')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 48,
              color: AppColors.success,
            ),
            const SizedBox(height: 12),
            Text(
              leer
                  ? 'Keine offenen Saisondaten.'
                  : 'Durch — $_erledigt nachgetragen.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (!leer) ...[
              const SizedBox(height: 8),
              const Text(
                'Die übersprungenen stehen weiterhin in der Warnung.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TapKnopf(
                text: 'Nochmals von vorn',
                primaer: false,
                onTap: () => setState(() {
                  _index = 0;
                  _erledigt = 0;
                  _geladenFuer = null;
                  _zuletztGespeichert = null;
                }),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _DatumFeld extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DatumFeld({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '' : _ddMMyyyy.format(value!);
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today, size: 18)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: '$label leeren',
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(
          text.isEmpty ? 'nicht gesetzt' : text,
          style: TextStyle(
            color: text.isEmpty ? AppColors.textSecondary : null,
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await zeigeDatumsauswahl(
      context,
      initial: value ?? DateTime.now(),
      erstes: DateTime(2020),
      letztes: DateTime(2050),
    );
    if (picked != null) onChanged(picked);
  }
}

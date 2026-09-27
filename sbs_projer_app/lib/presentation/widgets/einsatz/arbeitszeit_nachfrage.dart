import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/arbeitszeit_vorschlag_einsatz.dart';
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart' show Halt;
import 'package:sbs_projer_app/core/util/touren_anzeige.dart'
    show minutenAusHhmm;
import 'package:sbs_projer_app/presentation/providers/fahrten_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz/arbeitszeit_block.dart'
    show arbeitszeitFormatieren, arbeitszeitParsen;
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/presentation/widgets/zeit_auswahl.dart';

// Arbeitszeit beim Abschliessen einer Störung/Montage einmal nachfragen
// (Entscheid Daniel 27.09.2026). 34 von 36 Störungen seit August hatten kein
// `arbeit_von/bis` — die Zeitachse schätzte, «Fahrten aus der Kette» führte
// sie als «ohne Zeit». Gemeinsam für beide Formulare; die Vorschlagsregel
// steht rein in `core/util/arbeitszeit_vorschlag_einsatz.dart`.

/// Soll beim Speichern nach der Arbeitszeit gefragt werden?
///
/// Nur wenn der Einsatz mit diesem Speichern erledigt ist ([wirdErledigt]),
/// vor Ort stattfand ([vorOrt] — nicht bei Kilometerabrechnung, Spesen,
/// Aufwandsentschädigung, Anlass) und BEIDE Zeiten fehlen. Fehlt nur eine,
/// zeigt der `ArbeitszeitBlock` das schon an — keine zweite Frage.
/// [verzichtet]: früher «Ohne Zeit» gewählt — nicht bei jedem Speichern neu.
bool arbeitszeitNachfrageNoetig({
  required bool wirdErledigt,
  required bool vorOrt,
  required String arbeitVon,
  required String arbeitBis,
  bool verzichtet = false,
}) =>
    wirdErledigt &&
    vorOrt &&
    !verzichtet &&
    arbeitVon.trim().isEmpty &&
    arbeitBis.trim().isEmpty;

// ── «Ohne Zeit» merken ─────────────────────────────────────────────────
//
// Bewusst lokal (shared_preferences) statt eines DB-Felds: keine Migration
// für eine reine Bedien-Erinnerung (Entscheid 27.09.2026). Der Schlüssel
// trägt die Plan-Id des Einsatzes (`s_<id>` / `m_<id>`, wie im Tourenplan),
// damit Störung und Montage sich nie in die Quere kommen.

/// Schlüssel für [planId] (`s_<routeId>` bzw. `m_<routeId>`).
String arbeitszeitVerzichtSchluessel(String planId) =>
    'arbeitszeit_verzicht_$planId';

/// Wurde für [planId] schon «Ohne Zeit» gewählt? Ein gesperrter
/// Browser-Speicher zählt als «nein» — dann wird eben noch einmal gefragt.
Future<bool> arbeitszeitVerzichtet(String planId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(arbeitszeitVerzichtSchluessel(planId)) ?? false;
  } catch (e) {
    debugPrint('[Arbeitszeit] Verzicht nicht lesbar: $e');
    return false;
  }
}

/// Merkt sich «Ohne Zeit» für [planId]. Fehler bleiben still — schlimmstenfalls
/// kommt die Frage beim nächsten Speichern noch einmal.
Future<void> arbeitszeitVerzichtMerken(String planId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(arbeitszeitVerzichtSchluessel(planId), true);
  } catch (e) {
    debugPrint('[Arbeitszeit] Verzicht nicht gespeichert: $e');
  }
}

// ── Vorschlag laden ─────────────────────────────────────────────────────

/// Wie lange auf den Tagesplan gewartet wird, bevor ohne ihn vorgeschlagen
/// wird (heute «jetzt − Dauer», sonst leer). Das Speichern darf daran nicht
/// hängen bleiben.
const kArbeitszeitVorschlagTimeout = Duration(seconds: 6);

/// Halte des Tages über [tagesFahrtenProvider] und daraus der Vorschlag.
/// Fehler oder Zeitüberschreitung → Vorschlag ohne Kette.
Future<({String von, String bis})?> arbeitszeitVorschlagLaden(
  WidgetRef ref, {
  required DateTime datum,
  required String? betriebId,
  required int geplanteDauerMin,
  DateTime? jetzt,
}) async {
  final tag = DateTime(datum.year, datum.month, datum.day);
  var halte = const <Halt>[];
  // autoDispose: ohne Abo würde der Provider verworfen, bevor er liefert.
  final abo = ref.listenManual(tagesFahrtenProvider(tag), (_, _) {});
  try {
    final fahrten = await ref
        .read(tagesFahrtenProvider(tag).future)
        .timeout(kArbeitszeitVorschlagTimeout);
    halte = fahrten?.halte ?? const <Halt>[];
  } catch (e) {
    debugPrint('[Arbeitszeit] Tagesplan für Vorschlag nicht geladen: $e');
  } finally {
    abo.close();
  }
  return arbeitszeitVorschlag(
    datum: tag,
    betriebId: betriebId,
    halteDesTages: halte,
    geplanteDauerMin: geplanteDauerMin,
    jetzt: jetzt,
  );
}

// ── Ablauf beim Speichern ───────────────────────────────────────────────

enum ArbeitszeitWahl {
  /// Nicht nötig oder früher schon «Ohne Zeit» gewählt — normal speichern.
  nichtGefragt,

  /// Zeiten übernommen: [ArbeitszeitNachfrageErgebnis.von]/`bis` eintragen.
  uebernommen,

  /// «Ohne Zeit»: speichern wie bisher und den Verzicht merken.
  ohneZeit,

  /// Dialog weggetippt: nicht speichern, zurück ins Formular.
  abgebrochen,
}

class ArbeitszeitNachfrageErgebnis {
  const ArbeitszeitNachfrageErgebnis(this.wahl, {this.von, this.bis});

  final ArbeitszeitWahl wahl;

  /// 'HH:mm' — nur bei [ArbeitszeitWahl.uebernommen].
  final String? von, bis;
}

/// Der ganze Ablauf für beide Formulare: prüft [noetig] und einen früheren
/// Verzicht ([planId], `null` bei einem neuen Einsatz), lädt den Vorschlag
/// und zeigt die Frage.
Future<ArbeitszeitNachfrageErgebnis> arbeitszeitBeimAbschliessen(
  BuildContext context,
  WidgetRef ref, {
  required bool noetig,
  required String? planId,
  required DateTime datum,
  required String? betriebId,
  required int geplanteDauerMin,
  DateTime? jetzt,
}) async {
  const nichtGefragt = ArbeitszeitNachfrageErgebnis(
    ArbeitszeitWahl.nichtGefragt,
  );
  if (!noetig) return nichtGefragt;
  if (planId != null && await arbeitszeitVerzichtet(planId)) {
    return nichtGefragt;
  }
  final vorschlag = await arbeitszeitVorschlagLaden(
    ref,
    datum: datum,
    betriebId: betriebId,
    geplanteDauerMin: geplanteDauerMin,
    jetzt: jetzt,
  );
  if (!context.mounted) {
    return const ArbeitszeitNachfrageErgebnis(ArbeitszeitWahl.abgebrochen);
  }
  final antwort = await zeigeArbeitszeitNachfrage(
    context,
    vorschlag: vorschlag,
  );
  if (antwort == null) {
    return const ArbeitszeitNachfrageErgebnis(ArbeitszeitWahl.abgebrochen);
  }
  return antwort;
}

// ── Dialog ──────────────────────────────────────────────────────────────

/// «Arbeitszeit? Von – bis» mit [vorschlag] vorbelegt. Liefert
/// [ArbeitszeitWahl.uebernommen] mit den Zeiten, [ArbeitszeitWahl.ohneZeit]
/// oder `null` (weggetippt).
Future<ArbeitszeitNachfrageErgebnis?> zeigeArbeitszeitNachfrage(
  BuildContext context, {
  ({String von, String bis})? vorschlag,
}) => showDialog<ArbeitszeitNachfrageErgebnis>(
  context: context,
  builder: (_) => ArbeitszeitNachfrageDialog(vorschlag: vorschlag),
);

/// Aus Container/Row/GestureDetector und [TapKnopf] gebaut — Material-Knöpfe
/// rendern auf CanvasKit-Web nicht zuverlässig (CLAUDE.md). Die Zeitfelder
/// öffnen [zeigeZeitauswahl] (24 h).
class ArbeitszeitNachfrageDialog extends StatefulWidget {
  const ArbeitszeitNachfrageDialog({super.key, this.vorschlag});

  final ({String von, String bis})? vorschlag;

  @override
  State<ArbeitszeitNachfrageDialog> createState() =>
      _ArbeitszeitNachfrageDialogState();
}

class _ArbeitszeitNachfrageDialogState
    extends State<ArbeitszeitNachfrageDialog> {
  late String _von = widget.vorschlag?.von ?? '';
  late String _bis = widget.vorschlag?.bis ?? '';

  /// Beide gesetzt und verschieden (bis < von = über Mitternacht, Pikett).
  bool get _gueltig {
    final v = minutenAusHhmm(_von), b = minutenAusHhmm(_bis);
    return v != null && b != null && v != b;
  }

  bool get _ueberMitternacht {
    final v = minutenAusHhmm(_von), b = minutenAusHhmm(_bis);
    return v != null && b != null && b < v;
  }

  Future<void> _waehlen({required bool von}) async {
    final bisher = von ? _von : _bis;
    final picked = await zeigeZeitauswahl(
      context,
      initial: arbeitszeitParsen(bisher) ?? TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final text = arbeitszeitFormatieren(picked);
      if (von) {
        _von = text;
      } else {
        _bis = text;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hinweis = widget.vorschlag != null
        ? 'Vorschlag aus dem Tagesplan — zum Ändern antippen.'
        : 'Kein Vorschlag möglich — Zeiten antippen und wählen.';
    return AlertDialog(
      title: const Text('Arbeitszeit?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hinweis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Zeitfeld(
                  key: const Key('arbeitszeit_nachfrage_von'),
                  label: 'Von',
                  wert: _von,
                  onTap: () => _waehlen(von: true),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('–', style: TextStyle(fontSize: 18)),
              ),
              Expanded(
                child: _Zeitfeld(
                  key: const Key('arbeitszeit_nachfrage_bis'),
                  label: 'Bis',
                  wert: _bis,
                  onTap: () => _waehlen(von: false),
                ),
              ),
            ],
          ),
          if (_ueberMitternacht) ...[
            const SizedBox(height: 8),
            const Text(
              'Über Mitternacht (bis am Folgetag).',
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            '«Ohne Zeit» speichert wie bisher; für diesen Einsatz wird dann '
            'nicht mehr gefragt.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TapKnopf(
          text: 'Ohne Zeit',
          primaer: false,
          onTap: () => Navigator.pop(
            context,
            const ArbeitszeitNachfrageErgebnis(ArbeitszeitWahl.ohneZeit),
          ),
        ),
        TapKnopf(
          text: 'Übernehmen',
          icon: Icons.check,
          onTap: _gueltig
              ? () => Navigator.pop(
                  context,
                  ArbeitszeitNachfrageErgebnis(
                    ArbeitszeitWahl.uebernommen,
                    von: _von,
                    bis: _bis,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

class _Zeitfeld extends StatelessWidget {
  const _Zeitfeld({
    super.key,
    required this.label,
    required this.wert,
    required this.onTap,
  });

  final String label;
  final String wert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label ${wert.isEmpty ? 'leer' : wert}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.filterBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    wert.isEmpty ? '—' : wert,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/config/router.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/presentation/widgets/diktat_sheet.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/data/repositories/montage_repository.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';
import 'package:sbs_projer_app/data/repositories/termin_repository.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_detektoren_provider.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/datum_auswahl.dart';
import 'package:sbs_projer_app/presentation/widgets/einplanen_sheet.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';

/// Die Aktionen der Aufgabenliste — Sheet und Screen rufen dieselben (B6).
/// Jede Aktion endet mit dem Invalidieren der Tabelle und der Liste; Fehler
/// landen als SnackBar, nie als stiller Abbruch.
class AufgabenAktionen {
  final WidgetRef ref;
  const AufgabenAktionen(this.ref);

  void _neuLaden() {
    ref.invalidate(aufgabenZeilenProvider);
    ref.invalidate(draussenAufgabenProvider);
    ref.invalidate(aufgabenListeProvider);
  }

  Future<void> _sicher(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: ${kurzeFehlermeldung(e)}')),
        );
      }
    } finally {
      _neuLaden();
    }
  }

  /// «Dorthin». Im Sheet erst das Sheet schliessen — der Router-Push aus
  /// dem Sheet-Kontext heraus landete sonst unter dem Sheet.
  void dorthin(
    BuildContext context,
    AufgabenEintrag a, {
    bool imSheet = false,
  }) {
    final route = a.route;
    if (route == null) return;
    if (imSheet) Navigator.pop(context);
    // Wartende Diktate: das Sheet hat keine Adresse, es wird geöffnet.
    if (route == kDiktatAktion) {
      final ziel = imSheet
          ? router.routerDelegate.navigatorKey.currentContext
          : context;
      if (ziel != null && ziel.mounted) zeigeDiktatSheet(ziel);
      return;
    }
    router.push(route);
  }

  Future<void> snooze(BuildContext context, AufgabenEintrag a, int tage) =>
      _sicher(context, () => AufgabenRepository.snooze(a.key, tage));

  Future<void> erledigt(BuildContext context, AufgabenEintrag a) =>
      _sicher(context, () async {
        switch (a.quelle) {
          case AufgabenQuelle.eigene:
            await AufgabenRepository.eigeneErledigen(a.eigeneId!);
          case AufgabenQuelle.termin:
            await TerminRepository.erledigen(a.terminId!);
            ref.invalidate(offeneTermineProvider);
          case AufgabenQuelle.detektor:
            await AufgabenRepository.markerSetzen(a.key);
          default:
            return;
        }
      });

  Future<void> bestaetigen(BuildContext context, AufgabenEintrag a) =>
      _sicher(context, () async {
        final s = a.saison;
        if (s == null) return;
        await TerminRepository.anlegen(
          betriebId: s.betriebId,
          typ: s.typ,
          datum: s.datum,
          titel: s.titel,
          anlass: s.anlass,
        );
        ref.invalidate(offeneTermineProvider);
      });

  /// Einplanen einer Störung oder Montage — der Ablauf aus dem früheren
  /// Aufgaben-Screen, unverändert. Das Rohmodell wird über die `routeId`
  /// nachgeschlagen, weil der Eintrag nur die Einsatz-Sicht trägt.
  Future<void> einplanen(BuildContext context, AufgabenEintrag a) async {
    final e = a.einsatz;
    if (e == null) return;
    final lookup = ref.read(betriebLookupProvider);
    if (e.typ == EinsatzTyp.stoerung) {
      final s = ref
          .read(stoerungenProvider)
          .where((x) => x.routeId == e.routeId)
          .firstOrNull;
      if (s == null) return;
      final betrieb = s.betriebId != null ? lookup[s.betriebId!] : null;
      final titel = betrieb?.name ?? '?';
      final ergebnis = await zeigeEinplanenSheet(
        context,
        titel: titel,
        untertitel: s.problemBeschreibung,
        initialTag: s.geplantAm,
        initialZeit: s.geplantZeit,
        initialDauerMin: s.geplantDauerMin,
      );
      if (ergebnis == null) return;
      // Muss VOR dem Schreiben gelesen werden — siehe Doku bei
      // `einsatzUmplanen`. Ohne das Aufnehmen in den Tagesplan landet
      // der Einsatz nur in der Fällig-Liste des Zieltags, nie in der
      // Zeitachse; ohne das Entfernen aus dem alten Tag bleibt er
      // dort als „Geisterblock" stehen (Fehlerbericht 02.08.2026,
      // beide Teile).
      final altesDatum = s.geplantAm;
      await einsatzUmplanen(
        ref,
        altesDatum: altesDatum,
        neuesDatum: ergebnis.tag,
        schreiben: () async {
          await StoerungRepository.einplanen(
            id: s.routeId,
            tag: ergebnis.tag,
            zeit: ergebnis.zeit,
            dauerMin: ergebnis.dauerMin,
          );
          ref.invalidate(stoerungenStreamProvider);
        },
        eintrag: geplanterEinsatzEintrag(
          typ: TourEintragTyp.stoerung,
          routeId: s.routeId,
          betriebId: s.betriebId,
          anlageId: s.anlageId,
          betriebName: betrieb?.name ?? '?',
          betriebOrt: betrieb?.ort,
          regionId: betrieb?.regionId,
          beschreibung: s.problemBeschreibung,
          ruhetage: betrieb?.ruhetage ?? const [],
          servicezeit: servicezeitAus(betrieb),
          tag: ergebnis.tag,
          zeit: ergebnis.zeit,
          dauerMin: ergebnis.dauerMin,
        ),
      );
      _neuLaden();
    } else if (e.typ == EinsatzTyp.montage) {
      final m = ref
          .read(montagenProvider)
          .where((x) => x.routeId == e.routeId)
          .firstOrNull;
      if (m == null) return;
      final betrieb = m.betriebId != null ? lookup[m.betriebId!] : null;
      final titel = betrieb?.name ?? '?';
      final ergebnis = await zeigeEinplanenSheet(
        context,
        titel: titel,
        untertitel: m.montageTyp,
        initialTag: m.geplantAm,
        initialZeit: m.geplantZeit,
        initialDauerMin: m.geplantDauerMin,
      );
      if (ergebnis == null) return;
      // Muss VOR dem Schreiben gelesen werden — siehe Doku bei
      // `einsatzUmplanen`. Ohne das Aufnehmen in den Tagesplan landet
      // der Einsatz nur in der Fällig-Liste des Zieltags, nie in der
      // Zeitachse; ohne das Entfernen aus dem alten Tag bleibt er
      // dort als „Geisterblock" stehen (Fehlerbericht 02.08.2026,
      // beide Teile).
      final altesDatum = m.geplantAm;
      await einsatzUmplanen(
        ref,
        altesDatum: altesDatum,
        neuesDatum: ergebnis.tag,
        schreiben: () async {
          await MontageRepository.einplanen(
            id: m.routeId,
            tag: ergebnis.tag,
            zeit: ergebnis.zeit,
            dauerMin: ergebnis.dauerMin,
          );
          ref.invalidate(montagenStreamProvider);
        },
        eintrag: geplanterEinsatzEintrag(
          typ: m.montageTyp == 'heigenie_service'
              ? TourEintragTyp.heigenie
              : TourEintragTyp.montage,
          routeId: m.routeId,
          betriebId: m.betriebId,
          anlageId: m.anlageId,
          betriebName: betrieb?.name ?? '?',
          betriebOrt: betrieb?.ort,
          regionId: betrieb?.regionId,
          beschreibung: m.beschreibung,
          ruhetage: betrieb?.ruhetage ?? const [],
          servicezeit: servicezeitAus(betrieb),
          tag: ergebnis.tag,
          zeit: ergebnis.zeit,
          dauerMin: ergebnis.dauerMin,
          montageTyp: m.montageTyp,
        ),
      );
      _neuLaden();
    }
  }
}

/// Dialog «Neue Aufgabe» — für Sheet und Screen derselbe. `TextButton`
/// statt `FilledButton` (CanvasKit-Regel).
Future<void> neueAufgabeDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  DateTime? faellig;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Neue Aufgabe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Titel'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    faellig == null
                        ? 'Kein Datum'
                        : DateFormat('dd.MM.yyyy').format(faellig!),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final gewaehlt = await zeigeDatumsauswahl(
                      ctx,
                      initial: DateTime.now(),
                      erstes: DateTime.now(),
                      letztes: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (gewaehlt != null) setState(() => faellig = gewaehlt);
                  },
                  child: const Text('Datum wählen'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Anlegen'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || controller.text.trim().isEmpty) return;
  await AufgabenRepository.eigeneAnlegen(controller.text.trim(), faellig);
  ref.invalidate(aufgabenZeilenProvider);
  ref.invalidate(aufgabenListeProvider);
}

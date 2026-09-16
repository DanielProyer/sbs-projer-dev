import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_datei_repository.dart';
import 'package:sbs_projer_app/data/repositories/lohn_repository.dart';
import 'package:sbs_projer_app/presentation/providers/camt_pruefliste_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_pruef_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Ein Monat als Schlüssel — Records sind vergleichbar, damit taugen sie als
/// `family`-Argument ohne eigene Klasse.
typedef MonatsSchluessel = ({int jahr, int monat});

String _tagSchluessel(String betriebId, DateTime d) =>
    '$betriebId|${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Die Befunde eines Monats. Lädt alles einmal und parallel — nach dem
/// Vorbild von `abschlussPruefungProvider`.
final monatsPruefungProvider = FutureProvider.autoDispose
    .family<List<Pruefbefund>, MonatsSchluessel>((ref, m) async {
      final von = DateTime(m.jahr, m.monat, 1);
      final bis = DateTime(m.jahr, m.monat + 1, 0);
      bool imMonat(DateTime d) => !d.isBefore(von) && !d.isAfter(bis);

      final betriebe = ref.watch(betriebLookupProvider);
      final reinigungen = await ref.watch(
        reinigungenByJahrProvider(m.jahr).future,
      );
      final belegIds = await BuchungRepository.belegIdsMitBuchung(
        ab: von,
        bis: bis,
      );

      final einsaetze = <Einsatz>[
        for (final r in reinigungen)
          if (imMonat(r.datum))
            einsatzAusReinigung(
              r,
              betrieb: betriebe[r.betriebId],
              hatBuchung: r.serverId != null && belegIds.contains(r.serverId),
            ),
        for (final s in ref.watch(stoerungenProvider))
          if (imMonat(s.datum))
            einsatzAusStoerung(s, betrieb: betriebe[s.betriebId]),
        for (final mo in ref.watch(montagenProvider))
          if (imMonat(mo.datum))
            einsatzAusMontage(mo, betrieb: betriebe[mo.betriebId]),
      ];

      // Berg-Tage aus den Reinigungen des Monats: ein Besuch = Betrieb + Tag
      // (180 CHF je Besuch, nicht je Anlage).
      //
      // Über die abgeleitete Lage statt über `status == 'abgeschlossen'`:
      // Der rohe Vergleich ist genau das, was die Ratsche
      // (`test/status_vergleiche_ratsche_test.dart`) abbauen soll — und
      // `erledigt`/`verrechnet` sagt dasselbe, nur in der Sprache von B2.
      const fertig = {EinsatzStatus.erledigt, EinsatzStatus.verrechnet};
      final bergTage = <String>{
        for (final e in einsaetze)
          if (e.typ == EinsatzTyp.reinigung &&
              fertig.contains(e.status) &&
              e.betriebId != null &&
              (betriebe[e.betriebId]?.istBergkunde ?? false))
            _tagSchluessel(e.betriebId!, e.datum),
      };

      final client = SupabaseService.client;
      final uid = SupabaseService.dataUserId;
      final vonStr = von.toIso8601String().split('T').first;
      final bisStr = bis.toIso8601String().split('T').first;

      var pauschalenTage = <String>{};
      try {
        final rows = await client
            .from('bergkundenpauschalen')
            .select('betrieb_id, datum')
            .eq('user_id', uid)
            .gte('datum', vonStr)
            .lte('datum', bisStr);
        pauschalenTage = {
          for (final r in rows)
            _tagSchluessel(
              r['betrieb_id'] as String,
              DateTime.parse(r['datum'] as String),
            ),
        };
      } catch (e) {
        debugPrint('[Monatsabschluss] Pauschalen: $e');
      }

      String? heinekenStatus;
      try {
        final rows = await client
            .from('rechnungen')
            .select('zahlungsstatus')
            .eq('user_id', uid)
            .eq('rechnungstyp', 'heineken_monat')
            .eq('heineken_monat', vonStr)
            .limit(1);
        if (rows.isNotEmpty) {
          heinekenStatus = rows.first['zahlungsstatus'] as String?;
        }
      } catch (e) {
        debugPrint('[Monatsabschluss] Heineken-Rechnung: $e');
      }

      // Mail-Rechnungen ohne Versandvermerk: Die Zahlungsart steht an der
      // Reinigung, nicht an der Rechnung — deshalb über die Reinigungen des
      // Monats und deren Rechnungsstatus.
      var mailRechnungenOffen = 0;
      try {
        final rows = await client
            .from('rechnungen')
            .select('id, betrieb_id, created_at')
            .eq('user_id', uid)
            .eq('zahlungsstatus', 'offen')
            .neq('rechnungstyp', 'heineken_monat')
            .gte('created_at', vonStr)
            .lte('created_at', '${bisStr}T23:59:59');
        for (final r in rows) {
          final betriebId = r['betrieb_id']?.toString();
          if (betriebId == null) continue;
          final rein = await client
              .from('reinigungen')
              .select('id')
              .eq('betrieb_id', betriebId)
              .eq('zahlungsart', 'rechnung_mail')
              .eq('datum', (r['created_at'] as String).split('T').first)
              .limit(1);
          if (rein.isNotEmpty) mailRechnungenOffen++;
        }
      } catch (e) {
        debugPrint('[Monatsabschluss] Versandvermerk: $e');
      }

      // Feldnamen weichen vom Plan ab: `CamtDatei` heisst `zeitraumVon`/
      // `zeitraumBis` (nicht `von`/`bis`) und beide sind nullbar — dieselbe
      // Filterung wie in `abschlussPruefungProvider`.
      var camtDeckung = <({DateTime von, DateTime bis})>[];
      try {
        final dateien = await CamtDateiRepository.getAll();
        camtDeckung = [
          for (final d in dateien)
            if (d.zeitraumVon != null && d.zeitraumBis != null)
              (von: d.zeitraumVon!, bis: d.zeitraumBis!),
        ];
      } catch (e) {
        debugPrint('[Monatsabschluss] camt-Dateien: $e');
      }

      var offenePruefliste = 0;
      try {
        final offen = await ref.watch(camtPrueflisteProvider.future);
        offenePruefliste = offen.where((e) => imMonat(e.bookingDatum)).length;
      } catch (e) {
        debugPrint('[Monatsabschluss] Prüfliste: $e');
      }

      var lohnMonate = <int>{};
      try {
        final abrechnungen = await LohnRepository.getAbrechnungen(m.jahr);
        lohnMonate = {for (final a in abrechnungen) a.monat};
      } catch (e) {
        debugPrint('[Monatsabschluss] Lohn: $e');
      }

      return pruefeMonat(
        MonatsKontext(
          jahr: m.jahr,
          monat: m.monat,
          heute: DateTime.now(),
          einsaetze: einsaetze,
          mailRechnungenOffen: mailRechnungenOffen,
          heinekenStatus: heinekenStatus,
          bergTage: bergTage,
          pauschalenTage: pauschalenTage,
          camtDeckung: camtDeckung,
          offenePrueflisteImMonat: offenePruefliste,
          lohnMonate: lohnMonate,
        ),
      );
    });

/// Der Vormonat als Schlüssel — die Vorgabe des Screens und die Grundlage
/// des Detektors.
MonatsSchluessel vormonat(DateTime heute) {
  final d = DateTime(heute.year, heute.month - 1, 1);
  return (jahr: d.year, monat: d.month);
}

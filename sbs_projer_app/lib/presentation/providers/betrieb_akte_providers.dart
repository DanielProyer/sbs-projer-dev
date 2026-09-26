import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/betrieb_geld.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_akte.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/eigenauftrag_repository.dart';
import 'package:sbs_projer_app/data/repositories/eroeffnungsreinigung_repository.dart';
import 'package:sbs_projer_app/data/repositories/guthaben_repository.dart';
import 'package:sbs_projer_app/data/repositories/montage_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Offener Saldo, Mahnstufe und Guthaben eines Betriebs (Server-Id).
/// Ein Ladefehler bleibt ein Fehler — die Karte zeigt dann «nicht geladen»
/// statt einer falschen 0.
final betriebGeldProvider = FutureProvider.autoDispose
    .family<BetriebGeldStand, String>((ref, betriebId) async {
      // Beide Anfragen gleichzeitig; scheitert eine, scheitert das Ganze.
      final (rechnungen, guthaben) = await (
        RechnungRepository.getByBetrieb(betriebId),
        GuthabenRepository.offenesGuthaben(betriebId),
      ).wait;
      return betriebGeldStand(rechnungen, guthaben);
    });

/// Schlüssel der Akte: ein Betrieb, optional eingeschränkt auf eine Anlage.
typedef AkteSchluessel = ({String betriebId, String? anlageId});

/// Alle Einsätze eines Betriebs über alle Jahre, neueste zuerst (T10).
/// Quelle: die `getByBetrieb`-Aufrufe der fünf Typen, zusammengeführt über
/// dieselben Adapter wie der Einsätze-Screen (`einsaetzeDerAkte`).
final betriebEinsaetzeProvider = FutureProvider.autoDispose
    .family<List<Einsatz>, AkteSchluessel>((ref, k) async {
      final betrieb = ref.watch(betriebLookupProvider)[k.betriebId];
      final (reinigungen, stoerungen, montagen, eigenauftraege, saison) =
          await (
            ReinigungRepository.getByBetrieb(k.betriebId),
            StoerungRepository.getByBetrieb(k.betriebId),
            MontageRepository.getByBetrieb(k.betriebId),
            EigenauftragRepository.getByBetrieb(k.betriebId),
            EroeffnungsreinigungRepository.getByBetrieb(k.betriebId),
          ).wait;

      // «verrechnet» hängt an der Ertragsbuchung — dieselbe Regel wie im
      // Einsätze-Screen. Buchungen liegen nur auf dem Server; nativ bleibt
      // es bei `istAbgerechnet`.
      final belegIds = kIsWeb
          ? await BuchungRepository.belegIdsMitBuchungAus([
              for (final r in reinigungen)
                if (r.serverId != null) r.serverId!,
            ])
          : const <String>{};

      return einsaetzeDerAkte(
        betrieb: betrieb,
        reinigungen: reinigungen,
        stoerungen: stoerungen,
        montagen: montagen,
        eigenauftraege: eigenauftraege,
        saisonreinigungen: saison,
        belegIdsMitBuchung: belegIds,
        anlageId: k.anlageId,
      );
    });

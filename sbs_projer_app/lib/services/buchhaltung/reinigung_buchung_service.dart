import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/buchungs_beleg_repository.dart';
import 'package:sbs_projer_app/data/repositories/buchungs_vorlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/preis_repository.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Zahlungsarten, die eine Debitoren-Buchung auslösen. 'jahresrechnung' ist
/// dabei, obwohl sie KEINE Einzelrechnung erzeugt — die Forderung entsteht
/// trotzdem. Deshalb taugt `istRechnungsart` aus zahlungsart.dart hier nicht.
const reinigungRechnungsTypen = {
  'rechnung_tresen',
  'rechnung_mail',
  'rechnung_post',
  'jahresrechnung',
};

/// Braucht diese abgeschlossene Reinigung eine Ertragsbuchung?
///
/// Dieselbe Bedingung wie in [ReinigungBuchungService.createFromReinigung] —
/// bewusst als reine Funktion, damit die Nachhol-Suche
/// ([BuchungNachholService]) nicht eine zweite, driftende Kopie führt. `art`
/// ist die bereits aufgelöste Zahlungsart (`resolveZahlungsart`).
bool brauchtErtragsbuchung({
  required String art,
  required double netto,
  bool istKulanz = false,
  bool istHeinekenMonteur = false,
}) {
  if (istKulanz || istHeinekenMonteur) return false;
  if (netto <= 0) return false;
  return art == 'barzahlung' || reinigungRechnungsTypen.contains(art);
}

class ReinigungBuchungService {
  static double _round2(double v) => (v * 100).roundToDouble() / 100;
  static double _mwstFaktor = 0.081;

  /// Schweizer Rappenrundung: auf 5 Rappen (0.05 CHF) runden.
  static double _round5Rappen(double v) => (v * 20).roundToDouble() / 20;

  /// Netto-Betrag einer Reinigung — auch für die Nachhol-Suche, damit dort
  /// dieselbe Zahl über «buchen oder nicht» entscheidet wie hier.
  static double netto(ReinigungLocal reinigung) => _calcNetto(reinigung);

  /// Berechnet den tatsächlichen Netto-Betrag aus allen Komponenten.
  /// preis_netto in der DB kann unvollständig sein (nur Grundtarif).
  static double _calcNetto(ReinigungLocal reinigung) {
    final hatGrundtarif =
        reinigung.preisGrundtarif != null && reinigung.preisGrundtarif! > 0;
    if (!hatGrundtarif &&
        reinigung.preisBrutto != null &&
        reinigung.preisBrutto! > 0) {
      return _round2(reinigung.preisBrutto! / (1 + _mwstFaktor));
    }
    double netto = 0;
    if (hatGrundtarif) netto += reinigung.preisGrundtarif!;
    netto += reinigung.anzahlHaehneEigen * 18.0;
    netto += reinigung.anzahlHaehneOrion * 18.0;
    netto += reinigung.anzahlHaehneFremd * 23.0;
    netto += reinigung.anzahlHaehneWein * 23.0;
    netto += reinigung.anzahlHaehneAndererStandort * 30.0;
    // Bergkundenzuschlag wird Heineken verrechnet, NICHT dem Kunden
    return _round2(netto);
  }

  /// Erstellt Buchungen aus einer abgeschlossenen Reinigung:
  /// - Barzahlung (GF 1): Soll 1000 (Kasse) / Haben 3400 (Erlöse)
  /// - Rechnung (GF 1.1): Soll 1100 (Debitoren) / Haben 3400 (Erlöse)
  /// + MwSt-Buchung: Soll 3400 / Haben 2200 (Geschuldete MwSt)
  /// Gibt null zurück wenn keine Buchung nötig ist.
  static Future<Buchung?> createFromReinigung(
    ReinigungLocal reinigung,
    BetriebLocal betrieb,
  ) async {
    // MwSt-Satz laden
    final preis = await PreisRepository.getAktuell(datum: reinigung.datum);
    if (preis != null) _mwstFaktor = preis.mwstFaktor;

    // Massgebend ist die Zahlungsart der REINIGUNG (Ursache der 38: hier stand
    // betrieb.rechnungsstellung — heineken fiel lautlos durch, Cache veraltete).
    final rs = resolveZahlungsart(
      reinigung.zahlungsart,
      betrieb.rechnungsstellung,
    );
    final istBar = rs == 'barzahlung';

    // Netto aus den Komponenten rechnen (preisNetto kann unvollständig sein).
    final netto = _calcNetto(reinigung);

    // Einzige Stelle für «wird gebucht oder nicht» — dieselbe Funktion nutzt
    // die Nachhol-Suche, damit beide nie auseinanderlaufen.
    if (!brauchtErtragsbuchung(
      art: rs,
      netto: netto,
      istKulanz: reinigung.istKulanz,
      istHeinekenMonteur: reinigung.istHeinekenMonteur,
    )) {
      return null;
    }

    // Duplikat-Check via belegId
    final existing = await BuchungRepository.getByBeleg(reinigung.serverId!);
    if (existing.isNotEmpty) {
      debugPrint('ReinigungBuchung: Buchung existiert bereits für ${reinigung.serverId}');
      return null;
    }

    // Vorlage laden: GF '1' für Barzahlung, GF '1.1' für Rechnung
    final gfId = istBar ? '1' : '1.1';
    final vorlagen = await BuchungsVorlageRepository.getAll();
    final vorlage = vorlagen.cast<dynamic>().firstWhere(
      (v) => v.geschaeftsfallId == gfId && v.istAktiv,
      orElse: () => null,
    );
    if (vorlage == null) {
      debugPrint('ReinigungBuchung: Keine aktive Vorlage GF $gfId gefunden');
      return null;
    }

    final mwstSatz = vorlage.mwstSatz ?? 0.0;
    final datumStr = reinigung.datum.toIso8601String().split('T').first;

    // Beträge: 5-Rappen-Rundung für alle CHF-Beträge (Schweizer Standard)
    final bruttoRaw = netto * (1 + mwstSatz / 100);
    final brutto = _round5Rappen(bruttoRaw);
    final mwstBetrag = _round2(brutto - netto);

    final zahlungsweg = istBar ? 'kasse' : 'rechnung';
    final typLabel = istBar ? 'Bar' : 'Rechnung';

    try {
      // 1. Hauptbuchung: Soll (Kasse/Debitoren) / Haben 3400 (Erlöse) → Brutto
      final buchung = await BuchungRepository.create({
        'datum': datumStr,
        'vorlage_id': vorlage.id,
        'soll_konto': vorlage.sollKonto, // 1000 (Bar) oder 1100 (Debitoren)
        'haben_konto': vorlage.habenKonto, // 3400
        'mwst_konto': vorlage.mwstKonto, // 2200
        'betrag_netto': netto,
        'mwst_satz': mwstSatz,
        'mwst_betrag': mwstBetrag,
        'betrag_brutto': brutto,
        'beschreibung': 'Reinigung $typLabel – ${betrieb.name}',
        'zahlungsweg': zahlungsweg,
        'beleg_typ': 'rechnung',
        'beleg_id': reinigung.serverId,
        'geschaeftsjahr': reinigung.datum.year,
      });

      // KEINE separate MwSt-Trennbuchung mehr: die Hauptbuchung trägt
      // mwst_konto, die SaldoExpansion teilt Netto/MwSt/Brutto bereits auf.
      // Die frühere Zeile 3400/2200 verdoppelte die MwSt (Befund B1, 06.08.2026).

      // 2. Reinigungsprotokoll als Beleg anhängen
      await _attachProtokoll(buchung.id, reinigung, betrieb);

      debugPrint('ReinigungBuchung ($typLabel): Netto $netto, MwSt $mwstBetrag, Brutto $brutto');
      return buchung;
    } catch (e) {
      debugPrint('ReinigungBuchung fehlgeschlagen: $e');
      rethrow;
    }
  }

  /// Lädt das Reinigungsprotokoll aus Storage und hängt es als Beleg an die Buchung.
  static Future<void> _attachProtokoll(
    String buchungId,
    ReinigungLocal reinigung,
    BetriebLocal betrieb,
  ) async {
    final pfad = reinigung.protokollFotoPfad;
    if (pfad == null || pfad.isEmpty) return;

    try {
      final bytes = await SupabaseService.client.storage
          .from('reinigung-fotos')
          .download(pfad);
      final isPdf = pfad.endsWith('.pdf');
      await BuchungsBelegRepository.upload(
        buchungId: buchungId,
        dateiname: 'Reinigungsprotokoll.${isPdf ? 'pdf' : 'jpg'}',
        dateityp: isPdf ? 'pdf' : 'jpg',
        bytes: bytes,
        belegQuelle: 'rechnung',
        beschreibung: 'Reinigungsprotokoll ${betrieb.name}',
      );
    } catch (e) {
      debugPrint('ReinigungBuchung: Protokoll-Upload fehlgeschlagen: $e');
    }
  }
}

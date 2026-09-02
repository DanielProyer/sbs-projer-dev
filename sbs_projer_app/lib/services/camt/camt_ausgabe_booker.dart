import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';

import 'package:sbs_projer_app/services/buchhaltung/geschaeftsfall_resolver.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Löst die Konten einer Vorlage für den camt-Kontext auf. Phase-0a-Vorlagen
/// (art 'ausgabe'/'einnahme') tragen das Konto in `hauptkonto` und haben
/// soll/haben = NULL — der direkte Zugriff crashte dort (Fall «Bussen»/
/// «Fahrbewilligung»). camt läuft immer über die Bank → Zahlungsweg 'bank'.
AufgeloesteBuchung kontenFuerCamt(BuchungsVorlage vorlage) =>
    GeschaeftsfallResolver.aufloesen(vorlage, 'bank');

/// Das Bank-Konto, über das jede camt-Transaktion läuft.
const int kCamtBankKonto = 1020;

/// Muss bei einer Gutschrift getauscht werden? Nur, wenn die Vorlage die Bank
/// NICHT schon im Soll führt. Eine Einzahlungs-Vorlage wie «Bargeldeinzahlung»
/// (1020 an 1000) ist bereits richtig herum — der pauschale Tausch von
/// v0.72.8 drehte sie fälschlich zu «Kasse an Bank» (Doppel-Tausch-Bug,
/// gefunden beim Nachhol-Import 07.08.2026: 2 Automaten-Einzahlungen 8'050).
bool kontenWerdenGetauscht({
  required bool isCredit,
  required int vorlageSoll,
}) =>
    isCredit && vorlageSoll != kCamtBankKonto;

/// Konten und Beträge einer camt-Ausgabe-Buchung — richtungsbewusst (B8-Fix,
/// Buchhaltungsprüfung 06.08.2026; präzisiert 07.08.2026):
/// - **Belastung** (Normalfall): Konten wie in der Vorlage, MwSt-Split über
///   `mwst_konto` (SaldoExpansion).
/// - **Gutschrift** auf einer Vorlage, die die Bank bereits im Soll führt
///   (Einzahlungs-Vorlage, z. B. Bargeldeinzahlung 1020/1000): Konten wie in
///   der Vorlage, Split wie Vorlage — nichts zu drehen.
/// - **Gutschrift** auf einer echten Ausgabe-Vorlage (Bank im Haben, z. B.
///   Prämien-Rückerstattung): Konten getauscht, damit die Bank im Soll steht.
///   Der Vorsteuer-Split lässt sich in einer Zeile nicht invertieren (die
///   SaldoExpansion wählt den Zweig nach Konto-Klasse) → brutto ohne Split
///   buchen; die MwSt ist im Einzelfall manuell zu prüfen (Notiz-Hinweis).
Map<String, dynamic> ausgabeBuchungsFelder({
  required double betrag,
  required bool isCredit,
  required double mwstSatz,
  required int vorlageSoll,
  required int vorlageHaben,
  int? vorlageMwstKonto,
}) {
  final brutto = _round2(betrag);
  if (kontenWerdenGetauscht(isCredit: isCredit, vorlageSoll: vorlageSoll)) {
    return {
      'soll_konto': vorlageHaben,
      'haben_konto': vorlageSoll,
      'mwst_konto': null,
      'betrag_netto': brutto,
      'mwst_satz': 0,
      'mwst_betrag': 0.0,
      'betrag_brutto': brutto,
    };
  }
  final netto = mwstSatz > 0 ? _round2(brutto / (1 + mwstSatz / 100)) : brutto;
  return {
    'soll_konto': vorlageSoll,
    'haben_konto': vorlageHaben,
    'mwst_konto': vorlageMwstKonto,
    'betrag_netto': netto,
    'mwst_satz': mwstSatz,
    'mwst_betrag': _round2(brutto - netto),
    'betrag_brutto': brutto,
  };
}

/// Zuordnung einer Steuerzahlung beim camt-Bestätigen (Spec 02.09.2026, Abschnitt 5).
class SteuerZuordnung {
  final int steuerjahr;
  final String steuerart; // bund | kanton | mwst | busse
  final bool hatRueckstellung; // 2208-Saldo des Jahres > 0
  const SteuerZuordnung({
    required this.steuerjahr,
    required this.steuerart,
    required this.hatRueckstellung,
  });
}

/// Vorlagen mit diesem Soll-Konto sind Steuerzahlungen → Zuordnung anbieten.
bool istSteuerKonto(int konto) =>
    konto == 8900 || konto == 2208 || konto == 2202;

/// Gewinn-/Kapitalsteuer gegen die Rückstellung, sofern eine gebildet wurde;
/// Bussen sind nie zurückgestellt; MWST läuft über das Abrechnungskonto.
int steuerKontoFuer({required String steuerart, required bool hatRueckstellung}) {
  if (steuerart == 'mwst') return 2202;
  if (steuerart == 'busse') return 8900;
  return hatRueckstellung ? 2208 : 8900;
}

/// Noch nicht verbrauchte Steuerrückstellung (Konto 2208) je Steuerjahr.
///
/// Gruppiert wird nach `steuerjahr`, sonst nach `geschaeftsjahr` — die
/// Rückstellung entsteht im Abschluss des Steuerjahres (8900 an 2208), die
/// Umbuchungen der Zahlungen fallen ins Folgejahr (2208 an 8900).
///
/// **Der Gesamtsaldo des Kontos ist die Schranke.** Am 02.09.2026 trugen alle
/// drei 2208-Zeilen `steuerjahr = NULL`: Rückstellung 4'000.00 im Jahr 2025,
/// die beiden Umbuchungen (2'405.50 + 2'748.00) im Jahr 2026. Rein nach Jahr
/// gruppiert sähe 2025 nach +4'000.00 aus, obwohl das Konto gesamthaft mit
/// −1'153.50 überzogen ist — eine weitere Zahlung gegen 2208 hätte die
/// Rückstellung noch tiefer ins Minus gezogen. Deshalb: Gesamtsaldo ≤ 0 →
/// keine Rückstellung; sonst deckelt er jeden Jahreswert.
Map<int, double> rueckstellungsRest(List<Buchung> buchungen) {
  final saldoJeJahr = <int, double>{};
  double gesamt = 0;
  for (final b in buchungen) {
    if (!zaehltFuerSaldo(
        istStorniert: b.istStorniert, stornoVonId: b.stornoVonId)) {
      continue;
    }
    final jahr = b.steuerjahr ?? b.geschaeftsjahr;
    if (b.habenKonto == 2208) {
      saldoJeJahr[jahr] = (saldoJeJahr[jahr] ?? 0) + b.betragBrutto;
      gesamt += b.betragBrutto;
    } else if (b.sollKonto == 2208) {
      saldoJeJahr[jahr] = (saldoJeJahr[jahr] ?? 0) - b.betragBrutto;
      gesamt -= b.betragBrutto;
    }
  }
  if (gesamt <= 0.05) return {};
  return {
    for (final e in saldoJeJahr.entries)
      if (e.value > 0.05) e.key: e.value < gesamt ? e.value : gesamt,
  };
}

/// Steuerjahre, deren Rückstellung (Konto 2208) noch etwas hergibt.
Set<int> rueckstellungsJahre(List<Buchung> buchungen) =>
    rueckstellungsRest(buchungen).keys.toSet();

/// Steht die Bank (1020/1000) im Soll, kommt das Steuerkonto ins Haben — eine
/// Zahlung fliesst dann ZUR Firma zurück und die Rückstellung baut auf; sonst
/// wird sie verbraucht. Einzige Quelle für beides: die Seitenwahl in
/// [steuerFelderAnwenden] und die Fortschreibung des Rückstellungs-Rests.
bool rueckstellungBautAuf(Map<String, dynamic> felder) =>
    felder['soll_konto'] == kCamtBankKonto || felder['soll_konto'] == 1000;

/// Setzt bei einer bestätigten Steuerzahlung das Steuerkonto auf die Seite
/// GEGENÜBER der Bank und stempelt Steuerjahr/Steuerart, damit die
/// Steuer-Übersicht die Zahlung ohne Nacharbeit findet.
///
/// Die Seite folgt der Bank (1020/1000) und nicht der camt-Richtung: eine als
/// «Bank an 2208» definierte Rückerstattungs-Vorlage würde sonst bei einer
/// Belastung die Bank überschreiben und der Zahlungsweg ginge verloren.
/// Steuern tragen keine Vorsteuer → der MwSt-Split wird neutralisiert.
Map<String, dynamic> steuerFelderAnwenden(
  Map<String, dynamic> felder, {
  required SteuerZuordnung steuer,
}) {
  final konto = steuerKontoFuer(
      steuerart: steuer.steuerart, hatRueckstellung: steuer.hatRueckstellung);
  return {
    ...felder,
    if (rueckstellungBautAuf(felder)) 'haben_konto': konto else 'soll_konto': konto,
    'mwst_konto': null,
    'mwst_satz': 0,
    'mwst_betrag': 0.0,
    'betrag_netto': felder['betrag_brutto'],
    'steuerjahr': steuer.steuerjahr,
    'steuerart': steuer.steuerart,
  };
}

/// Bucht eine Ausgabe/Bargeld-Transaktion aus camt anhand einer Buchungsvorlage.
/// Erzeugt EINE Buchung (Brutto/Netto/MwSt in einer Zeile) und stempelt den
/// camt_tx_key direkt für robusten Dedup.
class CamtAusgabeBooker {
  static Future<Buchung> book(CamtTransaction tx, BuchungsVorlage vorlage,
      {SteuerZuordnung? steuer}) async {
    final konten = kontenFuerCamt(vorlage);
    var felder = ausgabeBuchungsFelder(
      betrag: tx.amount,
      isCredit: tx.isCredit,
      mwstSatz: vorlage.mwstSatz ?? 0,
      vorlageSoll: konten.sollKonto,
      vorlageHaben: konten.habenKonto,
      vorlageMwstKonto: konten.mwstKonto,
    );
    if (steuer != null) {
      felder = steuerFelderAnwenden(felder, steuer: steuer);
    }
    final datumStr = tx.bookingDate.toIso8601String().split('T').first;
    final beschreibung = tx.partyName != null
        ? '${tx.isCredit ? "Zahlung" : "Belastung"} ${tx.partyName}'
        : (tx.additionalInfo ?? vorlage.bezeichnung);
    final notizen = <String>[
      if (kontenWerdenGetauscht(
          isCredit: tx.isCredit, vorlageSoll: konten.sollKonto))
        'GUTSCHRIFT auf Ausgabe-Regel (Konten getauscht) — MwSt manuell prüfen',
      if (steuer != null) 'Steuer ${steuer.steuerjahr} ${steuer.steuerart}',
      if (tx.strukturierteReferenz != null) 'Ref: ${tx.strukturierteReferenz}',
      if (tx.partyIban != null) 'IBAN: ${tx.partyIban}',
    ].join('\n');

    return BuchungRepository.create({
      'datum': datumStr,
      'belegnummer': tx.accountServiceRef,
      'vorlage_id': vorlage.id,
      ...felder,
      'beschreibung': beschreibung,
      'zahlungsweg': vorlage.zahlungsweg ?? 'bank',
      'belegordner': vorlage.belegordner ?? 'bank',
      'beleg_typ': 'camt053',
      'geschaeftsjahr': tx.bookingDate.year,
      'camt_tx_key': tx.txKey,
      'notizen': notizen,
    });
  }
}

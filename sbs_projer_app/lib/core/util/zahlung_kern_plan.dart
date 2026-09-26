/// ZahlungKern — reine Planung (Analyse 25.09.2026 §3 Befund E, Runde 3).
///
/// Baut aus [differenzPlan] die Buchungszeilen und Rechnungs-Updates, die
/// `zahlung_erfassen` (SQL, Migration 209) in EINER Transaktion schreibt.
/// Alles Geld-Relevante (5-Rappen, Guthaben, Verlust von hinten) bleibt hier
/// in Dart und getestet; die DB prüft nur Sperren und schreibt.
library;

import 'dart:convert';

import 'package:sbs_projer_app/core/util/guthaben.dart';
import 'package:sbs_projer_app/core/util/guthaben_verrechnung.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/rechnung/mahnlauf_service.dart';

enum ZahlungWeg { bank, kasse, verrechnung }

/// Wohin eine Mehrzahlung geht (Entscheid 26.09.2026, Annahme 2).
enum MehrzahlungZiel { aoErtrag, guthaben }

/// Bis hierhin ist eine Mehrzahlung Trinkgeld/Rundung (8000); darüber ist
/// es Geld des Kunden (2030, wird mit der nächsten Rechnung verrechnet).
const double kMehrzahlungGuthabenAb = 5.00;

MehrzahlungZiel mehrzahlungStandard(double mehr) =>
    mehr > kMehrzahlungGuthabenAb + 1e-9
        ? MehrzahlungZiel.guthaben
        : MehrzahlungZiel.aoErtrag;

/// Belegtyp der Differenzzeilen einer erlassenen Minderzahlung (3805 + 2200).
///
/// WARUM `abschreibung` und nicht `zahlung`: `view_entgeltsminderung`
/// (Migration 196, MWST Ziff. 235) zählt nur Buchungen `2200 an 1100` mit
/// `beleg_typ = 'abschreibung'`. Mit `zahlung` fiele die MWST-Rückholung aus
/// der Deklaration. Folge für die Rücknahme («Zahlung rückgängig», SQL):
/// sie muss diese Zeilen über `beleg_id` + Belegtyp `abschreibung`
/// mitnehmen. Hinweis: die View setzt als Netto `r.betrag_netto` der
/// ganzen Rechnung an — für eine Teil-Minderung ist das zu hoch (siehe
/// Bericht Runde 3, Task 2).
const String kBelegTypMinderung = 'abschreibung';

class ZahlungKernPlan {
  final List<Map<String, dynamic>> buchungen;

  /// rechnung_id → {zahlung_betrag, zahlung_eingegangen_am, guthaben_verrechnet?}
  final Map<String, Map<String, dynamic>> updates;

  /// rechnung_id → Vorher-Stand (Status, 6 Mahnfelder, guthaben_verrechnet)
  final Map<String, Map<String, dynamic>> vorher;

  /// rechnung_id → Status, den die App gesehen hat
  final Map<String, String> erwartet;
  final List<String> camtTxKeys;
  final double differenz;
  final MehrzahlungZiel? mehrzahlungZiel;

  const ZahlungKernPlan({
    required this.buchungen,
    required this.updates,
    required this.vorher,
    required this.erwartet,
    required this.camtTxKeys,
    required this.differenz,
    required this.mehrzahlungZiel,
  });
}

String _tag(DateTime d) => d.toIso8601String().split('T').first;

/// MWST-Anteil eines Bruttobetrags im Satz der Rechnung (0, wenn die
/// Rechnung keine MWST trägt). Entgeltsminderung wie bei der Abschreibung.
double mwstAnteil(Rechnung r, double brutto) {
  if (r.mwstBetrag <= 0 || r.betragBrutto <= 0) return 0;
  return rundeAufRappen(brutto * r.mwstBetrag / r.betragBrutto);
}

const String kRechnungstypHeineken = 'heineken_monat';

/// Der Heineken-Zweig lehnt eine Zahlung ab (falsche Gruppierung, falscher
/// Weg, abweichender Betrag) — lesbarer Text statt roher `ArgumentError`
/// (Review Runde 3). `ZahlungGesperrt` passt nicht: die liegt in
/// `services/rechnung/zahlung_kern.dart`, dieser Fehler entsteht schon in der
/// reinen Planung, bevor die DB überhaupt gefragt wird.
class ZahlungPlanFehler implements Exception {
  final String text;
  const ZahlungPlanFehler(this.text);
  @override
  String toString() => text;
}

/// Heineken-Monatsrechnung: Heineken fakturiert UNGERUNDET (Befund B2
/// 06.08.2026) und zahlt genau das Brutto — KEINE 5-Rappen-Rundung, sonst
/// blieben auf 1100 Rappenreste stehen und 1020 wiche vom Kontoauszug ab.
/// Kein Guthaben, keine Differenzbuchung: Weicht der Betrag ab, ist das kein
/// Heineken-Treffer — dann wird nichts geplant (Fehler).
ZahlungKernPlan _heinekenPlan(List<Rechnung> rechnungen, double betrag,
    DateTime datum, ZahlungWeg weg, String? camtTxKey) {
  if (rechnungen.length != 1) {
    throw const ZahlungPlanFehler(
        'Heineken-Rechnungen werden einzeln bezahlt, nie gemischt oder gesammelt');
  }
  if (weg != ZahlungWeg.bank) {
    throw const ZahlungPlanFehler('Heineken zahlt nur per Bank');
  }
  final r = rechnungen.single;
  final brutto = rundeAufRappen(r.betragBrutto);
  if ((rundeAufRappen(betrag) - brutto).abs() >= 0.005) {
    throw ZahlungPlanFehler('Heineken-Zahlung ${rundeAufRappen(betrag)} ≠ '
        'Rechnungsbetrag $brutto — nichts gebucht');
  }
  final m = r.heinekenMonat;
  final monat =
      m == null ? '?' : '${m.month.toString().padLeft(2, '0')}/${m.year}';
  return ZahlungKernPlan(
    buchungen: [
      {
        'datum': _tag(datum),
        'belegnummer': r.rechnungsnummer ?? '',
        'soll_konto': 1020,
        'haben_konto': 1100,
        'betrag_netto': brutto,
        'mwst_satz': 0,
        'mwst_betrag': 0,
        'betrag_brutto': brutto,
        'beschreibung': 'Zahlungseingang Heineken $monat',
        'zahlungsweg': 'bank',
        'beleg_typ': 'zahlung',
        'beleg_id': r.id,
        'geschaeftsjahr': datum.year,
        if (camtTxKey != null) 'camt_tx_key': camtTxKey,
      },
    ],
    updates: {
      r.id: {'zahlung_betrag': brutto, 'zahlung_eingegangen_am': _tag(datum)},
    },
    vorher: {
      r.id: {
        ...MahnlaufService.vorherStand(r),
        'guthaben_verrechnet': r.guthabenVerrechnet,
      },
    },
    erwartet: {r.id: r.zahlungsstatus},
    camtTxKeys: [if (camtTxKey != null) camtTxKey],
    differenz: 0,
    mehrzahlungZiel: null,
  );
}

ZahlungKernPlan zahlungKernPlan({
  required List<Rechnung> rechnungen,
  required double betrag,
  required DateTime datum,
  required ZahlungWeg weg,
  Map<String, DateTime> datumProRechnung = const {},
  Map<String, String> camtTxKeyProRechnung = const {},
  String? camtTxKey,
  MehrzahlungZiel? mehrzahlung,
}) {
  if (rechnungen.any((r) => r.rechnungstyp == kRechnungstypHeineken)) {
    return _heinekenPlan(rechnungen, betrag, datum, weg, camtTxKey);
  }
  final plan = differenzPlan(rechnungen, betrag);
  final buchungen = <Map<String, dynamic>>[];
  final updates = <String, Map<String, dynamic>>{};
  final vorher = <String, Map<String, dynamic>>{};
  final erwartet = <String, String>{};
  final keys = <String>{};

  DateTime datumFuer(Rechnung r) => weg == ZahlungWeg.verrechnung
      ? r.rechnungsdatum
      : (datumProRechnung[r.id] ?? datum);
  String? keyFuer(Rechnung r) => camtTxKeyProRechnung[r.id] ?? camtTxKey;

  final sollHaupt = weg == ZahlungWeg.kasse ? 1000 : 1020;
  final wegText = weg == ZahlungWeg.kasse ? 'kasse' : 'bank';
  final sammel = rechnungen.length > 1 ? ' (Sammelzahlung)' : '';

  for (final z in plan.zeilen) {
    final r = z.rechnung;
    final nr = r.rechnungsnummer ?? '';
    final d = datumFuer(r);
    final key = keyFuer(r);
    if (key != null) keys.add(key);
    if (z.bank >= 0.005 && weg != ZahlungWeg.verrechnung) {
      buchungen.add({
        'datum': _tag(d),
        'belegnummer': nr,
        'soll_konto': sollHaupt,
        'haben_konto': 1100,
        'betrag_netto': z.bank,
        'mwst_satz': 0,
        'mwst_betrag': 0,
        'betrag_brutto': z.bank,
        'beschreibung':
            '${weg == ZahlungWeg.kasse ? 'Barzahlung' : 'Zahlungseingang'} $nr$sammel',
        'zahlungsweg': wegText,
        'beleg_typ': 'zahlung',
        'beleg_id': r.id,
        'geschaeftsjahr': d.year,
        if (z.guthabenVorher > 0)
          'notizen': guthabenNotiz(z.guthabenVorher)
        // Barzahlung: Mahn-Stand vor der Zahlung zusätzlich in der Notiz (nur
        // zur Nachvollziehbarkeit im Journal). Die Rücknahme liest ihn NICHT
        // hier, sondern aus `zahlungsgruppen.vorher` (zahlung_zuruecknehmen).
        else if (weg == ZahlungWeg.kasse)
          'notizen': jsonEncode(MahnlaufService.vorherStand(r)),
        if (key != null) 'camt_tx_key': key,
      });
    }
    if (z.verrechnung >= 0.005) {
      buchungen.add({
        'datum': _tag(d),
        'belegnummer': nr,
        'soll_konto': kKontoKundenguthaben,
        'haben_konto': 1100,
        'betrag_netto': z.verrechnung,
        'mwst_satz': 0,
        'mwst_betrag': 0,
        'betrag_brutto': z.verrechnung,
        'beschreibung': 'Verrechnung Kundenguthaben $nr',
        'zahlungsweg': 'intern',
        'beleg_typ': 'sonstiges',
        'beleg_id': r.id,
        'geschaeftsjahr': d.year,
      });
    }
    // zahlung_betrag = zugeordnet: Basis der Zeile («zu zahlen» bzw. Brutto)
    // + Verrechnung — einheitlich für alle Wege (vorher je Weg anders).
    final basis =
        rundeAuf5Rappen(plan.guthabenVerrechnet ? r.zuZahlen : r.betragBrutto);
    updates[r.id] = {
      'zahlung_betrag': weg == ZahlungWeg.verrechnung
          ? 0
          : rundeAufRappen(basis + z.verrechnung),
      'zahlung_eingegangen_am': _tag(d),
      if (plan.guthabenZuruecksetzen && r.guthabenVerrechnet > 0)
        'guthaben_verrechnet': 0,
    };
    vorher[r.id] = {
      ...MahnlaufService.vorherStand(r),
      'guthaben_verrechnet': r.guthabenVerrechnet,
    };
    erwartet[r.id] = r.zahlungsstatus;
  }

  MehrzahlungZiel? ziel;
  final diff = plan.differenz;
  if (diff.abs() >= 0.01 &&
      rechnungen.isNotEmpty &&
      weg != ZahlungWeg.verrechnung) {
    final letzte = rechnungen.last;
    final nr = letzte.rechnungsnummer ?? '';
    final d = datumFuer(letzte);
    final key = keyFuer(letzte);
    if (diff < 0) {
      // Minderzahlung erlassen = Entgeltsminderung: netto 3805, MWST-Anteil
      // 2200 (wie AbschreibungService). Belegtyp siehe [kBelegTypMinderung].
      final brutto = diff.abs();
      final mwst = mwstAnteil(letzte, brutto);
      final netto = rundeAufRappen(brutto - mwst);
      buchungen.add({
        'datum': _tag(d),
        'belegnummer': nr,
        'soll_konto': 3805,
        'haben_konto': 1100,
        'betrag_netto': netto,
        'mwst_satz': 0,
        'mwst_betrag': 0,
        'betrag_brutto': netto,
        'beschreibung': 'Debitorenverlust $nr$sammel (Differenz erlassen, netto)',
        'zahlungsweg': 'intern',
        'beleg_typ': kBelegTypMinderung,
        'beleg_id': letzte.id,
        'geschaeftsjahr': d.year,
      });
      if (mwst >= 0.005) {
        buchungen.add({
          'datum': _tag(d),
          'belegnummer': nr,
          'soll_konto': 2200,
          'haben_konto': 1100,
          'betrag_netto': mwst,
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': mwst,
          'beschreibung': 'MWST-Rückholung $nr (Differenz erlassen, Ziff. 235)',
          'zahlungsweg': 'intern',
          'beleg_typ': kBelegTypMinderung,
          'beleg_id': letzte.id,
          'geschaeftsjahr': d.year,
        });
      }
    } else {
      // Mehrzahlung auf 2030: Soll 1020 / Haben 2030, beleg_id = Rechnung.
      // offenesGuthabenJeBetrieb (guthaben.dart) filtert NICHT nach
      // beleg_typ — jedes Haben 2030 mit bekannter Rechnung zählt als
      // Guthaben des Betriebs; `zahlung` ist hier also unkritisch.
      ziel = mehrzahlung ?? mehrzahlungStandard(diff);
      final guthaben = ziel == MehrzahlungZiel.guthaben;
      buchungen.add({
        'datum': _tag(d),
        'belegnummer': nr,
        'soll_konto': sollHaupt,
        'haben_konto': guthaben ? kKontoKundenguthaben : 8000,
        'betrag_netto': diff,
        'mwst_satz': 0,
        'mwst_betrag': 0,
        'betrag_brutto': diff,
        'beschreibung': guthaben
            ? 'Mehrzahlung $nr — Kundenguthaben (wird mit der nächsten Rechnung verrechnet)'
            : 'Mehrzahlung $nr (Trinkgeld/Rundung)',
        'zahlungsweg': wegText,
        'beleg_typ': 'zahlung',
        'beleg_id': letzte.id,
        'geschaeftsjahr': d.year,
        if (key != null) 'camt_tx_key': key,
      });
    }
  }

  return ZahlungKernPlan(
    buchungen: buchungen,
    updates: updates,
    vorher: vorher,
    erwartet: erwartet,
    camtTxKeys: keys.toList(),
    differenz: diff,
    mehrzahlungZiel: ziel,
  );
}

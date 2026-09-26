import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Warum eine abgeschlossene Reinigung NICHT mehr preisrelevant geändert
/// werden darf. Bis v0.139.0 löschte jeder «Speichern»-Klick auf einer
/// abgeschlossenen Reinigung Rechnung und Buchungen und legte sie neu an —
/// ohne Blick auf bezahlt, gemahnt, Mahnfall oder abgeschlossenes Jahr
/// (Analyse 25.09.2026, R1). Reihenfolge = Schwere: bezahlt vor Mahnfall vor
/// gemahnt vor versendet vor Jahr.
enum KorrekturSperre {
  keine,
  bezahlt,
  mahnfall,
  gemahnt,
  versendet,
  abgeschlossenesJahr,
}

const _bezahltStatus = {'bezahlt', 'abgeschrieben'};
const _gemahntStatus = {'erinnert', 'mahnung_1', 'mahnung_2'};

KorrekturSperre korrekturSperre({
  required Rechnung? rechnung,
  required bool hatZahlungsbuchung,
  required bool imMahnfall,
  required DateTime nachbuchGrenze,
}) {
  if (rechnung == null) return KorrekturSperre.keine;
  if (_bezahltStatus.contains(rechnung.zahlungsstatus) ||
      rechnung.zahlungEingegangenAm != null ||
      hatZahlungsbuchung) {
    return KorrekturSperre.bezahlt;
  }
  if (imMahnfall) return KorrekturSperre.mahnfall;
  if (rechnung.mahnungStufe > 0 ||
      _gemahntStatus.contains(rechnung.zahlungsstatus)) {
    return KorrekturSperre.gemahnt;
  }
  if (rechnung.versendetAm != null || rechnung.uebergebenAm != null) {
    return KorrekturSperre.versendet;
  }
  if (rechnung.rechnungsdatum.isBefore(nachbuchGrenze)) {
    return KorrekturSperre.abgeschlossenesJahr;
  }
  return KorrekturSperre.keine;
}

/// Text für Band und Dialog. Leer bei [KorrekturSperre.keine].
String sperrText(KorrekturSperre sperre, String? rechnungsnummer) {
  final nr = rechnungsnummer == null ? 'Die Rechnung' : 'Rechnung $rechnungsnummer';
  const ausweg = ' Notiz, Foto und Zeiten lassen sich weiterhin speichern.';
  return switch (sperre) {
    KorrekturSperre.keine => '',
    KorrekturSperre.bezahlt =>
      '$nr ist bereits bezahlt — Preis und Positionen sind gesperrt.$ausweg',
    KorrekturSperre.mahnfall =>
      '$nr steckt in einem Mahnfall — Preis und Positionen sind gesperrt.$ausweg',
    KorrekturSperre.gemahnt =>
      '$nr wurde bereits gemahnt — Preis und Positionen sind gesperrt.$ausweg',
    KorrekturSperre.versendet =>
      '$nr ist beim Kunden (versendet/übergeben) — eine Preisänderung braucht '
          'einen Storno mit neuer Rechnung (kommt mit Runde 3).$ausweg',
    KorrekturSperre.abgeschlossenesJahr =>
      '$nr liegt in einem abgeschlossenen Geschäftsjahr — Preis und Positionen '
          'sind gesperrt.$ausweg',
  };
}

/// Ob sich zwischen [alt] (geladener Stand) und [neu] (Formular) etwas
/// geändert hat, das Rechnung oder Buchung berührt. Alles, was
/// `RechnungService._buildPositionen` und `ReinigungBuchungService._calcNetto`
/// lesen (Grundtarif, Hähne-Mengen aller Kategorien, Brutto-Rückrechnung,
/// Service-Typ für die Positionsbeschreibung), plus Datum
/// (Rechnungsnummer/-datum), Zahlungsart (Kasse vs. Debitoren) und Kulanz/
/// Heineken-Monteur (steuern `brauchtErtragsbuchung`). Notizen, Zeiten,
/// Foto, Checkliste zählen NICHT.
bool preisrelevantGeaendert(ReinigungLocal alt, ReinigungLocal neu) {
  DateTime tag(DateTime d) => DateTime(d.year, d.month, d.day);
  return tag(alt.datum) != tag(neu.datum) ||
      alt.zahlungsart != neu.zahlungsart ||
      alt.serviceTyp != neu.serviceTyp ||
      alt.istKulanz != neu.istKulanz ||
      alt.istHeinekenMonteur != neu.istHeinekenMonteur ||
      alt.preisGrundtarif != neu.preisGrundtarif ||
      alt.preisZusatzHaehne != neu.preisZusatzHaehne ||
      alt.bergkundenZuschlag != neu.bergkundenZuschlag ||
      alt.preisNetto != neu.preisNetto ||
      alt.preisBrutto != neu.preisBrutto ||
      alt.anzahlHaehneEigen != neu.anzahlHaehneEigen ||
      alt.anzahlHaehneOrion != neu.anzahlHaehneOrion ||
      alt.anzahlHaehneFremd != neu.anzahlHaehneFremd ||
      alt.anzahlHaehneWein != neu.anzahlHaehneWein ||
      alt.anzahlHaehneAndererStandort != neu.anzahlHaehneAndererStandort ||
      alt.anlageIdsJson != neu.anlageIdsJson;
}

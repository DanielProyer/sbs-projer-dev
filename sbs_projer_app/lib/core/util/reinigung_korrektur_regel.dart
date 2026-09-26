import 'dart:convert';

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
  jahresrechnung,
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
  // Die Jahresrechnung trägt die Positionen ALLER Reinigungen des Jahres;
  // `zuruecknehmen` würde sie ganz löschen (Review af581d42).
  if (rechnung.rechnungstyp == 'jahresrechnung') {
    return KorrekturSperre.jahresrechnung;
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
String sperrText(KorrekturSperre sperre, String? rechnungsnummer,
    {bool mitAusweg = true}) {
  final nr = rechnungsnummer == null ? 'Die Rechnung' : 'Rechnung $rechnungsnummer';
  final ausweg =
      mitAusweg ? ' Notiz, Foto und Zeiten lassen sich weiterhin speichern.' : '';
  return switch (sperre) {
    KorrekturSperre.keine => '',
    KorrekturSperre.bezahlt =>
      '$nr ist bereits bezahlt — Preis und Positionen sind gesperrt.$ausweg',
    KorrekturSperre.jahresrechnung =>
      '$nr ist eine Jahresrechnung — Preisänderung nur über die '
          'Jahresrechnung selbst.$ausweg',
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
/// lesen (Grundtarif, Bergkunde, Hähne-Mengen aller Kategorien, Brutto-Rückrechnung,
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
      alt.istBergkunde != neu.istBergkunde ||
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
      !_gleicheMenge(anlagenMenge(alt), anlagenMenge(neu));
}

bool _gleicheMenge(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

/// Anlagen einer Reinigung als Menge. Bei rund 5800 Altfällen ist
/// `anlage_ids` null und nur `anlageId` gesetzt; das Formular schreibt beim
/// Speichern aber immer das JSON — ein Textvergleich meldete dann bei jeder
/// Notiz-Änderung «preisrelevant». Reihenfolge zählt nicht.
Set<String> anlagenMenge(ReinigungLocal r) {
  final json = r.anlageIdsJson;
  if (json != null && json.isNotEmpty) {
    final liste = (jsonDecode(json) as List).map((e) => e.toString()).toSet();
    if (liste.isNotEmpty) return liste;
  }
  return r.anlageId.isEmpty ? <String>{} : {r.anlageId};
}

/// Kopie genau der Felder, die [preisrelevantGeaendert] vergleicht.
///
/// WARUM: Das Formular bearbeitet das geladene Objekt direkt
/// (`r = _existing ?? ReinigungLocal()`), `_existing` und `r` sind also
/// dasselbe Objekt — ein Vergleich `preisrelevantGeaendert(_existing!, r)`
/// wäre immer false und der Wächter blind. Deshalb hält das Formular beim
/// Laden diesen Schnappschuss fest. Bewusst hier neben dem Vergleich statt
/// über einen Mapper-Roundtrip: Kommt ein Feld zum Vergleich dazu, muss es
/// hier mit (sonst meldet der Vergleich für dieses Feld immer «geändert»,
/// sobald es gesetzt ist — sicher, aber lästig).
ReinigungLocal preisSchnappschuss(ReinigungLocal r) => ReinigungLocal()
  ..datum = r.datum
  ..zahlungsart = r.zahlungsart
  ..serviceTyp = r.serviceTyp
  ..istKulanz = r.istKulanz
  ..istHeinekenMonteur = r.istHeinekenMonteur
  ..istBergkunde = r.istBergkunde
  ..preisGrundtarif = r.preisGrundtarif
  ..preisZusatzHaehne = r.preisZusatzHaehne
  ..bergkundenZuschlag = r.bergkundenZuschlag
  ..preisNetto = r.preisNetto
  ..preisBrutto = r.preisBrutto
  ..anzahlHaehneEigen = r.anzahlHaehneEigen
  ..anzahlHaehneOrion = r.anzahlHaehneOrion
  ..anzahlHaehneFremd = r.anzahlHaehneFremd
  ..anzahlHaehneWein = r.anzahlHaehneWein
  ..anzahlHaehneAndererStandort = r.anzahlHaehneAndererStandort
  ..anlageId = r.anlageId
  ..anlageIdsJson = r.anlageIdsJson;

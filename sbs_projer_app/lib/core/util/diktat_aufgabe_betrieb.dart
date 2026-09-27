/// Betrieb einer diktierten Aufgabe (Migration 212, Entscheid Daniel
/// 27.09.2026).
///
/// «Beim Rössli den Hahn mitnehmen» — bis v0.148 legte das Diktat daraus
/// die Aufgabe «Hahn mitnehmen» an: `parse-einsatz` erkennt den Betrieb
/// zwar für jede Art (auch «aufgabe»), lässt ihn aber bewusst aus der
/// Beschreibung weg, und das Diktat-Sheet warf ihn bei Aufgaben weg. Jetzt
/// wird er zugeordnet — sichtbar und korrigierbar im Sheet, nie still.
///
/// Die Messlatte bleibt die der Betriebserkennung: lieber kein Betrieb als
/// ein falscher.
library;

import 'package:sbs_projer_app/core/util/einsatz_betrieb_match.dart';
import 'package:sbs_projer_app/core/util/google_termin_match.dart'
    show normalisiereText, unterscheidendeTokens;
import 'package:sbs_projer_app/data/models/einsatz_diktat_ergebnis.dart';

/// Zuordnung: [id]/[name] nur, wenn eindeutig; sonst höchstens
/// [kandidaten] zum Antippen.
typedef DiktatBetrieb = ({
  String? id,
  String? name,
  List<EinsatzBetriebKandidat> kandidaten,
});

const DiktatBetrieb _keiner = (id: null, name: null, kandidaten: []);

/// Der in [text] genannte Betrieb — über die App-eigene Betriebserkennung
/// (`betriebKandidaten`: Umlaut-Faltung, Tippfehler-Nähe, Gattungswörter
/// wie «Hotel» zählen nicht). Genau ein Treffer → eindeutig; mehrere →
/// nur Kandidaten; keiner → leer.
DiktatBetrieb betriebAusText(String text, List<BetriebEintrag> betriebe) {
  final treffer = betriebKandidaten(text: text, betriebe: betriebe);
  if (treffer.isEmpty) return _keiner;
  if (treffer.length == 1) {
    return (id: treffer.single.id, name: treffer.single.name, kandidaten: []);
  }
  return (
    id: null,
    name: null,
    kandidaten: [
      for (final t in treffer) EinsatzBetriebKandidat(id: t.id, name: t.name),
    ],
  );
}

/// Nennt [erkannt] den Betrieb [b] exakt? Jeder unterscheidende Namensteil
/// (ohne Gattungswörter wie «Restaurant») steht — nach der Umlaut-Faltung,
/// «Rossli» = «Rössli» — unverändert im erkannten Namen; ein Ort daneben
/// stört nicht («Rössli Ilanz»). Ein Tippfehler-Treffer («Adlar» →
/// «Adler») oder ein Teiltreffer («Sunset» → «Sunset Seehotel») zählt nicht.
bool nenntBetriebExakt(String erkannt, BetriebEintrag b) {
  final namensTeile = unterscheidendeTokens(b.name);
  if (namensTeile.isEmpty) return false;
  final woerter = normalisiereText(erkannt).split(' ').toSet();
  return namensTeile.every(woerter.contains);
}

/// Betrieb einer diktierten Aufgabe aus dem Ergebnis von `parse-einsatz`
/// und dem Rohtext [text]:
///
/// 1. Die Function hat einen Betrieb zugeordnet (und es gibt ihn) → der.
/// 2. Sie nennt Kandidaten → die, Daniel wählt.
/// 3. Sie hat einen Namen erkannt, aber keinen Betrieb gefunden → die
///    App-Erkennung auf diesen Namen (verhörte Eigennamen: «Rossli»).
///    Vorgewählt nur bei einem EXAKTEN Namenstreffer ([nenntBetriebExakt]);
///    ein bloss ähnlicher Einzeltreffer kommt als Chip zum Antippen — die
///    Tippfehler-Toleranz macht aus «Adlar» sonst still den «Adler»
///    (Review K6, 27.09.2026).
/// 4. Sie hat gar nichts erkannt → die App-Erkennung auf den ganzen Text,
///    aber NUR als Kandidat zum Antippen, nie vorgewählt: Die Function hat
///    den Satz mit der ganzen Betriebsliste gelesen und keinen Betrieb
///    gesehen — ein Einzelwort-Treffer der App soll das nicht überstimmen.
DiktatBetrieb aufgabeBetriebAusDiktat({
  required EinsatzDiktatErgebnis ergebnis,
  required String text,
  required List<BetriebEintrag> betriebe,
}) {
  String? nameVon(String id) {
    for (final b in betriebe) {
      if (b.id == id) return b.name;
    }
    return null;
  }

  // 1. Eine erfundene Id würde beim Speichern am Fremdschlüssel scheitern.
  final id = ergebnis.betriebId;
  if (id != null) {
    final name = nameVon(id);
    if (name != null) return (id: id, name: name, kandidaten: []);
  }

  // 2.
  final kandidaten = [
    for (final k in ergebnis.betriebKandidaten)
      if (nameVon(k.id) != null) k,
  ];
  if (kandidaten.isNotEmpty) {
    return (id: null, name: null, kandidaten: kandidaten);
  }

  // 3.
  final erkannt = ergebnis.betriebNameErkannt;
  if (erkannt != null) {
    final ausName = betriebAusText(erkannt, betriebe);
    final id = ausName.id;
    if (id == null) return ausName;
    final b = betriebe.firstWhere((b) => b.id == id);
    return nenntBetriebExakt(erkannt, b) ? ausName : _nurChip(ausName);
  }

  // 4.
  return _nurChip(betriebAusText(text, betriebe));
}

/// Ein eindeutiger Treffer, aber nur als Kandidat zum Antippen.
DiktatBetrieb _nurChip(DiktatBetrieb d) => d.id == null
    ? d
    : (
        id: null,
        name: null,
        kandidaten: [EinsatzBetriebKandidat(id: d.id!, name: d.name!)],
      );

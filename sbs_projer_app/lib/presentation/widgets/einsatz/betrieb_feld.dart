import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/betrieb_anzeige.dart';
import 'package:sbs_projer_app/core/util/betrieb_suche.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

/// Wie man einen gewählten Betrieb wieder los wird.
enum BetriebLeeren {
  /// Kreuz-Knopf im Feld (Störung, Montage, Kontakt).
  knopf,

  /// Feld leer tippen (Eigenauftrag, Eröffnungsreinigung).
  tippen,
}

/// Vorschläge des Betriebfelds für die Eingabe [suche].
///
/// Nur Betriebe mit `serverId` (die anderen lassen sich nicht verknüpfen).
/// Leere Eingabe: die ersten [leerMax] Betriebe, bei `null` alle. Sonst gilt
/// die gemeinsame Suchregel [betriebPasst] (A9).
Iterable<BetriebLocal> betriebVorschlaege(
  List<BetriebLocal> betriebe,
  String suche, {
  int? leerMax = 20,
}) {
  final mitId = betriebe.where((b) => b.serverId != null).toList();
  if (suche.isEmpty) {
    return leerMax == null ? mitId : mitId.take(leerMax);
  }
  final query = suche.toLowerCase();
  return mitId.where(
    (b) => betriebPasst(
      name: b.name,
      ort: b.ort,
      betriebNr: b.betriebNr,
      suche: query,
    ),
  );
}

/// Betrieb-Autocomplete der Einsatzformulare (Analyse 25.09.2026, §2.2).
///
/// WARUM ein Baustein: Das Feld stand fünfmal im Code (Störung, Montage,
/// Eigenauftrag, Eröffnungsreinigung, Kontakt), je ~85 Zeilen, mit kleinen,
/// unabsichtlichen Abweichungen. Die fachlichen Unterschiede sind jetzt
/// Parameter; der Standard jedes Parameters ist das Verhalten von Störung.
///
/// Der Zustand (welcher Betrieb gewählt ist und was daraus folgt, z. B.
/// Bergkunde) bleibt im Formular: [onGewaehlt]/[onGeleert] melden die
/// Änderung, [onGeaendert] wird davor gerufen (→ `markiereGeaendert`).
class BetriebFeld extends StatelessWidget {
  /// Alle Betriebe (typisch `ref.watch(betriebeProvider)`); Betriebe ohne
  /// `serverId` werden ausgeblendet.
  final List<BetriebLocal> betriebe;

  /// Aktuell gewählter Betrieb (`serverId`) — bestimmt den Anfangstext.
  final String? betriebId;

  final ValueChanged<BetriebLocal> onGewaehlt;
  final VoidCallback onGeleert;

  /// Vor jeder Auswahl/Leerung gerufen — das Formular legt ihn auf
  /// `markiereGeaendert`.
  final VoidCallback? onGeaendert;

  final String label;

  /// Fehlermeldung, wenn kein Betrieb gewählt ist; `null` = kein Pflichtfeld.
  final String? pflichtMeldung;

  /// Anzeige «Name, Ort» statt nur Name (Kontakt: mehrere Betriebe heissen
  /// gleich, Daniel 23.09.2026).
  final bool mitOrt;

  /// Vorschläge bei leerer Eingabe: die ersten N, `null` = alle.
  final int? leerMax;

  final BetriebLeeren leeren;

  /// Bergkunden-Symbol in der Vorschlagsliste (Eröffnungsreinigung: der
  /// Preis hängt daran).
  final bool bergkundeZeigen;

  const BetriebFeld({
    super.key,
    required this.betriebe,
    required this.betriebId,
    required this.onGewaehlt,
    required this.onGeleert,
    this.onGeaendert,
    this.label = 'Betrieb suchen',
    this.pflichtMeldung,
    this.mitOrt = false,
    this.leerMax = 20,
    this.leeren = BetriebLeeren.knopf,
    this.bergkundeZeigen = false,
  });

  String _anzeige(BetriebLocal b) =>
      mitOrt ? betriebMitOrt(b.name, b.ort) : b.name;

  @override
  Widget build(BuildContext context) {
    final aktuell = betriebId == null
        ? null
        : betriebe
              .where((b) => b.serverId != null && b.serverId == betriebId)
              .firstOrNull;

    return Autocomplete<BetriebLocal>(
      initialValue: aktuell != null
          ? TextEditingValue(text: _anzeige(aktuell))
          : TextEditingValue.empty,
      displayStringForOption: _anzeige,
      optionsBuilder: (textEditingValue) => betriebVorschlaege(
        betriebe,
        textEditingValue.text,
        leerMax: leerMax,
      ),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.store),
            suffixIcon: leeren == BetriebLeeren.knopf && betriebId != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      controller.clear();
                      onGeaendert?.call();
                      onGeleert();
                    },
                  )
                : null,
          ),
          validator: pflichtMeldung == null
              ? null
              : (_) => betriebId == null ? pflichtMeldung : null,
          onChanged: leeren == BetriebLeeren.tippen
              ? (v) {
                  if (v.isEmpty) {
                    onGeaendert?.call();
                    onGeleert();
                  }
                }
              : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final b = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(b.name),
                    subtitle: b.ort != null
                        ? Text(b.ort!, style: const TextStyle(fontSize: 12))
                        : null,
                    trailing: bergkundeZeigen && b.istBergkunde
                        ? const Icon(
                            Icons.terrain,
                            size: 16,
                            color: AppColors.warning,
                          )
                        : null,
                    onTap: () => onSelected(b),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (b) {
        onGeaendert?.call();
        onGewaehlt(b);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz_zeile.dart';

/// Route für einen neuen Einsatz des Typs — optional mit vorbelegtem
/// Betrieb und Anlage (Betriebs-/Anlagenseite, T10). Nicht jedes Formular
/// kennt beide Parameter; überzählige ignoriert der Router.
String einsatzNeuRoute(EinsatzTyp typ, {String? betriebId, String? anlageId}) {
  final basis = switch (typ) {
    EinsatzTyp.reinigung => '/reinigungen/neu',
    EinsatzTyp.stoerung => '/stoerungen/neu',
    EinsatzTyp.montage => '/montagen/neu',
    EinsatzTyp.eigenauftrag => '/eigenauftraege/neu',
    EinsatzTyp.saisonreinigung => '/eroeffnungsreinigungen/neu',
    EinsatzTyp.pikett => '/pikett/neu',
    // Termine entstehen im Tourenplan und per Diktat, nicht hier.
    EinsatzTyp.termin => '/touren',
  };
  if (typ == EinsatzTyp.termin || typ == EinsatzTyp.pikett) return basis;
  final query = [
    if (betriebId != null) 'betriebId=${Uri.encodeQueryComponent(betriebId)}',
    if (anlageId != null) 'anlageId=${Uri.encodeQueryComponent(anlageId)}',
  ];
  return query.isEmpty ? basis : '$basis?${query.join('&')}';
}

/// Typ-Auswahl als Bottom-Sheet aus `GestureDetector` + `Container` — kein
/// `ListTile` (CanvasKit-Regel). [onWahl] läuft NACH dem Schliessen des
/// Sheets; wer navigiert, holt sich den Router vorher (der Sheet-Kontext ist
/// nach `Navigator.pop` nicht mehr gültig, Lehre aus `diktat_sheet.dart`).
void zeigeEinsatzTypWahl(
  BuildContext context, {
  required List<EinsatzTyp> typen,
  required ValueChanged<EinsatzTyp> onWahl,
}) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in typen)
            GestureDetector(
              key: Key('typwahl_${t.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.pop(ctx);
                onWahl(t);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(einsatzTypIcon(t), color: einsatzTypFarbe(t), size: 22),
                    const SizedBox(width: 14),
                    Text(einsatzTypLabel(t), style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

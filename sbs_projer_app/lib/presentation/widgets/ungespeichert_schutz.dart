import 'package:flutter/material.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

/// Fragt nach, bevor ein Formular mit ungespeicherten Änderungen verlassen
/// wird — per Zurück-Geste, Browser-Zurück oder Pfeil in der Titelleiste.
///
/// Bis v0.99.11 hatte kein einziges der 19 Formulare diesen Schutz (Befund 6
/// der App-Analyse vom 08.09.2026): Auf dem Pixel 9 mit Gesten-Navigation
/// reichte ein Wischer am Rand, und eine ganze Reinigung mit Fotos und
/// Positionen war weg — ohne Meldung.
///
/// [geaendert] liefert das Formular (siehe [UngespeichertMixin]); [was] steht
/// im Dialogtext, z. B. «Die Reinigung».
class UngespeichertSchutz extends StatelessWidget {
  final bool geaendert;
  final String was;
  final Widget child;

  const UngespeichertSchutz({
    super.key,
    required this.geaendert,
    required this.was,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !geaendert,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final verwerfen = await verwerfenFragen(context, was: was);
        // Navigator.pop statt maybePop: der Schutz selbst darf jetzt nicht
        // ein zweites Mal fragen.
        if (verwerfen && context.mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }
}

/// Die Rückfrage — mit [TapKnopf] statt Material-Buttons, weil
/// FilledButton/OutlinedButton auf CanvasKit zweimal nicht reagierten
/// (CLAUDE.md). «Weiter bearbeiten» ist der sichere Weg und darum der
/// hervorgehobene und obere.
///
/// Die Knöpfe stehen untereinander, nicht nebeneinander: Auf 360 px —
/// Daniels Pixel 9 — lief die Zeile um 42 px über und schnitt ausgerechnet
/// den rettenden Knopf an. Untereinander sind sie ausserdem einhändig
/// sicherer zu treffen.
Future<bool> verwerfenFragen(
  BuildContext context, {
  required String was,
}) async {
  final antwort = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Änderungen verwerfen?'),
      content: Text('$was wurde geändert, aber nicht gespeichert.'),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TapKnopf(
              text: 'Weiter bearbeiten',
              onTap: () => Navigator.pop(ctx, false),
            ),
            const SizedBox(height: 8),
            TapKnopf(
              text: 'Verwerfen',
              primaer: false,
              onTap: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ],
    ),
  );
  return antwort ?? false;
}

/// Hält den Änderungsstand eines Formulars.
///
/// `Form(onChanged: markiereGeaendert)` deckt alle FormFields ab — jedes
/// TextFormField, jedes DropdownButtonFormField. Schalter, Kontrollkästchen,
/// Datums-/Zeitwahl, Fotos und Listen-Einträge rufen [markiereGeaendert]
/// selbst, dort wo ihr setState steht.
///
/// Vor dem Verlassen nach erfolgreichem Speichern [geaendertZuruecksetzen]
/// aufrufen — sonst fragt der Schutz auch beim programmatischen pop nach.
///
/// Falle: Wird ein bestehender Datensatz erst NACH dem ersten Frame in die
/// Controller geladen, meldet TextFormField das als Änderung und das
/// Formular gilt als geändert, ohne dass jemand getippt hat. Nach so einem
/// Befüllen im nächsten Frame [geaendertZuruecksetzen] aufrufen.
mixin UngespeichertMixin<T extends StatefulWidget> on State<T> {
  bool _geaendert = false;

  bool get geaendert => _geaendert;

  void markiereGeaendert() {
    if (_geaendert || !mounted) return;
    setState(() => _geaendert = true);
  }

  void geaendertZuruecksetzen() {
    if (!_geaendert) return;
    if (mounted) {
      setState(() => _geaendert = false);
    } else {
      _geaendert = false;
    }
  }
}

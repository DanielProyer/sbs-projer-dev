import 'dart:typed_data';

import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/jahresabschluss_schritte.dart';
import 'package:sbs_projer_app/core/util/jahresrechnung_kennzahlen.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/data/repositories/steuerjahr_repository.dart';

typedef JahresrechnungHochladen =
    Future<void> Function({
      required int jahr,
      required String titel,
      required String dateiname,
      required double betrag,
      required Uint8List bytes,
    });

/// [abgelegt]: liegt die Fassung im Dossier? [meldung]: was Daniel sehen
/// soll — Ablage, Steuerjahr, Abweichungen, Fehler in einem Satz.
typedef AblageErgebnis = ({bool abgelegt, String meldung});

/// Jahresrechnung erzeugen, ins Steuer-Dossier legen und das Steuerjahr
/// abgleichen.
///
/// WARUM eine eigene Klasse mit austauschbaren Abhängigkeiten: Im Screen
/// liess sich die Kette (Upload-Fehler → Meldung, Vorbefüllung nur leerer
/// Felder) nicht testen, weil Upload und Steuerjahr direkt an Supabase
/// hängen (Review 29.09.2026). Die Tests setzen hier Attrappen ein.
class JahresrechnungAblage {
  final JahresrechnungHochladen hochladen;
  final Future<List<Steuerjahr>> Function() steuerjahreLaden;
  final Future<void> Function(Steuerjahr) steuerjahrSpeichern;

  const JahresrechnungAblage({
    required this.hochladen,
    required this.steuerjahreLaden,
    required this.steuerjahrSpeichern,
  });

  /// Dossier (`dokumente`, Bereich `steuern`, Typ `jahresrechnung`) und
  /// `steuerjahre` in Supabase.
  factory JahresrechnungAblage.supabase() => JahresrechnungAblage(
    hochladen:
        ({
          required int jahr,
          required String titel,
          required String dateiname,
          required double betrag,
          required Uint8List bytes,
        }) async {
          await DokumentRepository.upload(
            bereich: 'steuern',
            typ: 'jahresrechnung',
            jahr: jahr,
            dokumentDatum: DateTime(jahr, 12, 31),
            // Der Gewinn der Fassung — Schritt 5 erkennt daran, ob sie nach
            // späteren Buchungen noch stimmt (W1).
            betrag: betrag,
            titel: titel,
            dateiname: dateiname,
            dateityp: 'application/pdf',
            bytes: bytes,
          );
        },
    steuerjahreLaden: SteuerjahrRepository.getAll,
    steuerjahrSpeichern: SteuerjahrRepository.upsert,
  );

  Future<AblageErgebnis> ablegen({
    required JahresrechnungKennzahlen k,
    required int fassung,
    required Future<Uint8List> Function() pdf,
  }) async {
    try {
      final bytes = await pdf();
      await hochladen(
        jahr: k.jahr,
        titel: jahresrechnungTitel(k, fassung: fassung),
        dateiname: jahresrechnungDateiname(k.jahr, fassung: fassung),
        betrag: k.gewinn,
        bytes: bytes,
      );
    } catch (e) {
      return (
        abgelegt: false,
        meldung: 'Jahresrechnung nicht abgelegt: ${kurzeFehlermeldung(e)}',
      );
    }

    final teile = [
      'Jahresrechnung ${k.jahr}${fassung > 1 ? ' (Fassung $fassung)' : ''} '
          'im Dossier abgelegt',
    ];
    // Steuerjahr frisch lesen, nicht aus der Lage: Wurde es inzwischen
    // bearbeitet, überschriebe der alte Stand sonst die neuen Felder.
    try {
      final alle = await steuerjahreLaden();
      final alt = alle.where((s) => s.jahr == k.jahr).firstOrNull;
      final abgleich = steuerjahrAbgleich(alt, k);
      final neu = abgleich.neu;
      if (neu != null) {
        await steuerjahrSpeichern(neu);
        final gefuellt = [
          if (alt?.steuerbarerGewinn == null) 'steuerbarer Gewinn',
          if (alt?.steuerbaresKapital == null) 'Kapital',
        ];
        teile.add('${gefuellt.join(' und ')} im Steuerjahr eingetragen');
      }
      final hinweis = steuerjahrHinweis(abgleich.abweichungen);
      if (hinweis != null) teile.add(hinweis);
    } catch (e) {
      teile.add('Steuerjahr nicht vorbefüllt: ${kurzeFehlermeldung(e)}');
    }
    return (abgelegt: true, meldung: teile.join(' — '));
  }
}

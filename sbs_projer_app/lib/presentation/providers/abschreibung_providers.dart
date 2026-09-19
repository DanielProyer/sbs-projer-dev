import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/abschreibung_lauf.dart';
import 'package:sbs_projer_app/data/repositories/abschreibung_lauf_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/jahrgang_abschreibung.dart';

/// Alle Abschreibungsläufe (wenige Zeilen, eine je Geschäftsjahr).
final abschreibungLaeufeProvider =
    FutureProvider.autoDispose<List<AbschreibungLauf>>(
      (ref) => AbschreibungLaufRepository.getAll(),
    );

/// Vorschau des Schritts «Jahrgang abschreiben» für ein Geschäftsjahr.
final jahrgangAbschreibVorschauProvider = FutureProvider.autoDispose
    .family<AbschreibVorschau, int>((ref, jahr) async {
      final (offene, betriebe) = await (
        RechnungRepository.getOffene(),
        BetriebRepository.getAll(),
      ).wait;
      final namen = {
        for (final b in betriebe)
          if (b.serverId != null) b.serverId!: b.name,
      };
      return AbschreibVorschau.aus(
        auswahlFuer(offene, geschaeftsjahr: jahr, betriebNamen: namen),
      );
    });

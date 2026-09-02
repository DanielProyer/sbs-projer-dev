import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/data/repositories/steuerjahr_repository.dart';
import 'package:sbs_projer_app/data/repositories/steuerzahlung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart'
    show toSaldoInput;
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/dokument_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart'
    show BuchungSaldo;
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart';

/// Eine Zeile der Steuern-Übersicht.
class SteuerjahrZeile {
  final Steuerjahr jahr;
  final SollIst sollIst;
  final double buchhaltungsgewinn;
  final Dossier dossier;
  const SteuerjahrZeile({
    required this.jahr,
    required this.sollIst,
    required this.buchhaltungsgewinn,
    required this.dossier,
  });
}

final steuerjahreProvider = FutureProvider<List<Steuerjahr>>(
  (ref) => SteuerjahrRepository.getAll(),
);

/// Übersicht: Vereinigung aus steuerjahre, zugeordneten Zahlungen und
/// Dokumenten — ein Jahr erscheint auch dann, wenn nur Zahlungen oder nur
/// Dokumente dazu existieren.
final steuernUebersichtProvider = FutureProvider<List<SteuerjahrZeile>>((
  ref,
) async {
  final jahre = await ref.watch(steuerjahreProvider.future);
  final bezahlt = await SteuerzahlungRepository.bezahltJeJahr();
  final docs = await DokumentRepository.getAll(bereich: 'steuern');
  // Journal über den Stream: rechnet nach camt-Import/Lohnlauf neu und spart
  // den zweiten Download (gleiches Muster wie bankWaechterProvider).
  final buchungen = await ref.watch(buchungenStreamProvider.future);
  final jeJahr = gruppiereNachJahr(toSaldoInput(buchungen));
  final heute = DateTime.now();

  final alleJahre = <int>{
    ...jahre.map((j) => j.jahr),
    ...bezahlt.keys.map((k) => k.$1),
    ...docs.map((d) => d.jahr).whereType<int>(),
  };
  final zeilen = <SteuerjahrZeile>[];
  for (final j in alleJahre.toList()..sort((a, b) => b.compareTo(a))) {
    final sj = jahre.firstWhere(
      (x) => x.jahr == j,
      orElse: () => Steuerjahr(jahr: j),
    );
    final bez = {
      for (final e in bezahlt.entries)
        if (e.key.$1 == j) e.key.$2: e.value,
    };
    zeilen.add(
      SteuerjahrZeile(
        jahr: sj,
        sollIst: SteuerjahrRechner.sollIst(jahr: sj, bezahlt: bez),
        buchhaltungsgewinn: _gewinn(jeJahr, j),
        dossier: SteuerjahrRechner.dossier(
          jahr: j,
          heute: heute,
          vorhanden: docs
              .where((d) => d.jahr == j)
              .map((d) => (d.typ, d.kategorie))
              .toList(),
        ),
      ),
    );
  }
  return zeilen;
});

/// Jahresergebnis eines Jahres aus den vorgruppierten Saldo-Zeilen.
double _gewinn(Map<int, List<BuchungSaldo>> jeJahr, int jahr) =>
    ErfolgsrechnungService.berechne(
      jeJahr[jahr] ?? const [],
      von: DateTime(jahr, 1, 1),
      bis: DateTime(jahr, 12, 31),
    ).jahresergebnis;

final steuerjahrZeileProvider = FutureProvider.family<SteuerjahrZeile, int>((
  ref,
  jahr,
) async {
  final alle = await ref.watch(steuernUebersichtProvider.future);
  for (final z in alle) {
    if (z.jahr.jahr == jahr) return z;
  }
  // Jahr ohne Steuerjahr-Satz, Zahlungen und Dokumente: leeres Soll und
  // leeres Dossier, den Buchhaltungsgewinn aber trotzdem echt rechnen —
  // eine 0 wäre eine Falschaussage über die Erfolgsrechnung.
  final buchungen = await ref.watch(buchungenStreamProvider.future);
  final jeJahr = gruppiereNachJahr(toSaldoInput(buchungen));
  final leer = Steuerjahr(jahr: jahr);
  return SteuerjahrZeile(
    jahr: leer,
    sollIst: SteuerjahrRechner.sollIst(jahr: leer, bezahlt: const {}),
    buchhaltungsgewinn: _gewinn(jeJahr, jahr),
    dossier: SteuerjahrRechner.dossier(
      jahr: jahr,
      heute: DateTime.now(),
      vorhanden: const [],
    ),
  );
});

final steuerzahlungenProvider = FutureProvider.family<List<Buchung>, int>((
  ref,
  jahr,
) {
  ref.watch(buchungenStreamProvider);
  return SteuerzahlungRepository.getByJahr(jahr);
});

final nichtZugeordneteSteuerbuchungenProvider = FutureProvider<List<Buchung>>((
  ref,
) {
  ref.watch(buchungenStreamProvider);
  return SteuerzahlungRepository.getNichtZugeordnet();
});

final steuerDokumenteProvider = FutureProvider.family<List<Dokument>, int>(
  (ref, jahr) => DokumentRepository.getAll(bereich: 'steuern', jahr: jahr),
);

/// Nach jeder Änderung im Steuern-Bereich alles neu laden.
void invalidateSteuern(WidgetRef ref) {
  ref.invalidate(steuerjahreProvider);
  ref.invalidate(steuernUebersichtProvider);
  ref.invalidate(steuerzahlungenProvider);
  ref.invalidate(nichtZugeordneteSteuerbuchungenProvider);
  ref.invalidate(steuerDokumenteProvider);
  // Der Dokument-Cache hängt an denselben Uploads/Löschungen.
  ref.invalidate(dokumenteProvider);
  ref.invalidate(dokumentJahreProvider);
}

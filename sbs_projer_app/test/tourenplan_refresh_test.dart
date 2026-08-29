import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/tourenplan_refresh.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';

void main() {
  test('tourenplanNeuLaden lädt alle Datenquellen des Tourenplans neu',
      () async {
    final laeufe = <String, int>{};
    void zaehle(String name) => laeufe[name] = (laeufe[name] ?? 0) + 1;

    final container = ProviderContainer(overrides: [
      betriebeStreamProvider.overrideWith((ref) {
        zaehle('betriebe');
        return Stream.value(const []);
      }),
      ferienPeriodenProvider.overrideWith((ref) async {
        zaehle('ferien');
        return const {};
      }),
      anlagenStreamProvider.overrideWith((ref) {
        zaehle('anlagen');
        return Stream.value(const []);
      }),
      reinigungenStreamProvider.overrideWith((ref) {
        zaehle('reinigungen');
        return Stream.value(const []);
      }),
      stoerungenStreamProvider.overrideWith((ref) {
        zaehle('stoerungen');
        return Stream.value(const []);
      }),
      montagenStreamProvider.overrideWith((ref) {
        zaehle('montagen');
        return Stream.value(const []);
      }),
    ]);
    addTearDown(container.dispose);

    // Erstbezug — entspricht dem App-Start.
    await tourenplanNeuLaden(container);
    expect(laeufe.values, everyElement(1),
        reason: 'Jede Quelle genau einmal geladen');

    // Refresh: JEDE Quelle muss neu laden — eine vergessene Quelle hiesse
    // z.B. frische Anlagen, aber veraltete Reinigungen.
    await tourenplanNeuLaden(container);
    expect(laeufe, {
      'betriebe': 2,
      'ferien': 2,
      'anlagen': 2,
      'reinigungen': 2,
      'stoerungen': 2,
      'montagen': 2,
    });
  });
}

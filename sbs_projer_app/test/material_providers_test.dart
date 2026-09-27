import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';

/// Nach Bestand ± auf der Material-Karte wird `materialienStreamProvider`
/// invalidiert. Lieferte `materialienProvider` währenddessen kurz `[]`,
/// bekäme der PageView itemCount 0 — die Position wäre weg und man stünde
/// nach jedem Tipp wieder auf der ersten Karte.
void main() {
  final liste = [
    Lager(id: 'a', userId: 'u', name: 'Zapfhahn'),
    Lager(id: 'b', userId: 'u', name: 'Dichtung'),
  ];

  test('Liste bleibt während des Neuladens stehen', () async {
    final container = ProviderContainer(
      overrides: [
        materialienStreamProvider.overrideWith((ref) => Stream.value(liste)),
      ],
    );
    addTearDown(container.dispose);

    // Abonnieren wie der Screen (ref.watch), damit der Provider lebt.
    container.listen(materialienProvider, (_, _) {});
    await container.read(materialienStreamProvider.future);
    expect(container.read(materialienProvider), liste);

    container.invalidate(materialienStreamProvider);
    // Sofort, noch bevor der neue Stream geliefert hat.
    expect(container.read(materialienStreamProvider).isLoading, isTrue);
    expect(container.read(materialienProvider), liste);

    await container.read(materialienStreamProvider.future);
    expect(container.read(materialienProvider), liste);
  });

  test('vor dem ersten Laden: leere Liste', () {
    final container = ProviderContainer(
      overrides: [
        materialienStreamProvider.overrideWith(
          (ref) => const Stream<List<Lager>>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(materialienProvider), isEmpty);
  });
}

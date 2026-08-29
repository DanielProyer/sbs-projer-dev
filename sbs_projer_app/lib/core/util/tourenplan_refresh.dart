import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';

/// Lädt alle Datenquellen des Tourenplans neu und wartet, bis sie da sind.
///
/// Hintergrund (Fall Bernina Bar/Viktoria, 29.08.2026): Auf Web laden die
/// Repositories ihre Daten EINMAL beim App-Start (`Stream.fromFuture`) — ein
/// Browser-Tab, der über Tage offen bleibt, zeigt sonst den Stand vom Start
/// und meldet längst gereinigte Anlagen weiter als überfällig. Der Tourenplan
/// bietet deshalb Pull-to-Refresh (Handy) und einen Aktualisieren-Knopf in
/// der AppBar (PC ohne Zieh-Geste); beide laufen über diese Funktion.
/// Auf Nativ liest das Neuladen nur die lokale Isar-Kopie neu — harmlos;
/// der Server-Abgleich bleibt Sache des Sync.
Future<void> tourenplanNeuLaden(ProviderContainer container) async {
  container.invalidate(betriebeStreamProvider);
  container.invalidate(ferienPeriodenProvider);
  container.invalidate(anlagenStreamProvider);
  container.invalidate(reinigungenStreamProvider);
  container.invalidate(stoerungenStreamProvider);
  container.invalidate(montagenStreamProvider);
  await Future.wait([
    container.read(betriebeStreamProvider.future),
    container.read(ferienPeriodenProvider.future),
    container.read(anlagenStreamProvider.future),
    container.read(reinigungenStreamProvider.future),
    container.read(stoerungenStreamProvider.future),
    container.read(montagenStreamProvider.future),
  ]);
}

import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Rangfolge von schlimm (0) nach unkritisch (hoch).
const _rang = <FaelligkeitsStatus, int>{
  FaelligkeitsStatus.ueberfaellig: 0,
  FaelligkeitsStatus.faellig: 1,
  FaelligkeitsStatus.baldFaellig: 2,
  FaelligkeitsStatus.endreinigungFaellig: 3,
  FaelligkeitsStatus.eroeffnungFaellig: 4,
  FaelligkeitsStatus.nichtFaellig: 5,
};

/// Betrieb-Fälligkeit = schlimmster Status seiner Anlagen.
/// Leere Liste -> [FaelligkeitsStatus.nichtFaellig].
FaelligkeitsStatus betriebFaelligkeit(List<FaelligkeitsStatus> anlagenStatus) {
  if (anlagenStatus.isEmpty) return FaelligkeitsStatus.nichtFaellig;
  return anlagenStatus.reduce(
    (a, b) => (_rang[a] ?? 5) <= (_rang[b] ?? 5) ? a : b,
  );
}

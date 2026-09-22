import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/camt_abgleich_providers.dart';

/// Wochen-Erinnerung: Ist der letzte erfasste Auszug älter als 7 Tage,
/// einen neuen hochladen. Bis v0.130.0 in der Buchhaltung.
class CamtErinnerungKarte extends ConsumerWidget {
  const CamtErinnerungKarte({super.key});

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final letzte = ref.watch(letzteCamtPeriodeProvider).valueOrNull;
    final faellig =
        letzte == null || DateTime.now().difference(letzte).inDays > 7;
    if (!faellig) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => context.push('/buchhaltung/camt-import'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warning.withAlpha(60)),
        ),
        child: Row(
          children: [
            const Icon(Icons.upload_file, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                letzte == null
                    ? 'Noch kein Bankauszug erfasst — camt-Datei hochladen'
                    : 'Letzter Auszug bis ${_fmt(letzte)} — neuen camt-Auszug hochladen',
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

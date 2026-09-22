import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';

/// Bank-Wächter: Journal gegen letzten Bank-Schlusssaldo, dazu «Tilgung
/// ohne Aufbau» auf Verbindlichkeitskonten. Bis v0.130.0 in der
/// Buchhaltung, seit v0.131.0 auf der Seite «Bank und Zahlungen» — dort,
/// wo man den Auszug importiert, der den Befund auflöst.
class BankWaechterKarte extends StatelessWidget {
  final AsyncValue<BankWaechterStand> stand;
  const BankWaechterKarte({super.key, required this.stand});

  @override
  Widget build(BuildContext context) {
    final s = stand.valueOrNull;
    if (s == null) return const SizedBox.shrink(); // lädt/Fehler: nichts zeigen
    final ok = s.allesImLot;
    final farbe = ok ? AppColors.success : AppColors.error;
    String datum(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: farbe.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: farbe.withAlpha(110)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.verified : Icons.warning_amber,
                size: 18,
                color: farbe,
              ),
              const SizedBox(width: 8),
              Text(
                'Bank-Wächter',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: farbe,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (s.schluss != null)
            Text(
              '${s.schluss!.ok ? '✓' : '⚠'} ${s.schluss!.text}'
              '${s.per != null ? ' (per ${datum(s.per!)})' : ''}',
              style: const TextStyle(fontSize: 12.5),
            ),
          if (s.verbindlichkeiten.isEmpty && s.schluss != null)
            const Text(
              '✓ Keine Verbindlichkeit im Soll.',
              style: TextStyle(fontSize: 12.5),
            ),
          for (final w in s.verbindlichkeiten)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '⚠ $w',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // Weiter zur vollen Abschlussprüfung (14 Regeln) fürs laufende Jahr.
          // Mindesthöhe 44 px — einhändig am Handy ist eine 20-px-Zeile nicht
          // zuverlässig zu treffen.
          InkWell(
            onTap: () =>
                context.push('/buchhaltung/audit?jahr=${DateTime.now().year}'),
            child: Container(
              // volle Breite, damit «rechtsbündig» in der Column auch greift
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: const Text(
                'Details →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/suche.dart';

/// Eine Zeile der Suchseite. CanvasKit: InkWell + Container + Row, kein
/// ListTile (CLAUDE.md) — die Suche ist eine Weiche, ein nicht rendernder
/// Treffer fiele erst auf, wenn man ihn braucht.
class SuchTrefferZeile extends StatelessWidget {
  final SuchTreffer treffer;
  final String suchtext;
  final VoidCallback onTap;

  /// Nur Personen mit Telefon.
  final VoidCallback? onAnruf;

  const SuchTrefferZeile({
    super.key,
    required this.treffer,
    required this.suchtext,
    required this.onTap,
    this.onAnruf,
  });

  static IconData _icon(SuchGruppe g) => switch (g) {
        SuchGruppe.betriebe => Icons.store,
        SuchGruppe.personen => Icons.person,
        SuchGruppe.rechnungen => Icons.request_quote,
        SuchGruppe.bereiche => Icons.apps,
      };

  Color? _statusFarbe() => switch (treffer.status) {
        null => null,
        'aktiv' => AppColors.aktiv,
        'saisonpause' => AppColors.warning,
        'geschlossen' => AppColors.geschlossen,
        _ => AppColors.inaktiv,
      };

  @override
  Widget build(BuildContext context) {
    final farbe = _statusFarbe();
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Icon(_icon(treffer.gruppe), size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        for (final (teil, fett) in markiere(treffer.titel, suchtext))
                          TextSpan(
                            text: teil,
                            style: TextStyle(
                              fontWeight:
                                  fett ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (treffer.untertitel != null &&
                      treffer.untertitel!.isNotEmpty)
                    Text(
                      treffer.untertitel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (farbe != null)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(color: farbe, shape: BoxShape.circle),
              ),
            if (onAnruf != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAnruf,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.phone, size: 20, color: AppColors.primary),
                ),
              )
            else
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

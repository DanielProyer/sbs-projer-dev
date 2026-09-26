import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_akte_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/detail/detail_karte.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz_typ_wahl.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz_zeile.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Wie viele Einsätze die Akte zeigt, bevor sie auf den Einsätze-Screen
/// verweist.
const kAkteZeilen = 10;

/// Eine Sektion «Einsätze» für die Betriebsseite (und, mit [anlageId], die
/// Anlagenseite): alle Typen, neueste zuerst — ersetzt die drei getrennten
/// Listen Reinigungen/Störungen/Eigenaufträge, in denen Montagen fehlten
/// (T10).
class EinsaetzeAkteKarte extends ConsumerWidget {
  final String betriebId;
  final String? anlageId;
  const EinsaetzeAkteKarte({super.key, required this.betriebId, this.anlageId});

  AkteSchluessel get _schluessel => (betriebId: betriebId, anlageId: anlageId);

  /// Auf der Anlagenseite nur, was an einer Anlage hängt; ein Eigenauftrag
  /// wird am Betrieb erfasst.
  List<EinsatzTyp> get _neueTypen => [
    EinsatzTyp.reinigung,
    EinsatzTyp.stoerung,
    EinsatzTyp.montage,
    if (anlageId == null) EinsatzTyp.eigenauftrag,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final einsaetze = ref.watch(betriebEinsaetzeProvider(_schluessel));
    final router = GoRouter.of(context);

    // Nach der Rückkehr neu laden — die Seite bleibt beim Öffnen eines
    // Einsatzes stehen, der Provider damit am Leben.
    Future<void> oeffne(String route) async {
      await router.push(route);
      ref.invalidate(betriebEinsaetzeProvider(_schluessel));
    }

    return EinsaetzeAkteInhalt(
      einsaetze: einsaetze,
      onOeffnen: (e) => oeffne(e.detailRoute),
      onAlle: () => router.push('/einsaetze?betrieb=$betriebId'),
      onNeu: _istGast()
          ? null
          : () => zeigeEinsatzTypWahl(
              context,
              typen: _neueTypen,
              onWahl: (t) => oeffne(
                einsatzNeuRoute(t, betriebId: betriebId, anlageId: anlageId),
              ),
            ),
    );
  }
}

bool _istGast() {
  try {
    return SupabaseService.isGuest;
  } catch (_) {
    return false;
  }
}

/// Darstellung ohne Datenanbindung — testbar ohne Provider.
class EinsaetzeAkteInhalt extends StatelessWidget {
  final AsyncValue<List<Einsatz>> einsaetze;
  final ValueChanged<Einsatz> onOeffnen;
  final VoidCallback onAlle;

  /// `null` = kein «+» (Gast).
  final VoidCallback? onNeu;

  const EinsaetzeAkteInhalt({
    super.key,
    required this.einsaetze,
    required this.onOeffnen,
    required this.onAlle,
    this.onNeu,
  });

  @override
  Widget build(BuildContext context) {
    final alle = einsaetze.valueOrNull;
    return DetailKarte(
      titel: alle == null ? 'Einsätze' : 'Einsätze (${alle.length})',
      icon: Icons.work_history_outlined,
      aktion: onNeu == null
          ? null
          : InkWell(
              key: const Key('akte_neu'),
              onTap: onNeu,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Neu',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      kinder: einsaetze.when(
        loading: () => const [_Hinweis('Wird geladen …')],
        error: (e, _) => [_Hinweis('Einsätze nicht geladen: $e', rot: true)],
        data: (liste) => [
          if (liste.isEmpty) const _Hinweis('Noch keine Einsätze erfasst'),
          for (final e in liste.take(kAkteZeilen))
            EinsatzZeile(einsatz: e, onTap: () => onOeffnen(e), imBetrieb: true),
          if (liste.isNotEmpty)
            InkWell(
              key: const Key('akte_alle'),
              onTap: onAlle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Row(
                  children: [
                    Text(
                      liste.length > kAkteZeilen
                          ? 'Alle ${liste.length} anzeigen'
                          : 'Alle anzeigen',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Hinweis extends StatelessWidget {
  final String text;
  final bool rot;
  const _Hinweis(this.text, {this.rot = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: TextStyle(
        color: rot ? AppColors.error : AppColors.textSecondary,
        fontSize: 13,
      ),
    ),
  );
}

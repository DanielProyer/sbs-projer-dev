import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/bereich_zaehler_provider.dart';
import 'package:sbs_projer_app/presentation/widgets/bereich_gruppen_liste.dart';

/// Eine Bereichsseite: Titel, optionale Karten oben, dann die Gruppen.
///
/// `push` statt `go`: Aus dem Bereich geöffnete Screens führen mit «zurück»
/// wieder hierher.
class BereichScreen extends ConsumerWidget {
  final Bereich bereich;
  final List<Widget> kopf;

  const BereichScreen({super.key, required this.bereich, this.kopf = const []});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zaehler = ref.watch(bereichZaehlerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(bereich.titel)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          ...kopf,
          // Nur auf Mehr: Sieht aus wie ein Suchfeld, ist aber ein Tipp-Ziel.
          // Die Suche selbst gibt es nur einmal, auf /suche — so scrollt Mehr
          // nicht plötzlich Treffer.
          if (bereich.id == 'mehr')
            GestureDetector(
              onTap: () => context.push('/suche'),
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Betrieb, Person, Rechnung, Bereich …',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          BereichGruppenListe(
            gruppen: bereich.gruppen,
            zaehler: zaehler,
            onTap: (ziel) => context.push(ziel),
          ),
        ],
      ),
    );
  }
}

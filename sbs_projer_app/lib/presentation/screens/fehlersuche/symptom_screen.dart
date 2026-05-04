import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/fehlersuche/fehlersuche_data.dart';
import 'package:sbs_projer_app/presentation/widgets/system_diagram/david_diagram.dart';
import 'package:sbs_projer_app/presentation/widgets/system_diagram/konventionell_diagram.dart';
import 'package:sbs_projer_app/presentation/widgets/system_diagram/orion_diagram.dart';
import 'package:sbs_projer_app/presentation/widgets/system_diagram/heigenie_diagram.dart';

class SymptomScreen extends StatelessWidget {
  final String systemId;

  const SymptomScreen({super.key, required this.systemId});

  @override
  Widget build(BuildContext context) {
    final system = getSystemById(systemId);

    if (system == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fehlersuche')),
        body: const Center(child: Text('System nicht gefunden')),
      );
    }

    final hasSymptome =
        system.symptome.isNotEmpty && system.symptome.first.id != 'platzhalter';

    return Scaffold(
      appBar: AppBar(title: Text(system.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // System-Diagramm
          _buildDiagram(systemId),
          const SizedBox(height: 20),

          // System-Beschreibung
          Text(
            system.beschreibung,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            hasSymptome ? 'Was ist das Problem?' : 'Symptome',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),

          if (!hasSymptome)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.hourglass_empty,
                        size: 48, color: AppColors.warning.withAlpha(150)),
                    const SizedBox(height: 12),
                    const Text(
                      'Entscheidungsbaum wird noch erfasst',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Die Symptome und Ursachen für dieses System werden noch ergänzt.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (hasSymptome)
            ...system.symptome.map(
              (symptom) => _SymptomCard(
                symptom: symptom,
                onTap: () => context.push(
                    '/fehlersuche/$systemId/${symptom.id}'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiagram(String id) {
    switch (id) {
      case 'david':
        return const DavidDiagram();
      case 'konventionell':
        return const KonventionellDiagram();
      case 'orion':
        return const OrionDiagram();
      case 'heigenie':
        return const HeigenieDiagram();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SymptomCard extends StatelessWidget {
  final dynamic symptom;
  final VoidCallback onTap;

  const _SymptomCard({required this.symptom, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(symptom.icon, color: AppColors.warning, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      symptom.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (symptom.beschreibung != null)
                      Text(
                        symptom.beschreibung!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      '${symptom.ursachen.length} mögliche Ursachen',
                      style: const TextStyle(
                        color: AppColors.info,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

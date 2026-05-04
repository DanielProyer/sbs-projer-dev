import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/fehlersuche/fehlersuche_data.dart';
import 'package:sbs_projer_app/data/models/fehlersuche.dart';

class FehlerSucheScreen extends StatelessWidget {
  const FehlerSucheScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final systems = getAllSystems();

    return Scaffold(
      appBar: AppBar(title: const Text('Fehlersuche')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'System auswählen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Wähle das Zapfsystem, bei dem das Problem auftritt.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...systems.map((system) => _SystemCard(system: system)),
        ],
      ),
    );
  }
}

class _SystemCard extends StatelessWidget {
  final TsSystem system;

  const _SystemCard({required this.system});

  IconData _iconForSystem(String id) {
    switch (id) {
      case 'david':
        return Icons.local_drink;
      case 'konventionell':
        return Icons.kitchen;
      case 'orion':
        return Icons.storage;
      case 'heigenie':
        return Icons.science;
      default:
        return Icons.settings;
    }
  }

  Color _colorForSystem(String id) {
    switch (id) {
      case 'david':
        return AppColors.primary;
      case 'konventionell':
        return AppColors.info;
      case 'orion':
        return AppColors.warning;
      case 'heigenie':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForSystem(system.id);
    final hasSymptome = system.symptome.isNotEmpty &&
        system.symptome.first.id != 'platzhalter';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/fehlersuche/${system.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconForSystem(system.id), color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          system.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (!hasSymptome) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Daten folgen',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      system.beschreibung,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (hasSymptome)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${system.symptome.length} Symptome',
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
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

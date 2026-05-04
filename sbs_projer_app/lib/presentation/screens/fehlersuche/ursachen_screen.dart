import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/fehlersuche/fehlersuche_data.dart';
import 'package:sbs_projer_app/data/models/fehlersuche.dart';
import 'package:sbs_projer_app/presentation/widgets/system_diagram/david_diagram.dart';
import 'package:sbs_projer_app/presentation/widgets/system_diagram/konventionell_diagram.dart';
import 'package:sbs_projer_app/presentation/widgets/system_diagram/orion_diagram.dart';
import 'package:sbs_projer_app/presentation/widgets/system_diagram/heigenie_diagram.dart';

class UrsachenScreen extends StatefulWidget {
  final String systemId;
  final String symptomId;

  const UrsachenScreen({
    super.key,
    required this.systemId,
    required this.symptomId,
  });

  @override
  State<UrsachenScreen> createState() => _UrsachenScreenState();
}

class _UrsachenScreenState extends State<UrsachenScreen> {
  int? _selectedUrsacheIndex;

  @override
  Widget build(BuildContext context) {
    final system = getSystemById(widget.systemId);
    if (system == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fehlersuche')),
        body: const Center(child: Text('System nicht gefunden')),
      );
    }

    TsSymptom? symptom;
    try {
      symptom = system.symptome.firstWhere((s) => s.id == widget.symptomId);
    } catch (_) {
      return Scaffold(
        appBar: AppBar(title: Text(system.name)),
        body: const Center(child: Text('Symptom nicht gefunden')),
      );
    }

    // Highlight-Komponenten basierend auf ausgewählter Ursache
    final highlightIds = _selectedUrsacheIndex != null &&
            _selectedUrsacheIndex! < symptom.ursachen.length
        ? symptom.ursachen[_selectedUrsacheIndex!].komponentenIds
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(symptom.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // System-Diagramm mit Highlight
          _buildDiagram(widget.systemId, highlightIds),
          const SizedBox(height: 8),
          if (highlightIds.isNotEmpty)
            Text(
              'Rot markiert: betroffene Bauteile',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 16),

          Text(
            'Mögliche Ursachen prüfen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tippe auf eine Ursache, um die betroffenen Bauteile im Diagramm zu sehen.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),

          ...List.generate(symptom.ursachen.length, (index) {
            final ursache = symptom!.ursachen[index];
            final isSelected = _selectedUrsacheIndex == index;
            return _UrsacheCard(
              index: index + 1,
              ursache: ursache,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _selectedUrsacheIndex =
                      _selectedUrsacheIndex == index ? null : index;
                });
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDiagram(String id, List<String> highlights) {
    switch (id) {
      case 'david':
        return DavidDiagram(highlightKomponenten: highlights);
      case 'konventionell':
        return KonventionellDiagram(highlightKomponenten: highlights);
      case 'orion':
        return OrionDiagram(highlightKomponenten: highlights);
      case 'heigenie':
        return HeigenieDiagram(highlightKomponenten: highlights);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _UrsacheCard extends StatelessWidget {
  final int index;
  final TsUrsache ursache;
  final bool isSelected;
  final VoidCallback onTap;

  const _UrsacheCard({
    required this.index,
    required this.ursache,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.orange.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.warning : AppColors.divider,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Nummer + Name + Badge
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.warning
                          : AppColors.textSecondary.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$index',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ursache.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (ursache.kundeKannSelbst == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person, size: 12, color: AppColors.success),
                          SizedBox(width: 3),
                          Text(
                            'Kunde',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Icon(
                    isSelected
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),

              // Expandierter Inhalt
              if (isSelected) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Check-Anleitung
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.search, size: 18, color: AppColors.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prüfen',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ursache.checkAnleitung,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (ursache.loesung != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.build, size: 18, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lösung',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ursache.loesung!,
                              style:
                                  const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

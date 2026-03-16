import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/models/rechnungs_position.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_service.dart';

class RechnungDetailScreen extends ConsumerWidget {
  final String rechnungId;

  const RechnungDetailScreen({super.key, required this.rechnungId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Rechnung?>(
      future: RechnungRepository.getById(rechnungId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final rechnung = snapshot.data;
        if (rechnung == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nicht gefunden')),
            body: const Center(child: Text('Rechnung nicht gefunden')),
          );
        }

        return _RechnungDetailContent(rechnung: rechnung);
      },
    );
  }
}

class _RechnungDetailContent extends ConsumerStatefulWidget {
  final Rechnung rechnung;

  const _RechnungDetailContent({required this.rechnung});

  @override
  ConsumerState<_RechnungDetailContent> createState() =>
      _RechnungDetailContentState();
}

class _RechnungDetailContentState
    extends ConsumerState<_RechnungDetailContent> {
  late Rechnung _rechnung;
  List<RechnungsPosition>? _positionen;
  String? _betriebName;
  String? _betriebId;
  bool _loadingPositionen = true;

  @override
  void initState() {
    super.initState();
    _rechnung = widget.rechnung;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final positionen =
          await RechnungsPositionRepository.getByRechnung(_rechnung.id);

      String? betriebName;
      if (_rechnung.betriebId != null) {
        final betrieb =
            await BetriebRepository.getByServerId(_rechnung.betriebId!);
        betriebName = betrieb?.name;
        _betriebId = betrieb?.routeId;
      }

      if (mounted) {
        setState(() {
          _positionen = positionen;
          _betriebName = betriebName;
          _loadingPositionen = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPositionen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_rechnung.rechnungsnummer ?? 'Rechnung'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF drucken / teilen',
            onPressed: () => _showPdf(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status
          _SectionCard(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Status',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  _StatusChip(status: _rechnung.zahlungsstatus),
                ],
              ),
              if (_rechnung.versandart != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                    'Versandart', _versandartLabel(_rechnung.versandart!)),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Betrieb
          if (_betriebName != null)
            _SectionCard(
              children: [
                InkWell(
                  onTap: _betriebId != null
                      ? () => context.push('/betriebe/$_betriebId')
                      : null,
                  child: Row(
                    children: [
                      const Icon(Icons.store,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_betriebName!,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      if (_betriebId != null)
                        const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // Rechnungsinfo
          _SectionCard(
            children: [
              const Text('Rechnungsdetails',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              _InfoRow(
                  'Rechnungs-Nr.', _rechnung.rechnungsnummer ?? 'Entwurf'),
              _InfoRow('Datum', _formatDate(_rechnung.rechnungsdatum)),
              _InfoRow('Fällig bis', _formatDate(_rechnung.faelligkeitsdatum)),
            ],
          ),
          const SizedBox(height: 12),

          // Positionen
          _SectionCard(
            children: [
              const Text('Positionen',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              if (_loadingPositionen)
                const Center(child: CircularProgressIndicator())
              else if (_positionen != null && _positionen!.isNotEmpty)
                ..._positionen!.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text('${p.position}.',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                          ),
                          Expanded(
                            child: Text(p.beschreibung,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          Text('CHF ${p.betragNetto.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ))
              else
                Text('Keine Positionen',
                    style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),

          // Summen
          _SectionCard(
            children: [
              _SummenRow('Netto', _rechnung.betragNetto),
              _SummenRow('MwSt 8.1%', _rechnung.mwstBetrag),
              const Divider(),
              _SummenRow(
                'Total CHF',
                (_rechnung.betragBrutto * 20).roundToDouble() / 20,
                bold: true,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Zahlungsinfo
          _SectionCard(
            children: [
              const Text('Zahlungsinformationen',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              const _InfoRow('Zahlungsfrist', '30 Tage netto'),
              const _InfoRow('Bank', 'Graubündner Kantonalbank'),
              const _InfoRow('IBAN', 'CH66 0077 4010 3765 5060 1'),
            ],
          ),
          const SizedBox(height: 16),

          // Aktionen
          if (_rechnung.zahlungsstatus == 'offen')
            FilledButton.icon(
              onPressed: () => _markAsBezahlt(context),
              icon: const Icon(Icons.check),
              label: const Text('Als bezahlt markieren'),
            ),
        ],
      ),
    );
  }

  Future<void> _showPdf(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Betrieb + Rechnungsadresse laden
      final betrieb = _rechnung.betriebId != null
          ? await BetriebRepository.getByServerId(_rechnung.betriebId!)
          : null;

      BetriebRechnungsadresse? ra;
      if (_rechnung.betriebId != null) {
        final raLocal = await BetriebRechnungsadresseRepository.getByBetrieb(
            _rechnung.betriebId!);
        if (raLocal != null) {
          ra = BetriebRechnungsadresse(
            id: raLocal.serverId ?? '',
            userId: raLocal.userId,
            betriebId: _rechnung.betriebId!,
            firma: raLocal.firma,
            vorname: raLocal.vorname,
            nachname: raLocal.nachname,
            strasse: raLocal.strasse,
            nr: raLocal.nr,
            plz: raLocal.plz,
            ort: raLocal.ort,
            email: raLocal.email,
          );
        }
      }

      // Positionen laden falls noch nicht vorhanden
      final positionen = _positionen ??
          await RechnungsPositionRepository.getByRechnung(_rechnung.id);

      if (betrieb == null) {
        if (context.mounted) Navigator.of(context).pop();
        return;
      }

      final pdfBytes = await RechnungPdfService.generate(
        rechnung: _rechnung,
        positionen: positionen,
        betrieb: betrieb,
        rechnungsadresse: ra,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name:
              'Rechnung_${_rechnung.rechnungsnummer ?? _rechnung.id}'.replaceAll('/', '_'),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF-Fehler: $e')),
        );
      }
    }
  }

  Future<void> _markAsBezahlt(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Als bezahlt markieren?'),
        content: Text(
            'Rechnung ${_rechnung.rechnungsnummer ?? ''} als bezahlt markieren?'),
        actions: [
          TextButton(
              onPressed: () => ctx.pop(false), child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => ctx.pop(true), child: const Text('Bestätigen')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await RechnungRepository.update(_rechnung.id, {
        'zahlungsstatus': 'bezahlt',
        'zahlung_eingegangen_am':
            DateTime.now().toIso8601String().split('T').first,
        'zahlung_betrag': _rechnung.betragBrutto,
      });

      if (mounted) {
        ref.invalidate(rechnungenStreamProvider);
        setState(() {
          // Refresh mit neuem Status
          _rechnung = Rechnung(
            id: _rechnung.id,
            userId: _rechnung.userId,
            rechnungsnummer: _rechnung.rechnungsnummer,
            rechnungstyp: _rechnung.rechnungstyp,
            betriebId: _rechnung.betriebId,
            rechnungsdatum: _rechnung.rechnungsdatum,
            faelligkeitsdatum: _rechnung.faelligkeitsdatum,
            betragNetto: _rechnung.betragNetto,
            mwstBetrag: _rechnung.mwstBetrag,
            betragBrutto: _rechnung.betragBrutto,
            zahlungsstatus: 'bezahlt',
            versandart: _rechnung.versandart,
            zahlungEingegangenAm: DateTime.now(),
            zahlungBetrag: _rechnung.betragBrutto,
            pdfUrl: _rechnung.pdfUrl,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rechnung als bezahlt markiert')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  String _versandartLabel(String art) {
    switch (art) {
      case 'rechnung_mail':
        return 'Per E-Mail';
      case 'rechnung_post':
        return 'Per Post';
      case 'rechnung_tresen':
        return 'Am Tresen';
      default:
        return art;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _SummenRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  const _SummenRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 15 : 13,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('CHF ${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  String get _label {
    switch (status) {
      case 'offen':
        return 'Offen';
      case 'bezahlt':
        return 'Bezahlt';
      case 'ueberfaellig':
        return 'Überfällig';
      case 'storniert':
        return 'Storniert';
      case 'teilbezahlt':
        return 'Teilbezahlt';
      case 'entwurf':
        return 'Entwurf';
      default:
        return status;
    }
  }

  Color get _color {
    switch (status) {
      case 'offen':
        return AppColors.warning;
      case 'bezahlt':
        return AppColors.success;
      case 'ueberfaellig':
        return AppColors.error;
      case 'storniert':
        return AppColors.inaktiv;
      case 'teilbezahlt':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }
}

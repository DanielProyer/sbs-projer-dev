import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/models/material_bestellung.dart';
import 'package:sbs_projer_app/data/repositories/kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';
import 'package:sbs_projer_app/data/repositories/material_bestellung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';
import 'package:sbs_projer_app/services/pdf/bestellung_pdf_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class MaterialBestellungScreen extends ConsumerStatefulWidget {
  const MaterialBestellungScreen({super.key});

  @override
  ConsumerState<MaterialBestellungScreen> createState() =>
      _MaterialBestellungScreenState();
}

class _BestellPosition {
  Lager? lager;
  double menge;
  final TextEditingController mengeController;

  _BestellPosition({this.lager, this.menge = 1})
      : mengeController =
            TextEditingController(text: menge.toStringAsFixed(0));
}

class _MaterialBestellungScreenState
    extends ConsumerState<MaterialBestellungScreen> {
  bool _loading = true;
  bool _sending = false;
  String? _empfaengerName;
  String? _empfaengerEmail;

  List<Lager> _verbrauchLager = [];
  List<Lager> _reinigungLager = [];

  List<_BestellPosition> _verbrauchPositionen = [];
  List<_BestellPosition> _reinigungPositionen = [];

  Map<String, String> _kategorieNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final p in [..._verbrauchPositionen, ..._reinigungPositionen]) {
      p.mengeController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final kontakt =
          await KontaktRepository.getHeinekenZuweisung('materialbestellung');
      final alleLager = await LagerRepository.getAll();
      final kategorien = ref.read(kategorienProvider).valueOrNull ?? [];
      final kategorieNames = <String, String>{};
      for (final k in kategorien) {
        kategorieNames[k.id] = k.name;
      }

      final verbrauchLager = <Lager>[];
      final reinigungLager = <Lager>[];

      for (final l in alleLager) {
        if (!l.istAktiv) continue;
        final katName =
            l.kategorieId != null ? kategorieNames[l.kategorieId] : null;
        if (katName == 'Verbrauchsmaterial') {
          verbrauchLager.add(l);
        } else if (katName == 'Reinigungsmaterial') {
          reinigungLager.add(l);
        }
      }

      verbrauchLager.sort((a, b) => a.name.compareTo(b.name));
      reinigungLager.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _verbrauchLager = verbrauchLager;
          _reinigungLager = reinigungLager;
          _kategorieNames = kategorieNames;
          _verbrauchPositionen = [_BestellPosition(), _BestellPosition()];
          _reinigungPositionen = [_BestellPosition(), _BestellPosition()];
          _empfaengerName = kontakt != null
              ? '${kontakt.vorname} ${kontakt.nachname ?? ''}'.trim()
              : null;
          _empfaengerEmail = kontakt?.email;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
    }
  }

  List<_BestellPosition> get _filledPositionen => [
        ..._verbrauchPositionen.where((p) => p.lager != null),
        ..._reinigungPositionen.where((p) => p.lager != null),
      ];

  Future<void> _sendBestellung() async {
    final filled = _filledPositionen;
    if (filled.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Artikel ausgewählt')),
      );
      return;
    }

    if (_empfaengerEmail == null || _empfaengerEmail!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Kein Heineken-Kontakt zugewiesen. Bitte unter Einstellungen → Heineken-Kontaktzuweisung konfigurieren.')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final bestellNr = await MaterialBestellungRepository.nextBestellNr();
      final empfaenger =
          MailConfig.empfaenger(_empfaengerEmail, bereich: 'bestellung');

      final positionen = filled.map((pos) {
        final l = pos.lager!;
        final katName = l.kategorieId != null
            ? _kategorieNames[l.kategorieId]
            : null;
        return MaterialBestellposition(
          id: '',
          bestellungId: '',
          lagerId: l.id,
          dboNr: l.dboNr,
          name: l.name,
          einheit: l.einheit,
          menge: pos.menge,
          bestandAktuell: l.bestandAktuell,
          bestandOptimal: l.bestandOptimal,
          kategorieName: katName,
          sortierung: 0,
        );
      }).toList();

      final bestellung = await MaterialBestellungRepository.create(
        bestellNr: bestellNr,
        datum: DateTime.now(),
        empfaengerName: _empfaengerName,
        empfaengerEmail: empfaenger,
        positionen: positionen,
      );

      final savedPositionen =
          await MaterialBestellungRepository.getPositionen(bestellung.id);

      final pdfBytes = await BestellungPdfService.generate(
        bestellung: bestellung,
        positionen: savedPositionen,
      );

      await MaterialBestellungRepository.uploadPdf(bestellung.id, pdfBytes);

      final datumStr = DateFormat('dd.MM.yyyy').format(DateTime.now());
      await SupabaseService.client.functions.invoke(
        'send-rechnung-mail',
        body: {
          'to': empfaenger,
          'subject': 'Materialbestellung $bestellNr – SBS Projer GmbH',
          'bodyText':
              'Guten Tag\n\nAnbei die Materialbestellung $bestellNr vom $datumStr.\n\n'
              'Anzahl Positionen: ${savedPositionen.length}\n\n'
              'Freundliche Grüsse\nDaniel Projer\nSBS Projer GmbH',
          'bestellungId': bestellung.id,
          'userId': SupabaseService.dataUserId,
        },
      );

      await MaterialBestellungRepository.updateStatus(
          bestellung.id, 'gesendet');

      if (mounted) {
        ref.invalidate(materialienStreamProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bestellung $bestellNr gesendet an $empfaenger'),
            duration: const Duration(seconds: 4),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _previewPdf() async {
    final filled = _filledPositionen;
    if (filled.isEmpty) return;

    final bestellNr = await MaterialBestellungRepository.nextBestellNr();
    final positionen = filled.map((pos) {
      final l = pos.lager!;
      final katName =
          l.kategorieId != null ? _kategorieNames[l.kategorieId] : null;
      return MaterialBestellposition(
        id: '',
        bestellungId: '',
        lagerId: l.id,
        dboNr: l.dboNr,
        name: l.name,
        einheit: l.einheit,
        menge: pos.menge,
        bestandAktuell: l.bestandAktuell,
        bestandOptimal: l.bestandOptimal,
        kategorieName: katName,
      );
    }).toList();

    final bestellung = MaterialBestellung(
      id: '',
      userId: '',
      bestellNr: bestellNr,
      datum: DateTime.now(),
      empfaengerName: _empfaengerName,
      empfaengerEmail: _empfaengerEmail,
    );

    final pdfBytes = await BestellungPdfService.generate(
      bestellung: bestellung,
      positionen: positionen,
    );

    if (!mounted) return;
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final filledCount = _filledPositionen.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Materialbestellung'),
        actions: [
          if (filledCount > 0)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'PDF-Vorschau',
              onPressed: _previewPdf,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildEmpfaengerCard(),
          const SizedBox(height: 16),

          _buildSektion(
            'Verbrauchsmaterial',
            _verbrauchLager,
            _verbrauchPositionen,
            onAdd: () => setState(
                () => _verbrauchPositionen.add(_BestellPosition())),
          ),
          const SizedBox(height: 16),

          _buildSektion(
            'Reinigungsmaterial',
            _reinigungLager,
            _reinigungPositionen,
            onAdd: () => setState(
                () => _reinigungPositionen.add(_BestellPosition())),
          ),

          const SizedBox(height: 24),

          if (filledCount > 0)
            FilledButton.icon(
              onPressed: _sending ? null : _sendBestellung,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending
                  ? 'Wird gesendet...'
                  : 'Bestellung senden ($filledCount Artikel)'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpfaengerCard() {
    final hasContact =
        _empfaengerEmail != null && _empfaengerEmail!.isNotEmpty;
    return Card(
      child: ListTile(
        leading: Icon(
          hasContact ? Icons.person : Icons.warning,
          color: hasContact ? AppColors.primary : AppColors.error,
        ),
        title: Text(hasContact
            ? _empfaengerName ?? 'Heineken-Kontakt'
            : 'Kein Kontakt zugewiesen'),
        subtitle: Text(
          hasContact
              ? _empfaengerEmail!
              : 'Einstellungen → Heineken-Kontaktzuweisung',
          style: TextStyle(
            fontSize: 12,
            color: hasContact ? AppColors.textSecondary : AppColors.error,
          ),
        ),
        trailing: hasContact
            ? null
            : IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.push('/heineken/zuweisungen'),
              ),
      ),
    );
  }

  Widget _buildSektion(
    String title,
    List<Lager> verfuegbar,
    List<_BestellPosition> positionen, {
    required VoidCallback onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Position', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(positionen.length, (index) {
          final already = positionen
              .where((p) => p != positionen[index] && p.lager != null)
              .map((p) => p.lager!.id)
              .toSet();
          return _buildPositionRow(
            positionen[index],
            verfuegbar.where((l) => !already.contains(l.id)).toList(),
            onRemove: positionen.length > 2
                ? () {
                    positionen[index].mengeController.dispose();
                    setState(() => positionen.removeAt(index));
                  }
                : null,
          );
        }),
      ],
    );
  }

  Widget _buildPositionRow(
    _BestellPosition position,
    List<Lager> verfuegbar, {
    VoidCallback? onRemove,
  }) {
    final items = verfuegbar.toList();
    if (position.lager != null &&
        !items.any((l) => l.id == position.lager!.id)) {
      items.insert(0, position.lager!);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: position.lager?.id,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)),
                  isDense: true,
                  hintText: 'Artikel wählen...',
                  hintStyle:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: items.map((l) {
                  final label = l.dboNr != null
                      ? '${l.dboNr} – ${l.name}'
                      : l.name;
                  return DropdownMenuItem(value: l.id, child: Text(label));
                }).toList(),
                onChanged: (id) {
                  setState(() {
                    if (id == null) {
                      position.lager = null;
                    } else {
                      final lager = items.firstWhere((l) => l.id == id);
                      position.lager = lager;
                      final fehlmenge =
                          lager.bestandOptimal - lager.bestandAktuell;
                      position.menge = fehlmenge > 0 ? fehlmenge : 1;
                      position.mengeController.text =
                          position.menge.toStringAsFixed(0);
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              height: 40,
              child: TextFormField(
                controller: position.mengeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)),
                  isDense: true,
                ),
                onChanged: (v) {
                  final val = double.tryParse(v);
                  if (val != null && val > 0) position.menge = val;
                },
              ),
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: AppColors.error,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onRemove,
              ),
            if (onRemove == null) const SizedBox(width: 32),
          ],
        ),
      ),
    );
  }
}

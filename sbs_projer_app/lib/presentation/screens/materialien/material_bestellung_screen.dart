import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/models/material_bestellung.dart';
import 'package:sbs_projer_app/data/models/material_kategorie.dart';
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

class _BestellItem {
  final Lager lager;
  double menge;
  bool selected;

  _BestellItem({
    required this.lager,
    required this.menge,
    this.selected = true,
  });
}

class _MaterialBestellungScreenState
    extends ConsumerState<MaterialBestellungScreen> {
  bool _loading = true;
  bool _sending = false;
  bool _autoNiedrig = true;
  String? _empfaengerName;
  String? _empfaengerEmail;

  List<_BestellItem> _verbrauchItems = [];
  List<_BestellItem> _reinigungItems = [];
  List<_BestellItem> _sonstigeItems = [];

  List<Lager> _alleLager = [];
  Map<String, String> _kategorieNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final kontakt =
          await KontaktRepository.getHeinekenZuweisung('materialbestellung');
      final alleLager = await LagerRepository.getAll();
      final kategorien =
          ref.read(kategorienProvider).valueOrNull ?? [];
      final kategorieMap = <String, MaterialKategorie>{};
      final kategorieNames = <String, String>{};
      for (final k in kategorien) {
        kategorieMap[k.id] = k;
        kategorieNames[k.id] = k.name;
      }

      final verbrauch = <_BestellItem>[];
      final reinigung = <_BestellItem>[];
      final sonstige = <_BestellItem>[];

      for (final l in alleLager) {
        if (!l.istAktiv) continue;
        final katName = l.kategorieId != null
            ? kategorieNames[l.kategorieId]
            : null;
        final shouldInclude =
            l.vorgemerkt || (_autoNiedrig && l.bestandNiedrig == true);
        final fehlmenge = l.bestandOptimal - l.bestandAktuell;
        if (fehlmenge <= 0 && !l.vorgemerkt) continue;

        final item = _BestellItem(
          lager: l,
          menge: fehlmenge > 0 ? fehlmenge : 1,
          selected: shouldInclude,
        );

        if (katName == 'Verbrauchsmaterial') {
          verbrauch.add(item);
        } else if (katName == 'Reinigungsmaterial') {
          reinigung.add(item);
        } else {
          sonstige.add(item);
        }
      }

      if (mounted) {
        setState(() {
          _alleLager = alleLager;
          _kategorieNames = kategorieNames;
          _verbrauchItems = verbrauch;
          _reinigungItems = reinigung;
          _sonstigeItems = sonstige;
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

  List<_BestellItem> get _selectedItems => [
        ..._verbrauchItems.where((i) => i.selected),
        ..._reinigungItems.where((i) => i.selected),
        ..._sonstigeItems.where((i) => i.selected),
      ];

  Future<void> _sendBestellung() async {
    final selected = _selectedItems;
    if (selected.isEmpty) {
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

      final positionen = selected.map((item) {
        final katName = item.lager.kategorieId != null
            ? _kategorieNames[item.lager.kategorieId]
            : null;
        return MaterialBestellposition(
          id: '',
          bestellungId: '',
          lagerId: item.lager.id,
          dboNr: item.lager.dboNr,
          name: item.lager.name,
          einheit: item.lager.einheit,
          menge: item.menge,
          bestandAktuell: item.lager.bestandAktuell,
          bestandOptimal: item.lager.bestandOptimal,
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

      await MaterialBestellungRepository.updateStatus(bestellung.id, 'gesendet');

      for (final item in selected) {
        if (item.lager.vorgemerkt) {
          await LagerRepository.toggleVorgemerkt(item.lager.id, false);
        }
      }

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
    final selected = _selectedItems;
    if (selected.isEmpty) return;

    final bestellNr = await MaterialBestellungRepository.nextBestellNr();
    final positionen = selected.map((item) {
      final katName = item.lager.kategorieId != null
          ? _kategorieNames[item.lager.kategorieId]
          : null;
      return MaterialBestellposition(
        id: '',
        bestellungId: '',
        lagerId: item.lager.id,
        dboNr: item.lager.dboNr,
        name: item.lager.name,
        einheit: item.lager.einheit,
        menge: item.menge,
        bestandAktuell: item.lager.bestandAktuell,
        bestandOptimal: item.lager.bestandOptimal,
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

    final selectedCount = _selectedItems.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Materialbestellung'),
        actions: [
          if (selectedCount > 0)
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
          // Empfänger-Info
          _buildEmpfaengerCard(),
          const SizedBox(height: 12),

          // Auto-Niedrig Toggle
          Card(
            child: SwitchListTile(
              title: const Text('Niedrige Bestände automatisch bestellen'),
              subtitle: Text(
                'Alle Artikel unter Mindestbestand',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              value: _autoNiedrig,
              onChanged: (v) {
                setState(() {
                  _autoNiedrig = v;
                  _updateAutoSelection();
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // Verbrauchsmaterial
          if (_verbrauchItems.isNotEmpty) ...[
            _buildSektionHeader(
                'Verbrauchsmaterial', _verbrauchItems),
            ..._verbrauchItems.map((item) => _buildItemTile(item)),
            const SizedBox(height: 16),
          ],

          // Reinigungsmaterial
          if (_reinigungItems.isNotEmpty) ...[
            _buildSektionHeader(
                'Reinigungsmaterial', _reinigungItems),
            ..._reinigungItems.map((item) => _buildItemTile(item)),
            const SizedBox(height: 16),
          ],

          // Sonstige
          if (_sonstigeItems.isNotEmpty) ...[
            _buildSektionHeader('Weitere Artikel', _sonstigeItems),
            ..._sonstigeItems.map((item) => _buildItemTile(item)),
            const SizedBox(height: 16),
          ],

          if (_verbrauchItems.isEmpty &&
              _reinigungItems.isEmpty &&
              _sonstigeItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.check_circle,
                        size: 64,
                        color: AppColors.success.withAlpha(150)),
                    const SizedBox(height: 16),
                    Text('Alle Bestände OK',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppColors.success)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Senden-Button
          if (selectedCount > 0)
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
                  : 'Bestellung senden ($selectedCount Artikel)'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpfaengerCard() {
    final hasContact = _empfaengerEmail != null && _empfaengerEmail!.isNotEmpty;
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

  Widget _buildSektionHeader(String title, List<_BestellItem> items) {
    final selectedCount = items.where((i) => i.selected).length;
    final allSelected = selectedCount == items.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
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
          const SizedBox(width: 8),
          Text('$selectedCount/${items.length}',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                for (final item in items) {
                  item.selected = !allSelected;
                }
              });
            },
            child: Text(allSelected ? 'Keine' : 'Alle',
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(_BestellItem item) {
    final l = item.lager;
    return Card(
      child: CheckboxListTile(
        value: item.selected,
        onChanged: (v) => setState(() => item.selected = v ?? false),
        secondary: l.vorgemerkt
            ? const Icon(Icons.bookmark, color: Colors.orange, size: 20)
            : (l.bestandNiedrig == true
                ? Icon(Icons.warning, color: AppColors.error, size: 20)
                : null),
        title: Row(
          children: [
            Expanded(
              child: Text(l.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (l.dboNr != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('DBO ${l.dboNr}',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              'Bestand: ${l.bestandAktuell.toStringAsFixed(0)}/${l.bestandOptimal.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12),
            ),
            const Spacer(),
            SizedBox(
              width: 60,
              height: 36,
              child: TextFormField(
                initialValue: item.menge.toStringAsFixed(0),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 4),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)),
                  isDense: true,
                ),
                onChanged: (v) {
                  final val = double.tryParse(v);
                  if (val != null && val > 0) item.menge = val;
                },
              ),
            ),
            const SizedBox(width: 4),
            Text(l.einheit,
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _updateAutoSelection() {
    for (final items in [_verbrauchItems, _reinigungItems, _sonstigeItems]) {
      for (final item in items) {
        if (item.lager.bestandNiedrig == true) {
          item.selected = _autoNiedrig;
        }
        if (item.lager.vorgemerkt) {
          item.selected = true;
        }
      }
    }
  }
}

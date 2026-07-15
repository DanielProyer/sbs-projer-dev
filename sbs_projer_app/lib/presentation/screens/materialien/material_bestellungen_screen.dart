import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/material_bestellung.dart';
import 'package:sbs_projer_app/data/repositories/material_bestellung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/widgets/abhol_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// Liste aller Materialbestellungen mit Status, Bestell-PDF und der
/// Abhol-Buchung („Material abgeholt" / „Buchung rückgängig").
class MaterialBestellungenScreen extends ConsumerStatefulWidget {
  const MaterialBestellungenScreen({super.key});

  @override
  ConsumerState<MaterialBestellungenScreen> createState() =>
      _MaterialBestellungenScreenState();
}

class _MaterialBestellungenScreenState
    extends ConsumerState<MaterialBestellungenScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy');
  bool _loading = true;
  bool _busy = false;
  List<MaterialBestellung> _bestellungen = [];
  final _positionen = <String, List<MaterialBestellposition>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await MaterialBestellungRepository.getAll();
      if (!mounted) return;
      setState(() {
        _bestellungen = list;
        _positionen.clear();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fehler beim Laden: $e')));
    }
  }

  Future<List<MaterialBestellposition>> _ladePositionen(String id) async {
    final cached = _positionen[id];
    if (cached != null) return cached;
    final list = await MaterialBestellungRepository.getPositionen(id);
    _positionen[id] = list;
    return list;
  }

  Future<void> _oeffnePdf(MaterialBestellung b) async {
    final pfad = b.pdfStoragePath;
    if (pfad == null || pfad.isEmpty) return;
    try {
      final url = await MaterialBestellungRepository.getSignedPdfUrl(pfad);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF konnte nicht geöffnet werden: $e')));
      }
    }
  }

  Future<void> _abholen(MaterialBestellung b) async {
    setState(() => _busy = true);
    final List<MaterialBestellposition> positionen;
    try {
      positionen = await _ladePositionen(b.id);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Positionen konnten nicht geladen werden: $e')));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final payload = await zeigeAbholDialog(context,
        bestellung: b, positionen: positionen);
    if (payload == null || payload.isEmpty) return;

    setState(() => _busy = true);
    try {
      await MaterialBestellungRepository.abholen(b.id, payload);
      if (!mounted) return;
      ref.invalidate(materialienStreamProvider); // Bestände sind neu
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${payload.length} Artikel gebucht — Bestände aktualisiert.')));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler beim Buchen: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rueckgaengig(MaterialBestellung b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buchung rückgängig?'),
        content: Text(
            'Die Bestände aus Bestellung ${b.bestellNr} werden wieder abgezogen '
            'und die Bestellung geht zurück auf „gesendet".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rückgängig')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await MaterialBestellungRepository.abholungRueckgaengig(b.id);
      if (!mounted) return;
      ref.invalidate(materialienStreamProvider);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buchung rückgängig gemacht.')));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bestellungen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bestellungen.isEmpty
              ? const Center(child: Text('Noch keine Bestellungen.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _bestellungen.length,
                    itemBuilder: (_, i) => _karte(_bestellungen[i]),
                  ),
                ),
    );
  }

  /// Karte einer Bestellung. Badge, PDF und der Aktions-Button liegen bewusst
  /// im **subtitle** (also ohne Aufklappen erreichbar) — „Material abgeholt"
  /// soll ein Klick sein. Das `Wrap` verhindert horizontales Scrollen auf dem
  /// Handy. Die Positionen sind das Aufklapp-Detail.
  Widget _karte(MaterialBestellung b) {
    final istGesendet = b.status == 'gesendet';
    final istAbgeholt = b.status == 'abgeholt';
    final hatPdf = b.pdfStoragePath != null && b.pdfStoragePath!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text('${b.bestellNr} · ${_dateFormat.format(b.datum)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _badge(b),
              if (hatPdf)
                GestureDetector(
                  onTap: () => _oeffnePdf(b),
                  behavior: HitTestBehavior.opaque,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.picture_as_pdf,
                        size: 15, color: AppColors.primary),
                    SizedBox(width: 3),
                    Text('PDF',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              if (istGesendet)
                _tapButton('Material abgeholt',
                    _busy ? null : () => _abholen(b), true),
              if (istAbgeholt)
                _tapButton('Buchung rückgängig',
                    _busy ? null : () => _rueckgaengig(b), false),
            ],
          ),
        ),
        onExpansionChanged: (offen) async {
          if (!offen || _positionen.containsKey(b.id)) return;
          await _ladePositionen(b.id);
          if (mounted) setState(() {});
        },
        children: _positionsZeilen(b),
      ),
    );
  }

  List<Widget> _positionsZeilen(MaterialBestellung b) {
    final positionen = _positionen[b.id];
    if (positionen == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(16),
          child: Center(
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        )
      ];
    }
    return positionen.map((p) {
      final erhalten = p.mengeErhalten;
      final abweichung = erhalten != null && erhalten != p.menge;
      return ListTile(
        dense: true,
        title: Text(p.name, style: const TextStyle(fontSize: 13)),
        trailing: Text(
          erhalten == null
              ? '${p.menge.toStringAsFixed(0)} ${p.einheit}'
              : 'bestellt ${p.menge.toStringAsFixed(0)} · '
                  'erhalten ${erhalten.toStringAsFixed(0)} ${p.einheit}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: abweichung ? FontWeight.w700 : FontWeight.normal,
            color: abweichung ? AppColors.warning : AppColors.textSecondary,
          ),
        ),
      );
    }).toList();
  }

  Widget _badge(MaterialBestellung b) {
    final (text, farbe) = switch (b.status) {
      'gesendet' => ('gesendet', AppColors.primary),
      'abgeholt' => (
          'abgeholt${b.abgeholtAm != null ? ' am ${_dateFormat.format(b.abgeholtAm!)}' : ''}',
          AppColors.success
        ),
      'storniert' => ('storniert', AppColors.error),
      _ => ('Entwurf', AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: farbe.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: farbe, fontWeight: FontWeight.w700)),
    );
  }

  /// Material-Buttons rendern im Material-Bereich unter CanvasKit teils nicht
  /// → GestureDetector-Pill (bestehendes Projekt-Muster).
  Widget _tapButton(String label, VoidCallback? onTap, bool primaer) {
    final farbe = primaer ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade300 : farbe,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

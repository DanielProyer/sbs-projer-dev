import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/mahn_hinweis.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/mahnfall_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/mahn_hinweis_provider.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
import 'package:sbs_projer_app/services/rechnung/barzahlung_service.dart';

final _ddMMyyyy = DateFormat('dd.MM.yyyy');

String _statusText(String s) => switch (s) {
      'offen' => 'Offen',
      'gesendet' => 'Gesendet',
      'erinnert' => 'Erinnert',
      'mahnung_1' => '1. Mahnung',
      'mahnung_2' => 'Letzte Mahnung',
      _ => s,
    };

/// Hinweis beim Service (Mahnwesen Teil 3, Spec §6): Band oben in Reinigung,
/// Störung und Montage, sobald der Betrieb gemahnte Rechnungen hat — orange
/// ab 1. Mahnung, rot bei Mahnfall («nur gegen Barzahlung»). Antippen öffnet
/// die offenen Rechnungen mit «Bar einkassieren» und «QR zeigen».
///
/// Nur Hinweis, nie Sperre. Einkassieren ist KEINE Änderung am Formular
/// (bucht direkt), markiert es also nicht als geändert.
/// CanvasKit-sicher: nur InkWell/GestureDetector + Container + Row/Column.
class MahnHinweisBand extends ConsumerWidget {
  /// Server-Id des Betriebs; null → nichts.
  final String? betriebId;
  final EdgeInsetsGeometry padding;

  const MahnHinweisBand({
    super.key,
    required this.betriebId,
    this.padding = const EdgeInsets.only(bottom: 8),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = betriebId;
    if (id == null) return const SizedBox.shrink();
    final hinweis = ref.watch(mahnHinweisProvider(id)).valueOrNull;
    if (hinweis == null || hinweis.stufe == MahnHinweisStufe.keine) {
      return const SizedBox.shrink();
    }
    final farbe =
        hinweis.stufe == MahnHinweisStufe.mahnfall ? AppColors.error : AppColors.warning;
    return Padding(
      padding: padding,
      child: InkWell(
        onTap: () => _zeigeSheet(context, id, hinweis),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: farbe.withAlpha(30),
            border: Border.all(color: farbe.withAlpha(100)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: farbe, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hinweis.text,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right, color: farbe, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _zeigeSheet(BuildContext context, String id, MahnHinweis hinweis) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => _OffeneRechnungenSheet(betriebId: id, hinweis: hinweis),
      );
}

class _OffeneRechnungenSheet extends ConsumerStatefulWidget {
  final String betriebId;
  final MahnHinweis hinweis;
  const _OffeneRechnungenSheet({required this.betriebId, required this.hinweis});

  @override
  ConsumerState<_OffeneRechnungenSheet> createState() => _OffeneRechnungenSheetState();
}

class _OffeneRechnungenSheetState extends ConsumerState<_OffeneRechnungenSheet> {
  late final Set<String> _gewaehlt = {for (final r in widget.hinweis.offene) r.id};
  bool _laeuft = false;

  /// Nach dem Einkassieren: Mahnfälle, deren Rechnungen jetzt alle bezahlt
  /// sind — Daniel schliesst sie auf der Mahnfall-Seite ab.
  List<String>? _abschliessbar;

  List<Rechnung> get _auswahl =>
      widget.hinweis.offene.where((r) => _gewaehlt.contains(r.id)).toList();

  double get _total => rundeAufRappen(_auswahl.fold(0.0, (s, r) => s + r.betragBrutto));

  void _meldung(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _qrZeigen(Rechnung r) async {
    try {
      final url = await RechnungPdfStorage.getSignedUrl(r.id);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      _meldung('PDF nicht verfügbar: ${kurzeFehlermeldung(e)}');
    }
  }

  Future<void> _einkassieren() async {
    final auswahl = _auswahl;
    if (auswahl.isEmpty) return;
    final total = _total;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('CHF ${chf(total)} bar erhalten?'),
        content: Text(
          '${auswahl.length} Rechnung${auswahl.length == 1 ? '' : 'en'} '
          'werden als bar bezahlt verbucht (Kasse).',
        ),
        actions: [
          TapKnopf(
            text: 'Abbrechen',
            primaer: false,
            onTap: () => Navigator.pop(ctx, false),
          ),
          TapKnopf(
            text: 'Bar erhalten',
            icon: Icons.check,
            onTap: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _laeuft = true);
    try {
      await BarzahlungService.kassieren(auswahl);
    } catch (e) {
      ref.invalidate(mahnHinweisProvider(widget.betriebId));
      if (mounted) setState(() => _laeuft = false);
      _meldung('Nicht kassiert: ${kurzeFehlermeldung(e)}');
      return;
    }
    ref.invalidate(mahnHinweisProvider(widget.betriebId));
    ref.invalidate(rechnungenStreamProvider);
    _meldung('Bar verbucht (Kasse): CHF ${chf(total)}');

    var abschliessbar = const <String>[];
    try {
      final faelle = (await MahnfallRepository.getSperrendeFaelle())
          .where((f) => f.betriebId == widget.betriebId)
          .map((f) => (id: f.id, rechnungIds: f.rechnungIds))
          .toList();
      if (faelle.isNotEmpty) {
        final rechnungen = await RechnungRepository.getKundenrechnungenAb(
          kMahnStart,
          betriebId: widget.betriebId,
        );
        abschliessbar = abschliessbareMahnfaelle(
          faelle: faelle,
          rechnungen: rechnungen,
          kassierteIds: {for (final r in auswahl) r.id},
        );
      }
    } catch (_) {
      // Nur ein Zusatzhinweis — die Zahlung ist gebucht.
    }
    if (!mounted) return;
    if (abschliessbar.isEmpty) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _laeuft = false;
        _abschliessbar = abschliessbar;
      });
    }
  }

  void _zumMahnfall(String id) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/rechnungen/mahnfall/$id');
  }

  @override
  Widget build(BuildContext context) {
    final mahnfall = widget.hinweis.stufe == MahnHinweisStufe.mahnfall;
    final abschliessbar = _abschliessbar;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Offene Rechnungen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (mahnfall) ...[
              const SizedBox(height: 4),
              const Text(
                'Mahnfall — Service nur gegen Barzahlung.',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            if (abschliessbar != null) ...[
              const Text(
                'Bar verbucht. Alle Rechnungen des Mahnfalls sind jetzt bezahlt — '
                'Mahnfall abschliessen:',
              ),
              const SizedBox(height: 8),
              for (final id in abschliessbar)
                GestureDetector(
                  onTap: () => _zumMahnfall(id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: const Row(
                      children: [
                        Icon(Icons.gavel, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mahnfall abschliessen',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              TapKnopf(
                text: 'Schliessen',
                primaer: false,
                onTap: () => Navigator.of(context).pop(),
              ),
            ] else ...[
              for (final r in widget.hinweis.offene) _zeile(r),
              const Divider(),
              Row(
                children: [
                  const Expanded(
                    child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Text(
                    'CHF ${chf(_total)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TapKnopf(
                text: 'Bar einkassieren — CHF ${chf(_total)}',
                icon: Icons.payments,
                laeuft: _laeuft,
                onTap: _gewaehlt.isEmpty || _laeuft ? null : _einkassieren,
              ),
              const SizedBox(height: 8),
              const Text(
                'Oder «QR zeigen»: Der Kunde zahlt mit seiner E-Banking-App.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _zeile(Rechnung r) {
    final an = _gewaehlt.contains(r.id);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _laeuft
                  ? null
                  : () => setState(() => an ? _gewaehlt.remove(r.id) : _gewaehlt.add(r.id)),
              child: Row(
                children: [
                  Icon(
                    an ? Icons.check_box : Icons.check_box_outline_blank,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.rechnungsnummer ?? r.id.substring(0, 8),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${_ddMMyyyy.format(r.rechnungsdatum)} · '
                          '${_statusText(r.zahlungsstatus)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text('CHF ${chf(r.betragBrutto)}'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _qrZeigen(r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: const Column(
                children: [
                  Icon(Icons.qr_code, size: 20, color: AppColors.primary),
                  Text(
                    'QR zeigen',
                    style: TextStyle(fontSize: 10, color: AppColors.primary),
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

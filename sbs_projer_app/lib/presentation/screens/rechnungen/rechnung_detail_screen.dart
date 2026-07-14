import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/rechnung_versand_status.dart';
import 'package:sbs_projer_app/core/util/rechnungsadresse_resolver.dart';
import 'package:sbs_projer_app/data/local/betrieb_rechnungsadresse_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/models/rechnungs_position.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/presentation/providers/geschaeft_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/services/pdf/mahnung_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

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
  BetriebRechnungsadresseLocal? _betriebRa;
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
      BetriebRechnungsadresseLocal? betriebRa;
      if (_rechnung.betriebId != null) {
        final betrieb =
            await BetriebRepository.getByServerId(_rechnung.betriebId!);
        betriebName = betrieb?.name;
        _betriebId = betrieb?.routeId;
        betriebRa = await BetriebRechnungsadresseRepository
            .getByBetrieb(_rechnung.betriebId!);
      }

      if (mounted) {
        setState(() {
          _positionen = positionen;
          _betriebName = betriebName;
          _betriebRa = betriebRa;
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
          if (_rechnung.rechnungstyp == 'jahresrechnung')
            IconButton(
              icon: const Icon(Icons.photo_library),
              tooltip: 'Reinigungsprotokolle',
              onPressed: () => _showProtokollePdf(context),
            ),
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
          // Frühwarnung: erstellt, aber nicht versendet
          if (rechnungNichtVersendet(_rechnung)) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withAlpha(80)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.mark_email_unread,
                      color: AppColors.error, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Diese Rechnung wurde erstellt, aber nicht versendet. '
                      'Unten über „Rechnung erneut senden" nachholen.',
                      style: TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
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

          // Rechnungsadresse (pro Rechnung anpassbar)
          _rechnungsadresseCard(),
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
              _SummenRow(
                'MwSt ${_rechnung.betragNetto > 0 ? (_rechnung.mwstBetrag / _rechnung.betragNetto * 100).toStringAsFixed(1) : '8.1'}%',
                _rechnung.mwstBetrag),
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

          // Mahnverlauf
          if (_hasMahnungen()) ...[
            _SectionCard(
              children: [
                const Text('Mahnverlauf',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 8),
                if (_rechnung.erinnerungAm != null)
                  _MahnungPdfRow(
                    label: 'Zahlungserinnerung',
                    datum: _rechnung.erinnerungAm!,
                    onTap: () => _showMahnungPdf(context, 0),
                  ),
                if (_rechnung.mahnung1Am != null)
                  _MahnungPdfRow(
                    label: '1. Mahnung',
                    datum: _rechnung.mahnung1Am!,
                    onTap: () => _showMahnungPdf(context, 1),
                  ),
                if (_rechnung.mahnung2Am != null)
                  _MahnungPdfRow(
                    label: '2. Mahnung',
                    datum: _rechnung.mahnung2Am!,
                    onTap: () => _showMahnungPdf(context, 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  // ─── Rechnungsadresse (gehört dem Betrieb; hier nur Anzeige + Neu-Versand) ───

  Widget _rechnungsadresseCard() {
    final ra = _betriebRa;
    return _SectionCard(
      children: [
        const Text('Rechnungsadresse',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        Text(
          ra != null
              ? _betriebRaText(ra)
              : 'Keine separate Rechnungsadresse beim Betrieb hinterlegt.',
          style: TextStyle(
              fontSize: 13, color: ra != null ? null : AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        // GestureDetector statt Material-Button (CanvasKit-Render-Bug im Body).
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _tapButton('Adresse beim Betrieb bearbeiten', _adresseBeiBetrieb,
                icon: Icons.edit_location_alt),
            if (_rechnung.betriebId != null)
              _tapButton('Rechnung erneut senden', _rechnungErneutSenden,
                  icon: Icons.send),
          ],
        ),
      ],
    );
  }

  String _betriebRaText(BetriebRechnungsadresseLocal a) {
    final lines = <String>[
      (a.firma ?? '').trim(),
      a.nachname.trim(),
      '${a.strasse}${a.nr != null && a.nr!.isNotEmpty ? ' ${a.nr}' : ''}'.trim(),
      '${a.plz} ${a.ort}'.trim(),
      (a.email ?? '').trim(),
    ].where((s) => s.isNotEmpty).toList();
    return lines.isEmpty ? '—' : lines.join('\n');
  }

  /// Springt zum Adress-Formular des Betriebs; danach Anzeige neu laden.
  Future<void> _adresseBeiBetrieb() async {
    final bid = _rechnung.betriebId;
    if (bid == null) return;
    await context.push('/betriebe/$bid/rechnungsadresse');
    final ra = await BetriebRechnungsadresseRepository.getByBetrieb(bid);
    if (mounted) setState(() => _betriebRa = ra);
  }

  /// Bestätigt + versendet die Rechnung neu (Fällig bis → heute+30).
  Future<void> _rechnungErneutSenden() async {
    final email = _betriebRa?.email;
    await _neuVersendenAnbieten(
        (email != null && email.trim().isNotEmpty) ? email.trim() : null);
  }

  /// Bietet den Neu-Versand an (Bestätigung).
  Future<void> _neuVersendenAnbieten(String? email) async {
    if (!mounted) return;
    final neueFaelligkeit = DateTime.now().add(const Duration(days: 30));
    final to = email ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechnung neu versenden?'),
        content: Text(to.isEmpty
            ? 'Keine E-Mail in der Rechnungsadresse hinterlegt — kein Versand möglich.'
            : 'Die Rechnung wird neu erzeugt und per Mail an\n$to\nversendet.\n\n'
                'Fällig bis wird auf ${_formatDate(neueFaelligkeit)} '
                '(heute + 30 Tage) gesetzt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nein')),
          if (to.isNotEmpty)
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Neu versenden')),
        ],
      ),
    );
    if (ok == true) await _neuVersenden(neueFaelligkeit, to);
  }

  /// Persistiert das neue Fälligkeitsdatum, erzeugt das PDF neu (mit neuer
  /// Adresse + Fälligkeit) und versendet es per Mail an [to].
  Future<void> _neuVersenden(DateTime neueFaelligkeit, String to) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      // 1. Fällig bis in der Rechnung/Forderung persistieren.
      await RechnungRepository.update(_rechnung.id, {
        'faelligkeitsdatum': neueFaelligkeit.toIso8601String().split('T').first,
      });
      await _reloadRechnung();

      // 2. Betrieb + effektive Adresse laden.
      final betrieb = _rechnung.betriebId != null
          ? await BetriebRepository.getByServerId(_rechnung.betriebId!)
          : null;
      if (betrieb == null) throw Exception('Betrieb nicht gefunden');
      BetriebRechnungsadresse? betriebRa;
      final raLocal = await BetriebRechnungsadresseRepository.getByBetrieb(
          _rechnung.betriebId!);
      if (raLocal != null) {
        betriebRa = BetriebRechnungsadresse(
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
      final effRa = effektiveRechnungsadresse(
          _rechnung.rechnungsadresse, betriebRa,
          betriebId: _rechnung.betriebId ?? '');

      // 3. PDF neu erzeugen (neue Adresse + Fälligkeit) + hochladen.
      final positionen = _positionen ??
          await RechnungsPositionRepository.getByRechnung(_rechnung.id);
      final g = ref.read(geschaeftProvider).valueOrNull;
      final pdfBytes = await RechnungPdfService.generate(
        rechnung: _rechnung,
        positionen: positionen,
        betrieb: betrieb,
        rechnungsadresse: effRa,
        firmaName: g?.firma,
        firmaStrasse: g?.adresseStrasse,
        firmaPlzOrt: g?.adressePlzOrt,
        firmaMwst: g?.mwstZeile,
      );
      await RechnungPdfStorage.uploadPdf(_rechnung.id, pdfBytes);

      // 4. Mail senden (MailConfig respektieren) + Protokoll als Anhang.
      final protokoll = await _findProtokollPfad(_rechnung.id);
      final empfaenger = MailConfig.empfaenger(to, bereich: 'reinigung');
      final d = _rechnung.rechnungsdatum;
      final datumStr = '${d.day}. ${_monatName(d.month)} ${d.year}';
      final betriebLabel = (betrieb.ort != null && betrieb.ort!.isNotEmpty)
          ? '${betrieb.name} ${betrieb.ort}'
          : betrieb.name;
      final betragStr = ((_rechnung.betragBrutto * 20).roundToDouble() / 20)
          .toStringAsFixed(2);
      await SupabaseService.client.functions.invoke('send-rechnung-mail', body: {
        'to': empfaenger,
        'subject':
            'Rechnung Service Offenausschankanlage $betriebLabel vom $datumStr',
        'bodyText': 'Guten Tag\n\n'
            'Im Anhang sende ich Ihnen die Rechnung für die Bierleitungsreinigung im $betriebLabel vom $datumStr, '
            'die Details entnehmen Sie bitte der Rechnung und dem Lieferschein im Anhang.\n\n'
            'Ich bitte Sie den offenen Betrag von CHF $betragStr innerhalb von 30 Tagen '
            'mit dem beiliegenden Einzahlungsschein zu begleichen.\n\n'
            'Mit freundlichen Grüssen\n\n'
            'Daniel Projer\n\n'
            'SBS Projer GmbH\nVia Rezia 8\n7013 Domat/Ems\n076 / 566 58 06',
        'rechnungId': _rechnung.id,
        'userId': SupabaseService.dataUserId,
        if (protokoll != null) 'protokollFotoPfad': protokoll,
      });

      // 5. versendet_am setzen (nur bei scharfem Versand).
      final istScharf = MailConfig.istScharf('reinigung');
      if (istScharf) {
        await RechnungRepository.update(_rechnung.id, {
          'versendet_am': DateTime.now().toIso8601String().split('T').first,
          'versandart': 'rechnung_mail',
        });
        await _reloadRechnung();
      }
      ref.invalidate(rechnungenStreamProvider);
      if (mounted) {
        Navigator.of(context).pop(); // Lade-Dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(istScharf
              ? 'Rechnung neu versendet an $empfaenger (Fällig bis ${_formatDate(neueFaelligkeit)}).'
              : 'TEST: Mail ging an $empfaenger (nicht an Kunde).'),
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Neu-Versand fehlgeschlagen: $e')));
      }
    }
  }

  /// Sucht den Protokoll-Pfad (Reinigung) für den Mail-Anhang.
  Future<String?> _findProtokollPfad(String rechnungId) async {
    try {
      final posRows = await SupabaseService.client
          .from('rechnungs_positionen')
          .select('service_id')
          .eq('rechnung_id', rechnungId)
          .eq('service_typ', 'reinigung')
          .limit(1);
      if ((posRows as List).isEmpty) return null;
      final sid = (posRows.first as Map)['service_id']?.toString();
      if (sid == null || sid.isEmpty) return null;
      final reinRows = await SupabaseService.client
          .from('reinigungen')
          .select('protokoll_foto_pfad')
          .eq('id', sid)
          .limit(1);
      if ((reinRows as List).isEmpty) return null;
      final pfad = (reinRows.first as Map)['protokoll_foto_pfad']?.toString();
      return (pfad != null && pfad.isNotEmpty) ? pfad : null;
    } catch (_) {
      return null;
    }
  }

  static String _monatName(int m) {
    const namen = [
      '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli',
      'August', 'September', 'Oktober', 'November', 'Dezember'
    ];
    return (m >= 1 && m <= 12) ? namen[m] : '';
  }

  /// Tap-Button (GestureDetector) — rendert auch dort, wo Material-Buttons in
  /// CanvasKit unsichtbar bleiben.
  Widget _tapButton(String label, VoidCallback onTap, {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _reloadRechnung() async {
    final r = await RechnungRepository.getById(_rechnung.id);
    if (r != null && mounted) setState(() => _rechnung = r);
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

      final g = ref.read(geschaeftProvider).valueOrNull;
      final pdfBytes = await RechnungPdfService.generate(
        rechnung: _rechnung,
        positionen: positionen,
        betrieb: betrieb,
        rechnungsadresse: effektiveRechnungsadresse(
            _rechnung.rechnungsadresse, ra,
            betriebId: _rechnung.betriebId ?? ''),
        firmaName: g?.firma,
        firmaStrasse: g?.adresseStrasse,
        firmaPlzOrt: g?.adressePlzOrt,
        firmaMwst: g?.mwstZeile,
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

  bool _hasMahnungen() =>
      _rechnung.erinnerungAm != null ||
      _rechnung.mahnung1Am != null ||
      _rechnung.mahnung2Am != null;

  Future<void> _showMahnungPdf(BuildContext context, int stufe) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
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

      if (betrieb == null) {
        if (context.mounted) Navigator.of(context).pop();
        return;
      }

      final pdfBytes = await MahnungPdfService.generate(
        rechnung: _rechnung,
        betrieb: betrieb,
        rechnungsadresse: effektiveRechnungsadresse(
            _rechnung.rechnungsadresse, ra,
            betriebId: _rechnung.betriebId ?? ''),
        mahnStufe: stufe,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        final titel = stufe == 0
            ? 'Zahlungserinnerung'
            : stufe == 1
                ? '1_Mahnung'
                : '2_Mahnung';
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: '${titel}_${_rechnung.rechnungsnummer ?? _rechnung.id}'
              .replaceAll('/', '_'),
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

  Future<void> _showProtokollePdf(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final url =
          await RechnungPdfStorage.getProtokollSignedUrl(_rechnung.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Keine Protokolle vorhanden oder Fehler: $e')),
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

class _MahnungPdfRow extends StatelessWidget {
  final String label;
  final DateTime datum;
  final VoidCallback onTap;

  const _MahnungPdfRow({
    required this.label,
    required this.datum,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final datumStr =
        '${datum.day.toString().padLeft(2, '0')}.${datum.month.toString().padLeft(2, '0')}.${datum.year}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, size: 18, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            Text(datumStr,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
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
      case 'offen': return 'Offen';
      case 'bezahlt': return 'Bezahlt';
      case 'erinnert': return 'Erinnert';
      case 'mahnung_1': return 'Mahnung 1';
      case 'mahnung_2': return 'Mahnung 2';
      case 'abgeschrieben': return 'Abgeschrieben';
      default: return status;
    }
  }

  Color get _color {
    switch (status) {
      case 'offen': return AppColors.warning;
      case 'bezahlt': return AppColors.success;
      case 'erinnert': return const Color(0xFFE65100);
      case 'mahnung_1': return AppColors.error;
      case 'mahnung_2': return const Color(0xFF8B0000);
      case 'abgeschrieben': return AppColors.inaktiv;
      default: return AppColors.textSecondary;
    }
  }
}

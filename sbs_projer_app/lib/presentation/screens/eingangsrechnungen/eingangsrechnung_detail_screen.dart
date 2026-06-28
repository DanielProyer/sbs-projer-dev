import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/data/models/konto.dart';
import 'package:sbs_projer_app/data/repositories/eingangsrechnung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eingangsrechnung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/konto_providers.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/eingangsrechnung_buchung_service.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/eingangsrechnung_reversal_service.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/kreditor_lern_service.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

/// Detail-Screen für eine Eingangsrechnung (Kreditor, TP-2).
///
/// Lädt den Datensatz, zeigt die erkannten Felder editierbar an und bietet die
/// Aktionen "Bestätigen & buchen" (Stufe 1: Aufwand an Kreditoren 2000),
/// "Nur ablegen (Info)" und "Verwerfen".
class EingangsrechnungDetailScreen extends ConsumerStatefulWidget {
  const EingangsrechnungDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<EingangsrechnungDetailScreen> createState() =>
      _EingangsrechnungDetailScreenState();
}

class _EingangsrechnungDetailScreenState
    extends ConsumerState<EingangsrechnungDetailScreen> {
  // Lade-/Speicher-Zustand
  bool _loading = true;
  bool _busy = false;
  String? _ladeFehler;
  Eingangsrechnung? _rechnung;

  // Editierbare Felder
  final _ausstellerCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _referenzCtrl = TextEditingController();
  final _betragCtrl = TextEditingController();
  final _mwstCtrl = TextEditingController();

  String _referenzTyp = 'NON';
  bool _mwstPflichtig = true;
  DateTime? _faelligkeit;
  int? _aufwandskonto;
  int? _vorsteuerKonto;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ausstellerCtrl.dispose();
    _ibanCtrl.dispose();
    _referenzCtrl.dispose();
    _betragCtrl.dispose();
    _mwstCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final e = await EingangsrechnungRepository.getById(widget.id);
      if (!mounted) return;
      if (e == null) {
        setState(() {
          _loading = false;
          _ladeFehler = 'Eingangsrechnung nicht gefunden.';
        });
        return;
      }
      _ausstellerCtrl.text = e.ausstellerName ?? '';
      _ibanCtrl.text = e.lieferantIban ?? '';
      _referenzCtrl.text = e.qrReferenz ?? '';
      _betragCtrl.text = e.betragBrutto == 0
          ? ''
          : e.betragBrutto.toStringAsFixed(2);
      final mwst = e.mwstSatz ?? 0;
      _mwstCtrl.text = mwst == 0 ? '0' : _trimNum(mwst);
      _referenzTyp = _normReferenzTyp(e.referenzTyp);
      _mwstPflichtig = e.mwstPflichtig;
      _faelligkeit = e.faelligkeit;
      _aufwandskonto = e.aufwandskonto;
      // Vorsteuer-Default: bei MwSt-Satz > 0 -> 1171, sonst kein Abzug.
      _vorsteuerKonto = e.vorsteuerKonto ?? (mwst > 0 ? 1171 : null);
      setState(() {
        _rechnung = e;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _ladeFehler = 'Fehler beim Laden: $err';
      });
    }
  }

  static String _normReferenzTyp(String? typ) {
    final t = (typ ?? '').toUpperCase();
    if (t == 'QRR' || t == 'SCOR' || t == 'NON') return t;
    return 'NON';
  }

  /// Entfernt unnötige Nachkommastellen (8.10 -> 8.1, 8.00 -> 8).
  static String _trimNum(double v) {
    var s = v.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  // ---------------------------------------------------------------------------
  // Aktionen
  // ---------------------------------------------------------------------------

  Future<void> _bestaetigenUndBuchen() async {
    if (_busy) return;
    if (_aufwandskonto == null) {
      _snack('Bitte Aufwandskonto wählen');
      return;
    }
    if (_parseBetrag(_betragCtrl.text) <= 0) {
      _snack('Betrag muss grösser als 0 sein');
      return;
    }

    setState(() => _busy = true);
    try {
      await EingangsrechnungRepository.update(widget.id, {
        'aussteller_name': _trimOrNull(_ausstellerCtrl.text),
        'lieferant_iban': _trimOrNull(_ibanCtrl.text),
        'qr_referenz': _trimOrNull(_referenzCtrl.text),
        'referenz_typ': _referenzTyp,
        'betrag_brutto': _parseBetrag(_betragCtrl.text),
        'mwst_satz': _parseMwst(_mwstCtrl.text),
        'mwst_pflichtig': _mwstPflichtig,
        'aufwandskonto': _aufwandskonto,
        'vorsteuer_konto': _vorsteuerKonto,
        'faelligkeit': _dateOnly(_faelligkeit),
        'status': 'bestaetigt',
      });

      final frisch = await EingangsrechnungRepository.getById(widget.id);
      await EingangsrechnungBuchungService.bucheStufe1(frisch!);

      // Lieferanten-Vorbelegung lernen (neue Regel oder Konto-Korrektur).
      // Fehler hier dürfen die erfolgte Buchung nicht stören.
      try {
        await KreditorLernService.lerne(
          ausstellerName: _trimOrNull(_ausstellerCtrl.text),
          iban: _trimOrNull(_ibanCtrl.text),
          referenz: _trimOrNull(_referenzCtrl.text),
          aufwandskonto: _aufwandskonto!,
          vorsteuerKonto: _vorsteuerKonto,
          mwstSatz: _parseMwst(_mwstCtrl.text),
          mwstPflichtig: _mwstPflichtig,
        );
      } catch (_) {
        // Lern-Fehler bewusst ignorieren.
      }

      ref.invalidate(eingangsrechnungenProvider);
      if (!mounted) return;
      _snack('Gebucht (Aufwand an Kreditoren 2000)');
      _zurueck();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Fehler beim Buchen: $e');
    }
  }

  Future<void> _nurAblegen() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await EingangsrechnungRepository.update(widget.id, {
        'status': 'abgelegt',
        'ist_nur_info': true,
      });
      ref.invalidate(eingangsrechnungenProvider);
      if (!mounted) return;
      _snack('Als Info abgelegt');
      _zurueck();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Fehler: $e');
    }
  }

  Future<void> _verwerfen() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechnung verwerfen?'),
        content: const Text(
          'Die Eingangsrechnung wird auf "verworfen" gesetzt und '
          'verschwindet aus der Liste.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Verwerfen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await EingangsrechnungRepository.update(widget.id, {
        'status': 'verworfen',
      });
      ref.invalidate(eingangsrechnungenProvider);
      if (!mounted) return;
      _snack('Verworfen');
      _zurueck();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Fehler: $e');
    }
  }

  /// TP-6: macht die Stufe-2-Zahlung rückgängig (löscht die Zahlungs-Buchung,
  /// setzt die Rechnung wieder auf offen/zahlbar; camt-Tx wird re-importierbar).
  Future<void> _zahlungRueckgaengig() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zahlung rückgängig?'),
        content: const Text(
          'Die Stufe-2-Buchung (Kreditor → Bank) wird gelöscht und die '
          'Rechnung wieder als offen/zahlbar gesetzt. Die Bank-Belastung kann '
          'danach erneut abgeglichen werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Rückgängig'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await EingangsrechnungReversalService.zahlungRueckgaengig(_rechnung!);
      ref.invalidate(eingangsrechnungenProvider);
      ref.invalidate(buchungenStreamProvider);
      if (!mounted) return;
      _snack('Zahlung rückgängig — Rechnung wieder offen');
      setState(() => _busy = false);
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Fehler: $e');
    }
  }

  Future<void> _belegOeffnen() async {
    final pfad = _rechnung?.belegPfad;
    if (pfad == null) return;
    try {
      final url = await EingangsrechnungRepository.signedBelegUrl(pfad);
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _snack('Beleg konnte nicht geöffnet werden');
      }
    } catch (e) {
      _snack('Fehler: $e');
    }
  }

  Future<void> _pickFaelligkeit() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _faelligkeit ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _faelligkeit = picked);
    }
  }

  // ---------------------------------------------------------------------------
  // Helfer
  // ---------------------------------------------------------------------------

  static String? _trimOrNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  static double _parseBetrag(String s) {
    final t = s.trim().replaceAll(',', '.');
    return double.tryParse(t) ?? 0;
  }

  static double _parseMwst(String s) {
    final t = s.trim().replaceAll(',', '.');
    return double.tryParse(t) ?? 0;
  }

  static String? _dateOnly(DateTime? d) {
    if (d == null) return null;
    return d.toIso8601String().substring(0, 10);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _zurueck() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/buchhaltung/eingangsrechnungen');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eingangsrechnung')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ladeFehler != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_ladeFehler!, textAlign: TextAlign.center),
                  ),
                )
              : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final e = _rechnung!;
    final konten = ref
        .watch(kontenProvider)
        .where((k) => k.istAktiv)
        .toList()
      ..sort((a, b) => a.kontonummer.compareTo(b.kontonummer));

    final niedrigeKonfidenz = e.konfidenz != null && e.konfidenz! < 0.85;

    return AbsorbPointer(
      absorbing: _busy,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _qrBadge(e),
            if (niedrigeKonfidenz) ...[
              _konfidenzBadge(e.konfidenz!),
              const SizedBox(height: 16),
            ],

            // Beleg öffnen
            if (e.belegPfad != null) ...[
              _outlineButton(
                label: e.belegDateiname ?? 'Beleg öffnen',
                icon: Icons.picture_as_pdf,
                onTap: _belegOeffnen,
              ),
              const SizedBox(height: 20),
            ],

            _label('Aussteller'),
            TextField(
              controller: _ausstellerCtrl,
              decoration: const InputDecoration(hintText: 'Lieferant / Firma'),
            ),
            const SizedBox(height: 16),

            _label('IBAN (Lieferant)'),
            TextField(
              controller: _ibanCtrl,
              decoration: const InputDecoration(hintText: 'CHxx …'),
            ),
            const SizedBox(height: 16),

            _label('QR-/Zahlungsreferenz'),
            TextField(
              controller: _referenzCtrl,
              decoration: const InputDecoration(hintText: 'Referenznummer'),
            ),
            const SizedBox(height: 16),

            _label('Referenz-Typ'),
            DropdownButtonFormField<String>(
              initialValue: _referenzTyp,
              items: const [
                DropdownMenuItem(value: 'QRR', child: Text('QRR (QR-Referenz)')),
                DropdownMenuItem(
                    value: 'SCOR', child: Text('SCOR (Creditor Reference)')),
                DropdownMenuItem(value: 'NON', child: Text('NON (keine)')),
              ],
              onChanged: (v) => setState(() => _referenzTyp = v ?? 'NON'),
            ),
            const SizedBox(height: 16),

            _label('Betrag (brutto, CHF)'),
            TextField(
              controller: _betragCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(hintText: '0.00'),
            ),
            const SizedBox(height: 16),

            _label('MwSt-Satz (%)'),
            _mwstSatzFeld(),
            const SizedBox(height: 12),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('MwSt-pflichtig (Vorsteuerabzug)'),
              value: _mwstPflichtig,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => setState(() => _mwstPflichtig = v),
            ),
            const SizedBox(height: 4),

            _label('Fälligkeit'),
            _faelligkeitFeld(),
            const SizedBox(height: 16),

            _label('Aufwandskonto (Pflicht zum Buchen)'),
            _aufwandskontoDropdown(konten),
            const SizedBox(height: 16),

            _label('Vorsteuerkonto'),
            _vorsteuerDropdown(),
            const SizedBox(height: 28),

            // Aktionen
            if (e.status == 'bezahlt' || e.bezahltAm != null) ...[
              _hinweisBanner(
                Icons.check_circle,
                AppColors.primary,
                e.bezahltAm != null
                    ? 'Bezahlt am ${_dateFormat.format(e.bezahltAm!)} (camt-Abgleich).'
                    : 'Bezahlt (camt-Abgleich).',
              ),
              const SizedBox(height: 16),
              _dangerButton(
                label: 'Zahlung rückgängig',
                icon: Icons.undo,
                onTap: _zahlungRueckgaengig,
              ),
            ] else ...[
              _primaryButton(
                label: 'Bestätigen & buchen',
                icon: Icons.check_circle,
                onTap: _bestaetigenUndBuchen,
              ),
              const SizedBox(height: 12),
              _outlineButton(
                label: 'Nur ablegen (Info)',
                icon: Icons.inventory_2_outlined,
                onTap: _nurAblegen,
              ),
              const SizedBox(height: 12),
              _dangerButton(
                label: 'Verwerfen',
                icon: Icons.delete_outline,
                onTap: _verwerfen,
              ),
            ],

            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Banner zum QR-Abgleich: rot bei Abweichung QR ↔ Texterkennung, gelb wenn
  /// kein QR gelesen wurde, sonst nichts (saubere Übereinstimmung).
  Widget _qrBadge(Eingangsrechnung e) {
    if (e.qrAbweichungen != null && e.qrAbweichungen!.isNotEmpty) {
      return _hinweisBanner(
        Icons.error_outline,
        AppColors.error,
        'QR ↔ Texterkennung weichen ab: ${e.qrAbweichungen}. '
        'Es gelten die QR-Werte (prüfziffer-gesichert).',
      );
    }
    if (!e.qrGelesen) {
      return _hinweisBanner(
        Icons.warning_amber_rounded,
        AppColors.warning,
        'Kein QR-Code gelesen – IBAN/Referenz stammen aus der Texterkennung. '
        'Bitte sorgfältig prüfen.',
      );
    }
    return const SizedBox.shrink();
  }

  Widget _hinweisBanner(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _konfidenzBadge(double konfidenz) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Niedrige Konfidenz '
              '(${(konfidenz * 100).toStringAsFixed(0)}%). '
              'Bitte Werte prüfen.',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mwstSatzFeld() {
    const saetze = ['8.1', '3.8', '2.6', '0'];
    final aktuell = _mwstCtrl.text.trim();
    final istBekannt = saetze.contains(aktuell);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _mwstCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(hintText: 'z.B. 8.1'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: istBekannt ? aktuell : null,
          hint: const Text('Satz'),
          items: const [
            DropdownMenuItem(value: '8.1', child: Text('8.1%')),
            DropdownMenuItem(value: '3.8', child: Text('3.8%')),
            DropdownMenuItem(value: '2.6', child: Text('2.6%')),
            DropdownMenuItem(value: '0', child: Text('0%')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _mwstCtrl.text = v;
              // Vorsteuer-Vorbelegung an MwSt koppeln.
              final satz = double.tryParse(v) ?? 0;
              _vorsteuerKonto = satz > 0 ? (_vorsteuerKonto ?? 1171) : null;
            });
          },
        ),
      ],
    );
  }

  Widget _faelligkeitFeld() {
    return GestureDetector(
      onTap: _pickFaelligkeit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(Icons.event, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _faelligkeit != null
                    ? _dateFormat.format(_faelligkeit!)
                    : 'Kein Datum',
                style: TextStyle(
                  color: _faelligkeit != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (_faelligkeit != null)
              GestureDetector(
                onTap: () => setState(() => _faelligkeit = null),
                child: Icon(Icons.clear,
                    size: 18, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _aufwandskontoDropdown(List<Konto> konten) {
    return DropdownButtonFormField<int>(
      initialValue: _aufwandskonto,
      isExpanded: true,
      hint: const Text('Konto wählen …'),
      items: konten
          .map((k) => DropdownMenuItem<int>(
                value: k.kontonummer,
                child: Text(
                  '${k.kontonummer} ${k.bezeichnung}',
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: (v) => setState(() => _aufwandskonto = v),
    );
  }

  Widget _vorsteuerDropdown() {
    return DropdownButtonFormField<int?>(
      initialValue: _vorsteuerKonto,
      isExpanded: true,
      items: const [
        DropdownMenuItem<int?>(
          value: 1170,
          child: Text('1170 Vorsteuer Material/DL'),
        ),
        DropdownMenuItem<int?>(
          value: 1171,
          child: Text('1171 Vorsteuer übr. Betriebsaufwand'),
        ),
        DropdownMenuItem<int?>(
          value: null,
          child: Text('Kein Vorsteuerabzug'),
        ),
      ],
      onChanged: (v) => setState(() => _vorsteuerKonto = v),
    );
  }

  // ---------------------------------------------------------------------------
  // UI-Bausteine (GestureDetector statt Material-Buttons wg. CanvasKit)
  // ---------------------------------------------------------------------------

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlineButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dangerButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

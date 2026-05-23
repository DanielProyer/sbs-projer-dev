// TEMPORÄRER SCREEN
// Zweck: Rechnungs-Backlog ab 18.02.2026 nachträglich per Mail an Kunden versenden.
// Wird nach ca. 1 Woche entfernt — der reguläre Mail-Versand erfolgt dann direkt
// beim Service-Abschluss.
//
// Zum Entfernen: diese Datei löschen, Route in router.dart entfernen,
// Tile in buchhaltung_dashboard_screen.dart entfernen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

class RechnungenNachversandScreen extends ConsumerStatefulWidget {
  const RechnungenNachversandScreen({super.key});

  @override
  ConsumerState<RechnungenNachversandScreen> createState() =>
      _RechnungenNachversandScreenState();
}

class _RechnungenNachversandScreenState
    extends ConsumerState<RechnungenNachversandScreen> {
  static final _dateFormat = DateFormat('dd.MM.yyyy');
  static const _stichtag = '2026-02-18';

  List<_NachversandItem> _items = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      // Direkte Supabase-Query: Rechnung + Betrieb + Rechnungsadresse
      // Filter: rechnungstyp=kundenrechnung, rechnungsdatum>=Stichtag,
      //         betrieb.rechnungsstellung='rechnung_mail'
      final rows = await SupabaseService.client
          .from('rechnungen')
          .select(
              'id, rechnungsnummer, rechnungsdatum, betrag_brutto, versendet_am, pdf_url, betrieb_id, '
              'betriebe!inner(name, ort, rechnungsstellung, '
              'betrieb_rechnungsadressen(email))')
          .eq('rechnungstyp', 'kundenrechnung')
          .gte('rechnungsdatum', _stichtag)
          .eq('betriebe.rechnungsstellung', 'rechnung_mail')
          .order('rechnungsdatum', ascending: false);

      final items = <_NachversandItem>[];
      for (final row in rows as List) {
        final m = row as Map<String, dynamic>;
        final betrieb = (m['betriebe'] as Map<String, dynamic>?) ?? const {};
        final adressen =
            (betrieb['betrieb_rechnungsadressen'] as List?) ?? const <dynamic>[];
        final email = adressen.isNotEmpty
            ? (adressen.first as Map<String, dynamic>)['email'] as String?
            : null;

        items.add(_NachversandItem(
          id: m['id'] as String,
          rechnungsnummer: m['rechnungsnummer'] as String? ?? '-',
          datum: DateTime.parse(m['rechnungsdatum'].toString()),
          betragBrutto:
              double.tryParse(m['betrag_brutto']?.toString() ?? '') ?? 0,
          versendetAm: m['versendet_am'] != null
              ? DateTime.parse(m['versendet_am'].toString())
              : null,
          pdfUrl: m['pdf_url'] as String?,
          betriebName: (betrieb['name'] as String?) ?? '?',
          betriebOrt: betrieb['ort'] as String?,
          emailController: TextEditingController(text: email ?? ''),
        ));
      }

      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openPdf(_NachversandItem item) async {
    if (item.pdfUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine PDF-URL vorhanden')),
      );
      return;
    }
    await launchUrl(Uri.parse(item.pdfUrl!),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _sendMail(_NachversandItem item) async {
    final empfaenger = item.emailController.text.trim();
    if (empfaenger.isEmpty) return;

    setState(() => item.sending = true);
    try {
      final datumStr =
          '${item.datum.day}. ${_monatName(item.datum.month)} ${item.datum.year}';
      final betriebLabel = item.betriebOrt != null && item.betriebOrt!.isNotEmpty
          ? '${item.betriebName} ${item.betriebOrt}'
          : item.betriebName;
      final betragRounded = (item.betragBrutto * 20).roundToDouble() / 20;
      final betragStr = betragRounded.toStringAsFixed(2);

      // MailConfig bewusst umgangen — direkter Versand an eingegebene Adresse.
      await SupabaseService.client.functions.invoke(
        'send-rechnung-mail',
        body: {
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
          'rechnungId': item.id,
          'userId': SupabaseService.dataUserId,
        },
      );

      // Nur versendet_am + versandart setzen (kein Status-Wechsel).
      try {
        await RechnungRepository.update(item.id, {
          'versendet_am': DateTime.now().toIso8601String().split('T').first,
          'versandart': 'rechnung_mail',
        });
        if (mounted) {
          setState(() {
            item.versendetAm = DateTime.now();
            item.sending = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Mail versendet an $empfaenger')),
          );
        }
      } catch (dbErr) {
        if (mounted) {
          setState(() => item.sending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.warning,
              content: Text(
                'Mail versendet, aber DB-Update fehlgeschlagen: $dbErr',
                style: const TextStyle(color: Colors.white),
              ),
              duration: const Duration(seconds: 8),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => item.sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Mail-Versand fehlgeschlagen: $e',
                style: const TextStyle(color: Colors.white)),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.emailController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechnungen nachversenden'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Neu laden',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Fehler beim Laden: $_loadError'),
                  ),
                )
              : Column(
                  children: [
                    // Warn-Banner
                    Container(
                      width: double.infinity,
                      color: AppColors.error.withAlpha(25),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, color: AppColors.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Temporärer Nachversand. Mails gehen DIREKT an die eingegebenen Kunden-Adressen — kein Test-Modus. '
                              '${_items.length} Rechnungen seit ${_dateFormat.format(DateTime.parse(_stichtag))}.',
                              style: const TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _items.isEmpty
                          ? const Center(child: Text('Keine Rechnungen gefunden'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _items.length,
                              itemBuilder: (context, i) =>
                                  _row(context, _items[i]),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _row(BuildContext context, _NachversandItem item) {
    final versendet = item.versendetAm != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.rechnungsnummer,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.betriebName}${item.betriebOrt != null && item.betriebOrt!.isNotEmpty ? " · ${item.betriebOrt}" : ""}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        '${_dateFormat.format(item.datum)} · ${_round5Rp(item.betragBrutto).toStringAsFixed(2)} CHF',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (versendet)
                  Chip(
                    avatar: Icon(Icons.check_circle,
                        size: 16, color: AppColors.success),
                    label: Text(
                        'versendet ${_dateFormat.format(item.versendetAm!)}'),
                    backgroundColor: AppColors.success.withAlpha(25),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: item.emailController,
                    decoration: const InputDecoration(
                      labelText: 'Empfänger E-Mail',
                      isDense: true,
                      prefixIcon: Icon(Icons.mail_outline, size: 18),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'PDF anzeigen',
                  onPressed: item.pdfUrl != null ? () => _openPdf(item) : null,
                ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  icon: item.sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: Text(versendet ? 'Erneut senden' : 'Senden'),
                  onPressed: item.sending ||
                          item.emailController.text.trim().isEmpty
                      ? null
                      : () => _sendMail(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Schweizer 5-Rappen-Rundung (0.05 CHF).
  static double _round5Rp(double v) => (v * 20).roundToDouble() / 20;

  static String _monatName(int m) {
    const namen = [
      '',
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];
    return namen[m];
  }
}

class _NachversandItem {
  final String id;
  final String rechnungsnummer;
  final DateTime datum;
  final double betragBrutto;
  DateTime? versendetAm;
  final String? pdfUrl;
  final String betriebName;
  final String? betriebOrt;
  final TextEditingController emailController;
  bool sending = false;

  _NachversandItem({
    required this.id,
    required this.rechnungsnummer,
    required this.datum,
    required this.betragBrutto,
    required this.versendetAm,
    required this.pdfUrl,
    required this.betriebName,
    required this.betriebOrt,
    required this.emailController,
  });
}

// TEMPORÄRER SCREEN
// Zweck: Rechnungs-Backlog ab 18.02.2026 nachträglich per Mail an Kunden versenden.
//
// NICHT VOR SCHARFSTELLUNG ENTFERNEN (Stand 30.05.2026):
// Während der Testphase (reinigungScharf=false) gehen automatische Versände nur
// an den Test-Empfänger. Der Backlog hier muss erhalten bleiben, bis reinigungScharf
// auf true steht und die Rechnungen von hier aus an die echten Kunden versendet wurden.
// Frühestens entfernen ca. 06.06.2026, nach Scharfstellung + Abarbeitung des Backlogs.
//
// Zum Entfernen: diese Datei löschen, Route in router.dart entfernen,
// Tile in buchhaltung_dashboard_screen.dart entfernen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
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

  /// Rechnungen, die bereits manuell (ausserhalb dieses Screens) versendet wurden
  /// und daher NICHT mehr in der Nachversand-Liste erscheinen sollen.
  /// versandart bewusst NICHT geändert, da das Mahnwesen darauf basiert.
  static const _bereitsManuellVersendet = <String>{
    '7eb327d8-5698-42dd-b6e1-b2e12d455897', // Piaggio Dosch · 2026-05-0615 · 08.05.2026
  };

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
      // Query 1: Rechnungen + Betrieb-Stammdaten (Inner-Join via rechnungsstellung)
      final rechnungRows = await SupabaseService.client
          .from('rechnungen')
          .select(
              'id, rechnungsnummer, rechnungsdatum, betrag_brutto, versendet_am, pdf_url, betrieb_id, '
              'betriebe!inner(name, ort, rechnungsstellung, email)')
          .eq('rechnungstyp', 'kundenrechnung')
          .gte('rechnungsdatum', _stichtag)
          .eq('betriebe.rechnungsstellung', 'rechnung_mail')
          .order('rechnungsdatum', ascending: false);

      // Betriebe-IDs sammeln
      final betriebIds = <String>{};
      for (final row in rechnungRows as List) {
        final id = (row as Map)['betrieb_id'];
        if (id is String) betriebIds.add(id);
      }

      // Query 2: Rechnungsadressen für diese Betriebe
      final emailByBetrieb = <String, String>{};
      if (betriebIds.isNotEmpty) {
        final adrRows = await SupabaseService.client
            .from('betrieb_rechnungsadressen')
            .select('betrieb_id, email')
            .inFilter('betrieb_id', betriebIds.toList());
        for (final row in adrRows as List) {
          final m = row as Map;
          final bid = m['betrieb_id'];
          final mail = m['email'];
          if (bid is String && mail is String && mail.isNotEmpty) {
            emailByBetrieb[bid] = mail;
          }
        }
      }

      // Rechnung-IDs sammeln (für Protokoll-Lookup)
      final rechnungIds = <String>[];
      for (final row in rechnungRows) {
        final id = (row as Map)['id'];
        if (id != null) rechnungIds.add(id.toString());
      }

      // Query 3: Protokoll-Pfade über rechnungs_positionen (service_typ='reinigung')
      // -> reinigungen.protokoll_foto_pfad. Damit das Reinigungsprotokoll mitgeschickt wird.
      final protokollByRechnung = <String, String>{};
      if (rechnungIds.isNotEmpty) {
        final posRows = await SupabaseService.client
            .from('rechnungs_positionen')
            .select('rechnung_id, service_id')
            .inFilter('rechnung_id', rechnungIds)
            .eq('service_typ', 'reinigung');
        final serviceIdByRechnung = <String, String>{};
        final serviceIds = <String>[];
        for (final row in posRows as List) {
          final m = row as Map;
          final rid = m['rechnung_id']?.toString();
          final sid = m['service_id']?.toString();
          if (rid != null &&
              sid != null &&
              sid.isNotEmpty &&
              !serviceIdByRechnung.containsKey(rid)) {
            serviceIdByRechnung[rid] = sid;
            serviceIds.add(sid);
          }
        }
        if (serviceIds.isNotEmpty) {
          final reinRows = await SupabaseService.client
              .from('reinigungen')
              .select('id, protokoll_foto_pfad')
              .inFilter('id', serviceIds);
          final protokollByService = <String, String>{};
          for (final row in reinRows as List) {
            final m = row as Map;
            final sid = m['id']?.toString();
            final pfad = m['protokoll_foto_pfad']?.toString();
            if (sid != null && pfad != null && pfad.isNotEmpty) {
              protokollByService[sid] = pfad;
            }
          }
          serviceIdByRechnung.forEach((rid, sid) {
            final pfad = protokollByService[sid];
            if (pfad != null) protokollByRechnung[rid] = pfad;
          });
        }
      }

      // Items bauen — komplett defensiv via .toString()
      // Email-Quelle: 1. betrieb_rechnungsadressen.email  2. fallback: betriebe.email
      final items = <_NachversandItem>[];
      for (final row in rechnungRows) {
        final m = row as Map;
        final rechnungId = m['id'].toString();
        // Bereits manuell versendete Rechnungen ausblenden
        if (_bereitsManuellVersendet.contains(rechnungId)) continue;
        final betrieb = (m['betriebe'] as Map?) ?? const {};
        final betriebId = m['betrieb_id']?.toString() ?? '';
        final fallbackEmail = betrieb['email']?.toString();
        final email = emailByBetrieb[betriebId] ??
            (fallbackEmail != null && fallbackEmail.isNotEmpty
                ? fallbackEmail
                : '');
        items.add(_NachversandItem(
          id: rechnungId,
          rechnungsnummer: m['rechnungsnummer']?.toString() ?? '-',
          datum: DateTime.parse(m['rechnungsdatum'].toString()),
          betragBrutto:
              double.tryParse(m['betrag_brutto']?.toString() ?? '') ?? 0,
          // versendet_am aus DB übernehmen, damit die "versendet"-Markierung
          // auch nach Reload/App-Neustart erhalten bleibt (seit Scharfstellung
          // sind die Werte zuverlässig, da echt an Kunden versendet wurde).
          versendetAm: m['versendet_am'] != null
              ? DateTime.tryParse(m['versendet_am'].toString())
              : null,
          pdfUrl: m['pdf_url']?.toString(),
          betriebName: betrieb['name']?.toString() ?? '?',
          betriebOrt: betrieb['ort']?.toString(),
          protokollFotoPfad: protokollByRechnung[rechnungId],
          emailController: TextEditingController(text: email),
        ));
      }

      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[Nachversand] Load-Fehler: $e\n$st');
      if (mounted) {
        setState(() {
          _loadError = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openPdf(_NachversandItem item) async {
    try {
      // Frische signed URL holen (gespeicherte pdf_url läuft nach 1h ab)
      final url = await RechnungPdfStorage.getSignedUrl(item.id);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF konnte nicht geladen werden: $e')),
        );
      }
    }
  }

  Future<void> _sendMail(_NachversandItem item) async {
    final empfaenger = item.emailController.text.trim();
    if (empfaenger.isEmpty) return;

    // MailConfig respektieren: in der Testphase (reinigungScharf=false) geht die
    // Mail an den Test-Empfänger, erst nach Scharfstellung an die Kundenadresse.
    final to = MailConfig.empfaenger(empfaenger, bereich: 'reinigung');

    setState(() => item.sending = true);
    try {
      final datumStr =
          '${item.datum.day}. ${_monatName(item.datum.month)} ${item.datum.year}';
      final betriebLabel = item.betriebOrt != null && item.betriebOrt!.isNotEmpty
          ? '${item.betriebName} ${item.betriebOrt}'
          : item.betriebName;
      final betragRounded = (item.betragBrutto * 20).roundToDouble() / 20;
      final betragStr = betragRounded.toStringAsFixed(2);

      await SupabaseService.client.functions.invoke(
        'send-rechnung-mail',
        body: {
          'to': to,
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
          if (item.protokollFotoPfad != null)
            'protokollFotoPfad': item.protokollFotoPfad,
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
            SnackBar(content: Text('Mail versendet an $to')),
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
                    // Modus-Banner: spiegelt MailConfig wider
                    Builder(builder: (_) {
                      final scharf = MailConfig.reinigungScharf &&
                          !MailConfig.testModus;
                      final farbe =
                          scharf ? AppColors.error : AppColors.warning;
                      final text = scharf
                          ? 'SCHARF: Mails gehen DIREKT an die eingegebenen Kunden-Adressen. '
                              '${_items.length} Rechnungen seit ${_dateFormat.format(DateTime.parse(_stichtag))}.'
                          : 'TESTMODUS: Mails gehen an ${MailConfig.testEmpfaenger}, NICHT an die Kunden. '
                              '${_items.length} Rechnungen seit ${_dateFormat.format(DateTime.parse(_stichtag))}.';
                      return Container(
                        width: double.infinity,
                        color: farbe.withAlpha(25),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber, color: farbe),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                    color: farbe,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
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
            const SizedBox(height: 12),
            TextField(
              controller: item.emailController,
              decoration: const InputDecoration(
                labelText: 'Empfänger E-Mail',
                isDense: true,
                prefixIcon: Icon(Icons.mail_outline, size: 20),
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 24),
                    label: const Text('PDF anzeigen',
                        style: TextStyle(fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed:
                        item.pdfUrl != null ? () => _openPdf(item) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: item.sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Icon(Icons.send, size: 22),
                    label: Text(versendet ? 'Erneut senden' : 'Mail senden',
                        style: const TextStyle(fontSize: 15)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: item.sending ||
                            item.emailController.text.trim().isEmpty
                        ? null
                        : () => _sendMail(item),
                  ),
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
  final String? protokollFotoPfad;
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
    required this.protokollFotoPfad,
    required this.emailController,
  });
}

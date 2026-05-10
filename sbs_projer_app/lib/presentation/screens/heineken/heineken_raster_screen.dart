import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/bierleitung_repository.dart';
import 'package:sbs_projer_app/data/repositories/kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/region_repository.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';
import 'package:sbs_projer_app/services/pdf/raster_pdf_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HeinekenRasterScreen extends ConsumerStatefulWidget {
  const HeinekenRasterScreen({super.key});

  @override
  ConsumerState<HeinekenRasterScreen> createState() =>
      _HeinekenRasterScreenState();
}

class _HeinekenRasterScreenState extends ConsumerState<HeinekenRasterScreen> {
  int _jahr = DateTime.now().year;
  bool _loading = false;
  String? _status;
  Uint8List? _pdfBytes;

  Future<void> _generateRaster() async {
    setState(() {
      _loading = true;
      _status = 'Lade Betriebe...';
    });

    try {
      final allBetriebe = await BetriebRepository.getAll();
      final meineKunden =
          allBetriebe.where((b) => b.istMeinKunde).toList();

      setState(() => _status = 'Lade Regionen...');
      final regionen = await RegionRepository.getAll();
      final regionMap = <String, String>{};
      for (final r in regionen) {
        regionMap[r.serverId ?? r.id.toString()] = r.name;
      }

      final betriebeProRegion = <String, List<RasterBetrieb>>{};

      for (var i = 0; i < meineKunden.length; i++) {
        final b = meineKunden[i];
        setState(() => _status = 'Verarbeite ${b.name} (${i + 1}/${meineKunden.length})...');

        // Anlagen laden → Hahnen (Bierleitungen) + Rotpunkt
        final anlagen = await AnlageRepository.getByBetrieb(b.serverId ?? b.id.toString());
        int leitungenGesamt = 0;
        int kleinstesIntervallWochen = 0;

        for (final a in anlagen) {
          final leitungen = await BierleitungRepository.getByAnlage(a.serverId ?? a.id.toString());
          leitungenGesamt += leitungen.length;

          final wochen = _rhythmusZuWochen(a.reinigungRhythmus);
          if (kleinstesIntervallWochen == 0 || (wochen > 0 && wochen < kleinstesIntervallWochen)) {
            kleinstesIntervallWochen = wochen;
          }
        }

        // Rotpunkt: kleinstes Intervall > 6 Wochen
        final rotpunkt = kleinstesIntervallWochen > 6;

        // Bemerkungen: Servicezeiten + Kontakt-Tel
        final bemTeile = <String>[];
        if (b.servicezeitMorgenAb != null || b.servicezeitNachmittagAb != null) {
          if (b.servicezeitMorgenAb != null) {
            bemTeile.add('${b.servicezeitMorgenAb}–${b.servicezeitMorgenBis ?? '?'}');
          }
          if (b.servicezeitNachmittagAb != null) {
            bemTeile.add('${b.servicezeitNachmittagAb}–${b.servicezeitNachmittagBis ?? '?'}');
          }
        }
        final kontakte = await BetriebKontaktRepository.getByBetrieb(b.serverId ?? b.id.toString());
        final kontaktMitTel = kontakte.where((k) => k.telefon != null && k.telefon!.isNotEmpty).toList();
        if (kontaktMitTel.isNotEmpty) {
          bemTeile.add(kontaktMitTel.first.telefon!);
        }

        // Zahlung
        String zahlung;
        switch (b.rechnungsstellung) {
          case 'barzahlung':
            zahlung = 'BZ';
            break;
          case 'heineken':
            zahlung = 'HS';
            break;
          default:
            zahlung = 'RG';
        }

        // Reinigungen für das Jahr
        final reinigungen = await ReinigungRepository.getByBetrieb(b.serverId ?? b.id.toString());
        final reinigungenImJahr = reinigungen
            .where((r) => r.datum.year == _jahr)
            .toList();

        final reinigungenProMonat = <int, List<RasterReinigung>>{};
        for (final r in reinigungenImJahr) {
          final monat = r.datum.month;
          reinigungenProMonat.putIfAbsent(monat, () => []);
          reinigungenProMonat[monat]!.add(
            RasterReinigung(tag: r.datum.day, serviceArt: r.serviceArt),
          );
        }

        // Ferien
        final ferien = <FerienPeriode>[];
        if (!b.keineBetriebsferien) {
          if (b.ferienStart != null && b.ferienEnde != null) {
            ferien.add(FerienPeriode(b.ferienStart!, b.ferienEnde!));
          }
          if (b.ferien2Start != null && b.ferien2Ende != null) {
            ferien.add(FerienPeriode(b.ferien2Start!, b.ferien2Ende!));
          }
          if (b.ferien3Start != null && b.ferien3Ende != null) {
            ferien.add(FerienPeriode(b.ferien3Start!, b.ferien3Ende!));
          }
        }

        final regionName = b.regionId != null
            ? (regionMap[b.regionId] ?? 'Ohne Region')
            : 'Ohne Region';

        betriebeProRegion.putIfAbsent(regionName, () => []);
        betriebeProRegion[regionName]!.add(RasterBetrieb(
          weNummer: b.weNummer,
          agNummer: b.agNummer,
          name: b.name,
          rotpunkt: rotpunkt,
          strasse: b.strasse,
          plz: b.plz,
          ort: b.ort,
          hahnen: leitungenGesamt,
          telefon: b.telefon,
          bemerkungen: bemTeile.join(', '),
          zahlung: zahlung,
          regionName: regionName,
          status: b.status,
          ferien: ferien,
          keineBetriebsferien: b.keineBetriebsferien,
          reinigungenProMonat: reinigungenProMonat,
        ));
      }

      // Innerhalb jeder Region nach Name sortieren
      for (final list in betriebeProRegion.values) {
        list.sort((a, b) => a.name.compareTo(b.name));
      }

      setState(() => _status = 'Generiere PDF...');
      final pdfBytes = await RasterPdfService.generate(
        jahr: _jahr,
        betriebeProRegion: betriebeProRegion,
      );

      setState(() {
        _pdfBytes = pdfBytes;
        _loading = false;
        _status = 'Raster generiert (${(pdfBytes.length / 1024).toStringAsFixed(0)} KB)';
      });
    } catch (e, stack) {
      setState(() {
        _loading = false;
        _status = null;
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Fehler'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: SingleChildScrollView(
                child: SelectableText('$e\n\n$stack'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _sendMail() async {
    if (_pdfBytes == null) return;
    setState(() {
      _loading = true;
      _status = 'Lade Heineken-Kontakt...';
    });

    try {
      final kontakt = await KontaktRepository.getHeinekenZuweisung('raster');
      final empfaenger = MailConfig.empfaenger(kontakt?.email, bereich: 'heineken');

      // PDF in Storage hochladen
      setState(() => _status = 'Lade PDF hoch...');
      final userId = SupabaseService.dataUserId;
      final storagePath = '$userId/Raster_$_jahr.pdf';

      await SupabaseService.client.storage
          .from('raster-pdfs')
          .uploadBinary(
            storagePath,
            _pdfBytes!,
            fileOptions: const FileOptions(upsert: true, contentType: 'application/pdf'),
          );

      // Mail senden via Edge Function
      setState(() => _status = 'Sende Mail...');
      await SupabaseService.client.functions.invoke('send-raster-mail',
          body: {
            'to': empfaenger,
            'subject': 'Monatsraster $_jahr SBS Projer GmbH',
            'bodyText':
                'Hallo${kontakt?.vorname != null ? ' ${kontakt!.vorname}' : ''}\n\n'
                'Im Anhang sende ich Dir das Monatsraster $_jahr.\n\n'
                'Gruass Dani',
            'pdfBucket': 'raster-pdfs',
            'pdfPath': storagePath,
            'pdfFilename': 'Raster_$_jahr.pdf',
          });

      setState(() {
        _loading = false;
        _status = 'Mail versendet an $empfaenger';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mail versendet an $empfaenger')),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Fehler: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _download() async {
    if (_pdfBytes == null) return;
    try {
      final userId = SupabaseService.dataUserId;
      final storagePath = '$userId/Raster_$_jahr.pdf';

      await SupabaseService.client.storage
          .from('raster-pdfs')
          .uploadBinary(
            storagePath,
            _pdfBytes!,
            fileOptions: const FileOptions(upsert: true, contentType: 'application/pdf'),
          );

      final url = SupabaseService.client.storage
          .from('raster-pdfs')
          .getPublicUrl(storagePath);

      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  int _rhythmusZuWochen(String rhythmus) {
    switch (rhythmus) {
      case '4-Wochen':
        return 4;
      case '6-Wochen':
        return 6;
      case '2-Monate':
        return 8;
      case '3-Monate':
        return 12;
      case 'auf-Abruf':
        return 99;
      case 'Selbstreiniger':
        return 99;
      default:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heineken Monatsraster')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Jahr: ', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _jahr,
                  items: List.generate(5, (i) {
                    final y = DateTime.now().year - 2 + i;
                    return DropdownMenuItem(value: y, child: Text('$y'));
                  }),
                  onChanged: _loading
                      ? null
                      : (v) {
                          if (v != null) {
                            setState(() {
                              _jahr = v;
                              _pdfBytes = null;
                              _status = null;
                            });
                          }
                        },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _generateRaster,
                icon: const Icon(Icons.grid_on),
                label: const Text('Raster generieren'),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const LinearProgressIndicator(),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(_status!, style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 24),
            if (_pdfBytes != null) ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _loading ? null : _download,
                    icon: const Icon(Icons.download),
                    label: const Text('PDF herunterladen'),
                  ),
                  FilledButton.icon(
                    onPressed: _loading ? null : _sendMail,
                    icon: const Icon(Icons.send),
                    label: const Text('Mail an Heineken senden'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

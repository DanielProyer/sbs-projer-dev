// lib/presentation/screens/buchhaltung/berichte_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/bericht_datum_picker.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/bilanz_view.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/erfolgsrechnung_view.dart';
import 'package:sbs_projer_app/services/mail/bericht_mail_service.dart';
import 'package:sbs_projer_app/services/pdf/bilanz_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/erfolgsrechnung_pdf_service.dart';

class BerichteScreen extends ConsumerStatefulWidget {
  const BerichteScreen({super.key});
  @override
  ConsumerState<BerichteScreen> createState() => _BerichteScreenState();
}

class _BerichteScreenState extends ConsumerState<BerichteScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  DateTime _stichtag = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  Zeitraum _zeitraum = (von: DateTime(DateTime.now().year, 1, 1), bis: DateTime(DateTime.now().year, 12, 31));

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _pdf() async {
    try {
      if (_tab.index == 0) {
        final b = await ref.read(bilanzStichtagProvider(_stichtag).future);
        final bytes = await BilanzPdfService.generate(b, _stichtag);
        await Printing.layoutPdf(onLayout: (_) => bytes);
      } else {
        final er = await ref.read(erfolgsrechnungZeitraumProvider(_zeitraum).future);
        final konten = await ref.read(erKontenAufstellungProvider(_zeitraum).future);
        final bytes = await ErfolgsrechnungPdfService.generate(er, konten, _zeitraum);
        await Printing.layoutPdf(onLayout: (_) => bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF-Fehler: $e')));
      }
    }
  }

  Future<void> _mail() async {
    final istBilanz = _tab.index == 0;
    final was = istBilanz ? 'Bilanz' : 'Erfolgsrechnung';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$was senden'),
        content: Text('$was als PDF an ${BerichtMailService.empfaenger} senden?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Senden')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final Uint8List bytes;
      final String filename;
      if (istBilanz) {
        final b = await ref.read(bilanzStichtagProvider(_stichtag).future);
        bytes = await BilanzPdfService.generate(b, _stichtag);
        filename = 'Bilanz.pdf';
      } else {
        final er = await ref.read(erfolgsrechnungZeitraumProvider(_zeitraum).future);
        final konten = await ref.read(erKontenAufstellungProvider(_zeitraum).future);
        bytes = await ErfolgsrechnungPdfService.generate(er, konten, _zeitraum);
        filename = 'Erfolgsrechnung.pdf';
      }
      await BerichtMailService.send(
        subject: '$was SBS Projer GmbH',
        bodyText: 'Im Anhang die $was.\n\nSBS Projer GmbH',
        filename: filename,
        pdf: bytes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$was gesendet an ${BerichtMailService.empfaenger}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mail-Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilanz & Erfolgsrechnung'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Per Mail senden',
            onPressed: _mail,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF',
            onPressed: _pdf,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Bilanz'), Tab(text: 'Erfolgsrechnung')],
        ),
      ),
      body: Column(
        children: [
          AnimatedBuilder(
            animation: _tab,
            builder: (context, _) => _tab.index == 0
                ? StichtagPicker(
                    stichtag: _stichtag,
                    onChanged: (d) => setState(() => _stichtag = d),
                  )
                : ZeitraumPicker(
                    zeitraum: _zeitraum,
                    onChanged: (z) => setState(() => _zeitraum = z),
                  ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                BilanzView(stichtag: _stichtag),
                ErfolgsrechnungView(zeitraum: _zeitraum),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

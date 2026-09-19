// lib/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/filter_chrome.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_detektoren_provider.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/data/models/abschreibung_lauf.dart';
import 'package:sbs_projer_app/presentation/providers/abschreibung_providers.dart';

class MwstAbrechnungScreen extends ConsumerStatefulWidget {
  const MwstAbrechnungScreen({super.key});
  @override
  ConsumerState<MwstAbrechnungScreen> createState() =>
      _MwstAbrechnungScreenState();
}

class _MwstAbrechnungScreenState extends ConsumerState<MwstAbrechnungScreen> {
  int _jahr = DateTime.now().year;
  late int _quartal = ((DateTime.now().month - 1) ~/ 3) + 1;

  static const _abgabefristen = {
    1: '31.05.',
    2: '31.08.',
    3: '30.11.',
    4: '28.02.',
  };

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(mwstQuartalDetailProvider(_jahr));
    return Scaffold(
      appBar: AppBar(
        title: const Text('MwSt-Abrechnung'),
        actions: [
          TextButton(
            onPressed: _pickJahr,
            child: FilterChrome(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_jahr',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (rows) {
          final entgeltsminderungen =
              (ref.watch(abschreibungLaeufeProvider).valueOrNull ??
                      const <AbschreibungLauf>[])
                  .where(
                    (l) =>
                        l.gebucht &&
                        l.mwstJahr == _jahr &&
                        l.mwstQuartal == _quartal,
                  )
                  .toList();
          final sel = rows.firstWhere(
            (r) => r['quartal'] == _quartal,
            orElse: () => <String, dynamic>{},
          );
          final umsatz = _d(sel['umsatz']);
          final umsatzsteuer = _d(sel['umsatzsteuer']);
          final vstMaterial = _d(sel['vorsteuer_material']);
          final vstBetrieb = _d(sel['vorsteuer_betrieb']);
          final netto = _d(sel['netto_mwst_schuld']);
          final fristJahr = _quartal == 4 ? _jahr + 1 : _jahr;
          final frist = '${_abgabefristen[_quartal]}$fristJahr';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Q1')),
                  ButtonSegment(value: 2, label: Text('Q2')),
                  ButtonSegment(value: 3, label: Text('Q3')),
                  ButtonSegment(value: 4, label: Text('Q4')),
                ],
                selected: {_quartal},
                onSelectionChanged: (s) => setState(() => _quartal = s.first),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q$_quartal $_jahr',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _z('Umsatz (Ziff. 200)', umsatz, AppColors.success),
                      _z(
                        'Umsatzsteuer (Ziff. 382)',
                        umsatzsteuer,
                        AppColors.error,
                      ),
                      // Abschreibungsläufe, deren MWST-Rückholung in dieses
                      // Quartal gehört (Ziff. 235 Entgeltsminderung). Die
                      // Umsatzsteuer oben ist um die Rückholung schon
                      // reduziert (2200 im Soll); im Formular wird sie über
                      // Ziff. 235 hergeleitet — beides muss zusammen.
                      for (final l in entgeltsminderungen) ...[
                        _z(
                          'Entgeltsminderung (Ziff. 235)',
                          l.netto,
                          AppColors.info,
                        ),
                        _z(
                          'Rückholung ${l.satz} %'
                          '${_formularZeile(l.satz)}',
                          l.mwst,
                          AppColors.success,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Abschreibung Jahrgang '
                            '${l.jahrgaenge.join(', ')} '
                            '(Abschluss ${l.geschaeftsjahr}, '
                            '${l.anzahl} Rechnungen)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      _z(
                        'Vorsteuer Material (Ziff. 400)',
                        vstMaterial,
                        AppColors.success,
                      ),
                      _z(
                        'Vorsteuer Betrieb (Ziff. 405)',
                        vstBetrieb,
                        AppColors.success,
                      ),
                      const Divider(),
                      _z(
                        'Zu bezahlen (Ziff. 500)',
                        netto,
                        netto > 0 ? AppColors.error : AppColors.success,
                        bold: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Abgabefrist: $frist',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (btnContext) {
                          // Aufgaben-Marker: MWST-Erinnerung für dieses Quartal erledigen.
                          final key = 'mwst:$_jahr-Q$_quartal';
                          final liste =
                              ref.watch(aufgabenListeProvider).valueOrNull ??
                              const <AufgabenEintrag>[];
                          final offen = liste.any((a) => a.key == key);
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              icon: Icon(
                                offen ? Icons.check_circle_outline : Icons.undo,
                                size: 18,
                              ),
                              label: Text(
                                offen
                                    ? 'Als abgerechnet markieren'
                                    : 'Markierung zurücknehmen',
                              ),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(
                                  btnContext,
                                );
                                try {
                                  if (offen) {
                                    await AufgabenRepository.markerSetzen(key);
                                  } else {
                                    await AufgabenRepository.markerLoeschen(
                                      key,
                                    );
                                  }
                                } catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Fehler: ${kurzeFehlermeldung(e)}',
                                      ),
                                    ),
                                  );
                                }
                                ref.invalidate(aufgabenZeilenProvider);
                                ref.invalidate(aufgabenListeProvider);
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _pickJahr() {
    final jetzt = DateTime.now().year;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Jahr wählen'),
        children: [
          for (int y = jetzt; y >= 2019; y--)
            SimpleDialogOption(
              onPressed: () {
                setState(() => _jahr = y);
                Navigator.pop(ctx);
              },
              child: Text(
                '$y',
                style: TextStyle(
                  fontWeight: y == _jahr ? FontWeight.w700 : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  /// Zeile im ESTV-Formular (Stand Q2/2026): 302 = 7.7 %, 303 = 8.1 %.
  static String _formularZeile(double satz) => switch (satz) {
    7.7 => ' (Zeile 302)',
    8.1 => ' (Zeile 303)',
    _ => '',
  };

  Widget _z(String label, double betrag, Color color, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${chf(betrag)} CHF',
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      );
}

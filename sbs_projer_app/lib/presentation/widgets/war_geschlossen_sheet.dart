import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/war_geschlossen.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_ferien_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/wegpunkt_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

enum _WgGrund { betriebsferien, ruhetag, anderes }

/// Öffnet das «War geschlossen»-Sheet (Spec 2026-07-31, Baustein A).
///
/// Daniel stand vor einem geschlossenen Betrieb — bisher blieb das spurlos:
/// der Betrieb ist morgen wieder «unbekannt». Das Sheet fragt kurz nach dem
/// Grund, trägt ihn — je nach Antwort — an den Betriebsstammdaten nach und
/// stempelt in jedem Fall einen Wegpunkt (`quelle: 'vergeblich'`), damit die
/// Leerfahrt später auswertbar ist.
///
/// Ausdrücklich KEINE automatische Neuplanung (Entscheid Daniel): Der Besuch
/// verschwindet nur aus dem TAGESPLAN, bleibt aber in der Fällig-Liste.
Future<void> zeigeWarGeschlossenSheet(
  BuildContext context, {
  required String eintragId,
  required BetriebLocal betrieb,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => WarGeschlossenSheet(eintragId: eintragId, betrieb: betrieb),
  );
}

class WarGeschlossenSheet extends ConsumerStatefulWidget {
  final String eintragId;
  final BetriebLocal betrieb;

  const WarGeschlossenSheet({
    super.key,
    required this.eintragId,
    required this.betrieb,
  });

  @override
  ConsumerState<WarGeschlossenSheet> createState() =>
      _WarGeschlossenSheetState();
}

class _WarGeschlossenSheetState extends ConsumerState<WarGeschlossenSheet> {
  _WgGrund? _grund;
  late DateTime _ferienVon;
  late DateTime _ferienBis;
  late String _ruhetag;
  final _notizCtrl = TextEditingController();
  bool _speichert = false;

  @override
  void initState() {
    super.initState();
    final fenster = standardFerienfenster();
    _ferienVon = fenster.von;
    _ferienBis = fenster.bis;
    _ruhetag = heutigesWochentagKuerzel();
  }

  @override
  void dispose() {
    _notizCtrl.dispose();
    super.dispose();
  }

  Future<void> _datumWaehlen({required bool istVon}) async {
    final gewaehlt = await showDatePicker(
      context: context,
      initialDate: istVon ? _ferienVon : _ferienBis,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (gewaehlt == null) return;
    setState(() {
      if (istVon) {
        _ferienVon = gewaehlt;
        if (_ferienBis.isBefore(_ferienVon)) _ferienBis = _ferienVon;
      } else {
        _ferienBis = gewaehlt;
      }
    });
  }

  Future<void> _speichern() async {
    final grund = _grund;
    if (grund == null) return;
    final notiz = _notizCtrl.text.trim();

    if (grund == _WgGrund.anderes && notiz.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte kurz den Grund notieren.')),
      );
      return;
    }
    if (grund == _WgGrund.betriebsferien && _ferienBis.isBefore(_ferienVon)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bis-Datum liegt vor dem Von-Datum.')),
      );
      return;
    }

    final betrieb = widget.betrieb;
    final betriebId = betrieb.serverId;
    if (grund != _WgGrund.anderes && betriebId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Betrieb ist noch nicht synchronisiert — bitte später erneut '
            'versuchen.',
          ),
        ),
      );
      return;
    }

    setState(() => _speichert = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      switch (grund) {
        case _WgGrund.betriebsferien:
          await BetriebFerienRepository.periodeErfassen(
            betriebId: betriebId!,
            von: _ferienVon,
            bis: _ferienBis,
            quelle: 'vor_ort',
            notiz: notiz.isEmpty ? null : notiz,
          );
          betrieb.ferienBestaetigtAm = DateTime.now().toUtc();
          await BetriebRepository.save(betrieb);
          ref.invalidate(ferienPeriodenProvider);
          ref.invalidate(betriebeStreamProvider);
          break;
        case _WgGrund.ruhetag:
          betrieb.ruhetage = ruhetageErgaenzt(betrieb.ruhetage, _ruhetag);
          betrieb.ruhetageBestaetigtAm = DateTime.now().toUtc();
          await BetriebRepository.save(betrieb);
          ref.invalidate(betriebeStreamProvider);
          break;
        case _WgGrund.anderes:
          // Keine Änderung an den Betriebsstammdaten — nur der Wegpunkt
          // unten dokumentiert die Leerfahrt.
          break;
      }

      // Wegpunkt in allen drei Fällen: Zeit + GPS + Notiz. Fire-and-forget
      // (WegpunktRepository schluckt Fehler selbst) — ein fehlender
      // Standort darf das Erfassen nicht blockieren.
      unawaited(
        WegpunktRepository.stempeln(
          quelle: 'vergeblich',
          betriebId: betriebId,
          notiz: notiz.isEmpty ? null : notiz,
        ),
      );

      ref.read(tagesplanProvider.notifier).entfernen(widget.eintragId);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 4),
          content: Text('Besuch bleibt fällig — bitte neu einplanen.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _speichert = false);
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_busy,
                      size: 18,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'War geschlossen — ${widget.betrieb.name}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Was war der Grund? Damit dieselbe Leerfahrt nicht '
                  'nächstes Jahr wieder passiert.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              _GrundZeile(
                icon: Icons.beach_access_outlined,
                text: 'Betriebsferien',
                ausgewaehlt: _grund == _WgGrund.betriebsferien,
                onTap: () => setState(() => _grund = _WgGrund.betriebsferien),
              ),
              if (_grund == _WgGrund.betriebsferien) _buildFerienAuswahl(),

              _GrundZeile(
                icon: Icons.today_outlined,
                text: 'Ruhetag',
                ausgewaehlt: _grund == _WgGrund.ruhetag,
                onTap: () => setState(() => _grund = _WgGrund.ruhetag),
              ),
              if (_grund == _WgGrund.ruhetag) _buildRuhetagAuswahl(),

              _GrundZeile(
                icon: Icons.help_outline,
                text: 'Niemand da / anderes',
                ausgewaehlt: _grund == _WgGrund.anderes,
                onTap: () => setState(() => _grund = _WgGrund.anderes),
              ),

              if (_grund != null) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Text(
                    'Notiz',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _notizCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: _grund == _WgGrund.anderes
                          ? 'z.B. Chef krank, Kollege wusste nichts'
                          : 'optional, z.B. wer vor Ort war',
                    ),
                  ),
                ),
              ],

              const Divider(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GestureDetector(
                  onTap: _grund == null || _speichert ? null : _speichern,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _grund == null
                          ? AppColors.divider
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: _speichert
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Erfassen',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFerienAuswahl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _DatumFeld(
              label: 'Von',
              datum: _ferienVon,
              onTap: () => _datumWaehlen(istVon: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DatumFeld(
              label: 'Bis',
              datum: _ferienBis,
              onTap: () => _datumWaehlen(istVon: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuhetagAuswahl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in wochentagKuerzelListe)
            _TagChip(
              text: tag,
              ausgewaehlt: _ruhetag == tag,
              onTap: () => setState(() => _ruhetag = tag),
            ),
        ],
      ),
    );
  }
}

/// Auswahl-Zeile für den Grund — bewusst GestureDetector + Container statt
/// eines Radio-/Material-Buttons (CanvasKit-Regel: Material-Buttons werden
/// in Bottom-Sheets auf Web nicht zuverlässig gezeichnet).
class _GrundZeile extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool ausgewaehlt;
  final VoidCallback onTap;

  const _GrundZeile({
    required this.icon,
    required this.text,
    required this.ausgewaehlt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              ausgewaehlt
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: ausgewaehlt ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: ausgewaehlt ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatumFeld extends StatelessWidget {
  final String label;
  final DateTime datum;
  final VoidCallback onTap;

  const _DatumFeld({
    required this.label,
    required this.datum,
    required this.onTap,
  });

  String get _text =>
      '${datum.day.toString().padLeft(2, '0')}.'
      '${datum.month.toString().padLeft(2, '0')}.${datum.year}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  final bool ausgewaehlt;
  final VoidCallback onTap;

  const _TagChip({
    required this.text,
    required this.ausgewaehlt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ausgewaehlt
              ? AppColors.primary.withAlpha(20)
              : Colors.transparent,
          border: Border.all(
            color: ausgewaehlt ? AppColors.primary : AppColors.divider,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ausgewaehlt ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

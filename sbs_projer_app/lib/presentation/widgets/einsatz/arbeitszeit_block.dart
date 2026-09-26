import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/arbeit_beenden_knopf.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/presentation/widgets/zeit_auswahl.dart';

/// «HH:mm» → [TimeOfDay]; `null` bei allem, was keine Uhrzeit ist.
TimeOfDay? arbeitszeitParsen(String text) {
  final t = text.trim();
  if (!t.contains(':')) return null;
  final parts = t.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

/// [TimeOfDay] → «HH:mm».
String arbeitszeitFormatieren(TimeOfDay zeit) =>
    '${zeit.hour.toString().padLeft(2, '0')}:'
    '${zeit.minute.toString().padLeft(2, '0')}';

/// «seit HH:mm · NN min» für die laufende Arbeitszeit-Anzeige.
///
/// `null`, sobald ein Ende erfasst ist — sonst zählte die Anzeige nach dem
/// Abschluss munter weiter (Fall Sartons, 11.08.2026). Liegt der Beginn
/// scheinbar in der Zukunft, war er gestern (Arbeit über Mitternacht).
String? laufendeArbeitszeitText(String von, String bis, DateTime jetzt) {
  if (bis.trim().isNotEmpty) return null;
  final beginn = arbeitszeitParsen(von);
  if (beginn == null) return null;
  var start = DateTime(
    jetzt.year,
    jetzt.month,
    jetzt.day,
    beginn.hour,
    beginn.minute,
  );
  if (start.isAfter(jetzt)) start = start.subtract(const Duration(days: 1));
  final minuten = jetzt.difference(start).inMinutes;
  return 'seit $von · $minuten min';
}

/// Arbeitszeit-Erfassung von Störung und Montage (Analyse 25.09.2026, §2.2):
/// «Arbeit beginnen»-Knopf bzw. laufendes Zeit-Band mit «Beenden», danach
/// die zwei von Hand änderbaren Zeitfelder «Arbeit von»/«Arbeit bis».
///
/// Der Zustand bleibt im Formular: Es besitzt die beiden Controller und
/// führt Beginn/Ende selbst aus ([onBeginnen]/[onBeenden] — Status setzen,
/// sofort speichern, GPS-Stempel; das unterscheidet sich je Einsatzart).
/// Der Baustein hält nur den 30-s-Timer der Live-Anzeige und beendet ihn in
/// `dispose`.
class ArbeitszeitBlock extends StatefulWidget {
  final TextEditingController vonController;
  final TextEditingController bisController;

  /// Band/Knopf zeigen — nur beim Bearbeiten eines noch geplanten oder
  /// laufenden Einsatzes (Daniel 31.07.2026).
  final bool beginnMoeglich;

  /// Beginn/Ende wird gerade gespeichert — sperrt die Knöpfe.
  final bool laeuft;

  final VoidCallback onBeginnen;
  final VoidCallback onBeenden;

  /// Nach einer Zeitwahl von Hand. Die Zeitfelder sind keine FormFields —
  /// `Form.onChanged` sieht sie nicht, das Formular muss selbst markieren.
  final VoidCallback onGeaendert;

  /// Was zwischen Band und Zeitfeldern steht (Störung: Datum/Eingang,
  /// Montage: Abschnittstitel).
  final List<Widget> zwischen;

  const ArbeitszeitBlock({
    super.key,
    required this.vonController,
    required this.bisController,
    required this.beginnMoeglich,
    required this.laeuft,
    required this.onBeginnen,
    required this.onBeenden,
    required this.onGeaendert,
    this.zwischen = const [],
  });

  @override
  State<ArbeitszeitBlock> createState() => _ArbeitszeitBlockState();
}

class _ArbeitszeitBlockState extends State<ArbeitszeitBlock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.vonController.addListener(_timerAbgleichen);
    widget.bisController.addListener(_timerAbgleichen);
    _timerAbgleichen();
  }

  @override
  void didUpdateWidget(covariant ArbeitszeitBlock alt) {
    super.didUpdateWidget(alt);
    if (alt.vonController != widget.vonController) {
      alt.vonController.removeListener(_timerAbgleichen);
      widget.vonController.addListener(_timerAbgleichen);
    }
    if (alt.bisController != widget.bisController) {
      alt.bisController.removeListener(_timerAbgleichen);
      widget.bisController.addListener(_timerAbgleichen);
    }
    _timerAbgleichen();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    widget.vonController.removeListener(_timerAbgleichen);
    widget.bisController.removeListener(_timerAbgleichen);
    super.dispose();
  }

  /// Läuft der Live-Timer gerade? (für Tests)
  @visibleForTesting
  bool get timerAktiv => _timer != null;

  /// Der Timer läuft genau dann, wenn das Band sichtbar ist und ein Beginn
  /// ohne Ende erfasst ist.
  void _timerAbgleichen() {
    final laufend =
        widget.beginnMoeglich &&
        widget.vonController.text.trim().isNotEmpty &&
        widget.bisController.text.trim().isEmpty;
    if (laufend && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    } else if (!laufend && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [_band(), ...widget.zwischen, _zeitfelder()],
    );
  }

  /// «Arbeit beginnen»-Knopf; nach dem ersten Tap zeigt derselbe Platz die
  /// laufende Zeit an (Daniel 31.07.2026).
  Widget _band() {
    if (!widget.beginnMoeglich) return const SizedBox.shrink();
    final von = widget.vonController.text.trim();
    if (von.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          // TapKnopf statt FilledButton (CanvasKit-Regel, CLAUDE.md): Der
          // Einstieg in die Zeiterfassung darf nicht unsichtbar sein.
          child: TapKnopf(
            text: 'Arbeit beginnen',
            icon: Icons.play_arrow,
            farbe: AppColors.info,
            laeuft: widget.laeuft,
            onTap: widget.onBeginnen,
          ),
        ),
      );
    }
    final bis = widget.bisController.text.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success),
      ),
      child: Row(
        children: [
          Icon(
            bis.isEmpty ? Icons.timer : Icons.check_circle,
            color: AppColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              bis.isNotEmpty
                  ? 'Arbeit erfasst: $von – $bis'
                  : (laufendeArbeitszeitText(
                          widget.vonController.text,
                          widget.bisController.text,
                          DateTime.now(),
                        ) ??
                        'Arbeit läuft seit $von'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          // «Arbeit beenden» — bis 11.08.2026 fehlte dieser Knopf ganz: Der
          // einzige Weg zum Abschluss war der Schalter «Erst geplant», was
          // niemand erraten konnte (Fall Sartons).
          if (bis.isEmpty)
            ArbeitBeendenKnopf(onTap: widget.onBeenden, laeuft: widget.laeuft),
        ],
      ),
    );
  }

  /// Zwei von Hand änderbare Zeitfelder — für den Fall, dass der
  /// «Beginn»-Knopf vergessen wurde oder eine Korrektur nötig ist.
  Widget _zeitfelder() {
    Widget feld(String label, TextEditingController controller, IconData icon) {
      return Expanded(
        child: InkWell(
          onTap: () async {
            final initial =
                arbeitszeitParsen(controller.text) ?? TimeOfDay.now();
            final picked = await zeigeZeitauswahl(context, initial: initial);
            if (picked != null && mounted) {
              setState(() => controller.text = arbeitszeitFormatieren(picked));
              widget.onGeaendert();
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
              isDense: true,
            ),
            child: Text(controller.text.isEmpty ? '—' : controller.text),
          ),
        ),
      );
    }

    return Row(
      children: [
        feld('Arbeit von', widget.vonController, Icons.play_circle_outline),
        const SizedBox(width: 12),
        feld('Arbeit bis', widget.bisController, Icons.stop_circle_outlined),
      ],
    );
  }
}

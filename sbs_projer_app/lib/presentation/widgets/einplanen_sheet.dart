import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart'
    show minutenAusHhmm;
import 'package:sbs_projer_app/presentation/widgets/zeit_auswahl.dart';

/// Ergebnis des Einplanen-Sheets: Tag, optionale fixe Uhrzeit, Dauer.
///
/// `zeit == null` heisst ganztägig — Daniels Entscheid vom 31.07.2026:
/// entweder ein fixer Termin (mit Uhrzeit) oder ganztägig an einem Datum,
/// siehe `core/util/einsatz_faellig.dart`.
class EinplanenErgebnis {
  final DateTime tag;
  final String? zeit;
  final int dauerMin;

  const EinplanenErgebnis({
    required this.tag,
    required this.zeit,
    required this.dauerMin,
  });
}

/// Zeigt das Einplanen-Sheet für einen Störungs-/Montage-Einsatz. Liefert
/// `null`, wenn der Nutzer abgebrochen hat (weggetippt / Sheet zugezogen).
Future<EinplanenErgebnis?> zeigeEinplanenSheet(
  BuildContext context, {
  required String titel,
  String? untertitel,
  DateTime? initialTag,
  String? initialZeit,
  int? initialDauerMin,
}) {
  return showModalBottomSheet<EinplanenErgebnis>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EinplanenSheet(
      titel: titel,
      untertitel: untertitel,
      initialTag: initialTag,
      initialZeit: initialZeit,
      initialDauerMin: initialDauerMin,
    ),
  );
}

class _EinplanenSheet extends StatefulWidget {
  final String titel;
  final String? untertitel;
  final DateTime? initialTag;
  final String? initialZeit;
  final int? initialDauerMin;

  const _EinplanenSheet({
    required this.titel,
    this.untertitel,
    this.initialTag,
    this.initialZeit,
    this.initialDauerMin,
  });

  @override
  State<_EinplanenSheet> createState() => _EinplanenSheetState();
}

class _EinplanenSheetState extends State<_EinplanenSheet> {
  static const _defaultZeit = TimeOfDay(hour: 8, minute: 0);

  late DateTime _tag;
  late bool _fixerTermin;
  late TimeOfDay _zeit;
  late int _dauerMin;

  @override
  void initState() {
    super.initState();
    final heute = DateTime.now();
    final heuteTag = DateTime(heute.year, heute.month, heute.day);
    final initialTag = widget.initialTag;
    // Vorauswahl: morgen — die meisten Einsätze werden für den Folgetag
    // eingeplant, nicht für heute (Daniel 31.07.2026).
    _tag = initialTag != null
        ? DateTime(initialTag.year, initialTag.month, initialTag.day)
        : heuteTag.add(const Duration(days: 1));
    _fixerTermin = widget.initialZeit != null && widget.initialZeit!.isNotEmpty;
    final initialMin = minutenAusHhmm(widget.initialZeit);
    _zeit = initialMin != null
        ? TimeOfDay(hour: initialMin ~/ 60, minute: initialMin % 60)
        : _defaultZeit;
    _dauerMin = widget.initialDauerMin ?? 60;
  }

  bool _gleicherTag(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _tagSetzen(DateTime tag) =>
      setState(() => _tag = DateTime(tag.year, tag.month, tag.day));

  Future<void> _datumWaehlen() async {
    final heute = DateTime.now();
    final heuteTag = DateTime(heute.year, heute.month, heute.day);
    final gewaehlt = await showDatePicker(
      context: context,
      initialDate: _tag,
      firstDate: heuteTag.subtract(const Duration(days: 365)),
      lastDate: heuteTag.add(const Duration(days: 730)),
      helpText: 'Einsatz einplanen',
    );
    if (gewaehlt == null || !mounted) return;
    _tagSetzen(gewaehlt);
  }

  Future<void> _zeitWaehlen() async {
    final gewaehlt = await zeigeZeitauswahl(context, initial: _zeit);
    if (gewaehlt == null || !mounted) return;
    setState(() => _zeit = gewaehlt);
  }

  String _zweistellig(int n) => n.toString().padLeft(2, '0');

  void _speichern() {
    final zeitText = _fixerTermin
        ? '${_zweistellig(_zeit.hour)}:${_zweistellig(_zeit.minute)}'
        : null;
    Navigator.pop(
      context,
      EinplanenErgebnis(tag: _tag, zeit: zeitText, dauerMin: _dauerMin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heute = DateTime.now();
    final heuteTag = DateTime(heute.year, heute.month, heute.day);
    final morgen = heuteTag.add(const Duration(days: 1));
    final istAnderesDatum =
        !_gleicherTag(_tag, heuteTag) && !_gleicherTag(_tag, morgen);
    final df = DateFormat('EE, dd.MM.yyyy', 'de_CH');

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
              // Griff
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 2),
                child: Text(
                  'Einplanen',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  widget.titel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.untertitel != null && widget.untertitel!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    widget.untertitel!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

              // ─── Tag ───
              const _SheetTitel('Tag'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _Wahlchip(
                        text: 'Heute',
                        ausgewaehlt: _gleicherTag(_tag, heuteTag),
                        onTap: () => _tagSetzen(heuteTag),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Wahlchip(
                        text: 'Morgen',
                        ausgewaehlt: _gleicherTag(_tag, morgen),
                        onTap: () => _tagSetzen(morgen),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Wahlchip(
                        text: 'Datum',
                        icon: Icons.calendar_today,
                        ausgewaehlt: istAnderesDatum,
                        onTap: _datumWaehlen,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  df.format(_tag),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const Divider(height: 24),

              // ─── Fixer Termin oder ganztägig ───
              // Ausdrücklich EINES von beiden — keine Uhrzeit heisst
              // ganztägig, eine Uhrzeit heisst fixer Termin (Daniels
              // Entscheid 31.07.2026).
              const _SheetTitel('Termin'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _Wahlchip(
                        text: 'Ganztägig',
                        icon: Icons.wb_sunny_outlined,
                        ausgewaehlt: !_fixerTermin,
                        onTap: () => setState(() => _fixerTermin = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Wahlchip(
                        text: 'Fixer Termin',
                        icon: Icons.push_pin_outlined,
                        ausgewaehlt: _fixerTermin,
                        onTap: () => setState(() => _fixerTermin = true),
                      ),
                    ),
                  ],
                ),
              ),
              if (_fixerTermin)
                _SheetAktion(
                  icon: Icons.schedule,
                  text:
                      '${_zweistellig(_zeit.hour)}:${_zweistellig(_zeit.minute)} Uhr',
                  onTap: _zeitWaehlen,
                )
              else
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    'Kein fixer Zeitpunkt — irgendwann an diesem Tag.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

              const Divider(height: 24),

              // ─── Dauer ───
              const _SheetTitel('Dauer'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    _RundKnopf(
                      icon: Icons.remove,
                      onTap: () => setState(
                        () => _dauerMin = (_dauerMin - 15) < 15
                            ? 15
                            : _dauerMin - 15,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '$_dauerMin min',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    _RundKnopf(
                      icon: Icons.add,
                      onTap: () => setState(() => _dauerMin += 15),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              // Speichern — bewusst GestureDetector + Container statt
              // ElevatedButton (CanvasKit-Regel: Material-Buttons in
              // Bottom-Sheets werden auf Web nicht zuverlässig gezeichnet,
              // siehe tourenplanung_screen.dart).
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: GestureDetector(
                  onTap: _speichern,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'Einplanen',
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bausteine (bewusst lokal, gleicher Stil wie
// tourenplanung_screen.dart — CanvasKit-Regel: kein ElevatedButton/
// TextButton in Bottom-Sheets) ───

class _SheetTitel extends StatelessWidget {
  final String text;

  const _SheetTitel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SheetAktion extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _SheetAktion({
    required this.icon,
    required this.text,
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
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Auswahl-Chip (Heute/Morgen/Datum, Ganztägig/Fixer Termin) — eigenes
/// Widget statt ChoiceChip, damit dieselbe CanvasKit-sichere Bauweise gilt.
class _Wahlchip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool ausgewaehlt;
  final VoidCallback onTap;

  const _Wahlchip({
    required this.text,
    this.icon,
    required this.ausgewaehlt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: ausgewaehlt
              ? AppColors.primary
              : AppColors.primary.withAlpha(18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: ausgewaehlt
                ? AppColors.primary
                : AppColors.primary.withAlpha(60),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: ausgewaehlt ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ausgewaehlt ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RundKnopf extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RundKnopf({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }
}

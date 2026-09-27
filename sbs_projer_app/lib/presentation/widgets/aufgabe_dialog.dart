import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/eigene_aufgabe.dart';
import 'package:sbs_projer_app/presentation/widgets/datum_auswahl.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz/betrieb_feld.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

/// Dialog «Neue Aufgabe» / «Aufgabe bearbeiten» — nur Oberfläche, speichert
/// nichts. Gibt die eingegebene Aufgabe zurück (mit der Id von [vorlage]
/// beim Bearbeiten), `null` bei Abbrechen.
///
/// [betriebId] belegt den Betrieb beim Anlegen vor (Betriebsseite «+ Neue
/// Aufgabe»). Der Betrieb ist optional und leerbar (Kreuz im Feld) —
/// Entscheid Daniel 27.09.2026.
Future<EigeneAufgabe?> zeigeAufgabeDialog(
  BuildContext context, {
  required List<BetriebLocal> betriebe,
  EigeneAufgabe? vorlage,
  String? betriebId,
}) => showDialog<EigeneAufgabe>(
  context: context,
  builder: (_) => AufgabeDialog(
    betriebe: betriebe,
    vorlage: vorlage,
    betriebId: betriebId,
  ),
);

/// Der Dialog selbst — öffentlich für den Widget-Test.
///
/// CanvasKit: Knöpfe als `TapKnopf`, die Datums-Aktionen als `InkWell` —
/// keine Material-Buttons (CLAUDE.md, drei bestätigte Vorfälle).
class AufgabeDialog extends StatefulWidget {
  final List<BetriebLocal> betriebe;
  final EigeneAufgabe? vorlage;
  final String? betriebId;

  const AufgabeDialog({
    super.key,
    required this.betriebe,
    this.vorlage,
    this.betriebId,
  });

  @override
  State<AufgabeDialog> createState() => _AufgabeDialogState();
}

class _AufgabeDialogState extends State<AufgabeDialog> {
  late final TextEditingController _titel;
  DateTime? _faellig;
  String? _betriebId;

  bool get _bearbeiten => widget.vorlage != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vorlage;
    _titel = TextEditingController(text: v?.titel ?? '');
    _faellig = v?.faelligAm;
    _betriebId = v != null ? v.betriebId : widget.betriebId;
  }

  @override
  void dispose() {
    _titel.dispose();
    super.dispose();
  }

  Future<void> _datumWaehlen() async {
    final heute = DateTime.now();
    final tag = DateTime(heute.year, heute.month, heute.day);
    // Eine überfällige Aufgabe behält beim Bearbeiten ihr altes Datum als
    // Untergrenze — sonst liesse sich der Kalender gar nicht öffnen.
    final erstes = _faellig != null && _faellig!.isBefore(tag)
        ? _faellig!
        : tag;
    final gewaehlt = await zeigeDatumsauswahl(
      context,
      initial: _faellig ?? tag,
      erstes: erstes,
      letztes: tag.add(const Duration(days: 730)),
    );
    if (gewaehlt != null && mounted) setState(() => _faellig = gewaehlt);
  }

  void _speichern() {
    final titel = _titel.text.trim();
    if (titel.isEmpty) return;
    Navigator.pop(
      context,
      EigeneAufgabe(
        id: widget.vorlage?.id ?? '',
        titel: titel,
        faelligAm: _faellig,
        erledigtAm: widget.vorlage?.erledigtAm,
        betriebId: _betriebId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final faellig = _faellig;
    return AlertDialog(
      title: Text(_bearbeiten ? 'Aufgabe bearbeiten' : 'Neue Aufgabe'),
      content: SizedBox(
        // Volle Dialogbreite statt Intrinsic-Messung — das Betriebsfeld ist
        // ein Autocomplete mit Overlay.
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('aufgabe_titel'),
                controller: _titel,
                autofocus: !_bearbeiten,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Titel'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.event,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      faellig == null
                          ? 'Kein Datum'
                          : DateFormat('dd.MM.yyyy').format(faellig),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (faellig != null)
                    InkWell(
                      key: const Key('aufgabe_datum_leeren'),
                      onTap: () => setState(() => _faellig = null),
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.textSecondary,
                          semanticLabel: 'Datum entfernen',
                        ),
                      ),
                    ),
                  InkWell(
                    key: const Key('aufgabe_datum'),
                    onTap: _datumWaehlen,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(
                        'Datum wählen',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              BetriebFeld(
                betriebe: widget.betriebe,
                betriebId: _betriebId,
                label: 'Betrieb (optional)',
                mitOrt: true,
                onGewaehlt: (b) => setState(() => _betriebId = b.serverId),
                onGeleert: () => setState(() => _betriebId = null),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TapKnopf(
          text: 'Abbrechen',
          primaer: false,
          onTap: () => Navigator.pop(context),
        ),
        TapKnopf(
          key: const Key('aufgabe_speichern'),
          text: _bearbeiten ? 'Speichern' : 'Anlegen',
          onTap: _titel.text.trim().isEmpty ? null : _speichern,
        ),
      ],
    );
  }
}

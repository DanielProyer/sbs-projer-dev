import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/saison_abmachung.dart';
import 'package:sbs_projer_app/core/util/saison_historie.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_saison_historie_repository.dart';
import 'package:sbs_projer_app/data/repositories/termin_repository.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

final _ddMMyyyy = DateFormat('dd.MM.yyyy');

/// Saisondaten erfassen und gleich die Saisonreinigung mit dem Wirt abmachen.
///
/// **Warum (Daniel, 20.09.2026):** Während der Reinigung steht der Wirt
/// daneben — das ist der Moment, um zu fragen «wann macht ihr zu, wann wieder
/// auf?» und gleich abzumachen, wann Daniel zur Eröffnungs- oder Endreinigung
/// kommen darf. Bis dahin musste er sich das merken und später im
/// Betriebs-Formular nachtragen.
///
/// Gibt `true` zurück, wenn gespeichert wurde.
Future<bool> zeigeSaisonAbmachungSheet(
  BuildContext context, {
  required BetriebLocal betrieb,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _SaisonAbmachungSheet(betrieb: betrieb),
  );
  return ok ?? false;
}

class _SaisonAbmachungSheet extends StatefulWidget {
  final BetriebLocal betrieb;
  const _SaisonAbmachungSheet({required this.betrieb});

  @override
  State<_SaisonAbmachungSheet> createState() => _SaisonAbmachungSheetState();
}

class _SaisonAbmachungSheetState extends State<_SaisonAbmachungSheet> {
  late bool _winterAktiv = widget.betrieb.winterSaisonAktiv;
  late DateTime? _winterStart = widget.betrieb.winterStartDatum;
  late DateTime? _winterEnde = widget.betrieb.winterEndeDatum;
  late bool _sommerAktiv = widget.betrieb.sommerSaisonAktiv;
  late DateTime? _sommerStart = widget.betrieb.sommerStartDatum;
  late DateTime? _sommerEnde = widget.betrieb.sommerEndeDatum;
  late bool _keineHerbstpause = widget.betrieb.keineHerbstpause;

  bool _abmachen = false;
  bool _endreinigung = true;
  Spielraum _spielraum = Spielraum.fix;
  DateTime? _terminDatum;
  TimeOfDay? _von;
  TimeOfDay? _bis;
  final _notiz = TextEditingController();
  bool _speichert = false;

  @override
  void dispose() {
    _notiz.dispose();
    super.dispose();
  }

  Zeitraum? get _zwischensaison => naechsteZwischensaison(
    winterAktiv: _winterAktiv,
    winterStart: _winterStart,
    winterEnde: _winterEnde,
    sommerAktiv: _sommerAktiv,
    sommerStart: _sommerStart,
    sommerEnde: _sommerEnde,
    heute: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    final z = _zwischensaison;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saisondaten & Abmachung',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          Text(
            widget.betrieb.ort == null || widget.betrieb.ort!.isEmpty
                ? widget.betrieb.name
                : '${widget.betrieb.name}, ${widget.betrieb.ort}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          _block(
            'Wintersaison',
            _winterAktiv,
            (v) {
              setState(() => _winterAktiv = v);
            },
            [
              _datum(
                'Start',
                _winterStart,
                (d) => setState(() => _winterStart = d),
              ),
              const SizedBox(height: 8),
              _datum(
                'Ende',
                _winterEnde,
                (d) => setState(() => _winterEnde = d),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _block(
            'Sommersaison',
            _sommerAktiv,
            (v) {
              setState(() => _sommerAktiv = v);
            },
            [
              _datum(
                'Start',
                _sommerStart,
                (d) => setState(() => _sommerStart = d),
              ),
              const SizedBox(height: 8),
              _datum(
                'Ende',
                _sommerEnde,
                (d) => setState(() => _sommerEnde = d),
              ),
            ],
          ),

          if (_winterAktiv && _sommerAktiv) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Keine Herbstpause'),
              subtitle: const Text(
                'Sommer geht direkt in den Winter über.',
                style: TextStyle(fontSize: 12),
              ),
              value: _keineHerbstpause,
              onChanged: (v) => setState(() => _keineHerbstpause = v),
            ),
          ],

          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Saisonreinigung abmachen',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Wann darfst du kommen? Geht auch ohne — dann werden nur die '
              'Saisondaten gespeichert.',
              style: TextStyle(fontSize: 12),
            ),
            value: _abmachen,
            onChanged: (v) => setState(() => _abmachen = v),
          ),
          if (_abmachen) ...[
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Endreinigung')),
                ButtonSegment(value: false, label: Text('Eröffnung')),
              ],
              selected: {_endreinigung},
              onSelectionChanged: (s) =>
                  setState(() => _endreinigung = s.first),
            ),
            const SizedBox(height: 12),
            const Text('Wann?', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final s in Spielraum.values)
                  ChoiceChip(
                    label: Text(s.label),
                    selected: _spielraum == s,
                    // «Ganze Zwischensaison» braucht beide Saisons mit Datum —
                    // ohne die lässt sich der Zeitraum nicht berechnen.
                    onSelected: (s == Spielraum.zwischensaison && z == null)
                        ? null
                        : (_) => setState(() => _spielraum = s),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _spielraum == Spielraum.zwischensaison && z != null
                  ? 'Zeitraum: ${_ddMMyyyy.format(z.von)} – '
                        '${_ddMMyyyy.format(z.bis)}'
                  : _spielraum.erklaerung,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            if (z == null) ...[
              const SizedBox(height: 4),
              const Text(
                '«Ganze Zwischensaison» braucht Winter- und Sommerdaten mit '
                'Start und Ende — dann rechnet die App den Zeitraum selbst.',
                style: TextStyle(fontSize: 11, color: AppColors.warning),
              ),
            ],
            if (_spielraum != Spielraum.zwischensaison) ...[
              const SizedBox(height: 12),
              _datum(
                _spielraum == Spielraum.woche ? 'Erster Tag der Woche' : 'Tag',
                _terminDatum,
                (d) => setState(() => _terminDatum = d),
              ),
            ],
            if (_spielraum == Spielraum.fix) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _zeit('Von', _von, (t) => setState(() => _von = t)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _zeit('Bis', _bis, (t) => setState(() => _bis = t)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notiz,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notiz (freiwillig)',
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'z. B. «Schlüssel beim Nachbarn»',
              ),
            ),
          ],
          const SizedBox(height: 20),
          TapKnopf(
            text: 'Speichern',
            icon: Icons.check,
            laeuft: _speichert,
            onTap: _speichern,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _block(
    String titel,
    bool aktiv,
    ValueChanged<bool> onAktiv,
    List<Widget> felder,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            titel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          value: aktiv,
          onChanged: onAktiv,
        ),
        if (aktiv) ...[...felder, const SizedBox(height: 12)],
      ],
    ),
  );

  Widget _datum(String label, DateTime? wert, ValueChanged<DateTime?> onNeu) =>
      InkWell(
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: wert ?? DateTime.now(),
            firstDate: DateTime(DateTime.now().year - 1),
            lastDate: DateTime(DateTime.now().year + 3),
          );
          if (d != null) onNeu(d);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: wert == null
                ? const Icon(Icons.calendar_today, size: 18)
                : IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => onNeu(null),
                  ),
          ),
          child: Text(
            wert == null ? 'nicht gesetzt' : _ddMMyyyy.format(wert),
            style: TextStyle(
              color: wert == null ? AppColors.textSecondary : null,
            ),
          ),
        ),
      );

  Widget _zeit(String label, TimeOfDay? wert, ValueChanged<TimeOfDay?> onNeu) =>
      InkWell(
        onTap: () async {
          final t = await showTimePicker(
            context: context,
            initialTime: wert ?? const TimeOfDay(hour: 8, minute: 0),
          );
          if (t != null) onNeu(t);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          child: Text(
            wert == null
                ? '—'
                : '${wert.hour.toString().padLeft(2, '0')}:'
                      '${wert.minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: wert == null ? AppColors.textSecondary : null,
            ),
          ),
        ),
      );

  String? _zeitText(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}';

  Future<void> _speichern() async {
    final b = widget.betrieb;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _speichert = true);

    final altWinterStart = b.winterStartDatum;
    final altWinterEnde = b.winterEndeDatum;
    final altSommerStart = b.sommerStartDatum;
    final altSommerEnde = b.sommerEndeDatum;
    try {
      b.winterSaisonAktiv = _winterAktiv;
      b.winterStartDatum = _winterAktiv ? _winterStart : null;
      b.winterEndeDatum = _winterAktiv ? _winterEnde : null;
      b.sommerSaisonAktiv = _sommerAktiv;
      b.sommerStartDatum = _sommerAktiv ? _sommerStart : null;
      b.sommerEndeDatum = _sommerAktiv ? _sommerEnde : null;
      b.keineHerbstpause = _winterAktiv && _sommerAktiv && _keineHerbstpause;
      await BetriebRepository.save(b);

      final sid = b.serverId;
      if (sid != null && sid.isNotEmpty) {
        final eintraege = [
          saisonArchivEintrag(
            saison: 'winter',
            altStart: altWinterStart,
            altEnde: altWinterEnde,
            neuStart: b.winterStartDatum,
          ),
          saisonArchivEintrag(
            saison: 'sommer',
            altStart: altSommerStart,
            altEnde: altSommerEnde,
            neuStart: b.sommerStartDatum,
          ),
        ].whereType<SaisonArchivEintrag>().toList();
        if (eintraege.isNotEmpty) {
          try {
            await BetriebSaisonHistorieRepository.archiviere(sid, eintraege);
          } catch (e) {
            debugPrint('[Saison] Archiv nicht geschrieben: $e');
          }
        }
      }

      var terminGesetzt = false;
      if (_abmachen && sid != null && sid.isNotEmpty) {
        final z = terminZeitraum(
          spielraum: _spielraum,
          datum: _terminDatum,
          zwischensaison: _zwischensaison,
        );
        if (z == null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Saisondaten gespeichert — für die Abmachung fehlt das Datum.',
              ),
            ),
          );
          navigator.pop(true);
          return;
        }
        await TerminRepository.anlegen(
          betriebId: sid,
          typ: _endreinigung ? 'endreinigung' : 'eroeffnungsreinigung',
          anlass: _endreinigung ? 'saisonende' : 'saisonstart',
          datum: z.von,
          datumBis: _spielraum == Spielraum.fix ? null : z.bis,
          spielraum: _spielraum.dbWert,
          uhrzeitVon: _spielraum == Spielraum.fix ? _zeitText(_von) : null,
          uhrzeitBis: _spielraum == Spielraum.fix ? _zeitText(_bis) : null,
          titel: abmachungTitel(endreinigung: _endreinigung, s: _spielraum),
          notizen: _notiz.text.trim().isEmpty ? null : _notiz.text.trim(),
        );
        terminGesetzt = true;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            terminGesetzt
                ? 'Saisondaten gespeichert, Termin gesetzt — steht im Kalender.'
                : 'Saisondaten gespeichert.',
          ),
        ),
      );
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Nicht gespeichert: ${kurzeFehlermeldung(e)}')),
      );
      if (mounted) setState(() => _speichert = false);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

final _ddMMyyyy = DateFormat('dd.MM.yyyy');

/// Was der Dialog zurückgibt: Datum, Titel und Notiz eines Service-Termins.
typedef ServiceTerminEingabe = ({
  DateTime datum,
  String titel,
  String? notizen,
});

/// Termin für den nächsten Service von Hand setzen.
///
/// **Warum (Daniel, 20.09.2026):** 33 Anlagen laufen «auf Abruf». Für die
/// rechnet die App bewusst kein Fälligkeitsdatum aus — sie tauchen also nie
/// von selbst im Tourenplan auf, und es gab keinen Weg, einen vereinbarten
/// Termin festzuhalten. Fall Alpina Resort Tschiertschen.
///
/// Der Termin läuft als `typ: 'sonstiges'`, `anlass: 'manuell'`. Damit geht er
/// über `TerminRepository.anlegen` in den Google Kalender («SBS · Service:
/// Betriebsname») und erscheint in den Einsätzen — beides war schon verdrahtet,
/// es fehlte nur der Weg, so einen Termin anzulegen.
Future<ServiceTerminEingabe?> zeigeServiceTerminDialog(
  BuildContext context, {
  required String betriebName,
  DateTime? vorschlag,
}) {
  final heute = DateTime.now();
  var datum = vorschlag ?? DateTime(heute.year, heute.month, heute.day + 7);
  final titelC = TextEditingController(text: 'Service');
  final notizC = TextEditingController();

  return showDialog<ServiceTerminEingabe>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLokal) => AlertDialog(
        title: const Text('Nächsten Service planen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                betriebName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: datum,
                    firstDate: DateTime(heute.year - 1),
                    lastDate: DateTime(heute.year + 3),
                  );
                  if (d != null) setLokal(() => datum = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Datum',
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(_ddMMyyyy.format(datum)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titelC,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                  isDense: true,
                  helperText: 'Steht im Kalender: «SBS · Titel: Betrieb»',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notizC,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notiz (freiwillig)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Der Termin geht in den Google Kalender und erscheint in den '
                'Einsätzen. Setzt du ihn später auf erledigt, verschwindet '
                'der Kalendereintrag wieder.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TapKnopf(
            text: 'Termin setzen',
            icon: Icons.event_available,
            onTap: () {
              final titel = titelC.text.trim();
              final notiz = notizC.text.trim();
              Navigator.pop(ctx, (
                datum: DateTime(datum.year, datum.month, datum.day),
                titel: titel.isEmpty ? 'Service' : titel,
                notizen: notiz.isEmpty ? null : notiz,
              ));
            },
          ),
        ],
      ),
    ),
  );
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/abgleich_fenster.dart';
import 'package:sbs_projer_app/core/util/bank_waechter.dart';
import 'package:sbs_projer_app/services/rechnung/buchung_service.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/camt_datei.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/camt_datei_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_pruefliste_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eingangsrechnung_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/abgleich_vorschau.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/buchungs_vorlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_pruefliste_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_regel_repository.dart';
import 'package:sbs_projer_app/data/repositories/eingangsrechnung_repository.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/camt/camt053_parser.dart';
import 'package:sbs_projer_app/services/camt/camt_ausgabe_booker.dart';
import 'package:sbs_projer_app/services/camt/camt_auto_booker.dart';
import 'package:sbs_projer_app/services/camt/camt_bereich_router.dart';
import 'package:sbs_projer_app/services/camt/camt_stichtag.dart';
import 'package:sbs_projer_app/services/camt/camt_vorschlag.dart';
import 'package:sbs_projer_app/services/camt/forderungs_abgleich_service.dart';
import 'package:sbs_projer_app/services/camt/file_picker_export.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart';

class CamtImportTab extends ConsumerStatefulWidget {
  final VoidCallback? onZurPruefliste;
  const CamtImportTab({super.key, this.onZurPruefliste});
  @override
  ConsumerState<CamtImportTab> createState() => _CamtImportTabState();
}

class _CamtImportTabState extends ConsumerState<CamtImportTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // State
  int _step = 0; // 0=Datei wählen, 1=Bestätigen, 2=Ergebnis
  CamtStatement? _statement;
  String? _xmlRoh;
  String? _dateiname; // echter Name der gewählten Datei (fürs Archiv)
  List<CamtVorschlag> _vorschlaege = []; // Bereich 2: zu bestätigen

  /// Steuer-Zuordnung je Transaktion (txKey) — vorbelegt, damit «Alle
  /// bestätigen» ohne einen einzigen Klick richtig kontiert.
  final _steuer = <String, SteuerZuordnung>{};

  /// Noch nicht verbrauchte Rückstellung (2208) je Steuerjahr — bestimmt, ob
  /// eine Zahlung gegen 2208 oder direkt auf 8900 läuft. Wird nach jeder
  /// Steuerbuchung fortgeschrieben, damit die zweite Zahlung desselben Jahres
  /// nicht nochmals gegen eine bereits aufgebrauchte Rückstellung läuft.
  Map<int, double> _rueckstellungRest = {};

  /// Die Rückstellungs-Prüfung ist gescheitert (Journal nicht ladbar) — es
  /// wird auf 8900 kontiert, die Zeile weist sichtbar darauf hin.
  bool _rueckstellungFehler = false;
  int _prueflisteCount = 0;
  int _uebersprungen = 0;
  int _altpostenAusgeblendet = 0;
  AbgleichErgebnis? _abgleich;          // Bereich 1 Ergebnis
  List<Rechnung> _alleOffenen = [];     // Pool für ⚪-Zuordnung
  Map<String, String> _betriebName = {};
  bool _loading = false;
  String? _error;
  int _automatisierbarCount = 0;

  /// Bank-Wächter: Anschluss-Check (OPBD vs. Journal) und Lücken-Warnung,
  /// berechnet direkt nach dem Parsen. `null` = noch nicht geprüft.
  SaldoCheck? _anschlussCheck;
  String? _lueckenWarnung;

  final _dateFormat = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildBody();
  }

  Widget _buildBody() {
    switch (_step) {
      case 0:
        return _buildFilePickerStep();
      case 1:
        return _buildConfirmStep();
      case 2:
        return _buildResultStep();
      default:
        return const SizedBox();
    }
  }

  // === Schritt 1: Datei wählen ===
  Widget _buildFilePickerStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance,
              size: 64,
              color: AppColors.primary.withAlpha(100),
            ),
            const SizedBox(height: 24),
            Text(
              'camt.053 Bankauszug importieren',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Wählen Sie eine XML-Datei aus dem GKB-Onlinebanking.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_loading)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('XML-Datei wählen'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    String schritt = 'Datei wählen';
    try {
      setState(() { _loading = true; _error = null; });

      final picked = await pickXmlFile();

      if (picked == null) {
        setState(() { _loading = false; _error = 'Keine Datei ausgewählt oder Datei konnte nicht gelesen werden.'; });
        return;
      }

      schritt = 'XML parsen';
      var xmlString = picked.content;
      // BOM entfernen falls vorhanden
      if (xmlString.startsWith('﻿')) {
        xmlString = xmlString.substring(1);
      }

      CamtStatement statement;
      try {
        statement = Camt053Parser.parse(xmlString);
      } catch (e) {
        setState(() {
          _error = 'XML-Parse-Fehler: $e';
          _loading = false;
        });
        return;
      }

      final automatisierbar = statement.transactions
          .where((t) => CamtStichtag.istAutomatisierbar(t.bookingDate))
          .length;

      // Bank-Wächter: Anschluss ans Journal prüfen, BEVOR irgendetwas
      // gebucht wird. Fängt untertags gezogene Exporte mit verlorenen
      // Transaktionen (Sorge Daniel 01.09.2026) — die Saldokette der Bank
      // ist die Wahrheit, unabhängig vom Exportzeitpunkt.
      schritt = 'Bank-Wächter (Anschluss-Prüfung)';
      SaldoCheck? anschluss;
      String? luecke;
      try {
        final vortag =
            statement.fromDate.subtract(const Duration(days: 1));
        final journalVortag = await BuchungService.bankSaldoPer(vortag);
        anschluss = BankWaechter.pruefeAnschluss(
            opbd: statement.openingBalance, journalVortag: journalVortag);
        final dateien = await CamtDateiRepository.getAll();
        final letzteBis = dateien.isEmpty
            ? null
            : dateien
                .map((d) => d.zeitraumBis)
                .whereType<DateTime>()
                .fold<DateTime?>(null,
                    (max, d) => max == null || d.isAfter(max) ? d : max);
        luecke = BankWaechter.luecke(
            letztesBis: letzteBis, neuesVon: statement.fromDate);
      } catch (e) {
        // Der Wächter darf den Import nie verhindern — nur informieren.
        debugPrint('[BankWaechter] Prüfung fehlgeschlagen: $e');
      }

      setState(() {
        _anschlussCheck = anschluss;
        _lueckenWarnung = luecke;
        _statement = statement;
        _xmlRoh = xmlString;
        _dateiname = picked.name;
        _automatisierbarCount = automatisierbar;
        _step = 1;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Fehler bei "$schritt": $e';
        _loading = false;
      });
    }
  }

  // === Schritt 2: Bestätigen ===
  // Robust: einfache scrollbare Spalte mit den Aktions-Buttons INLINE direkt
  // unter dem Text (kein Expanded / bottomNavigationBar — kann nicht verschwinden).
  Widget _buildConfirmStep() {
    final stmt = _statement!;
    final txs = stmt.transactions;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Auszugs-Header (volle Breite)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withAlpha(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bankauszug ${_dateFormat.format(stmt.fromDate)} – ${_dateFormat.format(stmt.toDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '${stmt.ownerName} · IBAN ${stmt.iban} · ${txs.length} Transaktionen',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Bank-Wächter: Anschluss-Prüfung + Lücken-Warnung (robuste
          // Container statt Material-Komfort-Widgets — CanvasKit-Regel).
          if (_anschlussCheck != null || _lueckenWarnung != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_lueckenWarnung == null &&
                        (_anschlussCheck?.ok ?? true))
                    ? AppColors.success.withAlpha(25)
                    : AppColors.error.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_lueckenWarnung == null &&
                          (_anschlussCheck?.ok ?? true))
                      ? AppColors.success.withAlpha(120)
                      : AppColors.error.withAlpha(120),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_anschlussCheck != null)
                    Text(
                      '${_anschlussCheck!.ok ? '✓' : '⚠'} ${_anschlussCheck!.text}',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  if (_lueckenWarnung != null) ...[
                    if (_anschlussCheck != null) const SizedBox(height: 4),
                    Text('⚠ $_lueckenWarnung',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 32),
          Icon(Icons.auto_awesome, size: 56, color: AppColors.primary.withAlpha(120)),
          const SizedBox(height: 20),
          Text(
            'Verbuchung & Rechnungskontrolle',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '$_automatisierbarCount von ${txs.length} Transaktion${txs.length == 1 ? '' : 'en'} '
              'liegen nach dem Stichtag ${_dateFormat.format(CamtStichtag.stichtag)} (der Tag selbst ist aus dem Excel gebucht). '
              'Nichts wird automatisch gebucht — du bestätigst jede Buchung danach selbst.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          // Aktions-Buttons als robuste Tap-Flächen (Material-Buttons rendern auf
          // diesem Screen nicht — bewusst GestureDetector+Container, ohne Row).
          // Verarbeiten (primär)
          GestureDetector(
            onTap: _loading ? null : _doImport,
            child: Container(
              constraints: const BoxConstraints(minWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 15),
              decoration: BoxDecoration(
                color: _loading
                    ? AppColors.primary.withAlpha(150)
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _loading
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(70),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
              ),
              child: Text(
                _loading ? 'Verarbeite…' : 'Verarbeiten',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Zurück (sekundär, dezent)
          GestureDetector(
            onTap: _loading
                ? null
                : () => setState(() {
                      _step = 0;
                      _statement = null;
                    }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Zurück',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _doImport() async {
    setState(() => _loading = true);
    try {
      final stmt = _statement!;
      // Doppel-Upload-Schutz (wie Forderungs-Abgleich).
      final bereitsErfasst = await CamtDateiRepository.existsZeitraum(
          stmt.iban, stmt.fromDate, stmt.toDate);
      if (bereitsErfasst) {
        if (!mounted) { setState(() => _loading = false); return; }
        final weiter = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Zeitraum bereits erfasst'),
            content: Text('Für diese IBAN ist der Zeitraum '
                '${_dateFormat.format(stmt.fromDate)} – '
                '${_dateFormat.format(stmt.toDate)} bereits archiviert.\n\n'
                'Trotzdem importieren?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Trotzdem')),
            ],
          ),
        );
        if (weiter != true) { setState(() => _loading = false); return; }
      }
      final betriebe = ref.read(betriebeProvider)
          .where((b) => b.serverId != null)
          .map((b) => {
                'id': b.serverId!,
                'name': b.name,
                'ort': b.ort ?? '',
                'aliase': b.zahlerAliase.join('\n'),
                'nr': b.nr ?? '',
                'we_nummer': b.weNummer ?? '',
                'ag_nummer': b.agNummer ?? '',
                'heineken_nr': b.betriebNr ?? '',
              })
          .toList();
      final alleRechnungen = await RechnungRepository.getAll();
      final alleOffenen = alleRechnungen.where((r) =>
          r.rechnungstyp == 'kundenrechnung' &&
          (r.zahlungsstatus == 'offen' || r.zahlungsstatus == 'gesendet')).toList();
      // Nur Forderungen bis ein Jahr zurück (Regel Daniel 28.07.2026) — ältere
      // stammen aus der Zeit ohne Rechnungsversand, werden abgeschrieben und
      // würden im Abgleich nur Fehlgriffe provozieren.
      final jetzt = DateTime.now();
      final offeneRechnungen = alleOffenen
          .where((r) => istImAbgleichsfenster(r.rechnungsdatum, jetzt))
          .toList();
      final ausgeblendeteAltposten = alleOffenen.length - offeneRechnungen.length;
      final heinekenRechnungen = alleRechnungen.where((r) =>
          r.rechnungstyp == 'heineken_monat' && r.zahlungsstatus != 'bezahlt').toList();
      // Gebuchte TX + erledigte/ignorierte Prüflisten-Einträge blockieren.
      // OFFENE Prüflisten-Einträge werden bewusst neu bewertet (Upsert
      // verhindert Duplikate; nach einer Buchung wird der Eintrag gelöscht).
      final bereitsVerarbeitet = <String>{
        ...await BuchungRepository.getAlleCamtTxKeys(),
        ...await CamtPrueflisteRepository.getBlockierendeTxKeys(),
      };
      final regeln = await CamtRegelRepository.getAktive();
      final vorlagen = (await BuchungsVorlageRepository.getAll())
          .cast<BuchungsVorlage>();
      final vorlagenById = {for (final v in vorlagen) v.id: v};
      // TP-5: offene Kreditoren (Stufe-1 gebucht, noch nicht bezahlt) als
      // Match-Kandidaten für camt-Belastungen.
      final offeneKreditoren = (await EingangsrechnungRepository
              .getByStatus(['gebucht', 'zahlung_vorgemerkt', 'exportiert']))
          .where((e) =>
              e.camtTxKey == null &&
              e.bezahltAm == null &&
              e.buchungStufe1Id != null)
          .toList();

      final stmtTx = _statement!.transactions;
      // Post-Stichtag + noch nicht verarbeitet → in Bereiche aufteilen.
      final post = stmtTx
          .where((t) => CamtStichtag.istAutomatisierbar(t.bookingDate))
          .where((t) => !bereitsVerarbeitet.contains(t.txKey))
          .toList();
      final bereich1 = post.where(istKundenzahlungsKandidat).toList();
      final bereich2 = post.where((t) => !istKundenzahlungsKandidat(t)).toList();

      // Bereich 2 (Übriges): Anfangsphase — NICHTS automatisch buchen.
      // Regel-/Heineken-Treffer werden als Vorschläge zum Bestätigen gezeigt,
      // ungetroffene gehen in die Prüfliste.
      final plan = CamtAutoBooker.plan(
        transactions: bereich2,
        heinekenRechnungen: heinekenRechnungen,
        regeln: regeln,
        vorlagenById: vorlagenById,
        offeneKreditoren: offeneKreditoren,
      );
      await CamtAutoBooker.zuPruefliste(plan.pruefliste);
      ref.invalidate(camtPrueflisteProvider);

      // Steuerzahlungen (Vorlage auf 8900/2208/2202) vorbelegen: Jahr, Art und
      // Zielkonto stehen damit schon vor dem ersten Klick richtig.
      final steuerVorschlaege = plan.vorschlaege.where(_istSteuerVorschlag);
      final rueckRest = <int, double>{};
      final steuerInit = <String, SteuerZuordnung>{};
      var rueckFehler = false;
      if (steuerVorschlaege.isNotEmpty) {
        try {
          rueckRest.addAll(rueckstellungsRest(
              await BuchungRepository.getAll()));
        } catch (e) {
          // Ohne Rückstellungs-Info wird auf 8900 kontiert — im Dropdown
          // korrigierbar; der Import darf daran nicht scheitern. Der Fehler
          // wird in der Steuerzeile sichtbar gemacht (nicht nur geloggt).
          rueckFehler = true;
          debugPrint('[camt] Rückstellungs-Prüfung fehlgeschlagen: $e');
        }
        for (final v in steuerVorschlaege) {
          steuerInit[v.tx.txKey] = _initialeSteuerZuordnung(v, rueckRest);
        }
      }

      final preStichtagOderVerarbeitet = stmtTx
          .where((t) =>
              !CamtStichtag.istAutomatisierbar(t.bookingDate) ||
              bereitsVerarbeitet.contains(t.txKey))
          .length;

      // Bereich 1: Kundenzahlungen gegen offene Forderungen abgleichen.
      final abgleich = ForderungsAbgleichService.abgleich(
        gutschriften: bereich1,
        offeneForderungen: offeneRechnungen,
        betriebe: betriebe,
      );

      // Archiv-Kopie ERST nach erfolgreicher Verarbeitung (UTF-8-normalisiert)
      // — sonst blockiert eine gescheiterte Verarbeitung über die
      // Duplikatprüfung jeden weiteren Versuch mit derselben Datei.
      final gutAnzahl = stmt.transactions.where((t) => t.isCredit).length;
      await CamtDateiRepository.speichern(
        CamtDatei(id: '', userId: '', dateiname: _dateiname ?? 'camt.xml',
          zeitraumVon: stmt.fromDate, zeitraumBis: stmt.toDate, iban: stmt.iban,
          anzahlEintraege: stmt.transactions.length, anzahlGutschriften: gutAnzahl, storagePfad: '',
          // Bank-Salden für den Bank-Wächter (Lückenlos- und Schluss-Check).
          anfangssaldo: stmt.openingBalance, schlusssaldo: stmt.closingBalance),
        Uint8List.fromList(utf8.encode(_xmlRoh ?? '')));

      setState(() {
        _vorschlaege = plan.vorschlaege;
        _rueckstellungRest = rueckRest;
        _rueckstellungFehler = rueckFehler;
        _steuer
          ..clear()
          ..addAll(steuerInit);
        _prueflisteCount = plan.pruefliste.length;
        _uebersprungen = plan.uebersprungen + preStichtagOderVerarbeitet;
        _altpostenAusgeblendet = ausgeblendeteAltposten;
        _abgleich = abgleich;
        // Der Pool für die manuelle Zuordnung enthält bewusst ALLE offenen
        // Forderungen — im Dialog lassen sich die älteren zuschalten, falls
        // ein Kunde doch erst nach über einem Jahr zahlt.
        _alleOffenen = alleOffenen;
        _betriebName = {
          for (final b in betriebe)
            b['id']!: (b['ort'] ?? '').isEmpty
                ? b['name']!
                : '${b['name']} · ${b['ort']}'
        };
        _step = 2;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import-Fehler: $e')));
      }
    }
  }

  // === Schritt 3: Ergebnis ===
  Widget _buildResultStep() {
    final ab = _abgleich!;
    final hatKundenzahlungen = ab.auto.isNotEmpty ||
        ab.manuell.isNotEmpty ||
        ab.unbekannteGutschriften.isNotEmpty ||
        ab.keineZahlung.isNotEmpty;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // === Bereich 1: Kundenzahlungen ===
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text('Kundenzahlungen',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            if (hatKundenzahlungen)
              AbgleichVorschau(
                ergebnis: ab,
                alleOffenen: _alleOffenen,
                betriebName: _betriebName,
                padding: const EdgeInsets.symmetric(vertical: 8),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Keine Kundenzahlungen in diesem Auszug.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            const Divider(height: 32),
            // === Bereich 2: Übriges — zu BESTÄTIGEN (nichts auto-gebucht) ===
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text('Übriges — zu bestätigen',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            if (_vorschlaege.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _tapButton(
                    'Alle bestätigen',
                    _bucheAlleVorschlaege,
                    primaer: true,
                  ),
                ),
              ),
              for (final v in _vorschlaege) _vorschlagZeile(v),
            ] else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Keine automatisch zuordenbaren Buchungen.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            if (_prueflisteCount > 0)
              _ResultRow(Icons.info_outline,
                  '$_prueflisteCount in Prüfliste (manuell klären)',
                  AppColors.warning),
            if (_uebersprungen > 0)
              _ResultRow(Icons.skip_next,
                  '$_uebersprungen übersprungen (vor Stichtag / bereits verarbeitet)',
                  AppColors.textSecondary),
            if (_altpostenAusgeblendet > 0)
              _ResultRow(Icons.history_toggle_off,
                  '$_altpostenAusgeblendet Forderungen älter als ein Jahr — nicht im Abgleich',
                  AppColors.textSecondary),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: _tapButton(
                'Zur Prüfliste',
                () => widget.onZurPruefliste?.call(),
                primaer: false,
              ),
            ),
            const Divider(height: 32),
            _tapButton(
              'Weiteren Auszug importieren',
              () => setState(() {
                _step = 0;
                _statement = null;
                _vorschlaege = [];
                _steuer.clear();
                _rueckstellungRest = {};
                _rueckstellungFehler = false;
                _prueflisteCount = 0;
                _uebersprungen = 0;
                _abgleich = null;
                _automatisierbarCount = 0;
                _xmlRoh = null;
                _dateiname = null;
                _alleOffenen = [];
                _betriebName = {};
              }),
              primaer: false,
            ),
            const SizedBox(height: 10),
            _tapButton('Fertig', () => Navigator.of(context).pop(),
                primaer: true),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Zusatz-Infos zu einer Bereich-2-Zahlung: Zahlungsempfänger + Adresse +
  /// Bemerkung (Verwendungszweck). Null, wenn nichts Brauchbares da ist.
  String? _vorschlagInfo(CamtVorschlag v) {
    final teile = <String>[];
    final name = effektiverZahlername(
        partyName: v.tx.partyName, additionalInfo: v.tx.additionalInfo);
    if (name != null) teile.add(name);
    final adr = v.tx.partyAddress.trim();
    if (adr.isNotEmpty) teile.add(adr);
    final remit = v.tx.remittanceInfo?.trim();
    if (remit != null && remit.isNotEmpty) teile.add('Bemerkung: $remit');
    return teile.isEmpty ? null : teile.join(' · ');
  }

  /// Zahlt dieser Vorschlag auf ein Steuerkonto (8900/2208/2202)? Dann sind
  /// Steuerjahr und Steuerart zu erfassen, sonst fehlen sie im Steuer-Screen.
  bool _istSteuerVorschlag(CamtVorschlag v) {
    if (v.typ != CamtVorschlagTyp.ausgabe || v.vorlage == null) return false;
    try {
      final k = kontenFuerCamt(v.vorlage!);
      // Auch die Haben-Seite prüfen: Rückerstattungs-Vorlagen sind als
      // «Bank an 2208/8900» definiert und blieben sonst ohne Steuerjahr —
      // sie fielen aus `view_steuerjahr_zahlungen` heraus.
      return istSteuerKonto(k.sollKonto) || istSteuerKonto(k.habenKonto);
    } catch (_) {
      // Unvollständige Vorlage — das Buchen scheitert ohnehin sichtbar.
      return false;
    }
  }

  /// Vorschlag: Steuerart aus Zahlungsempfänger + Referenz/Zusatzinfo (die
  /// ESTV-MWST-Referenz `k8qt` steht nicht im Namen), Jahr = Vorjahr
  /// (Gewinn-/Kapitalsteuer wird nachschüssig bezahlt).
  ///
  /// Bei MWST das Buchungsjahr: die Quartalsabrechnungen Q1–Q3 werden im
  /// selben Jahr bezahlt. Die Q4-Abrechnung fällt ins Folgejahr — dort ist die
  /// Vorbelegung um ein Jahr zu hoch und per Dropdown zu korrigieren
  /// (bewusste Spec-Entscheidung 02.09.2026: der häufigere Fall gewinnt).
  SteuerZuordnung _initialeSteuerZuordnung(
      CamtVorschlag v, Map<int, double> rueckstellungRest) {
    final name = effektiverZahlername(
            partyName: v.tx.partyName, additionalInfo: v.tx.additionalInfo) ??
        '';
    final art = steuerartVorschlag('$name '
        '${v.tx.strukturierteReferenz ?? ''} ${v.tx.additionalInfo ?? ''}');
    final jahr = art == 'mwst'
        ? v.tx.bookingDate.year
        : v.tx.bookingDate.year - 1;
    return SteuerZuordnung(
      steuerjahr: jahr,
      steuerart: art,
      hatRueckstellung: (rueckstellungRest[jahr] ?? 0) > 0.05,
    );
  }

  void _setzeSteuer(CamtVorschlag v, {int? jahr, String? art}) {
    final alt = _steuer[v.tx.txKey]!;
    final neuJahr = jahr ?? alt.steuerjahr;
    setState(() {
      _steuer[v.tx.txKey] = SteuerZuordnung(
        steuerjahr: neuJahr,
        steuerart: art ?? alt.steuerart,
        hatRueckstellung: (_rueckstellungRest[neuJahr] ?? 0) > 0.05,
      );
    });
  }

  /// Schreibt die Rückstellung nach einer verbuchten Steuerzahlung fort und
  /// bewertet die übrigen Vorschläge desselben Jahres neu — sonst liefen zwei
  /// Zahlungen aus demselben Auszug beide gegen eine Rückstellung, die schon
  /// die erste aufgebraucht hat. Ohne Aufruf aus `setState`.
  void _steuerWirkungAnwenden(CamtVorschlag v) {
    final z = _steuer[v.tx.txKey];
    if (z == null) return;
    final gebuchtesKonto = steuerKontoFuer(
        steuerart: z.steuerart, hatRueckstellung: z.hatRueckstellung);
    if (gebuchtesKonto != 2208) return; // 8900/2202 rühren die Rückstellung nicht an
    final rest = (_rueckstellungRest[z.steuerjahr] ?? 0) +
        (v.tx.isCredit ? v.tx.amount : -v.tx.amount);
    _rueckstellungRest[z.steuerjahr] = rest;
    final hat = rest > 0.05;
    for (final e in _steuer.entries.toList()) {
      if (e.key == v.tx.txKey || e.value.steuerjahr != z.steuerjahr) continue;
      if (e.value.hatRueckstellung == hat) continue;
      _steuer[e.key] = SteuerZuordnung(
        steuerjahr: e.value.steuerjahr,
        steuerart: e.value.steuerart,
        hatRueckstellung: hat,
      );
    }
  }

  /// Öffnet den erfassten Beleg (PDF/Bild) einer Eingangsrechnung (frisch signiert).
  Future<void> _oeffneBeleg(String belegPfad) async {
    try {
      final url = await EingangsrechnungRepository.signedBelegUrl(belegPfad);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Beleg konnte nicht geöffnet werden: $e')));
      }
    }
  }

  /// Eine Bereich-2-Vorschlagszeile (Betrag · Ziel · Zahler/Bemerkung · Beleg · Verbuchen).
  Widget _vorschlagZeile(CamtVorschlag v) {
    final info = _vorschlagInfo(v);
    final belegPfad = v.typ == CamtVorschlagTyp.kreditor
        ? v.eingangsrechnung?.belegPfad
        : null;
    final steuer = _steuer[v.tx.txKey];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${v.tx.amount.toStringAsFixed(2)} CHF',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      '${v.label} · ${_dateFormat.format(v.tx.bookingDate)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    if (info != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        info,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (belegPfad != null && belegPfad.isNotEmpty)
                GestureDetector(
                  onTap: () => _oeffneBeleg(belegPfad),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.picture_as_pdf, size: 16, color: AppColors.primary),
                      SizedBox(width: 3),
                      Text('Beleg',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              const SizedBox(width: 8),
              _tapButton('Verbuchen', () => _bucheVorschlag(v), primaer: true),
            ],
          ),
          if (steuer != null) _steuerZeile(v, steuer),
        ],
      ),
    );
  }

  /// Steuerjahr + Steuerart einer Steuerzahlung (Spec 02.09.2026, Abschnitt 5).
  /// Bewusst schmal gehalten (zwei Dropdowns nebeneinander passen auf 375 px).
  Widget _steuerZeile(CamtVorschlag v, SteuerZuordnung z) {
    final jahre = <int>{
      for (int j = DateTime.now().year; j >= kSteuerJahrAb; j--) j,
      z.steuerjahr,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final konto = steuerKontoFuer(
        steuerart: z.steuerart, hatRueckstellung: z.hatRueckstellung);
    const kontoText = {
      2208: '→ 2208 Rückstellung',
      8900: '→ 8900 Steueraufwand',
      2202: '→ 2202 MWST',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: z.steuerjahr,
                  isDense: true,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  items: [
                    for (final j in jahre)
                      DropdownMenuItem(value: j, child: Text('Steuerjahr $j')),
                  ],
                  onChanged: (j) =>
                      j == null ? null : _setzeSteuer(v, jahr: j),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: z.steuerart,
                  isDense: true,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  items: [
                    for (final e in steuerarten.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (a) =>
                      a == null ? null : _setzeSteuer(v, art: a),
                ),
              ),
            ],
          ),
          Text(
            kontoText[konto] ?? '→ $konto',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600),
          ),
          if (_rueckstellungFehler)
            const Text(
              'Rückstellungs-Prüfung fehlgeschlagen — Kontierung auf 8900, bitte prüfen',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  Future<void> _bucheVorschlag(CamtVorschlag v) async {
    try {
      await CamtAutoBooker.bucheVorschlag(v, steuer: _steuer[v.tx.txKey]);
      ref.invalidate(buchungenStreamProvider);
      ref.invalidate(eingangsrechnungenProvider);
      if (!mounted) return;
      setState(() {
        _steuerWirkungAnwenden(v);
        _vorschlaege.remove(v);
        _steuer.remove(v.tx.txKey);
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Verbucht.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Buchungs-Fehler: $e')));
      }
    }
  }

  Future<void> _bucheAlleVorschlaege() async {
    final liste = List<CamtVorschlag>.from(_vorschlaege);
    final fehler = <String>[];
    final ok = <CamtVorschlag>[];
    for (final v in liste) {
      try {
        await CamtAutoBooker.bucheVorschlag(v, steuer: _steuer[v.tx.txKey]);
        // Rückstellung sofort fortschreiben — die nächste Zahlung desselben
        // Jahres im selben Auszug muss den neuen Rest sehen.
        _steuerWirkungAnwenden(v);
        ok.add(v);
      } catch (e) {
        fehler.add('${v.label}: $e');
      }
    }
    ref.invalidate(buchungenStreamProvider);
    ref.invalidate(eingangsrechnungenProvider);
    if (mounted) {
      setState(() {
        _vorschlaege.removeWhere((v) => ok.contains(v));
        for (final v in ok) {
          _steuer.remove(v.tx.txKey);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(fehler.isEmpty
            ? '${ok.length} verbucht.'
            : '${ok.length} verbucht, ${fehler.length} fehlgeschlagen'),
      ));
    }
  }

  /// Robuste Tap-Fläche (Material-Buttons rendern auf diesem Screen nicht).
  Widget _tapButton(String label, VoidCallback onTap, {required bool primaer}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: primaer ? AppColors.primary : Colors.transparent,
          border: primaer ? null : Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: primaer ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// === Helper Widgets ===

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ResultRow(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: TextStyle(fontSize: 14, color: color))),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/material_filter.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';
import 'package:sbs_projer_app/data/repositories/material_artikel_repository.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/widgets/material_karte.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/widgets/material_kategorie_chips.dart';
import 'package:sbs_projer_app/services/storage/material_ansicht_speicher.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Materialliste mit Kategorie-Chips und zwei Ansichten: Liste und Karten,
/// durch die man wischt (Vorbild: v2-Materialkatalog der Heineken-App, ohne
/// dessen Fehler — Controller im State statt im build, Karten mit Key,
/// kein Trefferdeckel, Filterwechsel auf Seite 0).
class MaterialienListScreen extends ConsumerStatefulWidget {
  /// Nur für Tests: im Widget-Test gibt es keinen Supabase-Client, und
  /// `SupabaseService.isGuest` würfe. null → zur Laufzeit aus der Sitzung.
  final bool? istGast;

  const MaterialienListScreen({super.key, this.istGast});

  @override
  ConsumerState<MaterialienListScreen> createState() =>
      _MaterialienListScreenState();
}

class _MaterialienListScreenState
    extends ConsumerState<MaterialienListScreen> {
  String _suche = '';
  String? _kategorie;
  bool _nurNiedrig = false;
  MaterialAnsicht _ansicht = MaterialAnsicht.liste;
  int _karte = 0;

  // Im State, nicht im build: ein im build erzeugter Controller leckt bei
  // jedem Rebuild und schneidet laufende Wischgesten ab (v2-Fehler).
  PageController _seiten = PageController();

  /// Signierte Foto-URLs je materialId — sonst holte jede neu gebaute Karte
  /// (jedes Wischen, jedes Bestand ±) das Foto erneut.
  final _fotoUrls = <String, Future<String?>>{};

  /// Im Niedrig-Filter auf der Karte geänderte Artikel (siehe
  /// [MaterialFilter.behalten]); gilt bis zum nächsten Filterwechsel.
  final _behalten = <String>{};

  /// Gespeicherte Bestände, die das Neuladen noch nicht zurückgebracht hat
  /// (siehe [MaterialKarte.bestandVorgabe]). Ein Eintrag fällt weg, sobald
  /// der Server denselben Wert liefert. Bleibt über Filterwechsel bestehen —
  /// die Werte sind ja gespeichert.
  final _bestandLokal = <String, double>{};

  bool get _istGast => widget.istGast ?? SupabaseService.isGuest;

  @override
  void initState() {
    super.initState();
    _ladeGemerktes();
  }

  @override
  void dispose() {
    _seiten.dispose();
    super.dispose();
  }

  Future<void> _ladeGemerktes() async {
    final g = await MaterialAnsichtSpeicher.lade();
    if (!mounted) return;
    setState(() {
      _ansicht = g.ansicht;
      _kategorie = g.kategorieId;
    });
  }

  /// Bringt den PageView auf Seite [i]. Hängt der Controller an keinem
  /// PageView (Liste oder «keine Treffer» sichtbar), wird er ersetzt — sonst
  /// startete der nächste PageView an der alten `initialPage`.
  void _seitenAuf(int i) {
    if (_seiten.hasClients) {
      _seiten.jumpToPage(i);
    } else {
      _seiten.dispose();
      _seiten = PageController(initialPage: i);
    }
  }

  void _filterGeaendert(VoidCallback aenderung) {
    setState(() {
      aenderung();
      _karte = 0;
      _behalten.clear();
    });
    _seitenAuf(0);
  }

  /// Karten an [i] zeigen. Speichert die Ansicht NICHT: der Tipp auf eine
  /// Listenzeile ist ein vorübergehender Drill-in.
  void _zeigeKarten(int i) {
    _seitenAuf(i);
    setState(() {
      _ansicht = MaterialAnsicht.karten;
      _karte = i;
    });
  }

  void _umschalten(int anzahl) {
    if (_ansicht == MaterialAnsicht.liste) {
      _zeigeKarten(anzahl == 0 ? 0 : _karte.clamp(0, anzahl - 1));
      MaterialAnsichtSpeicher.speichereAnsicht(MaterialAnsicht.karten);
    } else {
      // Der Controller bleibt; er löst sich mit dem PageView von selbst.
      setState(() => _ansicht = MaterialAnsicht.liste);
      MaterialAnsichtSpeicher.speichereAnsicht(MaterialAnsicht.liste);
    }
  }

  Future<String?> _fotoUrl(Lager l) {
    final materialId = l.materialId;
    if (materialId == null) return Future.value(null);
    return _fotoUrls.putIfAbsent(materialId, () async {
      try {
        final a = await MaterialArtikelRepository.getById(materialId);
        final pfad = a?.fotoStoragePath;
        if (pfad == null) return null;
        // `await`, damit auch ein Fehler hier im catch landet — ein Foto
        // darf die Karte nie stören.
        return await MaterialArtikelRepository.getSignedUrlPreview(pfad);
      } catch (_) {
        return null;
      }
    });
  }

  // Fehler gehen bewusst an die Karte durch — sie setzt die Anzeige zurück.
  // Den Container vor dem await holen: Ist der Screen danach schon zu, darf
  // das Neuladen trotzdem laufen (Badge «N niedrig» in der Leiste), `ref`
  // wäre dann aber nicht mehr benutzbar.
  Future<void> _speichereBestand(Lager l, double neu) async {
    final container = ProviderScope.containerOf(context, listen: false);
    _behalten.add(l.id);
    await LagerRepository.update(l.id, {'bestand_aktuell': neu});
    // Vor dem invalidate: der Rebuild, den es auslöst, soll die Vorgabe
    // schon sehen.
    _bestandLokal[l.id] = neu;
    container.invalidate(materialienStreamProvider);
  }

  Future<void> _speichereVormerken(Lager l, bool v) async {
    final container = ProviderScope.containerOf(context, listen: false);
    await LagerRepository.toggleVorgemerkt(l.id, v);
    container.invalidate(materialienStreamProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Vorgaben aufräumen, sobald der Server den gespeicherten Wert liefert.
    // Im Listener statt im build (dort nichts mutieren); ohne setState — der
    // Rebuild durch das watch unten liest die Map ohnehin neu.
    ref.listen<List<Lager>>(materialienProvider, (_, liste) {
      for (final l in liste) {
        if (_bestandLokal[l.id] == l.bestandAktuell) {
          _bestandLokal.remove(l.id);
        }
      }
    });
    final materialien = ref.watch(materialienProvider);
    final kategorien = ref.watch(kategorienProvider).valueOrNull ?? [];
    final niedrigAnzahl = ref.watch(niedrigCountProvider);

    final kategorieNamen = <String, String>{
      for (final k in kategorien) k.id: k.name,
    };
    final chips = kategorieChips(kategorien, materialien);
    // Die gemerkte Kategorie bleibt in `_kategorie`, auch wenn sie gerade
    // nicht wirkt (Kategorien noch nicht geladen) — nichts wird vergessen.
    final wirksam = wirksameKategorie(_kategorie, chips);
    final gefiltert = filtereMaterial(
      materialien,
      MaterialFilter(
        suche: _suche,
        kategorieId: wirksam,
        nurNiedrig: _nurNiedrig,
        behalten: _behalten,
      ),
    );
    final karten = _ansicht == MaterialAnsicht.karten;
    final zaehlerStil = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material'),
        actions: [
          IconButton(
            icon: Icon(karten ? Icons.view_list : Icons.view_carousel),
            tooltip: karten ? 'Liste' : 'Karten',
            onPressed: () => _umschalten(gefiltert.length),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Bestellungen',
            onPressed: () => context.push('/materialien/bestellungen'),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            tooltip: 'Materialbestellung',
            onPressed: () => context.push('/materialien/bestellen'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBar(
              hintText: 'Material suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => _filterGeaendert(() => _suche = value),
            ),
          ),
          MaterialKategorieChips(
            chips: chips,
            gewaehlt: wirksam,
            nurNiedrig: _nurNiedrig,
            niedrigAnzahl: niedrigAnzahl,
            onKategorie: (id) {
              _filterGeaendert(() => _kategorie = id);
              MaterialAnsichtSpeicher.speichereKategorie(id);
            },
            onNurNiedrig: (v) => _filterGeaendert(() => _nurNiedrig = v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: karten && gefiltert.isNotEmpty
                ? Center(
                    child: Text(
                      '${math.min(_karte, gefiltert.length - 1) + 1} / '
                      '${gefiltert.length}',
                      style: zaehlerStil,
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${gefiltert.length} Materialien',
                      style: zaehlerStil,
                    ),
                  ),
          ),
          Expanded(
            child: gefiltert.isEmpty
                ? _buildEmpty(filterAktiv: wirksam != null)
                : karten
                ? _buildKarten(gefiltert, kategorieNamen)
                : _buildListe(gefiltert, kategorieNamen),
          ),
        ],
      ),
      // In den Karten kein FAB: Er läge genau über dem Vormerken-Kreis
      // unten rechts. Neu anlegen geht von der Liste aus.
      floatingActionButton: _istGast || karten
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/materialien/neu'),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildKarten(List<Lager> gefiltert, Map<String, String> kategorieNamen) {
    // Maus mit dazu: Flutter wischt Scrollables von Haus aus nur per
    // Touch/Stift — am PC-Browser käme man sonst nur über die Liste zur
    // nächsten Karte.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: PointerDeviceKind.values.toSet(),
      ),
      child: PageView.builder(
        controller: _seiten,
        itemCount: gefiltert.length,
        onPageChanged: (i) => setState(() => _karte = i),
        itemBuilder: (context, i) {
          final l = gefiltert[i];
          return MaterialKarte(
            // Key je Artikel: Nach einem Filterwechsel oder Neuladen gehörte
            // der lokale Bestand/Vormerk-Zustand sonst plötzlich zur Karte
            // eines anderen Artikels.
            key: ValueKey(l.id),
            lager: l,
            bestandVorgabe: _bestandLokal[l.id],
            kategorieName:
                l.kategorieId != null ? kategorieNamen[l.kategorieId] : null,
            fotoUrl: _fotoUrl(l),
            bearbeitbar: !_istGast,
            onBestand: (neu) => _speichereBestand(l, neu),
            onVormerken: (v) => _speichereVormerken(l, v),
            onDetails: () => context.push('/materialien/${l.id}'),
          );
        },
      ),
    );
  }

  Widget _buildListe(List<Lager> gefiltert, Map<String, String> kategorieNamen) {
    return ListView.builder(
      // Hält die Scrollposition, wenn man aus den Karten zurückkommt (die
      // Liste wird dabei neu aufgebaut).
      key: const PageStorageKey('material_liste'),
      itemCount: gefiltert.length,
      itemBuilder: (context, index) {
        final lager = gefiltert[index];
        return _MaterialListItem(
          lager: lager,
          kategorieName: lager.kategorieId != null
              ? kategorieNamen[lager.kategorieId]
              : null,
          onTap: () => _zeigeKarten(index),
        );
      },
    );
  }

  Widget _buildEmpty({required bool filterAktiv}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _suche.isNotEmpty || _nurNiedrig || filterAktiv
                ? 'Keine Ergebnisse'
                : 'Noch keine Materialien',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _MaterialListItem extends StatelessWidget {
  final Lager lager;
  final String? kategorieName;
  final VoidCallback onTap;

  const _MaterialListItem({
    required this.lager,
    this.kategorieName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isNiedrig = lager.bestandNiedrig == true;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (isNiedrig ? AppColors.error : AppColors.success).withAlpha(25),
          child: Icon(
            isNiedrig ? Icons.warning : Icons.inventory_2,
            color: isNiedrig ? AppColors.error : AppColors.success,
            size: 20,
          ),
        ),
        title: Text(
          lager.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _buildSubtitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lager.vorgemerkt)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.bookmark, size: 16, color: Colors.orange),
              ),
            Text(
              '${lager.bestandAktuell.toStringAsFixed(0)}/${lager.bestandOptimal.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isNiedrig ? AppColors.error : AppColors.success,
                fontSize: 13,
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (lager.dboNr != null) parts.add('DBO ${lager.dboNr}');
    if (lager.sapNr != null) parts.add('SAP ${lager.sapNr}');
    if (kategorieName != null) parts.add(kategorieName!);
    return parts.join(' · ');
  }
}

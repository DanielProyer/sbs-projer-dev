import 'package:flutter/material.dart';
import 'package:sbs_projer_app/data/models/lager.dart';

/// Lager-Vorschläge eines Material-Slots für die Eingabe [suche].
///
/// Voll (Störung, Montage): leere Eingabe → die ersten 10 Artikel, sonst
/// Treffer im Namen. Einfach (Eigenauftrag): leere Eingabe → nichts, sonst
/// Treffer in Name oder DBO-Nr., höchstens 10.
Iterable<Lager> lagerVorschlaege(
  List<Lager> lager,
  String suche, {
  bool einfach = false,
}) {
  if (einfach) {
    if (suche.isEmpty) return const [];
    final query = suche.toLowerCase();
    return lager
        .where(
          (l) =>
              l.name.toLowerCase().contains(query) ||
              (l.dboNr?.toLowerCase().contains(query) ?? false),
        )
        .take(10);
  }
  if (suche.isEmpty) return lager.take(10);
  final q = suche.toLowerCase();
  return lager.where((l) => l.name.toLowerCase().contains(q));
}

/// N Material-Slots mit Lager-Autocomplete und Mengenfeld (Analyse
/// 25.09.2026, §2.2 — vorher je eine Kopie in Störung, Montage und
/// Eigenauftrag).
///
/// Der Zustand bleibt im Formular: Es besitzt die Listen und Controller und
/// liest sie beim Speichern unverändert aus. Der Baustein schreibt nur hinein
/// — genau wie die früheren privaten `_buildMaterialSlots` — und meldet jede
/// Auswahl/Leerung über [onGeaendert] (→ `markiereGeaendert`). Tippen in die
/// Felder meldet `Form.onChanged` selbst.
///
/// Anzahl der Slots = `ids.length`.
class MaterialSlots extends StatefulWidget {
  /// Lagerartikel; solange leer, sind die Slots einfache Textfelder.
  final List<Lager> lager;

  /// Gewählte Lager-ID je Slot (vom Baustein gesetzt/geleert).
  final List<String?> ids;

  /// Name je Slot. Vorbelegung für das Autocomplete und Feld, solange
  /// [lager] leer ist.
  final List<TextEditingController> namen;

  /// Mengenfeld je Slot.
  final List<TextEditingController> mengenController;

  /// Menge als Zahl je Slot — wird bei jeder Eingabe mitgeschrieben
  /// (`?? 1`). `null`: das Formular liest die Controller selbst
  /// (Eigenauftrag).
  final List<double>? mengen;

  /// Hier legt jedes Autocomplete seinen eigenen Text-Controller ab — der
  /// Speicher-Fallback «getippt, aber nicht gewählt» liest ihn aus.
  /// Eigenauftrag übergibt hier bewusst [namen]: dort ersetzt der
  /// Autocomplete-Controller den Namen-Controller (bisheriges Verhalten).
  final List<TextEditingController?> feldController;

  /// Breite des Mengenfelds (Störung 70, Montage 105, Eigenauftrag 60).
  final double mengenBreite;

  /// Eigenauftrag-Variante: ohne Symbol und Leeren-Knopf, Standardliste nach
  /// unten, Suche auch in der DBO-Nr., Auswahl setzt nur die ID.
  final bool einfach;

  final VoidCallback onGeaendert;

  const MaterialSlots({
    super.key,
    required this.lager,
    required this.ids,
    required this.namen,
    required this.mengenController,
    required this.feldController,
    required this.onGeaendert,
    this.mengen,
    this.mengenBreite = 70,
    this.einfach = false,
  });

  @override
  State<MaterialSlots> createState() => _MaterialSlotsState();
}

class _MaterialSlotsState extends State<MaterialSlots> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        widget.ids.length,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: widget.lager.isNotEmpty
                    ? _autocomplete(i)
                    : TextFormField(
                        controller: widget.namen[i],
                        decoration: InputDecoration(
                          labelText: 'Material ${i + 1}',
                          isDense: true,
                          prefixIcon: widget.einfach
                              ? null
                              : const Icon(Icons.inventory_2, size: 20),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: widget.mengenBreite,
                child: TextFormField(
                  controller: widget.mengenController[i],
                  decoration: const InputDecoration(
                    labelText: 'Anz.',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: widget.mengen == null
                      ? null
                      : (v) => widget.mengen![i] = double.tryParse(v) ?? 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _autocomplete(int i) {
    final einfach = widget.einfach;
    return Autocomplete<Lager>(
      initialValue: TextEditingValue(text: widget.namen[i].text),
      displayStringForOption: (l) => l.name,
      optionsViewOpenDirection: einfach
          ? OptionsViewOpenDirection.down
          : OptionsViewOpenDirection.up,
      optionsBuilder: (textEditingValue) => lagerVorschlaege(
        widget.lager,
        textEditingValue.text,
        einfach: einfach,
      ),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        widget.feldController[i] = controller;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Material ${i + 1}',
            isDense: true,
            prefixIcon: einfach
                ? null
                : const Icon(Icons.inventory_2, size: 20),
            suffixIcon: !einfach && controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      controller.clear();
                      widget.onGeaendert();
                      setState(() {
                        widget.ids[i] = null;
                        widget.namen[i].clear();
                      });
                    },
                  )
                : null,
          ),
        );
      },
      optionsViewBuilder: einfach
          ? null
          : (context, onSelected, options) {
              return Align(
                alignment: Alignment.bottomLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 200,
                      maxWidth: 350,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final l = options.elementAt(index);
                        return ListTile(
                          dense: true,
                          title: Text(l.name),
                          subtitle: l.dboNr != null
                              ? Text(
                                  l.dboNr!,
                                  style: const TextStyle(fontSize: 11),
                                )
                              : null,
                          onTap: () => onSelected(l),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
      onSelected: (l) {
        widget.onGeaendert();
        setState(() {
          widget.ids[i] = l.id;
          if (!einfach) widget.namen[i].text = l.name;
        });
      },
    );
  }
}

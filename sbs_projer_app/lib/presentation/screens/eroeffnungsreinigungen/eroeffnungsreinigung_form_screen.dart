import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/repositories/eroeffnungsreinigung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eroeffnungsreinigung_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EroeffnungsreinigungFormScreen extends ConsumerStatefulWidget {
  final String? eroeffnungsreinigungId;
  final String? betriebId;

  const EroeffnungsreinigungFormScreen({
    super.key,
    this.eroeffnungsreinigungId,
    this.betriebId,
  });

  @override
  ConsumerState<EroeffnungsreinigungFormScreen> createState() =>
      _EroeffnungsreinigungFormScreenState();
}

class _EroeffnungsreinigungFormScreenState
    extends ConsumerState<EroeffnungsreinigungFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  EroeffnungsreinigungLocal? _existing;

  // Felder
  String? _betriebId;
  String _betriebSearchText = '';
  bool _istBergkunde = false;
  late DateTime _datum;
  late final _stoerungsnummerController = TextEditingController();

  // Preise aus Preistabelle
  double _preisNormal = 60.00;
  double _preisBergkunde = 135.00;

  @override
  void initState() {
    super.initState();
    _datum = DateTime.now();
    _betriebId = widget.betriebId;
    _loadPreise();
    if (widget.eroeffnungsreinigungId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadPreise() async {
    try {
      final rows = await SupabaseService.client
          .from('preise')
          .select('eroeffnung_preis_normal, eroeffnung_preis_bergkunde')
          .limit(1);
      if (rows.isNotEmpty && mounted) {
        setState(() {
          _preisNormal =
              double.tryParse(rows.first['eroeffnung_preis_normal'].toString()) ??
                  60.00;
          _preisBergkunde =
              double.tryParse(
                      rows.first['eroeffnung_preis_bergkunde'].toString()) ??
                  135.00;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadExisting() async {
    final er = await EroeffnungsreinigungRepository.getById(
        widget.eroeffnungsreinigungId!);
    if (er == null || !mounted) return;
    setState(() {
      _existing = er;
      _betriebId = er.betriebId;
      _datum = er.datum;
      _istBergkunde = er.istBergkunde;
      _stoerungsnummerController.text = er.stoerungsnummer;
    });
  }

  @override
  void dispose() {
    _stoerungsnummerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.eroeffnungsreinigungId != null;
    final preis = _istBergkunde ? _preisBergkunde : _preisNormal;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? 'Eröffnungsreinigung bearbeiten'
            : 'Neue Eröffnungsreinigung'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Betrieb
            _buildBetriebField(),
            const SizedBox(height: 16),

            // Störungsnummer
            TextFormField(
              controller: _stoerungsnummerController,
              decoration: const InputDecoration(
                labelText: 'Störungsnummer (Heineken) *',
                prefixIcon: Icon(Icons.tag),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Pflichtfeld' : null,
            ),
            const SizedBox(height: 16),

            // Datum
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Datum'),
              subtitle: Text(_formatDate(_datum)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),

            // Preis-Anzeige
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_money,
                      color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _istBergkunde ? 'Bergkunde' : 'Normal',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${preis.toStringAsFixed(2)} CHF',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  if (_istBergkunde)
                    Icon(Icons.terrain,
                        color: AppColors.warning, size: 28),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Speichern
            FilledButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(
                  isEdit ? 'Speichern' : 'Eröffnungsreinigung erfassen'),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildBetriebField() {
    final betriebe = ref
        .watch(betriebeProvider)
        .where((b) => b.serverId != null)
        .toList();

    // Aktuellen Betrieb-Namen finden
    if (_betriebId != null && _betriebSearchText.isEmpty) {
      final match = betriebe.where((b) => b.serverId == _betriebId).toList();
      if (match.isNotEmpty) {
        _betriebSearchText = match.first.name;
        // Auto-detect Bergkunde
        _istBergkunde = match.first.istBergkunde;
      }
    }

    return Autocomplete<BetriebLocal>(
      initialValue: TextEditingValue(text: _betriebSearchText),
      displayStringForOption: (b) => b.name,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return betriebe;
        final query = textEditingValue.text.toLowerCase();
        return betriebe.where((b) => b.name.toLowerCase().contains(query));
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Betrieb *',
            prefixIcon: Icon(Icons.store),
          ),
          validator: (_) =>
              _betriebId == null ? 'Bitte Betrieb auswählen' : null,
          onChanged: (v) {
            if (v.isEmpty) {
              setState(() {
                _betriebId = null;
                _betriebSearchText = '';
                _istBergkunde = false;
              });
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxHeight: 250, maxWidth: 350),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final b = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(b.name),
                    subtitle: b.ort != null ? Text(b.ort!) : null,
                    trailing: b.istBergkunde
                        ? Icon(Icons.terrain,
                            size: 16, color: AppColors.warning)
                        : null,
                    onTap: () => onSelected(b),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (b) {
        setState(() {
          _betriebId = b.serverId;
          _betriebSearchText = b.name;
          _istBergkunde = b.istBergkunde;
        });
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datum,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _datum = picked);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final er = _existing ?? EroeffnungsreinigungLocal();
      er.betriebId = _betriebId;
      er.stoerungsnummer = _stoerungsnummerController.text.trim();
      er.datum = _datum;
      er.istBergkunde = _istBergkunde;
      er.preis = _istBergkunde ? _preisBergkunde : _preisNormal;

      await EroeffnungsreinigungRepository.save(er);
      ref.invalidate(eroeffnungsreinigungenStreamProvider);

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

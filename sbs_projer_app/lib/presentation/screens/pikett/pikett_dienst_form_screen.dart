import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/pikett_dienst_local_export.dart';
import 'package:sbs_projer_app/data/repositories/pikett_dienst_repository.dart';
import 'package:sbs_projer_app/presentation/providers/pikett_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class PikettDienstFormScreen extends ConsumerStatefulWidget {
  final String? pikettId; // null = neu

  const PikettDienstFormScreen({super.key, this.pikettId});

  @override
  ConsumerState<PikettDienstFormScreen> createState() =>
      _PikettDienstFormScreenState();
}

class _PikettDienstFormScreenState
    extends ConsumerState<PikettDienstFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  PikettDienstLocal? _existing;

  // KW-Eingabe
  late int _jahr;
  late int _kw;

  // Pauschale
  double _pauschale = 80.0;
  int _anzahlFeiertage = 0;
  double _feiertagZuschlagProTag = 80.0;

  bool get _isEdit => widget.pikettId != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _jahr = now.year;
    _kw = _isoKw(now);

    _loadPauschale();
    if (_isEdit) _loadPikett();
  }

  Future<void> _loadPauschale() async {
    try {
      final preisRows = await SupabaseService.client
          .from('preise')
          .select('pikett_pauschale, pikett_feiertag_zuschlag')
          .order('gueltig_ab', ascending: false)
          .limit(1);
      if (preisRows.isNotEmpty && mounted) {
        final p = double.tryParse(
            preisRows.first['pikett_pauschale']?.toString() ?? '');
        final f = double.tryParse(
            preisRows.first['pikett_feiertag_zuschlag']?.toString() ?? '');
        setState(() {
          if (p != null) _pauschale = p;
          if (f != null) _feiertagZuschlagProTag = f;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPikett() async {
    final p = await PikettDienstRepository.getById(widget.pikettId!);
    if (p == null || !mounted) return;

    setState(() {
      _existing = p;
      _kw = _isoKw(p.datumStart);
      _jahr = p.datumStart.year;
      _pauschale = p.pauschale ?? 80.0;
      _anzahlFeiertage = p.anzahlFeiertage;
    });
  }

  /// Freitag der gewählten KW berechnen
  DateTime _freitagOfKw(int year, int kw) {
    // ISO 8601: KW 1 enthält den 4. Januar
    final jan4 = DateTime(year, 1, 4);
    final daysSinceMonday = jan4.weekday - 1;
    final mondayKw1 = jan4.subtract(Duration(days: daysSinceMonday));
    final mondayKw = mondayKw1.add(Duration(days: (kw - 1) * 7));
    return mondayKw.add(const Duration(days: 4)); // Freitag = +4
  }

  /// Samstag der gewählten KW berechnen
  DateTime _samstagOfKw(int year, int kw) {
    return _freitagOfKw(year, kw).add(const Duration(days: 1));
  }

  double get _pauschaleGesamt =>
      _pauschale + (_anzahlFeiertage * _feiertagZuschlagProTag);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final p = _existing ?? PikettDienstLocal();

      p.datumStart = _freitagOfKw(_jahr, _kw);
      p.datumEnde = _samstagOfKw(_jahr, _kw);
      p.istAktiv = false;
      p.pauschale = _pauschale;
      p.anzahlFeiertage = _anzahlFeiertage;
      p.feiertagZuschlag = _anzahlFeiertage * _feiertagZuschlagProTag;
      p.pauschaleGesamt = _pauschaleGesamt;

      await PikettDienstRepository.save(p);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit
                ? 'Pikett-Dienst aktualisiert'
                : 'Pikett-Dienst erfasst'),
          ),
        );
        if (kIsWeb) ref.invalidate(pikettDiensteStreamProvider);
        context.pop();
      }
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

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _existing == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final freitag = _freitagOfKw(_jahr, _kw);
    final samstag = _samstagOfKw(_jahr, _kw);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isEdit ? 'Pikett bearbeiten' : 'Neuer Pikett-Dienst'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === Kalenderwoche ===
            _sectionTitle(context, 'Kalenderwoche'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _jahr,
                    decoration: const InputDecoration(
                      labelText: 'Jahr',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    items: List.generate(3, (i) {
                      final y = DateTime.now().year - 1 + i;
                      return DropdownMenuItem(value: y, child: Text('$y'));
                    }),
                    onChanged: (v) {
                      if (v != null) setState(() => _jahr = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _kw,
                    decoration: const InputDecoration(
                      labelText: 'KW',
                      prefixIcon: Icon(Icons.date_range),
                    ),
                    items: List.generate(53, (i) {
                      final w = i + 1;
                      return DropdownMenuItem(value: w, child: Text('KW $w'));
                    }),
                    onChanged: (v) {
                      if (v != null) setState(() => _kw = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Zeiten-Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withAlpha(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Einsatzzeiten KW $_kw',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _zeitRow('Freitag', _formatDate(freitag), '17:00 – 22:00'),
                  _zeitRow('Samstag', _formatDate(samstag), '08:00 – 22:00'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // === Vergütung ===
            _sectionTitle(context, 'Vergütung'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Pauschale',
                      prefixIcon: Icon(Icons.attach_money),
                      suffixText: 'CHF',
                    ),
                    child: Text(_pauschale.toStringAsFixed(2)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _anzahlFeiertage,
                    decoration: const InputDecoration(
                      labelText: 'Feiertage',
                      prefixIcon: Icon(Icons.celebration),
                    ),
                    items: List.generate(4, (i) => DropdownMenuItem(
                      value: i,
                      child: Text('$i'),
                    )),
                    onChanged: (v) {
                      if (v != null) setState(() => _anzahlFeiertage = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildKostenPreview(),
            const SizedBox(height: 24),

            // === Speichern ===
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Speichern' : 'Pikett-Dienst erfassen'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _zeitRow(String tag, String datum, String zeit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(tag, style: const TextStyle(fontSize: 13)),
          ),
          SizedBox(
            width: 90,
            child: Text(datum,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Text(zeit,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildKostenPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _preisRow('Pauschale', '${_pauschale.toStringAsFixed(2)} CHF'),
          if (_anzahlFeiertage > 0)
            _preisRow(
              'Feiertag-Zuschlag',
              '$_anzahlFeiertage × ${_feiertagZuschlagProTag.toStringAsFixed(2)} = '
              '${(_anzahlFeiertage * _feiertagZuschlagProTag).toStringAsFixed(2)} CHF',
            ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gesamt',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              Text(
                '${_pauschaleGesamt.toStringAsFixed(2)} CHF',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preisRow(String label, String betrag) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(betrag, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  static int _isoKw(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    final wday = date.weekday;
    return ((dayOfYear - wday + 10) / 7).floor();
  }
}

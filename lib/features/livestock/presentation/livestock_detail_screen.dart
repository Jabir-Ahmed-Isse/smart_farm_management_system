import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/farm.dart';
import '../../../models/livestock.dart';
import '../data/livestock_repository.dart';
import 'livestock_screen.dart';

const _kinds = <(String, String)>[
  ('health', 'Health check'),
  ('vaccination', 'Vaccination'),
  ('treatment', 'Treatment'),
  ('feeding', 'Feed'),
  ('breeding', 'Breeding'),
  ('milk', 'Milk'),
  ('egg', 'Eggs'),
  ('weight', 'Weight'),
  ('other', 'Other'),
];

String _kindLabel(String key) =>
    _kinds.firstWhere((k) => k.$1 == key, orElse: () => (key, key)).$2;

Color _kindColor(String key) => switch (key) {
      'milk' || 'egg' => AppColors.primary,
      'vaccination' || 'treatment' || 'health' => AppColors.tertiary,
      'breeding' => AppColors.secondary,
      _ => AppColors.outline,
    };

/// One animal or herd: details plus health / production history.
class LivestockDetailScreen extends ConsumerStatefulWidget {
  const LivestockDetailScreen({
    super.key,
    required this.farm,
    required this.animal,
  });

  final Farm farm;
  final Livestock animal;

  @override
  ConsumerState<LivestockDetailScreen> createState() =>
      _LivestockDetailScreenState();
}

class _LivestockDetailScreenState extends ConsumerState<LivestockDetailScreen> {
  late Livestock _animal;

  @override
  void initState() {
    super.initState();
    _animal = widget.animal;
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(livestockRecordsProvider(_animal.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_animal.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'edit' ? _edit() : null,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Header(animal: _animal),
          const SizedBox(height: 20),
          _SummaryCard(
            animal: _animal,
            records: records.valueOrNull ?? const [],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('History', style: AppText.headlineSm),
              TextButton.icon(
                onPressed: _addRecord,
                icon: const Icon(Symbols.add, size: 18),
                label: const Text('Log entry'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          records.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Could not load the history.\n$e',
                  style: AppText.bodyMd.copyWith(color: AppColors.error)),
            ),
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('Nothing logged yet.',
                        style: AppText.bodyMd
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  )
                : Column(
                    children: [
                      for (final r in list)
                        _RecordTile(
                            record: r, onDelete: () => _deleteRecord(r)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit() async {
    await showLivestockSheet(context, widget.farm, existing: _animal);
    final list =
        await ref.read(livestockForFarmProvider(widget.farm.id).future);
    final updated = list.where((a) => a.id == _animal.id).firstOrNull;
    if (updated != null && mounted) setState(() => _animal = updated);
  }

  Future<void> _addRecord() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RecordSheet(farm: widget.farm, animal: _animal),
    );
    if (saved == true) ref.invalidate(livestockRecordsProvider(_animal.id));
  }

  Future<void> _deleteRecord(LivestockRecord record) async {
    final ok = await confirmDelete(context,
        title: 'Delete entry?',
        message: 'Remove the ${_kindLabel(record.kind).toLowerCase()} logged '
            'on ${DateFormat('d MMM yyyy').format(record.date)}?');
    if (ok != true) return;
    try {
      await ref.read(livestockRepositoryProvider).deleteRecord(record.id);
      ref.invalidate(livestockRecordsProvider(_animal.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the entry.')));
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.animal});
  final Livestock animal;

  @override
  Widget build(BuildContext context) {
    final age = animal.ageMonths;
    final meta = <String>[
      speciesLabel(animal.species),
      if (animal.breed != null) animal.breed!,
      if (animal.sex != null) animal.sex!,
      if (age != null) age >= 24 ? '${age ~/ 12} years old' : '$age months old',
      if (animal.acquiredDate != null)
        'since ${DateFormat('MMM yyyy').format(animal.acquiredDate!)}',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  animal.isHerd ? '${animal.count} head' : 'Single animal',
                  style: AppText.headlineSm,
                ),
                const SizedBox(height: 4),
                Text(meta.join(' · '),
                    style: AppText.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
                if (!animal.isActive) ...[
                  const SizedBox(height: 6),
                  Text(livestockStatusLabel(animal.status).toUpperCase(),
                      style: AppText.labelSm.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700)),
                ],
                if (animal.notes != null) ...[
                  const SizedBox(height: 8),
                  Text(animal.notes!, style: AppText.bodyMd),
                ],
              ],
            ),
          ),
          Icon(speciesIcon(animal.species),
              size: 40, color: AppColors.outlineVariant),
        ],
      ),
    );
  }
}

/// Production totals and what care has cost.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.animal, required this.records});

  final Livestock animal;
  final List<LivestockRecord> records;

  @override
  Widget build(BuildContext context) {
    final careCost = records.fold<num>(0, (sum, r) => sum + (r.cost ?? 0));
    final milk = _total(records, 'milk');
    final eggs = _total(records, 'egg');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Metric(label: 'Entries', value: '${records.length}'),
          ),
          if (milk > 0)
            Expanded(
              child: _Metric(
                  label: 'Milk logged', value: _num(milk)),
            ),
          if (eggs > 0)
            Expanded(
              child: _Metric(label: 'Eggs logged', value: _num(eggs)),
            ),
          Expanded(
            child: _Metric(
                label: 'Care cost', value: formatMoney(careCost)),
          ),
        ],
      ),
    );
  }

  static num _total(List<LivestockRecord> records, String kind) => records
      .where((r) => r.kind == kind)
      .fold<num>(0, (sum, r) => sum + (r.quantity ?? 0));

  static String _num(num v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.headlineSm),
        Text(label,
            maxLines: 2,
            style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onDelete});

  final LivestockRecord record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      DateFormat('d MMM yyyy').format(record.date),
      if (record.quantity != null)
        '${record.quantity}${record.unit != null ? ' ${record.unit}' : ''}',
      if (record.notes != null) record.notes!,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: _kindColor(record.kind), shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_kindLabel(record.kind),
                    style:
                        AppText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                Text(meta.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          if (record.cost != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(formatMoney(record.cost!),
                  style:
                      AppText.labelMd.copyWith(fontWeight: FontWeight.w700)),
            ),
          IconButton(
            icon: const Icon(Symbols.delete, size: 20),
            color: AppColors.onSurfaceVariant,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Log a health / production entry. Pops true when saved.
class _RecordSheet extends ConsumerStatefulWidget {
  const _RecordSheet({required this.farm, required this.animal});

  final Farm farm;
  final Livestock animal;

  @override
  ConsumerState<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<_RecordSheet> {
  final _qtyCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _kind = 'health';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Sensible default unit for the kind of entry being logged.
  void _applyKind(String kind) {
    setState(() {
      _kind = kind;
      if (_unitCtrl.text.isEmpty || _unitCtrl.text == _defaultUnit(_kind)) {
        _unitCtrl.text = _defaultUnit(kind);
      }
    });
  }

  static String _defaultUnit(String kind) => switch (kind) {
        'milk' => 'liter',
        'egg' => 'eggs',
        'weight' => 'kg',
        'feeding' => 'kg',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.animal.name} — log entry',
                style: AppText.headlineSm),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in _kinds)
                  ChoiceChip(
                    label: Text(k.$2),
                    selected: _kind == k.$1,
                    onSelected: (_) => _applyKind(k.$1),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Row(
                  children: [
                    const Icon(Symbols.event,
                        size: 20, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(DateFormat('d MMM yyyy').format(_date),
                        style: AppText.bodyMd),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unitCtrl,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _costCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              decoration:
                  const InputDecoration(labelText: 'Cost', prefixText: '\$ '),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Notes (optional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: AppText.labelMd.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onPrimary))
                  : const Text('Save entry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(livestockRepositoryProvider).addRecord(
            farmId: widget.farm.id,
            livestockId: widget.animal.id,
            date: _date,
            kind: _kind,
            quantity: num.tryParse(_qtyCtrl.text.trim()),
            unit: _unitCtrl.text,
            cost: num.tryParse(_costCtrl.text.trim()),
            notes: _notesCtrl.text,
          );
      nav.pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the entry.';
        });
      }
    }
  }
}

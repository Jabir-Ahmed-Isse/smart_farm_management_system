import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/crop.dart';
import '../../../models/farm.dart';
import '../../../models/irrigation_log.dart';
import '../../../models/plot.dart';
import '../../expenses/data/expense_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/irrigation_repository.dart';

const _methods = <(String, String)>[
  ('drip', 'Drip'),
  ('sprinkler', 'Sprinkler'),
  ('flood', 'Flood'),
  ('furrow', 'Furrow'),
  ('manual', 'By hand'),
  ('rain', 'Rain'),
  ('other', 'Other'),
];

const _sources = <(String, String)>[
  ('well', 'Well'),
  ('borehole', 'Borehole'),
  ('river', 'River'),
  ('canal', 'Canal'),
  ('dam', 'Dam'),
  ('rain', 'Rain'),
  ('municipal', 'Municipal'),
  ('tanker', 'Tanker'),
  ('other', 'Other'),
];

const _units = <String>['liter', 'm³', 'gallon', 'hour'];

String _methodLabel(String key) =>
    _methods.firstWhere((m) => m.$1 == key, orElse: () => (key, key)).$2;

String _sourceLabel(String key) =>
    _sources.firstWhere((s) => s.$1 == key, orElse: () => (key, key)).$2;

/// Irrigation log — every watering event, with monthly totals.
class WaterScreen extends ConsumerWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farm = ref.watch(activeFarmProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(ref.watch(stringsProvider).water)),
      floatingActionButton: farm == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showIrrigationSheet(context, farm),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Symbols.water_drop),
              label: Text(ref.watch(stringsProvider).logWatering),
            ),
      body: farm == null
          ? const Center(child: Text('Create a farm to log irrigation.'))
          : _Body(farm: farm),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(irrigationForFarmProvider(farm.id));

    return logs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load the irrigation log.\n$e',
              textAlign: TextAlign.center,
              style:
                  AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.water_drop,
                      size: 56, color: AppColors.outline),
                  const SizedBox(height: 12),
                  Text('No watering logged yet',
                      style: AppText.headlineSm, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Record each watering to see how much water — and '
                      'money — each plot takes.',
                      style: AppText.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final now = DateTime.now();
        final thisMonth = list
            .where((l) => l.date.year == now.year && l.date.month == now.month)
            .toList();
        // Volumes only add up within one unit, so total the dominant one.
        final unit = _dominantUnit(thisMonth);
        final volume = thisMonth
            .where((l) => l.volumeUnit == unit)
            .fold<num>(0, (sum, l) => sum + (l.volume ?? 0));
        final spend = thisMonth.fold<num>(0, (sum, l) => sum + (l.cost ?? 0));

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(irrigationForFarmProvider(farm.id)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Symbols.water_drop,
                      color: AppColors.primary,
                      value: volume > 0
                          ? '${_num(volume)} $unit'
                          : '${thisMonth.length}',
                      label: volume > 0
                          ? 'Water this month'
                          : 'Waterings this month',
                    ),
                  ),
                  if (spend > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Symbols.payments,
                        color: AppColors.tertiary,
                        value: formatMoneyCompact(spend),
                        label: 'Spent this month',
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              for (final log in list)
                _LogTile(
                  log: log,
                  onEdit: () =>
                      showIrrigationSheet(context, farm, existing: log),
                  onDelete: () => _delete(context, ref, log),
                ),
            ],
          ),
        );
      },
    );
  }

  /// The unit most of this month's entries use, so the total means something.
  static String _dominantUnit(List<IrrigationLog> logs) {
    final counts = <String, int>{};
    for (final l in logs.where((l) => l.volume != null)) {
      counts[l.volumeUnit] = (counts[l.volumeUnit] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'liter';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static String _num(num v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _delete(
      BuildContext context, WidgetRef ref, IrrigationLog log) async {
    final ok = await confirmDelete(context,
        title: 'Delete record?',
        message:
            'Remove the watering logged on ${DateFormat('d MMM yyyy').format(log.date)}?');
    if (ok != true) return;
    try {
      await ref.read(irrigationRepositoryProvider).deleteLog(log.id);
      ref.invalidate(irrigationForFarmProvider(farm.id));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the record.')));
      }
    }
  }
}

/// Add / edit a watering event.
Future<void> showIrrigationSheet(
  BuildContext context,
  Farm farm, {
  IrrigationLog? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _IrrigationSheet(farm: farm, existing: existing),
  );
}

class _IrrigationSheet extends ConsumerStatefulWidget {
  const _IrrigationSheet({required this.farm, this.existing});

  final Farm farm;
  final IrrigationLog? existing;

  @override
  ConsumerState<_IrrigationSheet> createState() => _IrrigationSheetState();
}

class _IrrigationSheetState extends ConsumerState<_IrrigationSheet> {
  late final TextEditingController _volumeCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _date;
  late String _method;
  late String _unit;
  String? _source;
  String? _plotId;
  String? _cropId;
  String? _error;
  bool _saving = false;

  IrrigationLog? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    _volumeCtrl =
        TextEditingController(text: _existing?.volume?.toString() ?? '');
    _durationCtrl = TextEditingController(
        text: _existing?.durationMinutes?.toString() ?? '');
    _costCtrl = TextEditingController(text: _existing?.cost?.toString() ?? '');
    _notesCtrl = TextEditingController(text: _existing?.notes ?? '');
    _date = _existing?.date ?? DateTime.now();
    _method = _existing?.method ?? 'drip';
    _unit = _existing?.volumeUnit ?? 'liter';
    _source = _existing?.source;
    _plotId = _existing?.plotId;
    _cropId = _existing?.cropId;
  }

  @override
  void dispose() {
    _volumeCtrl.dispose();
    _durationCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farmId = widget.farm.id;
    final plots =
        ref.watch(plotsForFarmProvider(farmId)).valueOrNull ?? const <Plot>[];
    final crops =
        ref.watch(cropsForFarmProvider(farmId)).valueOrNull ?? const <Crop>[];

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
            Text(_existing == null ? 'Log watering' : 'Edit record',
                style: AppText.headlineSm),
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
                    Text(DateFormat('EEE d MMM yyyy').format(_date),
                        style: AppText.bodyMd),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Method', style: AppText.labelMd),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _methods)
                  ChoiceChip(
                    label: Text(m.$2),
                    selected: _method == m.$1,
                    onSelected: (_) => setState(() => _method = m.$1),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _volumeCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    decoration: const InputDecoration(labelText: 'Volume'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: [
                      for (final u in _units)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (v) => setState(() => _unit = v ?? 'liter'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    decoration:
                        const InputDecoration(labelText: 'Minutes run'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _costCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    decoration: const InputDecoration(
                        labelText: 'Cost', prefixText: '\$ '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _source,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Water source'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Not recorded')),
                for (final s in _sources)
                  DropdownMenuItem<String?>(value: s.$1, child: Text(s.$2)),
              ],
              onChanged: (v) => setState(() => _source = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: plots.any((p) => p.id == _plotId) ? _plotId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Plot (optional)'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('No plot')),
                for (final p in plots)
                  DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _plotId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: crops.any((c) => c.id == _cropId) ? _cropId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Crop (optional)'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('No crop')),
                for (final c in crops)
                  DropdownMenuItem<String?>(
                      value: c.id, child: Text(c.displayName)),
              ],
              onChanged: (v) => setState(() => _cropId = v),
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
                  : Text(_existing == null ? 'Save watering' : 'Save changes'),
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
      final repo = ref.read(irrigationRepositoryProvider);
      final volume = num.tryParse(_volumeCtrl.text.trim());
      final duration = num.tryParse(_durationCtrl.text.trim());
      final cost = num.tryParse(_costCtrl.text.trim());
      if (_existing == null) {
        await repo.createLog(
          farmId: widget.farm.id,
          date: _date,
          method: _method,
          plotId: _plotId,
          cropId: _cropId,
          source: _source,
          durationMinutes: duration,
          volume: volume,
          volumeUnit: _unit,
          cost: cost,
          notes: _notesCtrl.text,
        );
      } else {
        await repo.updateLog(
          id: _existing!.id,
          date: _date,
          method: _method,
          plotId: _plotId,
          cropId: _cropId,
          source: _source,
          durationMinutes: duration,
          volume: volume,
          volumeUnit: _unit,
          cost: cost,
          notes: _notesCtrl.text,
        );
      }
      ref.invalidate(irrigationForFarmProvider(widget.farm.id));
      nav.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the record.';
        });
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.headlineSm.copyWith(color: color)),
                Text(label,
                    maxLines: 2,
                    style: AppText.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.log,
    required this.onEdit,
    required this.onDelete,
  });

  final IrrigationLog log;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (log.plotName != null) log.plotName!,
      if (log.cropName != null) log.cropName!,
      if (log.source != null) _sourceLabel(log.source!),
      if (log.durationMinutes != null) '${log.durationMinutes} min',
      if (log.notes != null) log.notes!,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${DateFormat('d MMM').format(log.date)}'
                        ' · ${_methodLabel(log.method)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyMd
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (log.volume != null) ...[
                      const SizedBox(width: 8),
                      Text('${log.volume} ${log.volumeUnit}',
                          style: AppText.labelMd
                              .copyWith(color: AppColors.primary)),
                    ],
                  ],
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          if (log.cost != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(formatMoney(log.cost!),
                  style:
                      AppText.labelMd.copyWith(fontWeight: FontWeight.w700)),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Symbols.more_vert,
                color: AppColors.onSurfaceVariant),
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/crop.dart';
import '../../../models/farm.dart';
import '../../../models/nursery_batch.dart';
import '../../../models/plot.dart';
import '../../expenses/data/expense_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/nursery_repository.dart';

const _statuses = <(String, String)>[
  ('sown', 'Sown'),
  ('germinating', 'Germinating'),
  ('hardening', 'Hardening off'),
  ('ready', 'Ready'),
  ('transplanted', 'Transplanted'),
  ('failed', 'Failed'),
];

String _statusLabel(String key) =>
    _statuses.firstWhere((s) => s.$1 == key, orElse: () => (key, key)).$2;

Color _statusColor(String key) => switch (key) {
      'ready' => AppColors.primary,
      'germinating' || 'hardening' => AppColors.tertiary,
      'failed' => AppColors.error,
      'transplanted' => AppColors.outline,
      _ => AppColors.secondary,
    };

/// Nursery — seedling batches from sowing to transplant.
class NurseryScreen extends ConsumerWidget {
  const NurseryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(myFarmsProvider);
    final farm =
        farms.valueOrNull?.isNotEmpty == true ? farms.value!.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(ref.watch(stringsProvider).nursery)),
      floatingActionButton: farm == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showBatchSheet(context, farm),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Symbols.add),
              label: Text(ref.watch(stringsProvider).newBatch),
            ),
      body: farm == null
          ? const Center(child: Text('Create a farm to raise seedlings.'))
          : _Body(farm: farm),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(nurseryForFarmProvider(farm.id));

    return batches.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load the nursery.\n$e',
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
                  const Icon(Symbols.potted_plant,
                      size: 56, color: AppColors.outline),
                  const SizedBox(height: 12),
                  Text('No seedling batches yet',
                      style: AppText.headlineSm, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Track each sowing from seed to transplant, and see '
                      'how much of it came up.',
                      style: AppText.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final due = list.where((b) => b.isDueToTransplant).length;
        final growing = list.where((b) => !b.isClosed).length;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(nurseryForFarmProvider(farm.id)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Symbols.potted_plant,
                      color: AppColors.primary,
                      value: '$growing',
                      label: 'Batches growing',
                    ),
                  ),
                  if (due > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Symbols.agriculture,
                        color: AppColors.tertiary,
                        value: '$due',
                        label: 'Ready to transplant',
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              for (final batch in list)
                _BatchTile(
                  batch: batch,
                  onEdit: () => showBatchSheet(context, farm, existing: batch),
                  onDelete: () => _delete(context, ref, batch),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, NurseryBatch batch) async {
    final ok = await confirmDelete(context,
        title: 'Delete batch?', message: 'Remove "${batch.name}"?');
    if (ok != true) return;
    try {
      await ref.read(nurseryRepositoryProvider).deleteBatch(batch.id);
      ref.invalidate(nurseryForFarmProvider(farm.id));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the batch.')));
      }
    }
  }
}

/// Add / edit a seedling batch.
Future<void> showBatchSheet(
  BuildContext context,
  Farm farm, {
  NurseryBatch? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _BatchSheet(farm: farm, existing: existing),
  );
}

class _BatchSheet extends ConsumerStatefulWidget {
  const _BatchSheet({required this.farm, this.existing});

  final Farm farm;
  final NurseryBatch? existing;

  @override
  ConsumerState<_BatchSheet> createState() => _BatchSheetState();
}

class _BatchSheetState extends ConsumerState<_BatchSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _varietyCtrl;
  late final TextEditingController _sourceCtrl;
  late final TextEditingController _sownCtrl;
  late final TextEditingController _germCtrl;
  late final TextEditingController _transCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _sowDate;
  late String _status;
  DateTime? _expected;
  DateTime? _actual;
  String? _cropId;
  String? _plotId;
  String? _error;
  bool _saving = false;

  NurseryBatch? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _existing?.name ?? '');
    _varietyCtrl = TextEditingController(text: _existing?.variety ?? '');
    _sourceCtrl = TextEditingController(text: _existing?.seedSource ?? '');
    _sownCtrl =
        TextEditingController(text: _existing?.quantitySown?.toString() ?? '');
    _germCtrl = TextEditingController(
        text: _existing?.quantityGerminated?.toString() ?? '');
    _transCtrl = TextEditingController(
        text: _existing?.quantityTransplanted?.toString() ?? '');
    _notesCtrl = TextEditingController(text: _existing?.notes ?? '');
    _sowDate = _existing?.sowDate ?? DateTime.now();
    _status = _existing?.status ?? 'sown';
    _expected = _existing?.expectedTransplantDate;
    _actual = _existing?.actualTransplantDate;
    _cropId = _existing?.cropId;
    _plotId = _existing?.plotId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _varietyCtrl.dispose();
    _sourceCtrl.dispose();
    _sownCtrl.dispose();
    _germCtrl.dispose();
    _transCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farmId = widget.farm.id;
    final crops =
        ref.watch(cropsForFarmProvider(farmId)).valueOrNull ?? const <Crop>[];
    final plots =
        ref.watch(plotsForFarmProvider(farmId)).valueOrNull ?? const <Plot>[];

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
            Text(_existing == null ? 'New seedling batch' : 'Edit batch',
                style: AppText.headlineSm),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: _existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  hintText: 'Batch name (e.g. Tomato tray 1)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _varietyCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Variety'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _sourceCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(labelText: 'Seed source'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DateRow(
              icon: Symbols.event,
              label: 'Sown',
              value: _sowDate,
              onPick: (d) => setState(() => _sowDate = d ?? _sowDate),
              clearable: false,
            ),
            const SizedBox(height: 16),
            Text('Status', style: AppText.labelMd),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _statuses)
                  ChoiceChip(
                    label: Text(s.$2),
                    selected: _status == s.$1,
                    onSelected: (_) => setState(() => _status = s.$1),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sownCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    decoration: const InputDecoration(labelText: 'Seeds sown'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _germCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    decoration:
                        const InputDecoration(labelText: 'Came up'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _transCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    decoration:
                        const InputDecoration(labelText: 'Planted out'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DateRow(
              icon: Symbols.schedule,
              label: 'Expected transplant (optional)',
              value: _expected,
              onPick: (d) => setState(() => _expected = d),
            ),
            const SizedBox(height: 12),
            _DateRow(
              icon: Symbols.agriculture,
              label: 'Actually transplanted (optional)',
              value: _actual,
              onPick: (d) => setState(() => _actual = d),
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
            DropdownButtonFormField<String?>(
              initialValue: plots.any((p) => p.id == _plotId) ? _plotId : null,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Destination plot'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Not decided')),
                for (final p in plots)
                  DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _plotId = v),
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
                  : Text(_existing == null ? 'Add batch' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'A batch name is required.');
      return;
    }
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(nurseryRepositoryProvider);
      final sown = int.tryParse(_sownCtrl.text.trim());
      final germ = int.tryParse(_germCtrl.text.trim());
      final trans = int.tryParse(_transCtrl.text.trim());
      if (_existing == null) {
        await repo.createBatch(
          farmId: widget.farm.id,
          name: _nameCtrl.text.trim(),
          sowDate: _sowDate,
          status: _status,
          variety: _varietyCtrl.text,
          seedSource: _sourceCtrl.text,
          cropId: _cropId,
          plotId: _plotId,
          quantitySown: sown,
          quantityGerminated: germ,
          quantityTransplanted: trans,
          expectedTransplantDate: _expected,
          actualTransplantDate: _actual,
          notes: _notesCtrl.text,
        );
      } else {
        await repo.updateBatch(
          id: _existing!.id,
          name: _nameCtrl.text.trim(),
          sowDate: _sowDate,
          status: _status,
          variety: _varietyCtrl.text,
          seedSource: _sourceCtrl.text,
          cropId: _cropId,
          plotId: _plotId,
          quantitySown: sown,
          quantityGerminated: germ,
          quantityTransplanted: trans,
          expectedTransplantDate: _expected,
          actualTransplantDate: _actual,
          notes: _notesCtrl.text,
        );
      }
      ref.invalidate(nurseryForFarmProvider(widget.farm.id));
      nav.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the batch.';
        });
      }
    }
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPick,
    this.clearable = true,
  });

  final IconData icon;
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value == null
                    ? label
                    : '$label — ${DateFormat('d MMM yyyy').format(value!)}',
                style: AppText.bodyMd.copyWith(
                    color: value == null
                        ? AppColors.onSurfaceVariant
                        : AppColors.onSurface),
              ),
            ),
            if (value != null && clearable)
              IconButton(
                icon: const Icon(Symbols.close, size: 18),
                onPressed: () => onPick(null),
              ),
          ],
        ),
      ),
    );
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
                Text(value, style: AppText.headlineSm.copyWith(color: color)),
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

class _BatchTile extends StatelessWidget {
  const _BatchTile({
    required this.batch,
    required this.onEdit,
    required this.onDelete,
  });

  final NurseryBatch batch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rate = batch.germinationRate;
    final meta = <String>[
      if (batch.variety != null) batch.variety!,
      if (batch.cropName != null) batch.cropName!,
      'sown ${DateFormat('d MMM').format(batch.sowDate)}',
      if (batch.quantitySown != null) '${batch.quantitySown} seeds',
      if (rate != null) '${(rate * 100).round()}% up',
      if (batch.plotName != null) '→ ${batch.plotName!}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: batch.isDueToTransplant
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: _statusColor(batch.status), shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(batch.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                              color: batch.isClosed
                                  ? AppColors.onSurfaceVariant
                                  : AppColors.onSurface)),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                        text: _statusLabel(batch.status).toUpperCase(),
                        color: _statusColor(batch.status)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(meta.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: AppText.labelSm.copyWith(
              color: color, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }
}

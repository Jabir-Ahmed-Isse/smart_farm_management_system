import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/equipment.dart';
import '../../../models/farm.dart';
import '../data/equipment_repository.dart';
import 'equipment_screen.dart';

const _kinds = <(String, String)>[
  ('service', 'Service'),
  ('repair', 'Repair'),
  ('inspection', 'Inspection'),
  ('other', 'Other'),
];

String _kindLabel(String key) =>
    _kinds.firstWhere((k) => k.$1 == key, orElse: () => (key, key)).$2;

/// One machine: its details and full service history.
class EquipmentDetailScreen extends ConsumerStatefulWidget {
  const EquipmentDetailScreen({
    super.key,
    required this.farm,
    required this.equipment,
  });

  final Farm farm;
  final Equipment equipment;

  @override
  ConsumerState<EquipmentDetailScreen> createState() =>
      _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends ConsumerState<EquipmentDetailScreen> {
  late Equipment _item;

  @override
  void initState() {
    super.initState();
    _item = widget.equipment;
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(maintenanceForEquipmentProvider(_item.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_item.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'edit' ? _edit() : null,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit equipment')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Header(item: _item),
          const SizedBox(height: 20),
          _CostCard(
            item: _item,
            logs: logs.valueOrNull ?? const [],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Service history', style: AppText.headlineSm),
              TextButton.icon(
                onPressed: _addLog,
                icon: const Icon(Symbols.add, size: 18),
                label: const Text('Log service'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          logs.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Could not load the service history.\n$e',
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
                      for (final log in list)
                        _LogTile(log: log, onDelete: () => _deleteLog(log)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit() async {
    await showEquipmentSheet(context, widget.farm, existing: _item);
    final list =
        await ref.read(equipmentForFarmProvider(widget.farm.id).future);
    final updated = list.where((e) => e.id == _item.id).firstOrNull;
    if (updated != null && mounted) setState(() => _item = updated);
  }

  Future<void> _addLog() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MaintenanceSheet(farm: widget.farm, equipment: _item),
    );
    if (saved == true) {
      ref.invalidate(maintenanceForEquipmentProvider(_item.id));
    }
  }

  Future<void> _deleteLog(MaintenanceLog log) async {
    final ok = await confirmDelete(context,
        title: 'Delete record?',
        message: 'Remove the ${_kindLabel(log.kind).toLowerCase()} logged on '
            '${DateFormat('d MMM yyyy').format(log.date)}?');
    if (ok != true) return;
    try {
      await ref.read(equipmentRepositoryProvider).deleteMaintenance(log.id);
      ref.invalidate(maintenanceForEquipmentProvider(_item.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the record.')));
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item});
  final Equipment item;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (item.type != null) item.type!,
      if (item.serialNumber != null) item.serialNumber!,
      if (item.purchaseDate != null)
        'bought ${DateFormat('MMM yyyy').format(item.purchaseDate!)}',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: equipmentStatusColor(item.status),
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(equipmentStatusLabel(item.status),
                  style: AppText.labelMd.copyWith(
                      color: equipmentStatusColor(item.status),
                      fontWeight: FontWeight.w700)),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(meta.join(' · '),
                style: AppText.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ],
          if (item.nextServiceDate != null) ...[
            const SizedBox(height: 8),
            Text(
              item.isServiceOverdue
                  ? 'Service was due ${DateFormat('d MMM yyyy').format(item.nextServiceDate!)}'
                  : 'Next service ${DateFormat('d MMM yyyy').format(item.nextServiceDate!)}',
              style: AppText.labelMd.copyWith(
                  color: item.isServiceOverdue
                      ? AppColors.error
                      : AppColors.onSurface),
            ),
          ],
          if (item.notes != null) ...[
            const SizedBox(height: 8),
            Text(item.notes!, style: AppText.bodyMd),
          ],
        ],
      ),
    );
  }
}

/// What the machine has cost so far — purchase plus every service logged.
class _CostCard extends StatelessWidget {
  const _CostCard({required this.item, required this.logs});

  final Equipment item;
  final List<MaintenanceLog> logs;

  @override
  Widget build(BuildContext context) {
    final upkeep = logs.fold<num>(0, (sum, l) => sum + (l.cost ?? 0));
    final total = (item.purchaseCost ?? 0) + upkeep;

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
            child: _Metric(
                label: 'Upkeep spent', value: formatMoney(upkeep)),
          ),
          Expanded(
            child: _Metric(
                label: 'Services logged', value: '${logs.length}'),
          ),
          if (item.purchaseCost != null)
            Expanded(
              child:
                  _Metric(label: 'Total cost', value: formatMoney(total)),
            ),
        ],
      ),
    );
  }
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

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log, required this.onDelete});

  final MaintenanceLog log;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      DateFormat('d MMM yyyy').format(log.date),
      if (log.performedBy != null) log.performedBy!,
      if (log.notes != null) log.notes!,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_kindLabel(log.kind),
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
          if (log.cost != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(formatMoney(log.cost!),
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

/// Log a service / repair. Pops true when saved.
class _MaintenanceSheet extends ConsumerStatefulWidget {
  const _MaintenanceSheet({required this.farm, required this.equipment});

  final Farm farm;
  final Equipment equipment;

  @override
  ConsumerState<_MaintenanceSheet> createState() => _MaintenanceSheetState();
}

class _MaintenanceSheetState extends ConsumerState<_MaintenanceSheet> {
  final _costCtrl = TextEditingController();
  final _byCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _kind = 'service';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _costCtrl.dispose();
    _byCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

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
            Text('${widget.equipment.name} — log service',
                style: AppText.headlineSm),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final k in _kinds)
                  ChoiceChip(
                    label: Text(k.$2),
                    selected: _kind == k.$1,
                    onSelected: (_) => setState(() => _kind = k.$1),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
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
              controller: _byCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  hintText: 'Done by (mechanic / shop) — optional'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  hintText: 'What was done (optional)'),
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
                  : const Text('Save record'),
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
      await ref.read(equipmentRepositoryProvider).addMaintenance(
            farmId: widget.farm.id,
            equipmentId: widget.equipment.id,
            date: _date,
            kind: _kind,
            cost: num.tryParse(_costCtrl.text.trim()),
            performedBy: _byCtrl.text,
            notes: _notesCtrl.text,
          );
      nav.pop(true);
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

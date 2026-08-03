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
import '../../../models/equipment.dart';
import '../../../models/farm.dart';
import '../../profile/data/profile_repository.dart';
import '../data/equipment_repository.dart';
import 'equipment_detail_screen.dart';

const equipmentStatuses = <(String, String)>[
  ('operational', 'Working'),
  ('maintenance', 'In service'),
  ('broken', 'Broken'),
  ('retired', 'Retired'),
];

String equipmentStatusLabel(String key) =>
    equipmentStatuses.firstWhere((s) => s.$1 == key, orElse: () => (key, key)).$2;

Color equipmentStatusColor(String key) => switch (key) {
      'operational' => AppColors.primary,
      'maintenance' => AppColors.tertiary,
      'broken' => AppColors.error,
      _ => AppColors.outline,
    };

/// Farm equipment with service-due alerts and full CRUD.
class EquipmentScreen extends ConsumerWidget {
  const EquipmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(myFarmsProvider);
    final farm =
        farms.valueOrNull?.isNotEmpty == true ? farms.value!.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(ref.watch(stringsProvider).equipment)),
      floatingActionButton: farm == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showEquipmentSheet(context, farm),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Symbols.add),
              label: Text(ref.watch(stringsProvider).addEquipment),
            ),
      body: farm == null
          ? const Center(child: Text('Create a farm to track equipment.'))
          : _Body(farm: farm),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(equipmentForFarmProvider(farm.id));

    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load equipment.\n$e',
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
                  const Icon(Symbols.agriculture,
                      size: 56, color: AppColors.outline),
                  const SizedBox(height: 12),
                  Text('No equipment yet',
                      style: AppText.headlineSm, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Track tractors, pumps and tools — and when each one '
                      'is next due for service.',
                      style: AppText.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final down = list.where((e) => e.needsAttention).length;
        final serviceDue = list
            .where((e) => e.isServiceOverdue || e.isServiceDueSoon)
            .length;

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(equipmentForFarmProvider(farm.id)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (down > 0 || serviceDue > 0) ...[
                Row(
                  children: [
                    if (down > 0)
                      Expanded(
                        child: _AlertCard(
                          icon: Symbols.build,
                          color: AppColors.error,
                          count: down,
                          label: 'Down / in service',
                        ),
                      ),
                    if (down > 0 && serviceDue > 0) const SizedBox(width: 12),
                    if (serviceDue > 0)
                      Expanded(
                        child: _AlertCard(
                          icon: Symbols.schedule,
                          color: AppColors.tertiary,
                          count: serviceDue,
                          label: 'Service due',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              for (final item in list)
                _EquipmentTile(
                  item: item,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          EquipmentDetailScreen(farm: farm, equipment: item),
                    ),
                  ),
                  onEdit: () =>
                      showEquipmentSheet(context, farm, existing: item),
                  onDelete: () => _delete(context, ref, item),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Equipment item) async {
    final ok = await confirmDelete(context,
        title: 'Delete equipment?',
        message: 'Remove "${item.name}"? Its service history goes too. '
            'To keep the history, set it to Retired instead.');
    if (ok != true) return;
    try {
      await ref.read(equipmentRepositoryProvider).deleteEquipment(item.id);
      ref.invalidate(equipmentForFarmProvider(farm.id));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the equipment.')));
      }
    }
  }
}

/// Add / edit equipment.
Future<void> showEquipmentSheet(
  BuildContext context,
  Farm farm, {
  Equipment? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _EquipmentSheet(farm: farm, existing: existing),
  );
}

class _EquipmentSheet extends ConsumerStatefulWidget {
  const _EquipmentSheet({required this.farm, this.existing});

  final Farm farm;
  final Equipment? existing;

  @override
  ConsumerState<_EquipmentSheet> createState() => _EquipmentSheetState();
}

class _EquipmentSheetState extends ConsumerState<_EquipmentSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _typeCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _notesCtrl;
  late String _status;
  DateTime? _purchaseDate;
  DateTime? _nextService;
  String? _error;
  bool _saving = false;

  Equipment? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _existing?.name ?? '');
    _typeCtrl = TextEditingController(text: _existing?.type ?? '');
    _serialCtrl = TextEditingController(text: _existing?.serialNumber ?? '');
    _costCtrl =
        TextEditingController(text: _existing?.purchaseCost?.toString() ?? '');
    _notesCtrl = TextEditingController(text: _existing?.notes ?? '');
    _status = _existing?.status ?? 'operational';
    _purchaseDate = _existing?.purchaseDate;
    _nextService = _existing?.nextServiceDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _serialCtrl.dispose();
    _costCtrl.dispose();
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
            Text(_existing == null ? 'Add equipment' : 'Edit equipment',
                style: AppText.headlineSm),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: _existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  hintText: 'Name (e.g. Massey Ferguson 385)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _typeCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Type', hintText: 'Tractor'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      for (final s in equipmentStatuses)
                        DropdownMenuItem(value: s.$1, child: Text(s.$2)),
                    ],
                    onChanged: (v) =>
                        setState(() => _status = v ?? 'operational'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _serialCtrl,
              decoration: const InputDecoration(
                  hintText: 'Serial / plate number (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _costCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              decoration: const InputDecoration(
                  labelText: 'Purchase cost', prefixText: '\$ '),
            ),
            const SizedBox(height: 12),
            _DateField(
              icon: Symbols.event,
              label: 'Purchase date (optional)',
              value: _purchaseDate,
              onPick: (d) => setState(() => _purchaseDate = d),
            ),
            const SizedBox(height: 12),
            _DateField(
              icon: Symbols.build,
              label: 'Next service due (optional)',
              value: _nextService,
              onPick: (d) => setState(() => _nextService = d),
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
                  : Text(_existing == null ? 'Add equipment' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'A name is required.');
      return;
    }
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(equipmentRepositoryProvider);
      final cost = num.tryParse(_costCtrl.text.trim());
      if (_existing == null) {
        await repo.createEquipment(
          farmId: widget.farm.id,
          name: _nameCtrl.text.trim(),
          status: _status,
          type: _typeCtrl.text,
          serialNumber: _serialCtrl.text,
          purchaseDate: _purchaseDate,
          purchaseCost: cost,
          nextServiceDate: _nextService,
          notes: _notesCtrl.text,
        );
      } else {
        await repo.updateEquipment(
          id: _existing!.id,
          name: _nameCtrl.text.trim(),
          status: _status,
          type: _typeCtrl.text,
          serialNumber: _serialCtrl.text,
          purchaseDate: _purchaseDate,
          purchaseCost: cost,
          nextServiceDate: _nextService,
          notes: _notesCtrl.text,
        );
      }
      ref.invalidate(equipmentForFarmProvider(widget.farm.id));
      nav.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the equipment.';
        });
      }
    }
  }
}

/// Tappable date row used by the equipment and maintenance sheets.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPick,
  });

  final IconData icon;
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
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
                value == null ? label : DateFormat('d MMM yyyy').format(value!),
                style: AppText.bodyMd.copyWith(
                    color: value == null
                        ? AppColors.onSurfaceVariant
                        : AppColors.onSurface),
              ),
            ),
            if (value != null)
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

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final int count;
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
                Text('$count',
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

class _EquipmentTile extends StatelessWidget {
  const _EquipmentTile({
    required this.item,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Equipment item;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (item.type != null) item.type!,
      equipmentStatusLabel(item.status),
      if (item.nextServiceDate != null)
        'service ${DateFormat('d MMM').format(item.nextServiceDate!)}',
      if (item.purchaseCost != null) formatMoney(item.purchaseCost!),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isServiceOverdue || item.status == 'broken'
              ? AppColors.error.withValues(alpha: 0.4)
              : AppColors.outlineVariant,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: equipmentStatusColor(item.status),
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.bodyMd.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: item.isRetired
                                        ? AppColors.onSurfaceVariant
                                        : AppColors.onSurface)),
                          ),
                          if (item.isServiceOverdue) ...[
                            const SizedBox(width: 8),
                            const _Pill(
                                text: 'SERVICE DUE', color: AppColors.error),
                          ] else if (item.isServiceDueSoon) ...[
                            const SizedBox(width: 8),
                            const _Pill(
                                text: 'SERVICE SOON',
                                color: AppColors.tertiary),
                          ],
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
          ),
        ),
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

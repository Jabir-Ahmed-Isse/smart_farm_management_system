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
import '../../../models/farm.dart';
import '../../../models/inventory_item.dart';
import '../../profile/data/profile_repository.dart';
import '../data/inventory_repository.dart';

const _categories = <(String, String)>[
  ('seeds', 'Seeds'),
  ('fertilizer', 'Fertilizer'),
  ('pesticide', 'Pesticide'),
  ('herbicide', 'Herbicide'),
  ('fungicide', 'Fungicide'),
  ('fuel', 'Fuel'),
  ('equipment', 'Equipment'),
  ('spare_parts', 'Spare parts'),
  ('packaging', 'Packaging'),
  ('other', 'Other'),
];

String _categoryLabel(String key) =>
    _categories.firstWhere((c) => c.$1 == key, orElse: () => (key, key)).$2;

/// Farm inventory with low-stock / expiry alerts and full CRUD.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farm = ref.watch(activeFarmProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(ref.watch(stringsProvider).inventory)),
      floatingActionButton: farm == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _itemSheet(context, ref, farm),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Symbols.add),
              label: Text(ref.watch(stringsProvider).addItem),
            ),
      body: farm == null
          ? const Center(child: Text('Create a farm to track inventory.'))
          : _Body(farm: farm),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inventoryForFarmProvider(farm.id));
    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load inventory.\n$e',
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
                  const Icon(Symbols.inventory_2,
                      size: 56, color: AppColors.outline),
                  const SizedBox(height: 12),
                  Text('No inventory yet',
                      style: AppText.headlineSm, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Track seeds, fertilizer, fuel and more.',
                      style: AppText.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final lowStock = list.where((i) => i.isLowStock).length;
        final expiring =
            list.where((i) => i.isExpired || i.isExpiringSoon).length;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(inventoryForFarmProvider(farm.id)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (lowStock > 0 || expiring > 0) ...[
                Row(
                  children: [
                    if (lowStock > 0)
                      Expanded(
                        child: _AlertCard(
                          icon: Symbols.warning,
                          color: AppColors.error,
                          count: lowStock,
                          label: lowStock == 1 ? 'Low stock' : 'Low stock',
                        ),
                      ),
                    if (lowStock > 0 && expiring > 0) const SizedBox(width: 12),
                    if (expiring > 0)
                      Expanded(
                        child: _AlertCard(
                          icon: Symbols.schedule,
                          color: AppColors.tertiary,
                          count: expiring,
                          label: 'Expiring / expired',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              for (final item in list)
                _ItemTile(
                  item: item,
                  onEdit: () => _itemSheet(context, ref, farm, existing: item),
                  onDelete: () => _delete(context, ref, item),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, InventoryItem item) async {
    final ok = await confirmDelete(context,
        title: 'Delete item?',
        message: 'Remove "${item.name}" from inventory?');
    if (ok != true) return;
    try {
      await ref.read(inventoryRepositoryProvider).deleteItem(item.id);
      ref.invalidate(inventoryForFarmProvider(farm.id));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the item.')));
      }
    }
  }
}

/// Add / edit item bottom sheet.
Future<void> _itemSheet(
  BuildContext context,
  WidgetRef ref,
  Farm farm, {
  InventoryItem? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final unitCtrl = TextEditingController(text: existing?.unit ?? 'unit');
  final qtyCtrl =
      TextEditingController(text: existing?.quantity.toString() ?? '');
  final reorderCtrl =
      TextEditingController(text: existing?.reorderLevel.toString() ?? '');
  final costCtrl =
      TextEditingController(text: existing?.unitCost?.toString() ?? '');
  final supplierCtrl = TextEditingController(text: existing?.supplier ?? '');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  String category = existing?.category ?? 'other';
  DateTime? expiry = existing?.expiryDate;
  String? error;
  bool saving = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'Add inventory item' : 'Edit item',
                  style: AppText.headlineSm),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: existing == null,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(hintText: 'Item name (e.g. NPK 20-20)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                isExpanded: true,
                items: [
                  for (final c in _categories)
                    DropdownMenuItem(value: c.$1, child: Text(c.$2)),
                ],
                onChanged: (v) => setModalState(() => category = v ?? 'other'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
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
                      controller: unitCtrl,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: reorderCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                      ],
                      decoration:
                          const InputDecoration(labelText: 'Reorder at'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: costCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                      ],
                      decoration: const InputDecoration(
                          labelText: 'Unit cost', prefixText: '\$ '),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: supplierCtrl,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(hintText: 'Supplier (optional)'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: expiry ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setModalState(() => expiry = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Row(
                    children: [
                      const Icon(Symbols.event,
                          size: 20, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Text(
                        expiry == null
                            ? 'Expiry date (optional)'
                            : DateFormat('d MMM yyyy').format(expiry!),
                        style: AppText.bodyMd.copyWith(
                            color: expiry == null
                                ? AppColors.onSurfaceVariant
                                : AppColors.onSurface),
                      ),
                      const Spacer(),
                      if (expiry != null)
                        IconButton(
                          icon: const Icon(Symbols.close, size: 18),
                          onPressed: () => setModalState(() => expiry = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Notes (optional)'),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!,
                    style: AppText.labelMd.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          setModalState(() => error = 'Item name is required.');
                          return;
                        }
                        final nav = Navigator.of(ctx);
                        setModalState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final repo = ref.read(inventoryRepositoryProvider);
                          final qty =
                              num.tryParse(qtyCtrl.text.trim()) ?? 0;
                          final reorder =
                              num.tryParse(reorderCtrl.text.trim()) ?? 0;
                          final cost = num.tryParse(costCtrl.text.trim());
                          final unit = unitCtrl.text.trim().isEmpty
                              ? 'unit'
                              : unitCtrl.text.trim();
                          if (existing == null) {
                            await repo.createItem(
                              farmId: farm.id,
                              name: nameCtrl.text.trim(),
                              category: category,
                              unit: unit,
                              quantity: qty,
                              reorderLevel: reorder,
                              unitCost: cost,
                              supplier: supplierCtrl.text,
                              expiryDate: expiry,
                              notes: notesCtrl.text,
                            );
                          } else {
                            await repo.updateItem(
                              id: existing.id,
                              name: nameCtrl.text.trim(),
                              category: category,
                              unit: unit,
                              quantity: qty,
                              reorderLevel: reorder,
                              unitCost: cost,
                              supplier: supplierCtrl.text,
                              expiryDate: expiry,
                              notes: notesCtrl.text,
                            );
                          }
                          ref.invalidate(inventoryForFarmProvider(farm.id));
                          nav.pop();
                        } catch (_) {
                          setModalState(() {
                            saving = false;
                            error = 'Could not save the item.';
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onPrimary))
                    : Text(existing == null ? 'Add item' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$count',
                  style: AppText.headlineSm.copyWith(color: color)),
              Text(label,
                  style: AppText.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });
  final InventoryItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
                      child: Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyMd
                              .copyWith(fontWeight: FontWeight.w600)),
                    ),
                    if (item.isLowStock) ...[
                      const SizedBox(width: 8),
                      const _Pill(text: 'LOW', color: AppColors.error),
                    ],
                    if (item.isExpired) ...[
                      const SizedBox(width: 6),
                      const _Pill(text: 'EXPIRED', color: AppColors.error),
                    ] else if (item.isExpiringSoon) ...[
                      const SizedBox(width: 6),
                      const _Pill(text: 'EXPIRING', color: AppColors.tertiary),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_qty(item.quantity)} ${item.unit} · ${_categoryLabel(item.category)}'
                  '${item.reorderLevel > 0 ? ' · reorder ${_qty(item.reorderLevel)}' : ''}'
                  '${item.expiryDate != null ? ' · exp ${DateFormat('d MMM yyyy').format(item.expiryDate!)}' : ''}',
                  style: AppText.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (item.unitCost != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(formatMoney(item.unitCost! * item.quantity),
                  style:
                      AppText.labelMd.copyWith(fontWeight: FontWeight.w700)),
            ),
          PopupMenuButton<String>(
            icon:
                const Icon(Symbols.more_vert, color: AppColors.onSurfaceVariant),
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

  static String _qty(num q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
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
          style: AppText.labelSm
              .copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }
}

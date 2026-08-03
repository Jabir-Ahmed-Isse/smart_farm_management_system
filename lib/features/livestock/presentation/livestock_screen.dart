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
import '../../../models/livestock.dart';
import '../../profile/data/profile_repository.dart';
import '../data/livestock_repository.dart';
import 'livestock_detail_screen.dart';

const livestockSpecies = <(String, String, IconData)>[
  ('cattle', 'Cattle', Symbols.pets),
  ('goat', 'Goats', Symbols.pets),
  ('sheep', 'Sheep', Symbols.pets),
  ('camel', 'Camels', Symbols.pets),
  ('poultry', 'Poultry', Symbols.egg),
  ('donkey', 'Donkeys', Symbols.pets),
  ('bee', 'Bees', Symbols.hive),
  ('other', 'Other', Symbols.pets),
];

const livestockStatuses = <(String, String)>[
  ('active', 'On the farm'),
  ('sold', 'Sold'),
  ('dead', 'Died'),
  ('butchered', 'Butchered'),
];

String speciesLabel(String key) => livestockSpecies
    .firstWhere((s) => s.$1 == key, orElse: () => (key, key, Symbols.pets))
    .$2;

IconData speciesIcon(String key) => livestockSpecies
    .firstWhere((s) => s.$1 == key, orElse: () => (key, key, Symbols.pets))
    .$3;

String livestockStatusLabel(String key) =>
    livestockStatuses.firstWhere((s) => s.$1 == key, orElse: () => (key, key)).$2;

/// Livestock roster — animals and herds, with health & production history.
class LivestockScreen extends ConsumerWidget {
  const LivestockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farm = ref.watch(activeFarmProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(ref.watch(stringsProvider).livestock)),
      floatingActionButton: farm == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showLivestockSheet(context, farm),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Symbols.add),
              label: Text(ref.watch(stringsProvider).addAnimals),
            ),
      body: farm == null
          ? const Center(child: Text('Create a farm to track livestock.'))
          : _Body(farm: farm),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animals = ref.watch(livestockForFarmProvider(farm.id));

    return animals.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load livestock.\n$e',
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
                  const Icon(Symbols.pets, size: 56, color: AppColors.outline),
                  const SizedBox(height: 12),
                  Text('No livestock yet',
                      style: AppText.headlineSm, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Add an animal or a whole herd, then log health, '
                      'breeding and production against it.',
                      style: AppText.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final active = list.where((a) => a.isActive).toList();
        final head = active.fold<int>(0, (sum, a) => sum + a.count);
        // Head count per species, biggest first — the farm at a glance.
        final bySpecies = <String, int>{};
        for (final a in active) {
          bySpecies[a.species] = (bySpecies[a.species] ?? 0) + a.count;
        }
        final speciesEntries = bySpecies.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(livestockForFarmProvider(farm.id)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$head',
                        style: AppText.headlineSm
                            .copyWith(color: AppColors.primary)),
                    Text(head == 1 ? 'head on the farm' : 'head on the farm',
                        style: AppText.labelSm
                            .copyWith(color: AppColors.onSurfaceVariant)),
                    if (speciesEntries.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final e in speciesEntries)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(speciesIcon(e.key),
                                      size: 16,
                                      color: AppColors.onSurfaceVariant),
                                  const SizedBox(width: 6),
                                  Text('${e.value} ${speciesLabel(e.key)}',
                                      style: AppText.labelSm),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              for (final animal in list)
                _AnimalTile(
                  animal: animal,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          LivestockDetailScreen(farm: farm, animal: animal),
                    ),
                  ),
                  onEdit: () =>
                      showLivestockSheet(context, farm, existing: animal),
                  onDelete: () => _delete(context, ref, animal),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Livestock animal) async {
    final ok = await confirmDelete(context,
        title: 'Delete record?',
        message: 'Remove "${animal.name}"? Its health and production history '
            'goes too. To keep the history, set the status to Sold or Died '
            'instead.');
    if (ok != true) return;
    try {
      await ref.read(livestockRepositoryProvider).deleteAnimal(animal.id);
      ref.invalidate(livestockForFarmProvider(farm.id));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the record.')));
      }
    }
  }
}

/// Add / edit an animal or herd.
Future<void> showLivestockSheet(
  BuildContext context,
  Farm farm, {
  Livestock? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _LivestockSheet(farm: farm, existing: existing),
  );
}

class _LivestockSheet extends ConsumerStatefulWidget {
  const _LivestockSheet({required this.farm, this.existing});

  final Farm farm;
  final Livestock? existing;

  @override
  ConsumerState<_LivestockSheet> createState() => _LivestockSheetState();
}

class _LivestockSheetState extends ConsumerState<_LivestockSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _breedCtrl;
  late final TextEditingController _countCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _notesCtrl;
  late String _species;
  late String _status;
  String? _sex;
  DateTime? _birth;
  DateTime? _acquired;
  String? _error;
  bool _saving = false;

  Livestock? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _existing?.name ?? '');
    _breedCtrl = TextEditingController(text: _existing?.breed ?? '');
    _countCtrl =
        TextEditingController(text: (_existing?.count ?? 1).toString());
    _costCtrl = TextEditingController(
        text: _existing?.acquisitionCost?.toString() ?? '');
    _notesCtrl = TextEditingController(text: _existing?.notes ?? '');
    _species = _existing?.species ?? 'goat';
    _status = _existing?.status ?? 'active';
    _sex = _existing?.sex;
    _birth = _existing?.birthDate;
    _acquired = _existing?.acquiredDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _countCtrl.dispose();
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
            Text(_existing == null ? 'Add livestock' : 'Edit livestock',
                style: AppText.headlineSm),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: _existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  hintText: 'Name or tag (e.g. Ear-tag 042, or Goat herd)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _species,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Species'),
                    items: [
                      for (final s in livestockSpecies)
                        DropdownMenuItem(value: s.$1, child: Text(s.$2)),
                    ],
                    onChanged: (v) => setState(() => _species = v ?? 'other'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _countCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Head'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _breedCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Breed'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _sex,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sex'),
                    items: const [
                      DropdownMenuItem<String?>(
                          value: null, child: Text('—')),
                      DropdownMenuItem<String?>(
                          value: 'female', child: Text('Female')),
                      DropdownMenuItem<String?>(
                          value: 'male', child: Text('Male')),
                      DropdownMenuItem<String?>(
                          value: 'mixed', child: Text('Mixed')),
                    ],
                    onChanged: (v) => setState(() => _sex = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final s in livestockStatuses)
                  DropdownMenuItem(value: s.$1, child: Text(s.$2)),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'active'),
            ),
            const SizedBox(height: 12),
            _DateRow(
              icon: Symbols.cake,
              label: 'Born (optional)',
              value: _birth,
              onPick: (d) => setState(() => _birth = d),
            ),
            const SizedBox(height: 12),
            _DateRow(
              icon: Symbols.event,
              label: 'Acquired (optional)',
              value: _acquired,
              onPick: (d) => setState(() => _acquired = d),
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
                  : Text(_existing == null ? 'Add' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'A name or tag is required.');
      return;
    }
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(livestockRepositoryProvider);
      final count = int.tryParse(_countCtrl.text.trim()) ?? 1;
      final cost = num.tryParse(_costCtrl.text.trim());
      if (_existing == null) {
        await repo.createAnimal(
          farmId: widget.farm.id,
          name: _nameCtrl.text.trim(),
          species: _species,
          count: count,
          status: _status,
          breed: _breedCtrl.text,
          sex: _sex,
          birthDate: _birth,
          acquiredDate: _acquired,
          acquisitionCost: cost,
          notes: _notesCtrl.text,
        );
      } else {
        await repo.updateAnimal(
          id: _existing!.id,
          name: _nameCtrl.text.trim(),
          species: _species,
          count: count,
          status: _status,
          breed: _breedCtrl.text,
          sex: _sex,
          birthDate: _birth,
          acquiredDate: _acquired,
          acquisitionCost: cost,
          notes: _notesCtrl.text,
        );
      }
      ref.invalidate(livestockForFarmProvider(widget.farm.id));
      nav.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save.';
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

class _AnimalTile extends StatelessWidget {
  const _AnimalTile({
    required this.animal,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Livestock animal;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final age = animal.ageMonths;
    final meta = <String>[
      speciesLabel(animal.species),
      if (animal.isHerd) '${animal.count} head',
      if (animal.breed != null) animal.breed!,
      if (age != null) age >= 24 ? '${age ~/ 12} yrs' : '$age mo',
      if (!animal.isActive) livestockStatusLabel(animal.status),
      if (animal.acquisitionCost != null) formatMoney(animal.acquisitionCost!),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
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
                CircleAvatar(
                  radius: 20,
                  backgroundColor: animal.isActive
                      ? AppColors.primaryContainer
                      : AppColors.surfaceContainerHigh,
                  child: Icon(speciesIcon(animal.species),
                      size: 20,
                      color: animal.isActive
                          ? AppColors.onPrimaryContainer
                          : AppColors.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(animal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                              color: animal.isActive
                                  ? AppColors.onSurface
                                  : AppColors.onSurfaceVariant)),
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

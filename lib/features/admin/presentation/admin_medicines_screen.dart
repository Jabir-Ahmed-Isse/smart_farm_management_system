import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/medicine.dart';
import '../data/medicine_repository.dart';

/// Admin → Medicine Management. Searchable catalog with full CRUD and a live
/// sprayer-dose calculator in the editor.
class AdminMedicinesScreen extends ConsumerStatefulWidget {
  const AdminMedicinesScreen({super.key});

  @override
  ConsumerState<AdminMedicinesScreen> createState() => _AdminMedicinesScreenState();
}

class _AdminMedicinesScreenState extends ConsumerState<AdminMedicinesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final meds = ref.watch(medicinesProvider(_search));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Medicines'),
        backgroundColor: AppColors.background,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Symbols.add),
        label: const Text('Add medicine'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search medicines…',
                prefixIcon: const Icon(Symbols.search),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(medicinesProvider),
              child: meds.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _error(e.toString()),
                data: (list) => list.isEmpty
                    ? _empty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _tile(context, list[i]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Medicine m) {
    return Card(
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.primaryContainer,
          child: Icon(Symbols.medication, color: Colors.white),
        ),
        title: Text(m.name, style: AppText.labelMd),
        subtitle: Text(
            [m.category, if (m.activeIngredient != null) m.activeIngredient].join(' · '),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.labelSm),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _openForm(context, m);
            if (v == 'delete') _delete(context, m);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _openForm(context, m),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, [Medicine? existing]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _MedicineForm(existing: existing),
    ));
    if (saved == true) ref.invalidate(medicinesProvider);
  }

  Future<void> _delete(BuildContext context, Medicine m) async {
    final ok = await confirmDelete(context,
        title: 'Delete medicine?',
        message: 'Remove "${m.name}" from the catalog.');
    if (ok != true) return;
    try {
      await ref.read(medicineRepositoryProvider).delete(m.id);
      ref.invalidate(medicinesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Widget _empty() => ListView(children: [
        const SizedBox(height: 120),
        const Icon(Symbols.medication, size: 52, color: AppColors.outline),
        const SizedBox(height: 12),
        Center(child: Text('No medicines yet', style: AppText.labelMd)),
        const SizedBox(height: 4),
        Center(child: Text('Tap "Add medicine" to build the catalog.', style: AppText.labelSm)),
      ]);

  Widget _error(String e) {
    final denied = e.contains('42501') || e.toLowerCase().contains('authorized');
    return Center(
      child: Text(denied ? 'Admins only' : 'Could not load medicines',
          style: AppText.headlineSm),
    );
  }
}

// ============================================================ form

class _MedicineForm extends ConsumerStatefulWidget {
  const _MedicineForm({this.existing});
  final Medicine? existing;

  @override
  ConsumerState<_MedicineForm> createState() => _MedicineFormState();
}

class _MedicineFormState extends ConsumerState<_MedicineForm> {
  late final Map<String, TextEditingController> _c = {
    for (final k in _fields) k: TextEditingController()
  };
  String _category = 'other';
  bool _saving = false;

  static const _fields = [
    'name', 'active_ingredient', 'supported_diseases', 'dosage_per_liter',
    'mixing_ratio', 'repeat_interval', 'max_applications', 'pre_harvest_interval',
    'organic_alternative', 'availability', 'price_level', 'safety_notes'
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _category = e.category;
      _c['name']!.text = e.name;
      _c['active_ingredient']!.text = e.activeIngredient ?? '';
      _c['supported_diseases']!.text = e.supportedDiseases ?? '';
      _c['dosage_per_liter']!.text = e.dosagePerLiter ?? '';
      _c['mixing_ratio']!.text = e.mixingRatio ?? '';
      _c['repeat_interval']!.text = e.repeatInterval ?? '';
      _c['max_applications']!.text = e.maxApplications ?? '';
      _c['pre_harvest_interval']!.text = e.preHarvestInterval ?? '';
      _c['organic_alternative']!.text = e.organicAlternative ?? '';
      _c['availability']!.text = e.availability ?? '';
      _c['price_level']!.text = e.priceLevel ?? '';
      _c['safety_notes']!.text = e.safetyNotes ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Medicine _build() => Medicine(
        id: widget.existing?.id ?? '',
        name: _c['name']!.text,
        category: _category,
        activeIngredient: _c['active_ingredient']!.text,
        supportedDiseases: _c['supported_diseases']!.text,
        dosagePerLiter: _c['dosage_per_liter']!.text,
        mixingRatio: _c['mixing_ratio']!.text,
        repeatInterval: _c['repeat_interval']!.text,
        maxApplications: _c['max_applications']!.text,
        preHarvestInterval: _c['pre_harvest_interval']!.text,
        organicAlternative: _c['organic_alternative']!.text,
        availability: _c['availability']!.text,
        priceLevel: _c['price_level']!.text,
        safetyNotes: _c['safety_notes']!.text,
      );

  @override
  Widget build(BuildContext context) {
    final dose = _build();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add medicine' : 'Edit medicine'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _field('name', 'Name *'),
          _dropdown(),
          _field('active_ingredient', 'Active ingredient'),
          _field('supported_diseases', 'Supported diseases'),
          _field('dosage_per_liter', 'Dose per litre (e.g. 2 ml)'),
          if (dose.doseFor(15) != null) _sprayerPreview(dose),
          _field('mixing_ratio', 'Mixing ratio'),
          Row(children: [
            Expanded(child: _field('repeat_interval', 'Repeat interval')),
            const SizedBox(width: 12),
            Expanded(child: _field('max_applications', 'Max applications')),
          ]),
          _field('pre_harvest_interval', 'Pre-harvest interval'),
          _field('organic_alternative', 'Organic alternative'),
          Row(children: [
            Expanded(child: _field('availability', 'Availability')),
            const SizedBox(width: 12),
            Expanded(child: _field('price_level', 'Price level')),
          ]),
          _field('safety_notes', 'Safety notes', lines: 3),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save medicine'),
          ),
        ],
      ),
    );
  }

  Widget _field(String key, String label, {int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _c[key],
          minLines: lines,
          maxLines: lines,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  Widget _dropdown() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
          items: [
            for (final c in medicineCategories)
              DropdownMenuItem(value: c, child: Text(c[0].toUpperCase() + c.substring(1))),
          ],
          onChanged: (v) => setState(() => _category = v ?? 'other'),
        ),
      );

  Widget _sprayerPreview(Medicine m) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sprayer calculator', style: AppText.labelSm.copyWith(color: AppColors.onTertiaryFixedVariant)),
            const SizedBox(height: 8),
            Row(children: [
              for (final l in [15, 20, 25])
                Expanded(
                  child: Column(children: [
                    Text('${l}L', style: AppText.labelSm),
                    Text(m.doseFor(l) ?? '—',
                        style: AppText.labelMd.copyWith(color: AppColors.tertiary, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ],
        ),
      );

  Future<void> _save() async {
    if (_c['name']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(medicineRepositoryProvider);
    final m = _build();
    try {
      if (widget.existing == null) {
        await repo.create(m);
      } else {
        await repo.update(widget.existing!.id, m);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }
}

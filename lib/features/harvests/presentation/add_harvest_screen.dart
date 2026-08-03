import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../models/crop.dart';
import '../../../models/farm.dart';
import '../../../models/harvest.dart';
import '../../../models/plot.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../expenses/data/expense_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/harvest_repository.dart';

const _units = ['kg', 'ton', 'sack', 'crate', 'box', 'bunch', 'piece'];
const _grades = ['A', 'B', 'C', 'Mixed'];

/// Full-screen Harvest form. Pass [existing] to edit instead of create.
class AddHarvestScreen extends ConsumerStatefulWidget {
  const AddHarvestScreen({super.key, this.existing});
  final Harvest? existing;

  @override
  ConsumerState<AddHarvestScreen> createState() => _AddHarvestScreenState();
}

class _AddHarvestScreenState extends ConsumerState<AddHarvestScreen> {
  final _quantityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  Farm? _farm;
  bool _farmTouched = false;
  Crop? _crop;
  bool _cropTouched = false;
  Plot? _plot;
  bool _plotTouched = false;
  String _unit = 'kg';
  String? _grade;
  DateTime _date = DateTime.now();

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final h = widget.existing;
    if (h != null) {
      _quantityCtrl.text = h.quantity.toString();
      _notesCtrl.text = h.notes ?? '';
      _unit = _units.contains(h.unit) ? h.unit : 'kg';
      _grade = _grades.contains(h.grade) ? h.grade : null;
      _date = h.date;
    }
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  T? _match<T>(List<T> items, bool touched, T? picked, String? id,
      String Function(T) idOf) {
    if (touched || id == null) return picked;
    for (final it in items) {
      if (idOf(it) == id) return it;
    }
    return picked;
  }

  @override
  Widget build(BuildContext context) {
    final farms = ref.watch(myFarmsProvider);

    final t = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? t.editHarvest : t.addHarvest)),
      body: farms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => FormMessage(message: 'Could not load your farms.\n$e'),
        data: (list) {
          if (list.isEmpty) {
            return const FormMessage(
              icon: Symbols.agriculture,
              message: 'Create a farm first, then you can record harvests.',
            );
          }
          return _buildForm(list);
        },
      ),
    );
  }

  Widget _buildForm(List<Farm> farms) {
    final farm = _match(farms, _farmTouched, _farm, widget.existing?.farmId,
            (f) => f.id) ??
        farms.first;
    final plots = ref.watch(plotsForFarmProvider(farm.id));
    final crops = ref.watch(cropsForFarmProvider(farm.id));
    final t = ref.watch(stringsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FormErrorBanner(_error!),
          ),

        FieldLabel(t.farm, required: true),
        FormDropdown<Farm>(
          value: farm,
          items: [
            for (final f in farms)
              DropdownMenuItem(value: f, child: Text(f.name)),
          ],
          onChanged: farms.length == 1
              ? null
              : (f) => setState(() {
                    _farm = f;
                    _farmTouched = true;
                    _plot = null;
                    _plotTouched = true;
                    _crop = null;
                    _cropTouched = true;
                  }),
        ),
        const SizedBox(height: 20),

        FieldLabel(t.crop),
        crops.maybeWhen(
          data: (list) => FormDropdown<Crop>(
            value: _match(
                list, _cropTouched, _crop, widget.existing?.cropId, (c) => c.id),
            hint: list.isEmpty ? t.noCropsOptional : t.selectCrop,
            items: [
              for (final c in list)
                DropdownMenuItem(value: c, child: Text(c.displayName)),
            ],
            onChanged: list.isEmpty
                ? null
                : (c) => setState(() {
                      _crop = c;
                      _cropTouched = true;
                    }),
          ),
          orElse: () => const LinearProgressIndicator(),
        ),
        const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel(t.quantity, required: true),
                  TextField(
                    controller: _quantityCtrl,
                    autofocus: !_isEdit,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel(t.unit, required: true),
                  FormDropdown<String>(
                    value: _unit,
                    items: [
                      for (final u in _units)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (u) => setState(() => _unit = u ?? 'kg'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        FieldLabel(t.date, required: true),
        DateField(date: _date, onTap: _pickDate),
        const SizedBox(height: 20),

        FieldLabel(t.grade),
        FormDropdown<String>(
          value: _grade,
          hint: t.optional,
          items: [
            for (final g in _grades)
              DropdownMenuItem(value: g, child: Text(g)),
          ],
          onChanged: (g) => setState(() => _grade = g),
        ),
        const SizedBox(height: 20),

        plots.maybeWhen(
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel(t.plot),
                    FormDropdown<Plot>(
                      value: _match(list, _plotTouched, _plot,
                          widget.existing?.plotId, (p) => p.id),
                      hint: t.optional,
                      items: [
                        for (final p in list)
                          DropdownMenuItem(value: p, child: Text(p.name)),
                      ],
                      onChanged: (p) => setState(() {
                        _plot = p;
                        _plotTouched = true;
                      }),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
          orElse: () => const SizedBox.shrink(),
        ),

        FieldLabel(t.notes),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: t.extraDetail),
        ),
        const SizedBox(height: 28),

        FilledButton(
          onPressed: _saving ? null : () => _save(farm),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.onPrimary))
              : Text(_isEdit ? t.saveChanges : t.saveHarvest),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save(Farm farm) async {
    final qty = num.tryParse(_quantityCtrl.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a valid quantity greater than zero.');
      return;
    }
    final crop = _match(ref.read(cropsForFarmProvider(farm.id)).valueOrNull ?? const [],
        _cropTouched, _crop, widget.existing?.cropId, (c) => c.id);
    final plot = _match(ref.read(plotsForFarmProvider(farm.id)).valueOrNull ?? const [],
        _plotTouched, _plot, widget.existing?.plotId, (p) => p.id);

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = ref.read(harvestRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.updateHarvest(
          id: widget.existing!.id,
          quantity: qty,
          unit: _unit,
          date: _date,
          cropId: crop?.id,
          plotId: plot?.id,
          grade: _grade,
          notes: _notesCtrl.text,
        );
      } else {
        await repo.addHarvest(
          farmId: farm.id,
          quantity: qty,
          unit: _unit,
          date: _date,
          cropId: crop?.id,
          plotId: plot?.id,
          grade: _grade,
          notes: _notesCtrl.text,
        );
      }

      ref.invalidate(farmSummaryProvider);
      ref.invalidate(harvestsForFarmProvider(farm.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isEdit
                ? ref.read(stringsProvider).harvestUpdated
                : ref.read(stringsProvider).harvestSaved)),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the harvest. Please try again.';
      });
    }
  }
}

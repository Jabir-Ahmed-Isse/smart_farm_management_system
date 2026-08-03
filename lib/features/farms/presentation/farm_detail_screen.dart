import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/crop.dart';
import '../../../models/farm.dart';
import '../../../models/plot.dart';
import '../../crops/data/crop_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../expenses/data/expense_repository.dart';
import '../../journey/presentation/crop_journey_screen.dart';
import '../../plots/data/plot_repository.dart';
import '../../plots/presentation/plot_detail_screen.dart';
import '../../profile/data/profile_repository.dart';

const _plotTypes = <(String, String)>[
  ('open_field', 'Open field'),
  ('greenhouse', 'Greenhouse'),
];

const _cropStages = <(String, String)>[
  ('seed', 'Seed'),
  ('germination', 'Germination'),
  ('vegetative', 'Vegetative'),
  ('flowering', 'Flowering'),
  ('fruiting', 'Fruiting'),
  ('harvest', 'Harvest'),
  ('completed', 'Completed'),
];

/// Plots & crops management for a single farm, plus edit/delete of the farm.
class FarmDetailScreen extends ConsumerStatefulWidget {
  const FarmDetailScreen({super.key, required this.farm});
  final Farm farm;

  @override
  ConsumerState<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends ConsumerState<FarmDetailScreen> {
  late Farm _farm = widget.farm;

  @override
  Widget build(BuildContext context) {
    final plots = ref.watch(plotsForFarmProvider(_farm.id));
    final crops = ref.watch(cropsForFarmProvider(_farm.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_farm.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'edit' ? _editFarm() : _deleteFarm(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit farm')),
              PopupMenuItem(value: 'delete', child: Text('Delete farm')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SectionHeader(title: 'Plots', onAdd: () => _plotSheet()),
          const SizedBox(height: 12),
          plots.when(
            loading: () => const _Loading(),
            error: (e, _) => const _ErrorText('Could not load plots.'),
            data: (list) => list.isEmpty
                ? const _Empty('No plots yet. Add one to organise your farm.')
                : Column(
                    children: [
                      for (final p in list)
                        _PlotTile(
                          plot: p,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => PlotDetailScreen(plot: p)),
                          ),
                          onEdit: () => _plotSheet(existing: p),
                          onDelete: () => _deletePlot(p),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 28),
          _SectionHeader(title: 'Crops', onAdd: () => _cropSheet()),
          const SizedBox(height: 12),
          crops.when(
            loading: () => const _Loading(),
            error: (e, _) => const _ErrorText('Could not load crops.'),
            data: (list) => list.isEmpty
                ? const _Empty('No crops yet. Add what you are growing.')
                : Column(
                    children: [
                      for (final c in list)
                        _CropTile(
                          crop: c,
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      CropJourneyScreen(cropId: c.id))),
                          onEdit: () => _cropSheet(existing: c),
                          onDelete: () => _deleteCrop(c),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---- Farm edit / delete ------------------------------------------------

  Future<void> _editFarm() async {
    final nameCtrl = TextEditingController(text: _farm.name);
    final regionCtrl = TextEditingController(text: _farm.region ?? '');
    String? error;
    bool saving = false;

    await _sheet('Edit farm', (setModalState) {
      return [
        TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Farm name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: regionCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Region (optional)'),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: AppText.labelMd.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    setModalState(() => error = 'Farm name is required.');
                    return;
                  }
                  final nav = Navigator.of(context);
                  setModalState(() {
                    saving = true;
                    error = null;
                  });
                  try {
                    final updated =
                        await ref.read(profileRepositoryProvider).updateFarm(
                              id: _farm.id,
                              name: nameCtrl.text.trim(),
                              region: regionCtrl.text.trim(),
                            );
                    ref.invalidate(myFarmsProvider);
                    if (mounted) setState(() => _farm = updated);
                    nav.pop();
                  } catch (_) {
                    setModalState(() {
                      saving = false;
                      error = 'Could not update the farm.';
                    });
                  }
                },
          child: saving ? const _BtnSpinner() : const Text('Save changes'),
        ),
      ];
    });
  }

  Future<void> _deleteFarm() async {
    final ok = await confirmDelete(
      context,
      title: 'Delete farm?',
      message:
          'This permanently deletes "${_farm.name}" and ALL its plots, crops, '
          'expenses, harvests and sales. This cannot be undone.',
    );
    if (ok != true) return;
    try {
      await ref.read(profileRepositoryProvider).deleteFarm(_farm.id);
      ref.invalidate(myFarmsProvider);
      ref.invalidate(farmSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Farm deleted')));
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the farm.')));
      }
    }
  }

  // ---- Plot add / edit / delete ------------------------------------------

  Future<void> _plotSheet({Plot? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final areaCtrl =
        TextEditingController(text: existing?.area?.toString() ?? '');
    String type = existing?.type ?? 'open_field';
    String? error;
    bool saving = false;

    await _sheet(existing == null ? 'Add a plot' : 'Edit plot', (setModalState) {
      return [
        TextField(
          controller: nameCtrl,
          autofocus: existing == null,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Plot name (e.g. Field A)'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: type,
          items: [
            for (final t in _plotTypes)
              DropdownMenuItem(value: t.$1, child: Text(t.$2)),
          ],
          onChanged: (v) => setModalState(() => type = v ?? 'open_field'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: areaCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration:
              const InputDecoration(hintText: 'Area in hectares (optional)'),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: AppText.labelMd.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    setModalState(() => error = 'Plot name is required.');
                    return;
                  }
                  final nav = Navigator.of(context);
                  setModalState(() {
                    saving = true;
                    error = null;
                  });
                  try {
                    final repo = ref.read(plotRepositoryProvider);
                    final area = num.tryParse(areaCtrl.text.trim());
                    if (existing == null) {
                      await repo.createPlot(
                          farmId: _farm.id,
                          name: nameCtrl.text.trim(),
                          type: type,
                          area: area);
                    } else {
                      await repo.updatePlot(
                          id: existing.id,
                          name: nameCtrl.text.trim(),
                          type: type,
                          area: area);
                    }
                    ref.invalidate(plotsForFarmProvider(_farm.id));
                    nav.pop();
                  } catch (_) {
                    setModalState(() {
                      saving = false;
                      error = 'Could not save the plot.';
                    });
                  }
                },
          child: saving
              ? const _BtnSpinner()
              : Text(existing == null ? 'Add plot' : 'Save changes'),
        ),
      ];
    });
  }

  Future<void> _deletePlot(Plot p) async {
    final ok = await confirmDelete(context,
        title: 'Delete plot?',
        message: 'Delete "${p.name}"? Crops linked to it stay but lose the plot.');
    if (ok != true) return;
    try {
      await ref.read(plotRepositoryProvider).deletePlot(p.id);
      ref.invalidate(plotsForFarmProvider(_farm.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the plot.')));
      }
    }
  }

  // ---- Crop add / edit / delete ------------------------------------------

  Future<void> _cropSheet({Crop? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final varietyCtrl = TextEditingController(text: existing?.variety ?? '');
    String stage = existing?.stage ?? 'seed';
    final plotList = ref.read(plotsForFarmProvider(_farm.id)).valueOrNull ?? [];
    Plot? plot = existing?.plotId == null
        ? null
        : plotList.where((p) => p.id == existing!.plotId).firstOrNull;
    String? error;
    bool saving = false;

    await _sheet(existing == null ? 'Add a crop' : 'Edit crop', (setModalState) {
      return [
        TextField(
          controller: nameCtrl,
          autofocus: existing == null,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Crop (e.g. Tomato)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: varietyCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Variety (optional)'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: stage,
          items: [
            for (final s in _cropStages)
              DropdownMenuItem(value: s.$1, child: Text(s.$2)),
          ],
          onChanged: (v) => setModalState(() => stage = v ?? 'seed'),
        ),
        if (plotList.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<Plot?>(
            initialValue: plot,
            isExpanded: true,
            hint: const Text('Plot (optional)'),
            items: [
              const DropdownMenuItem<Plot?>(value: null, child: Text('No plot')),
              for (final p in plotList)
                DropdownMenuItem(value: p, child: Text(p.name)),
            ],
            onChanged: (p) => setModalState(() => plot = p),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: AppText.labelMd.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    setModalState(() => error = 'Crop name is required.');
                    return;
                  }
                  final nav = Navigator.of(context);
                  setModalState(() {
                    saving = true;
                    error = null;
                  });
                  try {
                    final repo = ref.read(cropRepositoryProvider);
                    if (existing == null) {
                      await repo.createCrop(
                          farmId: _farm.id,
                          name: nameCtrl.text.trim(),
                          variety: varietyCtrl.text.trim(),
                          plotId: plot?.id,
                          stage: stage);
                    } else {
                      await repo.updateCrop(
                          id: existing.id,
                          name: nameCtrl.text.trim(),
                          variety: varietyCtrl.text.trim(),
                          plotId: plot?.id,
                          stage: stage);
                    }
                    ref.invalidate(cropsForFarmProvider(_farm.id));
                    ref.invalidate(farmSummaryProvider);
                    nav.pop();
                  } catch (_) {
                    setModalState(() {
                      saving = false;
                      error = 'Could not save the crop.';
                    });
                  }
                },
          child: saving
              ? const _BtnSpinner()
              : Text(existing == null ? 'Add crop' : 'Save changes'),
        ),
      ];
    });
  }

  Future<void> _deleteCrop(Crop c) async {
    final ok = await confirmDelete(context,
        title: 'Delete crop?', message: 'Delete "${c.displayName}"?');
    if (ok != true) return;
    try {
      await ref.read(cropRepositoryProvider).deleteCrop(c.id);
      ref.invalidate(cropsForFarmProvider(_farm.id));
      ref.invalidate(farmSummaryProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the crop.')));
      }
    }
  }

  Future<void> _sheet(
    String title,
    List<Widget> Function(StateSetter setModalState) body,
  ) {
    return showModalBottomSheet<void>(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppText.headlineSm),
              const SizedBox(height: 16),
              ...body(setModalState),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});
  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppText.headlineSm),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Symbols.add, size: 20),
          label: const Text('Add'),
        ),
      ],
    );
  }
}

class _PlotTile extends StatelessWidget {
  const _PlotTile({
    required this.plot,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });
  final Plot plot;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final typeLabel = plot.type == 'greenhouse' ? 'Greenhouse' : 'Open field';
    final subtitle =
        plot.area != null ? '$typeLabel · ${plot.area} ${plot.areaUnit}' : typeLabel;
    return _Tile(
      icon: plot.type == 'greenhouse' ? Symbols.yard : Symbols.crop_square,
      title: plot.name,
      subtitle: subtitle,
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _CropTile extends StatelessWidget {
  const _CropTile(
      {required this.crop,
      required this.onEdit,
      required this.onDelete,
      this.onTap});
  final Crop crop;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      icon: Symbols.eco,
      title: crop.displayName,
      badge: crop.stage.toUpperCase(),
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onEdit,
    required this.onDelete,
    this.onTap,
    this.subtitle,
    this.badge,
  });
  final IconData icon;
  final String title;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final String? subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.onPrimaryContainer),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: AppText.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(badge!,
                  style: AppText.labelSm.copyWith(
                      color: AppColors.onPrimaryFixed,
                      fontWeight: FontWeight.w700)),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Symbols.more_vert, color: AppColors.onSurfaceVariant),
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
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Text(message,
          textAlign: TextAlign.center,
          style: AppText.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;
  @override
  Widget build(BuildContext context) =>
      Text(message, style: AppText.labelMd.copyWith(color: AppColors.error));
}

class _BtnSpinner extends StatelessWidget {
  const _BtnSpinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.onPrimary),
      );
}

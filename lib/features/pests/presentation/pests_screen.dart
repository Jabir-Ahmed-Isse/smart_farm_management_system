import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/crop.dart';
import '../../../models/disease_log.dart';
import '../../../models/farm.dart';
import '../../../models/plot.dart';
import '../../expenses/data/expense_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/pest_repository.dart';

const _kinds = <(String, String)>[
  ('pest', 'Pest'),
  ('disease', 'Disease'),
];

const _severities = <(String, String)>[
  ('low', 'Low'),
  ('medium', 'Medium'),
  ('high', 'High'),
];

const _statuses = <(String, String)>[
  ('active', 'Active'),
  ('treated', 'Treated'),
  ('resolved', 'Resolved'),
];

String _label(List<(String, String)> from, String key) =>
    from.firstWhere((e) => e.$1 == key, orElse: () => (key, key)).$2;

Color _severityColor(String key) => switch (key) {
      'high' => AppColors.error,
      'medium' => AppColors.tertiary,
      _ => AppColors.outline,
    };

/// Farm-wide pest & disease log. The same records show on a plot's own screen.
class PestsScreen extends ConsumerWidget {
  const PestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(myFarmsProvider);
    final farm =
        farms.valueOrNull?.isNotEmpty == true ? farms.value!.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(ref.watch(stringsProvider).pestsTitle)),
      floatingActionButton: farm == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showPestSheet(context, farm),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Symbols.pest_control),
              label: Text(ref.watch(stringsProvider).report),
            ),
      body: farm == null
          ? const Center(child: Text('Create a farm to log pests.'))
          : _Body(farm: farm),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(pestLogsForFarmProvider(farm.id));

    return logs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load the pest log.\n$e',
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
                  const Icon(Symbols.pest_control,
                      size: 56, color: AppColors.outline),
                  const SizedBox(height: 12),
                  Text('Nothing reported',
                      style: AppText.headlineSm, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Log pests and diseases as you spot them so you can '
                      'see what keeps coming back.',
                      style: AppText.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final active = list.where((l) => l.isActive).toList();
        final high = active.where((l) => l.severity == 'high').length;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(pestLogsForFarmProvider(farm.id)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (active.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: _AlertCard(
                        icon: Symbols.pest_control,
                        color: AppColors.tertiary,
                        count: active.length,
                        label: 'Active problems',
                      ),
                    ),
                    if (high > 0) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AlertCard(
                          icon: Symbols.priority_high,
                          color: AppColors.error,
                          count: high,
                          label: 'High severity',
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
              ],
              for (final log in list)
                _LogTile(
                  log: log,
                  onEdit: () => showPestSheet(context, farm, existing: log),
                  onDelete: () => _delete(context, ref, log),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, DiseaseLog log) async {
    final ok = await confirmDelete(context,
        title: 'Delete report?', message: 'Remove "${log.name}"?');
    if (ok != true) return;
    try {
      await ref.read(pestRepositoryProvider).deleteLog(log.id);
      ref.invalidate(pestLogsForFarmProvider(farm.id));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the report.')));
      }
    }
  }
}

/// Report / edit a pest or disease.
Future<void> showPestSheet(
  BuildContext context,
  Farm farm, {
  DiseaseLog? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PestSheet(farm: farm, existing: existing),
  );
}

class _PestSheet extends ConsumerStatefulWidget {
  const _PestSheet({required this.farm, this.existing});

  final Farm farm;
  final DiseaseLog? existing;

  @override
  ConsumerState<_PestSheet> createState() => _PestSheetState();
}

class _PestSheetState extends ConsumerState<_PestSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _treatmentCtrl;
  late final TextEditingController _notesCtrl;
  late String _kind;
  late String _severity;
  late String _status;
  late DateTime _observed;
  String? _plotId;
  String? _cropId;
  String? _error;
  bool _saving = false;

  DiseaseLog? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _existing?.name ?? '');
    _treatmentCtrl = TextEditingController(text: _existing?.treatment ?? '');
    _notesCtrl = TextEditingController(text: _existing?.notes ?? '');
    _kind = _existing?.kind ?? 'pest';
    _severity = _existing?.severity ?? 'medium';
    _status = _existing?.status ?? 'active';
    _observed = _existing?.observedDate ?? DateTime.now();
    _plotId = _existing?.plotId;
    _cropId = _existing?.cropId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _treatmentCtrl.dispose();
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
            Text(_existing == null ? 'Report a problem' : 'Edit report',
                style: AppText.headlineSm),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: _existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  hintText: 'What is it? (e.g. Fall armyworm)'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _kind,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      for (final k in _kinds)
                        DropdownMenuItem(value: k.$1, child: Text(k.$2)),
                    ],
                    onChanged: (v) => setState(() => _kind = v ?? 'pest'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _severity,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Severity'),
                    items: [
                      for (final s in _severities)
                        DropdownMenuItem(value: s.$1, child: Text(s.$2)),
                    ],
                    onChanged: (v) => setState(() => _severity = v ?? 'medium'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Status', style: AppText.labelMd),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
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
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _observed,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _observed = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Row(
                  children: [
                    const Icon(Symbols.event,
                        size: 20, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text('Seen ${DateFormat('d MMM yyyy').format(_observed)}',
                        style: AppText.bodyMd),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: plots.any((p) => p.id == _plotId) ? _plotId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Plot (optional)'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Whole farm')),
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
              controller: _treatmentCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(hintText: 'Treatment applied'),
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
                  : Text(_existing == null ? 'Save report' : 'Save changes'),
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
      final repo = ref.read(pestRepositoryProvider);
      if (_existing == null) {
        await repo.addLog(
          farmId: widget.farm.id,
          name: _nameCtrl.text.trim(),
          kind: _kind,
          severity: _severity,
          status: _status,
          observedDate: _observed,
          plotId: _plotId,
          cropId: _cropId,
          treatment: _treatmentCtrl.text,
          notes: _notesCtrl.text,
        );
      } else {
        await repo.updateLog(
          id: _existing!.id,
          name: _nameCtrl.text.trim(),
          kind: _kind,
          severity: _severity,
          status: _status,
          observedDate: _observed,
          plotId: _plotId,
          cropId: _cropId,
          treatment: _treatmentCtrl.text,
          notes: _notesCtrl.text,
        );
      }
      ref.invalidate(pestLogsForFarmProvider(widget.farm.id));
      nav.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the report.';
        });
      }
    }
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

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.log,
    required this.onEdit,
    required this.onDelete,
  });

  final DiseaseLog log;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      _label(_kinds, log.kind),
      log.plotName ?? 'whole farm',
      if (log.cropName != null) log.cropName!,
      DateFormat('d MMM').format(log.observedDate),
      if (log.treatment != null) log.treatment!,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: log.isActive && log.severity == 'high'
              ? AppColors.error.withValues(alpha: 0.4)
              : AppColors.outlineVariant,
        ),
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
                      child: Text(log.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                              color: log.isActive
                                  ? AppColors.onSurface
                                  : AppColors.onSurfaceVariant)),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                        text: _label(_severities, log.severity).toUpperCase(),
                        color: _severityColor(log.severity)),
                    if (!log.isActive) ...[
                      const SizedBox(width: 6),
                      _Pill(
                          text: _label(_statuses, log.status).toUpperCase(),
                          color: AppColors.outline),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/crop.dart';
import '../../../models/farm.dart';
import '../../../models/plot.dart';
import '../../../models/task.dart';
import '../../../models/worker.dart';
import '../../expenses/data/expense_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../workers/data/worker_repository.dart';
import '../../workers/presentation/worker_form_sheet.dart';
import '../data/task_repository.dart';

const _statuses = <(String, String)>[
  ('pending', 'To do'),
  ('in_progress', 'In progress'),
  ('completed', 'Completed'),
  ('cancelled', 'Cancelled'),
];

const _priorities = <(String, String)>[
  ('low', 'Low'),
  ('medium', 'Medium'),
  ('high', 'High'),
];

String _statusLabel(String key) =>
    _statuses.firstWhere((s) => s.$1 == key, orElse: () => (key, key)).$2;

String _priorityLabel(String key) =>
    _priorities.firstWhere((p) => p.$1 == key, orElse: () => (key, key)).$2;

Color _priorityColor(String key) => switch (key) {
      'high' => AppColors.error,
      'medium' => AppColors.tertiary,
      _ => AppColors.outline,
    };

enum _Filter { open, done, all }

/// Farm tasks — assign to a worker, schedule a due date, tick off when done.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farm = ref.watch(activeFarmProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(ref.watch(stringsProvider).tasks)),
      floatingActionButton: farm == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => taskSheet(context, ref, farm),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Symbols.add),
              label: Text(ref.watch(stringsProvider).newTask),
            ),
      body: farm == null
          ? const Center(child: Text('Create a farm to plan tasks.'))
          : _Body(farm: farm),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.farm});
  final Farm farm;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  _Filter _filter = _Filter.open;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksForFarmProvider(widget.farm.id));

    return tasks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load tasks.\n$e',
              textAlign: TextAlign.center,
              style:
                  AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
        ),
      ),
      data: (all) {
        if (all.isEmpty) return const _EmptyState();

        final overdue = all.where((t) => t.isOverdue).length;
        final dueToday = all.where((t) => t.isDueToday).length;
        final list = switch (_filter) {
          _Filter.open => all.where((t) => t.isOpen).toList(),
          _Filter.done => all.where((t) => !t.isOpen).toList(),
          _Filter.all => all,
        };

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(tasksForFarmProvider(widget.farm.id)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (overdue > 0 || dueToday > 0) ...[
                Row(
                  children: [
                    if (overdue > 0)
                      Expanded(
                        child: _AlertCard(
                          icon: Symbols.event_busy,
                          color: AppColors.error,
                          count: overdue,
                          label: 'Overdue',
                        ),
                      ),
                    if (overdue > 0 && dueToday > 0) const SizedBox(width: 12),
                    if (dueToday > 0)
                      Expanded(
                        child: _AlertCard(
                          icon: Symbols.today,
                          color: AppColors.tertiary,
                          count: dueToday,
                          label: 'Due today',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  for (final f in _Filter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(switch (f) {
                          _Filter.open =>
                            'To do (${all.where((t) => t.isOpen).length})',
                          _Filter.done => 'Done',
                          _Filter.all => 'All',
                        }),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    _filter == _Filter.open
                        ? 'Nothing left to do — nice work.'
                        : 'No tasks here yet.',
                    textAlign: TextAlign.center,
                    style: AppText.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ),
              for (final task in list)
                _TaskTile(
                  task: task,
                  onToggle: () => _toggle(task),
                  onEdit: () =>
                      taskSheet(context, ref, widget.farm, existing: task),
                  onDelete: () => _delete(task),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggle(FarmTask task) async {
    try {
      await ref.read(taskRepositoryProvider).setDone(task.id, task.isOpen);
      ref.invalidate(tasksForFarmProvider(widget.farm.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update the task.')));
      }
    }
  }

  Future<void> _delete(FarmTask task) async {
    final ok = await confirmDelete(context,
        title: 'Delete task?', message: 'Remove "${task.title}"?');
    if (ok != true) return;
    try {
      await ref.read(taskRepositoryProvider).deleteTask(task.id);
      ref.invalidate(tasksForFarmProvider(widget.farm.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the task.')));
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.task_alt, size: 56, color: AppColors.outline),
            const SizedBox(height: 12),
            Text('No tasks yet',
                style: AppText.headlineSm, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Plan the work: assign it, schedule it, tick it off.',
                style:
                    AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Add / edit task bottom sheet.
Future<void> taskSheet(
  BuildContext context,
  WidgetRef ref,
  Farm farm, {
  FarmTask? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    // A Consumer widget (not a StatefulBuilder) so the worker / plot / crop
    // lists can be watched from a real build scope and refresh in place.
    builder: (ctx) => _TaskSheet(farm: farm, existing: existing),
  );
}

/// Sentinel value for the "+ Add worker…" entry in the assignee dropdown.
const _addWorkerValue = '__add_worker__';

class _TaskSheet extends ConsumerStatefulWidget {
  const _TaskSheet({required this.farm, this.existing});

  final Farm farm;
  final FarmTask? existing;

  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _status;
  late String _priority;
  DateTime? _due;
  String? _workerId;
  String? _plotId;
  String? _cropId;
  String? _error;
  bool _saving = false;

  FarmTask? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: _existing?.title ?? '');
    _descCtrl = TextEditingController(text: _existing?.description ?? '');
    _status = _existing?.status ?? 'pending';
    _priority = _existing?.priority ?? 'medium';
    _due = _existing?.dueDate;
    _workerId = _existing?.workerId;
    _plotId = _existing?.plotId;
    _cropId = _existing?.cropId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farmId = widget.farm.id;
    final workers =
        ref.watch(workersForFarmProvider(farmId)).valueOrNull ?? const <Worker>[];
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
            Text(_existing == null ? 'New task' : 'Edit task',
                style: AppText.headlineSm),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              autofocus: _existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  hintText: 'What needs doing? (e.g. Irrigate Plot A)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      for (final s in _statuses)
                        DropdownMenuItem(value: s.$1, child: Text(s.$2)),
                    ],
                    onChanged: (v) =>
                        setState(() => _status = v ?? 'pending'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _priority,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: [
                      for (final p in _priorities)
                        DropdownMenuItem(value: p.$1, child: Text(p.$2)),
                    ],
                    onChanged: (v) =>
                        setState(() => _priority = v ?? 'medium'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _due ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _due = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Row(
                  children: [
                    const Icon(Symbols.event,
                        size: 20, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      _due == null
                          ? 'Due date (optional)'
                          : DateFormat('d MMM yyyy').format(_due!),
                      style: AppText.bodyMd.copyWith(
                          color: _due == null
                              ? AppColors.onSurfaceVariant
                              : AppColors.onSurface),
                    ),
                    const Spacer(),
                    if (_due != null)
                      IconButton(
                        icon: const Icon(Symbols.close, size: 18),
                        onPressed: () => setState(() => _due = null),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue:
                  workers.any((w) => w.id == _workerId) ? _workerId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Assign to'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Unassigned')),
                for (final w in workers)
                  DropdownMenuItem<String?>(
                      value: w.id, child: Text(w.displayName)),
                const DropdownMenuItem<String?>(
                    value: _addWorkerValue, child: Text('+ Add worker…')),
              ],
              onChanged: (v) async {
                if (v == _addWorkerValue) {
                  final created = await _addWorker();
                  if (created != null && mounted) {
                    setState(() => _workerId = created.id);
                  }
                } else {
                  setState(() => _workerId = v);
                }
              },
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
              controller: _descCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(hintText: 'Details (optional)'),
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
                  : Text(_existing == null ? 'Add task' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'A task title is required.');
      return;
    }
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(taskRepositoryProvider);
      if (_existing == null) {
        await repo.createTask(
          farmId: widget.farm.id,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text,
          status: _status,
          priority: _priority,
          dueDate: _due,
          plotId: _plotId,
          cropId: _cropId,
          workerId: _workerId,
        );
      } else {
        await repo.updateTask(
          id: _existing!.id,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text,
          status: _status,
          priority: _priority,
          dueDate: _due,
          plotId: _plotId,
          cropId: _cropId,
          workerId: _workerId,
          completedAt: _existing!.completedAt,
        );
      }
      ref.invalidate(tasksForFarmProvider(widget.farm.id));
      nav.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the task.';
        });
      }
    }
  }

  /// Add a worker without leaving the task form — the same sheet the Workers
  /// module uses. Returns the created worker so it can be selected.
  Future<Worker?> _addWorker() => showWorkerSheet(context, widget.farm);
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
              Text('$count', style: AppText.headlineSm.copyWith(color: color)),
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

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final FarmTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (task.workerName != null) task.workerName!,
      if (task.plotName != null) task.plotName!,
      if (task.cropName != null) task.cropName!,
      if (task.dueDate != null)
        'due ${DateFormat('d MMM').format(task.dueDate!)}',
      if (task.status == 'in_progress' || task.status == 'cancelled')
        _statusLabel(task.status),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.isOverdue
              ? AppColors.error.withValues(alpha: 0.4)
              : AppColors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.isDone,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.primary,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: task.isOpen
                              ? null
                              : TextDecoration.lineThrough,
                          color: task.isOpen
                              ? AppColors.onSurface
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (task.priority != 'low' && task.isOpen) ...[
                      const SizedBox(width: 8),
                      _Pill(
                          text: _priorityLabel(task.priority).toUpperCase(),
                          color: _priorityColor(task.priority)),
                    ],
                    if (task.isOverdue) ...[
                      const SizedBox(width: 6),
                      const _Pill(text: 'OVERDUE', color: AppColors.error),
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

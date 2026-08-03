import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/disease_log.dart';
import '../../../models/plot.dart';
import '../data/plot_detail_repository.dart';

const _kinds = <(String, String)>[('disease', 'Disease'), ('pest', 'Pest')];
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

/// Everything about one plot: money in/out, harvests, sales, disease log, notes.
class PlotDetailScreen extends ConsumerWidget {
  const PlotDetailScreen({super.key, required this.plot});
  final Plot plot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(plotSummaryProvider(plot.id));
    final diseases = ref.watch(plotDiseaseLogsProvider(plot.id));
    final comments = ref.watch(plotCommentsProvider(plot.id));

    final typeLabel = plot.type == 'greenhouse' ? 'Greenhouse' : 'Open field';
    final sub = plot.area != null
        ? '$typeLabel · ${plot.area} ${plot.areaUnit}'
        : typeLabel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(plot.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 10),
              child: Text(sub,
                  style: AppText.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(plotSummaryProvider(plot.id));
          ref.invalidate(plotDiseaseLogsProvider(plot.id));
          ref.invalidate(plotCommentsProvider(plot.id));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            summary.when(
              loading: () => const _CardLoading(height: 190),
              error: (e, _) => const _CardError('Could not load plot totals.'),
              data: (s) => _SummarySection(summary: s),
            ),
            const SizedBox(height: 28),

            // Diseases
            _SectionHeader(
              title: 'Pests & diseases',
              onAdd: () => _diseaseSheet(context, ref),
            ),
            const SizedBox(height: 12),
            diseases.when(
              loading: () => const _CardLoading(height: 60),
              error: (e, _) => const _CardError('Could not load the log.'),
              data: (list) => list.isEmpty
                  ? const _Empty('No pests or diseases logged for this plot.')
                  : Column(
                      children: [
                        for (final d in list)
                          _DiseaseTile(
                            log: d,
                            onEdit: () =>
                                _diseaseSheet(context, ref, existing: d),
                            onDelete: () => _deleteDisease(context, ref, d),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 28),

            // Comments
            _SectionHeader(
              title: 'Comments',
              onAdd: () => _commentSheet(context, ref),
            ),
            const SizedBox(height: 12),
            comments.when(
              loading: () => const _CardLoading(height: 60),
              error: (e, _) => const _CardError('Could not load comments.'),
              data: (list) => list.isEmpty
                  ? const _Empty('No comments yet. Add a note about this plot.')
                  : Column(
                      children: [
                        for (final c in list)
                          _CommentTile(
                            body: c.body,
                            date: c.createdAt,
                            onDelete: () async {
                              final ok = await confirmDelete(context,
                                  title: 'Delete comment?',
                                  message: 'Remove this comment?');
                              if (ok != true) return;
                              await ref
                                  .read(plotDetailRepositoryProvider)
                                  .deleteComment(c.id);
                              ref.invalidate(plotCommentsProvider(plot.id));
                            },
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDisease(
      BuildContext context, WidgetRef ref, DiseaseLog d) async {
    final ok = await confirmDelete(context,
        title: 'Delete entry?', message: 'Remove "${d.name}" from the log?');
    if (ok != true) return;
    await ref.read(plotDetailRepositoryProvider).deleteDiseaseLog(d.id);
    ref.invalidate(plotDiseaseLogsProvider(plot.id));
  }

  Future<void> _commentSheet(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    bool saving = false;
    String? error;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add comment', style: AppText.headlineSm),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    hintText: 'What did you observe on this plot?'),
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
                        if (ctrl.text.trim().isEmpty) {
                          setModalState(() => error = 'Write something first.');
                          return;
                        }
                        final nav = Navigator.of(ctx);
                        setModalState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await ref
                              .read(plotDetailRepositoryProvider)
                              .addComment(
                                  farmId: plot.farmId,
                                  plotId: plot.id,
                                  body: ctrl.text);
                          ref.invalidate(plotCommentsProvider(plot.id));
                          nav.pop();
                        } catch (_) {
                          setModalState(() {
                            saving = false;
                            error = 'Could not add the comment.';
                          });
                        }
                      },
                child: saving ? const _BtnSpinner() : const Text('Add comment'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _diseaseSheet(BuildContext context, WidgetRef ref,
      {DiseaseLog? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final treatmentCtrl =
        TextEditingController(text: existing?.treatment ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String kind = existing?.kind ?? 'disease';
    String severity = existing?.severity ?? 'medium';
    String status = existing?.status ?? 'active';
    DateTime date = existing?.observedDate ?? DateTime.now();
    bool saving = false;
    String? error;

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
                Text(existing == null ? 'Log a pest / disease' : 'Edit entry',
                    style: AppText.headlineSm),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  autofocus: existing == null,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      hintText: 'Name (e.g. Leaf blight, Aphids)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: kind,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: [
                          for (final k in _kinds)
                            DropdownMenuItem(value: k.$1, child: Text(k.$2)),
                        ],
                        onChanged: (v) =>
                            setModalState(() => kind = v ?? 'disease'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: severity,
                        decoration:
                            const InputDecoration(labelText: 'Severity'),
                        items: [
                          for (final s in _severities)
                            DropdownMenuItem(value: s.$1, child: Text(s.$2)),
                        ],
                        onChanged: (v) =>
                            setModalState(() => severity = v ?? 'medium'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final s in _statuses)
                      DropdownMenuItem(value: s.$1, child: Text(s.$2)),
                  ],
                  onChanged: (v) => setModalState(() => status = v ?? 'active'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setModalState(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Observed'),
                    child: Text(DateFormat('d MMM yyyy').format(date),
                        style: AppText.bodyMd),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: treatmentCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      hintText: 'Treatment applied (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                      const InputDecoration(hintText: 'Notes (optional)'),
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
                            setModalState(() => error = 'Name is required.');
                            return;
                          }
                          final nav = Navigator.of(ctx);
                          setModalState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            final repo =
                                ref.read(plotDetailRepositoryProvider);
                            if (existing == null) {
                              await repo.addDiseaseLog(
                                farmId: plot.farmId,
                                plotId: plot.id,
                                name: nameCtrl.text.trim(),
                                kind: kind,
                                severity: severity,
                                status: status,
                                observedDate: date,
                                treatment: treatmentCtrl.text,
                                notes: notesCtrl.text,
                              );
                            } else {
                              await repo.updateDiseaseLog(
                                id: existing.id,
                                name: nameCtrl.text.trim(),
                                kind: kind,
                                severity: severity,
                                status: status,
                                observedDate: date,
                                treatment: treatmentCtrl.text,
                                notes: notesCtrl.text,
                              );
                            }
                            ref.invalidate(plotDiseaseLogsProvider(plot.id));
                            nav.pop();
                          } catch (_) {
                            setModalState(() {
                              saving = false;
                              error = 'Could not save the entry.';
                            });
                          }
                        },
                  child: saving
                      ? const _BtnSpinner()
                      : Text(existing == null ? 'Save entry' : 'Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary});
  final PlotSummary summary;

  @override
  Widget build(BuildContext context) {
    final profit = summary.profit;
    final isLoss = profit < 0;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isLoss ? 'NET LOSS' : 'NET PROFIT',
                  style: AppText.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant, letterSpacing: .5)),
              const SizedBox(height: 4),
              Text(
                '${isLoss ? '-' : ''}${formatMoney(profit.abs())}',
                style: AppText.headlineLgMobile.copyWith(
                    color: isLoss ? AppColors.error : AppColors.primary),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(),
              ),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Sales',
                      value: formatMoney(summary.salesTotal),
                      sub: '${summary.salesCount} sale${summary.salesCount == 1 ? '' : 's'}',
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'Expenses',
                      value: formatMoney(summary.expenseTotal),
                      sub:
                          '${summary.expenseCount} item${summary.expenseCount == 1 ? '' : 's'}',
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            children: [
              const Icon(Symbols.agriculture, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summary.harvestCount == 0
                      ? 'No harvests recorded on this plot'
                      : '${summary.harvestCount} harvest${summary.harvestCount == 1 ? '' : 's'} · '
                          '${_qty(summary.harvestQty)} ${summary.harvestUnit} total',
                  style: AppText.bodyMd,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _qty(num q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });
  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: AppText.headlineSm.copyWith(color: color)),
        Text(sub,
            style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}

class _DiseaseTile extends StatelessWidget {
  const _DiseaseTile(
      {required this.log, required this.onEdit, required this.onDelete});
  final DiseaseLog log;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color get _sevColor => switch (log.severity) {
        'high' => AppColors.error,
        'low' => AppColors.onSurfaceVariant,
        _ => AppColors.tertiary,
      };

  @override
  Widget build(BuildContext context) {
    final statusLabel =
        _statuses.firstWhere((s) => s.$1 == log.status, orElse: () => (log.status, log.status)).$2;
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: _sevColor.withValues(alpha: 0.14),
                shape: BoxShape.circle),
            child: Icon(log.kind == 'pest' ? Symbols.pest_control : Symbols.coronavirus,
                size: 20, color: _sevColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '${log.severity[0].toUpperCase()}${log.severity.substring(1)} · $statusLabel · ${DateFormat('d MMM').format(log.observedDate)}',
                  style: AppText.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
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
}

class _CommentTile extends StatelessWidget {
  const _CommentTile(
      {required this.body, required this.date, required this.onDelete});
  final String body;
  final DateTime date;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(body, style: AppText.bodyMd),
                const SizedBox(height: 4),
                Text(DateFormat('d MMM yyyy · HH:mm').format(date),
                    style: AppText.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.delete, size: 20),
            color: AppColors.onSurfaceVariant,
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ],
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

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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

class _CardLoading extends StatelessWidget {
  const _CardLoading({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: height, child: const Center(child: CircularProgressIndicator()));
}

class _CardError extends StatelessWidget {
  const _CardError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => _Empty(message);
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

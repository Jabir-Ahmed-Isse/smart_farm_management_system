import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/farm.dart';
import '../../../models/worker.dart';
import '../../profile/data/profile_repository.dart';
import '../data/worker_repository.dart';
import 'worker_detail_screen.dart';
import 'worker_form_sheet.dart';

/// The farm's worker roster. Tap a worker for attendance and pay.
class WorkersScreen extends ConsumerWidget {
  const WorkersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farm = ref.watch(activeFarmProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(ref.watch(stringsProvider).workers)),
      floatingActionButton: farm == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showWorkerSheet(context, farm),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Symbols.person_add),
              label: Text(ref.watch(stringsProvider).addWorker),
            ),
      body: farm == null
          ? const Center(child: Text('Create a farm to build a roster.'))
          : _Body(farm: farm),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(workersForFarmProvider(farm.id));

    return workers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load workers.\n$e',
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
                  const Icon(Symbols.groups, size: 56, color: AppColors.outline),
                  const SizedBox(height: 12),
                  Text('No workers yet',
                      style: AppText.headlineSm, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Add your team to assign tasks, track attendance '
                      'and record pay.',
                      style: AppText.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final active = list.where((w) => w.active).length;
        final payroll = list
            .where((w) => w.active)
            .fold<num>(0, (sum, w) => sum + (w.dailyWage ?? 0));

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(workersForFarmProvider(farm.id)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Symbols.groups,
                      color: AppColors.primary,
                      value: '$active',
                      label: active == 1 ? 'Active worker' : 'Active workers',
                    ),
                  ),
                  if (payroll > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Symbols.payments,
                        color: AppColors.tertiary,
                        value: formatMoneyCompact(payroll),
                        label: 'Wages per full day',
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              for (final worker in list)
                _WorkerTile(
                  worker: worker,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          WorkerDetailScreen(farm: farm, worker: worker),
                    ),
                  ),
                  onEdit: () =>
                      showWorkerSheet(context, farm, existing: worker),
                  onDelete: () => _delete(context, ref, worker),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Worker worker) async {
    final ok = await confirmDelete(context,
        title: 'Delete worker?',
        message: 'Remove ${worker.fullName}? Their attendance and pay records '
            'go too. To keep the history, switch them to not working instead.');
    if (ok != true) return;
    try {
      await ref.read(workerRepositoryProvider).deleteWorker(worker.id);
      ref.invalidate(workersForFarmProvider(farm.id));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the worker.')));
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
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
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _WorkerTile extends StatelessWidget {
  const _WorkerTile({
    required this.worker,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Worker worker;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (worker.position != null) worker.position!,
      if (worker.phone != null) worker.phone!,
      if (worker.dailyWage != null) '${formatMoney(worker.dailyWage!)}/day',
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
                  backgroundColor: worker.active
                      ? AppColors.primaryContainer
                      : AppColors.surfaceContainerHigh,
                  child: Text(
                    _initials(worker.fullName),
                    style: AppText.labelMd.copyWith(
                      color: worker.active
                          ? AppColors.onPrimaryContainer
                          : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(worker.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.bodyMd
                                    .copyWith(fontWeight: FontWeight.w600)),
                          ),
                          if (!worker.active) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.outline.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('NOT WORKING',
                                  style: AppText.labelSm.copyWith(
                                      color: AppColors.outline,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10)),
                            ),
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
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

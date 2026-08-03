import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../profile/data/profile_repository.dart';
import 'presentation/farm_detail_screen.dart';

/// Turns backend/auth exceptions into a short message the farmer can act on.
String _friendlyError(Object e) {
  if (e is StateError) return e.message;
  if (e is AuthException) {
    return 'Your session has expired. Please sign in again.';
  }
  if (e is PostgrestException) {
    // 42501 = RLS violation → almost always a stale/invalid session.
    if (e.code == '42501' || e.message.contains('row-level security')) {
      return 'Permission denied — your session may have expired. '
          'Please sign out and sign in again.';
    }
    return 'Could not save: ${e.message}';
  }
  return 'Could not create farm. Please check your connection and try again.';
}

/// Lists the user's farms (live from Supabase under RLS) and can create one.
class FarmsScreen extends ConsumerWidget {
  const FarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(myFarmsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(ref.watch(stringsProvider).myFarms)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFarm(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Symbols.add),
        label: Text(ref.watch(stringsProvider).addFarm),
      ),
      body: farms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    isOfflineError(e) ? Symbols.wifi_off : Symbols.error,
                    size: 48,
                    color: AppColors.outline),
                const SizedBox(height: 12),
                Text(friendlyError(e),
                    textAlign: TextAlign.center,
                    style: AppText.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(myFarmsProvider),
                  icon: const Icon(Symbols.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return _EmptyState(onAdd: () => _showAddFarm(context, ref));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myFarmsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final f = list[i];
                return Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FarmDetailScreen(farm: f),
                      ),
                    ),
                    child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Symbols.grass,
                            color: AppColors.onPrimaryContainer),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.name,
                                style: AppText.bodyMd
                                    .copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              f.totalArea != null
                                  ? '${f.locationLabel} · ${f.totalArea} ${f.areaUnit}'
                                  : f.locationLabel,
                              style: AppText.labelSm
                                  .copyWith(color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Symbols.chevron_right,
                          color: AppColors.outline),
                    ],
                  ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddFarm(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final regionCtrl = TextEditingController();
    String? error;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
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
                  Text('Add a farm', style: AppText.headlineSm),
                  const SizedBox(height: 16),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(error!,
                          style:
                              AppText.labelMd.copyWith(color: AppColors.error)),
                    ),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        hintText: 'Farm name (e.g. Afgooye Farm)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: regionCtrl,
                    decoration:
                        const InputDecoration(hintText: 'Region (optional)'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty) {
                              setModalState(
                                  () => error = 'Farm name is required.');
                              return;
                            }
                            setModalState(() {
                              saving = true;
                              error = null;
                            });
                            try {
                              await ref
                                  .read(profileRepositoryProvider)
                                  .createFarm(
                                    name: nameCtrl.text.trim(),
                                    region: regionCtrl.text.trim(),
                                  );
                              ref.invalidate(myFarmsProvider);
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              setModalState(() {
                                saving = false;
                                error = _friendlyError(e);
                              });
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.onPrimary))
                        : const Text('Add farm'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.agriculture, size: 56, color: AppColors.outline),
            const SizedBox(height: 12),
            Text('No farms yet',
                style: AppText.headlineSm, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Create your first farm to start tracking.',
                style:
                    AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAdd, child: const Text('Add farm')),
          ],
        ),
      ),
    );
  }
}

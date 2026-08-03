import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'sync_service.dart';

/// Thin strip that tells the farmer where their data stands.
///
/// Silent when everything is synced — it only speaks up when work is waiting,
/// which is the moment "did my expense actually save?" matters.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);

    if (status.isClean) return const SizedBox.shrink();

    final (icon, colour, message) = switch (status) {
      _ when status.stuck > 0 => (
          Symbols.error,
          AppColors.error,
          '${status.stuck} ${status.stuck == 1 ? 'change' : 'changes'} could not '
              'be saved to the server',
        ),
      _ when !status.online => (
          Symbols.cloud_off,
          AppColors.onSurfaceVariant,
          status.hasPending
              ? 'Offline — ${status.pending} waiting to sync'
              : 'Offline — your work is saved on this phone',
        ),
      _ when status.syncing => (
          Symbols.sync,
          AppColors.primary,
          'Syncing ${status.pending}…',
        ),
      _ => (
          Symbols.cloud_upload,
          AppColors.tertiary,
          '${status.pending} waiting to sync',
        ),
    };

    return Material(
      color: colour.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colour),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: AppText.labelSm.copyWith(color: colour)),
            ),
            if (status.online && status.hasPending && !status.syncing)
              TextButton(
                onPressed: () => ref.read(syncServiceProvider).drain(),
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

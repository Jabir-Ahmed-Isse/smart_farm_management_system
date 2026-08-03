import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/time_ago.dart';
import '../../admin/data/admin_system_repository.dart';
import '../data/notifications_repository.dart';

/// Farmer-facing announcements inbox. Opening it marks everything seen, which
/// clears the badge on the dashboard bell.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  DateTime? _lastSeen;

  @override
  void initState() {
    super.initState();
    // Capture the previous last-seen for highlighting, then mark all seen.
    final repo = ref.read(notificationsRepositoryProvider);
    _lastSeen = repo.lastSeen();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await repo.markAllSeen();
      ref.invalidate(unreadNotificationsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(myNotificationsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: AppColors.background,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myNotificationsProvider),
        child: inbox.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(children: [
            const SizedBox(height: 120),
            Center(child: Text('Could not load announcements',
                style: AppText.headlineSm)),
          ]),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 140),
                const Icon(Symbols.notifications_off,
                    size: 56, color: AppColors.outline),
                const SizedBox(height: 12),
                Center(
                    child: Text('No announcements yet', style: AppText.headlineSm)),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) => _Card(
                b: list[i],
                isNew: _lastSeen == null || list[i].createdAt.isAfter(_lastSeen!),
              ),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
            );
          },
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.b, required this.isNew});
  final Broadcast b;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isNew ? AppColors.primary : AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Symbols.campaign, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(b.title, style: AppText.labelMd)),
            if (isNew)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('New',
                    style: AppText.labelSm.copyWith(color: AppColors.onPrimary)),
              ),
          ]),
          const SizedBox(height: 8),
          Text(b.body, style: AppText.bodyMd),
          const SizedBox(height: 8),
          Text(timeAgo(b.createdAt),
              style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

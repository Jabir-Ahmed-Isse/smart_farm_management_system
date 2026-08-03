import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/time_ago.dart';
import '../../../models/chat.dart';
import '../data/chat_repository.dart';
import 'chat_thread_screen.dart';
import 'find_farmers_screen.dart';

/// The farmer's chat inbox — a list of 1:1 conversations.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(chatThreadsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FindFarmersScreen())),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Symbols.edit_square),
        label: const Text('New message'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(chatThreadsProvider),
        child: threads.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            Center(child: Text('Messages aren\'t available yet.',
                style: AppText.bodyMd)),
          ]),
          data: (list) => list.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 120),
                  const Icon(Symbols.forum, size: 56, color: AppColors.outline),
                  const SizedBox(height: 12),
                  Center(child: Text('No conversations yet', style: AppText.headlineSm)),
                  const SizedBox(height: 8),
                  Center(
                      child: Text('Tap "New message" to find a farmer and chat.',
                          style: AppText.bodyMd
                              .copyWith(color: AppColors.onSurfaceVariant))),
                ])
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _tile(context, list[i]),
                ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, ChatThread t) {
    return ListTile(
      leading: _Avatar(name: t.otherName, url: t.otherAvatar),
      title: Text(t.otherName, style: AppText.labelMd),
      subtitle: Text(t.lastMessage ?? 'Say hello 👋',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.labelSm),
      trailing: t.lastAt == null
          ? null
          : Text(timeAgo(t.lastAt!), style: AppText.labelSm),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          threadId: t.threadId,
          otherName: t.otherName,
          otherAvatar: t.otherAvatar,
        ),
      )),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url});
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.startsWith('http')) {
      return CircleAvatar(radius: 22, backgroundImage: NetworkImage(url!));
    }
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join();
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primaryContainer,
      child: Text(initials.toUpperCase(),
          style: AppText.labelMd.copyWith(color: Colors.white)),
    );
  }
}

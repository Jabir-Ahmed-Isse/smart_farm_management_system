import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/roles.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/time_ago.dart';
import '../../../models/community_post.dart';
import '../data/community_repository.dart';
import 'messages_screen.dart';
import 'post_detail_screen.dart';
import 'widgets/post_image.dart';

/// The global community feed — posts from farmers and experts.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(communityFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Community'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            tooltip: 'Messages',
            icon: const Icon(Symbols.chat),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MessagesScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _compose(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Symbols.edit),
        label: Text(ref.watch(stringsProvider).newPost),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(communityFeedProvider),
        child: feed.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              const Icon(Symbols.forum, size: 56, color: AppColors.outline),
              const SizedBox(height: 12),
              Center(child: Text('Community isn\'t available yet', style: AppText.headlineSm)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text('Pull down to refresh once it\'s set up.',
                    textAlign: TextAlign.center,
                    style: AppText.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ),
            ],
          ),
          data: (posts) => posts.isEmpty
              ? _empty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  itemCount: posts.length,
                  itemBuilder: (_, i) => _PostCard(post: posts[i]),
                ),
        ),
      ),
    );
  }

  Widget _empty() => ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(Symbols.forum, size: 56, color: AppColors.outline),
          const SizedBox(height: 12),
          Center(child: Text('No posts yet', style: AppText.headlineSm)),
          const SizedBox(height: 8),
          Center(
              child: Text('Be the first to share something.',
                  style: AppText.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant))),
        ],
      );

  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    var posting = false;
    Uint8List? image;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setState) {
            final hasContent =
                controller.text.trim().isNotEmpty || image != null;

            Future<void> submit() async {
              if (controller.text.trim().isEmpty && image == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Write something or add a photo first.')));
                return;
              }
              setState(() => posting = true);
              try {
                final repo = ref.read(communityRepositoryProvider);
                String? url;
                if (image != null) url = await repo.uploadPostImage(image!);
                await repo.createPost(controller.text, imageUrl: url);
                ref.invalidate(communityFeedProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                setState(() => posting = false);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Could not post: $e')));
                }
              }
            }

            Future<void> pickPhoto() async {
              final file = await ImagePicker()
                  .pickImage(source: ImageSource.gallery, maxWidth: 2000);
              if (file != null) {
                final b = await file.readAsBytes();
                setState(() => image = b);
              }
            }

            return ConstrainedBox(
              // Keep the sheet within the space above the keyboard so the
              // pinned Post button at the bottom is always visible.
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.9 -
                    MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('New post', style: AppText.headlineSm),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Symbols.close),
                        onPressed: posting ? null : () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: controller,
                            autofocus: true,
                            minLines: 3,
                            maxLines: 6,
                            // Refresh so the Post button enables as you type.
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Share a question, tip or update…',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (image != null) ...[
                            const SizedBox(height: 12),
                            Stack(
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(image!,
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Material(
                                    color: Colors.black54,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () =>
                                          setState(() => image = null),
                                      child: const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(Symbols.close,
                                            size: 18, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Symbols.check_circle,
                                            size: 14, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Photo added',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: posting ? null : pickPhoto,
                              icon: const Icon(Symbols.add_photo_alternate),
                              label: Text(
                                  image == null ? 'Add photo' : 'Change photo'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Primary action — full width, pinned above the keyboard so
                  // it can never be hidden by the photo preview or the keyboard.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (posting || !hasContent) ? null : submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.4),
                        disabledForegroundColor:
                            AppColors.onPrimary.withValues(alpha: 0.7),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: posting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Symbols.send, size: 18),
                      label: Text(posting ? 'Posting…' : 'Post'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerStatefulWidget {
  const _PostCard({required this.post});
  final CommunityPost post;

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  late CommunityPost _post = widget.post;
  bool _liking = false;

  @override
  Widget build(BuildContext context) {
    final p = _post;
    final mine = ref.watch(currentUserProvider)?.id == p.authorId;
    final isAdmin = ref.watch(isAdminProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: p.pinned ? AppColors.primary : AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.pinned) ...[
            Row(children: [
              const Icon(Symbols.push_pin, size: 15, color: AppColors.primary, fill: 1),
              const SizedBox(width: 4),
              Text('Pinned', style: AppText.labelSm.copyWith(color: AppColors.primary)),
            ]),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              _Avatar(name: p.authorName, url: p.authorAvatar),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(p.authorName,
                              style: AppText.labelMd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (p.isExpert) ...[
                          const SizedBox(width: 6),
                          _badge('Expert'),
                        ],
                      ],
                    ),
                    Text(timeAgo(p.createdAt), style: AppText.labelSm),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Symbols.more_vert, size: 20),
                onSelected: (v) => _onMenu(v, mine),
                itemBuilder: (_) => [
                  if (mine)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  if (!mine)
                    const PopupMenuItem(value: 'report', child: Text('Report')),
                  if (isAdmin)
                    PopupMenuItem(
                        value: 'pin', child: Text(p.pinned ? 'Unpin' : 'Pin')),
                  if (isAdmin && !mine)
                    const PopupMenuItem(
                        value: 'admin_delete', child: Text('Delete (admin)')),
                  if (isAdmin && !mine)
                    const PopupMenuItem(value: 'ban', child: Text('Ban author')),
                ],
              ),
            ],
          ),
          if (p.body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(p.body, style: AppText.bodyMd),
          ],
          if (p.imageUrl != null && p.imageUrl!.startsWith('http')) ...[
            const SizedBox(height: 10),
            PostImage(url: p.imageUrl!),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _action(
                icon: p.likedByMe ? Symbols.favorite : Symbols.favorite,
                filled: p.likedByMe,
                color: p.likedByMe ? AppColors.error : AppColors.onSurfaceVariant,
                label: '${p.likeCount}',
                onTap: _liking ? null : _toggleLike,
              ),
              const SizedBox(width: 20),
              _action(
                icon: Symbols.chat_bubble,
                filled: false,
                color: AppColors.onSurfaceVariant,
                label: '${p.commentCount}',
                onTap: _openDetail,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required bool filled,
    required Color color,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color, fill: filled ? 1 : 0),
            const SizedBox(width: 6),
            Text(label, style: AppText.labelMd.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text,
            style: AppText.labelSm.copyWith(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10)),
      );

  Future<void> _toggleLike() async {
    final before = _post;
    setState(() {
      _liking = true;
      _post = _post.copyWith(
        likedByMe: !before.likedByMe,
        likeCount: before.likeCount + (before.likedByMe ? -1 : 1),
      );
    });
    try {
      await ref.read(communityRepositoryProvider).toggleLike(before.id);
    } catch (_) {
      if (mounted) setState(() => _post = before);
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _openDetail() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PostDetailScreen(post: _post),
    ));
    ref.invalidate(communityFeedProvider);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This removes your post and its comments.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(communityRepositoryProvider).deletePost(_post.id);
      ref.invalidate(communityFeedProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  Future<void> _onMenu(String action, bool mine) async {
    final repo = ref.read(communityRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case 'delete':
        return _confirmDelete();
      case 'report':
        final reason = await _reportDialog();
        if (reason == null) return;
        try {
          await repo.reportPost(_post.id, reason);
          messenger.showSnackBar(const SnackBar(
              content: Text('Reported. Thanks — our team will review it.')));
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('Report failed: $e')));
        }
      case 'pin':
        try {
          await repo.adminSetPinned(_post.id, !_post.pinned);
          setState(() => _post = _post.copyWith(pinned: !_post.pinned));
          ref.invalidate(communityFeedProvider);
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      case 'admin_delete':
        if (!await _confirm('Delete this post?', 'Removes the post as a moderator.')) {
          return;
        }
        try {
          await repo.adminDeletePost(_post.id);
          ref.invalidate(communityFeedProvider);
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      case 'ban':
        if (!await _confirm('Ban this user?',
            'Suspends ${_post.authorName} from the app until restored.')) {
          return;
        }
        try {
          await repo.banUser(_post.authorId);
          messenger.showSnackBar(SnackBar(content: Text('${_post.authorName} banned')));
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
    }
  }

  Future<String?> _reportDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report post'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'What is wrong with this post?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Report')),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String msg) async =>
      (await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
          ],
        ),
      )) ??
      false;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url});
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.startsWith('http')) {
      return CircleAvatar(radius: 20, backgroundImage: NetworkImage(url!));
    }
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join();
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.primaryContainer,
      child: Text(initials.toUpperCase(),
          style: AppText.labelMd.copyWith(color: Colors.white)),
    );
  }
}

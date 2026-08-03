import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/time_ago.dart';
import '../../../models/community_post.dart';
import '../data/chat_repository.dart';
import '../data/community_repository.dart';
import 'chat_thread_screen.dart';
import 'widgets/post_image.dart';

/// A single post with its comments and an input to add one.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.post});
  final CommunityPost post;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final comments = ref.watch(postCommentsProvider(post.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _postHeader(post),
                const Divider(height: 32),
                Text('Comments', style: AppText.labelMd),
                const SizedBox(height: 8),
                comments.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) =>
                      Text('Could not load comments.', style: AppText.labelSm),
                  data: (list) => list.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text('No comments yet. Start the conversation.',
                              style: AppText.bodyMd
                                  .copyWith(color: AppColors.onSurfaceVariant)),
                        )
                      : Column(
                          children: [
                            for (final c in list) _comment(c),
                          ],
                        ),
                ),
              ],
            ),
          ),
          _input(post),
        ],
      ),
    );
  }

  Widget _postHeader(CommunityPost p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryContainer,
              child: Text(_initials(p.authorName),
                  style: AppText.labelMd.copyWith(color: Colors.white)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.authorName, style: AppText.labelMd),
                  Text(timeAgo(p.createdAt), style: AppText.labelSm),
                ],
              ),
            ),
            if (ref.watch(currentUserProvider)?.id != p.authorId &&
                p.authorId.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _message(p),
                icon: const Icon(Symbols.chat, size: 18),
                label: const Text('Message'),
              ),
          ],
        ),
        if (p.body.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(p.body, style: AppText.bodyLg),
        ],
        if (p.imageUrl != null && p.imageUrl!.startsWith('http')) ...[
          const SizedBox(height: 12),
          PostImage(url: p.imageUrl!),
        ],
      ],
    );
  }

  Widget _comment(CommunityComment c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surfaceContainerHigh,
            child: Text(_initials(c.authorName),
                style: AppText.labelSm.copyWith(color: AppColors.onSurface)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(c.authorName, style: AppText.labelMd)),
                      Text(timeAgo(c.createdAt), style: AppText.labelSm),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(c.body, style: AppText.bodyMd),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(CommunityPost post) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(top: BorderSide(color: AppColors.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Write a comment…',
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : () => _send(post),
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Symbols.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _message(CommunityPost post) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final threadId =
          await ref.read(chatRepositoryProvider).startChat(post.authorId);
      if (!mounted) return;
      navigator.push(MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          threadId: threadId,
          otherName: post.authorName,
          otherAvatar: post.authorAvatar,
        ),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not start chat: $e')));
    }
  }

  Future<void> _send(CommunityPost post) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(communityRepositoryProvider).addComment(post.id, text);
      _controller.clear();
      ref.invalidate(postCommentsProvider(post.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not comment: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _initials(String name) => name.trim().isEmpty
      ? '?'
      : name
          .trim()
          .split(RegExp(r'\s+'))
          .take(2)
          .map((w) => w[0])
          .join()
          .toUpperCase();
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/time_ago.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/kb_article.dart';
import '../data/kb_repository.dart';
import 'article_editor_screen.dart';
import 'articles_screen.dart' show KbMode, kbStatusMeta;

/// Reads one article and exposes role-appropriate actions: bookmark (everyone),
/// edit/delete (author or admin), approve/reject/unpublish (admin).
class ArticleDetailScreen extends ConsumerStatefulWidget {
  const ArticleDetailScreen({super.key, required this.article, required this.mode});
  final KbArticle article;
  final KbMode mode;

  @override
  ConsumerState<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends ConsumerState<ArticleDetailScreen> {
  late KbArticle _a = widget.article;
  bool _busy = false;

  bool get _isAdmin => widget.mode == KbMode.admin;
  bool get _canEdit => widget.mode == KbMode.admin || widget.mode == KbMode.mine;

  @override
  Widget build(BuildContext context) {
    final a = _a;
    final (sColor, sLabel) = kbStatusMeta(a.status);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            tooltip: 'Bookmark',
            icon: Icon(a.bookmarked ? Symbols.bookmark : Symbols.bookmark_border,
                fill: a.bookmarked ? 1 : 0,
                color: a.bookmarked ? AppColors.primary : null),
            onPressed: _toggleBookmark,
          ),
          if (_canEdit)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Symbols.edit),
              onPressed: _edit,
            ),
          if (_canEdit)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Symbols.delete),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          if (a.coverImageUrl != null && a.coverImageUrl!.startsWith('http'))
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(a.coverImageUrl!,
                    width: double.infinity, height: 200, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          Row(children: [
            _chip(kbCategoryLabel(a.category), AppColors.primary),
            const SizedBox(width: 8),
            if (widget.mode != KbMode.read) _chip(sLabel, sColor),
          ]),
          const SizedBox(height: 12),
          Text(a.title, style: AppText.headlineMd),
          const SizedBox(height: 6),
          Text('${a.authorName ?? 'Expert'} · ${timeAgo(a.createdAt)}',
              style: AppText.labelSm),
          const Divider(height: 28),
          Text(a.body.isEmpty ? 'No content.' : a.body, style: AppText.bodyLg),
          if (_isAdmin) ...[
            const SizedBox(height: 24),
            _moderation(a),
          ],
        ],
      ),
    );
  }

  Widget _moderation(KbArticle a) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Moderation', style: AppText.labelMd),
          const SizedBox(height: 12),
          Row(children: [
            if (a.status != 'published')
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _setStatus('published'),
                  icon: const Icon(Symbols.check),
                  label: const Text('Approve'),
                ),
              ),
            if (a.status == 'published')
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _setStatus('draft'),
                  icon: const Icon(Symbols.unpublished),
                  label: const Text('Unpublish'),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _setStatus('rejected'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                icon: const Icon(Symbols.close),
                label: const Text('Reject'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    final before = _a;
    setState(() => _a = _a.copyWith(bookmarked: !_a.bookmarked));
    try {
      await ref.read(kbRepositoryProvider).toggleBookmark(_a.id);
    } catch (_) {
      if (mounted) setState(() => _a = before);
    }
  }

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(kbRepositoryProvider).setStatus(_a.id, status);
      setState(() {
        _a = KbArticle(
          id: _a.id, title: _a.title, body: _a.body, category: _a.category,
          coverImageUrl: _a.coverImageUrl, authorId: _a.authorId, authorName: _a.authorName,
          status: status, publishedAt: _a.publishedAt, createdAt: _a.createdAt,
          bookmarked: _a.bookmarked,
        );
      });
      messenger.showSnackBar(SnackBar(content: Text('Article ${_statusVerb(status)}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _statusVerb(String s) => switch (s) {
        'published' => 'approved & published',
        'rejected' => 'rejected',
        'draft' => 'unpublished',
        _ => 'updated',
      };

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ArticleEditorScreen(existing: _a)));
    if (saved == true && mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirmDelete(context,
        title: 'Delete article?', message: 'This permanently removes "${_a.title}".');
    if (ok != true) return;
    try {
      await ref.read(kbRepositoryProvider).delete(_a.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: AppText.labelSm.copyWith(color: color, fontWeight: FontWeight.w600)),
      );
}

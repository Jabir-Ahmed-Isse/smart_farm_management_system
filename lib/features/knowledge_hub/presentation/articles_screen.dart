import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/time_ago.dart';
import '../../../models/kb_article.dart';
import '../data/kb_repository.dart';
import 'article_detail_screen.dart';
import 'article_editor_screen.dart';

/// How the Knowledge Base list behaves per role.
enum KbMode {
  /// Everyone: published articles, read-only + bookmarks.
  read,

  /// Expert: their own articles across all statuses, with a "Write" button.
  mine,

  /// Admin: every article with a status filter (approval queue) + moderation.
  admin,
}

(Color, String) kbStatusMeta(String s) => switch (s) {
      'published' => (AppColors.primary, 'Published'),
      'pending' => (AppColors.tertiary, 'Pending'),
      'rejected' => (AppColors.error, 'Rejected'),
      _ => (AppColors.outline, 'Draft'),
    };

class ArticlesScreen extends ConsumerStatefulWidget {
  const ArticlesScreen({super.key, this.mode = KbMode.read});
  final KbMode mode;

  @override
  ConsumerState<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends ConsumerState<ArticlesScreen> {
  String _search = '';
  String _category = '';
  String? _statusFilter; // admin queue filter
  bool _bookmarkedOnly = false;

  bool get _canWrite => widget.mode != KbMode.read;

  String get _title => switch (widget.mode) {
        KbMode.admin => 'Knowledge Base',
        KbMode.mine => 'My Articles',
        KbMode.read => 'Knowledge Hub',
      };

  @override
  Widget build(BuildContext context) {
    final query = (
      search: _search,
      category: _category,
      status: widget.mode == KbMode.read
          ? 'published'
          : (widget.mode == KbMode.admin ? _statusFilter : null),
      mine: widget.mode == KbMode.mine,
      bookmarked: _bookmarkedOnly,
    );
    final articles = ref.watch(kbArticlesProvider(query));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: AppColors.background,
        actions: [
          if (widget.mode == KbMode.read)
            IconButton(
              tooltip: 'Bookmarks',
              icon: Icon(_bookmarkedOnly ? Symbols.bookmark : Symbols.bookmark_border,
                  fill: _bookmarkedOnly ? 1 : 0),
              onPressed: () => setState(() => _bookmarkedOnly = !_bookmarkedOnly),
            ),
        ],
      ),
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(context),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Symbols.edit_note),
              label: const Text('Write'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search articles…',
                prefixIcon: const Icon(Symbols.search),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
          _filters(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(kbArticlesProvider),
              child: articles.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text(
                        e.toString().contains('42501') ? 'Not authorized' : 'Could not load',
                        style: AppText.headlineSm)),
                data: (list) => list.isEmpty
                    ? _empty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _ArticleCard(
                            article: list[i], mode: widget.mode, onChanged: _refresh),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          if (widget.mode == KbMode.admin) ...[
            for (final s in const [(null, 'All'), ('pending', 'Pending'), ('published', 'Published'), ('rejected', 'Rejected')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.$2),
                  selected: _statusFilter == s.$1,
                  onSelected: (_) => setState(() => _statusFilter = s.$1),
                ),
              ),
            const SizedBox(width: 4),
            const VerticalDivider(width: 1),
            const SizedBox(width: 8),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All topics'),
              selected: _category.isEmpty,
              onSelected: (_) => setState(() => _category = ''),
            ),
          ),
          for (final c in kbCategories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(kbCategoryLabel(c)),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              ),
            ),
        ],
      ),
    );
  }

  void _refresh() => ref.invalidate(kbArticlesProvider);

  Future<void> _openEditor(BuildContext context) async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const ArticleEditorScreen()));
    if (saved == true) _refresh();
  }

  Widget _empty() => ListView(children: [
        const SizedBox(height: 120),
        const Icon(Symbols.menu_book, size: 52, color: AppColors.outline),
        const SizedBox(height: 12),
        Center(
            child: Text(
                _bookmarkedOnly ? 'No bookmarks yet' : 'No articles yet',
                style: AppText.labelMd)),
      ]);
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.mode, required this.onChanged});
  final KbArticle article;
  final KbMode mode;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final showStatus = mode != KbMode.read;
    final (sColor, sLabel) = kbStatusMeta(article.status);
    return Card(
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ArticleDetailScreen(article: article, mode: mode)));
          onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.coverImageUrl != null && article.coverImageUrl!.startsWith('http'))
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(article.coverImageUrl!,
                        width: 56, height: 56, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 56, height: 56)),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(article.title,
                        style: AppText.labelMd, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      '${kbCategoryLabel(article.category)} · ${article.authorName ?? 'Expert'} · ${timeAgo(article.createdAt)}',
                      style: AppText.labelSm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showStatus) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: sColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(sLabel,
                            style: AppText.labelSm
                                .copyWith(color: sColor, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
              if (article.bookmarked)
                const Icon(Symbols.bookmark, size: 18, color: AppColors.primary, fill: 1),
            ],
          ),
        ),
      ),
    );
  }
}

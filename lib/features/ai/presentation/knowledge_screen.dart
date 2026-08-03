import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/farm.dart';
import '../../../models/knowledge_entry.dart';
import '../../profile/data/profile_repository.dart';
import '../data/knowledge_repository.dart';

/// Searchable AI knowledge base — diagnoses, treatments, corrections & notes.
class KnowledgeScreen extends ConsumerStatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  ConsumerState<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends ConsumerState<KnowledgeScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farms = ref.watch(myFarmsProvider);
    final farm =
        farms.valueOrNull?.isNotEmpty == true ? farms.value!.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(ref.watch(stringsProvider).knowledgeBase)),
      floatingActionButton: farm == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addSheet(farm),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Symbols.add),
              label: const Text('Add note'),
            ),
      body: farm == null
          ? const Center(child: Text('Create a farm to use the knowledge base.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
                    decoration: InputDecoration(
                      hintText: 'Search treatments, diseases, notes…',
                      prefixIcon: const Icon(Symbols.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Symbols.close),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ),
                Expanded(child: _List(farm: farm, query: _query)),
              ],
            ),
    );
  }

  Future<void> _addSheet(Farm farm) async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    String? error;
    bool saving = false;

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
              Text('Add knowledge note', style: AppText.headlineSm),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    const InputDecoration(hintText: 'Title (e.g. Blight fix)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    hintText: 'What worked, dosage, notes…'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tagsCtrl,
                decoration: const InputDecoration(
                    hintText: 'Tags, comma-separated (optional)'),
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
                        if (titleCtrl.text.trim().isEmpty ||
                            contentCtrl.text.trim().isEmpty) {
                          setModalState(
                              () => error = 'Add a title and some content.');
                          return;
                        }
                        final nav = Navigator.of(ctx);
                        setModalState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final tags = tagsCtrl.text
                              .split(',')
                              .map((t) => t.trim())
                              .where((t) => t.isNotEmpty)
                              .toList();
                          await ref.read(knowledgeRepositoryProvider).addEntry(
                                farmId: farm.id,
                                title: titleCtrl.text,
                                content: contentCtrl.text,
                                tags: tags,
                              );
                          ref.invalidate(knowledgeForFarmProvider(farm.id));
                          nav.pop();
                        } catch (_) {
                          setModalState(() {
                            saving = false;
                            error = 'Could not save the note.';
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onPrimary))
                    : const Text('Save note'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.farm, required this.query});
  final Farm farm;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(knowledgeForFarmProvider(farm.id));
    return entries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load the knowledge base.\n$e',
              textAlign: TextAlign.center,
              style:
                  AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
        ),
      ),
      data: (all) {
        final list = query.isEmpty
            ? all
            : all.where((e) => e.searchText.contains(query)).toList();
        if (all.isEmpty) {
          return _empty(
              'No knowledge notes yet.\nSave treatments and fixes that worked.');
        }
        if (list.isEmpty) {
          return _empty('No notes match "$query".');
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: list.length,
          itemBuilder: (_, i) => _EntryCard(
            entry: list[i],
            onDelete: list[i].isGlobal
                ? null
                : () async {
                    final ok = await confirmDelete(context,
                        title: 'Delete note?',
                        message: 'Remove "${list[i].title}"?');
                    if (ok != true) return;
                    await ref
                        .read(knowledgeRepositoryProvider)
                        .deleteEntry(list[i].id);
                    ref.invalidate(knowledgeForFarmProvider(farm.id));
                  },
          ),
        );
      },
    );
  }

  Widget _empty(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.menu_book, size: 48, color: AppColors.outline),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: AppText.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, this.onDelete});
  final KnowledgeEntry entry;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(entry.title,
                    style: AppText.bodyMd
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
              _SourceChip(
                  source: entry.source, global: entry.isGlobal),
              if (onDelete != null)
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Symbols.delete,
                        size: 18, color: AppColors.onSurfaceVariant),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(entry.content,
                style: AppText.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ),
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in entry.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('#$t',
                        style: AppText.labelSm
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source, required this.global});
  final String source;
  final bool global;

  @override
  Widget build(BuildContext context) {
    final label = global ? 'Shared' : source;
    final color = global ? AppColors.secondary : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: AppText.labelSm
              .copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

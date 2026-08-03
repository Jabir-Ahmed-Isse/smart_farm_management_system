import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/kb_article.dart';
import '../data/kb_repository.dart';

/// Create or edit a Knowledge Base article. New articles submit as 'pending'
/// for admin approval; edits keep the current status.
class ArticleEditorScreen extends ConsumerStatefulWidget {
  const ArticleEditorScreen({super.key, this.existing});
  final KbArticle? existing;

  @override
  ConsumerState<ArticleEditorScreen> createState() => _ArticleEditorScreenState();
}

class _ArticleEditorScreenState extends ConsumerState<ArticleEditorScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _category = 'general';
  String? _coverUrl;
  Uint8List? _newCover;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _body.text = e.body;
      _category = e.category;
      _coverUrl = e.coverImageUrl;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCover = _newCover != null || (_coverUrl != null && _coverUrl!.startsWith('http'));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Write article' : 'Edit article'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          GestureDetector(
            onTap: _pickCover,
            child: Container(
              height: 160,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant),
                image: hasCover
                    ? DecorationImage(
                        image: _newCover != null
                            ? MemoryImage(_newCover!)
                            : NetworkImage(_coverUrl!) as ImageProvider,
                        fit: BoxFit.cover)
                    : null,
              ),
              child: hasCover
                  ? null
                  : const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Symbols.image, size: 32, color: AppColors.outline),
                      SizedBox(height: 6),
                      Text('Add cover image (optional)'),
                    ])),
            ),
          ),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: [
              for (final c in kbCategories)
                DropdownMenuItem(value: c, child: Text(kbCategoryLabel(c))),
            ],
            onChanged: (v) => setState(() => _category = v ?? 'general'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 10,
            maxLines: 24,
            decoration: const InputDecoration(
                labelText: 'Article body',
                alignLabelWithHint: true,
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text(
            widget.existing == null
                ? 'New articles are submitted for admin review before they appear to farmers.'
                : 'Saving keeps the current status.',
            style: AppText.labelSm,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _saving
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.existing == null ? 'Submit for review' : 'Save changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCover() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000);
    if (file != null) {
      setState(() => _newCover = null);
      final b = await file.readAsBytes();
      setState(() => _newCover = b);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(kbRepositoryProvider);
    try {
      var cover = _coverUrl;
      if (_newCover != null) cover = await repo.uploadCover(_newCover!);
      if (widget.existing == null) {
        await repo.create(
            title: _title.text, body: _body.text, category: _category, cover: cover);
      } else {
        await repo.update(
            id: widget.existing!.id,
            title: _title.text,
            body: _body.text,
            category: _category,
            cover: cover);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }
}

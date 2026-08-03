import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/disease.dart';
import '../data/disease_repository.dart';

(Color, String) severityMeta(String s) => switch (s) {
      'critical' => (AppColors.error, 'CRITICAL'),
      'high' => (AppColors.error, 'HIGH'),
      'medium' => (AppColors.tertiary, 'MEDIUM'),
      _ => (AppColors.primary, 'LOW'),
    };

/// Admin → Disease Database. Searchable reference library with CRUD and
/// reference-image upload.
class AdminDiseasesScreen extends ConsumerStatefulWidget {
  const AdminDiseasesScreen({super.key});

  @override
  ConsumerState<AdminDiseasesScreen> createState() => _AdminDiseasesScreenState();
}

class _AdminDiseasesScreenState extends ConsumerState<AdminDiseasesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final diseases = ref.watch(diseasesProvider(_search));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Disease Database'),
        backgroundColor: AppColors.background,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Symbols.add),
        label: const Text('Add disease'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search diseases or crops…',
                prefixIcon: const Icon(Symbols.search),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(diseasesProvider),
              child: diseases.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                      e.toString().contains('42501') ? 'Admins only' : 'Could not load',
                      style: AppText.headlineSm),
                ),
                data: (list) => list.isEmpty
                    ? _empty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _tile(context, list[i]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Disease d) {
    final (color, label) = severityMeta(d.severity);
    return Card(
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: ListTile(
        leading: d.imageUrl != null && d.imageUrl!.startsWith('http')
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(d.imageUrl!,
                    width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Symbols.coronavirus)),
              )
            : CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(Symbols.coronavirus, color: color)),
        title: Text(d.name, style: AppText.labelMd),
        subtitle: Text(d.crop ?? 'General',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.labelSm),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _openForm(context, d);
            if (v == 'delete') _delete(context, d);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _openForm(context, d),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, [Disease? existing]) async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => _DiseaseForm(existing: existing)));
    if (saved == true) ref.invalidate(diseasesProvider);
  }

  Future<void> _delete(BuildContext context, Disease d) async {
    final ok = await confirmDelete(context,
        title: 'Delete disease?', message: 'Remove "${d.name}".');
    if (ok != true) return;
    try {
      await ref.read(diseaseRepositoryProvider).delete(d.id);
      ref.invalidate(diseasesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Widget _empty() => ListView(children: [
        const SizedBox(height: 120),
        const Icon(Symbols.coronavirus, size: 52, color: AppColors.outline),
        const SizedBox(height: 12),
        Center(child: Text('No diseases yet', style: AppText.labelMd)),
      ]);
}

// ============================================================ form

class _DiseaseForm extends ConsumerStatefulWidget {
  const _DiseaseForm({this.existing});
  final Disease? existing;

  @override
  ConsumerState<_DiseaseForm> createState() => _DiseaseFormState();
}

class _DiseaseFormState extends ConsumerState<_DiseaseForm> {
  final _name = TextEditingController();
  final _crop = TextEditingController();
  final _symptoms = TextEditingController();
  final _causes = TextEditingController();
  final _chemical = TextEditingController();
  final _organic = TextEditingController();
  final _prevention = TextEditingController();
  final _recovery = TextEditingController();
  String _severity = 'medium';
  String? _imageUrl;
  Uint8List? _newImage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _crop.text = e.crop ?? '';
      _symptoms.text = e.symptoms ?? '';
      _causes.text = e.causes ?? '';
      _chemical.text = e.chemicalTreatment ?? '';
      _organic.text = e.organicTreatment ?? '';
      _prevention.text = e.prevention ?? '';
      _recovery.text = e.recovery ?? '';
      _severity = e.severity;
      _imageUrl = e.imageUrl;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _crop, _symptoms, _causes, _chemical, _organic, _prevention, _recovery]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add disease' : 'Edit disease'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _imagePicker(),
          _field(_name, 'Name *'),
          Row(children: [
            Expanded(child: _field(_crop, 'Crop')),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _severity,
                decoration: const InputDecoration(labelText: 'Severity', border: OutlineInputBorder()),
                items: [
                  for (final s in diseaseSeverities)
                    DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1))),
                ],
                onChanged: (v) => setState(() => _severity = v ?? 'medium'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _field(_symptoms, 'Symptoms', lines: 3),
          _field(_causes, 'Causes', lines: 2),
          _field(_chemical, 'Chemical treatment', lines: 3),
          _field(_organic, 'Organic treatment', lines: 3),
          _field(_prevention, 'Prevention', lines: 2),
          _field(_recovery, 'Recovery', lines: 2),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save disease'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          minLines: lines,
          maxLines: lines,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  Widget _imagePicker() {
    final hasImage = _newImage != null || (_imageUrl != null && _imageUrl!.startsWith('http'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant),
            image: hasImage
                ? DecorationImage(
                    image: _newImage != null
                        ? MemoryImage(_newImage!)
                        : NetworkImage(_imageUrl!) as ImageProvider,
                    fit: BoxFit.cover)
                : null,
          ),
          child: hasImage
              ? null
              : const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Symbols.add_a_photo, size: 32, color: AppColors.outline),
                  SizedBox(height: 6),
                  Text('Add reference image'),
                ])),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000);
    if (file != null) {
      final b = await file.readAsBytes();
      setState(() => _newImage = b);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(diseaseRepositoryProvider);
    try {
      var imageUrl = _imageUrl;
      if (_newImage != null) imageUrl = await repo.uploadReferenceImage(_newImage!);
      final d = Disease(
        id: widget.existing?.id ?? '',
        name: _name.text,
        crop: _crop.text,
        severity: _severity,
        symptoms: _symptoms.text,
        causes: _causes.text,
        chemicalTreatment: _chemical.text,
        organicTreatment: _organic.text,
        prevention: _prevention.text,
        recovery: _recovery.text,
        imageUrl: imageUrl,
      );
      if (widget.existing == null) {
        await repo.create(d);
      } else {
        await repo.update(widget.existing!.id, d);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }
}

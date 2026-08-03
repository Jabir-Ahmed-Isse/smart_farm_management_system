import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/admin_system_repository.dart';

/// Admin → view and edit platform-wide settings. Boolean settings toggle
/// inline; text/number settings open an edit sheet. Every change persists and
/// is recorded in the audit log.
class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(adminSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('System Settings')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminSettingsProvider),
        child: settings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            const Icon(Symbols.error, size: 56, color: AppColors.outline),
            const SizedBox(height: 12),
            Center(child: Text('Could not load', style: AppText.headlineSm)),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('$e',
                  textAlign: TextAlign.center, style: AppText.labelSm),
            ),
          ]),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              for (final s in list) _SettingTile(setting: s),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingTile extends ConsumerStatefulWidget {
  const _SettingTile({required this.setting});
  final SystemSetting setting;

  @override
  ConsumerState<_SettingTile> createState() => _SettingTileState();
}

class _SettingTileState extends ConsumerState<_SettingTile> {
  bool _busy = false;

  Future<void> _save(String value) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminSystemRepositoryProvider)
          .setSetting(widget.setting.key, value);
      ref.invalidate(adminSettingsProvider);
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not save the setting.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _title(String key) => key
      .replaceAll('_', ' ')
      .replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());

  @override
  Widget build(BuildContext context) {
    final s = widget.setting;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(s.key),
                    style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                if (s.description != null)
                  Text(s.description!,
                      style: AppText.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
                if (!s.isBool)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(s.value ?? '—',
                        style: AppText.labelMd
                            .copyWith(color: AppColors.primary)),
                  ),
              ],
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (s.isBool)
            Switch(
              value: s.boolValue,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => _save(v ? 'true' : 'false'),
            )
          else
            IconButton(
              icon: const Icon(Symbols.edit, size: 20),
              color: AppColors.onSurfaceVariant,
              onPressed: _edit,
            ),
        ],
      ),
    );
  }

  Future<void> _edit() async {
    final s = widget.setting;
    final ctrl = TextEditingController(text: s.value ?? '');
    final numeric =
        RegExp(r'^\d+$').hasMatch(s.value ?? '') || s.key.contains('limit');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_title(s.key)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(hintText: s.description),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) await _save(result);
  }
}

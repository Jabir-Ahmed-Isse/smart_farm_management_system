import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/profile_repository.dart';

/// Account & privacy: export your data or permanently delete your account.
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _exporting = false;
  bool _deleting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await ref.read(profileRepositoryProvider).exportMyData();
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = Uint8List.fromList(utf8.encode(pretty));
      final stamp = DateTime.now().toIso8601String().split('T').first;
      await FileSaver.instance.saveFile(
        name: 'somali-farm-export-$stamp',
        bytes: bytes,
        ext: 'json',
        mimeType: MimeType.json,
      );
      messenger.showSnackBar(
          const SnackBar(content: Text('Your data was exported.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteConfirmDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      // Sign-out flips the auth state; the router redirect sends us to /login.
      router.go('/login');
    } catch (e) {
      if (mounted) setState(() => _deleting = false);
      messenger.showSnackBar(
          SnackBar(content: Text('Could not delete account: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Account & Privacy'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            icon: Symbols.download,
            title: 'Export my data',
            body: 'Download a JSON copy of your profile, farms and all your '
                'records (expenses, harvests, sales, tasks and more).',
            action: FilledButton.icon(
              onPressed: _exporting ? null : _export,
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onPrimary))
                  : const Icon(Symbols.download),
              label: Text(_exporting ? 'Preparing…' : 'Export data'),
            ),
          ),
          const SizedBox(height: 12),
          const _Card(
            icon: Symbols.privacy_tip,
            title: 'Your privacy',
            body: 'Your farm data is private to your account and is not shared '
                'with other farmers. Announcements and community posts you '
                'choose to publish are visible to others.',
          ),
          const SizedBox(height: 24),
          Text('Danger zone',
              style: AppText.labelMd.copyWith(color: AppColors.error)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.errorContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Symbols.warning, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Text('Delete account', style: AppText.labelMd),
                ]),
                const SizedBox(height: 6),
                Text(
                    'This permanently deletes your account and all your farm '
                    'data. This cannot be undone.',
                    style: AppText.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _deleting ? null : _delete,
                    icon: _deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.error))
                        : const Icon(Symbols.delete_forever),
                    label: Text(_deleting ? 'Deleting…' : 'Delete my account'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Requires the user to type DELETE, so it can't be dismissed by a stray tap.
class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog();

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  final _ctrl = TextEditingController();
  bool _ok = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This permanently removes your account and every farm, '
              'record and report tied to it. It cannot be undone.\n\n'
              'Type DELETE to confirm.'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(
                hintText: 'DELETE', border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _ok = v.trim() == 'DELETE'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _ok ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Delete forever'),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: AppText.labelMd),
          ]),
          const SizedBox(height: 6),
          Text(body,
              style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
          if (action != null) ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: action!),
          ],
        ],
      ),
    );
  }
}

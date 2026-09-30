import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/auth/roles.dart';
import '../../core/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/offline/local_store.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/profile.dart';
import '../auth/data/auth_repository.dart';
import '../community/data/community_repository.dart';
import '../farms/farms_screen.dart';
import '../knowledge_hub/presentation/articles_screen.dart';
import 'data/profile_repository.dart';

const _languages = <(String, String)>[
  ('so', 'Somali (Soomaali)'),
  ('en', 'English'),
];

String _languageLabel(String code) =>
    _languages.firstWhere((l) => l.$1 == code, orElse: () => (code, code)).$2;

/// Profile & preferences — live profile, editable details, working settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final farms = ref.watch(myFarmsProvider);
    final email = ref.watch(currentUserProvider)?.email ?? '';

    final name = profile.valueOrNull?.fullName ??
        (email.isNotEmpty ? email.split('@').first : 'Farmer');
    final role = profile.valueOrNull?.role ?? 'farmer';
    final language = profile.valueOrNull?.language ?? 'so';
    final plan = profile.valueOrNull?.aiPlan ?? 'free';
    final farmCount = farms.valueOrNull?.length ?? 0;
    final t = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.profile),
        actions: [
          IconButton(
            icon: const Icon(Symbols.logout),
            tooltip: t.signOut,
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'F',
                    style: AppText.headlineMd
                        .copyWith(color: AppColors.onPrimaryContainer),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name, style: AppText.headlineSm),
                if (email.isNotEmpty)
                  Text(email,
                      style: AppText.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Chip(label: role, filled: true),
                    const SizedBox(width: 8),
                    _Chip(label: language.toUpperCase()),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(label: 'Active Farms', value: '$farmCount'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                          label: t.language, value: language.toUpperCase()),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: profile.valueOrNull == null
                        ? null
                        : () => _editProfile(context, ref, profile.value!),
                    icon: const Icon(Symbols.edit, size: 18),
                    label: Text(t.editProfile),
                  ),
                ),
              ],
            ),
          ),
          if (ref.watch(isExpertProvider)) ...[
            const SizedBox(height: 24),
            Text('Administration',
                style:
                    AppText.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (ref.watch(isAdminProvider))
              _SettingsTile(
                icon: Symbols.admin_panel_settings,
                label: 'Admin Dashboard',
                subtitle: 'Users, medicines, moderation & analytics',
                onTap: () => context.push('/admin'),
              ),
            if (ref.watch(isExpertProvider))
              _SettingsTile(
                icon: Symbols.menu_book,
                label: 'My Articles',
                subtitle: 'Write & manage knowledge articles',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ArticlesScreen(mode: KbMode.mine))),
              ),
          ],
          const SizedBox(height: 24),
          Text(t.settingsPrefs,
              style: AppText.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Symbols.agriculture,
            label: t.farmSettings,
            subtitle: t.farmSettingsSub,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FarmsScreen()),
            ),
          ),
          _SettingsTile(
            icon: Symbols.bar_chart,
            label: t.financialReports,
            subtitle: t.financialReportsSub,
            onTap: () => context.push('/reports'),
          ),
          _SettingsTile(
            icon: Symbols.workspace_premium,
            label: 'Plan & Upgrade',
            subtitle: 'Current: ${plan[0].toUpperCase()}${plan.substring(1)}',
            onTap: () => context.push('/upgrade'),
          ),
          _SettingsTile(
            icon: Symbols.language,
            label: t.language,
            subtitle: _languageLabel(language),
            onTap: () => _pickLanguage(context, ref, language),
          ),
          _SettingsTile(
            icon: Symbols.help,
            label: t.helpSupport,
            subtitle: t.helpSupportSub,
            onTap: () => context.push('/help'),
          ),
          _SettingsTile(
            icon: Symbols.feedback,
            label: 'Send Feedback',
            subtitle: 'Report a problem or request a feature',
            onTap: () => context.push('/feedback'),
          ),
          _SettingsTile(
            icon: Symbols.manage_accounts,
            label: 'Account & Privacy',
            subtitle: 'Export your data or delete your account',
            onTap: () => context.push('/account'),
          ),
          if (!ref.watch(isExpertProvider))
            _SettingsTile(
              icon: Symbols.verified,
              label: 'Become an Expert',
              subtitle: 'Apply to review diagnoses & publish articles',
              onTap: () => _applyExpert(context, ref),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Symbols.logout),
            label: Text(t.signOut),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.outlineVariant),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(
      BuildContext context, WidgetRef ref, Profile profile) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(profile: profile),
    );
  }

  Future<void> _pickLanguage(
      BuildContext context, WidgetRef ref, String current) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LanguageSheet(current: current),
    );
  }

  Future<void> _applyExpert(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final message = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Become an Expert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Experts review AI diagnoses and publish knowledge articles. '
                'Tell us about your agricultural background — an admin will review your request.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                  hintText: 'Your experience / qualifications',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Submit')),
        ],
      ),
    );
    if (message == null) return;
    try {
      await ref.read(communityRepositoryProvider).applyForExpert(message);
      messenger.showSnackBar(const SnackBar(
          content: Text('Request submitted — an admin will review it.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not submit: $e')));
    }
  }

}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.filled = false});
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? AppColors.primaryFixed : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppText.labelSm.copyWith(
          color: filled ? AppColors.onPrimaryFixed : AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Text(label.toUpperCase(),
              style:
                  AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: AppText.headlineSm.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.15),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(label, style: AppText.bodyMd),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant)),
        trailing: const Icon(Symbols.chevron_right, color: AppColors.outline),
        onTap: onTap,
      ),
    );
  }
}

/// Edit name, phone and language. Persists via the update_my_profile RPC.
class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});
  final Profile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late String _language;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.fullName ?? '');
    _phoneCtrl = TextEditingController(text: widget.profile.phone ?? '');
    _language = widget.profile.language;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit profile', style: AppText.headlineSm),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: const InputDecoration(labelText: 'Language'),
            items: [
              for (final l in _languages)
                DropdownMenuItem(value: l.$1, child: Text(l.$2)),
            ],
            onChanged: (v) => setState(() => _language = v ?? _language),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: AppText.labelMd.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.onPrimary))
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'A name is required.');
      return;
    }
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(
            fullName: _nameCtrl.text,
            phone: _phoneCtrl.text,
            language: _language,
          );
      // Keep the local UI-language override in step with the saved choice so
      // the two edit paths never disagree.
      ref.read(languageOverrideProvider.notifier).state =
          _language == 'en' ? AppLang.en : AppLang.so;
      await LocalStore.instance.metaPut(kUiLanguageKey, _language);
      ref.invalidate(myProfileProvider);
      nav.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save your profile: ${friendlyError(e)}';
        });
      }
    }
  }
}

/// Quick language picker. Persists the choice now; the interface translation
/// itself ships in a later update, which this note is honest about.
class _LanguageSheet extends ConsumerStatefulWidget {
  const _LanguageSheet({required this.current});
  final String current;

  @override
  ConsumerState<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends ConsumerState<_LanguageSheet> {
  bool _saving = false;

  Future<void> _choose(String code) async {
    if (_saving) return;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    // Language is a local UI preference — apply and persist it on-device right
    // away so the switch always works, even offline or if the profile sync
    // below fails. This is the source of truth for the UI.
    ref.read(languageOverrideProvider.notifier).state =
        code == 'en' ? AppLang.en : AppLang.so;
    await LocalStore.instance.metaPut(kUiLanguageKey, code);
    // Best-effort: mirror the choice to the profile so it follows the user
    // across devices. Failures are non-blocking and silent — the local switch
    // already succeeded, so no alert is shown either way.
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(language: code);
      ref.invalidate(myProfileProvider);
    } catch (_) {
      // Ignore: language is saved on-device regardless of the sync result.
    }
    if (!mounted) return;
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Language', style: AppText.headlineSm),
          const SizedBox(height: 4),
          Text('The full Somali interface is rolling out in an update — your '
              'choice is saved now.',
              style:
                  AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (final l in _languages)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                l.$1 == widget.current
                    ? Symbols.radio_button_checked
                    : Symbols.radio_button_unchecked,
                color: l.$1 == widget.current
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
              title: Text(l.$2, style: AppText.bodyMd),
              onTap: _saving ? null : () => _choose(l.$1),
            ),
        ],
      ),
    );
  }
}


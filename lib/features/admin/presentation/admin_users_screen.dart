import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/admin_user.dart';
import '../data/admin_users_repository.dart';
import 'admin_user_detail_screen.dart';

/// Colour + label for a role, shared by the list and detail screens.
(Color, String) roleMeta(String role) => switch (role) {
      'admin' => (AppColors.error, 'Admin'),
      'expert' => (AppColors.primary, 'Expert'),
      'manager' => (AppColors.tertiary, 'Manager'),
      'worker' => (AppColors.secondary, 'Worker'),
      _ => (AppColors.outline, 'Farmer'),
    };

const adminRoleOptions = <(String, String)>[
  ('farmer', 'Farmer'),
  ('expert', 'Agricultural Expert'),
  ('admin', 'Super Admin'),
  ('manager', 'Manager'),
  ('worker', 'Worker'),
];

/// Admin → Users & Roles. Search, filter by role, and open a user to manage
/// their role, credits and suspension.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _roleFilter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users =
        ref.watch(adminUsersProvider((search: _search, role: _roleFilter)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Users & Roles'),
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search name, email or phone…',
                prefixIcon: const Icon(Symbols.search),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final f in const [
                  ('', 'All'),
                  ('farmer', 'Farmers'),
                  ('expert', 'Experts'),
                  ('admin', 'Admins'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _roleFilter == f.$1,
                      onSelected: (_) => setState(() => _roleFilter = f.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminUsersProvider),
              child: users.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _error(e.toString()),
                data: (list) => list.isEmpty
                    ? _empty()
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => _UserTile(user: list[i]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => ListView(children: [
        const SizedBox(height: 120),
        const Icon(Symbols.person_search, size: 52, color: AppColors.outline),
        const SizedBox(height: 12),
        Center(child: Text('No users found', style: AppText.labelMd)),
      ]);

  Widget _error(String e) {
    final denied = e.contains('42501') || e.toLowerCase().contains('authorized');
    return ListView(children: [
      const SizedBox(height: 120),
      Center(
          child: Text(denied ? 'Admins only' : 'Could not load users',
              style: AppText.headlineSm)),
      if (!denied)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(e, textAlign: TextAlign.center, style: AppText.labelSm),
        ),
    ]);
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final (color, label) = roleMeta(user.role);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text(
          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
          style: AppText.labelMd.copyWith(color: color),
        ),
      ),
      title: Row(
        children: [
          Flexible(
              child: Text(user.displayName,
                  style: AppText.labelMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          if (user.isPremium) ...[
            const SizedBox(width: 6),
            const Icon(Symbols.workspace_premium,
                size: 16, color: AppColors.tertiary),
          ],
          if (user.suspended) ...[
            const SizedBox(width: 6),
            _pill('Suspended', AppColors.error),
          ],
        ],
      ),
      subtitle: Text(user.email ?? user.phone ?? '—',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.labelSm),
      trailing: _pill(label, color),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AdminUserDetailScreen(userId: user.id),
      )),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: AppText.labelSm.copyWith(color: color, fontWeight: FontWeight.w600)),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/auth_repository.dart';

/// Shown in place of the app when the signed-in account has been suspended by
/// an admin. It's a full-screen block: the only action is to sign out. The
/// server still enforces per-row RLS, but this stops a suspended user from
/// using the app UI at all.
class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Symbols.block, size: 44, color: AppColors.error),
              ),
              const SizedBox(height: 24),
              Text('Account suspended',
                  style: AppText.headlineMd, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Your account has been suspended by an administrator. '
                'If you believe this is a mistake, please contact support.',
                style: AppText.bodyMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                icon: const Icon(Symbols.logout),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(200, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

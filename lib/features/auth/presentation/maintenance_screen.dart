import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/public_flags.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/auth_repository.dart';

/// Shown to non-admins while maintenance_mode is on. Admins bypass this so they
/// can still reach the dashboard and turn maintenance off.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

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
                  color: AppColors.tertiaryContainer.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Symbols.construction,
                    size: 44, color: AppColors.tertiary),
              ),
              const SizedBox(height: 24),
              Text('Under maintenance',
                  style: AppText.headlineMd, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Somali Farm is temporarily down for maintenance. '
                'Please check back shortly.',
                style: AppText.bodyMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => ref.invalidate(publicFlagsProvider),
                icon: const Icon(Symbols.refresh),
                label: const Text('Try again'),
                style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

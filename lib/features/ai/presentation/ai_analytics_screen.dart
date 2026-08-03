import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/farm.dart';
import '../../profile/data/profile_repository.dart';
import '../data/ai_analytics_repository.dart';

/// AI usage analytics + per-crop health scores.
class AiAnalyticsScreen extends ConsumerWidget {
  const AiAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(myFarmsProvider);
    final farm =
        farms.valueOrNull?.isNotEmpty == true ? farms.value!.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(ref.watch(stringsProvider).aiAnalytics)),
      body: farm == null
          ? const Center(child: Text('Create a farm to see analytics.'))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(aiAnalyticsProvider(farm.id));
                ref.invalidate(cropHealthProvider(farm.id));
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Text('AI usage', style: AppText.headlineSm),
                  const SizedBox(height: 12),
                  _UsageSection(farm: farm),
                  const SizedBox(height: 28),
                  Text('Crop health scores', style: AppText.headlineSm),
                  const SizedBox(height: 4),
                  Text(
                    'Derived from active diseases and recent AI diagnoses.',
                    style: AppText.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  _CropHealthSection(farm: farm),
                ],
              ),
            ),
    );
  }
}

class _UsageSection extends ConsumerWidget {
  const _UsageSection({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(aiAnalyticsProvider(farm.id));
    return analytics.when(
      loading: () => const _Loading(height: 120),
      error: (e, _) => _Error('$e'),
      data: (a) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Symbols.psychiatry,
                  color: AppColors.primary,
                  value: '${a.diagnosisCount}',
                  label: 'Plant diagnoses',
                  sub: a.diagnosisThisMonth > 0
                      ? '+${a.diagnosisThisMonth} this month'
                      : 'this month: 0',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Symbols.smart_toy,
                  color: AppColors.secondary,
                  value: '${a.chatCount}',
                  label: 'Assistant questions',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Symbols.target,
                  color: AppColors.tertiary,
                  value: a.diagnosisCount == 0
                      ? '—'
                      : '${a.avgConfidence.round()}%',
                  label: 'Avg confidence',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Symbols.coronavirus,
                  color: AppColors.error,
                  value: a.topDisease ?? '—',
                  label: 'Most common disease',
                  small: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatTile(
            icon: Symbols.eco,
            color: AppColors.primary,
            value: a.topCrop ?? '—',
            label: 'Most scanned crop',
            small: true,
            wide: true,
          ),
        ],
      ),
    );
  }
}

class _CropHealthSection extends ConsumerWidget {
  const _CropHealthSection({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(cropHealthProvider(farm.id));
    return health.when(
      loading: () => const _Loading(height: 100),
      error: (e, _) => _Error('$e'),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyCard(
            'No active crops to score yet. Add crops and log any diseases or '
            'run the Plant Doctor to build health scores.',
          );
        }
        return Column(children: [for (final c in list) _CropHealthTile(c)]);
      },
    );
  }
}

class _CropHealthTile extends StatelessWidget {
  const _CropHealthTile(this.crop);
  final CropHealth crop;

  Color get _color => switch (crop.band) {
        'good' => AppColors.primary,
        'watch' => AppColors.tertiary,
        _ => AppColors.error,
      };

  String get _label => switch (crop.band) {
        'good' => 'Healthy',
        'watch' => 'Watch',
        _ => 'At risk',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(crop.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyMd
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
              Text('${crop.score}',
                  style: AppText.headlineSm.copyWith(color: _color)),
              Text(' /100',
                  style: AppText.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: crop.score / 100,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(_color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_label,
                    style: AppText.labelSm.copyWith(
                        color: _color, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(
                crop.activeIssues == 0
                    ? 'No active issues'
                    : '${crop.activeIssues} active issue${crop.activeIssues == 1 ? '' : 's'}',
                style: AppText.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.sub,
    this.small = false,
    this.wide = false,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String? sub;
  final bool small;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (small ? AppText.bodyMd : AppText.headlineSm)
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: AppText.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant)),
          if (sub != null)
            Text(sub!,
                style: AppText.labelSm.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: height, child: const Center(child: CircularProgressIndicator()));
}

class _Error extends StatelessWidget {
  const _Error(this.message);
  final String message;
  @override
  Widget build(BuildContext context) =>
      _EmptyCard('Could not load. $message');
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Text(message,
            textAlign: TextAlign.center,
            style:
                AppText.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
      );
}

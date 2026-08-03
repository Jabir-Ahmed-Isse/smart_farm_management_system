import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/ai_insight.dart';
import '../../../models/farm.dart';
import '../../profile/data/profile_repository.dart';
import '../data/ai_service.dart';
import '../data/insights_repository.dart';

/// AI Insights — auto-generated, farm-specific insight cards.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  bool _generating = false;

  String get _language =>
      ui.PlatformDispatcher.instance.locale.languageCode == 'so' ? 'so' : 'en';

  @override
  Widget build(BuildContext context) {
    final farms = ref.watch(myFarmsProvider);
    final farm =
        farms.valueOrNull?.isNotEmpty == true ? farms.value!.first : null;
    final credit = ref.watch(insightCreditProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Insights'),
        actions: [
          if (credit != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  credit.unlimited
                      ? 'Unlimited'
                      : '${credit.remaining} left',
                  style: AppText.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
      body: farm == null
          ? const Center(child: Text('Create a farm to get insights.'))
          : _Body(
              farm: farm,
              generating: _generating,
              onGenerate: () => _generate(farm),
            ),
    );
  }

  Future<void> _generate(Farm farm) async {
    setState(() => _generating = true);
    final outcome = await ref
        .read(insightsRepositoryProvider)
        .generate(farmId: farm.id, language: _language);
    if (!mounted) return;
    setState(() => _generating = false);

    switch (outcome) {
      case InsightsOk():
        ref.invalidate(insightsForFarmProvider(farm.id));
        ref.invalidate(insightCreditProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insights updated')),
        );
      case InsightsCreditLimit():
        _snack(
            "You've used all your free insights this month. They reset next month.");
      case InsightsError(:final message):
        _snack(message);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.farm,
    required this.generating,
    required this.onGenerate,
  });
  final Farm farm;
  final bool generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsForFarmProvider(farm.id));

    return Column(
      children: [
        if (generating) const LinearProgressIndicator(minHeight: 3),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'AI-generated highlights from your farm data.',
                  style: AppText.labelMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: generating ? null : onGenerate,
                icon: const Icon(Symbols.auto_awesome, size: 18),
                label: Text(
                  insights.valueOrNull?.isNotEmpty == true
                      ? 'Refresh'
                      : 'Generate',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: insights.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load insights.\n$e',
                    textAlign: TextAlign.center,
                    style: AppText.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ),
            ),
            data: (list) => list.isEmpty
                ? _EmptyState(generating: generating, onGenerate: onGenerate)
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(insightsForFarmProvider(farm.id)),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _InsightCard(
                        insight: list[i],
                        onDismiss: () async {
                          await ref
                              .read(insightsRepositoryProvider)
                              .dismiss(list[i].id);
                          ref.invalidate(insightsForFarmProvider(farm.id));
                        },
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.generating, required this.onGenerate});
  final bool generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.auto_awesome, size: 56, color: AppColors.outline),
            const SizedBox(height: 12),
            Text('No insights yet',
                style: AppText.headlineSm, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Generate AI insights about your revenue, stock, crops and '
              'diseases — based on the data you\'ve logged.',
              textAlign: TextAlign.center,
              style:
                  AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: generating ? null : onGenerate,
              icon: const Icon(Symbols.auto_awesome, size: 18),
              label: const Text('Generate insights'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, required this.onDismiss});
  final AiInsight insight;
  final VoidCallback onDismiss;

  (Color, IconData) get _style {
    final color = switch (insight.severity) {
      'critical' => AppColors.error,
      'warning' => AppColors.tertiary,
      'positive' => AppColors.primary,
      _ => AppColors.secondary,
    };
    final icon = switch (insight.kind) {
      'revenue' => Symbols.trending_up,
      'expense' => Symbols.payments,
      'inventory' => Symbols.inventory_2,
      'disease' => Symbols.coronavirus,
      'harvest' => Symbols.agriculture,
      'crop' => Symbols.eco,
      'weather' => Symbols.rainy,
      _ => Symbols.lightbulb,
    };
    return (color, icon);
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _style;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 5,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        shape: BoxShape.circle),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(insight.title,
                            style: AppText.bodyMd
                                .copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(insight.body,
                            style: AppText.bodyMd
                                .copyWith(color: AppColors.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        Text(DateFormat('d MMM').format(insight.createdAt),
                            style: AppText.labelSm
                                .copyWith(color: AppColors.outline)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Symbols.close, size: 18),
                    color: AppColors.onSurfaceVariant,
                    tooltip: 'Dismiss',
                    onPressed: onDismiss,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

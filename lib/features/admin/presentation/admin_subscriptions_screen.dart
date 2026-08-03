import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/subscription_plan.dart';
import '../data/subscription_repository.dart';
import 'admin_plan_requests_screen.dart';

/// Admin → Subscriptions & AI Credits. Manage the plans and the monthly AI
/// limits they grant (which the AI Edge Function reads live). Per-user plan
/// assignment + credit history live on the user detail screen.
class AdminSubscriptionsScreen extends ConsumerWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(subscriptionPlansProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Subscriptions & Credits'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Symbols.approval),
            tooltip: 'Upgrade requests',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AdminPlanRequestsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(subscriptionPlansProvider),
        child: plans.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Text(e.toString().contains('42501') ? 'Admins only' : 'Could not load',
                  style: AppText.headlineSm)),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text('Plans define the monthly AI credits each tier grants. '
                  'Changes apply immediately to every user on the plan.',
                  style: AppText.labelSm),
              const SizedBox(height: 16),
              for (final p in list) _PlanCard(plan: p),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});
  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
            Text(plan.name, style: AppText.headlineSm),
            const SizedBox(width: 8),
            Text(plan.price == 0 ? 'Free' : '${formatMoney(plan.price)}/mo',
                style: AppText.labelMd.copyWith(color: AppColors.tertiary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${plan.userCount} users', style: AppText.labelSm),
            ),
          ]),
          if (plan.features != null) ...[
            const SizedBox(height: 4),
            Text(plan.features!, style: AppText.labelSm),
          ],
          const SizedBox(height: 12),
          Row(children: [
            _limit('Diagnoses', plan.diagnosisLimit),
            _limit('Chats', plan.chatLimit),
            _limit('Insights', plan.insightLimit),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Symbols.edit, size: 18),
              label: const Text('Edit limits'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _limit(String label, int v) => Expanded(
        child: Column(children: [
          Text(SubscriptionPlan.limitLabel(v),
              style: AppText.labelMd.copyWith(color: AppColors.primary)),
          Text(label, style: AppText.labelSm),
        ]),
      );

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<SubscriptionPlan>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditPlanSheet(plan: plan),
    );
    if (result == null) return;
    try {
      await ref.read(subscriptionRepositoryProvider).updatePlan(result);
      ref.invalidate(subscriptionPlansProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${plan.name} updated')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}

class _EditPlanSheet extends StatefulWidget {
  const _EditPlanSheet({required this.plan});
  final SubscriptionPlan plan;

  @override
  State<_EditPlanSheet> createState() => _EditPlanSheetState();
}

class _EditPlanSheetState extends State<_EditPlanSheet> {
  late final _diag = TextEditingController(text: _v(widget.plan.diagnosisLimit));
  late final _chat = TextEditingController(text: _v(widget.plan.chatLimit));
  late final _insight = TextEditingController(text: _v(widget.plan.insightLimit));
  late final _price = TextEditingController(text: widget.plan.price.toString());
  late final _features = TextEditingController(text: widget.plan.features ?? '');
  late bool _unlimited = widget.plan.diagnosisLimit < 0;

  static String _v(int v) => v < 0 ? '' : '$v';

  @override
  void dispose() {
    for (final c in [_diag, _chat, _insight, _price, _features]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit ${widget.plan.name}', style: AppText.headlineSm),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Unlimited AI'),
            value: _unlimited,
            onChanged: (v) => setState(() => _unlimited = v),
          ),
          if (!_unlimited)
            Row(children: [
              Expanded(child: _num(_diag, 'Diagnoses/mo')),
              const SizedBox(width: 10),
              Expanded(child: _num(_chat, 'Chats/mo')),
              const SizedBox(width: 10),
              Expanded(child: _num(_insight, 'Insights/mo')),
            ]),
          const SizedBox(height: 12),
          _num(_price, 'Price / month'),
          const SizedBox(height: 12),
          TextField(
            controller: _features,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              int lim(TextEditingController c) =>
                  _unlimited ? -1 : (int.tryParse(c.text.trim()) ?? 0);
              Navigator.pop(
                context,
                widget.plan.copyWith(
                  diagnosisLimit: lim(_diag),
                  chatLimit: lim(_chat),
                  insightLimit: lim(_insight),
                  price: num.tryParse(_price.text.trim()) ?? 0,
                  features: _features.text.trim(),
                ),
              );
            },
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('Save plan'),
          ),
        ],
      ),
    );
  }

  Widget _num(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );
}

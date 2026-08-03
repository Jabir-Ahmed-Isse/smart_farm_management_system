import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/plan_request.dart';
import '../../../models/subscription_plan.dart';
import '../../admin/data/subscription_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/billing_repository.dart';

/// Farmer self-serve plan upgrade. Plans + prices come from subscription_plans;
/// payment is by mobile money (number/instructions are admin-editable) and the
/// farmer submits a transaction reference that an admin verifies.
class UpgradeScreen extends ConsumerWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(subscriptionPlansProvider);
    final current = ref.watch(myProfileProvider).valueOrNull?.aiPlan ?? 'free';
    final pending = ref.watch(myPendingRequestProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Plans & Upgrade'),
        backgroundColor: AppColors.background,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(subscriptionPlansProvider);
          ref.invalidate(myPendingRequestProvider);
        },
        child: plans.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
              child: Text('Could not load plans', style: AppText.headlineSm)),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (pending != null) _PendingBanner(request: pending),
              Text('You are on the ${_name(list, current)} plan.',
                  style: AppText.labelMd),
              const SizedBox(height: 4),
              Text('Upgrade for more AI diagnoses, chats and insights.',
                  style: AppText.labelSm),
              const SizedBox(height: 16),
              for (final p in list)
                _PlanCard(
                  plan: p,
                  isCurrent: p.code == current,
                  locked: pending != null,
                  onChoose: () => _choose(context, ref, p),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _name(List<SubscriptionPlan> list, String code) =>
      list.firstWhere((p) => p.code == code,
          orElse: () => SubscriptionPlan(
              code: code,
              name: code,
              diagnosisLimit: 0,
              chatLimit: 0,
              insightLimit: 0,
              price: 0)).name;

  Future<void> _choose(
      BuildContext context, WidgetRef ref, SubscriptionPlan plan) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PaymentSheet(plan: plan),
    );
    if (ok == true) {
      ref.invalidate(myPendingRequestProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Request submitted — an admin will verify it.')));
      }
    }
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.request});
  final PlanRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const Icon(Symbols.hourglass_top, color: AppColors.tertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upgrade pending', style: AppText.labelMd),
              Text(
                  'Your request for the ${request.plan} plan is awaiting '
                  'verification. You’ll be moved automatically once approved.',
                  style: AppText.labelSm),
            ],
          ),
        ),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.locked,
    required this.onChoose,
  });
  final SubscriptionPlan plan;
  final bool isCurrent;
  final bool locked;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isCurrent ? AppColors.primary : AppColors.outlineVariant,
            width: isCurrent ? 2 : 1),
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
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('Current',
                    style: AppText.labelSm.copyWith(color: AppColors.onPrimary)),
              ),
          ]),
          if (plan.features != null && plan.features!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(plan.features!, style: AppText.labelSm),
          ],
          const SizedBox(height: 12),
          Row(children: [
            _limit('Diagnoses', plan.diagnosisLimit),
            _limit('Chats', plan.chatLimit),
            _limit('Insights', plan.insightLimit),
          ]),
          if (!isCurrent) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: locked ? null : onChoose,
                child: Text(plan.price == 0 ? 'Switch to Free' : 'Upgrade'),
              ),
            ),
          ],
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
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.plan});
  final SubscriptionPlan plan;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _reference = TextEditingController();
  String _method = 'evc';
  bool _sending = false;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await ref.read(billingRepositoryProvider).requestUpgrade(
            plan: widget.plan.code,
            method: _method,
            reference: _reference.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        final msg = e.toString().contains('pending')
            ? 'You already have a pending request.'
            : 'Could not submit: $e';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(billingInfoProvider);
    final paid = widget.plan.price > 0;
    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.plan.name} — ${paid ? '${formatMoney(widget.plan.price)}/mo' : 'Free'}',
                style: AppText.headlineSm),
            const SizedBox(height: 12),
            if (paid)
              info.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (b) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (b.number.isNotEmpty)
                        Row(children: [
                          const Icon(Symbols.smartphone,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Pay to: ${b.number}',
                                style: AppText.bodyMd
                                    .copyWith(fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            icon: const Icon(Symbols.content_copy, size: 18),
                            tooltip: 'Copy',
                            onPressed: () => Clipboard.setData(
                                ClipboardData(text: b.number)),
                          ),
                        ]),
                      if (b.instructions.isNotEmpty)
                        Text(b.instructions, style: AppText.labelSm),
                    ],
                  ),
                ),
              ),
            if (paid) const SizedBox(height: 12),
            if (paid) ...[
              Text('Payment method', style: AppText.labelSm),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in paymentMethods)
                    ChoiceChip(
                      label: Text(m.$2),
                      selected: _method == m.$1,
                      onSelected: (_) => setState(() => _method = m.$1),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(
                    labelText: 'Transaction reference',
                    hintText: 'e.g. the SMS confirmation code',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
            ] else
              Text('Request to switch to the Free plan. An admin will confirm.',
                  style: AppText.labelSm),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _sending ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(_sending ? 'Submitting…' : 'Submit request'),
            ),
            const SizedBox(height: 4),
            Text('No card details are stored. You pay via mobile money and we '
                'verify your reference.',
                style: AppText.labelSm.copyWith(color: AppColors.outline),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

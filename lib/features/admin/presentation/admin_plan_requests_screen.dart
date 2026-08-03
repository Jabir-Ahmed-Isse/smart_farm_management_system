import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/time_ago.dart';
import '../../../models/plan_request.dart';
import '../../billing/data/billing_repository.dart';

/// Admin → verify mobile-money upgrade requests and activate plans.
class AdminPlanRequestsScreen extends ConsumerStatefulWidget {
  const AdminPlanRequestsScreen({super.key});

  @override
  ConsumerState<AdminPlanRequestsScreen> createState() =>
      _AdminPlanRequestsScreenState();
}

class _AdminPlanRequestsScreenState
    extends ConsumerState<AdminPlanRequestsScreen> {
  String? _filter = 'pending';

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(adminPlanRequestsProvider(_filter));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Upgrade Requests'),
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _chip('Pending', 'pending'),
                _chip('Approved', 'approved'),
                _chip('Rejected', 'rejected'),
                _chip('All', null),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(adminPlanRequestsProvider(_filter)),
              child: list.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text(e.toString().contains('42501')
                        ? 'Admins only'
                        : 'Could not load')),
                data: (items) => items.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 120),
                        Center(
                            child: Text('Nothing here', style: AppText.headlineSm)),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _RequestCard(
                          req: items[i],
                          onApprove: () => _review(items[i], true),
                          onReject: () => _review(items[i], false),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? value) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );

  Future<void> _review(PlanRequest req, bool approve) async {
    if (!approve) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject request?'),
          content: Text('Reject ${req.userName ?? req.userEmail ?? 'this user'}'
              '’s request for the ${req.plan} plan?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reject')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await ref
          .read(billingRepositoryProvider)
          .adminReview(id: req.id, approve: approve);
      ref.invalidate(adminPlanRequestsProvider(_filter));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(approve
                ? 'Approved — ${req.plan} plan activated.'
                : 'Request rejected.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.req,
    required this.onApprove,
    required this.onReject,
  });
  final PlanRequest req;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final pending = req.status == 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text('${req.plan.toUpperCase()} · ${formatMoney(req.amount)}',
                    style: AppText.labelMd)),
            if (!pending)
              Text(req.status,
                  style: AppText.labelSm.copyWith(
                      color: req.status == 'approved'
                          ? AppColors.tertiary
                          : AppColors.error)),
          ]),
          const SizedBox(height: 4),
          Text('${req.userName ?? req.userEmail ?? 'User'} · ${timeAgo(req.createdAt)}',
              style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text('Paid via ${paymentMethodLabel(req.method)}'
              '${req.reference != null ? '  ·  Ref: ${req.reference}' : ''}',
              style: AppText.bodyMd),
          if (pending) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onApprove,
                  child: const Text('Approve'),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

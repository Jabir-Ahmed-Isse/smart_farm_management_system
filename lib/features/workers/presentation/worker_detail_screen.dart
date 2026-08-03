import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/farm.dart';
import '../../../models/worker.dart';
import '../../../models/worker_attendance.dart';
import '../../../models/worker_payment.dart';
import '../data/worker_repository.dart';
import 'worker_form_sheet.dart';

const _attendanceStatuses = <(String, String)>[
  ('present', 'Present'),
  ('half_day', 'Half day'),
  ('absent', 'Absent'),
  ('leave', 'Leave'),
];

const _paymentMethods = <(String, String)>[
  ('cash', 'Cash'),
  ('mobile_money', 'Mobile money'),
  ('bank_transfer', 'Bank transfer'),
  ('credit', 'Credit'),
];

String _statusLabel(String key) =>
    _attendanceStatuses.firstWhere((s) => s.$1 == key, orElse: () => (key, key)).$2;

Color _statusColor(String key) => switch (key) {
      'present' => AppColors.primary,
      'half_day' => AppColors.tertiary,
      'absent' => AppColors.error,
      _ => AppColors.outline,
    };

String _methodLabel(String key) =>
    _paymentMethods.firstWhere((m) => m.$1 == key, orElse: () => (key, key)).$2;

/// One worker: their details, attendance log and pay history.
class WorkerDetailScreen extends ConsumerStatefulWidget {
  const WorkerDetailScreen({
    super.key,
    required this.farm,
    required this.worker,
  });

  final Farm farm;
  final Worker worker;

  @override
  ConsumerState<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends ConsumerState<WorkerDetailScreen> {
  late Worker _worker;

  @override
  void initState() {
    super.initState();
    _worker = widget.worker;
  }

  @override
  Widget build(BuildContext context) {
    final attendance = ref.watch(workerAttendanceProvider(_worker.id));
    final payments = ref.watch(workerPaymentsProvider(_worker.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_worker.fullName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'edit' ? _edit() : null,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit worker')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Header(worker: _worker),
          const SizedBox(height: 20),
          _EarningsCard(
            worker: _worker,
            attendance: attendance.valueOrNull ?? const [],
            payments: payments.valueOrNull ?? const [],
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Attendance',
            actionLabel: 'Mark a day',
            onAction: () => _markAttendance(),
          ),
          const SizedBox(height: 8),
          attendance.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _ErrorText('Could not load attendance.\n$e'),
            data: (list) => list.isEmpty
                ? const _EmptyText('No days recorded yet.')
                : Column(
                    children: [
                      for (final day in list)
                        _AttendanceTile(
                          entry: day,
                          onEdit: () => _markAttendance(existing: day),
                          onDelete: () => _deleteAttendance(day),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Payments',
            actionLabel: 'Record pay',
            onAction: () => _addPayment(),
          ),
          const SizedBox(height: 8),
          payments.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _ErrorText('Could not load payments.\n$e'),
            data: (list) => list.isEmpty
                ? const _EmptyText('No payments recorded yet.')
                : Column(
                    children: [
                      for (final payment in list)
                        _PaymentTile(
                          payment: payment,
                          onDelete: () => _deletePayment(payment),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit() async {
    await showWorkerSheet(context, widget.farm, existing: _worker);
    final list = await ref.read(workersForFarmProvider(widget.farm.id).future);
    final updated = list.where((w) => w.id == _worker.id).firstOrNull;
    if (updated != null && mounted) setState(() => _worker = updated);
  }

  Future<void> _markAttendance({WorkerAttendance? existing}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AttendanceSheet(
        farm: widget.farm,
        worker: _worker,
        existing: existing,
      ),
    );
    if (result == true) ref.invalidate(workerAttendanceProvider(_worker.id));
  }

  Future<void> _deleteAttendance(WorkerAttendance day) async {
    final ok = await confirmDelete(context,
        title: 'Delete record?',
        message: 'Remove ${DateFormat('d MMM yyyy').format(day.date)}?');
    if (ok != true) return;
    try {
      await ref.read(workerRepositoryProvider).deleteAttendance(day.id);
      ref.invalidate(workerAttendanceProvider(_worker.id));
    } catch (_) {
      _snack('Could not delete the record.');
    }
  }

  Future<void> _addPayment() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PaymentSheet(farm: widget.farm, worker: _worker),
    );
    if (result == true) ref.invalidate(workerPaymentsProvider(_worker.id));
  }

  Future<void> _deletePayment(WorkerPayment payment) async {
    final ok = await confirmDelete(context,
        title: 'Delete payment?',
        message: 'Remove the ${formatMoney(payment.amount)} payment?');
    if (ok != true) return;
    try {
      await ref.read(workerRepositoryProvider).deletePayment(payment.id);
      ref.invalidate(workerPaymentsProvider(_worker.id));
    } catch (_) {
      _snack('Could not delete the payment.');
    }
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.worker});
  final Worker worker;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (worker.position != null) worker.position!,
      if (worker.phone != null) worker.phone!,
      if (worker.hireDate != null)
        'since ${DateFormat('MMM yyyy').format(worker.hireDate!)}',
      if (!worker.active) 'not working',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker.fullName, style: AppText.headlineSm),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(meta.join(' · '),
                      style: AppText.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          if (worker.dailyWage != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatMoney(worker.dailyWage!),
                    style: AppText.bodyMd
                        .copyWith(fontWeight: FontWeight.w700)),
                Text('per day',
                    style: AppText.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Days worked vs money paid — the balance a farmer actually asks about.
class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.worker,
    required this.attendance,
    required this.payments,
  });

  final Worker worker;
  final List<WorkerAttendance> attendance;
  final List<WorkerPayment> payments;

  @override
  Widget build(BuildContext context) {
    final daysWorked =
        attendance.fold<double>(0, (sum, a) => sum + a.payFraction);
    final earned = (worker.dailyWage ?? 0) * daysWorked;
    final paid = payments.fold<num>(0, (sum, p) => sum + p.amount);
    final owed = earned - paid;

    return Container(
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
                child: _Metric(
                  label: 'Days worked',
                  value: _days(daysWorked),
                  color: AppColors.onSurface,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Paid',
                  value: formatMoney(paid),
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          if (worker.dailyWage != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Earned (days × wage)',
                    value: formatMoney(earned),
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: owed >= 0 ? 'Outstanding' : 'Overpaid',
                    value: formatMoney(owed.abs()),
                    color: owed > 0 ? AppColors.error : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Based on every attendance record shown below '
              '(half days count as ½).',
              style:
                  AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text('Set a daily wage on this worker to see what they are owed.',
                style: AppText.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  static String _days(double d) =>
      d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(1);
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppText.headlineSm.copyWith(color: color)),
        Text(label,
            style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppText.headlineSm),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Symbols.add, size: 18),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text,
          style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text,
          style: AppText.bodyMd.copyWith(color: AppColors.error)),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkerAttendance entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(entry.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('EEE d MMM yyyy').format(entry.date),
                    style: AppText.bodyMd
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(
                  [
                    _statusLabel(entry.status),
                    if (entry.hours != null) '${entry.hours}h',
                    if (entry.notes != null) entry.notes!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Symbols.more_vert,
                color: AppColors.onSurfaceVariant),
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.onDelete});

  final WorkerPayment payment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      DateFormat('d MMM yyyy').format(payment.date),
      if (payment.method != null) _methodLabel(payment.method!),
      if (payment.periodStart != null && payment.periodEnd != null)
        '${DateFormat('d MMM').format(payment.periodStart!)}'
            ' – ${DateFormat('d MMM').format(payment.periodEnd!)}',
      if (payment.notes != null) payment.notes!,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatMoney(payment.amount),
                    style: AppText.bodyMd
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(meta.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.delete, size: 20),
            color: AppColors.onSurfaceVariant,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Mark one day's attendance. Pops true when saved.
class _AttendanceSheet extends ConsumerStatefulWidget {
  const _AttendanceSheet({
    required this.farm,
    required this.worker,
    this.existing,
  });

  final Farm farm;
  final Worker worker;
  final WorkerAttendance? existing;

  @override
  ConsumerState<_AttendanceSheet> createState() => _AttendanceSheetState();
}

class _AttendanceSheetState extends ConsumerState<_AttendanceSheet> {
  late DateTime _date;
  late String _status;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _notesCtrl;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.existing?.date ?? DateTime.now();
    _status = widget.existing?.status ?? 'present';
    _hoursCtrl =
        TextEditingController(text: widget.existing?.hours?.toString() ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _notesCtrl.dispose();
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.worker.fullName} — attendance',
                style: AppText.headlineSm),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Row(
                  children: [
                    const Icon(Symbols.event,
                        size: 20, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(DateFormat('EEE d MMM yyyy').format(_date),
                        style: AppText.bodyMd),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final s in _attendanceStatuses)
                  ChoiceChip(
                    label: Text(s.$2),
                    selected: _status == s.$1,
                    onSelected: (_) => setState(() => _status = s.$1),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hoursCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              decoration:
                  const InputDecoration(labelText: 'Hours (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Notes (optional)'),
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
                  : const Text('Save day'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(workerRepositoryProvider).markAttendance(
            farmId: widget.farm.id,
            workerId: widget.worker.id,
            date: _date,
            status: _status,
            hours: num.tryParse(_hoursCtrl.text.trim()),
            notes: _notesCtrl.text,
          );
      nav.pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the day.';
        });
      }
    }
  }
}

/// Record a payment to a worker. Pops true when saved.
class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.farm, required this.worker});

  final Farm farm;
  final Worker worker;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  DateTimeRange? _period;
  String? _method = 'cash';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pay ${widget.worker.fullName}', style: AppText.headlineSm),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              decoration: const InputDecoration(
                  labelText: 'Amount', prefixText: '\$ '),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _method,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Method'),
              items: [
                for (final m in _paymentMethods)
                  DropdownMenuItem<String?>(value: m.$1, child: Text(m.$2)),
              ],
              onChanged: (v) => setState(() => _method = v),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Row(
                  children: [
                    const Icon(Symbols.event,
                        size: 20, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text('Paid ${DateFormat('d MMM yyyy').format(_date)}',
                        style: AppText.bodyMd),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDateRange: _period,
                );
                if (picked != null) setState(() => _period = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Row(
                  children: [
                    const Icon(Symbols.date_range,
                        size: 20, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _period == null
                            ? 'Period covered (optional)'
                            : '${DateFormat('d MMM').format(_period!.start)}'
                                ' – ${DateFormat('d MMM yyyy').format(_period!.end)}',
                        style: AppText.bodyMd.copyWith(
                            color: _period == null
                                ? AppColors.onSurfaceVariant
                                : AppColors.onSurface),
                      ),
                    ),
                    if (_period != null)
                      IconButton(
                        icon: const Icon(Symbols.close, size: 18),
                        onPressed: () => setState(() => _period = null),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Notes (optional)'),
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
                  : const Text('Record payment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final amount = num.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount.');
      return;
    }
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(workerRepositoryProvider).addPayment(
            farmId: widget.farm.id,
            workerId: widget.worker.id,
            amount: amount,
            date: _date,
            periodStart: _period?.start,
            periodEnd: _period?.end,
            method: _method,
            notes: _notesCtrl.text,
          );
      nav.pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the payment.';
        });
      }
    }
  }
}

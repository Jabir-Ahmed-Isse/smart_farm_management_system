import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/farm.dart';
import '../../../models/worker.dart';
import '../data/worker_repository.dart';

/// Add / edit a worker. Returns the created worker when adding (so callers
/// like the task assignee dropdown can select it), null on cancel or edit.
Future<Worker?> showWorkerSheet(
  BuildContext context,
  Farm farm, {
  Worker? existing,
}) {
  return showModalBottomSheet<Worker>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _WorkerSheet(farm: farm, existing: existing),
  );
}

class _WorkerSheet extends ConsumerStatefulWidget {
  const _WorkerSheet({required this.farm, this.existing});

  final Farm farm;
  final Worker? existing;

  @override
  ConsumerState<_WorkerSheet> createState() => _WorkerSheetState();
}

class _WorkerSheetState extends ConsumerState<_WorkerSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _positionCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _wageCtrl;
  DateTime? _hireDate;
  late bool _active;
  String? _error;
  bool _saving = false;

  Worker? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _existing?.fullName ?? '');
    _positionCtrl = TextEditingController(text: _existing?.position ?? '');
    _phoneCtrl = TextEditingController(text: _existing?.phone ?? '');
    _wageCtrl =
        TextEditingController(text: _existing?.dailyWage?.toString() ?? '');
    _hireDate = _existing?.hireDate;
    _active = _existing?.active ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _positionCtrl.dispose();
    _phoneCtrl.dispose();
    _wageCtrl.dispose();
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
            Text(_existing == null ? 'Add worker' : 'Edit worker',
                style: AppText.headlineSm),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: _existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _positionCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  hintText: 'Role (e.g. Foreman) — optional'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _wageCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    decoration: const InputDecoration(
                        labelText: 'Daily wage', prefixText: '\$ '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _hireDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _hireDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Row(
                  children: [
                    const Icon(Symbols.event,
                        size: 20, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      _hireDate == null
                          ? 'Hire date (optional)'
                          : DateFormat('d MMM yyyy').format(_hireDate!),
                      style: AppText.bodyMd.copyWith(
                          color: _hireDate == null
                              ? AppColors.onSurfaceVariant
                              : AppColors.onSurface),
                    ),
                    const Spacer(),
                    if (_hireDate != null)
                      IconButton(
                        icon: const Icon(Symbols.close, size: 18),
                        onPressed: () => setState(() => _hireDate = null),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              activeThumbColor: AppColors.primary,
              title: Text('Currently working', style: AppText.bodyMd),
              subtitle: Text(
                _active
                    ? 'Shows in the roster and task assignee list'
                    : 'Kept on record, hidden from active lists',
                style:
                    AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant),
              ),
              onChanged: (v) => setState(() => _active = v),
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
                  : Text(_existing == null ? 'Add worker' : 'Save changes'),
            ),
          ],
        ),
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
      final repo = ref.read(workerRepositoryProvider);
      final wage = num.tryParse(_wageCtrl.text.trim());
      Worker? created;
      if (_existing == null) {
        created = await repo.createWorker(
          farmId: widget.farm.id,
          fullName: _nameCtrl.text.trim(),
          position: _positionCtrl.text,
          phone: _phoneCtrl.text,
          dailyWage: wage,
          hireDate: _hireDate,
          active: _active,
        );
      } else {
        await repo.updateWorker(
          id: _existing!.id,
          fullName: _nameCtrl.text.trim(),
          position: _positionCtrl.text,
          phone: _phoneCtrl.text,
          dailyWage: wage,
          hireDate: _hireDate,
          active: _active,
        );
      }
      ref.invalidate(workersForFarmProvider(widget.farm.id));
      nav.pop(created);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the worker.';
        });
      }
    }
  }
}

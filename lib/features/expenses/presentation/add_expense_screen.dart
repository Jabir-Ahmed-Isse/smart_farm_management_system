import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../models/crop.dart';
import '../../../models/expense.dart';
import '../../../models/expense_category.dart';
import '../../../models/farm.dart';
import '../../../models/plot.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/expense_repository.dart';

/// The four `payment_method` enum values with display labels.
const _paymentMethods = <(String, String)>[
  ('cash', 'Cash'),
  ('mobile_money', 'Mobile money'),
  ('bank_transfer', 'Bank transfer'),
  ('credit', 'Credit'),
];

/// Full-screen Expense form. Pass [existing] to edit instead of create.
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key, this.existing});
  final Expense? existing;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  // Object selections + "touched" flags so prefilled values resolve once the
  // async lists load, then defer to the user's choice after they interact.
  Farm? _farm;
  bool _farmTouched = false;
  ExpenseCategory? _category;
  bool _categoryTouched = false;
  Plot? _plot;
  bool _plotTouched = false;
  Crop? _crop;
  bool _cropTouched = false;

  DateTime _date = DateTime.now();
  String? _paymentMethod;

  Uint8List? _receiptBytes;
  String _receiptExt = 'jpg';

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amountCtrl.text = e.totalCost.toString();
      _supplierCtrl.text = e.supplier ?? '';
      _descriptionCtrl.text = e.description ?? '';
      _date = e.date;
      _paymentMethod = e.paymentMethod;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _supplierCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  T? _match<T>(List<T> items, bool touched, T? picked, String? id,
      String Function(T) idOf) {
    if (touched) return picked;
    if (id == null) return picked;
    for (final it in items) {
      if (idOf(it) == id) return it;
    }
    return picked;
  }

  @override
  Widget build(BuildContext context) {
    final farms = ref.watch(myFarmsProvider);
    final categories = ref.watch(expenseCategoriesProvider);

    final t = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? t.editExpense : t.addExpense)),
      body: farms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => FormMessage(message: 'Could not load your farms.\n$e'),
        data: (farmList) {
          if (farmList.isEmpty) {
            return const FormMessage(
              icon: Symbols.agriculture,
              message: 'Create a farm first, then you can log expenses for it.',
            );
          }
          return _buildForm(farmList, categories);
        },
      ),
    );
  }

  Widget _buildForm(
    List<Farm> farms,
    AsyncValue<List<ExpenseCategory>> categories,
  ) {
    final farm = _match(farms, _farmTouched, _farm, widget.existing?.farmId,
            (f) => f.id) ??
        farms.first;
    final plots = ref.watch(plotsForFarmProvider(farm.id));
    final crops = ref.watch(cropsForFarmProvider(farm.id));
    final t = ref.watch(stringsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FormErrorBanner(_error!),
          ),

        FieldLabel(t.amount, required: true),
        TextField(
          controller: _amountCtrl,
          autofocus: !_isEdit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(prefixText: '\$ ', hintText: '0.00'),
          style: AppText.headlineSm,
        ),
        const SizedBox(height: 20),

        FieldLabel(t.farm, required: true),
        FormDropdown<Farm>(
          value: farm,
          items: [
            for (final f in farms)
              DropdownMenuItem(value: f, child: Text(f.name)),
          ],
          onChanged: farms.length == 1
              ? null
              : (f) => setState(() {
                    _farm = f;
                    _farmTouched = true;
                    _plotTouched = true;
                    _plot = null;
                    _cropTouched = true;
                    _crop = null;
                  }),
        ),
        const SizedBox(height: 20),

        FieldLabel(t.category, required: true),
        categories.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(t.couldNotLoadCategories,
              style: AppText.labelMd.copyWith(color: AppColors.error)),
          data: (cats) => FormDropdown<ExpenseCategory>(
            value: _match(cats, _categoryTouched, _category,
                widget.existing?.categoryId, (c) => c.id),
            hint: t.selectCategory,
            items: [
              for (final c in cats)
                DropdownMenuItem(value: c, child: Text(c.label())),
            ],
            onChanged: (c) => setState(() {
              _category = c;
              _categoryTouched = true;
            }),
          ),
        ),
        const SizedBox(height: 20),

        FieldLabel(t.date, required: true),
        DateField(date: _date, onTap: _pickDate),
        const SizedBox(height: 20),

        FieldLabel(t.paymentMethod),
        FormDropdown<String>(
          value: _paymentMethod,
          hint: t.optional,
          items: [
            for (final m in _paymentMethods)
              DropdownMenuItem(value: m.$1, child: Text(m.$2)),
          ],
          onChanged: (m) => setState(() => _paymentMethod = m),
        ),
        const SizedBox(height: 20),

        FieldLabel(t.supplier),
        TextField(
          controller: _supplierCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: t.whoYouPaid),
        ),
        const SizedBox(height: 20),

        plots.maybeWhen(
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel(t.plot),
                    FormDropdown<Plot>(
                      value: _match(list, _plotTouched, _plot,
                          widget.existing?.plotId, (p) => p.id),
                      hint: t.optional,
                      items: [
                        for (final p in list)
                          DropdownMenuItem(value: p, child: Text(p.name)),
                      ],
                      onChanged: (p) => setState(() {
                        _plot = p;
                        _plotTouched = true;
                      }),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
          orElse: () => const SizedBox.shrink(),
        ),

        crops.maybeWhen(
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel(t.crop),
                    FormDropdown<Crop>(
                      value: _match(list, _cropTouched, _crop,
                          widget.existing?.cropId, (c) => c.id),
                      hint: t.optional,
                      items: [
                        for (final c in list)
                          DropdownMenuItem(
                              value: c, child: Text(c.displayName)),
                      ],
                      onChanged: (c) => setState(() {
                        _crop = c;
                        _cropTouched = true;
                      }),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
          orElse: () => const SizedBox.shrink(),
        ),

        FieldLabel(t.notes),
        TextField(
          controller: _descriptionCtrl,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: t.extraDetail),
        ),
        const SizedBox(height: 20),

        FieldLabel(t.receiptPhoto),
        _ReceiptPicker(
          bytes: _receiptBytes,
          existingUrl: _isEdit ? widget.existing!.receiptUrl : null,
          onPick: _pickReceipt,
          onRemove: () => setState(() => _receiptBytes = null),
        ),
        const SizedBox(height: 28),

        FilledButton(
          onPressed: _saving ? null : () => _save(farm),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.onPrimary))
              : Text(_isEdit ? t.saveChanges : t.saveExpense),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.photo_camera),
              title: Text(ref.read(stringsProvider).takePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Symbols.photo_library),
              title: Text(ref.read(stringsProvider).chooseGallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picker = ImagePicker();
      final file =
          await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final dot = file.name.lastIndexOf('.');
      setState(() {
        _receiptBytes = bytes;
        _receiptExt = dot == -1 ? 'jpg' : file.name.substring(dot + 1);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not access the camera or gallery.');
      }
    }
  }

  Future<void> _save(Farm farm) async {
    final amount = num.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount greater than zero.');
      return;
    }
    final category = _match(
        ref.read(expenseCategoriesProvider).valueOrNull ?? const [],
        _categoryTouched,
        _category,
        widget.existing?.categoryId,
        (c) => c.id);
    if (category == null) {
      setState(() => _error = 'Please choose a category.');
      return;
    }
    final plot = _match(ref.read(plotsForFarmProvider(farm.id)).valueOrNull ?? const [],
        _plotTouched, _plot, widget.existing?.plotId, (p) => p.id);
    final crop = _match(ref.read(cropsForFarmProvider(farm.id)).valueOrNull ?? const [],
        _cropTouched, _crop, widget.existing?.cropId, (c) => c.id);

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = ref.read(expenseRepositoryProvider);
    try {
      String? receiptUrl;
      if (_receiptBytes != null) {
        receiptUrl = await repo.uploadReceipt(
            farmId: farm.id, bytes: _receiptBytes!, fileExt: _receiptExt);
      }

      if (_isEdit) {
        await repo.updateExpense(
          id: widget.existing!.id,
          totalCost: amount,
          date: _date,
          categoryId: category.id,
          plotId: plot?.id,
          cropId: crop?.id,
          supplier: _supplierCtrl.text,
          description: _descriptionCtrl.text,
          paymentMethod: _paymentMethod,
          receiptUrl: receiptUrl,
        );
      } else {
        await repo.addExpense(
          farmId: farm.id,
          totalCost: amount,
          date: _date,
          categoryId: category.id,
          plotId: plot?.id,
          cropId: crop?.id,
          supplier: _supplierCtrl.text,
          description: _descriptionCtrl.text,
          paymentMethod: _paymentMethod,
          receiptUrl: receiptUrl,
        );
      }

      ref.invalidate(farmSummaryProvider);
      ref.invalidate(expensesForFarmProvider(farm.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isEdit
                ? ref.read(stringsProvider).expenseUpdated
                : ref.read(stringsProvider).expenseSaved)),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the expense. Please try again.';
      });
    }
  }
}

class _ReceiptPicker extends StatelessWidget {
  const _ReceiptPicker({
    required this.bytes,
    required this.onPick,
    required this.onRemove,
    this.existingUrl,
  });

  final Uint8List? bytes;
  final String? existingUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes!,
                height: 160, width: double.infinity, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Material(
              color: AppColors.surface,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Symbols.close, size: 20),
                onPressed: onRemove,
                tooltip: 'Remove',
              ),
            ),
          ),
        ],
      );
    }

    final hasExisting = existingUrl != null;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Symbols.add_a_photo, color: AppColors.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(hasExisting ? 'Replace receipt' : 'Add a receipt',
                style: AppText.labelMd
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

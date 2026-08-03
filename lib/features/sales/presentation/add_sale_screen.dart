import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../models/crop.dart';
import '../../../models/farm.dart';
import '../../../models/sale.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../expenses/data/expense_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/sales_repository.dart';

const _units = ['kg', 'ton', 'sack', 'crate', 'box', 'bunch', 'piece'];

const _paymentMethods = <(String, String)>[
  ('cash', 'Cash'),
  ('mobile_money', 'Mobile money'),
  ('bank_transfer', 'Bank transfer'),
  ('credit', 'Credit'),
];

const _paymentStatuses = <(String, String)>[
  ('paid', 'Paid'),
  ('partial', 'Partial'),
  ('unpaid', 'Unpaid'),
];

/// Full-screen Sale form. Pass [existing] to edit instead of create.
class AddSaleScreen extends ConsumerStatefulWidget {
  const AddSaleScreen({super.key, this.existing});
  final Sale? existing;

  @override
  ConsumerState<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends ConsumerState<AddSaleScreen> {
  final _quantityCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  final _marketCtrl = TextEditingController();

  Farm? _farm;
  bool _farmTouched = false;
  Crop? _crop;
  bool _cropTouched = false;
  String _unit = 'kg';
  String _paymentStatus = 'paid';
  String? _paymentMethod;
  DateTime _date = DateTime.now();

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    if (s != null) {
      _quantityCtrl.text = s.quantity.toString();
      _priceCtrl.text = s.unitPrice.toString();
      _discountCtrl.text = s.discount == 0 ? '' : s.discount.toString();
      _customerCtrl.text = s.customer ?? '';
      _marketCtrl.text = s.market ?? '';
      _unit = _units.contains(s.unit) ? s.unit : 'kg';
      _paymentStatus = s.paymentStatus;
      _paymentMethod = s.paymentMethod;
      _date = s.date;
    }
    for (final c in [_quantityCtrl, _priceCtrl, _discountCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _customerCtrl.dispose();
    _marketCtrl.dispose();
    super.dispose();
  }

  double get _total {
    final q = double.tryParse(_quantityCtrl.text.trim()) ?? 0;
    final p = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final d = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    final t = q * p - d;
    return t < 0 ? 0 : t;
  }

  T? _match<T>(List<T> items, bool touched, T? picked, String? id,
      String Function(T) idOf) {
    if (touched || id == null) return picked;
    for (final it in items) {
      if (idOf(it) == id) return it;
    }
    return picked;
  }

  @override
  Widget build(BuildContext context) {
    final farms = ref.watch(myFarmsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: Text(_isEdit
              ? ref.read(stringsProvider).editSale
              : ref.read(stringsProvider).recordSale)),
      body: farms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => FormMessage(message: 'Could not load your farms.\n$e'),
        data: (list) {
          if (list.isEmpty) {
            return const FormMessage(
              icon: Symbols.agriculture,
              message: 'Create a farm first, then you can record sales.',
            );
          }
          return _buildForm(list);
        },
      ),
    );
  }

  Widget _buildForm(List<Farm> farms) {
    final farm = _match(farms, _farmTouched, _farm, widget.existing?.farmId,
            (f) => f.id) ??
        farms.first;
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

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.saleTotal,
                  style: AppText.labelSm.copyWith(
                      color: AppColors.onPrimaryContainer, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(formatMoney(_total),
                  style: AppText.headlineLgMobile
                      .copyWith(color: AppColors.onPrimaryContainer)),
            ],
          ),
        ),

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
                    _crop = null;
                    _cropTouched = true;
                  }),
        ),
        const SizedBox(height: 20),

        FieldLabel(t.crop),
        crops.maybeWhen(
          data: (list) => FormDropdown<Crop>(
            value: _match(
                list, _cropTouched, _crop, widget.existing?.cropId, (c) => c.id),
            hint: list.isEmpty ? t.noCropsOptional : t.selectCrop,
            items: [
              for (final c in list)
                DropdownMenuItem(value: c, child: Text(c.displayName)),
            ],
            onChanged: list.isEmpty
                ? null
                : (c) => setState(() {
                      _crop = c;
                      _cropTouched = true;
                    }),
          ),
          orElse: () => const LinearProgressIndicator(),
        ),
        const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel(t.quantity, required: true),
                  _numberField(_quantityCtrl, hint: '0', autofocus: !_isEdit),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel(t.unit, required: true),
                  FormDropdown<String>(
                    value: _unit,
                    items: [
                      for (final u in _units)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (u) => setState(() => _unit = u ?? 'kg'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel(t.unitPrice, required: true),
                  _numberField(_priceCtrl, hint: '0.00', prefix: '\$ '),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel(t.discount),
                  _numberField(_discountCtrl, hint: '0.00', prefix: '\$ '),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        FieldLabel(t.paymentStatus, required: true),
        FormDropdown<String>(
          value: _paymentStatus,
          items: [
            for (final s in _paymentStatuses)
              DropdownMenuItem(value: s.$1, child: Text(s.$2)),
          ],
          onChanged: (s) => setState(() => _paymentStatus = s ?? 'paid'),
        ),
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

        FieldLabel(t.customer),
        TextField(
          controller: _customerCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: t.buyerName),
        ),
        const SizedBox(height: 20),

        FieldLabel(t.market),
        TextField(
          controller: _marketCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: t.whereSold),
        ),
        const SizedBox(height: 20),

        FieldLabel(t.date, required: true),
        DateField(date: _date, onTap: _pickDate),
        const SizedBox(height: 28),

        FilledButton(
          onPressed: _saving ? null : () => _save(farm),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.onPrimary))
              : Text(_isEdit ? t.saveChanges : t.saveSale),
        ),
      ],
    );
  }

  Widget _numberField(
    TextEditingController controller, {
    required String hint,
    String? prefix,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(hintText: hint, prefixText: prefix),
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

  Future<void> _save(Farm farm) async {
    final qty = num.tryParse(_quantityCtrl.text.trim());
    final price = num.tryParse(_priceCtrl.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a valid quantity greater than zero.');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _error = 'Enter a valid unit price greater than zero.');
      return;
    }
    final discount = num.tryParse(_discountCtrl.text.trim()) ?? 0;
    final crop = _match(ref.read(cropsForFarmProvider(farm.id)).valueOrNull ?? const [],
        _cropTouched, _crop, widget.existing?.cropId, (c) => c.id);

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = ref.read(salesRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.updateSale(
          id: widget.existing!.id,
          quantity: qty,
          unit: _unit,
          unitPrice: price,
          discount: discount,
          date: _date,
          paymentStatus: _paymentStatus,
          cropId: crop?.id,
          customer: _customerCtrl.text,
          market: _marketCtrl.text,
          paymentMethod: _paymentMethod,
        );
      } else {
        await repo.addSale(
          farmId: farm.id,
          quantity: qty,
          unit: _unit,
          unitPrice: price,
          discount: discount,
          date: _date,
          paymentStatus: _paymentStatus,
          cropId: crop?.id,
          customer: _customerCtrl.text,
          market: _marketCtrl.text,
          paymentMethod: _paymentMethod,
        );
      }

      ref.invalidate(farmSummaryProvider);
      ref.invalidate(salesForFarmProvider(farm.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isEdit
                ? ref.read(stringsProvider).saleUpdated
                : ref.read(stringsProvider).saleRecorded)),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the sale. Please try again.';
      });
    }
  }
}

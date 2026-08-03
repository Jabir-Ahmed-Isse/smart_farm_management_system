import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A form field label, with an optional red asterisk for required fields.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: text,
          style: AppText.labelMd.copyWith(color: AppColors.onSurfaceVariant),
          children: required
              ? [
                  TextSpan(
                      text: ' *',
                      style: AppText.labelMd.copyWith(color: AppColors.error)),
                ]
              : null,
        ),
      ),
    );
  }
}

/// A themed dropdown that matches the app's input decoration.
class FormDropdown<T> extends StatelessWidget {
  const FormDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      hint: hint == null
          ? null
          : Text(hint!,
              style:
                  AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
      items: items,
      onChanged: onChanged,
    );
  }
}

/// An inline error banner shown above a form.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Symbols.error,
              color: AppColors.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppText.labelMd
                    .copyWith(color: AppColors.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

/// A centered full-screen message (used for load errors / "create a farm").
class FormMessage extends StatelessWidget {
  const FormMessage({super.key, required this.message, this.icon = Symbols.error});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.outline),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: AppText.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Date-picker field styled like the other inputs.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        '${_weekday(date.weekday)}, ${date.day} ${_month(date.month)} ${date.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(),
        child: Row(
          children: [
            const Icon(Symbols.calendar_today,
                size: 20, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(label, style: AppText.bodyMd),
          ],
        ),
      ),
    );
  }

  static String _weekday(int w) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
  static String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}

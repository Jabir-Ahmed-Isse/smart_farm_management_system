import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

/// Reached after the user follows the emailed password-recovery link, which
/// signs them in with a temporary recovery session. Here they set a new
/// password; on success we send them into the app.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pw = _password.text;
    if (pw.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pw != _confirm.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(pw);
      if (mounted) context.go('/');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Set a new password',
      subtitle: 'Choose a new password for your account.',
      children: [
        if (_error != null) AuthBanner(message: _error!),
        AuthField(
          controller: _password,
          label: 'New password',
          icon: Symbols.lock,
          obscure: _obscure,
          hint: '••••••••',
          trailing: IconButton(
            icon: Icon(_obscure ? Symbols.visibility : Symbols.visibility_off,
                size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        AuthField(
          controller: _confirm,
          label: 'Confirm password',
          icon: Symbols.lock,
          obscure: _obscure,
          hint: '••••••••',
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.onPrimary),
                )
              : const Text('Update password'),
        ),
      ],
    );
  }
}

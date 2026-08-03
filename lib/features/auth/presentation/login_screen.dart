import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _email.text.trim(),
            password: _password.text,
          );
      if (mounted) context.go('/');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = ref.read(stringsProvider).somethingWrong);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    return AuthScaffold(
      title: t.authWelcome,
      subtitle: t.signInSubtitle,
      footer: TextButton(
        onPressed: () => context.go('/register'),
        child: Text.rich(
          TextSpan(
            text: t.newToSfms,
            style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            children: [
              TextSpan(
                text: t.createAccount,
                style: AppText.bodyMd.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
      children: [
        if (_error != null) AuthBanner(message: _error!),
        AuthField(
          controller: _email,
          label: t.email,
          icon: Symbols.mail,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        AuthField(
          controller: _password,
          label: t.password,
          icon: Symbols.lock,
          hint: '••••••••',
          obscure: _obscure,
          textInputAction: TextInputAction.done,
          trailing: IconButton(
            icon: Icon(_obscure ? Symbols.visibility : Symbols.visibility_off,
                size: 20, color: AppColors.outline),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.go('/forgot-password'),
            child: Text(t.forgotPassword,
                style: AppText.labelMd.copyWith(color: AppColors.primary)),
          ),
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
              : Text(t.signIn),
        ),
      ],
    );
  }
}

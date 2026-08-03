import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/public_flags.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _checkEmail = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(ref.read(publicFlagsProvider).valueOrNull?.signupsEnabled ?? true)) {
      setState(() => _error = 'New sign-ups are currently disabled.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = ref.read(stringsProvider).passwordMinError);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ref.read(authRepositoryProvider).signUp(
            email: _email.text.trim(),
            password: _password.text,
            fullName: _name.text.trim(),
          );
      if (!mounted) return;
      if (res.session != null) {
        context.go('/');
      } else {
        setState(() => _checkEmail = true);
      }
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
    final signupsEnabled =
        ref.watch(publicFlagsProvider).valueOrNull?.signupsEnabled ?? true;
    if (_checkEmail) {
      return AuthScaffold(
        title: t.checkYourEmail,
        subtitle: t.confirmSentTo(_email.text.trim()),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                  color: AppColors.primaryFixed, shape: BoxShape.circle),
              child: const Icon(Symbols.mark_email_read,
                  color: AppColors.onPrimaryFixed),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: Text(t.backToSignIn),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: t.createAccountTitle,
      subtitle: t.registerSubtitle,
      footer: TextButton(
        onPressed: () => context.go('/login'),
        child: Text.rich(
          TextSpan(
            text: t.alreadyHaveAccount,
            style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            children: [
              TextSpan(
                text: t.signIn,
                style: AppText.bodyMd.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
      children: [
        if (!signupsEnabled)
          const AuthBanner(
              message: 'New sign-ups are currently disabled. '
                  'Please check back later.'),
        if (_error != null) AuthBanner(message: _error!),
        AuthField(
          controller: _name,
          label: t.fullName,
          icon: Symbols.person,
          hint: 'Ahmed Ali',
          textInputAction: TextInputAction.next,
        ),
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
          hint: t.passwordMinHint,
          obscure: _obscure,
          textInputAction: TextInputAction.done,
          trailing: IconButton(
            icon: Icon(_obscure ? Symbols.visibility : Symbols.visibility_off,
                size: 20, color: AppColors.outline),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: (_loading || !signupsEnabled) ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.onPrimary),
                )
              : Text(t.createAccountTitle),
        ),
      ],
    );
  }
}

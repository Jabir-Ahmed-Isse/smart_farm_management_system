import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/data/profile_repository.dart';
import 'app_strings.dart';

export 'app_strings.dart';

/// An in-session language override, set the instant the user picks a language so
/// the UI switches without waiting for the profile round-trip. Null = follow the
/// saved profile preference.
final languageOverrideProvider = StateProvider<AppLang?>((ref) => null);

/// The language the UI should render in: the override if set, otherwise the
/// signed-in profile's `language` (defaulting to Somali for this audience).
final appLanguageProvider = Provider<AppLang>((ref) {
  final override = ref.watch(languageOverrideProvider);
  if (override != null) return override;
  final lang = ref.watch(myProfileProvider).valueOrNull?.language;
  return lang == 'en' ? AppLang.en : AppLang.so;
});

/// The active string table. Watch this in a widget and it rebuilds on switch:
///   final t = ref.watch(stringsProvider);
///   Text(t.navHome);
final stringsProvider = Provider<AppStrings>((ref) {
  return AppStrings(ref.watch(appLanguageProvider));
});

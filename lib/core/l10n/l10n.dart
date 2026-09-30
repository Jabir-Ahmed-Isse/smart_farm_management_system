import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/data/profile_repository.dart';
import '../offline/local_store.dart';
import 'app_strings.dart';

export 'app_strings.dart';

/// Device-local key holding the user's chosen UI language ('en' | 'so').
const kUiLanguageKey = 'ui:language';

/// The user's chosen UI language, applied the instant they pick one and
/// persisted on-device so it survives restarts and never depends on a network
/// round-trip. Seeded from local storage at startup. Null = follow the saved
/// profile preference.
final languageOverrideProvider = StateProvider<AppLang?>((ref) {
  if (!LocalStore.isReady) return null;
  final saved = LocalStore.instance.metaGet(kUiLanguageKey);
  if (saved == 'en') return AppLang.en;
  if (saved == 'so') return AppLang.so;
  return null;
});

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
